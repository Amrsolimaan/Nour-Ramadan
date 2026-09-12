package com.NourRamadan

import android.app.AlarmManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

// ════════════════════════════════════════════════════════════════
//  AzanWorker — نبضة تدقيق دورية (وليست آلية التوقيت)
//
//  الدور الصحيح لـ WorkManager (plan_azan_reliability.md §2.5):
//  وظيفة دورية تتحقّق أن الجدول ما زال مُسلَّحاً وتُجدّد الأفق.
//  ❌ ليست الآلية التي تُطلق الأذان — ذلك دور setAlarmClock() فقط،
//     لأن WorkManager واجهة عمل قابل للتأجيل بطبيعتها.
//
//  المرحلة 2:
//  • الفاصل 24 ساعة (كان 4) — مع أفق 21 يوماً لم يبقَ داعٍ للإلحاح.
//  • ExistingPeriodicWorkPolicy.UPDATE (كان KEEP) — وإلا بقيت النسخ
//    المُثبَّتة على الفاصل القديم إلى الأبد. (§1.12c)
//  • حُذفت حلقة إعادة التسليح المحلية ومنطق "فجر الطوارئ" الانعكاسي:
//    AlarmScheduler.refresh() الذرّية تُغطّيهما، ووجود كاتبَين للجدولة
//    كان يُنتج معرّفات متعارضة.
//
//  المرحلة 3: تدقيق حقيقي بدل إعادة حساب دائمة.
//  ❌ كان doWork() يستدعي AlarmScheduler.refresh() في كل نبضة دون شرط —
//     يعمل، لكنه يُعيد حساب/تسليح 231 منبهاً كل 24 ساعة بلا داعٍ في
//     الغالبية العظمى من الحالات (السجلّ سليم والأفق كافٍ فعلاً).
//  ✅ الآن: AlarmScheduler.reconcile() يقرأ السجلّ المحفوظ، يفحص كل
//     معرّف في نظام التشغيل، ويُرجع قراراً — لا يُستدعى refresh() إلا
//     عند خلل حقيقي (معرّف مفقود من نظام التشغيل) أو اقتراب نهاية
//     الأفق (أقل من ⅓ الأفق المتبقي). راجع §2.5 وتدقيق المرحلة 3.
// ════════════════════════════════════════════════════════════════
class AzanWorker(
    private val context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "AzanWorker"
        private const val WORK_NAME = "azan_daily_refresh"
        private const val INTERVAL_HOURS = 24L

        fun schedule(context: Context) {
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                PeriodicWorkRequestBuilder<AzanWorker>(INTERVAL_HOURS, TimeUnit.HOURS).build()
            )
            Log.d(TAG, "✅ نبضة التدقيق مُسجَّلة (كل ${INTERVAL_HOURS}h)")
        }

        fun rescheduleNow(context: Context) {
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                PeriodicWorkRequestBuilder<AzanWorker>(INTERVAL_HOURS, TimeUnit.HOURS).build()
            )
            Log.d(TAG, "🔄 أُعيد تسجيل نبضة التدقيق")
        }
    }

    override suspend fun doWork(): Result {
        Log.d(TAG, "⚙️ نبضة التدقيق — بدء")

        return try {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            if (alarmManager == null) {
                Log.e(TAG, "❌ AlarmManager غير متاح")
                return Result.retry()
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms()
            ) {
                // الإذن مسحوب — لا جدوى من المحاولة حتى يمنحه المستخدم
                Log.e(TAG, "❌ إذن SCHEDULE_EXACT_ALARM مسحوب")
                return Result.success()
            }

            // ✅ المرحلة 3: تدقيق فعلي — سجلّ محفوظ مقابل ما يُقرّه نظام
            // التشغيل، بدل استدعاء refresh() في كل نبضة بلا شرط.
            val decision = AlarmScheduler.reconcile(context)
            Log.d(
                TAG,
                "🔍 تدقيق: ${decision.reason} " +
                    "(سجلّ=${decision.ledgerSize}، مفقود=${decision.missingFromOs}، " +
                    "أفق متبقٍ=${decision.horizonRemainingMs / 86_400_000L}يوم)",
            )

            if (decision.shouldRefresh) {
                AlarmScheduler.refresh(context)
            } else {
                Log.d(TAG, "✅ لا حاجة لإعادة الحساب — السجلّ سليم")
            }

            logBatteryOptimizationState()

            Log.d(TAG, "✅ نبضة التدقيق — اكتملت")
            Result.success()
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException (قيد مُصنّع؟): ${e.message}")
            Result.retry()
        } catch (e: Exception) {
            Log.e(TAG, "❌ خطأ في النبضة: ${e.message}", e)
            Result.retry()
        }
    }

    // ════════════════════════════════════════════════════════════
    //  تشخيص: هل التطبيق ما زال معفيًّا من تحسين البطارية؟
    //  (تسجيل فقط — التنبيه UX يُعالَج في المرحلة 4)
    // ════════════════════════════════════════════════════════════
    private fun logBatteryOptimizationState() {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            if (!pm.isIgnoringBatteryOptimizations(context.packageName)) {
                Log.w(TAG, "⚠️ تحسين البطارية مُفعَّل — نبضة التدقيق قد تتأخر")
            }
        } catch (e: Exception) {
            Log.w(TAG, "تعذّر فحص تحسين البطارية: ${e.message}")
        }
    }
}
