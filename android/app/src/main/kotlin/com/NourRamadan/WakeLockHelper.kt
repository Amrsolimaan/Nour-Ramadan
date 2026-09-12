package com.NourRamadan

import android.content.Context
import android.os.PowerManager
import android.util.Log

/**
 * WakeLockHelper — يضمن بقاء الجهاز مستيقظاً أثناء تشغيل الأذان
 * 
 * ✅ يحل مشكلة Doze Mode على Android 12+
 * ✅ يضمن تشغيل الأذان حتى في Deep Sleep
 * ✅ يتحرر تلقائياً بعد انتهاء المدة المحددة
 * 
 * الاستخدام:
 * ```kotlin
 * // احتفظ بالجهاز مستيقظاً لمدة دقيقة
 * WakeLockHelper.acquire(context, "AzanAlarm", 60_000L)
 * 
 * // يتحرر تلقائياً بعد 60 ثانية
 * // أو يمكن التحرير يدوياً:
 * WakeLockHelper.release()
 * ```
 */
object WakeLockHelper {
    private const val TAG = "WakeLockHelper"
    private var wakeLock: PowerManager.WakeLock? = null
    
    /**
     * احتفظ بالجهاز مستيقظاً لفترة محددة
     * 
     * @param context سياق التطبيق
     * @param tag اسم فريد للـ WakeLock (للتتبع في Logs)
     * @param timeout المدة بالميلي ثانية (افتراضي: دقيقة واحدة)
     * 
     * ملاحظة: يتحرر تلقائياً بعد انتهاء timeout لتجنب استنزاف البطارية
     */
    fun acquire(context: Context, tag: String, timeout: Long = 60_000L) {
        try {
            // تحرير أي wake lock قديم أولاً لتجنب التسريب
            release()
            
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "NourRamadan::$tag"
            )
            
            // acquire مع timeout تلقائي - يتحرر تلقائياً بعد انتهاء المدة
            // هذا يمنع استنزاف البطارية إذا نسينا استدعاء release()
            wakeLock?.acquire(timeout)
            
            Log.d(TAG, "✅ WakeLock acquired: $tag for ${timeout}ms")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to acquire WakeLock: ${e.message}")
        }
    }
    
    /**
     * تحرير WakeLock يدوياً (اختياري - يتحرر تلقائياً بعد timeout)
     * 
     * استخدم هذه الدالة إذا أردت تحرير WakeLock قبل انتهاء المدة المحددة
     */
    fun release() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "✅ WakeLock released manually")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to release WakeLock: ${e.message}")
        }
    }
    
    /**
     * التحقق من حالة WakeLock
     * 
     * @return true إذا كان WakeLock نشطاً حالياً
     */
    fun isHeld(): Boolean {
        return try {
            wakeLock?.isHeld ?: false
        } catch (e: Exception) {
            false
        }
    }
}
