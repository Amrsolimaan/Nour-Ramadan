package com.NourRamadan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

// ════════════════════════════════════════════════════════════════
//  AzanBootReceiver — استرداد كامل عند أي حدث يمحو/يُبطل الجدول
//
//  رغم اسمه، لا يُعالِج فقط الإقلاع — بل كل الأحداث التي تعني
//  "أُعيد الجهاز/التطبيق/الصلاحية إلى حالة تتطلّب إعادة بناء الجدول
//  من الصفر"، وهي أربعة (المرحلة 1-3 مجتمعة):
//
//  1) BOOT_COMPLETED / LOCKED_BOOT_COMPLETED / QUICKBOOT_POWERON:
//     منبهات AlarmManager تُمحى بالكامل عند إيقاف الجهاز:
//     "By default, all alarms are canceled when a device shuts down."
//
//  2) MY_PACKAGE_REPLACED (المرحلة 2): تحديث التطبيق يمحو المنبهات أيضاً.
//
//  3) SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED (المرحلة 3، Android 12+):
//     يُبث عند منح/سحب إذن "التنبيهات والمنبهات". التوثيق الرسمي يوصي
//     صريحاً بمعالجته "بمثل ما يُعالَج به BOOT_COMPLETED" — أهم حالة:
//     المستخدم يسحب الإذن (فتفشل كل الجدولة صامتة) ثم يعيد منحه من
//     الإعدادات دون فتح التطبيق مطلقاً — بلا هذا المستقبل تبقى الأذانات
//     معطّلة حتى يُفتح التطبيق يدوياً.
//
//  ❌ السلوك القديم (قبل المرحلة 2): rescheduleAzansDirectly() كانت
//     تقرأ flutter.azan_<id>_time بالمخطط النسبي القديم — ولم يكن أي
//     كود يكتب تلك المفاتيح فعلاً (§1.8)، فكانت تُسلّح صفر منبه دائماً.
//
//  ✅ الجديد: نداء واحد إلى AlarmScheduler.refresh() التي تُعيد بناء
//     أفق الـ21 يوماً من الصفر (الموقع + الإعدادات المحفوظة).
// ════════════════════════════════════════════════════════════════
class AzanBootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AzanBootReceiver"

        // Android 12+ (API 31) فقط — الثابت الحقيقي في AlarmManager
        // مُقيَّد بـ @RequiresApi(31)؛ نستخدم السلسلة النصّية مباشرةً
        // (نفس نمط QUICKBOOT_POWERON أدناه) بلا حاجة لأي فحص SDK_INT
        // عند المطابقة — الجهاز الذي minSdk=26 لن يُصدِر هذا الـ action
        // إطلاقاً فتبقى المقارنة بلا أثر (لا استثناء، لا حاجة لحارس).
        private const val ACTION_EXACT_ALARM_PERMISSION_STATE_CHANGED =
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"

        /// كل الأحداث التي تُشغِّل إعادة البناء الكاملة.
        ///
        /// دالة صِرفة (pure) — مجرّد مطابقة نصوص، بلا Context/Intent
        /// حقيقيين — قابلة للاختبار مباشرةً بـ JUnit عادي دون Robolectric.
        /// راجع AzanBootReceiverTest.kt.
        internal val RECOVERY_ACTIONS: Set<String> = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            ACTION_EXACT_ALARM_PERMISSION_STATE_CHANGED,
        )

        internal fun isRecoveryAction(action: String?): Boolean =
            action != null && action in RECOVERY_ACTIONS
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (!isRecoveryAction(action)) return

        Log.d(TAG, "🚀 $action — إعادة بناء أفق الجدولة بالكامل")

        val pending = goAsync()
        Thread {
            try {
                AlarmScheduler.refresh(context)
                // نبضة التدقيق الدورية (قد تكون أُلغيت مع الإقلاع)
                AzanWorker.schedule(context)
                Log.d(TAG, "✅ اكتملت إعادة البناء بعد: $action")
            } catch (e: Exception) {
                Log.e(TAG, "❌ فشلت إعادة البناء بعد $action: ${e.message}", e)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
