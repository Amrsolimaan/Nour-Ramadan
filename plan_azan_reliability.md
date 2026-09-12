# خطة إصلاح موثوقية الأذان — Azan Notification Reliability

**Status:** Analysis & research complete — **no code changed.**
**Date:** 2026-09-11
**App:** `nour_ramadan` v4.0.5+9 · Flutter 3.8.1 · minSdk 26 / targetSdk 35 / compileSdk 36
**Symptom:** Azan notifications degrade and eventually stop unless the user manually opens the app. Other prayer apps run for months untouched.

---

## 0. Executive summary (read this first)

The app already contains a **large, well-intentioned, and mostly correctly-architected** native scheduling layer: 14 Kotlin files, a boot receiver, a time-change receiver, a WorkManager heartbeat, a JobScheduler fallback, `setAlarmClock()` as the alarm primitive, and a full set of manifest permissions. On paper this is close to the industry-standard design.

**It is almost entirely dead code at runtime.**

Every Kotlin component reads its inputs from `SharedPreferences` keys named `flutter.last_lat`, `flutter.last_lng`, and `flutter.azan_<id>_time`. Every Dart component writes those values through `shared_preferences`, which **automatically prepends `flutter.` to every key it stores**. The Dart code additionally hardcodes the `flutter.` prefix into the key string. The result is that Dart writes to `flutter.flutter.last_lat` while Kotlin reads `flutter.last_lat` — **a permanent miss, on every device, on every run.**

Consequence chain:

1. `AlarmScheduler.refresh()` — the entire "Phase 2 native self-computation engine" — **returns at its third statement, every single time**, because it cannot find a location.
2. Therefore `AzanBootReceiver`, `AzanWorker`, `AzanJobService`, `TimeChangeReceiver`, and the post-azan re-arm chain all find **zero** usable prayer data and schedule **zero** alarms.
3. The **only** code path in the entire app that ever arms a real alarm is `PrayerNotificationManager._scheduleAllNotifications()`, which runs **only while the Flutter app is in the foreground**, and which schedules **today's 5 prayers + sunrise + tomorrow's Fajr — roughly a 30-hour horizon.**
4. When those ~7 alarms have fired, nothing re-arms them. The app goes silent until the user opens it again.

That is an exact, mechanical match for the reported symptom. It is not a Doze problem, not an OEM problem, and not a permissions problem — those are all secondary. **It is a two-character key-naming bug that silently disables a thousand lines of otherwise-correct recovery code.**

A DST/clock change makes it strictly worse: `TimeChangeReceiver` **cancels all 42 alarm IDs first**, then calls the dead `AlarmScheduler.refresh()`, then tries `startActivity()` from a `BroadcastReceiver` — which Android 10+ blocks outright. So a seasonal clock change in Egypt actively **destroys** the remaining schedule and restores nothing.

---

## Part 1 — Audit of the current implementation

### 1.1 Inventory of the pipeline

**Native Android — `android/app/src/main/kotlin/com/NourRamadan/` (4,548 lines):**

| File | Lines | Role | Live? |
|---|---|---|---|
| `AlarmScheduler.kt` | 414 | "Phase 2" self-contained Kotlin engine; computes 7 days via `adhan-java`, arms a 48h sliding window | ❌ **Dead** (§1.8) |
| `AzanAlarmReceiver.kt` | 709 | Receives each azan alarm, plays audio, re-arms the next batch | ⚠️ Fires, but re-arm is dead |
| `AzanBootReceiver.kt` | 236 | `BOOT_COMPLETED` → re-arm next 24h | ❌ **Dead** (§1.8) |
| `TimeChangeReceiver.kt` | 193 | `TIME_SET` / `TIMEZONE_CHANGED` → cancel-all then re-arm | ❌ **Destructive** (§1.6) |
| `AzanWorker.kt` | 688 | WorkManager 4h heartbeat + self-heal + emergency Fajr | ❌ **Dead** (§1.8) |
| `AzanJobService.kt` | 146 | JobScheduler fallback | ❌ **Never scheduled** (§1.10) |
| `AzanPlugin.kt` | 478 | MethodChannel `com.nour_ramadan/azan_service` | ✅ Live |
| `AzanForegroundService.kt` | 587 | Plays the azan audio | ✅ Live |
| `AdhanActivity.kt` / `AzanDismissReceiver.kt` / `ReminderAlarmReceiver.kt` / `WakeLockHelper.kt` / `ManufacturerHelper.kt` / `MainActivity.kt` | 1,097 | UI, dismissal, reminders, OEM helpers | ✅ Live |

**Flutter/Dart — `lib/core/services/`:**

| File | Role |
|---|---|
| `prayer_notification_manager.dart` (481) | **The only live scheduler.** Reacts to `prayerProvider`/`settingsProvider`; schedules today + tomorrow's Fajr |
| `unified_azan_service.dart` (664) | `scheduleAzan()` → MethodChannel `scheduleExactAlarm`; iOS path uses `zonedSchedule` |
| `notification_service.dart` (450) | `flutter_local_notifications` wrapper (reminders, suhoor, iftar) |
| `location_service.dart` (302) | Persists lat/lng — **source of the key bug** |
| `alarm_permission_service.dart` (268) | Permission checks incl. battery optimization |

**iOS — in scope but currently non-functional for azan:** `unified_azan_service.dart:190-230` disables azan audio on iOS entirely ("audio files need to be `.aiff` format") and falls back to a `zonedSchedule` notification with the default system sound. `AppDelegate.swift` registers a notification category and nothing else. There is **no** iOS long-horizon or repeating-trigger scheduling.

---

### 1.2 What actually triggers (re)scheduling today

| Trigger | Code | Effective? |
|---|---|---|
| App launch | `MainActivity.onCreate` → `AlarmScheduler.refresh()` | ❌ bails (§1.8) |
| App launch | `MainActivity.onCreate` → `AzanWorker.schedule()` | ⚠️ enqueues, but worker is a no-op |
| App resume | `main.dart:451` `didChangeAppLifecycleState` → `manualReschedule()` | ✅ **the only thing that works** |
| Prayer/settings change | `prayer_notification_manager.dart:39-86` Riverpod listeners | ✅ works (foreground only) |
| Every 4 hours | `AzanWorker.doWork()` | ❌ no-op (§1.8) |
| After each azan | `AzanAlarmReceiver:157` `AlarmScheduler.refresh()` + `scheduleFromSharedPrefsOnly()` | ❌ both read dead keys |
| Device reboot | `AzanBootReceiver.onReceive` | ❌ no-op (§1.8) |
| Clock/TZ change | `TimeChangeReceiver.onReceive` | ❌ **worse than no-op** (§1.6) |

**Net: the schedule can only ever be extended by the user opening the app.** Precisely the reported complaint.

---

### 1.3 Alarm permissions — ✅ this part is correct

`AndroidManifest.xml:5-15` declares `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `USE_FULL_SCREEN_INTENT`, `WAKE_LOCK`, `POST_NOTIFICATIONS`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `FOREGROUND_SERVICE(_MEDIA_PLAYBACK)`.

The alarm primitive is also correct. Every scheduling site uses **`AlarmManager.setAlarmClock()`** — `AlarmScheduler.kt:299`, `AzanBootReceiver.kt:180`, `AzanWorker.kt:648`, `AzanJobService.kt:122`, `AzanPlugin.kt:117`. Per Android docs, `setAlarmClock()` is **fully exempt from Doze**: *"Alarms set with `setAlarmClock()` continue to fire normally. The system exits Doze shortly before those alarms fire."* Permission is checked via `canScheduleExactAlarms()` before each pass.

`flutter_local_notifications` is used **only for reminders/suhoor/iftar on Android and for everything on iOS**, with `AndroidScheduleMode.exactAllowWhileIdle` (`unified_azan_service.dart:214, 409`). That is an acceptable mode, though weaker than `setAlarmClock` — see §2.2.

> **Verdict: permissions and the alarm primitive are not the root cause.** This is already better than many apps in this category.

---

### 1.4 Boot persistence — receiver exists, but is inert

`AzanBootReceiver` is correctly declared (`AndroidManifest.xml:80-91`) with `directBootAware="true"` and listens for `BOOT_COMPLETED` plus the HTC/quickboot variants. `flutter_local_notifications`' own `ScheduledNotificationBootReceiver` is also registered.

But `rescheduleAzansDirectly()` (`AzanBootReceiver.kt:67`) reads `flutter.azan_<id>_time` — a key **nothing ever writes** (§1.8). Every ID is skipped, `azanCount == 0`, and the fallback at line 138 calls `AzanWorker.rescheduleNow()`, which is equally dead.

> **A reboot silently wipes the entire schedule.** The recovery code is present and correct in shape — it just has no data to read.

---

### 1.5 Timezone / DST handling

- **Receivers:** registered correctly (`AndroidManifest.xml:94-104`) for `TIME_CHANGED`, `TIME_SET`, `TIMEZONE_CHANGED`. These are on Android's **implicit-broadcast exemption list**, so manifest registration is valid post-Oreo. (Note `Intent.ACTION_TIME_CHANGED` and `"android.intent.action.TIME_SET"` are the *same string constant* — the duplicate entry is harmless.)
- **`timezone` package:** `main.dart:83-88`:
  ```dart
  tz.initializeTimeZones();
  try {
    tz_local.setLocalLocation(tz_local.local);   // ← no-op
  } catch (e) {
    tz_local.setLocalLocation(tz_local.getLocation('Africa/Cairo'));
  }
  ```
  `tz.local` **defaults to UTC** until explicitly set. So line 85 sets local ← local (UTC), never throws, and the `Africa/Cairo` fallback is **unreachable dead code**. `tz.local` is UTC for the app's entire lifetime. There is no `flutter_timezone` dependency, so the app **cannot detect the device's real IANA zone at all.**
- **Impact today:** limited, because `tz.TZDateTime.from()` preserves the absolute instant and the Android azan path bypasses `tz` entirely (it passes raw `millisecondsSinceEpoch`). **But** it silently breaks anything relying on wall-clock semantics — which is exactly what a repeating/`matchDateTimeComponents` design would need.
- **Prayer-time math is DST-immune by construction:** `adhan` computes solar instants; a DST shift does not move the epoch-ms of Fajr. The alarm timestamps stay correct across a DST transition.

> **So why does Egypt's DST break it?** Not the math — the *receiver*. See §1.6.

---

### 1.6 `TimeChangeReceiver` is actively destructive 🔴

`TimeChangeReceiver.handleTimeChange()` (`TimeChangeReceiver.kt:69`) runs three steps:

1. **`cancelAllOldAlarms()`** — iterates IDs `100-105, 150, 210-265` and cancels every matching `PendingIntent`. **This works.** All alarms are destroyed.
2. **`AlarmScheduler.refresh()`** — **bails immediately** (§1.8). Nothing is re-armed.
3. **`notifyFlutterToRecalculate()`** — calls `context.startActivity(...)` **from inside a `BroadcastReceiver`**. Android 10+ (API 29) **blocks background activity starts**; this throws or is silently dropped. Even if it worked, force-opening the app on a clock change is unacceptable UX.

> **Result: every DST transition, every manual clock change, every network-time correction, and every timezone change deletes the entire schedule and restores nothing.** Egypt's seasonal clock changes therefore produce exactly the reported "it stopped around the time change" failure. This is the **second-most-damaging** defect after §1.8.

---

### 1.7 Battery optimization / OEM killing

- Permission `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` **is** declared; `AzanPlugin` implements `requestBatteryExemption` and `isBatteryOptimizationDisabled`; `ManufacturerHelper.kt` (358 lines) has per-OEM autostart/battery deep-links for Xiaomi/Huawei/Oppo/etc.; a `BatteryPermissionScreen` exists.
- **But the prompt is never shown proactively.** `main.dart:225`:
  ```dart
  // await azanService.requestBatteryExemption();
  ```
  **Commented out.** The user must find Settings → battery screen on their own. In practice, almost nobody does.
- `AzanWorker.checkBatteryOptimizationStatus()` only **logs** — it never notifies the user.

> **Contributing factor, not root cause.** With `setAlarmClock()` the alarms themselves are Doze-exempt; the exemption mainly protects the *WorkManager heartbeat*. Since the heartbeat is a no-op anyway (§1.8), fixing battery optimization alone would change nothing today.

---

### 1.8 🔴 **ROOT CAUSE: the `shared_preferences` double-prefix**

**The mechanism.** `shared_preferences` 2.5.5 (`lib/src/shared_preferences_legacy.dart:22, 172`):

```dart
static String _prefix = 'flutter.';
...
final prefixedKey = '$_prefix$key';
```

Every Dart key is stored in Android `SharedPreferences` with `flutter.` **prepended by the plugin**. The app never calls `setPrefix()` (verified: zero occurrences in `lib/`), and does not use the non-prefixing `SharedPreferencesAsync` API.

**The bug.** `location_service.dart:28-30` — with a comment stating the exact misunderstanding:

```dart
// ✅ مفاتيح بـ flutter. prefix ليقرأها Kotlin مباشرةً
static const _flutterLatKey = 'flutter.last_lat';
static const _flutterLngKey = 'flutter.last_lng';
```
```dart
await prefs.setString(_flutterLatKey, _lat!.toString());   // line 144
```
→ actually stored as **`flutter.flutter.last_lat`**.

While `AlarmScheduler.kt:85` reads:
```kotlin
val lat = prefs.getString("flutter.last_lat", null)?.toDoubleOrNull()
```
→ **always `null`.**

**The same file proves the correct convention exists elsewhere.** `settings_provider.dart:225-228` uses `'settings_muezzin'`, `'settings_madhab'`, `'settings_prayer_reminder'` **without** a manual prefix → stored as `flutter.settings_muezzin` → **Kotlin reads these correctly.** Two conventions coexist in one codebase; only one is right.

**Full list of broken keys** (every Dart string literal beginning `'flutter.'`):

| Dart writes (→ actual stored key) | Kotlin reads | Consumer |
|---|---|---|
| `flutter.last_lat` → `flutter.flutter.last_lat` | `flutter.last_lat` | `AlarmScheduler:85`, `AzanWorker:562` |
| `flutter.last_lng` → `flutter.flutter.last_lng` | `flutter.last_lng` | same |
| `flutter.azan_<id>_time` → `flutter.flutter.azan_<id>_time` | `flutter.azan_<id>_time` | `AzanBootReceiver:100`, `AzanWorker:131`, `AzanAlarmReceiver:342`, `AzanJobService:88` |
| `flutter.azan_<id>_prayer` / `_sound` | same pattern | all of the above |
| `flutter.last_sound_file_scheduled` (`prayer_notification_manager.dart:460`, `settings_provider.dart:295`) | `flutter.last_sound_file_scheduled` | ⚠️ **also written correctly** by `unified_azan_service.dart:243` → partially works by accident |
| `flutter.pending_navigation` | written by **Kotlin** `MainActivity:148` | ✅ works (Kotlin↔Kotlin) |

**Consequences, in order:**

1. `AlarmScheduler.refresh()` returns at line 88 (`❌ لا يوجد موقع محفوظ`) — **100% of the time, on 100% of devices.** The 7-day computation, the sliding window, the reminder scheduling, and the `azan_<id>_*` writes that everything else depends on **never execute**.
2. Because step 1 never runs, the `flutter.azan_<id>_*` keys are **never populated by Kotlin either** — so the fallback readers also find nothing.
3. `AzanWorker.doWork()` → `hasValidData = false` → emergency Fajr → **also needs `flutter.last_lat`** → returns `false`. Complete failure.
4. `AzanBootReceiver` → `azanCount == 0` → delegates to the dead worker.
5. `AzanAlarmReceiver`'s post-azan re-arm → all IDs skipped.

> **This single defect converts a sophisticated, multi-layered, self-healing architecture into a foreground-only scheduler with a ~30-hour horizon.** Everything else in this report is secondary to it.

---

### 1.9 🔴 Scheduling horizon: ~30 hours, and it is a single-link chain

`prayer_notification_manager.dart:_scheduleAllNotifications()` schedules:

- today's 5 prayers (IDs 100–104) — **only if `selectedDate == today`** (line 136-145)
- sunrise (ID 105)
- suhoor (300) / iftar (301) if enabled
- **tomorrow's Fajr only** (ID 150, `_scheduleNextDayFajr`, line 295)

**Maximum horizon ≈ 30 hours. Maximum ~8 armed alarms.**

The design *intends* the chain to be extended by `AzanAlarmReceiver` after each azan and by the 4h worker — both dead. So the actual behaviour is: **open app → ~30h of coverage → silence.** This confirms the "self-perpetuating chain that breaks on any single missed link" hypothesis in the strongest possible form: **every link is already broken; only the initial manual push works.**

---

### 1.10 The 48h window rests on a factual error 🔴

`AlarmScheduler.kt:38` sets `WINDOW_MS = 48h`, justified by comments repeated throughout the codebase:

> `AzanAlarmReceiver.kt:249` — *"OLD APPROACH: Schedule 49 alarms (7 days × 7 prayers). Problem: **Exceeds Doze Mode limit of 9 alarms per app**"*
> `AzanAlarmReceiver.kt:306` — *"Maximum: ~10 alarms (well under Doze limit of 9 per app)"*

**There is no such limit.** The Android documentation says:

> *"Neither `setAndAllowWhileIdle()` nor `setExactAndAllowWhileIdle()` can fire alarms **more than once per nine minutes, per app**."*

That is a **rate** limit (one firing per 9 *minutes*), not a **count** limit of 9 alarms — and it **does not apply to `setAlarmClock()` at all**, which this app already uses for every azan. The only real ceiling is the system-wide **500 concurrent alarms per UID** (`IllegalStateException: Maximum limit of concurrent alarms 500 reached for uid`).

> **The entire fragile windowing design — the thing that makes the app depend on a recompute cycle at all — was adopted to avoid a constraint that does not exist.** 7 days × 6 prayers = 42 alarms is ~8% of the real budget. 30 days × 6 = 180 alarms is still comfortably within it.

---

### 1.11 Day-relative alarm IDs rotate under persistent alarms ⚠️ (latent)

`AlarmScheduler.idForDay()` (line 236): `day 0 → 100+i`, `day N → 200 + N*10 + i`.

**IDs are relative to "today", but armed `PendingIntent`s are absolute.** An alarm armed on day D as ID `210` ("tomorrow's Fajr") is still pending on day D+1 — when `refresh()` has **rewritten `flutter.azan_210_time` to mean D+2's Fajr.**

Now `AzanAlarmReceiver.kt:52-75` runs its staleness guard on arrival:

```kotlin
val savedTime = prefs.getString("flutter.azan_${alarmId}_time")!!.toLong()
val diff = now - savedTime
if (diff > 10*60*1000L) { /* ignore: too late */ return }
if (diff < -60*1000L)   { /* ignore: too early */ return }   // ← fires here
```

`diff ≈ −24h` → **the azan is silently suppressed as an "early alarm."**

There is partial redundancy (`refresh()` also arms ID `100` for the same instant), and `isAlarmScheduled(210)` returning `true` prevents ID 210 from ever advancing to D+2. The net effect is a mix of **duplicate alarms and silently-dropped alarms** that varies by when `refresh()` last ran.

> **Currently masked** by §1.8 (the prefs are empty, so the guard is skipped and the azan plays). **It will become an active, user-visible bug the moment the key bug is fixed** — so it must be fixed in the *same* change, not later.

---

### 1.12 Secondary findings

| # | Finding | Evidence | Severity |
|---|---|---|---|
| a | `isAlarmScheduled()` uses `PendingIntent.FLAG_NO_CREATE` as a liveness probe. A `PendingIntent` record can outlive an OEM-cancelled alarm → false "already scheduled" → **self-heal skips a missing alarm.** Also, `PendingIntent` matching **ignores extras** — the `putExtra` calls in the probe are meaningless (only `requestCode` + component disambiguate). | `AlarmScheduler.kt:346-360`, `AzanWorker.kt:166-176` | Moderate |
| b | Reminder liveness probe builds an `Intent(context, AzanAlarmReceiver::class)` but reminders are armed against `ReminderAlarmReceiver` → **never matches → reminders re-armed on every pass.** | `AlarmScheduler.kt:199` vs `:319` | Low (wasteful, not broken) |
| c | `AzanWorker` uses `ExistingPeriodicWorkPolicy.KEEP`. Existing installs that enqueued the old 12h interval **keep 12h forever**; the documented "4h heartbeat" never takes effect for them. | `AzanWorker.kt:48-54` | Moderate |
| d | WorkManager periodic work is **cancelled permanently by a user force-stop** and by most OEM "app killers", and is **not restored until the app is next launched** — making it structurally unfit as the primary continuity mechanism. | Design | Moderate |
| e | `AzanJobService` is only ever scheduled from inside a `catch` nested in a `catch` in `AzanAlarmReceiver:194-207`. In practice **it never runs.** Declared in manifest, 146 lines, dead. | `AzanAlarmReceiver.kt:191-211` | Low |
| f | `AzanWorker.calculatePreciseFajrTime()` calls `adhan` via **reflection** (`Class.forName`) despite `adhan` being a direct Gradle dependency that `AlarmScheduler.kt` imports normally. Survives R8 only because `proguard-rules.pro:18` keeps `com.batoulapps.adhan.**`. Fragile and unnecessary. | `AzanWorker.kt:640-700` | Low |
| g | Two `calculateSimplifiedFajrTime` / `calculateFajrTime` methods are byte-identical dead duplicates; the "simplified" solar math ignores latitude entirely and would produce badly wrong times if ever reached. | `AzanWorker.kt:520-600` | Low |
| h | `tz.local` is permanently **UTC**; `Africa/Cairo` fallback unreachable; no `flutter_timezone` dependency. | `main.dart:83-88` | Moderate (blocks §2.6) |
| i | iOS azan is **disabled outright** (`.mp3` vs `.aiff`); iOS gets a default-sound notification with no long-horizon strategy. | `unified_azan_service.dart:190` | Scope decision |

---

### 1.13 Ranked root-cause statement

| Rank | Cause | Contribution | Confidence |
|---|---|---|---|
| **1** | **SharedPreferences double-`flutter.` prefix** disables 100% of native re-scheduling (§1.8) | **~70%** — alone sufficient to produce the exact symptom | **Certain** (verified in plugin source + every call site) |
| **2** | **`TimeChangeReceiver` cancels everything and restores nothing** (§1.6); `startActivity` from receiver blocked on Android 10+ | **~15%** — explains DST-correlated failures specifically | **Certain** |
| **3** | **~30h horizon with no working extension mechanism** (§1.9, §1.10) — a design that *requires* a recompute cycle that does not exist | **~10%** — the amplifier; would still be fragile even if #1/#2 were fixed | **Certain** |
| **4** | **WorkManager as primary continuity** (§1.12c/d) — wrong primitive, `KEEP` policy bug, dies on force-stop | ~3% | High |
| **5** | **Day-relative IDs + staleness guard** (§1.11) — currently masked, becomes active after #1 is fixed | ~1% now, **high after the fix** | High |
| **6** | **Battery-optimization prompt commented out** (§1.7) | ~1% | Certain |

> **Bottom line:** this is not "Android background work is hard." The architecture is broadly right; a key-naming defect silently severed the Dart→Kotlin data contract, and a destructive time-change handler finishes off whatever survives.

---

## Part 2 — The correct, industry-standard architecture

### 2.1 Schedule far in advance, in one pass

Reliable prayer apps arm **weeks** of alarms at once, so that a missed recompute cycle is invisible. The buffer is the reliability mechanism.

- **Budget:** 500 concurrent alarms per UID is the hard ceiling.
- **Recommended:** **30 days × 6 prayers = 180 alarms** (+ reminders if native-scheduled → 360; still under budget but tighter).
- **Safe and comfortable:** **21 days × 6 = 126 azan alarms + 105 reminders = 231 total.**
- **Refresh trigger:** re-arm whenever coverage drops below **⅓ of the window** (e.g. re-arm at 10 days remaining on a 30-day window), not when it is exhausted.
- Accuracy is not a concern: `adhan` is a deterministic astronomical calculation. Times computed 30 days ahead are identical to times computed that morning, provided **latitude/longitude and calculation method are unchanged** — and both changes already trigger an explicit re-arm.

### 2.2 Exact alarms, done right

`AlarmManager.setAlarmClock()` is the correct primitive and **the app already uses it.** Per Android docs it is **fully Doze-exempt** with no rate limit, unlike `setExactAndAllowWhileIdle()` (capped at one firing per 9 minutes under Doze). It also surfaces in the system alarm UI, which is appropriate and reassuring for prayer times.

**WorkManager is the wrong primitive for delivery.** It is explicitly a *deferrable* work API — "a promise that your work will eventually run when the system determines it's appropriate." It must never be the thing that fires the azan, and must never be the *only* thing that extends the schedule.

### 2.3 Boot + time-change receivers are mandatory

Android: *"By default, all alarms are canceled when a device shuts down."* A `BOOT_COMPLETED` receiver that re-arms from scratch is **non-negotiable** — without it, one reboot silently ends the feature forever.

Required set, all on the implicit-broadcast **exemption list** (so manifest registration is valid):
- `ACTION_BOOT_COMPLETED` (+ `LOCKED_BOOT_COMPLETED` for direct boot)
- `ACTION_TIME_SET` (== `ACTION_TIME_CHANGED`)
- `ACTION_TIMEZONE_CHANGED`
- `ACTION_MY_PACKAGE_REPLACED` (app update also clears alarms)
- `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` (Android 12+; docs explicitly say to treat it like boot)

**The critical rule these receivers must obey: never cancel before you can rebuild.** Compute first, then replace. A cancel-then-fail path (§1.6) is worse than doing nothing.

### 2.4 Battery-optimization exemption UX

Standard pattern in this app category: **ask once, early, with context, and degrade gracefully.**

- Show a single explanatory screen after the user first enables azan: *"To deliver the azan on time even when the app is closed, Android needs to exempt this app from battery optimization."*
- One button → `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. One "later" button.
- If declined: **do not hard-fail.** `setAlarmClock()` still fires under Doze. Record the refusal, don't re-prompt for ≥30 days, and surface a passive indicator on the prayer screen.
- On known-aggressive OEMs, follow up with the autostart deep-link — `ManufacturerHelper.kt` **already implements this** and just needs to be wired to a prompt.

### 2.5 Periodic self-healing is supplementary, never primary

WorkManager's correct role: a **daily audit** that verifies the armed set still matches the intended set, tops up the horizon, and repairs anything an OEM killed. With a 30-day buffer, missing this job for two weeks is harmless — which is exactly the property the current 48h design lacks.

Layered defence, in priority order:
1. **Primary:** 30 days of `setAlarmClock()` alarms (survives everything except reboot/force-stop)
2. **Repair:** boot / time-change / package-replace / permission-change receivers
3. **Audit:** daily WorkManager top-up
4. **Opportunistic:** re-arm on every app foreground (cheap, already works)
5. **Last resort:** each fired azan tops the horizon back up — a bonus, not the mechanism

### 2.6 iOS (if in scope)

Hard cap: **64 pending local notifications per app**; the system keeps the 64 soonest and silently discards the rest. With 6 prayers/day that is **~10 days** of one-shot notifications.

Two viable strategies:
- **Rolling window:** schedule the nearest 64 (~10 days), top up on every launch and from a BGTaskScheduler `BGAppRefreshTask`. Simple; degrades if the app is never opened for >10 days.
- **`UNCalendarNotificationTrigger` with `repeats: true`:** a repeating request counts as **one** against the 64-limit. But prayer times shift daily, so a fixed date-matching trigger drifts — usable only as a coarse safety net, not as the primary mechanism.

**Recommendation: rolling-window + BGAppRefreshTask.** Note iOS azan is currently disabled anyway (`.mp3` vs required `.aiff`/`.caf`), so iOS needs an asset-conversion decision before any of this matters.

---

## Part 3 — Remediation architecture for *this* stack

### 3.1 Target design

```
┌─ Flutter / Dart ──────────────────────────────────────────────┐
│ LocationService ──► writes lat/lng (UNPREFIXED keys)          │
│ SettingsProvider ─► writes method/madhab/muezzin (already OK) │
│ PrayerNotificationManager                                      │
│   • on launch / resume / settings change / location change:   │
│       → MethodChannel 'refreshAlarms'                          │
│   • NO LONGER arms individual Android alarms itself            │
│   • still owns iOS scheduling + suhoor/iftar                   │
└───────────────────────────┬────────────────────────────────────┘
                            │ MethodChannel (settings push only)
┌───────────────────────────▼────────────────────────────────────┐
│ Kotlin — AlarmScheduler (single source of truth for Android)   │
│   • reads lat/lng + settings from SharedPreferences            │
│   • computes N days via adhan-java                             │
│   • arms ALL of them with setAlarmClock()                      │
│   • ABSOLUTE, date-derived alarm IDs (no day-relative rotation)│
│   • idempotent: safe to call any number of times               │
└───────────────────────────┬────────────────────────────────────┘
        ┌───────────┬───────┴────────┬──────────────┬───────────┐
   BootReceiver  TimeChange   PackageReplaced  ExactAlarmPerm  AzanWorker
   (re-arm)     (re-arm)       (re-arm)         (re-arm)      (daily audit)
```

**Single source of truth = Kotlin `AlarmScheduler`** for Android. It already exists and is well-written; it simply needs to be reachable, unbounded, and correctly keyed. Dart's role shrinks to "keep the inputs fresh and poke the engine."

### 3.2 Native Android changes

| Change | Where | Why |
|---|---|---|
| **Absolute alarm IDs** — derive from the date, e.g. `id = (daysSinceEpoch % 400) * 10 + prayerIndex`, offset into a reserved band | `AlarmScheduler.idForDay()` | Kills the ID-rotation bug (§1.11). An ID must always mean the same instant. |
| **Remove the 48h window** — arm the whole horizon | `AlarmScheduler.WINDOW_MS` | The constraint it avoids does not exist (§1.10) |
| **Horizon = N days** (see open question Q1) | `AlarmScheduler.DAYS_AHEAD` | Buffer *is* the reliability mechanism |
| **Make `refresh()` compute-then-replace** | `AlarmScheduler.refresh()` | Never leave the user with zero alarms mid-pass |
| **Rewrite `TimeChangeReceiver`** to call `AlarmScheduler.refresh()` only; **delete `cancelAllOldAlarms()` as a separate step** and **delete `notifyFlutterToRecalculate()`** | `TimeChangeReceiver.kt` | Fixes §1.6; removes the blocked `startActivity` |
| **Relax the staleness guard** — keep the "≥10 min late → drop" rule, **remove the "early" rule**, and compare against the alarm's *own* scheduled time carried in the Intent extras, not a mutable pref | `AzanAlarmReceiver.kt:52-75` | The "early" branch can suppress correct alarms |
| **Add receivers:** `MY_PACKAGE_REPLACED`, `LOCKED_BOOT_COMPLETED`, `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` | `AndroidManifest.xml` + receiver | App updates and permission changes also clear alarms |
| **`ExistingPeriodicWorkPolicy.UPDATE`**; interval → 24h | `AzanWorker.schedule()` | Fixes §1.12c; daily audit is the correct cadence |
| **Delete dead code:** `AzanJobService` (+ manifest entry), reflection-based `calculatePreciseFajrTime`, both `calculate*SimplifiedFajrTime` duplicates | various | ~400 lines of unreachable/duplicated code |
| **Replace `isAlarmScheduled()`** with a persisted ledger of armed `(id → triggerAtMillis)` in SharedPreferences, reconciled on each pass | `AlarmScheduler` | `FLAG_NO_CREATE` is not a reliable liveness probe (§1.12a) |

### 3.3 Flutter / Dart changes

| Change | Where | Why |
|---|---|---|
| 🔴 **Strip the hardcoded `flutter.` from every Dart pref key** — `last_lat`, `last_lng`, `azan_*_time/_prayer/_sound`, `last_sound_file_scheduled` | `location_service.dart:29-30`, `prayer_notification_manager.dart:453-460`, `settings_provider.dart:293-295`, `boot_test_service.dart`, `system_diagnostics_service.dart` | **The root cause.** One-line-per-site fix. |
| **One-time migration** — on first launch after update, copy any `flutter.flutter.*` values to the correct keys and delete the old ones | new `PrefsMigration` | Existing installs carry poisoned keys |
| **Stop arming Android azan alarms from Dart**; call `refreshAlarms` instead | `prayer_notification_manager.dart`, `unified_azan_service.dart` | Eliminates the dual-writer/dual-ID-scheme conflict |
| **Fix timezone init** — add `flutter_timezone`, resolve the real IANA zone, `setLocalLocation(getLocation(name))`, fall back to `Africa/Cairo` | `main.dart:83-88` | §1.5; unblocks correct iOS/`tz` behaviour |
| **Re-enable the battery prompt** as a proper one-time contextual screen | `main.dart:225`, `battery_permission_screen.dart` | §1.7 |
| **Verification surface** — a diagnostics screen showing armed-alarm count, horizon end date, last refresh, permission states | extend `system_diagnostics_service.dart` | Makes "is it actually working?" answerable without a logcat |

---

## Part 4 — Phased roadmap

Each phase is independently reviewable, testable, and shippable. **Phases 1–2 alone should resolve the reported bug.**

### Phase 1 — Restore the data contract 🔴 **[Dart only]** — ✅ **DONE (2026-09-11)**
*The single highest-value change in this plan.*
- ✅ Removed hardcoded `flutter.` prefixes from all Dart pref keys, routed through a new `PrefKeys` contract (`lib/core/services/prefs_keys.dart`) with a `guard()` that `assert()`-fails in debug on any manual `'flutter.'` prefix.
- ✅ Added the one-time `flutter.flutter.*` → `flutter.*` migration (`lib/core/services/prefs_migration.dart`), run at the top of `main()` before any location/scheduling code. 60 passing tests in `test/prefs_migration_test.dart`.
- ✅ **Cleanup bundled in:** fixed the `flutter.pending_navigation` key — Kotlin writes the raw single-prefixed key correctly; Dart's hardcoded-prefix read/write was invisible to it (tap-to-navigate from an azan/reminder notification was silently broken). Routed through `PrefKeys.pendingNavigation`. Deleted the stale `test/widget_test.dart` stub (referenced a nonexistent `MyApp` class; real root is `NourRamadanApp`, which needs a full app harness to smoke-test — not a trivial widget test).
- **Test — ✅ verified on a real device** (`SM A546E`, Android 12/API 32): raw `SharedPreferences.getInstance()...` dumped via `adb shell run-as com.NourRamadan cat shared_prefs/FlutterSharedPreferences.xml` showed `flutter.last_lat`/`flutter.last_lng` single-prefixed, zero surviving `flutter.flutter.*` keys, and `AlarmScheduler` logged `✅ تحديث ذرّي: مُسلَّح=228 فشل=0` instead of `❌ لا يوجد موقع محفوظ` on next launch.
- **Risk:** low. **No native changes required** (the pending_navigation fix touched zero Kotlin — Kotlin's write was already correct).

### Phase 2 — Stop the destruction, extend the horizon 🔴 **[Kotlin]** — 🟡 **CODE COMPLETE, PARTIALLY VERIFIED (2026-09-11)**
- ✅ Rewrote `TimeChangeReceiver` → single call to the now-atomic `AlarmScheduler.refresh()`; deleted `cancelAllOldAlarms()` and the blocked `startActivity()` entirely.
- ✅ `AlarmScheduler.refresh()` is now atomic: computes the full 21-day set first, arms it, and only then cancels whatever in the old ledger isn't in the new set. A failed computation (no location, permission revoked) leaves existing alarms untouched — never a zero-alarm state.
- ✅ `DAYS_AHEAD = 21` (framed explicitly as a **secondary safety net** — the primary fix is Phase 1 restoring the daily-renewal mechanism); deleted `WINDOW_MS` and the 48h sliding-window logic entirely.
- ✅ Absolute, date-derived IDs: `id = ID_BASE + (epochDay % 10000)*10 + prayerIndex` — an ID now means the same instant regardless of "today." Deleted the "early alarm" suppression branch (`AzanAlarmReceiver`'s staleness guard now reads the intended trigger time from the Intent extra `EXTRA_SCHEDULED_AT`, not a mutable pref key).
- ✅ Rewrote `AzanBootReceiver`, `AzanJobService`, `AzanWorker` (688→109 lines) to all delegate to `AlarmScheduler.refresh()` as the single owner, instead of each maintaining its own copy of the old relative-ID scheduling loop. `AzanWorker` heartbeat: 4h→24h, `KEEP`→`UPDATE` policy (§1.12c).
- ✅ Added `MY_PACKAGE_REPLACED` and `LOCKED_BOOT_COMPLETED` to the boot receiver's manifest filter (pulled forward from Phase 3 since it was near-zero incremental cost alongside the boot-receiver rewrite).
- 🐛 **Bug found and fixed during verification:** `unified_azan_service.dart` was still calling `scheduleExactAlarm`/`scheduleReminderAlarm` on Android from three sites, arming a *second*, old-relative-ID alarm at the same instant as the new native set — i.e. a real double-azan. Disabled all three Dart-side Android arming calls; Dart's role on Android is now exclusively to keep prefs fresh and call `refreshNativeScheduler()`.
- 🐛 **Second bug found during a subsequent code-only review (device having disconnected) and fixed (2026-09-11):** `refresh()`'s cancellation loop keyed off `oldLedger - nowArmed` (only what *actually armed this pass*) rather than `oldLedger - plannedIds` (everything this pass *intended* to cover). Consequence: a **partial** failure — one `setAlarmClock()` call throwing, or one day's `PrayerTimes(...)` computation throwing and being `continue`d past — would cancel a still-valid alarm successfully armed by a *previous* pass, net-destroying coverage instead of leaving it alone for retry next cycle. Full-failure (`nowArmed.isEmpty()`) and total-computation-failure paths were already safe; only this partial-failure path was affected. Fixed by extracting the decision into a pure `AlarmScheduler.computeStaleIds(oldLedger, plannedIds)` and keying the loop off `plannedIds` instead. Covered by `android/app/src/test/kotlin/com/NourRamadan/AlarmSchedulerTest.kt` (new JVM unit-test source set + `testImplementation("junit:junit:4.13.2")` in `android/app/build.gradle.kts` — no Robolectric/device/emulator needed since the function under test touches no Android framework class), 4 tests, run via `./gradlew testDebugUnitTest --tests "com.NourRamadan.AlarmSchedulerTest"`.
- **Test — ✅ verified on device before it disconnected:** atomic refresh armed 228 alarms (0 failed); `dumpsys alarm` confirmed 21 distinct trigger dates 2026-09-11 → 2026-10-01 with `exactAllowReason=permission`; alarms **survived normal process death** (`adb shell am kill`, simulating an OOM-killed/backgrounded app — the actual real-world "app not opened" scenario) — 233 `RTC_WAKEUP` entries for the package present afterward.
- ⏸️ **Not re-verified after the duplicate-alarm fix**, and **not yet run**: 3-day clock advance, DST-shift simulation, full `adb reboot`. The Android device (`127.0.0.1:7555`) disconnected mid-verification and could not be reconnected (not a process this session controls — likely torn down by the harness between turns); `flutter devices` no longer lists it. Will resume the moment a device is available.
- ⚠️ **One test-item correction, evidenced on-device:** `am force-stop` **cancels all `AlarmManager` alarms for the app as a matter of documented Android OS policy** — this applies identically to every Android app, including Google's own Clock, and cannot be worked around from application code (confirmed: force-stopping the app during testing did clear its alarm entries from `dumpsys alarm`). Testing "force-stop → advance 3 days → alarms still fire" would fail on **any** app, so it isn't a meaningful acceptance test for this fix. The scenario that actually matters — and the one real prayer apps must survive — is normal process death without force-stop (backgrounded, OOM-killed, swiped away), which **did** pass. Recovery from an actual force-stop is only possible via the boot/package-replace receivers on next boot, or the user reopening the app — this is already noted in §2.4/Phase 4 (battery-optimization UX) and is standard for this app category.
- **Risk:** medium — this is the ID-scheme change. Ships **after** Phase 1 (as planned).

### Phase 3 — Harden the recovery layer **[Kotlin + manifest]** — 🟡 **CODE + UNIT TESTS COMPLETE, DEVICE VERIFICATION PENDING (2026-09-11)**
- ✅ `MY_PACKAGE_REPLACED` and `LOCKED_BOOT_COMPLETED` were already added to `AzanBootReceiver` during Phase 2 (pulled forward — near-zero incremental cost alongside that rewrite). `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` added this phase: new manifest `<action>` on `AzanBootReceiver`'s existing intent-filter, and the action-matching logic extracted into a pure, testable `AzanBootReceiver.isRecoveryAction()` (was an inline `!=` chain) covering all six recovery actions.
- ✅ `AzanWorker` already used `UPDATE` policy and a 24h cadence (done in Phase 2). What changed this phase: `doWork()` no longer calls `AlarmScheduler.refresh()` unconditionally every cycle — it now calls the new `AlarmScheduler.reconcile()` first (reads the persisted ledger, probes each ID's actual `AlarmManager` state, compares against the persisted horizon-end) and only refreshes on a real mismatch or when the remaining horizon drops below ⅓ of the window (7 of 21 days). The decision logic (`AlarmScheduler.decideNeedsRefresh()`) is a pure function taking `(ledgerSize, missingFromOsCount, horizonRemainingMs)` — fully unit-testable without touching `AlarmManager`.
- ✅ `isAlarmScheduled()` was already fully replaced by the ledger in Phase 2 — nothing left to replace here. What Phase 3 *did* need: the OS-side liveness probe (`isArmedInOs()`) that `reconcile()` uses had to correctly distinguish azan vs. reminder IDs by receiver class, which surfaced a **pre-existing dispatch bug**: `refresh()`'s own stale-cancellation loop (introduced in Phase 2) only ever built its cancellation `PendingIntent` against `AzanAlarmReceiver`, so a stale *reminder* ID was never actually cancelled (silent no-op — wrong-class lookup never matches). Fixed by centralizing dispatch into one `cancelById()`/`isArmedInOs()` pair keyed off `isReminderId()`, used by both `refresh()`'s cancellation loop and `cancelAll()` (the latter had the correct dispatch already, inlined — simplified to share the same helper). The pre-existing `cancelExact`/`cancelReminder` primitives were kept as-is for `sweepLegacyIdsOnce()`, which addresses the old, differently-shaped legacy ID scheme and doesn't fit the new range-based dispatch.
- **Unit tests — ✅ 23/23 passing** (`./gradlew :app:testDebugUnitTest`): 15 in `AlarmSchedulerTest.kt` (7 new this phase: `isReminderId` boundaries, `decideNeedsRefresh` — empty ledger, expired/negative horizon, any mismatch, below/at-threshold boundary, healthy no-op case, the real 7-day default), 8 in new `AzanBootReceiverTest.kt` (all six recovery actions individually, unrelated/null actions rejected, exact set size). All pure-logic — no Robolectric, no device, no emulator.
- **Test — ⏸️ not yet run (device/emulator unavailable this session):** install an APK update over an armed schedule and confirm `MY_PACKAGE_REPLACED` rebuilds it; revoke and re-grant exact-alarm permission from Settings and confirm the new broadcast re-arms without reopening the app; leave the schedule healthy for a full `AzanWorker` cycle and confirm via logcat that it logs "لا حاجة لإعادة الحساب" (no-op) rather than a full refresh every 24h.
- **Risk:** low–medium.

### Phase 4 — Battery-optimization & OEM UX **[Dart + existing Kotlin]** — 🟡 **CODE + UNIT TESTS COMPLETE, COPY PENDING APPROVAL (2026-09-11)**
- ✅ New `BatteryPromptService` (`lib/core/services/battery_prompt_service.dart`): pure decision logic (`shouldPromptPure`, `pickGrantAction`) separated from the I/O wrappers (`shouldPromptNow`, `recordDeclined`, `resolveGrantAction`, `maybeShow`) — same split pattern as `AlarmScheduler`'s Kotlin-side logic this phase.
- ✅ Trigger wired at the actual "user first enables azan" point: `prayer_times_screen.dart`'s per-prayer notification toggle (`toggleNotification`), captured as `isEnabling = !item.isNotificationEnabled` *before* the toggle call, then `BatteryPromptService.instance.maybeShow(context)` *after* — not at app launch, not a blocking dialog. Fires on every OFF→ON toggle; the service's own gating (exemption check + persisted decline cooldown) decides whether anything actually shows.
- ✅ Decline persistence: single `PrefKeys.batteryPromptLastDeclinedAt` timestamp (routed through the same `PrefKeys.guard()` contract as every other key this session). 30-day cooldown, boundary-tested at exactly 30 days (re-prompts) vs. 29 days 23:59:59 (doesn't).
- ✅ OEM routing wired end-to-end: new native `AzanPlugin.kt` handler `"hasStrictOemRestrictions"` → `ManufacturerHelper.hasStrictRestrictions()` (reused, not reimplemented) → new Dart wrapper `AlarmPermissionService.hasStrictOemRestrictions()` → `BatteryPromptService.resolveGrantAction()`. The screen's grant button branches on this: strict-OEM devices (Xiaomi/Vivo/Oppo/Huawei) get `openManufacturerSettings()` (native autostart/protected-apps deep link, itself already falling back internally to generic settings if the OEM-specific intent fails to resolve); everything else gets the direct `requestBatteryExemption()` (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) — deliberately *not* `ManufacturerHelper`'s own internal generic fallback, which opens a list screen (`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`) rather than a direct one-tap grant dialog for this app specifically.
- ✅ **Incidental fix, flagged rather than silent:** the existing manual-steps dialog in `battery_permission_screen.dart` showed a hardcoded, generic 5-step list regardless of device — `ManufacturerHelper.getInstructions()` already had rich, OEM-specific instructions natively but the screen never called the existing `AlarmPermissionService.getManufacturerInstructions()` wrapper. Wired it in, with the old hardcoded text kept only as the empty-result fallback.
- ⚠️ **Arabic copy is DRAFT, not finalized** — every user-facing string in the enhanced `battery_permission_screen.dart` is marked with an inline `// DRAFT` comment pending explicit sign-off (per this phase's request — wording must be shown before finalizing). Feature is fully functional and tested with the draft copy in place; swapping to approved wording is a same-file text-only change.
- ✅ **Resolved (2026-09-11):** the old dialog-based battery/exact-alarm prompt (`AlarmPermissionService.checkAndPromptIfNeeded()`, throttled to once per 6 hours) was retired from its only call site (`prayer_times_screen.dart`'s `initState`) in favor of the single one-time contextual `BatteryPromptService` flow above — the two no longer coexist. `checkAndPromptIfNeeded()` and its underlying permission-check logic were **not deleted** (grepped first: it had exactly one caller, `startPeriodicCheck()`'s hourly-`Timer` wrapper was already dead code with zero callers of its own, and `resetDialogState()` also had zero callers anywhere including tests) — only the call site was removed, so the method remains available if something else needs it later. One side-effect surfaced and accepted: `checkAndPromptIfNeeded()` bundled an exact-alarm-permission dialog together with the battery one (checks either-or, exact-alarm takes priority) — removing the call also drops that friendly in-app explanation. Not a coverage gap, though: `main.dart:198-207` already independently checks and requests `SCHEDULE_EXACT_ALARM` on every launch (no dialog, goes straight to the settings screen) — just a less-explained version of the same permission request.
- **Unit tests — ✅ 8/8 passing** (`flutter test test/battery_prompt_service_test.dart`): the 30-day cooldown boundary (null/never-declined, exactly-30-days, 29-days-23:59:59, custom `cooldownDays`), already-exempted overriding everything, and both branches of OEM-routing. Pure Dart — no widget pump, no mocks.
- **Test — ⏸️ not yet run (device/emulator unavailable this session):** toggle a prayer's azan on for the first time and confirm the screen appears exactly once; decline and confirm it doesn't reappear on a second prayer toggled the same day; fast-forward past 30 days (or back-date the persisted timestamp) and confirm it reappears; grant on a real Xiaomi/Huawei device and confirm the manufacturer-specific settings screen actually opens (vs. the generic dialog on a Pixel/stock device).
- **Risk:** low. Pure UX; `ManufacturerHelper` already existed and needed no changes.

### Phase 5 — Timezone correctness **[Dart]** — ✅ **DONE (2026-09-11)**
- ✅ Added `flutter_timezone: ^5.1.0` (via `flutter pub add`, resolved by pub.dev — not hand-picked).
- ✅ New `TimezoneService` (`lib/core/services/timezone_service.dart`): pure `pickZoneName()` (chooses device name vs. `Africa/Cairo` fallback, no I/O) + `applyZoneWithFallback()` (touches `tz`'s global local-location state, wraps `tz.getLocation()` in try/catch, no platform channel) + `resolveAndApply()` (the real wrapper calling `FlutterTimezone.getLocalTimezone()`). Same pure/impure split used throughout this session.
- ✅ `main.dart`'s startup now calls `TimezoneService.resolveAndApply()` in place of the old `tz_local.setLocalLocation(tz_local.local)` — confirmed by reading `package:timezone/src/env.dart` that `tz.local` is a plain getter that never throws, so the old `catch` branch (the `Africa/Cairo` fallback) was **dead code**, and the app ran on UTC for its entire runtime regardless of device timezone. Removed the now-unused `tz_local` import alias.
- ✅ Re-resolution wired into **two existing hooks, no new one added** (per this phase's explicit constraint): `_AppRootState.didChangeAppLifecycleState`'s existing `_recheckPermissionsAndReschedule()` (fires on every app resume), and the existing `rescheduleFromTimeChange` MethodChannel handler in `main.dart` (the historical Dart-side reaction point for native time/timezone-change signals) — noted in both places that `TimeChangeReceiver`'s Phase 2 rewrite no longer calls the latter directly, but the handler stays correct for any future/other caller.
- **Unit tests — ✅ 11/11 passing** (`flutter test test/timezone_service_test.dart`): `pickZoneName` (valid name, whitespace-trimmed, null→fallback, empty→fallback, whitespace-only→fallback, custom fallback) and `applyZoneWithFallback` (valid IANA name applied as-is and confirmed via `tz.local.name`, unrecognized name falls back to Africa/Cairo *and confirms the fallback was actually applied*, empty string bypassing `pickZoneName` still falls back safely, custom fallback parameter honored, a valid name never touches fallback even when one is supplied). Needs only `tz.initializeTimeZones()` in `setUpAll` — in-memory data, no platform channel, no device.
- **Not tested (accepted, same pattern as every other real I/O wrapper this session):** `resolveAndApply()`'s actual `FlutterTimezone.getLocalTimezone()` platform-channel call itself.
- **Risk:** low.

#### Phase 5 follow-up — one-time reschedule for pre-fix `matchDateTimeComponents` series — ✅ **DONE (2026-09-11)**

A follow-up request asked for a broad one-time reschedule of *every* Dart-side `zonedSchedule` call (iOS azan/reminders, suhoor, iftar) on the assumption that all of them had computed the wrong absolute instant while `tz.local` was UTC. **Verified against actual source before implementing, and that assumption turned out to be false for the vast majority of it:**

- `TZDateTime.from(dt, location)` always derives its absolute instant via `dt.toUtc()` — Dart's own OS-level conversion, independent of `tz.local` entirely (`timezone/src/date_time.dart:219-225`).
- `flutter_local_notifications.zonedSchedule()` transmits `(scheduledDateTime, timeZoneName)` as a self-consistent pair (`tz_datetime_mapper.dart:24-27`), and **both** native implementations reconstruct the absolute instant from that same pair — Android via `ZonedDateTime.of(LocalDateTime.parse(scheduledDateTime), ZoneId.of(timeZoneName))` (`FlutterLocalNotificationsPlugin.java:1345-1347`), iOS via the offset-qualified `scheduledDateTimeISO8601` string (`FlutterLocalNotificationsPlugin.m:814-824`). The round trip recovers the correct instant regardless of what `tz.local` was at construction time.
- **Conclusion: every one-shot `zonedSchedule` call in this codebase (azan, prayer reminders, suhoor, iftar, shurooq) was scheduled at the correct absolute instant even while `tz.local` was UTC.** The pre-fix bug affected *display* correctness (anything reading `.hour`/`.day` off a `TZDateTime`), never scheduling correctness.
- **One real, narrower exception found by grepping every call site:** `notification_service.dart:426`'s `matchDateTimeComponents: DateTimeComponents.time` — a native OS-level daily-repeat mode with no further app involvement after the first arm. Used in exactly one place: `HifzReminderScheduler` (the daily wird/memorization reminder). A series armed *before* the timezone fix, tagged UTC (zero DST), would drift by the DST offset in local wall-clock terms across any subsequent DST transition, until re-armed — genuinely caused by the pre-fix bug, unlike everything else in scope.

Presented this finding to the user before writing code (rather than building a migration whose comments would claim to fix a bug that doesn't exist for most of what it'd touch); user chose the narrow, correctly-scoped fix.

**What shipped:**
- `PrefKeys.timezoneFixRescheduleV1Done` — new persisted flag, same `guard()` contract as every key this session.
- `TimezoneFixRescheduleMigration.run(rescheduleHifzReminder)` (`lib/core/services/timezone_fix_reschedule.dart`): gates a single injected callback to run once. Deliberately diverges from `PrefsMigration`'s "always mark done" pattern — this is one atomic, idempotent operation, so a failure leaves the flag unset and retries on the next launch, rather than being marked done regardless of outcome.
- `HifzNotifier.rescheduleReminderNow()` — new public method reusing the existing `_ref.read(hifzSettingsProvider)` + `HifzScheduler.isWirdMet(...)` + `HifzReminderScheduler.reschedule(...)` pattern already used at three other call sites in `hifz_provider.dart`, rather than duplicating it.
- Wired into `_AppRootState.initState()` (`main.dart`) — the first point in the startup sequence where `ref`/Riverpod is actually available, strictly after `main()`'s top-level `TimezoneService.resolveAndApply()` has already completed (that finishes before `runApp()` even builds this widget). Kept as a distinctly-named, separate step per the original request, not folded into `TimezoneService`.
- **Unit tests — ✅ 5/5 passing** (`flutter test test/timezone_fix_reschedule_test.dart`): first-run invokes and marks done; second run is a no-op; repeated runs after success stay no-op; a failed first attempt does *not* mark done and is retried on the next simulated launch; the migration never lets an internal exception propagate to its caller. Pure Dart with a fake injected callback — no Riverpod/Hive/Kotlin dependency needed.
- Azan/reminder/suhoor/iftar scheduling was **not** touched — re-arming them would not have corrected anything.

### Phase 6 — Dead-code removal **[Kotlin]** — ✅ **DONE (2026-09-11)**
- ✅ Deleted `AzanJobService.kt` entirely + its manifest `<service>` entry. Grepped first per this phase's own instruction: zero live callers anywhere — no `JobScheduler.schedule()`/`JobInfo.Builder` targeting it exists in the codebase (that fallback chain was itself deleted from `AzanAlarmReceiver.kt` back in Phase 2). The only references were the manifest registration and two stale comments (in `AlarmScheduler.kt`'s header and `PrefKeys`'s doc-comment), both corrected to note the deletion.
- ✅ **Reflection-based Fajr path and the duplicated simplified-Fajr methods: already gone.** Grepped for `calculatePreciseFajrTime`, `calculateSimplifiedFajrTime`, `calculateFajrTime`, `scheduleEmergencyFajr`, and any `Class.forName(...adhan...)` reflection call — zero matches anywhere in `android/app/src/main/kotlin/`. These were removed as part of Phase 2's full `AzanWorker.kt` rewrite (688→109 lines); nothing left to delete this phase. Reported rather than silently claimed.
- ✅ Deleted the commented-out `android_alarm_manager_plus` manifest block (`<service>`/`<receiver>` fragments, already inert, never uncommented).
- ✅ `android_alarm_manager_plus`: confirmed zero Dart references anywhere in `lib/` — removed from `pubspec.yaml`. `flutter pub get` confirmed clean resolution and explicitly reported *"These packages are no longer being depended on: - android_alarm_manager_plus 5.0.0."*
- ⚠️ `workmanager`: **not removed** — this phase's own instruction was conditional ("if genuinely unused"), and it isn't: `main.dart:305` still calls `await Workmanager().initialize(callbackDispatcher, isInDebugMode: false)` at startup, even though `callbackDispatcher` is a no-op stub (its body just logs "disabled, AzanWorker handles this"). The *package* is dead weight functionally, but removing it from `pubspec.yaml` without also deleting that live Dart call site and the `callbackDispatcher` function would break compilation — out of scope for a manifest/pubspec-only cleanup pass. Left a comment in `pubspec.yaml` noting why it stays; flagging as a distinct future cleanup candidate rather than silently expanding this phase into a `main.dart` rewrite.
- ✅ **[Dart]** Deleted `PrayerNotificationManager._saveAzanDataForNative()` and all three call sites (`prayer_notification_manager.dart`) — the fuller of the two options the earlier flag left open (delete outright vs. just fix the stale comments); deleting subsumes the comment problem entirely rather than leaving dead-weight code with merely-corrected comments in a phase whose whole point is removing dead weight. Also removed the two imports (`shared_preferences`, `prefs_keys.dart`) that became unused as a result, and one unrelated pre-existing unused import (`prayer_tracking_service.dart`, flagged by the analyzer) noticed in the same file during this same cleanup pass.
- **Unit tests — ✅ 23/23 passing** (`./gradlew :app:testDebugUnitTest`): 15 in `AlarmSchedulerTest`, 8 in `AzanBootReceiverTest` — unchanged from Phase 3, confirming the `AzanJobService.kt` deletion and comment edits didn't break Kotlin compilation.
- **Risk:** low. Pure deletion, done last, after the new path (Phases 1-5) was proven.

### Phase 7 — iOS — ✅ **PART A: DONE · PART B: DONE (2026-09-11)**

**Part A — audio format feasibility → decision → implementation. Done.**
- ✅ Confirmed via web search (Apple developer forums + docs, cited): `UNNotificationSound` accepts only `.aiff`, `.wav`, or `.caf`; `.mp3`/`.m4a` are rejected outright; any accepted file **must be under 30 seconds** or iOS silently falls back to the default system sound.
- ✅ Checked the actual files: `assets/audio/azan_{abdelbaset,mohamed_jazi,nasser_alqatami}.mp3`, 5.6–8.7 MB each — full recitations, 135–261s, far over the 30s cap (confirmed exactly once `ffprobe` became available, below).
- **Decision made:** trim each reciter's file to a short opening excerpt (the opening takbir, ~5s) and use *that* as the `UNNotificationSound` resource. The full recitation remains available in-app only (unchanged) — not part of the notification-sound path.
- ✅ **Tooling:** `ffmpeg` turned out to already be installed on this Windows machine via `scoop` (not detected in the earlier audit pass — re-checked and found at `scoop/shims/ffmpeg`, version 9.0.1). No install step was actually needed.
- ✅ Trimmed all 3 files to exactly 5.000s, PCM `s16le` WAV (44.1kHz stereo) — chosen over `.caf`/`.aiff` since `ffmpeg`'s `.caf` muxer support is unreliable and `.wav` needs no extra muxer; iOS's `UNNotificationSound` accepts `.wav` directly. Verified programmatically via `ffprobe`/`ffmpeg -f null -` (duration, codec, clean decode) for all 3 — not assumed from the trim command's exit code alone.
- ✅ Placed at `ios/Runner/Resources/azan_{abdelbaset,mohamed_jazi,nasser_alqatami}.wav` and registered as Xcode build resources in `project.pbxproj` (`PBXFileReference`/`PBXBuildFile`/`PBXGroup` entries, wired into the Runner target's `PBXResourcesBuildPhase`) — there was no prior precedent for a bundled iOS notification-sound resource in this project (the pre-existing Android-only `notification.mp3` was never actually registered as an iOS resource either; that gap predates this phase and is unrelated to azan).
- ✅ Wired per-reciter into `NotificationService.scheduleIosAzanNotification()` (new `reciterSoundFileName` param → `DarwinNotificationDetails.sound`) and `IosNotificationWindow._scheduleDays()` (new `_resolveReciterSoundFileName()` helper reads the raw `settings_muezzin` pref — same defensive raw-prefs pattern as `_resolveParams`, since this runs from the same headless `BGAppRefreshTask` context — and maps through `kMuezzins`, imported from `settings_provider.dart`, mirroring the existing `core→features` import precedent already used by `prayer_notification_manager.dart`). Mapping: `abdelbaset → azan_abdelbaset.wav`, `mohamed_jazi → azan_mohamed_jazi.wav`, `nasser_alqatami → azan_nasser_alqatami.wav`.
- ✅ **Missing-resource fallback confirmed, not assumed:** read `flutter_local_notifications`' own Obj-C source (`FlutterLocalNotificationsPlugin.m`) — it calls `+[UNNotificationSound soundNamed:]` directly with whatever filename is given; per Apple's documented behavior, an unresolvable resource name falls back to the default notification sound, not a crash or silence. No extra Dart-side handling needed; documented in `notification_service.dart`'s doc comment.
- ⚠️ **Unverified this session (no Mac/Xcode available):** the `project.pbxproj` edits (new `PBXFileReference`/`PBXBuildFile`/`PBXGroup`/`PBXResourcesBuildPhase` entries) were made by hand, following the file's existing patterns exactly, but have **not** been opened in Xcode or built — whether the 3 `.wav` files actually get bundled into the `.app` correctly (vs. a typo'd object ID, a malformed group reference, etc.) is unverified. Flagged alongside Part B's `BGAppRefreshTask` device-verification gap below — together these are the two remaining unverified pieces of Phase 7 as a whole; both require a Mac, which this session did not have.

**Part B — rolling notification window. Implemented, code + tests complete.**
- ✅ **Window-size math** (shown in full in `ios_notification_window.dart`'s header comment): per day, iOS needs 5 azan + 1 shurooq + 5 reminders = **11 notifications/day**. Reserved (constant, not multiplied by window size): 1 suhoor + 1 iftar (single always-refreshed slots, not accumulated) + 1 hifz wird reminder (a `matchDateTimeComponents` repeating request counts as one against the 64-cap regardless of repeat count, per Phase 5's research) = **3**. Chose **N = 5 days**: `11×5 + 3 = 58`, a 6-slot (~9%) margin under the 64 cap — deliberately not maxed to the theoretical ceiling (`N=6` would be 69, over the cap). Top-up threshold: 2 days remaining.
- ✅ `IosNotificationWindow` (`lib/core/services/ios_notification_window.dart`): pure `decideTopUp()` (same pure/impure split as every other phase this session) + a real wrapper that reads the ledger (`PrefKeys.iosWindowScheduledThroughDate`) and location/settings directly from raw `SharedPreferences` — deliberately not `LocationService.instance`/Riverpod, since this must run from a **headless background context** (no live widget tree), the same constraint that shaped `AlarmScheduler.kt`'s design on Android. Absolute date-derived IDs (`idFor`, disjoint `2,000,000+` range) — same reasoning as Android's Phase 2 fix (§1.11): an ID must always mean the same instant.
- 🐛 **Duplicate-scheduling bug found and fixed before it shipped, not after** (same class of bug Phase 2 found and fixed for Android): the existing foreground-triggered `_scheduleAllNotifications()` was *still* scheduling today's iOS azan/reminder/shurooq independently, under the old low-ID scheme — running in parallel with the new rolling window would have double-scheduled every prayer on iOS, exactly like the Android bug. Fixed by making `UnifiedAzanService.scheduleAzan()`/`scheduleShurooqNotification()`'s iOS branches no-ops (mirroring the existing Android no-op pattern verbatim) and excluding iOS from the reminder call site's platform gate in `prayer_notification_manager.dart`. The actual scheduling bodies were *moved*, not deleted — now live as `NotificationService.scheduleIosAzanNotification()`/`scheduleIosShurooqNotification()`, called only by `IosNotificationWindow`.
- ✅ **`BGAppRefreshTask` wired by reusing existing infrastructure, not hand-rolled.** Investigated first: `workmanager` (kept as a live dependency per Phase 6's finding — `main.dart` still calls `Workmanager().initialize()`) ships real iOS support (`SwiftWorkmanagerPlugin.swift`) that already implements exactly this pattern — `registerPeriodicTask` maps to `BGAppRefreshTaskRequest`/`BGAppRefreshTask`, and its handler already re-submits itself on every firing (self-perpetuating, avoiding the exact "who re-arms the next one" failure mode this whole plan started from). Confirmed by reading the plugin's Swift source directly (not assumed) that the *handler registration* (`BGTaskScheduler.shared.register`) must happen natively at launch — Apple requires this complete before `didFinishLaunchingWithOptions` returns, and the Dart-side call cannot do it (it only *submits* a request against an already-registered identifier). Implemented accordingly:
  - `AppDelegate.swift`: calls `SwiftWorkmanagerPlugin.registerPeriodicTask(withIdentifier:frequency:)` directly, at launch, with a 12-hour frequency (the real, effective recurrence — the Dart-side `frequency` parameter is not read by this native code path, confirmed by reading it; only `initialDelaySeconds` is).
  - `Info.plist`: added the required `BGTaskSchedulerPermittedIdentifiers` array entry. `UIBackgroundModes` already had `fetch` (needed for `BGAppRefreshTask`) — no change needed there.
  - `main.dart`: `callbackDispatcher()` now branches — Android keeps its existing no-op (`AzanWorker` handles it, per Phase 6), iOS calls `IosNotificationWindow.topUpIfNeeded()`. `registerBackgroundTask()` + an immediate `topUpIfNeeded()` call added to `_AppRootState.initState()`, iOS-gated internally.
  - **Explicitly accepted, not glossed over:** `BGAppRefreshTaskRequest.earliestBeginDate` is a floor, not a guarantee — iOS decides opportunistically whether/when to actually run it, and commonly runs it much later than requested or not at all for days if the app isn't opened. This is supplementary self-healing, exactly like Android's `AzanWorker` 24h audit — the *primary* reliability mechanism is the 5-day buffer itself, scheduled whenever the app **is** opened.
- **Unit tests — ✅ 16/16 passing** (`flutter test test/ios_notification_window_test.dart`): the full `decideTopUp` boundary set (empty/negative→full top-up, exactly-at-threshold→tops up, one-above-threshold→doesn't, full/over-full window→doesn't, custom `targetDays`/`thresholdDays`/`perDayCount`), the window-math constants asserted directly (`58 < 64`, margin ≥ 5), and `idFor` (distinct across dates, distinct across prayer indices on the same date, deterministic, time-of-day-independent, correctly disjoint from both other ID ranges). Pure Dart, no platform channel.
- **Not verified this session (no device/simulator):** whether the `BGAppRefreshTask` actually fires on a real device, whether the headless Flutter engine invocation works end-to-end, whether the native Swift registration compiles/links correctly in a real Xcode build. Written correctly per the plugin's own documented contract and verified by reading its source, but genuinely unverified beyond that — flagged plainly rather than claimed as tested. **Same root constraint (no Mac) as Part A's unverified `project.pbxproj` resource registration above — together, these are the two remaining unverified pieces of Phase 7.**
- **Full verification:** `flutter analyze lib/ test/` → 0 errors (no new issues in any touched file). `flutter test` → **100/100 passed** (84 prior + 16 new). Part A's later audio-trim work: `flutter analyze` clean on touched files, `flutter test` 104/105→106/106 after an unrelated pre-existing Hifz-toast test bug (found and fixed the same day, see repo history) — no azan-related test regressions.
- **Risk:** Part A — low; asset processing + Dart wiring only, both platform-verifiable pieces (durations, PCM validity, Dart-side fallback behavior) confirmed programmatically — only the Xcode-level bundling step is unverified. Part B — medium; the scheduling logic is solid and tested, but the BGAppRefreshTask wiring is unverified on-device by necessity of this session's constraints.

### Phase 8 — Verification surface **[Dart]** — ✅ **DONE (2026-09-11)**
- ✅ Extended `system_diagnostics_service.dart` (per this plan's own Part 3.3 placement) with a read-only data layer: `AzanHealthSnapshot` (immutable), pure `classifyHorizonHealth()` (healthy/shrinking/critical/unknown — same ⅓-of-window philosophy as `AlarmScheduler.decideNeedsRefresh()`/`IosNotificationWindow.decideTopUp()`, `now` passed explicitly for determinism, same pattern as `TimezoneService`/`BatteryPromptService`), pure `formatRelativeTimeLabel()`, pure `parseEpochMsString()`, and the real I/O wrapper `loadAzanHealthSnapshot()`.
- ✅ **No new platform-channel plumbing needed for the ledger/horizon/last-refresh data** — `AlarmScheduler.kt` already persists these as plain, correctly single-`flutter.`-prefixed `SharedPreferences` strings (`azan_armed_ids`, `azan_last_refresh_at`, `azan_horizon_end_at`); Dart reads them directly via the existing `shared_preferences` plugin, now exposed as `PrefKeys.azanArmedIds`/`azanLastRefreshAt`/`azanHorizonEndAt`. iOS horizon reuses the existing `PrefKeys.iosWindowScheduledThroughDate` from Phase 7B verbatim. Permission states reuse the existing `AzanPlugin` channel methods (`hasExactAlarmPermission`, `isBatteryOptimizationDisabled`) and `NotificationPermissionService.hasPermission()` — same channel/pattern `system_diagnostics_service.dart`'s pre-existing `_testPermissions()` already used.
- ✅ **"Last azan fired" was genuinely not tracked anywhere** (grepped first, confirmed zero matches) — added the minimal write-point on both platforms, per this phase's explicit instruction:
  - **Android:** `AzanAlarmReceiver.kt`, at the actual firing point (after the staleness guard passes, before dispatching to `AzanForegroundService`/`AdhanActivity` — the one place that unconditionally means "an azan is really about to play now"). Writes `flutter.azan_last_fired_at`/`_prayer` to raw `SharedPreferences`, matching this file's existing raw-write convention.
  - **iOS:** no equivalent unconditional native hook exists for a *delivered* local notification while the app is backgrounded/terminated (would require a separate Notification Service Extension — out of scope for a read-only diagnostics phase). Implemented the closest available real signal instead: `NotificationService`'s `onDidReceiveNotificationResponse` (fires on notification tap, including from a terminated app) now persists last-fired when the response payload carries the new `azan_fired:` prefix tag added to `scheduleIosAzanNotification()`'s `zonedSchedule` call. **Flagged plainly, not glossed over** — both in the code comment and directly in the diagnostics screen itself: this is "last azan *tapped*," not "last azan *delivered*," on iOS specifically; Android's value is exact.
- ✅ New screen: `lib/features/diagnostics/screens/azan_diagnostics_screen.dart` — no existing screen in this codebase already fit (the pre-existing `system_diagnostics_service.dart`/`SystemDiagnosticsService` had zero callers/screen anywhere; `LogsScreen` similarly exists but isn't wired into navigation; neither is a dashboard of current state — they're pass/fail functional self-tests, a different shape than what this phase asked for). Wired into `settings_screen.dart` as a new nav entry (`_buildAzanDiagnosticsButton()`), following the exact existing `_buildAppGuideButton()`/`_buildPrivacyPolicyButton()` pattern in that file. Read-only: a `FutureBuilder` over `loadAzanHealthSnapshot()`, a color-coded horizon-health card, and per-platform sections (Android shows armed count + last refresh; iOS section explains the horizon-only view and the tap-vs-delivered caveat above). Accepts an injectable `snapshotLoader` for testability without mocking `SharedPreferences`/`MethodChannel`.
- **Unit tests — ✅ 22/22 passing** (`flutter test test/azan_diagnostics_test.dart`): `classifyHorizonHealth` (null→unknown, past/exactly-now→critical boundary, one-minute-under-threshold→shrinking boundary, exactly-at-threshold→healthy boundary, well-past→healthy, Android's 7-day vs. iOS's 2-day threshold producing different results for the *same* horizon date), `formatRelativeTimeLabel` (null + custom label, sub-minute→"now", future/clock-skew→"now" not a crash, minute/hour/day boundaries), `parseEpochMsString` (null/empty/non-numeric/zero/negative all→null safely, valid round-trip), `AzanHealthSnapshot.horizonHealth()` delegation, `allPermissionsOk` (all-granted vs. one-missing), iOS snapshot leaving Android-only fields `null` without issue. All pure Dart, `now` injected explicitly — no I/O, no platform channel, no widget pump.
- **Widget tests — ✅ 7/7 passing** (`flutter test test/azan_diagnostics_screen_test.dart`): all four horizon-health states render their correct label/color, Android-only rows hidden on iOS (with the tap-vs-delivered caveat text visible instead), last-fired prayer name renders, and a throwing loader shows an error message instead of crashing — via the injected `snapshotLoader`, no real `SharedPreferences`/`MethodChannel` involved.
- **Full verification:** `flutter analyze` → 0 new issues in any touched file. `flutter test` → see full-suite count below.
- **Not verified this session (no device):** the two new native write-points (`AzanAlarmReceiver.kt`'s `SharedPreferences` write, and the `flutter_local_notifications` iOS tap-payload round-trip) compile correctly per Kotlin/Dart syntax review but weren't exercised on a real firing alarm/notification — consistent with every other native change this session under the same device-unavailable constraint.
- **Risk:** none — read-only surfacing, zero new scheduling logic, as scoped.

---

## Part 5 — Open questions — **I need your decision before implementation**

**Q1 — Scheduling horizon?** My recommendation: **30 days of azan alarms (180) + 30 days of reminders (150) = 330 alarms**, refreshed when coverage drops below 10 days. That is well under the 500/UID ceiling but leaves limited headroom. A more conservative **21 days (126 + 105 = 231)** halves the risk and still means the app can go three weeks untouched. **Which do you want — 21 or 30 days?**

**Q2 — Battery-optimization prompt: show it, and with what wording?** It is currently commented out. My recommendation: show it **once**, right after the user first enables azan (not at first launch — the user has no context yet). I can draft Arabic copy for your review, or you can supply it. **Should I add the prompt, and do you want to write the wording or review mine?**

**Q3 — Reminders (15 min before): native or Flutter?** Currently Android reminders are native-only and iOS uses `flutter_local_notifications`. Keeping them native doubles the alarm count. **Keep native (simpler, consistent) or move Android reminders to `flutter_local_notifications` to halve alarm usage?** I lean native.

**Q4 — Is iOS in scope?** iOS azan is currently disabled outright (wrong audio format) and has no long-horizon strategy. Fixing it properly means asset conversion plus a rolling-window scheduler plus `BGAppRefreshTask` — a substantial piece of work. **Android-only for now (Phases 1–6, 8), or include Phase 7?**

**Q5 — Migration aggressiveness.** Existing installs have poisoned `flutter.flutter.*` keys. **Silent migration (my recommendation), or also a one-time "please reopen once to upgrade your prayer schedule" notice?**

**Q6 — Phase 1 as an immediate hotfix?** Phase 1 is Dart-only, low-risk, and should by itself restore most of the missing reliability by reviving the existing native engine. **Do you want it shipped as a standalone hotfix release before the rest of the work, or should everything land together?**

---

## Sources

- [Schedule alarms — Android Developers](https://developer.android.com/develop/background-work/services/alarms/schedule)
- [Optimize for Doze and App Standby — Android Developers](https://developer.android.com/training/monitoring-device-state/doze-standby)
- [Implicit broadcast exceptions — Android Developers](https://developer.android.com/develop/background-work/background-tasks/broadcasts/broadcast-exceptions)
- [Restrictions on starting activities from the background — Android Developers](https://developer.android.com/guide/components/activities/background-starts)
- [Schedule exact alarms are denied by default (Android 14) — Android Developers](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)
- [Maximum limit of concurrent alarms 500 reached for uid — eclipse-paho/paho.mqtt.android#468](https://github.com/eclipse-paho/paho.mqtt.android/issues/468)
- [iOS pending notification limit — MaikuB/flutter_local_notifications#2312](https://github.com/MaikuB/flutter_local_notifications/issues/2312)
- [Does UNNotificationRequest have a 64-notification scheduling limit? — Apple Developer Forums](https://developer.apple.com/forums/thread/811171)
- [How Does WorkManager Guarantee Task Execution?](https://outcomeschool.substack.com/p/how-does-workmanager-guarantee-task)
- [Don't kill my app! — OEM background-restriction survey](https://www.malaymail.com/news/tech/gadgets/2019/01/14/does-your-smartphone-kill-important-apps-here-are-the-top-offenders-and-how/1712481)
- Local source of record: `shared_preferences-2.5.5/lib/src/shared_preferences_legacy.dart:22,172` (the `flutter.` prefix)
