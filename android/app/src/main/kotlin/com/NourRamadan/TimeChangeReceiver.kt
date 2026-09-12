package com.NourRamadan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

// ════════════════════════════════════════════════════════════════
//  TimeChangeReceiver — المرحلة 2 (plan_azan_reliability.md §1.6)
//
//  ❌ السلوك القديم كان مُدمِّراً:
//     1. cancelAllOldAlarms()      → يُلغي كل المعرّفات الـ42
//     2. AlarmScheduler.refresh()  → كانت تفشل صامتةً (خطأ المفاتيح §1.8)
//     3. notifyFlutterToRecalculate() → startActivity() من BroadcastReceiver،
//        وهو محجوب على Android 10+ (قيود Background Activity Launch)
//
//     المحصّلة: كل تغيير توقيت صيفي/شتوي أو تصحيح ساعة كان يمحو
//     الجدول بالكامل ولا يُعيد شيئاً → صمت تام حتى يفتح المستخدم التطبيق.
//     (هذا تفسير أعطال التوقيت الصيفي في مصر تحديداً)
//
//  ✅ السلوك الجديد: نداء واحد إلى AlarmScheduler.refresh() التي:
//     • تحسب مجموعة الـ21 يوماً كاملةً أولاً
//     • تُسلّح الجديد
//     • ثم تُلغي المتقادم فقط
//     → لا توجد لحظة يكون فيها الجهاز بلا منبهات، ولو فشل الحساب
//       تبقى المنبهات القديمة عاملةً بدل أن تُمحى.
//
//  ملاحظة: لحظات الصلاة مطلقة (epoch ms) ومشتقّة من موضع الشمس، فلا
//  يُحرّكها تغيير المنطقة الزمنية. ما يتغيّر هو ربط التاريخ المحلي
//  بالمعرّفات — وإعادة الحساب الذرّية تتولّى ذلك.
//
//  ملاحظة 2: Intent.ACTION_TIME_CHANGED و "android.intent.action.TIME_SET"
//  نفس الثابت النصّي — البثّان في المنيفست مكرّران لكن بلا ضرر.
//  كلا ACTION_TIME_SET و ACTION_TIMEZONE_CHANGED مُستثنيان من قيود
//  البثّ الضمني على Android 8+، فالتسجيل في المنيفست صحيح.
// ════════════════════════════════════════════════════════════════
class TimeChangeReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "TimeChangeReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        when (action) {
            Intent.ACTION_TIME_CHANGED,
            "android.intent.action.TIME_SET",
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.d(TAG, "⏰ تغيّر الوقت/المنطقة (action=$action) — إعادة حساب ذرّية")

                // goAsync: الحساب قد يستغرق أكثر من مهلة onReceive المباشرة
                val pending = goAsync()
                Thread {
                    try {
                        AlarmScheduler.refresh(context)
                        Log.d(TAG, "✅ اكتملت إعادة الحساب بعد تغيير الوقت")
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ فشلت إعادة الحساب: ${e.message}", e)
                    } finally {
                        pending.finish()
                    }
                }.start()
            }

            else -> Log.d(TAG, "تجاهل action=$action")
        }
    }
}
