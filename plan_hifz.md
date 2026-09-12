# خطة نظام حفظ القرآن (Hifz Tracking System) — Phase 0

> **Status:** Analysis & planning only. No implementation code is written in this phase.
> **Scope:** A full Quran memorization tracking system, page-granular (604 pages), with an
> escalating spaced-review engine and a **freely user-configurable daily wird target**.
> **Guiding constraint:** This system is **independent** of `QuranProgressService` /
> `quranProgressProvider` (which track *reading* / ختمة). Memorization is a separate,
> stateful, per-page domain and gets its own data model, service, providers and feature folder.

---

## 0. Codebase facts established during investigation

| Area | File | Key facts |
|---|---|---|
| Quran home header | `lib/features/quran/screens/quran_home_screen.dart` | `_buildAppBar` (L105–218) is **one `Row`**: back button → **ختم القرآن pill** (L130–166) → `Spacer` → title `القرآن الكريم` (L169–177) → `Spacer` → **reciter pill** (L180–214). `_buildTabBar` (L221–253) is the segmented **السور / الأجزاء** control. `build` Column (L76–97): `_buildAppBar`, `_buildTabBar`, `Expanded(TabBarView)`. `TabController(length: 2)` (L37). |
| Reading-progress storage | `lib/core/services/quran_progress_service.dart` | Static class. `init()` opens a raw Hive `Box` (`quran_progress_box`). Stores `List<int>` (read surahs/juz), `int` (khatmah count), ISO‑8601 `String` (dates). No Hive adapters. |
| Last-read storage | `lib/core/services/last_read_service.dart` | Same pattern. Box `quran_last_read_box`. Stores a **`Map<String,dynamic>`** via `LastReadPosition.toMap()`; a `Map<int,int>` persisted with **stringified int keys**; `fromMap` does **defensive parsing** and returns `null` on corrupt data. Model fields: `surahNumber, ayahNumber, pageNumber, juzNumber, updatedAt`. |
| Providers | `lib/features/quran/providers/quran_progress_provider.dart`, `.../last_read_provider.dart` | `StateNotifierProvider<XNotifier, XState>`; immutable state class + `copyWith`; `_load()` in constructor; notifier method → service write → `state = state.copyWith(...)`. |
| Service init | `lib/main.dart` L269–276 | `await Future.wait([ QuranProgressService.init(), LastReadService.init(), PrayerTrackingService.init(), ... ])` after `Hive.initFlutter()` (L250). |
| Page metadata | `lib/core/data/quran_page_data.dart` | `QuranPageData.ayahPageInfo : Map<int surah, Map<int ayah, AyahPageInfo>>`, **complete for all 114 surahs**. `AyahPageInfo { int page /*1–604*/, int juz /*1–30*/, int hizb /*1–60*/, int hizbQuarter /*1–240*/ }`. Helper `getAyahInfo(s, a)`. Source: Madani mushaf (alquran.cloud). |
| Juz ↔ page alignment | verified at juz 1/2 boundary | In this dataset **juz boundaries are snapped to page starts** (2:141 = page 21 / juz 1; 2:142 = page 22 / juz 2). ⇒ every page maps to **exactly one** juz. ~20.13 pages/juz. `hizbQuarter` (1–240) = 8 quarter‑hizbs per juz — the natural "ربع حزب" review unit. |
| Ayah/juz data loading | `lib/core/services/local_quran_service.dart`, `offline_quran_service.dart` | `getSurahAyahs(s)` returns `List<LocalAyah>` each carrying `pageNumber/juzNumber/hizbNumber` (derived from `QuranPageData`). `getJuzSections(j)` from `JuzData.juzContent` (`JuzSection { surahNumber, surahName, fromAyah, toAyah, page }`). |
| Surah metadata | `lib/core/services/quran_service.dart` | `QuranDataService.surahs : List<SurahInfo(number, name, nameEn, ayahCount, juz, page, type)>` (const, all 114). `juzNames : List<String>` (30). `surahById(id)`. |
| Reader entry | `lib/features/quran/screens/quran_reader_screen.dart` | `ModernQuranReaderV2({ required int surahNumber, int? initialAyah })` (L24–32). `initialAyah` → `_scrollToAyah` via `addPostFrameCallback` (L130–134). Selection state `_selStart/_selEnd`; audio via epoch‑guarded `_startPlayback`/`_playAyahRange`/`_stopPlayback` (L413/520/621). Reader currently returns **no result** to its caller. |
| Reuse idioms | reader + khatmah screens | Toast: `_showToast` (L1304) — bg `Color(0xFF1A1535)`, floating, radius 12, goldWarm 0.4 border ("نفس نمط تم النسخ"). Error snackbar: `_showErrorMessage` (L1279) — goldWarm bg. Bottom sheet: `showModalBottomSheet` bg `AppColors.nightCard`, `RoundedRectangleBorder(vertical top 20.r, side borderGold)`, drag handle 40×4 rounded (`quran_home` L387–398, 417–424). Dialog: `AlertDialog` bg `nightMid`, radius 16.r, goldWarm 0.3 border, TextButton + ElevatedButton (`khatmah` L48–115). Stat tiles: `_StatItem` (`khatmah` L288–334). Staggered list: `RevealAnimation(delay: Duration(milliseconds: i*30))`. Shared card: `lib/shared/widgets/gold_card.dart` (`GoldCard`). |
| Settings persistence | `lib/features/settings/providers/settings_provider.dart` | `SettingsNotifier extends StateNotifier<SettingsState>`, persisted via **`SharedPreferences`** (`getDouble/getInt/getBool` + defaults). |
| Feature-folder convention | `lib/features/<name>/{models,providers,screens,widgets}` | e.g. `prayer/`, `dua/`, `tasbih/`. Cross-cutting services live in `lib/core/services/`. Data tables live in `lib/core/data/`. |
| Design tokens | `lib/core/theme/app_colors.dart` | `nightDeep #08061A`, `nightMid #130F2A`, `nightSurface #1C1535`, `nightCard #221A40`; `goldWarm #C8922A`, `goldLight #F0C060`, `goldGlow #FFD97D`, `goldDim #8B6520`; `borderGold #40C8922A`, `borderGoldStrong #99C8922A`; `textPrimary #F5E6CC`, `textDim #9B8A6E`, `agedPlaster #E8D5B0`; mushaf: `mushafPaper #F8F5EE`, `mushafInk #2C2418`, `mushafBorder #D4C8B0`. Sizing via `flutter_screenutil` (`.w .h .r .sp`). Fonts: `Tajawal` (UI), `NotoNaskhArabic` (headings/surah names), `Amiri` (ayah body). |

---

## 1. Header restructure (`quran_home_screen.dart`)

### 1.1 Current widget tree (exact)

```
build() Column                                     // L76–97
 ├─ _buildAppBar(context, sheikh)                   // L105–218  — ONE Row
 │   ├─ GestureDetector → back button (36.r circle) // L111–127
 │   ├─ SizedBox(width: 8.w)                        // L128
 │   ├─ GestureDetector → "ختم القرآن" pill         // L130–166  ← MOVE to row 2
 │   ├─ Spacer()                                    // L167
 │   ├─ Text("القرآن الكريم")                        // L169–177  (identity)
 │   ├─ Spacer()                                    // L178
 │   └─ GestureDetector → reciter pill              // L180–214  (identity)
 ├─ _buildTabBar()                                  // L221–253  — السور / الأجزاء segmented
 └─ Expanded(TabBarView(controller: _tabs, ...))    // L85–95
```

### 1.2 Target: three single-purpose rows

```
build() Column
 ├─ _buildIdentityRow(context, sheikh)   // NEW name / trimmed _buildAppBar
 │     [back button] ....... Text("القرآن الكريم") ....... [reciter pill]
 ├─ _buildNavRow(context)                // NEW — two PLAIN-TEXT nav buttons, tab-style pill chrome
 │     ┌───────────────── segmented container (copy of _buildTabBar shell) ─────────────────┐
 │     │      "ختم القرآن"            │            "الحفظ"                                    │
 │     └────────────────────────────────────────────────────────────────────────────────────┘
 ├─ _buildTabBar()                       // UNCHANGED — السور / الأجزاء view-toggle
 └─ Expanded(TabBarView(...))            // UNCHANGED
```

### 1.3 What moves / what is reused — precise

**Row 1 — `_buildIdentityRow` (edit `_buildAppBar` in place):**
- **Keep** back button (L111–127) as leading. *(Open question 1 — see §7; recommend it stays here: it is app‑chrome navigation, not a semantic section entry point like the row‑2 buttons.)*
- **Delete** the `SizedBox(width: 8.w)` at L128 and the entire **ختم القرآن `GestureDetector`** at L130–166.
- **Keep** `Spacer` / title (L169–177) / `Spacer` / reciter pill (L180–214) verbatim — no style change.
- Net effect: `[back] — spacer — القرآن الكريم — spacer — [reciter pill]`, visually balanced.

**Row 2 — `_buildNavRow` (new method):** must use the **exact chrome of `_buildTabBar`** (L221–253), *not* the old pill chrome, per the confirmed decision:

| Token | Source (verbatim) |
|---|---|
| Outer container | `margin: EdgeInsets.symmetric(horizontal: 16.w)`, `height: 38.h`, `decoration: BoxDecoration(color: AppColors.nightCard, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.borderGold, width: 1.0))` — copied from `_buildTabBar` L222–229 |
| Row contents | Two `Expanded` children, each a `GestureDetector`/`InkWell` wrapping a `Center(child: Text(...))`. A `1`‑wide `VerticalDivider`/`Container` in `AppColors.borderGold` between them (mirrors the segmented look). |
| Label text style | `TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp, fontWeight: FontWeight.w600)`, color `AppColors.goldLight` — copied from `_buildTabBar` `labelStyle` + `labelColor` (L239–245). **No icons.** |
| Pressed feedback | Optional: on tap, briefly paint the tapped half with the tab indicator decoration (`color: AppColors.goldWarm.withValues(alpha: 0.20)`, `borderRadius: 20.r`, `border: AppColors.borderGoldStrong`) — from `_buildTabBar` `indicator` (L232–236). Not required; these are navigation, so a plain splash is acceptable. |
| Spacing above/below | `SizedBox(height: 8.h)` between rows (match existing vertical rhythm around `_buildTabBar`). |

Row‑2 button actions:
- **"ختم القرآن"** → `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KhatmahTrackingScreen()))` — the exact call currently at L131–137, relocated.
- **"الحفظ"** → `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HifzDashboardScreen()))` — new import `lib/features/hifz/screens/hifz_dashboard_screen.dart`.

**Row 3 — `_buildTabBar`:** untouched. (Note: current `tabs` order is `['السور','الأجزاء']` with `TabController` index 0 = السور. Leave as‑is unless a separate task asks to flip it.)

### 1.4 Files touched in Phase 1 for the header
- `lib/features/quran/screens/quran_home_screen.dart` — rename/trim `_buildAppBar`→`_buildIdentityRow`; add `_buildNavRow`; update `build()` Column; add `HifzDashboardScreen` import.
- No new style tokens. No new widgets required (row 2 is ~30 lines inline, matching how `_buildTabBar` is inline).

---

## 2. Data model

### 2.1 Enums (`lib/features/hifz/models/hifz_models.dart`)

```
enum HifzStage    { notStarted, newlyMemorized, underReview, mastered }
enum HifzGrade    { weak, medium, strong }          // self-assessment after a review
enum HifzPortionUnit { page, quarterHizb, halfHizb, hizb }   // wird display unit
enum HifzStartPreference { fromFatihah, fromJuzAmma, custom } // "New Memorization" ordering hint
```
Serialization rule (matches existing services): **enums → `.name` string**, **`DateTime` → `toIso8601String()`**, maps keyed by **stringified int**. Every `fromMap` is defensive (unknown/absent → sensible default, never throws) — copy the `LastReadPosition.fromMap` style.

### 2.2 Per-page state — `HifzPageState`

| Field | Type | Meaning | Persisted? |
|---|---|---|---|
| `page` | `int` (1–604) | key | yes (also map key) |
| `stage` | `HifzStage` | current stage | yes |
| `firstMemorizedAt` | `DateTime?` | date first marked memorized — **never mutated after set** | yes |
| `lastReviewedAt` | `DateTime?` | last review completion | yes |
| `reviewCount` | `int` | total reviews ever | yes |
| `lastGrade` | `HifzGrade?` | most recent self-assessment | yes |
| `consecutiveStrong` | `int` | consecutive `strong` grades since last non-strong — drives promotion & weak‑recovery | yes |
| `stageEnteredAt` | `DateTime?` | when current `stage` began — drives the newly‑memorized window | yes |
| `farCyclesSurvived` | `int` | completed far-review cycles with no `weak` — drives `underReview → mastered` | yes |
| `priorityUntil` | `DateTime?` | if set & in the future, page is force-included in the near queue (weak‑grade recovery) | yes |

**Derived, never persisted:** `juz` (`HifzPageIndex.juzOfPage`), `quarter` (1–240), `firstAyah` (surah+ayah), `isDueToday` (computed by the scheduler). No `nextDueAt` is stored — see §3.4.

**Storage shape** (Hive box `hifz_box`, key `pages`):
```
Map<String /*page number*/, Map<String,dynamic> /*HifzPageState.toMap()*/>
```
Sparse — only pages with `stage != notStarted` are written (like `read_surahs`). Absent key ⇒ `notStarted`. Mirrors `LastReadService`'s "Map persisted with stringified int keys".

### 2.3 Settings — `HifzSettings` (Hive box `hifz_box`, key `settings`)

| Field | Type | Default | Meaning |
|---|---|---|---|
| `newPortionUnit` | `HifzPortionUnit` | `page` | display unit for the **new-memorization** wird |
| `newPortionCount` | `double` | `1` | how many units/day of **new** memorization (e.g. `1 page`, `0.5 hizb`) |
| `reviewPortionUnit` | `HifzPortionUnit` | `quarterHizb` | display unit for the **far-review** wird |
| `reviewPortionCount` | `double` | `1` | far-review units/day (auto-escalates — see §3.3; user can override at any time) |
| `autoEscalateReview` | `bool` | `true` | allow the engine to grow `reviewPortionCount` over successful cycles |
| `reviewPortionMaxUnit` | `HifzPortionUnit` | `hizb` | ceiling for auto-escalation |
| `newlyMemorizedWindowDays` | `int` | `14` | min days a page stays in the near queue before it may promote |
| `promoteAfterConsecutiveStrong` | `int` | `7` | consecutive `strong` grades needed to promote `newlyMemorized → underReview` |
| `masterAfterFarCycles` | `int` | `3` | clean far-cycles needed for `underReview → mastered` |
| `weakRecoveryDays` | `int` | `3` | how long a `weak`-graded page is force-pinned to the near queue |
| `startPreference` | `HifzStartPreference` | `fromFatihah` | ordering hint for the New-Memorization picker only |
| `restWeekdays` | `List<int>` | `[]` | weekday numbers with no *new* wird (review continues) |
| `countReviewTowardWird` | `bool` | `true` | does completing the review portion satisfy "today's wird" for the streak? |
| `countNewTowardWird` | `bool` | `true` | does new memorization satisfy it? |
| `schemaVersion` | `int` | `1` | migration guard |

Unit → pages conversion is **computed live** from `HifzPageIndex`, not hard-coded:
`page` = 1 page; `quarterHizb` = the set of pages sharing one `hizbQuarter` (~2–3 pages); `halfHizb` = one `hizb` value (~5 pages); `hizb` = two consecutive `hizb` values / one full juz-eighth… (exact page lists come from the index, so "half a hizb" is always a precise, mushaf-correct page set, never a rounded guess).

### 2.4 Review-session log — `HifzReviewSession` (Hive box `hifz_box`, key `sessions`)

Append-only `List<Map<String,dynamic>>`; each entry:
`{ date, kind: 'near'|'far'|'new', pages: List<int>, grades: Map<pageStr, gradeName>, durationSec? }`.
Used by the Statistics screen (§4.5). Cap at e.g. last 400 entries (trim oldest) to bound box size.

### 2.5 Meta / streak — `HifzMeta` (Hive box `hifz_box`, key `meta`)

| Field | Type | Meaning |
|---|---|---|
| `createdAt` | `DateTime` | first use |
| `farReviewCursor` | `int` (1–604) | ring pointer: where the next far-review session resumes |
| `farCycleCount` | `int` | completed full passes of the memorized corpus |
| `lastCycleAvgGrade` | `double` | mean grade of the last completed cycle (0..2) — drives escalate/de-escalate |
| `lastActivityDate` | `DateTime?` | last day any wird action happened |
| `currentStreak` / `longestStreak` | `int` | consecutive‑day streaks |
| `todayNewPages` / `todayReviewPages` | `int` | today's counters (reset when date rolls over) |
| `doneToday` | `List<int>` | page numbers already reviewed today (prevents a page showing twice/day) |
| `schemaVersion` | `int` | migration guard |

### 2.6 Why the model is not merged with `QuranProgressService`
`quran_progress_box` stores binary `Set<int>` checkboxes + a khatmah counter. Memorization needs per‑page **stage machine + 8 mutable fields + dated history + a scheduling cursor + a session log**. Different lifecycle, different write frequency, different reset semantics ("new khatmah" wipes reading progress; memorization is never wiped). Separate box + service keeps both simple and prevents an accidental `startNewKhatmah()` from nuking years of hifz history.

---

## 3. Review-scheduling algorithm

All logic lives in a **pure** module `lib/features/hifz/logic/hifz_scheduler.dart` (no Hive, no Riverpod — trivially unit-testable). Inputs: `Map<int,HifzPageState> pages`, `HifzSettings settings`, `HifzMeta meta`, `DateTime today`, `HifzPageIndex index`. Outputs: new immutable copies + a `TodayQueue`.

### 3.1 `TodayQueue` = near ∪ far, de-duplicated

```
class TodayQueue {
  List<HifzQueueItem> near;   // تثبيت — newly memorized + weak-recovery pins
  List<HifzQueueItem> far;    // مراجعة دورية — cyclical sweep of the memorized corpus
}
class HifzQueueItem { int page; HifzQueueKind kind; String subtitle; /* juz, surah range */ }
```

### 3.2 Near queue (تثبيت)

Include a page iff **not** in `meta.doneToday` AND (
`stage == newlyMemorized`  **OR**  `priorityUntil != null && priorityUntil >= today`
).

On grading a near-queue page:
- **strong** → `consecutiveStrong++`, `lastGrade = strong`, `reviewCount++`, `lastReviewedAt = today`, append to `doneToday`.
  Promotion test: if `stage == newlyMemorized` AND `consecutiveStrong >= settings.promoteAfterConsecutiveStrong` AND `today - stageEnteredAt >= settings.newlyMemorizedWindowDays` →
  `stage = underReview`, `stageEnteredAt = today`, `consecutiveStrong = 0`, `farCyclesSurvived = 0`.
  Also clear `priorityUntil` if the pin has expired.
- **medium** → `consecutiveStrong = 0`; otherwise same bookkeeping; stays in stage.
- **weak** → `consecutiveStrong = 0`; `priorityUntil = today + settings.weakRecoveryDays`; stays in stage; still counts as reviewed today.

### 3.3 Far queue (مراجعة دورية) — escalating cyclical sweep

Corpus = all pages with `stage ∈ {underReview, mastered}`, in **mushaf order**.
`meta.farReviewCursor` points at the next unreviewed page.

**Each day:**
1. `quota = pagesForPortion(settings.reviewPortionUnit, settings.reviewPortionCount, index)` — a precise page count from the index (e.g. `quarterHizb × 1 ≈ 2–3` pages; `hizb × 2 ≈ 10` pages).
2. Walk the corpus ring from `farReviewCursor`, take the next `quota` corpus pages **not already in `doneToday`**, emit them as `far` items.
3. When the user grades them, advance `farReviewCursor` past the last graded page. If the walk wraps past page 604 back to the corpus start → **cycle complete**: `farCycleCount++`, compute `lastCycleAvgGrade`, run **escalation**:
   - if `settings.autoEscalateReview` AND `lastCycleAvgGrade >= 1.6` (≈ mostly strong) AND current unit `< reviewPortionMaxUnit` →
     bump one step: `page → quarterHizb → halfHizb → hizb`, or if already at `hizb`, `reviewPortionCount += 1` (2 hizb, 3 hizb…). This is the traditional "shorten the full-review cycle from months toward weeks by growing the daily quantity".
   - if `lastCycleAvgGrade < 0.8` (≈ mostly weak/medium) → step **down** one level (never below `quarterHizb × 1`).
   - user-set values are respected: escalation only ever *raises toward* `reviewPortionMaxUnit`; the user may lower unit/count or set `autoEscalateReview = false` at any time.

**Per-page effects of a far-review grade:**
- **strong** → `reviewCount++`, `lastReviewedAt`, `consecutiveStrong++`, `lastGrade`. On cycle completion, pages graded ≥ medium all cycle get `farCyclesSurvived++`; if `stage == underReview` AND `farCyclesSurvived >= settings.masterAfterFarCycles` → `stage = mastered`, `stageEnteredAt = today`.
- **medium** → as strong but `consecutiveStrong = 0`; page still "survives" the cycle (no reset).
- **weak** → `consecutiveStrong = 0`, `farCyclesSurvived = 0`, `priorityUntil = today + settings.weakRecoveryDays` (page now **also** surfaces in the near queue until it recovers), `lastGrade = weak`. Stage floor is `underReview`: a `mastered` page **drops to `underReview`**; an `underReview` page **stays** `underReview` (never falls back to `newlyMemorized`). `firstMemorizedAt` is **untouched**. After 2 consecutive `strong` in the near queue the pin expires and the page rejoins the normal ring at its natural position.

### 3.4 A changed wird target reflows the schedule with zero migration

The schedule is **derived, never materialized.** We persist only *intrinsic* per-page facts (`stage`, dates, `reviewCount`, `lastGrade`, `consecutiveStrong`, `farCyclesSurvived`, `priorityUntil`) plus **one** calendar-independent pointer (`farReviewCursor`, a page number). We never write "page X is due on date Y".

Consequences when the user edits settings mid-stream:
- **Raise/lower `newPortionCount`/unit** → only the New-Memorization screen's *suggested* portion changes. Existing `HifzPageState`s are untouched. Nothing to migrate.
- **Raise/lower `reviewPortionCount`/unit** → tomorrow's `quota` (step 1) simply reads the new value. `farReviewCursor` is still a valid page number, so the sweep continues from exactly where it was; the *cycle length* stretches or contracts organically.
- **Toggle `autoEscalateReview`** → engine stops/starts bumping the unit; no state rewrite.
- **Change `newlyMemorizedWindowDays` / `promoteAfterConsecutiveStrong` / `masterAfterFarCycles`** → promotion/mastery tests read the new thresholds on the next grade. A page that already exceeds a lowered threshold promotes on its next `strong`; a raised threshold simply delays the next promotion. No page loses history, and `firstMemorizedAt` never moves.
- **Guard:** `HifzSettingsNotifier.update()` calls `HifzScheduler.onSettingsChanged(pages, meta, settings)` which (a) recomputes nothing persistent, (b) only clamps `farReviewCursor` into `[1,604]` and re-derives `todayQueue`. There is no cached due-date to invalidate because none is stored.

### 3.5 Day-roll handling
On first `hifzProvider` read of a new calendar day (compare `meta.lastActivityDate`): reset `todayNewPages/todayReviewPages/doneToday`; if `lastActivityDate == yesterday && wird was met` keep `currentStreak`, else if a full day was missed with wird unmet → `currentStreak = 0`. Streak increment happens when the day's wird condition (`countNewTowardWird`/`countReviewTowardWird`) is first satisfied.

### 3.6 Unit tests to write in Phase 1 (scheduler + index)
promotion at exactly threshold; promotion blocked by window; weak pin appears in near queue then clears after 2 strong; far cursor wrap → cycle++ → escalation step; de-escalation on bad cycle; `pagesForPortion` returns mushaf-correct page sets for each unit; settings change does not mutate any `HifzPageState`; day-roll streak logic (met / missed / same-day).

---

## 4. Screens

Every screen: `Scaffold(backgroundColor: AppColors.nightDeep)` → `SafeArea` → `Column`, leading a circular back button (`khatmah_tracking_screen.dart` `_AppBar` L122–172 is the template — extract to `lib/features/hifz/widgets/hifz_app_bar.dart`). All sizing `flutter_screenutil`. Cards = `GoldCard` or the `_StatsHeader` gradient pattern. Lists = `ListView.builder` + `RevealAnimation`.

### 4.1 Hifz Dashboard — `hifz_dashboard_screen.dart`  ·  title **حفظ القرآن**
**Purpose:** at-a-glance state of the whole memorization journey; entry point to every other Hifz screen.
**Elements:**
- **Overall memorized %** — `memorizedPages / 604` (count pages with `stage != notStarted`; optionally weight `mastered` fully, `newlyMemorized` half for a "consolidated" figure — Open Q 3). Big number + progress ring, reuse `_StatItem` styling.
- **Juz completion map** — `juz_completion_map.dart`: 30 cells (6×5 grid). Each cell = juz number badge (reuse the `_buildJuzTab` circular gradient badge, `quran_home` L314–336) tinted by completion ratio of that juz's ~20 pages: `notStarted` → `nightCard`; partial → `goldWarm` at `alpha = ratio`; fully `mastered` → solid `goldGlow` / green accent. Tap → Juz Detail (§4.4).
- **"مراجعة اليوم" summary card** — counts: `near.length` تثبيت + `far.length` دورية, and how many already `doneToday`. Tap → Today's Review (§4.2). Reuse `_StatsHeader` gradient card.
- **Wird / streak card** — `wird_streak_card.dart`: `currentStreak` (🔥), `longestStreak`, today's progress toward the wird target (`todayNewPages` / target, `todayReviewPages` / target), a one-line "ورد اليوم: صفحة" from settings. Tap → Hifz Settings (§4.6).
- Secondary buttons row: **حفظ جديد** (§4.3), **الإحصائيات** (§4.5).
**Reuse:** `GoldCard`, `_StatItem`, `RevealAnimation`, tokens. **Data:** `hifzProvider`, `hifzSettingsProvider`, `hifzTodayProvider`, `HifzPageIndex`. **No new data files.**

### 4.2 Today's Review — `hifz_today_review_screen.dart`  ·  title **مراجعة اليوم**
**Purpose:** work through today's merged near+far queue, grade each page.
**Elements:**
- Two sections with headers `التثبيت` (near) and `المراجعة الدورية` (far) — reuse `_SectionHeader` (`khatmah` L339–367).
- Each row = `hifz_page_tile.dart`: page number badge, "صفحة N · الجزء J · سورة …" subtitle (from `HifzPageIndex`), current stage chip, and a trailing state (pending / done ✓). Tap row → **open the existing reader**: `Navigator.push(ModernQuranReaderV2(surahNumber: s, initialAyah: a))` where `(s,a) = index.firstAyahOfPage(page)`. **No reader change required** (see §5).
- On return from the reader (or via an inline "قيّم" button), present `grade_selector_sheet.dart` — `showModalBottomSheet` (bg `nightCard`, top‑radius 20.r, `borderGold` side, drag handle) with three large buttons **ضعيف / متوسط / قوي** → `hifzProvider.gradePage(page, grade)` → scheduler applies §3.2/§3.3, row flips to ✓, counters/streak update, a `_showToast`-style confirmation ("تم — أحسنت").
- Progress bar at top: `doneToday / (near+far total)`. Empty state when nothing is due: "لا مراجعة اليوم — أحسنت" with a calm illustration.
**Reuse:** bottom-sheet idiom, `_showToast`, `_SectionHeader`, `RevealAnimation`, reader entry, tokens. **Data:** `hifzTodayProvider`, `hifzProvider`, `HifzPageIndex`.

### 4.3 New Memorization — `hifz_new_memorization_screen.dart`  ·  title **حفظ جديد**
**Purpose:** mark a page / page-range / surah as newly memorized *today*.
**Elements:**
- Suggested portion banner from settings ("وردك: صفحة واحدة — الصفحة N التالية"), computed as the first `notStarted` page at/after the current frontier (respecting `startPreference`).
- Picker modes (segmented, reuse `_buildTabBar` chrome): **بحسب الصفحة** (range slider / two page steppers) · **بحسب السورة** (list from `QuranDataService.surahs`, tap adds all its `notStarted` pages) · **بحسب الجزء** (30 chips).
- Live preview: "ستضيف 1 صفحة (صفحة 15) — سورة البقرة". Confirm button **أضِف إلى الحفظ** → `hifzProvider.markNewlyMemorized({pages})` → for each page: create `HifzPageState(stage: newlyMemorized, firstMemorizedAt: today, stageEnteredAt: today)`; skip pages already tracked (toast "الصفحة N محفوظة مسبقاً"). Updates `todayNewPages`, streak.
- Undo affordance: a `_showToast` with an "تراجع" action, and long-press on a page in Juz Detail to reset it (Open Q 11).
**Reuse:** segmented chrome, dialog/toast, `QuranDataService.surahs`, `HifzPageIndex`. **Data:** `hifzProvider`, `hifzSettingsProvider`.

### 4.4 Juz Detail — `hifz_juz_detail_screen.dart`  ·  title **الجزء {n}**  *(optional, high value)*
**Purpose:** per-page breakdown inside one juz; quick manual stage edits.
**Elements:** header with juz name (`QuranDataService.juzNames[n-1]`) + juz completion ring. `ListView` of the ~20 pages via `hifz_page_tile.dart`, each showing stage chip, `lastReviewedAt`, `reviewCount`, `lastGrade`. Tap → reader at that page. Long-press → small sheet: "علّمها محفوظة اليوم" / "أعِد ضبطها" / "قيّمها الآن". Filter chips: الكل / حفظ حديث / قيد المراجعة / متقن / لم يبدأ.
**Reuse:** `_SectionHeader`, page tile, bottom sheet, `RevealAnimation`. **Data:** `hifzProvider`, `HifzPageIndex.pagesInJuz(n)`.

### 4.5 Statistics / History — `hifz_stats_screen.dart`  ·  title **السجل والإحصائيات**
**Purpose:** progress over time + review-session log.
**Elements:**
- Top stat tiles (`_StatItem`): total memorized pages, % of mushaf, pages `mastered`, current far-cycle length (days), longest streak.
- **Progress-over-time chart** — memorized-pages count per week (derive from `firstMemorizedAt` histogram; no charting lib assumed — a simple bar column built with `Container`s/`CustomPaint`, matching the app's hand-rolled visual style; if a chart package is later added, isolate it here).
- **سجل المراجعات** — reverse-chronological `ListView` over `HifzReviewSession` entries: date, kind chip (تثبيت / دورية / حفظ جديد), page range, mini grade breakdown (n قوي · n متوسط · n ضعيف).
- Optional: heat-strip of the last 30 days (wird met / missed / partial).
**Reuse:** `_StatItem`, `GoldCard`, `RevealAnimation`, `DateFormat('yyyy/MM/dd')` (intl already initialised for `ar`). **Data:** `hifzProvider` (`sessions`, `meta`, `pages`).

### 4.6 Hifz Settings — `hifz_settings_screen.dart`  ·  title **إعدادات الحفظ**
**Purpose:** freely edit the wird target and pacing at any time.
**Elements (each writes `hifzSettingsProvider` immediately):**
- **مقدار ورد الحفظ اليومي** — unit dropdown (صفحة / ربع حزب / نصف حزب / حزب) + count stepper. Live "≈ N صفحة/يوم".
- **مقدار ورد المراجعة اليومي** — same controls + a toggle **زيادة تلقائية لتقصير دورة المراجعة** (`autoEscalateReview`) + ceiling dropdown (`reviewPortionMaxUnit`).
- **نافذة التثبيت (أيام)** slider (`newlyMemorizedWindowDays`).
- **عدد التقييمات القوية للترقية** stepper (`promoteAfterConsecutiveStrong`).
- **دورات المراجعة للإتقان** stepper (`masterAfterFarCycles`).
- **نقطة البداية المقترحة** — من الفاتحة / من جزء عمّ / مخصّص (`startPreference`).
- **أيام الراحة** weekday multi-select (`restWeekdays`).
- **ما الذي يحقّق ورد اليوم؟** — الحفظ / المراجعة / كلاهما.
- Danger zone: **إعادة ضبط كل بيانات الحفظ** (typed confirmation `AlertDialog`, `khatmah` dialog style) → `HifzService.clearAll()`.
Every change: after write, show a `_showToast` "تم الحفظ — سيظهر الأثر في ورد الغد" and call `HifzScheduler.onSettingsChanged` (§3.4).
**Reuse:** dialog idiom, toast, segmented chrome. **Data:** `hifzSettingsProvider`.

---

## 5. Reusing the existing reader for the review flow — feasibility: **confirmed**

- `ModernQuranReaderV2({ required int surahNumber, int? initialAyah })` already scrolls to `initialAyah` on load (L130–134). "Review this page" =
  `final (s, a) = index.firstAyahOfPage(page); Navigator.push(MaterialPageRoute(builder: (_) => ModernQuranReaderV2(surahNumber: s, initialAyah: a)));`
- Audio is already range-capable (`_playAyahRange`), so a "استمع للصفحة" affordance inside the review needs **no reader work**; the user selects on the existing page and plays.
- **No changes to the reader are required for Phases 1–4.** The grade is captured *after* returning, in the Hifz Today screen (bottom sheet), keeping the reader untouched and each phase independently reviewable.
- **Optional, later (Phase 5+ nicety, not required):** add `int? initialPage` and/or `({int from, int to})? highlightRange` params to `ModernQuranReaderV2` so a page can be opened + visually framed without computing the first ayah, and add an `onFinishedRange`/pop-result so grading can be prompted on exit. These are additive and backward-compatible; flag before starting if desired.

---

## 6. Proposed file list

### New — `lib/core/`
| File | Role |
|---|---|
| `lib/core/services/hifz_service.dart` | Static Hive wrapper. `init()` (called from `main.dart`). Box `hifz_box`, keys `pages / settings / sessions / meta`. Read/write helpers returning/accepting `Map`, defensive parsing (mirrors `LastReadService`). `clearAll()`. |
| `lib/core/data/hifz_page_index.dart` | Pure, computed once from `QuranPageData.ayahPageInfo`. API: `pageCount = 604`, `firstAyahOfPage(p) → (int surah, int ayah)`, `surahRangeOnPage(p)`, `pagesInJuz(j) → List<int>`, `juzOfPage(p) → int`, `quarterOfPage(p) → int (1–240)`, `pagesInQuarter(q)`, `pagesInHizb(h)`, `pagesOfSurah(s)`, `pagesForPortion(unit, count) → List<int>` starting at a given cursor. *(Lives in `core/data` because it is generic mushaf structure, reusable beyond Hifz.)* |

### New — `lib/features/hifz/`
| File | Role |
|---|---|
| `models/hifz_models.dart` | Enums (`HifzStage`, `HifzGrade`, `HifzPortionUnit`, `HifzStartPreference`); classes `HifzPageState`, `HifzSettings`, `HifzReviewSession`, `HifzMeta` — each with `toMap`/`fromMap` (enum→`.name`, date→ISO‑8601, defensive). |
| `logic/hifz_scheduler.dart` | Pure engine: `buildTodayQueue(...)`, `gradeNearPage(...)`, `gradeFarPage(...)`, `advanceFarCursor(...)`, `onCycleComplete(...)` (escalation/de-escalation), `onSettingsChanged(...)`, `rollDay(...)`, `pagesForPortion(...)`. No Hive / no Riverpod. |
| `providers/hifz_provider.dart` | `hifzProvider = StateNotifierProvider<HifzNotifier, HifzState>`. `HifzState { Map<int,HifzPageState> pages; HifzMeta meta; List<HifzReviewSession> sessions; bool isLoading }` + `copyWith`. Actions: `markNewlyMemorized(Set<int>)`, `gradePage(int, HifzGrade)`, `resetPage(int)`, `reload()`. Loads from `HifzService` in ctor. |
| `providers/hifz_settings_provider.dart` | `hifzSettingsProvider = StateNotifierProvider<HifzSettingsNotifier, HifzSettings>`. Persists to `HifzService` `settings` key; `update(...)` → write → `HifzScheduler.onSettingsChanged`. |
| `providers/hifz_today_provider.dart` | `hifzTodayProvider = Provider<TodayQueue>` — derives the merged near+far queue from `hifzProvider` + `hifzSettingsProvider` + `HifzPageIndex` + `DateTime.now()`. |
| `screens/hifz_dashboard_screen.dart` | §4.1 |
| `screens/hifz_today_review_screen.dart` | §4.2 |
| `screens/hifz_new_memorization_screen.dart` | §4.3 |
| `screens/hifz_juz_detail_screen.dart` | §4.4 (optional) |
| `screens/hifz_stats_screen.dart` | §4.5 |
| `screens/hifz_settings_screen.dart` | §4.6 |
| `widgets/hifz_app_bar.dart` | Circular-back-button app bar, extracted from `khatmah_tracking_screen.dart` `_AppBar`. |
| `widgets/juz_completion_map.dart` | 6×5 juz grid, cells tinted by completion. |
| `widgets/hifz_page_tile.dart` | Page row (badge + subtitle + stage chip + trailing state) used by Today / Juz Detail. |
| `widgets/grade_selector_sheet.dart` | ضعيف / متوسط / قوي bottom sheet. |
| `widgets/wird_streak_card.dart` | Streak + today-vs-target card. |
| `widgets/hifz_stat_card.dart` | Thin wrapper over `_StatItem` styling (or reuse `lib/features/progress/widgets/stat_card.dart`). |

### New — `test/`
| File | Role |
|---|---|
| `test/hifz_scheduler_test.dart` | §3.6 cases. |
| `test/hifz_page_index_test.dart` | page↔juz↔quarter↔ayah correctness against `QuranPageData`; 604 pages; each juz's page list contiguous; `pagesForPortion` sizes. |

### Edited (existing)
| File | Change | Phase |
|---|---|---|
| `lib/main.dart` (~L270) | add `HifzService.init()` to the `Future.wait([...])`. | 1 |
| `lib/features/quran/screens/quran_home_screen.dart` | header 3-row restructure (§1); import + nav to `HifzDashboardScreen`. | 1 |
| `lib/features/quran/screens/quran_reader_screen.dart` | *only if* Open Q on optional `initialPage`/pop-result is approved. | 5+ (optional) |

---

## 7. Arabic labels (register matched to ختم القرآن / آخر قراءة)

| Concept | Label | Notes |
|---|---|---|
| Nav button (row 2) | **الحفظ** | confirmed; parallels "ختم القرآن" |
| Dashboard screen title | **حفظ القرآن** | fuller form as a heading, like the ختم screen |
| Today's review (card + screen) | **مراجعة اليوم** | |
| Near sub-section | **التثبيت** | newly-memorized consolidation |
| Far sub-section | **المراجعة الدورية** | cyclical sweep |
| New-memorization screen | **حفظ جديد** / button **أضِف إلى الحفظ** | |
| Juz detail | **الجزء {n}** (screen) / **تفاصيل الجزء** (menu) | |
| Statistics / history | **السجل والإحصائيات** ; session log **سجل المراجعات** | |
| Settings | **إعدادات الحفظ** | |
| Dashboard cards | memorized % → **نسبة الحفظ** ; juz grid → **خريطة الأجزاء** ; streak → **المواظبة والورد** | |
| Stages | لم يبدأ / **حفظ حديث** / **قيد المراجعة** / **متقن** | |
| Grades | **ضعيف** / **متوسط** / **قوي** | grade "strong" = **قوي**, *not* متقن — avoids collision with the `mastered` stage label متقن |
| Wird target | **مقدار الورد اليومي** ; units صفحة / ربع حزب / نصف حزب / حزب | |
| Escalation toggle | **زيادة تلقائية لتقصير دورة المراجعة** | |
| Confirmation toast | **تم — أحسنت** / **تم الحفظ** | reuse `_showToast` visual |

---

## 8. Phased implementation roadmap

Each phase is independently reviewable and mergeable (matches how last-read / audio were phased).

### Phase 0 — this document. ✅

### Phase 1 — Header restructure + data layer (no user-visible Hifz UI beyond a stub)
- `quran_home_screen.dart`: §1 three-row header; `الحفظ` → stub `HifzDashboardScreen` (empty "قريباً" scaffold).
- `hifz_page_index.dart` (+ tests).
- `hifz_models.dart` (enums + 4 classes + map (de)serialization).
- `hifz_service.dart`; wire `HifzService.init()` into `main.dart`.
- `hifz_scheduler.dart` — full pure engine (+ tests, §3.6).
- `hifz_provider.dart`, `hifz_settings_provider.dart`, `hifz_today_provider.dart`.
- **Review gate:** header matches the three-row spec using existing tab chrome; tapping الحفظ opens the stub; `flutter test` green; no persistence written yet except on explicit action; no regression to ختم / آخر قراءة / reader.

### Phase 2 — Dashboard
- `hifz_dashboard_screen.dart` (real), `juz_completion_map.dart`, `wird_streak_card.dart`, `hifz_app_bar.dart`, `hifz_stat_card.dart`.
- Today card + secondary buttons link to stub destinations (Today / New / Stats can be "قريباً" until their phase).
- **Review gate:** dashboard renders correct %, juz map, streak from seeded/manual data; no writes from this screen except navigation.

### Phase 2.5 — Juz Detail *(optional; fold into Phase 2 if time allows)*
- `hifz_juz_detail_screen.dart`, `hifz_page_tile.dart` (shared with Phase 3).
- Long-press quick actions may be stubbed until Phase 3/4 land their write paths.

### Phase 3 — Today's Review flow
- `hifz_today_review_screen.dart`, `grade_selector_sheet.dart`.
- Rows open `ModernQuranReaderV2` at the page's first ayah (no reader change).
- `hifzProvider.gradePage` live → scheduler promotion/demotion/escalation active → session log entries → streak/counters.
- **Review gate:** grading a near page N times promotes it at the correct threshold; a weak far page reappears in تثبيت and clears after 2 strong; far cursor advances and wraps → cycle++/escalation; `doneToday` prevents duplicates.

### Phase 4 — New Memorization flow
- `hifz_new_memorization_screen.dart`.
- `markNewlyMemorized` with dup-guard + undo toast; suggested portion from settings; feeds Phase 3's near queue.
- **Review gate:** adding a page/surah/juz creates correct `HifzPageState`s dated today; already-tracked pages are skipped with feedback; new pages appear in tomorrow's تثبيت.

### Phase 5 — Statistics / History + Settings
- `hifz_stats_screen.dart` (progress chart + سجل المراجعات), `hifz_settings_screen.dart`.
- Prove the **freely-editable wird** requirement end-to-end: change unit/count/escalation/window mid-journey and confirm (a) no `HifzPageState` is mutated, (b) `firstMemorizedAt` never moves, (c) tomorrow's queue reflects the new target, (d) `farReviewCursor` stays valid.
- **Review gate:** settings changes reflow the schedule with zero data loss; stats match the underlying `pages`/`sessions`.

### Phase 6 *(optional, later)* — polish
- Optional reader params (`initialPage`, pop-result grading prompt).
- Daily wird reminder via the existing `NotificationService` (hook point only; not before Phase 5).
- `mastered` reduced-frequency far-review (skip alternate cycles) if Open Q 3 resolves that way.

---

## 9. Resolved decisions

All twelve open questions from Phase 0 were resolved before Phase 1 implementation began. None of them required deviating from the algorithm as specified in §2/§3 above — every resolution confirms a default the plan already proposed. Implemented exactly as stated below.

1. **Back button on row 1.** Stays as the leading element of the identity row (`_buildIdentityRow` in `quran_home_screen.dart`) — app chrome, not a semantic section entry point.
2. **"Today's wird" for the streak.** Satisfied by **either** the new-memorization portion **or** the review portion (`countNewTowardWird`/`countReviewTowardWird`, both default `true`). No algorithm change from §3 was needed — `HifzScheduler.registerActivity`/`_isWirdMet` implement this "either" check directly.
3. **`mastered` semantics.** A **badge only** — it does **not** reduce far-review frequency. `HifzScheduler.buildTodayQueue`'s far corpus is `{underReview, mastered}` with no alternate-cycle skip anywhere in the scheduler; `onCycleComplete` reviews `mastered` pages every cycle exactly like `underReview` ones. `masterAfterFarCycles` default is `3`.
4. **Consolidated %.** Both are implemented now in `HifzScheduler`: `simpleFraction`/`memorizedPageCount` (any `stage != notStarted` counts as 1 — the big dashboard number) and `consolidatedFraction` (weighted `newlyMemorized=0.5`, `underReview=0.8`, `mastered=1.0` — the secondary line). `HifzState` exposes both as getters for Phase 2 to consume directly.
5. **Newly-memorized promotion.** Requires **both** `newlyMemorizedWindowDays` elapsed **and** `promoteAfterConsecutiveStrong` consecutive strong grades — implemented as an `&&` in `HifzScheduler.gradeNearPage`'s `promote` condition, proposed defaults 14 / 7.
6. **Demotion floor.** Confirmed and implemented: `gradeFarPage`'s weak branch drops `mastered → underReview` only; `underReview` never falls back to `newlyMemorized`. `firstMemorizedAt` has no setter path anywhere after construction — it is never reassigned by any scheduler function.
7. **Day-based granularity.** A page is "done for today" once graded — `HifzMeta.doneToday` (reset by `HifzScheduler.rollDay` on a new calendar day).
8. **Mushaf numbering.** Madani 604-page numbering (`QuranPageData`) only — `HifzPageIndex.pageCount` is derived from it, not hard-coded, and a test asserts it equals 604.
9. **`hifz_page_index.dart` location.** `lib/core/data/hifz_page_index.dart` — confirmed. It imports nothing from `features/hifz`; conversely `HifzPortionUnit`-aware helpers (`pagesForPortion`) live in `HifzScheduler`, not the index, so the index stays a dependency-free, generic mushaf-structure module reusable outside Hifz.
10. **Juz map cells.** Flat single color per juz by completion ratio. `HifzScheduler.juzCompletion(pages, {weighted})` is implemented now (both a simple started/not-started ratio and a weighted variant) and exposed via `HifzState.juzCompletion()`, ready for the Phase 2 `juz_completion_map.dart` widget to consume without further data-layer work.
11. **Undo/correction UX.** Long-press → reset/re-grade/mark-memorized-today is sufficient for v1. The only data-layer requirement this implies — `HifzNotifier.resetPage(page)` — exists now; the long-press UI itself is Phase 2.5/3/4 scope.
12. **Far-review ordering.** Strict mushaf order. `HifzScheduler.buildTodayQueue`'s far corpus is sorted ascending by page number and walked from `meta.farReviewCursor`; `advanceFarCursor` always advances to the next **higher** corpus page number. No alternate sort (e.g. oldest-`lastReviewedAt`-first) exists anywhere in the scheduler.

---
