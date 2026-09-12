package com.NourRamadan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// ════════════════════════════════════════════════════════════════
//  AzanPlugin — مسجَّل في كل FlutterEngine (بما فيها الخلفية)
//  ✅ الإصلاح: يعالج الآن scheduleExactAlarm و cancelAlarm
//  حتى لا تضيع الطلبات عندما لا تكون MainActivity هي المعالجة
// ════════════════════════════════════════════════════════════════
class AzanPlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        private const val TAG = "AzanPlugin"
        private const val CHANNEL = "com.nour_ramadan/azan_service"
    }

    private lateinit var channel: MethodChannel
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        Log.d(TAG, "✅ AzanPlugin attached to engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Application context is null", null)
            return
        }

        Log.d(TAG, "Method called: ${call.method}")

        when (call.method) {

            // ── تشغيل الأذان فوراً ────────────────────────────────
            "playAzan" -> {
                // ✅ PHASE 4: تم تعطيل هذه الوظيفة - الأذان يعمل مباشرة من AlarmManager
                Log.d(TAG, "⚠️ playAzan deprecated - using direct AlarmManager scheduling")
                result.success(null)
            }

            // ── إيقاف الأذان ──────────────────────────────────────
            "stopAzan" -> {
                // ✅ PHASE 4: تم تعطيل هذه الوظيفة - الأذان يعمل مباشرة من AlarmManager
                Log.d(TAG, "⚠️ stopAzan deprecated - using direct AlarmManager scheduling")
                result.success(null)
            }

            // ══════════════════════════════════════════════════════════
            //  ✅ PHASE 2: Gold Standard Scheduling with setAlarmClock()
            //  
            //  Why setAlarmClock()?
            //  1. Highest priority in Doze Mode (no 9-alarm limit)
            //  2. Shows in system alarm UI (user can see upcoming prayers)
            //  3. Guaranteed to fire even in aggressive power saving
            //  4. Screen wakes automatically (works with Phase 1 fullScreenIntent)
            //  
            //  AlarmClockInfo metadata:
            //  - triggerTime: When alarm fires
            //  - showIntent: What opens when user taps system alarm icon
            //  
            //  This is the GOLD STANDARD for time-critical alarms like prayer times
            // ══════════════════════════════════════════════════════════
            "scheduleExactAlarm" -> {
                try {
                    val id         = call.argument<Int>("id")         ?: return
                    val timeMillis = call.argument<Long>("timeMillis") ?: return
                    val soundFile  = call.argument<String>("soundFile")  ?: ""
                    val prayerName = call.argument<String>("prayerName") ?: "الصلاة"

                    val alarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

                    // ── Create alarm intent ────────────────────────────
                    val intent = Intent(ctx, AzanAlarmReceiver::class.java).apply {
                        putExtra(AzanAlarmReceiver.EXTRA_SOUND_FILE,  soundFile)
                        putExtra(AzanAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
                        putExtra(AzanAlarmReceiver.EXTRA_ALARM_ID,    id)
                    }

                    val pendingIntent = PendingIntent.getBroadcast(
                        ctx,
                        id,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    // ── Create show intent (opens app when user taps alarm icon) ──
                    val showIntent = Intent(ctx, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra("navigate_to", "open_prayer_times")
                    }
                    val showPendingIntent = PendingIntent.getActivity(
                        ctx,
                        id + 10000,  // Unique request code
                        showIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    // ══════════════════════════════════════════════════
                    //  ✅ PHASE 2: Use setAlarmClock() - Gold Standard
                    //  
                    //  This replaces setExactAndAllowWhileIdle()
                    //  Provides maximum reliability for prayer times
                    // ══════════════════════════════════════════════════
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        val alarmClockInfo = AlarmManager.AlarmClockInfo(
                            timeMillis,
                            showPendingIntent  // Opens app when user taps system alarm icon
                        )
                        alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                        Log.d(TAG, "✅ setAlarmClock (GOLD): id=$id, prayer=$prayerName, time=$timeMillis")
                    } else {
                        // Fallback for Android <21 (very rare)
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeMillis, pendingIntent)
                        Log.d(TAG, "✅ setExact (fallback): id=$id, prayer=$prayerName")
                    }

                    result.success(null)

                } catch (e: Exception) {
                    Log.e(TAG, "❌ scheduleExactAlarm error: ${e.message}")
                    result.error("ALARM_ERROR", e.message, null)
                }
            }

            // ✅ جدولة تذكير 15 دقيقة قبل الصلاة ─────────────────
            "scheduleReminderAlarm" -> {
                try {
                    val id         = call.argument<Int>("id")         ?: return
                    val timeMillis = call.argument<Long>("timeMillis") ?: return
                    val prayerName = call.argument<String>("prayerName") ?: "الصلاة"

                    val alarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

                    // ✅ FIX: فحص canScheduleExactAlarms كان غائباً هنا
                    // scheduleExactAlarm يتحقق لكن scheduleReminderAlarm كان يجدول بدون فحص
                    // على Android 12+ بدون إذن → setExactAndAllowWhileIdle تفشل بصمت
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        if (!alarmManager.canScheduleExactAlarms()) {
                            Log.e(TAG, "❌ scheduleReminderAlarm: No SCHEDULE_EXACT_ALARM permission")
                            result.error("NO_PERMISSION", "SCHEDULE_EXACT_ALARM not granted", null)
                            return
                        }
                    }

                    val intent = Intent(ctx, ReminderAlarmReceiver::class.java).apply {
                        putExtra(ReminderAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
                        putExtra(ReminderAlarmReceiver.EXTRA_ALARM_ID, id)  // ✅ FIX: ID فريد لكل تذكير
                    }

                    val pendingIntent = PendingIntent.getBroadcast(
                        ctx,
                        id,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            timeMillis,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setExact(
                            AlarmManager.RTC_WAKEUP,
                            timeMillis,
                            pendingIntent
                        )
                    }

                    Log.d(TAG, "✅ scheduleReminderAlarm: id=$id, prayer=$prayerName, time=$timeMillis")
                    result.success(null)

                } catch (e: Exception) {
                    Log.e(TAG, "❌ scheduleReminderAlarm error: ${e.message}")
                    result.error("REMINDER_ERROR", e.message, null)
                }
            }

            // ✅ الإصلاح الرئيسي: إلغاء أذان محدد ─────────────────
            "cancelAlarm" -> {
                try {
                    val id = call.argument<Int>("id") ?: return

                    val alarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val intent = Intent(ctx, AzanAlarmReceiver::class.java).apply {
                        putExtra(AzanAlarmReceiver.EXTRA_ALARM_ID, id)  // ✅ FIX M2
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        ctx,
                        id,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    alarmManager.cancel(pendingIntent)
                    pendingIntent.cancel()

                    Log.d(TAG, "✅ cancelAlarm: id=$id")
                    result.success(null)

                } catch (e: Exception) {
                    Log.e(TAG, "❌ cancelAlarm error: ${e.message}")
                    result.error("CANCEL_ERROR", e.message, null)
                }
            }

            // ══════════════════════════════════════════════════════════
            //  ✅ PHASE 3: تحديث فوري للمحرك الناتيف (AlarmScheduler)
            //
            //  يُستدعى من Dart في نهاية _scheduleAllNotifications:
            //  يعيد حساب أفق 21 يوماً ذرّياً ويطبق تغييرات الإعدادات فوراً
            //  (تبديل التذكير / تغيير المؤذن) بدل انتظار نبضة Worker.
            // ══════════════════════════════════════════════════════════
            "refreshAlarms" -> {
                try {
                    AlarmScheduler.refresh(ctx)
                    Log.d(TAG, "✅ Native scheduler refreshed from Dart")
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "❌ refreshAlarms error: ${e.message}")
                    result.error("REFRESH_ERROR", e.message, null)
                }
            }

            // ══════════════════════════════════════════════════════════
            //  ✅ PHASE 2: Android 14+ Permission Logic
            //  
            //  Android 14 (API 34) introduced USE_EXACT_ALARM as a
            //  non-revocable permission for alarm clock apps.
            //  
            //  Permission Strategy:
            //  - Android 14+: Prefer USE_EXACT_ALARM (no user prompt)
            //  - Android 12-13: Use SCHEDULE_EXACT_ALARM (requires user grant)
            //  - Android <12: No permission needed
            //  
            //  This ensures optimal user experience on latest Android versions
            // ══════════════════════════════════════════════════════
            "hasExactAlarmPermission" -> {
                when {
                    // Android 14+ (API 34+): Check USE_EXACT_ALARM first
                    Build.VERSION.SDK_INT >= 34 -> {
                        val alarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        // USE_EXACT_ALARM is automatically granted if declared in manifest
                        // No runtime check needed, but we verify canScheduleExactAlarms() as fallback
                        val hasPermission = alarmManager.canScheduleExactAlarms()
                        Log.d(TAG, "✅ Android 14+: USE_EXACT_ALARM status = $hasPermission")
                        result.success(hasPermission)
                    }
                    // Android 12-13 (API 31-33): Use SCHEDULE_EXACT_ALARM
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                        val alarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val hasPermission = alarmManager.canScheduleExactAlarms()
                        Log.d(TAG, "✅ Android 12-13: SCHEDULE_EXACT_ALARM status = $hasPermission")
                        result.success(hasPermission)
                    }
                    // Android <12: No permission needed
                    else -> {
                        Log.d(TAG, "✅ Android <12: No exact alarm permission needed")
                        result.success(true)
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            //  ✅ NEW: Check USE_FULL_SCREEN_INTENT Permission
            //  
            //  Android 11+ (API 29+): Required for full-screen intents
            //  Android 14+ (API 34+): Requires explicit user grant
            //  
            //  This permission allows AdhanActivity to show over lockscreen
            //  and wake the screen when alarm fires
            // ══════════════════════════════════════════════════════════
            "hasFullScreenIntentPermission" -> {
                when {
                    // Android 14+ (API 34+): Check if permission is granted
                    Build.VERSION.SDK_INT >= 34 -> {
                        try {
                            val notificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) 
                                as android.app.NotificationManager
                            val hasPermission = notificationManager.canUseFullScreenIntent()
                            Log.d(TAG, "✅ Android 14+: USE_FULL_SCREEN_INTENT status = $hasPermission")
                            result.success(hasPermission)
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Failed to check full screen intent permission: ${e.message}")
                            result.success(false)
                        }
                    }
                    // Android 11-13 (API 29-33): Permission granted automatically if in manifest
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                        Log.d(TAG, "✅ Android 11-13: USE_FULL_SCREEN_INTENT auto-granted")
                        result.success(true)
                    }
                    // Android <11: Not needed
                    else -> {
                        Log.d(TAG, "✅ Android <11: USE_FULL_SCREEN_INTENT not needed")
                        result.success(true)
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            //  ✅ NEW: Request USE_FULL_SCREEN_INTENT Permission
            //  
            //  Opens settings on Android 14+ to allow full-screen intents
            //  This is required for AdhanActivity to show over lockscreen
            // ══════════════════════════════════════════════════════════
            "requestFullScreenIntentPermission" -> {
                when {
                    // Android 14+ (API 34+): Open settings
                    Build.VERSION.SDK_INT >= 34 -> {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                            intent.data = android.net.Uri.parse("package:${ctx.packageName}")
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            ctx.startActivity(intent)
                            Log.d(TAG, "✅ Opened USE_FULL_SCREEN_INTENT settings (Android 14+)")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Failed to open full screen intent settings: ${e.message}")
                            result.error("PERMISSION_ERROR", e.message, null)
                        }
                    }
                    // Android <14: No action needed
                    else -> {
                        Log.d(TAG, "✅ Android <14: No full screen intent permission request needed")
                        result.success(null)
                    }
                }
            }

            // ══════════════════════════════════════════════════════════
            //  ✅ PHASE 2: Smart Permission Request
            //  
            //  Android 14+: USE_EXACT_ALARM is declared in manifest
            //  and automatically granted (no user action needed)
            //  
            //  Android 12-13: Opens settings for SCHEDULE_EXACT_ALARM
            //  (requires user to manually grant permission)
            // ══════════════════════════════════════════════════════════
            "requestExactAlarmPermission" -> {
                when {
                    // Android 14+: USE_EXACT_ALARM is auto-granted
                    Build.VERSION.SDK_INT >= 34 -> {
                        Log.d(TAG, "✅ Android 14+: USE_EXACT_ALARM auto-granted (no user action needed)")
                        // Still check if permission is actually available
                        val alarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        if (!alarmManager.canScheduleExactAlarms()) {
                            // Fallback: Open settings if somehow permission is missing
                            try {
                                val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                ctx.startActivity(intent)
                                Log.d(TAG, "⚠️ Opened settings as fallback")
                            } catch (e: Exception) {
                                Log.e(TAG, "❌ Failed to open settings: ${e.message}")
                            }
                        }
                        result.success(null)
                    }
                    // Android 12-13: Requires user action
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            ctx.startActivity(intent)
                            Log.d(TAG, "✅ Opened SCHEDULE_EXACT_ALARM settings (Android 12-13)")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ requestExactAlarmPermission error: ${e.message}")
                            result.error("PERMISSION_ERROR", e.message, null)
                        }
                    }
                    // Android <12: No action needed
                    else -> {
                        Log.d(TAG, "✅ Android <12: No permission request needed")
                        result.success(null)
                    }
                }
            }

            // ── طلب إعفاء من Battery Optimization ──────────────────
            "requestBatteryExemption" -> {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = android.net.Uri.parse("package:${ctx.packageName}")
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    ctx.startActivity(intent)
                    Log.d(TAG, "✅ Opened battery optimization settings")
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "❌ requestBatteryExemption error: ${e.message}")
                    result.error("BATTERY_EXEMPTION_ERROR", e.message, null)
                }
            }

            // ✅ المرحلة 4: هل هذا الجهاز من مصنّع معروف بقيود صارمة؟
            // يُستخدم من الشاشة السياقية لتقرير: زر "منح الصلاحية" يفتح
            // إعدادات المصنّع الخاصة (Xiaomi/Vivo/Oppo/Huawei) أم طلب
            // الإعفاء العام المباشر (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).
            "hasStrictOemRestrictions" -> {
                try {
                    result.success(ManufacturerHelper.hasStrictRestrictions())
                } catch (e: Exception) {
                    Log.e(TAG, "❌ hasStrictOemRestrictions error: ${e.message}")
                    result.error("OEM_DETECTION_ERROR", e.message, null)
                }
            }

            // ✅ FIX #8: فتح إعدادات المصنّع الخاصة
            "openManufacturerSettings" -> {
                try {
                    val opened = ManufacturerHelper.openAutostartSettings(ctx) ||
                                ManufacturerHelper.openBatterySettings(ctx)
                    Log.d(TAG, "✅ Opened manufacturer settings: $opened")
                    result.success(opened)
                } catch (e: Exception) {
                    Log.e(TAG, "❌ openManufacturerSettings error: ${e.message}")
                    result.error("MANUFACTURER_ERROR", e.message, null)
                }
            }

            // ✅ FIX #8: الحصول على تعليمات المصنّع
            "getManufacturerInstructions" -> {
                try {
                    val instructions = ManufacturerHelper.getInstructions(ctx)
                    Log.d(TAG, "✅ Got manufacturer instructions")
                    result.success(instructions)
                } catch (e: Exception) {
                    Log.e(TAG, "❌ getManufacturerInstructions error: ${e.message}")
                    result.error("MANUFACTURER_ERROR", e.message, null)
                }
            }

            // ── فحص Battery Optimization ──────────────────────────
            "isBatteryOptimizationDisabled" -> {
                try {
                    val pm = ctx.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(ctx.packageName))
                } catch (e: Exception) {
                    result.error("BATTERY_ERROR", e.message, null)
                }
            }

            // ══════════════════════════════════════════════════════════════
            //  ✅ FIX: إعادة جدولة من تغيير الوقت/المنطقة الزمنية
            //  
            //  يُستدعى من TimeChangeReceiver عند تغيير وقت النظام
            //  Flutter سيُعيد حساب الأوقات وجدولة الأذانات بـ timestamps جديدة
            // ══════════════════════════════════════════════════════════════
            "rescheduleFromTimeChange" -> {
                Log.d(TAG, "🔄 Reschedule from time/timezone change - notifying Flutter")
                result.success(null)
            }

            // ── بدء إشعار العداد التنازلي ──────────────────────────
            "startCountdown" -> {
                // ✅ PHASE 4: تم تعطيل هذه الوظيفة - لا حاجة للعداد التنازلي
                Log.d(TAG, "⚠️ startCountdown deprecated - countdown feature disabled")
                result.success(null)
            }

            // ── إيقاف إشعار العداد التنازلي ───────────────────────
            "stopCountdown" -> {
                // ✅ PHASE 4: تم تعطيل هذه الوظيفة - لا حاجة للعداد التنازلي
                Log.d(TAG, "⚠️ stopCountdown deprecated - countdown feature disabled")
                result.success(null)
            }

            else -> result.notImplemented()

        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Log.d(TAG, "AzanPlugin detached from engine")
    }
}