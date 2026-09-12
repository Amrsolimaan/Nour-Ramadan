package com.NourRamadan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

// ════════════════════════════════════════════════════════════════
//  ReminderAlarmReceiver — إشعار التذكير 15 دقيقة قبل الصلاة
//
//  ✅ PHASE 2: مستقبل منفصل للتذكيرات
//  يعمل بشكل مستقل عن AzanAlarmReceiver
//  يضمن عمل التذكيرات حتى مع إغلاق التطبيق
// ════════════════════════════════════════════════════════════════
class ReminderAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "ReminderAlarmReceiver"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_ALARM_ID    = "alarm_id"    // ✅ FIX B: لتمييز كل تذكير
        const val REMINDER_CHANNEL_ID = "prayer_reminder_native"
        // ✅ FIX A: حُذف REMINDER_NOTIF_ID الثابت — كل تذكير له ID خاص (alarm_id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"

        // ✅ FIX B: قراءة الـ ID الخاص بهذا التذكير من الـ intent
        // السبب: REMINDER_NOTIF_ID=9003 الثابت كان يجعل كل التذكيرات تكتب فوق بعض
        val notifId = intent.getIntExtra(EXTRA_ALARM_ID, 9003)

        // ✅ لا تذكير للشروق — ليست صلاة
        if (prayerName.contains("شروق") || prayerName.contains("الشروق")) {
            Log.d(TAG, "⏭️ Skipping reminder for Shurooq")
            return
        }

        // ✅ التحقق من إعداد "تذكير قبل الصلاة 15 دقيقة"
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val reminderEnabled = prefs.getBoolean("flutter.settings_prayer_reminder", true)

        if (!reminderEnabled) {
            Log.d(TAG, "⏭️ Prayer reminder disabled in settings - skipping")
            return
        }

        Log.d(TAG, "🔔 Reminder triggered for: $prayerName (notifId=$notifId)")
        showReminderNotification(context, prayerName, notifId)
    }

    // ════════════════════════════════════════════════════════════
    //  عرض إشعار التذكير (15 دقيقة قبل الصلاة)
    // ════════════════════════════════════════════════════════════
    private fun showReminderNotification(context: Context, prayerName: String, notifId: Int) {
        // إنشاء قناة التذكير إذا لم تكن موجودة
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                REMINDER_CHANNEL_ID,
                "تذكير الصلاة",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعارات تذكير بمواعيد الصلاة"
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        // تحديد emoji حسب نوع الصلاة
        val emoji = when {
            prayerName.contains("فجر")   -> "🌙"
            prayerName.contains("ظهر")  -> "☀️"
            prayerName.contains("عصر")  -> "🌤️"
            prayerName.contains("مغرب") -> "🌇"
            prayerName.contains("عشاء") -> "🌃"
            else                         -> "🕌"
        }

        // ✅ FIX C: استخدام notifId كـ request code بدلاً من 40 الثابت
        // السبب: request code=40 الثابت كان يجعل كل PendingIntents تشترك
        // الأخير يكتب فوق السابق → فتح التطبيق من تذكير الفجر يفتح صفحة الظهر
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            // ✅ FIX C: حفظ في SharedPreferences بدلاً من navigate_to extra
            // السبب: MainActivity يقرأ من SharedPreferences فقط (pending_navigation)
            // putExtra("navigate_to",...) كان يُهمَل تماماً
        }

        // ✅ حفظ pending_navigation في SharedPreferences قبل فتح MainActivity
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putString("flutter.pending_navigation", "open_prayer_times").apply()
        } catch (e: Exception) {
            Log.w(TAG, "Could not save pending_navigation: ${e.message}")
        }

        val openPending = PendingIntent.getActivity(
            context,
            notifId,   // ✅ FIX C: request code فريد لكل تذكير
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // بناء الإشعار
        val notification = NotificationCompat.Builder(context, REMINDER_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("$emoji تذكير بصلاة $prayerName")
            .setContentText("باقي 15 دقيقة على موعد صلاة $prayerName")
            .setColor(0xFF221A40.toInt())
            .setColorized(true)
            .setContentIntent(openPending)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        // عرض الإشعار بـ ID فريد لكل صلاة
        try {
            NotificationManagerCompat.from(context).notify(notifId, notification)
            Log.d(TAG, "✅ Reminder shown: $prayerName (notifId=$notifId)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show reminder: ${e.message}")
        }
    }
}