package com.NourRamadan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.CalculationParameters
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale

// ════════════════════════════════════════════════════════════════
//  AlarmScheduler — المالك الوحيد لجدولة الأذان على Android
//
//  ✅ المرحلة 2 (plan_azan_reliability.md):
//
//  1) أفق 21 يوماً بدل نافذة 48 ساعة.
//     ⚠️ الأفق شبكة أمان ثانوية — وليس الإصلاح الأساسي.
//     الإصلاح الأساسي هو المرحلة 1: تصحيح مفاتيح SharedPreferences
//     حتى تعمل آلية التجديد اليومية (Worker/Boot/بعد كل أذان) أصلاً.
//     الأفق يضمن فقط أن فوات دورة تجديد لا يُسبب صمتاً فورياً.
//
//  2) معرّفات مطلقة مشتقّة من التاريخ:
//     id = ID_BASE + (epochDay % DAY_MODULUS) * 10 + prayerIndex
//     المعرّف يعني دائماً نفس اللحظة مهما تغيّر "اليوم الحالي".
//     (المخطط القديم 200+day*10 كان نسبياً لليوم، فيتبدّل معناه كل
//      منتصف ليل بينما الـ PendingIntent المسلَّح باقٍ → أذان مكتوم
//      أو مكرّر. راجع §1.11)
//
//  3) refresh() ذرّية: تحسب المجموعة الكاملة أولاً، ثم تُسلّح،
//     ثم تُلغي المتقادم فقط. لا تترك الجهاز بلا منبهات أبداً.
//
//  4) سجلّ مُسلَّح (ledger) في SharedPreferences بدل استخدام
//     PendingIntent.FLAG_NO_CREATE كفحص وجود — وهو فحص غير موثوق
//     لأن سجلّ الـ PendingIntent قد يبقى بعد إلغاء المُصنّع للمنبه. (§1.12a)
//
//  عدد المنبهات: 21 × 6 أذان = 126، و21 × 5 تذكير = 105، الإجمالي 231.
//  الحدّ الفعلي للنظام 500 منبه لكل uid — لا علاقة لـ Doze بعدد المنبهات،
//  و setAlarmClock() معفيّ من Doze أصلاً.
// ════════════════════════════════════════════════════════════════
object AlarmScheduler {

    private const val TAG = "AlarmScheduler"
    private const val PREFS_NAME = "FlutterSharedPreferences"

    // ✅ المرحلة 2: أفق 21 يوماً (شبكة أمان ثانوية)
    const val DAYS_AHEAD = 21

    // منبه أُطلق للتو: لا يُعاد تسليحه
    private const val TIME_BUFFER_MS = 5 * 60 * 1000L
    private const val REMINDER_LEAD_MS = 15 * 60 * 1000L

    // ── نطاقات المعرّفات (مفصولة تماماً عن معرّفات Dart القديمة < 20000) ──
    private const val ID_BASE = 1_000_000       // أذان:   1,000,000 .. 1,099,999
    private const val REMINDER_OFFSET = 100_000 // تذكير:  1,100,000 .. 1,199,999
    private const val SHOW_OFFSET = 200_000     // showPi: 1,200,000 .. 1,299,999
    private const val DAY_MODULUS = 10_000      // يتكرّر كل ~27 سنة — لا تداخل ضمن 21 يوماً

    // ── مفاتيح الحالة (مفاتيح خام — الناتيف يكتب بالبادئة الواحدة) ──
    private const val KEY_LEDGER = "flutter.azan_armed_ids"
    private const val KEY_LAST_REFRESH = "flutter.azan_last_refresh_at"
    private const val KEY_HORIZON_END = "flutter.azan_horizon_end_at"
    private const val KEY_LEGACY_SWEPT = "flutter.azan_legacy_ids_swept"

    private data class PrayerSpec(val name: String, val index: Int)

    private val PRAYERS = listOf(
        PrayerSpec("الفجر", 0),
        PrayerSpec("الظهر", 1),
        PrayerSpec("العصر", 2),
        PrayerSpec("المغرب", 3),
        PrayerSpec("العشاء", 4),
        PrayerSpec("الشروق", 5)
    )

    /// منبه واحد محسوب — قبل التسليح
    private data class PlannedAlarm(
        val id: Int,
        val triggerAtMillis: Long,
        val prayerName: String,
        val soundFile: String,
        val isReminder: Boolean
    )

    // ════════════════════════════════════════════════════════════
    //  refresh() — نقطة الدخول الوحيدة (ذرّية)
    //
    //  تُستدعى من: MainActivity، AzanWorker، AzanBootReceiver،
    //              AzanAlarmReceiver، TimeChangeReceiver،
    //              وقناة Dart 'refreshAlarms'.
    //  (AzanJobService حُذف في المرحلة 6 — كان بلا أي مُستدعٍ فعلي
    //  لجدولته؛ راجع plan_azan_reliability.md)
    //
    //  التسلسل الذرّي:
    //    1. احسب المجموعة الكاملة (21 يوماً) — أي فشل هنا = خروج بلا أثر
    //    2. سلّح كل المجموعة الجديدة (FLAG_UPDATE_CURRENT = تحديث موضعي)
    //    3. ألغِ فقط ما في السجلّ القديم وليس في الجديد
    //    4. احفظ السجلّ الجديد
    //  النتيجة: لا توجد لحظة واحدة يكون فيها الجهاز بلا منبهات.
    // ════════════════════════════════════════════════════════════
    fun refresh(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            if (alarmManager == null) {
                Log.e(TAG, "❌ AlarmManager غير متاح — لا تغيير")
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms()
            ) {
                Log.e(TAG, "❌ لا يوجد إذن SCHEDULE_EXACT_ALARM — لا تغيير")
                return
            }

            // ───── 1) الحساب الكامل أولاً ─────────────────────────
            val planned = computeSchedule(prefs)
            if (planned == null) {
                // لا موقع / فشل حساب → نُبقي المنبهات الحالية كما هي
                Log.w(TAG, "⚠️ تعذّر الحساب — أُبقيت المنبهات الحالية دون مساس")
                return
            }
            if (planned.isEmpty()) {
                Log.w(TAG, "⚠️ المجموعة المحسوبة فارغة — أُبقيت المنبهات الحالية")
                return
            }

            val oldLedger = readLedger(prefs)

            // ───── 2) تسليح المجموعة الجديدة بالكامل ──────────────
            var armed = 0
            var failed = 0
            val nowArmed = mutableSetOf<Int>()
            // كل ما تنوي هذه الدورة تغطيته — بصرف النظر عن نجاح التسليح.
            // ✅ الإصلاح: هذه هي المرجع الصحيح لتحديد "المتقادم"، لا nowArmed.
            val plannedIds = planned.map { it.id }.toSet()

            for (alarm in planned) {
                val ok = if (alarm.isReminder) {
                    scheduleReminder(context, alarmManager, alarm)
                } else {
                    scheduleAzan(context, alarmManager, alarm)
                }
                if (ok) {
                    armed++
                    nowArmed.add(alarm.id)
                } else {
                    failed++
                }
            }

            // فشل تسليح كل شيء → لا نُلغِ أي شيء قديم
            if (nowArmed.isEmpty()) {
                Log.e(TAG, "❌ فشل تسليح كل المنبهات — السجلّ القديم باقٍ كما هو")
                return
            }

            // ───── 3) إلغاء المتقادم فقط ──────────────────────────
            // ✅ الإصلاح: نُقارن oldLedger بـ plannedIds (كل ما تنوي هذه
            // الدورة تغطيته) لا بـ nowArmed (ما نجح تسليحه فعلاً فقط).
            //
            // قبل الإصلاح: فشل تسليح معرّف واحد (استثناء عابر في
            // setAlarmClock، أو فشل حساب يوم واحد في computeSchedule)
            // كان يُخرجه من nowArmed فقط ليقع ضمن oldLedger - nowArmed
            // ويُلغى — حتى لو كان مُسلَّحاً بنجاح من دورة سابقة وما زال
            // صالحاً ضمن النافذة الجديدة. أي فشل جزئي كان يُدمّر منبهاً
            // صحيحاً بدل أن يترك الفشل يُعالَج في الدورة التالية.
            //
            // بعد الإصلاح: معرّف فشل تسليحه هذه الدورة يبقى ضمن
            // plannedIds (لأنه لا يزال ضمن النافذة) فلا يُعتبر متقادماً
            // ولا يُلغى — يبقى بمنبهه القديم إن وُجد، وتُعاد محاولة
            // تسليحه في الدورة التالية (self-healing).
            // ✅ المرحلة 3: cancelById() تُوجّه للمستقبل الصحيح (أذان/تذكير)
            // بحسب نطاق المعرّف — كانت هذه الحلقة تستخدم cancelExact() فقط
            // فتُخفق صامتة على أي معرّف تذكير متقادم (PendingIntent.getBroadcast
            // بمستقبل خاطئ لا يُطابق شيئاً أبداً)، فتبقى تذكيرات متقادمة
            // (منتهية زمنياً وبلا أثر عملي، لكنها كانت تُفسد أي فحص لاحق
            // يعتمد على "هل هذا المعرّف مُسلَّح فعلاً" — راجع isArmedInOs أدناه).
            var cancelled = 0
            for (staleId in computeStaleIds(oldLedger, plannedIds)) {
                if (cancelById(context, alarmManager, staleId)) cancelled++
            }

            // ───── 4) حفظ السجلّ الجديد + بيانات التشخيص ──────────
            val horizonEnd = planned.maxOf { it.triggerAtMillis }
            writeLedger(prefs, nowArmed, horizonEnd)

            // ───── 5) كنس المعرّفات القديمة (مرّة واحدة بعد الترقية) ──
            sweepLegacyIdsOnce(context, alarmManager, prefs)

            Log.d(
                TAG,
                "✅ تحديث ذرّي: مُسلَّح=$armed فشل=$failed مُلغى(متقادم)=$cancelled " +
                    "أفق=${DAYS_AHEAD}يوم حتى ${formatTime(horizonEnd)}"
            )
        } catch (e: Exception) {
            Log.e(TAG, "❌ خطأ في refresh: ${e.message}", e)
        }
    }

    // ════════════════════════════════════════════════════════════
    //  الحساب — لا يلمس AlarmManager إطلاقاً
    //  يُعيد null عند تعذّر الحساب (لا موقع / خطأ)
    // ════════════════════════════════════════════════════════════
    private fun computeSchedule(prefs: SharedPreferences): List<PlannedAlarm>? {
        val lat = prefs.getString("flutter.last_lat", null)?.toDoubleOrNull()
        val lng = prefs.getString("flutter.last_lng", null)?.toDoubleOrNull()

        if (lat == null || lng == null) {
            Log.e(TAG, "❌ لا يوجد موقع محفوظ (flutter.last_lat/last_lng)")
            return null
        }

        val methodKey = prefs.getString("flutter.settings_calculation_method", null)
        val madhabKey = prefs.getString("flutter.settings_madhab", null)
        val reminderEnabled = prefs.getBoolean("flutter.settings_prayer_reminder", true)
        val defaultSound = resolveDefaultSound(prefs)

        val coords = Coordinates(lat, lng)
        val params = resolveParams(methodKey, madhabKey)

        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)
        val now = System.currentTimeMillis()

        val out = mutableListOf<PlannedAlarm>()
        val editor = prefs.edit()

        for (dayOffset in 0 until DAYS_AHEAD) {
            val date = today.plusDays(dayOffset.toLong())

            val times = try {
                PrayerTimes(
                    coords,
                    DateComponents(date.year, date.monthValue, date.dayOfMonth),
                    params
                )
            } catch (e: Exception) {
                Log.e(TAG, "❌ فشل حساب $date: ${e.message}")
                continue
            }

            val dayTimes = listOf(
                times.fajr, times.dhuhr, times.asr,
                times.maghrib, times.isha, times.sunrise
            )

            for (prayer in PRAYERS) {
                val id = idFor(date, prayer.index)
                val triggerAt = dayTimes[prayer.index].time

                // بيانات ليقرأها أي مكوّن آخر (تشخيص/احتياط)
                editor
                    .putString("flutter.azan_${id}_time", triggerAt.toString())
                    .putString("flutter.azan_${id}_prayer", prayer.name)
                    .putString("flutter.azan_${id}_sound", defaultSound)

                // ماضٍ (أو أُطلق للتو) → لا يُسلَّح
                if (triggerAt <= now + TIME_BUFFER_MS) continue

                out.add(
                    PlannedAlarm(
                        id = id,
                        triggerAtMillis = triggerAt,
                        prayerName = prayer.name,
                        soundFile = defaultSound,
                        isReminder = false
                    )
                )

                // تذكير 15 دقيقة (لا تذكير للشروق)
                if (reminderEnabled && prayer.index != 5) {
                    val reminderAt = triggerAt - REMINDER_LEAD_MS
                    if (reminderAt > now + TIME_BUFFER_MS) {
                        out.add(
                            PlannedAlarm(
                                id = id + REMINDER_OFFSET,
                                triggerAtMillis = reminderAt,
                                prayerName = prayer.name,
                                soundFile = defaultSound,
                                isReminder = true
                            )
                        )
                    }
                }
            }
        }

        editor.putString("flutter.last_sound_file_scheduled", defaultSound).apply()
        return out
    }

    // ════════════════════════════════════════════════════════════
    //  المعرّفات المطلقة — مشتقّة من تاريخ الصلاة نفسه
    // ════════════════════════════════════════════════════════════
    /// معرّف ثابت لكل (تاريخ، صلاة). لا يتغيّر معناه بمرور الأيام.
    fun idFor(date: LocalDate, prayerIndex: Int): Int =
        ID_BASE + ((date.toEpochDay() % DAY_MODULUS).toInt()) * 10 + prayerIndex

    /// هل هذا المعرّف من نطاق الجدولة الجديد؟
    fun isManagedId(id: Int): Boolean = id >= ID_BASE && id < ID_BASE + SHOW_OFFSET

    // ════════════════════════════════════════════════════════════
    //  تحديد المعرّفات المتقادمة (خارج النافذة الجديدة كلياً)
    //
    //  ✅ يُقارن بـ plannedIds (كل ما تنوي هذه الدورة تغطيته) — لا بما
    //  نجح تسليحه فعلاً. معرّف فشل تسليحه هذه الدورة (استثناء عابر،
    //  أو فشل حساب يوم واحد) يبقى "مخطَّطاً" فلا يُعتبر متقادماً.
    //
    //  دالة صِرفة (pure) — بلا Context/AlarmManager — قابلة للاختبار
    //  مباشرةً بـ JUnit عادي دون Robolectric. راجع AlarmSchedulerTest.kt
    //  و plan_azan_reliability.md (تدقيق المرحلة 2، البند 2).
    // ════════════════════════════════════════════════════════════
    internal fun computeStaleIds(oldLedger: Set<Int>, plannedIds: Set<Int>): Set<Int> =
        oldLedger - plannedIds

    // ════════════════════════════════════════════════════════════
    //  السجلّ (ledger) — بديل موثوق لـ FLAG_NO_CREATE
    // ════════════════════════════════════════════════════════════
    private fun readLedger(prefs: SharedPreferences): Set<Int> {
        val raw = prefs.getString(KEY_LEDGER, null) ?: return emptySet()
        if (raw.isBlank()) return emptySet()
        return raw.split(',').mapNotNull { it.trim().toIntOrNull() }.toSet()
    }

    private fun writeLedger(prefs: SharedPreferences, ids: Set<Int>, horizonEnd: Long) {
        prefs.edit()
            .putString(KEY_LEDGER, ids.joinToString(","))
            .putString(KEY_LAST_REFRESH, System.currentTimeMillis().toString())
            .putString(KEY_HORIZON_END, horizonEnd.toString())
            .apply()
    }

    // ════════════════════════════════════════════════════════════
    //  كنس المعرّفات القديمة (100-105، 150، 210-265، 8000+) مرّة واحدة
    //  يُنفَّذ بعد نجاح التسليح الجديد — لا قبله.
    // ════════════════════════════════════════════════════════════
    private fun sweepLegacyIdsOnce(
        context: Context,
        alarmManager: AlarmManager,
        prefs: SharedPreferences
    ) {
        if (prefs.getBoolean(KEY_LEGACY_SWEPT, false)) return
        var n = 0
        for (id in legacyIds()) {
            if (cancelExact(context, alarmManager, id)) n++
            if (cancelReminder(context, alarmManager, 8000 + id)) n++
        }
        prefs.edit().putBoolean(KEY_LEGACY_SWEPT, true).apply()
        Log.d(TAG, "🧹 كنس لمرة واحدة: أُلغي $n منبه بالمخطط القديم")
    }

    private fun legacyIds(): List<Int> {
        val ids = mutableListOf(100, 101, 102, 103, 104, 105, 150, 999)
        for (day in 1..6) for (p in 0..5) ids.add(200 + day * 10 + p)
        return ids
    }

    // ════════════════════════════════════════════════════════════
    //  إلغاء كل المنبهات (تغيير الموقع مثلاً) — يتبعه refresh()
    // ════════════════════════════════════════════════════════════
    fun cancelAll(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: return
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            var n = 0
            for (id in readLedger(prefs)) {
                if (cancelById(context, alarmManager, id)) n++
            }
            prefs.edit().putString(KEY_LEDGER, "").apply()
            Log.d(TAG, "🧹 أُلغي $n منبه (cancelAll)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ فشل cancelAll: ${e.message}")
        }
    }

    // ════════════════════════════════════════════════════════════
    //  التسليح
    // ════════════════════════════════════════════════════════════
    private fun scheduleAzan(
        context: Context,
        alarmManager: AlarmManager,
        alarm: PlannedAlarm
    ): Boolean = try {
        val intent = Intent(context, AzanAlarmReceiver::class.java).apply {
            putExtra(AzanAlarmReceiver.EXTRA_SOUND_FILE, alarm.soundFile)
            putExtra(AzanAlarmReceiver.EXTRA_PRAYER_NAME, alarm.prayerName)
            putExtra(AzanAlarmReceiver.EXTRA_ALARM_ID, alarm.id)
            // ✅ الوقت المقصود يُحمل داخل النيّة نفسها — لا يعتمد على
            // مفتاح قابل لإعادة الكتابة (كان سبب كتم الأذان في §1.11)
            putExtra(AzanAlarmReceiver.EXTRA_SCHEDULED_AT, alarm.triggerAtMillis)
        }
        val pi = PendingIntent.getBroadcast(
            context, alarm.id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val showIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("navigate_to", "open_prayer_times")
        }
        val showPi = PendingIntent.getActivity(
            context, alarm.id + SHOW_OFFSET, showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // setAlarmClock: معفيّ تماماً من Doze، وبلا حدّ على العدد
        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(alarm.triggerAtMillis, showPi), pi
        )
        true
    } catch (e: SecurityException) {
        Log.e(TAG, "❌ SecurityException id=${alarm.id}: ${e.message}")
        false
    } catch (e: Exception) {
        Log.e(TAG, "❌ فشل تسليح id=${alarm.id}: ${e.message}")
        false
    }

    private fun scheduleReminder(
        context: Context,
        alarmManager: AlarmManager,
        alarm: PlannedAlarm
    ): Boolean = try {
        val pi = PendingIntent.getBroadcast(
            context, alarm.id,
            Intent(context, ReminderAlarmReceiver::class.java).apply {
                putExtra(ReminderAlarmReceiver.EXTRA_PRAYER_NAME, alarm.prayerName)
                putExtra(ReminderAlarmReceiver.EXTRA_ALARM_ID, alarm.id)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, alarm.triggerAtMillis, pi
        )
        true
    } catch (e: Exception) {
        Log.e(TAG, "❌ فشل تسليح تذكير id=${alarm.id}: ${e.message}")
        false
    }

    // ════════════════════════════════════════════════════════════
    //  ✅ المرحلة 3: توجيه المعرّف إلى مستقبله الصحيح
    //
    //  معرّفات النطاق الجديد فقط (ID_BASE فما فوق) — الحساب ثابت مهما
    //  تغيّر التاريخ (idFor بالأعلى). لا يُستخدم لمعرّفات المخطط القديم
    //  (100-105، 8000+) — تلك تُعالَج بدوالّها الصريحة في
    //  sweepLegacyIdsOnce() لأن حسابها لا يتبع هذا النطاق أصلاً.
    // ════════════════════════════════════════════════════════════
    internal fun isReminderId(id: Int): Boolean = id >= ID_BASE + REMINDER_OFFSET

    private fun receiverClassFor(id: Int): Class<out android.content.BroadcastReceiver> =
        if (isReminderId(id)) ReminderAlarmReceiver::class.java else AzanAlarmReceiver::class.java

    /// يُلغي منبهاً بمعرّفه — يوجّه تلقائياً لمستقبل الأذان أو التذكير.
    /// بديل موحّد لاستخدام cancelExact/cancelReminder اليدوي على معرّفات
    /// النطاق الجديد (يمنع تكرار الخطأ: مستقبل خاطئ = إلغاء صامت بلا أثر).
    private fun cancelById(context: Context, am: AlarmManager, id: Int): Boolean = try {
        val pi = PendingIntent.getBroadcast(
            context, id, Intent(context, receiverClassFor(id)),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pi != null) { am.cancel(pi); pi.cancel(); true } else false
    } catch (e: Exception) {
        false
    }

    /// هل هذا المعرّف مُسلَّح فعلاً في نظام التشغيل الآن؟ (فحص PendingIntent
    /// بـ FLAG_NO_CREATE — الآلية الوحيدة المتاحة لتطبيق عادي؛ تحمل نفس
    /// القيد الموثَّق في §1.12a: قد تُبقي "موجود" حتى بعد إلغاء المُصنّع
    /// للمنبه فعلياً. هذا سبب وجود فاحص الأفق المستقل في decideNeedsRefresh
    /// أدناه — لا يعتمد على هذا الفحص وحده).
    private fun isArmedInOs(context: Context, id: Int): Boolean = try {
        PendingIntent.getBroadcast(
            context, id, Intent(context, receiverClassFor(id)),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        ) != null
    } catch (e: Exception) {
        false
    }

    // ════════════════════════════════════════════════════════════
    //  ✅ المرحلة 3: التدقيق الدوري (AzanWorker) — المقارنة الصِرفة
    //
    //  دور AzanWorker الصحيح: تدقيق كل 24 ساعة، لا إعادة حساب دائمة.
    //  يقرأ ما "يجب أن يكون مُسلَّحاً" (السجلّ الذي كتبته refresh() آخر
    //  مرّة) مقابل ما "يُقرّه نظام التشغيل فعلاً مُسلَّحاً"، ولا يستدعي
    //  refresh() إلا عند خلل حقيقي أو اقتراب نهاية الأفق.
    // ════════════════════════════════════════════════════════════

    /// ⅓ من الأفق (٧ أيام من ٢١) — نفس النسبة الموصى بها في §2.1.
    /// (بلا .toLong() — نفس نمط TIME_BUFFER_MS أعلاه: حاصل ضرب صحيح
    /// ينتهي بلاحقة L فيصبح Long تلقائياً، وهو تعبير ثابت صالح لـ const val)
    private const val HORIZON_REFRESH_THRESHOLD_MS =
        (DAYS_AHEAD / 3) * 24 * 60 * 60 * 1000L

    data class ReconcileResult(
        val shouldRefresh: Boolean,
        val reason: String,
        val ledgerSize: Int,
        val missingFromOs: Int,
        val horizonRemainingMs: Long,
    )

    /// القرار وحده — دالة صِرفة (pure) بلا أي وصول لـ AlarmManager/Context.
    /// قابلة للاختبار مباشرةً بـ JUnit عادي. راجع AlarmSchedulerTest.kt.
    internal fun decideNeedsRefresh(
        ledgerSize: Int,
        missingFromOsCount: Int,
        horizonRemainingMs: Long,
        horizonThresholdMs: Long = HORIZON_REFRESH_THRESHOLD_MS,
    ): ReconcileResult = when {
        ledgerSize == 0 -> ReconcileResult(
            true, "لا يوجد سجلّ مُسلَّح", ledgerSize, missingFromOsCount, horizonRemainingMs,
        )
        horizonRemainingMs <= 0L -> ReconcileResult(
            true, "انتهى الأفق كلياً", ledgerSize, missingFromOsCount, horizonRemainingMs,
        )
        missingFromOsCount > 0 -> ReconcileResult(
            true,
            "$missingFromOsCount من $ledgerSize مفقود من نظام التشغيل",
            ledgerSize, missingFromOsCount, horizonRemainingMs,
        )
        horizonRemainingMs < horizonThresholdMs -> ReconcileResult(
            true,
            "الأفق المتبقي (${horizonRemainingMs / 86_400_000L} يوم) دون الحدّ الأدنى",
            ledgerSize, missingFromOsCount, horizonRemainingMs,
        )
        else -> ReconcileResult(
            false, "السجلّ سليم والأفق كافٍ", ledgerSize, missingFromOsCount, horizonRemainingMs,
        )
    }

    /// الغلاف الحقيقي — يقرأ السجلّ/الأفق المحفوظين، يفحص كل معرّف في
    /// نظام التشغيل، ثم يُفوّض القرار لـ decideNeedsRefresh() الصِرفة.
    /// يُستدعى من AzanWorker.doWork() فقط — لا يُغيّر أي شيء بنفسه.
    fun reconcile(context: Context, nowMillis: Long = System.currentTimeMillis()): ReconcileResult {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ledger = readLedger(prefs)
        val horizonEnd = prefs.getString(KEY_HORIZON_END, null)?.toLongOrNull() ?: 0L
        val missing = ledger.count { id -> !isArmedInOs(context, id) }
        return decideNeedsRefresh(
            ledgerSize = ledger.size,
            missingFromOsCount = missing,
            horizonRemainingMs = horizonEnd - nowMillis,
        )
    }

    // ════════════════════════════════════════════════════════════
    //  الإلغاء (معرّفات المخطط القديم — sweepLegacyIdsOnce فقط)
    // ════════════════════════════════════════════════════════════
    private fun cancelExact(context: Context, am: AlarmManager, id: Int): Boolean = try {
        val pi = PendingIntent.getBroadcast(
            context, id, Intent(context, AzanAlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pi != null) { am.cancel(pi); pi.cancel(); true } else false
    } catch (e: Exception) {
        false
    }

    private fun cancelReminder(context: Context, am: AlarmManager, id: Int): Boolean = try {
        val pi = PendingIntent.getBroadcast(
            context, id, Intent(context, ReminderAlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pi != null) { am.cancel(pi); pi.cancel(); true } else false
    } catch (e: Exception) {
        false
    }

    // ════════════════════════════════════════════════════════════
    //  الإعدادات
    // ════════════════════════════════════════════════════════════
    private fun resolveParams(methodKey: String?, madhabKey: String?): CalculationParameters {
        val method = when (methodKey?.lowercase()) {
            "makkah", "umm_al_qura" -> CalculationMethod.UMM_AL_QURA
            "karachi"               -> CalculationMethod.KARACHI
            "isna", "north_america" -> CalculationMethod.NORTH_AMERICA
            "dubai"                 -> CalculationMethod.DUBAI
            "kuwait"                -> CalculationMethod.KUWAIT
            "qatar"                 -> CalculationMethod.QATAR
            "singapore"             -> CalculationMethod.SINGAPORE
            else                    -> CalculationMethod.EGYPTIAN
        }
        val params = method.getParameters()
        params.madhab = if (madhabKey?.lowercase() == "hanafi") Madhab.HANAFI else Madhab.SHAFI
        return params
    }

    private fun resolveDefaultSound(prefs: SharedPreferences): String =
        prefs.getString("flutter.last_sound_file_scheduled", null)
            ?: prefs.getString("flutter.settings_muezzin", null)?.let {
                when (it) {
                    "abdelbaset"      -> "azan_abdelbaset"
                    "mohamed_jazi"    -> "azan_mohamed_jazi"
                    "nasser_alqatami" -> "azan_nasser_alqatami"
                    else              -> "azan_abdelbaset"
                }
            } ?: "azan_abdelbaset"

    private fun formatTime(millis: Long): String =
        SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(millis)
}
