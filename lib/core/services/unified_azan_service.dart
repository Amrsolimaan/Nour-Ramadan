import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'app_logger.dart';

// ════════════════════════════════════════════════════════════════
//  Unified Azan Service
// ════════════════════════════════════════════════════════════════

typedef OnNotificationAction = void Function(String actionId);
OnNotificationAction? onNotificationActionCallback;

const _azanChannel = MethodChannel('com.nour_ramadan/azan_service');
const _azanNotificationIds = [100, 101, 102, 103, 104];

// ════════════════════════════════════════════════════════════════
//  ✅ Callback — تم إزالته واستبداله بـ AlarmManager الأصلي
//  الآن يتم استخدام AzanAlarmReceiver مباشرة
// ════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════
//  معالج الخلفية لـ flutter_local_notifications
// ════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) async {
  final actionId = response.actionId ?? '';
  debugPrint('🔔 Background action: $actionId');
  if (actionId == 'open_athkar' ||
      actionId == 'open_dua' ||
      actionId == 'open_qibla' ||
      actionId == 'open_prayer_times') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_navigation', actionId);
  }
}

// ════════════════════════════════════════════════════════════════
//  UnifiedAzanService
// ════════════════════════════════════════════════════════════════
class UnifiedAzanService {
  static final UnifiedAzanService _instance = UnifiedAzanService._internal();
  factory UnifiedAzanService() => _instance;
  UnifiedAzanService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ── تهيئة ──
  Future<void> initialize() async {
    logger.info(LogCategory.azan, 'Initializing UnifiedAzanService');

    try {
      // ✅ لم نعد نحتاج AndroidAlarmManager.initialize() لأننا نستخدم AlarmManager الأصلي

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _notifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
              final actionId = response.actionId ?? 'notification_tap';
              logger.info(
                LogCategory.notification,
                'Foreground action received',
                data: {'actionId': actionId},
              );
              await _handleAction(actionId);
            },
        onDidReceiveBackgroundNotificationResponse:
            onBackgroundNotificationResponse,
      );

      logger.info(
        LogCategory.azan,
        'UnifiedAzanService initialized successfully',
      );
    } catch (e, stackTrace) {
      logger.error(
        LogCategory.azan,
        'Failed to initialize UnifiedAzanService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ── معالجة الـ Action ──
  Future<void> _handleAction(String actionId) async {
    if (actionId == 'open_athkar' ||
        actionId == 'open_dua' ||
        actionId == 'open_qibla' ||
        actionId == 'open_prayer_times') {
      await _cancelAzanNotificationsOnly();
      if (onNotificationActionCallback != null) {
        onNotificationActionCallback!(actionId);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_navigation', actionId);
      }
    }
  }

  // ── إلغاء إشعارات الأذان فقط ──
  Future<void> _cancelAzanNotificationsOnly() async {
    for (final id in _azanNotificationIds) {
      await _notifications.cancel(id);
    }
    debugPrint('✅ Cancelled azan notifications only');
  }

  // ════════════════════════════════════════════════════════════
  //  جدولة الأذان
  // ════════════════════════════════════════════════════════════
  Future<void> scheduleAzan({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
    required String muezzinFileName,
  }) async {
    logger.info(
      LogCategory.azan,
      'Scheduling azan',
      data: {
        'id': id,
        'prayerName': prayerName,
        'prayerTime': prayerTime.toString(),
        'muezzinFileName': muezzinFileName,
      },
    );

    if (prayerTime.isBefore(DateTime.now())) {
      logger.warning(
        LogCategory.azan,
        'Skipping past time',
        data: {'prayerName': prayerName, 'prayerTime': prayerTime.toString()},
      );
      return;
    }

    final soundFile = muezzinFileName
        .replaceAll('.mp3', '')
        .toLowerCase()
        .replaceAll('-', '_');

    if (Platform.isAndroid) {
      // ✅ المرحلة 2: AlarmScheduler (Kotlin) هو المالِك الوحيد لجدولة
      // Android — يُسلّح 21 يوماً بمعرّفات مطلقة عبر refreshNativeScheduler().
      // لا نُسلّح من هنا: كان يُنتج منبهاً ثانياً على نفس اللحظة بمعرّف
      // قديم (100-105/150) بينما الناتيف يُسلّح بمعرّف مطلق مختلف
      // لنفس التوقيت → أذان مزدوج فعلي على الجهاز (مُلاحَظ ميدانياً).
      logger.info(
        LogCategory.azan,
        'Azan delegated to native AlarmScheduler (Dart no-op)',
        data: {
          'id': id,
          'prayerName': prayerName,
          'time':
              '${prayerTime.hour}:${prayerTime.minute.toString().padLeft(2, '0')}',
          'soundFile': soundFile,
        },
      );
    } else if (Platform.isIOS) {
      // ✅ المرحلة 7: IosNotificationWindow هو المالِك الوحيد لجدولة
      // iOS — يُسلّح نافذة متدرّجة (5 أيام) بمعرّفات مطلقة عبر
      // NotificationService.scheduleIosAzanNotification() مباشرةً.
      // لا نُسلّح من هنا: نفس سبب الأندرويد بالضبط (§1.11/تدقيق المرحلة 2)
      // — منبهان لنفس اللحظة بمعرّفَين مختلفين (100-104 هنا القديم مقابل
      // معرّف IosNotificationWindow المطلق) لو بقي هذا المسار فعّالاً.
      logger.info(
        LogCategory.azan,
        'Azan delegated to IosNotificationWindow (Dart no-op)',
        data: {
          'id': id,
          'prayerName': prayerName,
          'time':
              '${prayerTime.hour}:${prayerTime.minute.toString().padLeft(2, '0')}',
          'soundFile': soundFile,
        },
      );
    }

    // ✅ FIX M11: حذف الحفظ المكرر من هنا
    // السبب: _saveAzanDataForNative() في prayer_notification_manager
    //        تُستدعى دائماً بعد scheduleAzan() وتحفظ نفس البيانات
    //        الاحتفاظ هنا بـ last_sound_file_scheduled فقط لأنه مفيد
    //        كـ fallback عند قراءة الصوت في AzanAlarmReceiver
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sound_file_scheduled', soundFile);
    } catch (e, stackTrace) {
      logger.error(
        LogCategory.storage,
        'Failed to save last_sound_file_scheduled',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  جدولة تذكير 15 دقيقة قبل الصلاة (via AlarmManager)
  // ════════════════════════════════════════════════════════════
  Future<void> schedulePrayerReminder({
    required int id,
    required String prayerName,
    required DateTime reminderTime,
  }) async {
    logger.info(
      LogCategory.azan,
      'Scheduling prayer reminder',
      data: {
        'id': id,
        'prayerName': prayerName,
        'reminderTime': reminderTime.toString(),
      },
    );

    if (reminderTime.isBefore(DateTime.now())) {
      logger.warning(
        LogCategory.azan,
        'Skipping past reminder time',
        data: {'reminderTime': reminderTime.toString()},
      );
      return;
    }

    if (Platform.isAndroid) {
      // ✅ المرحلة 2: التذكير أيضاً يُسلَّح عبر AlarmScheduler (Kotlin)
      // ضمن نفس التحديث الذرّي — لا تسليح مزدوج من Dart.
      logger.info(
        LogCategory.azan,
        'Reminder delegated to native AlarmScheduler (Dart no-op)',
        data: {
          'id': id,
          'prayerName': prayerName,
          'time':
              '${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, '0')}',
        },
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  ✅ PHASE 3: دفع تحديث فوري للمحرك الناتيف
  //  يستدعي AlarmScheduler.refresh() الذرّية (أفق 21 يوماً) ويطبق
  //  تغييرات الإعدادات فوراً بدل انتظار نبضة AzanWorker.
  // ════════════════════════════════════════════════════════════
  Future<void> refreshNativeScheduler() async {
    if (!Platform.isAndroid) return;
    try {
      await _azanChannel.invokeMethod('refreshAlarms');
      logger.info(
        LogCategory.azan,
        'Native scheduler refreshed (7-day compute)',
      );
    } catch (e, stackTrace) {
      logger.error(
        LogCategory.azan,
        'Failed to refresh native scheduler',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  جدولة إشعار الشروق (via AlarmManager, no azan sound)
  // ════════════════════════════════════════════════════════════
  Future<void> scheduleShurooqNotification({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
  }) async {
    logger.info(
      LogCategory.azan,
      'Scheduling Shurooq notification',
      data: {
        'id': id,
        'prayerName': prayerName,
        'prayerTime': prayerTime.toString(),
      },
    );

    if (prayerTime.isBefore(DateTime.now())) {
      logger.warning(
        LogCategory.azan,
        'Skipping past Shurooq time',
        data: {'prayerTime': prayerTime.toString()},
      );
      return;
    }

    if (Platform.isAndroid) {
      // ✅ المرحلة 2: الشروق مجدول ضمن مجموعة الأذان الكاملة في
      // AlarmScheduler (Kotlin) — نفس منطق §1.11 القديم (لا تسليح مزدوج).
      logger.info(
        LogCategory.azan,
        'Shurooq delegated to native AlarmScheduler (Dart no-op)',
        data: {
          'id': id,
          'prayerName': prayerName,
          'time':
              '${prayerTime.hour}:${prayerTime.minute.toString().padLeft(2, '0')}',
        },
      );
    } else if (Platform.isIOS) {
      // ✅ المرحلة 7: نفس منطق scheduleAzan أعلاه — IosNotificationWindow
      // يُسلّح الشروق ضمن نافذته المتدرّجة عبر
      // NotificationService.scheduleIosShurooqNotification() مباشرةً.
      logger.info(
        LogCategory.azan,
        'Shurooq delegated to IosNotificationWindow (Dart no-op)',
        data: {
          'id': id,
          'prayerName': prayerName,
          'time':
              '${prayerTime.hour}:${prayerTime.minute.toString().padLeft(2, '0')}',
        },
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  إلغاء أذان واحد
  // ════════════════════════════════════════════════════════════
  Future<void> cancelAzan(int id) async {
    if (Platform.isAndroid) {
      try {
        await _azanChannel.invokeMethod('cancelAlarm', {'id': id});
        debugPrint('✅ Cancelled azan alarm: $id');
      } catch (e) {
        debugPrint('❌ cancelAzan error: $e');
      }
    }
    await _notifications.cancel(id);

    // ⚠️ FIX #1 جزء 2: لا نحذف البيانات من SharedPreferences
    // هذه البيانات ضرورية لاسترداد Kotlin (AzanBootReceiver, restartCountdownForNextPrayer)
    // إذا حذفناها، لن يجد Kotlin أي أذانات عند البحث ويتوقف النظام
    debugPrint('✅ Cancelled alarm $id (recovery data preserved in SharedPreferences)');
  }

  // ════════════════════════════════════════════════════════════
  //  إلغاء كل الأذانات
  //  
  //  ⚠️ PHASE 3: DEPRECATED - لا تستخدم هذه الدالة!
  //  السبب: تسبب race condition خطير
  //  - إذا قُتل التطبيق بين الإلغاء وإعادة الجدولة → منبهات ضائعة
  //  - FLAG_UPDATE_CURRENT في AlarmManager يحدّث المنبه تلقائياً
  //  
  //  البديل: استخدم FLAG_UPDATE_CURRENT مباشرة (لا حاجة للإلغاء)
  // ════════════════════════════════════════════════════════════
  @Deprecated(
    'PHASE 3: Do not use - causes race condition. '
    'Use FLAG_UPDATE_CURRENT instead (auto-updates existing alarms)',
  )
  Future<void> cancelAllAzans({bool keepSavedData = false}) async {
    if (Platform.isAndroid) {
      try {
        for (int id = 100; id <= 155; id++) {
          await _azanChannel.invokeMethod('cancelAlarm', {'id': id});
        }
        debugPrint('✅ All azan alarms cancelled via AlarmManager');
      } catch (e) {
        debugPrint('❌ cancelAllAzans error: $e');
      }
    }
    await _cancelAzanNotificationsOnly();

    // ⚠️ FIX #1 جزء 2: نحافظ دائماً على بيانات الاسترداد في SharedPreferences
    // Kotlin يحتاجها في AzanBootReceiver و restartCountdownForNextPrayer
    // حتى عند keepSavedData=false، نتجاهل الحذف لأنه يكسر الاستقلالية
    if (!keepSavedData) {
      debugPrint('✅ cancelAllAzans: alarms cancelled (recovery data preserved intentionally)');
    } else {
      debugPrint('✅ cancelAllAzans: alarms cancelled, saved data kept for recovery');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  إيقاف الأذان الشغّال فوراً (Android فقط)
  // ════════════════════════════════════════════════════════════
  Future<void> stopPlayingAzan() async {
    if (!Platform.isAndroid) return;
    try {
      await _azanChannel.invokeMethod('stopAzan');
      debugPrint('✅ Stop signal sent to AzanForegroundService');
    } catch (e) {
      debugPrint('❌ stopPlayingAzan error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  بدء إشعار العداد التنازلي الثابت (WeMuslim-style)
  //  يُستدعى بعد الجدولة — يُظهر عداداً للصلاة القادمة
  //  
  //  ⚠️ PHASE 4: DEPRECATED - العداد التنازلي غير موثوق
  //  السبب: يعتمد على PrayerCountdownService الذي يُقتل من Android 15
  //  تم حذف PrayerCountdownService نهائياً
  // ════════════════════════════════════════════════════════════
  @Deprecated(
    'PHASE 4: Countdown feature removed - unreliable on Android 15. '
    'PrayerCountdownService has been deleted.',
  )
  Future<void> startCountdownNotification({
    required String prayerName,
    required DateTime prayerTime,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      // نمرر timeMillis كـ Long (64-bit) لضمان الدقة على الجانب الأصلي
      await _azanChannel.invokeMethod('startCountdown', {
        'prayerName': prayerName,
        'prayerTimeMillis': prayerTime.millisecondsSinceEpoch,
      });
      debugPrint('✅ Countdown started: $prayerName at $prayerTime');
    } catch (e) {
      debugPrint('❌ startCountdownNotification error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  إيقاف إشعار العداد التنازلي
  // ════════════════════════════════════════════════════════════
  Future<void> stopCountdownNotification() async {
    if (!Platform.isAndroid) return;
    try {
      await _azanChannel.invokeMethod('stopCountdown');
      debugPrint('✅ Countdown notification stopped');
    } catch (e) {
      debugPrint('❌ stopCountdownNotification error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  Battery Optimization (Android فقط)
  // ════════════════════════════════════════════════════════════
  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _azanChannel.invokeMethod<bool>(
        'isBatteryOptimizationDisabled',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('❌ isBatteryOptimizationDisabled error: $e');
      return false;
    }
  }

  Future<void> requestBatteryExemption() async {
    if (!Platform.isAndroid) return;
    try {
      await _azanChannel.invokeMethod('requestBatteryExemption');
      debugPrint('✅ Battery exemption requested');
    } catch (e) {
      debugPrint('❌ requestBatteryExemption error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  معالجة Payload الأذان
  // ════════════════════════════════════════════════════════════
  Future<void> handleAzanPayload(String payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_azan_payload', payload);
    debugPrint('✅ Azan payload saved: $payload');
  }

  // ── للتوافق مع الكود القديم ──
  Future<List<PendingNotificationRequest>> getPendingAzans() async =>
      await _notifications.pendingNotificationRequests();

  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async =>
      await _notifications.getNotificationAppLaunchDetails();
}

// ════════════════════════════════════════════════════════════════
//  معرفات الصلوات
// ════════════════════════════════════════════════════════════════
class PrayerNotificationIds {
  static const int fajrAzan = 100;
  static const int dhuhrAzan = 101;
  static const int asrAzan = 102;
  static const int maghribAzan = 103;
  static const int ishaAzan = 104;

  static const int fajrReminder = 200;
  static const int dhuhrReminder = 201;
  static const int asrReminder = 202;
  static const int maghribReminder = 203;
  static const int ishaReminder = 204;

  static const int suhoor = 300;
  static const int iftar = 301;
  static const int shurooqAzan = 105;  // ✅ Treat like other prayers (100-104)
  static const int shurooqReminder = 205;  // ✅ Consistent with other reminders (200-204)

  static int getAzanId(String prayerId) {
    switch (prayerId) {
      case 'fajr':
        return fajrAzan;
      case 'shurooq':
        return shurooqAzan;  // ✅ Added
      case 'dhuhr':
        return dhuhrAzan;
      case 'asr':
        return asrAzan;
      case 'maghrib':
        return maghribAzan;
      case 'isha':
        return ishaAzan;
      default:
        return -1;
    }
  }

  static int getReminderId(String prayerId) {
    switch (prayerId) {
      case 'fajr':
        return fajrReminder;
      case 'shurooq':
        return shurooqReminder;  // ✅ Updated to use reminder ID
      case 'dhuhr':
        return dhuhrReminder;
      case 'asr':
        return asrReminder;
      case 'maghrib':
        return maghribReminder;
      case 'isha':
        return ishaReminder;
      default:
        return -1;
    }
  }

  static List<int> get allAzanIds => [
    fajrAzan,
    dhuhrAzan,
    asrAzan,
    maghribAzan,
    ishaAzan,
  ];

  static List<int> get allReminderIds => [
    fajrReminder,
    shurooqReminder,  // ✅ Moved to correct position
    dhuhrReminder,
    asrReminder,
    maghribReminder,
    ishaReminder,
    suhoor,
    iftar,
  ];
}