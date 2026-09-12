import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'prefs_keys.dart';

// ════════════════════════════════════════════════════════════════
//  Notification Service — خدمة الإشعارات
// ════════════════════════════════════════════════════════════════

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _androidSound = RawResourceAndroidNotificationSound(
    'notification',
  );
  static const _iosSound = 'notification.mp3';

  /// قناة Android عامة للتذكيرات اليومية بوقت ثابت (غير مرتبطة بصلاة).
  /// عامة الاستخدام — أُضيفت خصّيصاً لتذكير ورد الحفظ اليومي
  /// (lib/features/hifz/logic/hifz_reminder_scheduler.dart) لكنها ليست
  /// خاصة به؛ أي ميزة تذكير يومي مستقبلية بوقت ثابت يمكنها إعادة استخدامها.
  static const String genericDailyChannelId = 'daily_reminder_channel';

  /// بادئة payload تُميّز إشعارات الأذان تحديداً عن بقية أنواع
  /// الإشعارات (تذكير/سحور/إفطار/شروق) — لا شيء غيرها يضبط payload
  /// في هذا الملف حالياً. راجع scheduleIosAzanNotification أدناه.
  static const String _azanFiredPayloadPrefix = 'azan_fired:';

  /// المرحلة 8 (iOS) — آخر أذان أُطلق فعلياً، للوحة التشخيص.
  ///
  /// ⚠️ محدودية منصّة حقيقية، لا نقص تنفيذ: iOS لا يمنح فلاتر أي
  /// استدعاء عند مجرّد "تسليم" إشعار محلي بينما التطبيق في الخلفية أو
  /// مُغلَق تماماً (يتطلّب Notification Service Extension منفصلاً —
  /// خارج نطاق هذه المرحلة). onDidReceiveNotificationResponse يُستدعى
  /// فقط عند تفاعل المستخدم الفعلي (نقر) مع الإشعار — لذا هذا يُسجّل
  /// "آخر أذان iOS نُقر عليه"، وهو أفضل تقريب متاح لـ"أُطلق" على iOS
  /// تحديداً؛ الفارق موثَّق صراحةً في شاشة التشخيص أيضاً، لا يُخفى.
  static Future<void> _recordAzanFiredFromResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload == null || !payload.startsWith(_azanFiredPayloadPrefix)) {
      return;
    }
    final prayerName = payload.substring(_azanFiredPayloadPrefix.length);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PrefKeys.azanLastFiredAt,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await prefs.setString(PrefKeys.azanLastFiredPrayer, prayerName);
    } catch (e) {
      debugPrint('❌ _recordAzanFiredFromResponse error: $e');
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _recordAzanFiredFromResponse(response);
      },
    );

    // ✅ إنشاء القنوات فوراً بأولوية قصوى
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    
    if (androidPlugin != null) {
      // 1. قناة تذكير الصلاة
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'prayer_reminder_sound',
        'تذكير الصلاة',
        description: 'إشعارات تذكير بمواعيد الصلاة',
        importance: Importance.max,
        playSound: true,
        sound: _androidSound,
      ));

      // 2. قناة السحور
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'suhoor_reminder_sound',
        'تذكير السحور',
        description: 'إشعار تذكير بوقت السحور',
        importance: Importance.max,
        playSound: true,
        sound: _androidSound,
      ));

      // 3. قناة الإفطار
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'iftar_reminder_sound',
        'تذكير الإفطار',
        description: 'إشعار تذكير بوقت الإفطار',
        importance: Importance.max,
        playSound: true,
        sound: _androidSound,
      ));

      // 4. قناة الشروق
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'shurooq_channel',
        'إشعارات الشروق',
        description: 'إشعارات وقت الشروق ووقت النهي عن الصلاة',
        importance: Importance.high,
        playSound: true,
        sound: _androidSound,
      ));

      // 5. قناة عامة للتذكيرات اليومية ذات الوقت الثابت (غير مرتبطة
      // بصلاة) — أول استخدام لها: تذكير ورد الحفظ اليومي.
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        genericDailyChannelId,
        'تذكيرات يومية',
        description: 'تذكيرات يومية عامة بوقت ثابت لا ترتبط بمواقيت الصلاة',
        importance: Importance.defaultImportance,
        playSound: true,
        sound: _androidSound,
      ));
    }

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  // ✅ الإصلاح: TZDateTime.from أبسط وأدق من البناء اليدوي
  tz.TZDateTime _toTZ(DateTime dt) {
    return tz.TZDateTime.from(dt, tz.local);
  }

  // ════════════════════════════════════════════════════════════════
  //  تذكير قبل الصلاة بـ 15 دقيقة
  // ════════════════════════════════════════════════════════════════
  Future<void> schedulePrayerReminder({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
  }) async {
    final reminderTime = prayerTime.subtract(const Duration(minutes: 15));

    if (reminderTime.isBefore(DateTime.now())) {
      debugPrint('⏭️ Reminder time passed for $prayerName — skipping');
      return;
    }

    final tzTime = _toTZ(reminderTime);

    final androidDetails = AndroidNotificationDetails(
      'prayer_reminder_sound',
      'تذكير الصلاة',
      channelDescription: 'إشعارات تذكير بمواعيد الصلاة',
      importance: Importance.high,
      priority: Priority.high,
      sound: _androidSound,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF221A40),
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: _iosSound,
    );

    await _notifications.zonedSchedule(
      id,
      'تذكير بصلاة $prayerName',
      'باقي 15 دقيقة على موعد صلاة $prayerName',
      tzTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '✅ Scheduled reminder: $prayerName at '
      '${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, '0')}',
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  إشعار السحور
  // ════════════════════════════════════════════════════════════════
  Future<void> scheduleSuhoorReminder({required DateTime suhoorTime}) async {
    if (suhoorTime.isBefore(DateTime.now())) {
      debugPrint('⏭️ Suhoor time passed — skipping');
      return;
    }

    final tzTime = _toTZ(suhoorTime);

    final androidDetails = AndroidNotificationDetails(
      'suhoor_reminder_sound',
      'تذكير السحور',
      channelDescription: 'إشعار تذكير بوقت السحور',
      importance: Importance.max,
      priority: Priority.max,
      sound: _androidSound,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF221A40),
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: _iosSound,
    );

    // ✅ ID موحد مع PrayerNotificationIds (300)
    await _notifications.zonedSchedule(
      300,
      '🌙 حان وقت السحور',
      'باقي ساعة على أذان الفجر',
      tzTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '✅ Scheduled suhoor at '
      '${suhoorTime.hour}:${suhoorTime.minute.toString().padLeft(2, '0')}',
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  إشعار الإفطار
  // ════════════════════════════════════════════════════════════════
  Future<void> scheduleIftarReminder({required DateTime maghribTime}) async {
    if (maghribTime.isBefore(DateTime.now())) {
      debugPrint('⏭️ Iftar time passed — skipping');
      return;
    }

    final tzTime = _toTZ(maghribTime);

    final androidDetails = AndroidNotificationDetails(
      'iftar_reminder_sound',
      'تذكير الإفطار',
      channelDescription: 'إشعار تذكير بوقت الإفطار',
      importance: Importance.max,
      priority: Priority.max,
      sound: _androidSound,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF221A40),
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: _iosSound,
    );

    // ✅ ID موحد مع PrayerNotificationIds (301)
    await _notifications.zonedSchedule(
      301,
      '🌅 حان وقت الإفطار',
      'اللهم لك صمت وعلى رزقك أفطرت',
      tzTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '✅ Scheduled iftar at '
      '${maghribTime.hour}:${maghribTime.minute.toString().padLeft(2, '0')}',
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  إشعار الشروق (ID=302)
  // ════════════════════════════════════════════════════════════════
  Future<void> scheduleShurooqNotification({required DateTime shurooqTime}) async {
    if (shurooqTime.isBefore(DateTime.now())) {
      debugPrint('⏭️ Shurooq time passed — skipping');
      return;
    }

    final tzTime = _toTZ(shurooqTime);

    final androidDetails = AndroidNotificationDetails(
      'shurooq_channel',
      'إشعارات الشروق',
      channelDescription: 'إشعارات وقت الشروق ووقت النهي عن الصلاة',
      importance: Importance.high,
      priority: Priority.high,
      sound: _androidSound,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF221A40),
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: _iosSound,
    );

    // ✅ ID موحد (302)
    await _notifications.zonedSchedule(
      302,
      '🌅 شروق الشمس',
      'وقت نهي عن الصلاة — انتظر حتى ترتفع الشمس قيد رمح',
      tzTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '✅ Scheduled shurooq at '
      '${shurooqTime.hour}:${shurooqTime.minute.toString().padLeft(2, '0')}',
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  تذكير الشروق قبل 15 دقيقة (ID=205)
  // ════════════════════════════════════════════════════════════════
  Future<void> scheduleShurooqReminder({required DateTime shurooqTime}) async {
    final reminderTime = shurooqTime.subtract(const Duration(minutes: 15));  // ✅ Changed from 20 to 15

    if (reminderTime.isBefore(DateTime.now())) {
      debugPrint('⏭️ Shurooq reminder time passed — skipping');
      return;
    }

    final tzTime = _toTZ(reminderTime);

    final androidDetails = AndroidNotificationDetails(
      'shurooq_channel',
      'إشعارات الشروق',
      channelDescription: 'إشعارات وقت الشروق ووقت النهي عن الصلاة',
      importance: Importance.high,
      priority: Priority.high,
      sound: _androidSound,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF221A40),
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: _iosSound,
    );

    // ✅ ID موحد (205)
    await _notifications.zonedSchedule(
      205,  // ✅ Updated ID to match new constant
      '🌄 باقي 15 دقيقة على الشروق',  // ✅ Updated from 20 to 15
      'سيبدأ وقت النهي عن الصلاة قريباً',
      tzTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '✅ Scheduled shurooq reminder at '
      '${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, '0')}',
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  تذكير يومي عام بوقت ثابت (غير مرتبط بصلاة) — يتكرّر تلقائياً كل
  //  يوم في نفس الساعة/الدقيقة عبر matchDateTimeComponents.time، دون
  //  أي حاجة لإعادة جدولة يومية من التطبيق نفسه (بخلاف تذكيرات الصلاة
  //  أعلاه التي تُعاد حسابها كل يوم لأن وقتها يتغيّر مع الفلك).
  //  مضافة كقدرة عامة (وليست خاصة بميزة الحفظ) لأنها أول دالة جدولة
  //  متكرّرة تلقائياً في هذه الخدمة — أي ميزة تذكير يومي مستقبلية
  //  يمكنها استخدامها مباشرةً.
  // ════════════════════════════════════════════════════════════════
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required DateTime firstFireTime,
    bool exact = false,
  }) async {
    final tzTime = _toTZ(firstFireTime);

    final androidDetails = AndroidNotificationDetails(
      genericDailyChannelId,
      'تذكيرات يومية',
      channelDescription: 'تذكيرات يومية عامة بوقت ثابت لا ترتبط بمواقيت الصلاة',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      sound: _androidSound,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF221A40),
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: _iosSound,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint(
      '✅ Scheduled daily reminder #$id at '
      '${firstFireTime.hour}:${firstFireTime.minute.toString().padLeft(2, '0')} '
      '(repeats daily)',
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  دوال مساعدة
  // ════════════════════════════════════════════════════════════════
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  // ════════════════════════════════════════════════════════════════
  //  المرحلة 7 (iOS) — إشعارات النافذة المتدرّجة
  //
  //  نُقلت هنا حرفياً من UnifiedAzanService.scheduleAzan/
  //  scheduleShurooqNotification (فرعا iOS)، اللذان أصبحا no-op على
  //  كل المنصّات (Android: المرحلة 2 — AlarmScheduler؛ iOS: المرحلة 7
  //  — IosNotificationWindow) لمنع تسليح مزدوج لنفس اللحظة بمعرّفَين
  //  مختلفين، تماماً كما حدث ووُثِّق للأندرويد في §1.11/تدقيق المرحلة 2.
  //
  //  الجدولة idempotent بطبيعتها: UNUserNotificationCenter.add(request)
  //  بمعرّف مطابق يُحدِّث الطلب القائم — لا حاجة لإلغاء صريح قبل
  //  إعادة الجدولة (بخلاف AlarmManager على أندرويد الذي يحتاج ذلك
  //  أحياناً بحسب الـ flags).
  // ════════════════════════════════════════════════════════════════

  /// إشعار أذان على iOS — يستخدم مقتطف افتتاحية الأذان (التكبيرة الأولى،
  /// ~5 ثوانٍ، wav PCM) الخاص بالمؤذن المختار كصوت UNNotificationSound
  /// (راجع تدقيق المرحلة 7، الجزء أ — الأذان الكامل mp3 غير صالح كمورد
  /// UNNotificationSound لتجاوزه سقف 30 ثانية؛ المقطع المقصوص في
  /// ios/Runner/Resources/ هو الحل المُتّخذ). [reciterSoundFileName] هو
  /// اسم الملف كما هو مُسجَّل في حزمة iOS (مثال: azan_abdelbaset.wav)؛
  /// عند تركه null أو تعذّر إيجاد المورد، تتراجع UNNotificationSound.soundNamed:
  /// تلقائياً لصوت النظام الافتراضي (سلوك Apple موثَّق، لا حاجة لمعالجة
  /// صريحة هنا — راجع FlutterLocalNotificationsPlugin.m).
  Future<void> scheduleIosAzanNotification({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
    String? reciterSoundFileName,
  }) async {
    if (prayerTime.isBefore(DateTime.now())) return;
    try {
      final tzTime = _toTZ(prayerTime);
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: reciterSoundFileName ?? 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      await _notifications.zonedSchedule(
        id,
        'حان وقت صلاة $prayerName',
        'اللهم اجعلنا من المحافظين على الصلاة',
        tzTime,
        NotificationDetails(iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // ✅ المرحلة 8: يُقرأ في _recordAzanFiredFromResponse عند النقر
        // على الإشعار — يُميّزه عن بقية الأنواع (تذكير/سحور/إفطار/شروق).
        payload: '$_azanFiredPayloadPrefix$prayerName',
      );
    } catch (e) {
      debugPrint('❌ scheduleIosAzanNotification error (id=$id): $e');
    }
  }

  /// إشعار شروق على iOS — نفس منطق [scheduleIosAzanNotification] بنص مختلف.
  Future<void> scheduleIosShurooqNotification({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
  }) async {
    if (prayerTime.isBefore(DateTime.now())) return;
    try {
      final tzTime = _toTZ(prayerTime);
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      await _notifications.zonedSchedule(
        id,
        '🌅 $prayerName',
        'وقت نهي عن الصلاة — انتظر حتى ترتفع الشمس قيد رمح',
        tzTime,
        const NotificationDetails(iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('❌ scheduleIosShurooqNotification error (id=$id): $e');
    }
  }
}
