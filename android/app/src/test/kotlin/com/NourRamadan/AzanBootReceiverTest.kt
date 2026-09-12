package com.NourRamadan

import android.content.Intent
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// ════════════════════════════════════════════════════════════════
//  AzanBootReceiverTest — تدقيق المرحلة 3 (plan_azan_reliability.md)
//
//  يختبر AzanBootReceiver.isRecoveryAction() — الدالة الصِرفة (pure)
//  التي يستخدمها onReceive() فعلياً لتقرير أي بثّ يُطلق إعادة البناء.
//  اختبار JVM عادي: مجرّد مقارنة نصوص مع ثوابت Intent.ACTION_* —
//  هذه ثوابت compile-time (public static final String) تُحلّ كقيم
//  حرفية عند التصريف، فلا تحتاج Robolectric ولا أي محاكاة لإطار
//  Android إطلاقاً.
//
//  ما لا يُختبر هنا عمداً: onReceive() نفسها (goAsync/Thread/refresh)
//  تحتاج Context/Intent حقيقيين أو Robolectric — نفس القيد المقبول
//  في TimeChangeReceiver ولا داعي لتكراره.
// ════════════════════════════════════════════════════════════════
class AzanBootReceiverTest {

    @Test
    fun `boot completed is a recovery action`() {
        assertTrue(AzanBootReceiver.isRecoveryAction(Intent.ACTION_BOOT_COMPLETED))
    }

    @Test
    fun `locked boot completed is a recovery action`() {
        assertTrue(AzanBootReceiver.isRecoveryAction(Intent.ACTION_LOCKED_BOOT_COMPLETED))
    }

    @Test
    fun `my package replaced is a recovery action`() {
        assertTrue(AzanBootReceiver.isRecoveryAction(Intent.ACTION_MY_PACKAGE_REPLACED))
    }

    @Test
    fun `oem quickboot variants are recovery actions`() {
        assertTrue(AzanBootReceiver.isRecoveryAction("android.intent.action.QUICKBOOT_POWERON"))
        assertTrue(AzanBootReceiver.isRecoveryAction("com.htc.intent.action.QUICKBOOT_POWERON"))
    }

    @Test
    fun `exact alarm permission state changed is a recovery action`() {
        // ✅ المرحلة 3: Android 12+ — منح/سحب إذن SCHEDULE_EXACT_ALARM
        assertTrue(
            AzanBootReceiver.isRecoveryAction(
                "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
            ),
        )
    }

    @Test
    fun `unrelated actions are not recovery actions`() {
        assertFalse(AzanBootReceiver.isRecoveryAction(Intent.ACTION_TIME_CHANGED))
        assertFalse(AzanBootReceiver.isRecoveryAction(Intent.ACTION_TIMEZONE_CHANGED))
        assertFalse(AzanBootReceiver.isRecoveryAction("android.intent.action.SCREEN_ON"))
        assertFalse(AzanBootReceiver.isRecoveryAction("com.example.random.ACTION"))
    }

    @Test
    fun `null action is not a recovery action`() {
        assertFalse(AzanBootReceiver.isRecoveryAction(null))
    }

    @Test
    fun `RECOVERY_ACTIONS contains exactly the six documented actions`() {
        assertTrue(AzanBootReceiver.RECOVERY_ACTIONS.size == 6)
    }
}
