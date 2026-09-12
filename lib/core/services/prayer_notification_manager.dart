import 'package:adhan/adhan.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/prayer/providers/prayer_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'notification_service.dart';
import 'unified_azan_service.dart';
import 'azan_settings_service.dart';
import 'location_service.dart';
import 'notification_permission_service.dart';

// ════════════════════════════════════════════════════════════════
//  Prayer Notification Manager
//  ✅ الإصلاح: إزالة setMethodCallHandler من هنا تماماً
//  القناة يُعالجها main.dart فقط (مصدر واحد للحقيقة)
// ════════════════════════════════════════════════════════════════

class PrayerNotificationManager {
  PrayerNotificationManager({required this.ref}) {
    _initialize();
  }

  final Ref ref;
  final NotificationService _notificationService = NotificationService();
  final UnifiedAzanService _azanService = UnifiedAzanService();

  bool _initialScheduleDone = false;
  DateTime? _lastScheduleTime; // ✅ لتجنب الجدولة المتكررة

  void _initialize() {
    debugPrint('🔧 PrayerNotificationManager: _initialize()');

    // ✅ لا نضع setMethodCallHandler هنا — يسبب تعارضاً مع main.dart
    // التعامل مع rescheduleFromTimeChange يتم من main.dart ثم يُستدعى manualReschedule()

    // ── الاستماع لتغيّر الصلوات ──────────────────────────────────
    ref.listen(prayerProvider, (previous, next) {
      final now = DateTime.now();
      final isToday =
          next.selectedDate.year == now.year &&
          next.selectedDate.month == now.month &&
          next.selectedDate.day == now.day;

      if (!isToday) return;

      // الجدولة الأولى عند تحميل الصلوات
      if (!_initialScheduleDone && next.prayers.isNotEmpty && !next.isLoading) {
        debugPrint('✅ PNM: Initial schedule from listener');
        _initialScheduleDone = true;
        _scheduleAllNotifications();
        return;
      }

      // إعادة الجدولة عند تغيير حالة الإشعارات
      if (_initialScheduleDone) {
        final prevNotifs = previous?.prayers
            .map((p) => '${p.id}:${p.isNotificationEnabled}')
            .join();
        final nextNotifs = next.prayers
            .map((p) => '${p.id}:${p.isNotificationEnabled}')
            .join();

        if (prevNotifs != nextNotifs) {
          debugPrint('🔔 PNM: Notification states changed - rescheduling');
          _scheduleAllNotifications();
        }
      }
    });

    // ── الاستماع لتغيّر الإعدادات ────────────────────────────────
    ref.listen(settingsProvider, (previous, next) {
      if (!_initialScheduleDone) return;

      final muezzinChanged =
          previous?.muezzin.fileName != next.muezzin.fileName;
      final remindersChanged =
          previous?.prayerReminderEnabled != next.prayerReminderEnabled ||
          previous?.suhoorReminderEnabled != next.suhoorReminderEnabled ||
          previous?.iftarReminderEnabled != next.iftarReminderEnabled;

      if (muezzinChanged || remindersChanged) {
        debugPrint('⚙️ PNM: Settings changed - rescheduling');
        _scheduleAllNotifications();
      }
    });

    // ── جدولة مؤجّلة كـ fallback ─────────────────────────────────
    // في حال لم يُطلق listener (مثلاً الصلوات محمّلة قبل الاستماع)
    Future.delayed(const Duration(seconds: 4), () {
      if (_initialScheduleDone) return;

      final prayerState = ref.read(prayerProvider);
      if (prayerState.prayers.isNotEmpty &&
          !prayerState.isLoading &&
          LocationService.instance.hasLocation) {
        debugPrint('✅ PNM: Fallback initial schedule (4s delay)');
        _initialScheduleDone = true;
        _scheduleAllNotifications();
      }
    });

    debugPrint('✅ PrayerNotificationManager: ready');
  }

  // ════════════════════════════════════════════════════════════
  //  الجدولة الرئيسية
  // ════════════════════════════════════════════════════════════
  Future<void> _scheduleAllNotifications() async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔄 _scheduleAllNotifications()');

    // ✅ تجنب الجدولة المتكررة (أقل من دقيقة واحدة)
    final now = DateTime.now();
    if (_lastScheduleTime != null &&
        now.difference(_lastScheduleTime!).inSeconds < 60) {
      debugPrint(
        '⏭️ Skipping reschedule (too soon: ${now.difference(_lastScheduleTime!).inSeconds}s ago)',
      );
      return;
    }

    // ✅ شرط مزدوج: يجب وجود موقع وأذونات إشعارات
    if (!LocationService.instance.hasLocation) {
      debugPrint('⚠️ No location — skipping scheduling');
      return;
    }

    final hasPermission = await NotificationPermissionService.hasPermission();
    if (!hasPermission) {
      debugPrint('⚠️ No notification permission — skipping scheduling');
      return;
    }

    final prayerState = ref.read(prayerProvider);
    final settings = ref.read(settingsProvider);

    final isToday =
        prayerState.selectedDate.year == now.year &&
        prayerState.selectedDate.month == now.month &&
        prayerState.selectedDate.day == now.day;

    if (!isToday || prayerState.prayers.isEmpty) {
      debugPrint('⏭️ Not today or no prayers — skipping');
      return;
    }

    debugPrint('✅ Checks passed — scheduling...');
    _lastScheduleTime = now; // ✅ تسجيل وقت الجدولة

    // إلغاء الجداول القديمة (مع الاحتفاظ بالبيانات المحفوظة للاستعادة)
    await _azanService.cancelAllAzans(keepSavedData: true);
    await _notificationService.cancelAll();

    final mainPrayers = prayerState.prayers
        .where((p) => p.id != 'shurooq')
        .toList();

    for (final prayer in mainPrayers) {
      final azanId = PrayerNotificationIds.getAzanId(prayer.id);
      final reminderId = PrayerNotificationIds.getReminderId(prayer.id);
      if (azanId == -1 || reminderId == -1) continue;

      // ── تذكير 15 دقيقة ──
      // ✅ PHASE 3: على Android التذكير يُدار بالكامل من المحرك الناتيف
      // (AlarmScheduler.refresh → ReminderAlarmReceiver بمعرف 8000+id)
      // نعتمد مساراً واحداً لنمنع: التذكير المزدوج + إعادة تسجيل البقايا
      // القديمة بعد إعادة التشغيل (سبب "الظهر وقت العشاء").
      // ✅ المرحلة 7: على iOS أيضاً IosNotificationWindow أصبح المالِك
      // الوحيد لتذكيرات الصلاة (نافذة متدرّجة 5 أيام) — استُبعد iOS من
      // هذا الشرط لنفس سبب استبعاد Android: تذكير مزدوج على نفس اللحظة
      // بمعرّفَين مختلفين لو بقي هذا المسار فعّالاً بجانب النافذة الجديدة.
      try {
        if (!Platform.isAndroid &&
            !Platform.isIOS &&
            settings.prayerReminderEnabled &&
            prayer.isNotificationEnabled) {
          await _notificationService.schedulePrayerReminder(
            id: reminderId,
            prayerName: prayer.name,
            prayerTime: prayer.time,
          );
          debugPrint('✅ Reminder (iOS): ${prayer.name}');
        }
      } catch (e) {
        debugPrint('❌ Reminder failed for ${prayer.name}: $e');
      }

      // ── أذان ──
      try {
        final azanEnabledInSettings = AzanSettingsService.isAzanEnabled(
          prayer.id,
        );
        if (prayer.isNotificationEnabled && azanEnabledInSettings) {
          await _azanService.scheduleAzan(
            id: azanId,
            prayerName: prayer.name,
            prayerTime: prayer.time,
            muezzinFileName: settings.muezzin.fileName,
          );
          debugPrint('✅ Azan: ${prayer.name}');
        } else {
          debugPrint(
            '⏭️ Azan skipped: ${prayer.name} '
            '(notif=${prayer.isNotificationEnabled}, azanSetting=$azanEnabledInSettings)',
          );
        }
      } catch (e) {
        debugPrint('❌ Azan failed for ${prayer.name}: $e');
      }
    }

    // ── الشروق ──
    try {
      final shurooqList = prayerState.prayers
          .where((p) => p.id == 'shurooq')
          .toList();

      if (shurooqList.isNotEmpty) {
        final shurooq = shurooqList.first;
        if (shurooq.isNotificationEnabled) {
          await _azanService.scheduleShurooqNotification(
            id: PrayerNotificationIds.shurooqAzan,
            prayerName: shurooq.name,
            prayerTime: shurooq.time,
          );
          debugPrint('✅ Shurooq notification scheduled');
        } else {
          debugPrint('⏭️ Shurooq notification skipped (disabled)');
        }
      }
    } catch (e) {
      debugPrint('❌ Shurooq failed: $e');
    }

    // ── السحور ──
    try {
      if (settings.suhoorReminderEnabled && prayerState.suhoorTime != null) {
        await _notificationService.scheduleSuhoorReminder(
          suhoorTime: prayerState.suhoorTime!,
        );
        debugPrint('✅ Suhoor reminder scheduled');
      }
    } catch (e) {
      debugPrint('❌ Suhoor failed: $e');
    }

    // ── الإفطار ──
    try {
      if (settings.iftarReminderEnabled && prayerState.iftarTime != null) {
        await _notificationService.scheduleIftarReminder(
          maghribTime: prayerState.iftarTime!,
        );
        debugPrint('✅ Iftar reminder scheduled');
      }
    } catch (e) {
      debugPrint('❌ Iftar failed: $e');
    }

    // ── فجر الغد (يضمن الاستمرارية) ──
    try {
      await _scheduleNextDayFajr(settings.muezzin.fileName);
    } catch (e) {
      debugPrint('❌ Next-day fajr failed: $e');
    }

    // ── بدء إشعار العداد التنازلي للصلاة القادمة (WeMuslim-style) ──
    try {
      await _startCountdownForNextPrayer(prayerState.prayers);
    } catch (e) {
      debugPrint('❌ Countdown notification failed: $e');
    }

    // ── ✅ PHASE 3: دفع الإعدادات للمحرك الناتيف فوراً ──
    // يعيد حساب 7 أيام ويطبق (تذكير/مؤذن/معايير) دون انتظار نبضة Worker
    try {
      await _azanService.refreshNativeScheduler();
    } catch (e) {
      debugPrint('❌ Native scheduler refresh failed: $e');
    }

    debugPrint('═══════════════════════════════════════');
  }

  // ════════════════════════════════════════════════════════════
  //  فجر الغد
  // ════════════════════════════════════════════════════════════
  Future<void> _scheduleNextDayFajr(String muezzinFileName) async {
    if (!AzanSettingsService.isAzanEnabled('fajr')) {
      debugPrint('⏭️ Next-day fajr skipped (disabled)');
      return;
    }

    final tomorrowFajr = _getTomorrowFajrTime();
    if (tomorrowFajr == null) {
      debugPrint('❌ Cannot calculate tomorrow fajr');
      return;
    }

    // ✅ ID 150 لفجر الغد — لا يتعارض مع فجر اليوم (100)
    await _azanService.scheduleAzan(
      id: 150,
      prayerName: 'الفجر',
      prayerTime: tomorrowFajr,
      muezzinFileName: muezzinFileName,
    );

    debugPrint(
      '✅ Tomorrow fajr: '
      '${tomorrowFajr.hour}:${tomorrowFajr.minute.toString().padLeft(2, '0')}',
    );
  }

  DateTime? _getTomorrowFajrTime() {
    try {
      final lat = LocationService.instance.lat ?? 30.0444;
      final lng = LocationService.instance.lng ?? 31.2357;
      final coords = Coordinates(lat, lng);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dateComponents = DateComponents(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );
      final params = CalculationMethod.egyptian.getParameters();
      params.madhab = Madhab.shafi;
      return PrayerTimes(coords, dateComponents, params).fajr;
    } catch (e) {
      debugPrint('❌ _getTomorrowFajrTime: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  API عامة
  // ════════════════════════════════════════════════════════════

  /// إعادة جدولة يدوية — تُستدعى من main.dart بعد تغيير الوقت أو الموقع
  Future<void> manualReschedule() async {
    debugPrint('🔄 PNM: manualReschedule()');
    _initialScheduleDone = true;
    _lastScheduleTime = null; // ✅ السماح بالجدولة الفورية

    // ✅ إعادة حساب أوقات الصلاة أولاً ثم إعادة الجدولة
    // ضروري عند تغيير الوقت أو المنطقة الزمنية
    await _recalculatePrayersForToday();

    await _scheduleAllNotifications();
  }

  /// إعادة حساب الصلوات لليوم الحالي وتحديث prayerProvider
  Future<void> _recalculatePrayersForToday() async {
    try {
      final loc = LocationService.instance;
      if (!loc.hasLocation || loc.lat == null || loc.lng == null) {
        debugPrint('⚠️ PNM: No location — cannot recalculate prayers');
        return;
      }
      debugPrint('🔄 PNM: Recalculating prayers for today...');
      await ref
          .read(prayerProvider.notifier)
          .calculatePrayers(loc.lat!, loc.lng!, DateTime.now());
      debugPrint('✅ PNM: Prayers recalculated');
    } catch (e) {
      debugPrint('❌ PNM: Failed to recalculate prayers: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  بدء العداد التنازلي للصلاة القادمة
  // ════════════════════════════════════════════════════════════
  Future<void> _startCountdownForNextPrayer(List<dynamic> prayers) async {
    final now = DateTime.now();

    // البحث عن أول صلاة قادمة مع إشعار مفعّل
    final upcomingPrayer = prayers
        .where((p) => p.id != 'shurooq' && p.time.isAfter(now))
        .cast<dynamic>()
        .fold<dynamic>(null, (prev, curr) {
          if (prev == null) return curr;
          return (curr.time as DateTime).isBefore(prev.time as DateTime)
              ? curr
              : prev;
        });

    if (upcomingPrayer == null) {
      debugPrint('⏭️ PNM: No upcoming prayer found — skipping countdown');
      return;
    }

    // بدء العداد — الخدمة تتولى التحديث الذاتي إذا كانت شغّالة أصلاً
    await _azanService.startCountdownNotification(
      prayerName: upcomingPrayer.name as String,
      prayerTime: upcomingPrayer.time as DateTime,
    );

    debugPrint(
      '✅ PNM: Countdown started → ${upcomingPrayer.name} '
      'at ${(upcomingPrayer.time as DateTime).hour}:'
      '${(upcomingPrayer.time as DateTime).minute.toString().padLeft(2, '0')}',
    );
  }

  /// تنظيف
  void dispose() {}
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════
final prayerNotificationManagerProvider = Provider<PrayerNotificationManager>((
  ref,
) {
  final manager = PrayerNotificationManager(ref: ref);
  ref.onDispose(() => manager.dispose());
  return manager;
});