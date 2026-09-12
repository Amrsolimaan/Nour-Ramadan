package com.NourRamadan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

// ════════════════════════════════════════════════════════════════
//  AzanAlarmReceiver — النسخة النهائية
//
//  ✅ المرحلة 2: Kotlin لا يحسب الأوقات أبداً
//  يقرأ فقط ما حسبه Flutter وحفظه في SharedPreferences
//  Flutter هو المصدر الوحيد للحقيقة في حساب الأوقات
// ════════════════════════════════════════════════════════════════
class AzanAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "AzanAlarmReceiver"
        const val EXTRA_SOUND_FILE  = "sound_file"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_ALARM_ID    = "alarm_id"   // ✅ FIX M2: لتحديد صوت كل أذان
        // ✅ المرحلة 2: الوقت المقصود يُحمل في النيّة نفسها.
        // سابقاً كان الحرس يقرأ flutter.azan_<id>_time — وهو مفتاح تُعيد
        // refresh() كتابته، فكان المعرّف النسبي القديم يُقارَن بوقت يوم آخر
        // فيُكتم أذان صحيح بوصفه "مبكراً". راجع §1.11
        const val EXTRA_SCHEDULED_AT = "scheduled_at"
        const val PREFS_NAME = "FlutterSharedPreferences"
        private const val TIME_BUFFER_MS = 5 * 60 * 1000L

        // ✅ المرحلة 8: سطح التحقّق — آخر أذان فعلي أُطلق (بلا الشروق،
        // فهو ليس أذاناً). يقرأها system_diagnostics_service.dart عبر
        // PrefKeys.azanLastFiredAt/azanLastFiredPrayer المطابقة حرفياً.
        private const val KEY_LAST_FIRED_AT = "flutter.azan_last_fired_at"
        private const val KEY_LAST_FIRED_PRAYER = "flutter.azan_last_fired_prayer"
    }

    override fun onReceive(context: Context, intent: Intent) {
        WakeLockHelper.acquire(context, "AzanAlarm", 5 * 60_000L)

        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"
        val alarmId    = intent.getIntExtra(EXTRA_ALARM_ID, -1)
        val prefs      = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🔔 DIAGNOSTIC: Alarm received!")
        Log.d(TAG, "   Prayer: $prayerName")
        Log.d(TAG, "   Alarm ID: $alarmId")
        Log.d(TAG, "   Current time: ${java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(System.currentTimeMillis())}")
        Log.d(TAG, "═══════════════════════════════════════")

        // ════════════════════════════════════════════════════════════
        //  ✅ FIX: فحص الوقت - تجاهل الأذانات القديمة جداً
        //  
        //  السبب: عند تغيير الوقت، قد تُطلق أذانات قديمة لم تُلغى
        //  الحل: نفحص timestamp المحفوظ، إذا كان قديماً جداً نتجاهله
        //  
        //  القاعدة: إذا كان الأذان متأخر أكثر من 10 دقائق، نتجاهله
        // ════════════════════════════════════════════════════════════
        // ✅ المرحلة 2: حرس التقادم — من النيّة، لا من مفتاح متغيّر
        //
        //  نُبقي قاعدة "متأخر جداً ⇒ تجاهل" (منبه ظلّ عالقاً ثم أُطلق بعد
        //  ساعات لا يجب أن يؤذّن). وحُذفت قاعدة "مبكر ⇒ تجاهل" لأنها كانت
        //  تُكتم أذاناً صحيحاً عندما يتبدّل معنى المعرّف النسبي (§1.11).
        //  المعرّفات الآن مطلقة، والوقت المقصود يأتي في النيّة.
        val scheduledAt = intent.getLongExtra(EXTRA_SCHEDULED_AT, 0L)
        if (scheduledAt > 0L) {
            val lateBy = System.currentTimeMillis() - scheduledAt
            if (lateBy > 10 * 60 * 1000L) {
                Log.w(TAG, "⚠️ تجاهل منبه متأخر: $prayerName (${lateBy / 1000}s)")
                WakeLockHelper.release()
                return
            }
            Log.d(TAG, "✅ توقيت سليم: $prayerName (فرق ${lateBy / 1000}s)")
        }

        // ════════════════════════════════════════════════════════════
        //  ✅ FIX: قراءة الصوت مع ضمان عدم وجود null أبداً
        //  
        //  سلسلة الـ fallbacks (بالترتيب):
        //  1. flutter.azan_${alarmId}_sound (الصوت المحدد لهذا الأذان)
        //  2. flutter.last_sound_file_scheduled (آخر صوت تم جدولته)
        //  3. flutter.settings_muezzin (الصوت من الإعدادات)
        //  4. "azan_abdelbaset" (الصوت الافتراضي - مضمون 100%)
        // ════════════════════════════════════════════════════════════
        var resolvedSound: String? = null
        
        // المحاولة 1: الصوت المحدد لهذا الأذان
        if (alarmId != -1) {
            resolvedSound = prefs.getString("flutter.azan_${alarmId}_sound", null)
            if (resolvedSound != null) {
                Log.d(TAG, "✅ Sound from alarm ID: $resolvedSound")
            }
        }
        
        // المحاولة 2: آخر صوت تم جدولته
        if (resolvedSound == null) {
            resolvedSound = prefs.getString("flutter.last_sound_file_scheduled", null)
            if (resolvedSound != null) {
                Log.d(TAG, "✅ Sound from last scheduled: $resolvedSound")
            }
        }
        
        // المحاولة 3: الصوت من الإعدادات
        if (resolvedSound == null) {
            val muezzinSetting = prefs.getString("flutter.settings_muezzin", null)
            if (muezzinSetting != null) {
                resolvedSound = when (muezzinSetting) {
                    "abdelbaset"       -> "azan_abdelbaset"
                    "mohamed_jazi"     -> "azan_mohamed_jazi"
                    "nasser_alqatami"  -> "azan_nasser_alqatami"
                    else               -> "azan_abdelbaset"
                }
                Log.d(TAG, "✅ Sound from settings: $resolvedSound")
            }
        }
        
        // المحاولة 4: الصوت الافتراضي (مضمون 100%)
        if (resolvedSound == null) {
            resolvedSound = "azan_abdelbaset"
            Log.d(TAG, "✅ Sound from default fallback: $resolvedSound")
        }

        Log.d(TAG, "📡 Received: $prayerName | sound: $resolvedSound")

        // ── تشغيل الأذان أو إشعار الشروق ──────────────────────
        val isShurooq = prayerName.contains("شروق")
        if (!isShurooq) {
            // ✅ المرحلة 8: تسجيل "آخر أذان أُطلق" هنا بالضبط — نقطة
            // الإطلاق الفعلية الوحيدة (بعد اجتياز حرس التقادم أعلاه)،
            // قبل أي مسار فرعي قد يفشل (AzanForegroundService/AdhanActivity).
            prefs.edit()
                .putString(KEY_LAST_FIRED_AT, System.currentTimeMillis().toString())
                .putString(KEY_LAST_FIRED_PRAYER, prayerName)
                .apply()
            // ✅ resolvedSound مضمون 100% أنه ليس null
            playAzanDirectly(context, resolvedSound, prayerName)
        } else {
            showShurooqNotification(context)
            // ✅ FIX: لا نُطلق WakeLock هنا - سيُطلق بعد إعادة الجدولة
        }

        // ══════════════════════════════════════════════════════════
        //  ✅ PHASE 5: Race Condition Protection
        //  ✅ FIX: goAsync يُنفذ للجميع (الصلوات + الشروق)
        //  
        //  Use goAsync() with timeout monitoring
        //  If operations take > 5 seconds, delegate to WorkManager
        //  This prevents BroadcastReceiver timeout (10 seconds)
        //  
        //  CRITICAL: الشروق يجب أن يُعيد جدولة الصلوات التالية
        //  بدون هذا، أذان الظهر سيفشل بعد الشروق
        // ══════════════════════════════════════════════════════════
        // ══════════════════════════════════════════════════════════
        //  ✅ المرحلة 2: تجديد الأفق بعد كل أذان
        //
        //  AlarmScheduler.refresh() ذرّية ومالِكة وحيدة للجدولة:
        //  تحسب 21 يوماً، تُسلّح، ثم تُلغي المتقادم فقط.
        //  حُذفت حلقات إعادة التسليح المحلية التي كانت تستخدم المخطط
        //  النسبي القديم (100-105/210-265) لأنها تُعارض المعرّفات المطلقة.
        // ══════════════════════════════════════════════════════════
        val pendingResult = goAsync()
        val startTime = System.currentTimeMillis()

        Thread {
            try {
                AlarmScheduler.refresh(context)
            } catch (e: Exception) {
                Log.e(TAG, "❌ فشل refresh بعد الأذان: ${e.message}", e)
                // احتياط: نبضة Worker تُحاول مرّة أخرى
                try {
                    AzanWorker.rescheduleNow(context)
                } catch (ex: Exception) {
                    Log.e(TAG, "❌ فشل احتياط Worker: ${ex.message}")
                }
            } finally {
                Log.d(TAG, "✅ اكتمل تجديد الأفق في ${System.currentTimeMillis() - startTime}ms")
                pendingResult.finish()
            }
        }.start()
    }

    private fun playAzanDirectly(context: Context, soundFile: String, prayerName: String) {
        try {
            // ── Start Audio Service ────────────────────────────────
            val serviceIntent = Intent(context, AzanForegroundService::class.java).apply {
                action = AzanForegroundService.ACTION_PLAY
                putExtra(AzanForegroundService.EXTRA_SOUND_FILE,  soundFile)
                putExtra(AzanForegroundService.EXTRA_PRAYER_NAME, prayerName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "✅ AzanForegroundService started: $prayerName")
            
            // ── Launch UI Activity (PHASE 1 INJECTION) ─────────────
            // This is the critical addition that wakes the screen
            val activityIntent = Intent(context, AdhanActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(AdhanActivity.EXTRA_PRAYER_NAME, prayerName)
                putExtra(AdhanActivity.EXTRA_SOUND_FILE, soundFile)
            }
            context.startActivity(activityIntent)
            Log.d(TAG, "✅ AdhanActivity launched: $prayerName")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ playAzanDirectly error: ${e.message}")
        } finally {
            // ✅ WakeLock managed by existing WakeLockHelper
            // Release happens after both service and activity are started
            WakeLockHelper.release()
        }
    }

    // ════════════════════════════════════════════════════════════
    //  إشعار الشروق
    // ════════════════════════════════════════════════════════════
    private fun showShurooqNotification(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                "shurooq_channel", "إشعارات الشروق",
                android.app.NotificationManager.IMPORTANCE_HIGH
            ).apply {
                enableVibration(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            context.getSystemService(android.app.NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
        val openPending = android.app.PendingIntent.getActivity(
            context, 51,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        try {
            androidx.core.app.NotificationManagerCompat.from(context).notify(
                9002,
                androidx.core.app.NotificationCompat.Builder(context, "shurooq_channel")
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("🌅 وقت الشروق")
                    .setContentText("انقضاء وقت الفجر - وقت نهي عن الصلاة")
                    .setColor(0xFF221A40.toInt()).setColorized(true)
                    .setContentIntent(openPending)
                    .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                    .setAutoCancel(true)
                    .setVisibility(androidx.core.app.NotificationCompat.VISIBILITY_PUBLIC)
                    .build()
            )
            Log.d(TAG, "✅ Shurooq notification shown")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Shurooq notification error: ${e.message}")
        }
    }
}