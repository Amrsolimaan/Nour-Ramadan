import 'dart:io' show Platform;

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/settings/providers/settings_provider.dart' show kMuezzins;
import 'notification_service.dart';
import 'prefs_keys.dart';

// ════════════════════════════════════════════════════════════════
//  IosNotificationWindow — المرحلة 7، الجزء ب (plan_azan_reliability.md)
//
//  المالِك الوحيد لجدولة الأذان/التذكيرات/الشروق على iOS — نظير
//  AlarmScheduler.kt على أندرويد، لكن بمنطق مختلف جوهرياً لأن iOS
//  ليس له معادل لـ AlarmManager: بديله سقف صارم ~64 إشعاراً معلَّقاً
//  لكل تطبيق (راجع §2.6 وبحث المرحلة 5 السابق حول flutter_local_notifications).
//  لذلك: نافذة متدرّجة (rolling window) بدل أفق ثابت كامل كالأندرويد.
//
//  ═══ حساب N (حجم النافذة) — راجع تدقيق المرحلة 7 ═══
//
//  لكل يوم مُسلَّح (5 صلوات: فجر/ظهر/عصر/مغرب/عشاء):
//    • أذان لكل صلاة                    = 5
//    • شروق (إشعار واحد، لا تذكير له)    = 1
//    • تذكير 15 دقيقة (للصلوات الخمس فقط) = 5
//    ───────────────────────────────────────
//    الإجمالي لكل يوم (perDayNotificationCount) = 11
//
//  محجوزات ثابتة لا تتضاعف مع N (كيانات مفردة تُحدَّث لا تتراكم):
//    • السحور (معرّف ثابت واحد، يُحدَّث لا يتراكم)     = 1
//    • الإفطار (معرّف ثابت واحد)                        = 1
//    • تذكير ورد الحفظ (matchDateTimeComponents.time —
//      طلب متكرّر واحد يُحتسب "واحداً" ضد السقف 64
//      بصرف النظر عن تكراره — راجع بحث المرحلة 5)        = 1
//    ───────────────────────────────────────
//    reservedSlots = 3
//
//  السقف الفعلي 64. المطلوب: 11×N + 3 ≤ 64 بهامش أمان واضح (لا نُشبع
//  الحدّ الأقصى نظرياً) — راجع الخيارات:
//    N=5 → 11×5+3 = 58   (هامش 6 خانات، ≈9%)   ← المُختار
//    N=6 → 11×6+3 = 69   (يتجاوز 64 فعلياً)     ← مرفوض
//    N=4 → 11×4+3 = 47   (هامش 17 خانة، ≈27%)  ← أكثر تحفّظاً، بديل مقبول
//
//  targetWindowDays = 5. عتبة التجديد topUpThresholdDays = 2 (نُجدِّد
//  حين يتبقّى يومان أو أقل، لا عند الاستنفاد الكامل — نفس فلسفة الثلث
//  المتبقّي في AlarmScheduler.kt للأندرويد، مُطبَّقة بنسبة مكافئة هنا).
// ════════════════════════════════════════════════════════════════

/// قرار التجديد — dataclass بسيطة (pure) لنتيجة [IosNotificationWindow.decideTopUp].
class IosWindowTopUpDecision {
  const IosWindowTopUpDecision({
    required this.needsTopUp,
    required this.daysToAdd,
    required this.notificationsToAdd,
  });

  final bool needsTopUp;
  final int daysToAdd;
  final int notificationsToAdd;

  @override
  String toString() =>
      'IosWindowTopUpDecision(needsTopUp: $needsTopUp, daysToAdd: $daysToAdd, '
      'notificationsToAdd: $notificationsToAdd)';

  @override
  bool operator ==(Object other) =>
      other is IosWindowTopUpDecision &&
      other.needsTopUp == needsTopUp &&
      other.daysToAdd == daysToAdd &&
      other.notificationsToAdd == notificationsToAdd;

  @override
  int get hashCode => Object.hash(needsTopUp, daysToAdd, notificationsToAdd);
}

class IosNotificationWindow {
  IosNotificationWindow._();

  // ── الثوابت — راجع الحساب في التعليق أعلى الملف ────────────────
  static const int targetWindowDays = 5;
  static const int topUpThresholdDays = 2;
  static const int perDayNotificationCount = 11; // 5 أذان + 1 شروق + 5 تذكير

  // ── هوية مهمّة الخلفية (BGAppRefreshTask عبر workmanager) ──────
  static const String backgroundTaskUniqueName = 'ios_notification_window_topup';
  static const String backgroundTaskName = 'iosNotificationWindowTopUp';

  /// ⚠️ الفاصل الفعلي للتكرار على iOS يُضبط من AppDelegate.swift
  /// (SwiftWorkmanagerPlugin.registerPeriodicTask(withIdentifier:frequency:))
  /// — القيمة هنا للتوثيق/الاتساق فقط، لا تُغيِّر شيئاً في iOS فعلياً
  /// (المعالج الأصلي لا يقرأ frequency القادمة من طلب Dart لإعادة
  /// الجدولة الدورية؛ راجع تدقيق المرحلة 7).
  static const Duration backgroundTaskFrequency = Duration(hours: 12);

  // ── نطاق معرّفات مطلق ومنفصل تماماً (2,000,000+) ────────────────
  // مفصول عن: معرّفات Dart القديمة (100-301) ومعرّفات AlarmScheduler
  // على أندرويد (1,000,000+) — لا تداخل منطقي رغم أن iOS/Android
  // مخزنان منفصلان أصلاً؛ نظافة اتّساق فقط.
  static const int _idBase = 2_000_000;
  static const int _reminderOffset = 100_000;
  static const int _dayModulus = 10_000;
  static const int _shurooqIndex = 5;

  static const List<_PrayerSpec> _prayers = [
    _PrayerSpec('الفجر', 0),
    _PrayerSpec('الظهر', 1),
    _PrayerSpec('العصر', 2),
    _PrayerSpec('المغرب', 3),
    _PrayerSpec('العشاء', 4),
  ];

  // ════════════════════════════════════════════════════════════
  //  ① القرار الصِرف (pure) — بلا أي I/O إطلاقاً
  // ════════════════════════════════════════════════════════════

  /// كم يوماً مُسلَّح الآن → هل نحتاج تجديداً، وبكم يوم/إشعار؟
  ///
  /// [daysCurrentlyScheduled]: عدد الأيام المُغطّاة من اليوم (ضمناً)
  /// فصاعداً — مثال: إن كانت النافذة تمتد حتى اليوم نفسه فقط = 1.
  /// قيمة سالبة تُعامَل كصفر (نافذة منتهية/غير موجودة).
  static IosWindowTopUpDecision decideTopUp({
    required int daysCurrentlyScheduled,
    int targetDays = targetWindowDays,
    int thresholdDays = topUpThresholdDays,
    int perDayCount = perDayNotificationCount,
  }) {
    final clamped = daysCurrentlyScheduled < 0 ? 0 : daysCurrentlyScheduled;

    if (clamped > thresholdDays) {
      return const IosWindowTopUpDecision(
        needsTopUp: false,
        daysToAdd: 0,
        notificationsToAdd: 0,
      );
    }

    final daysToAdd = targetDays - clamped;
    if (daysToAdd <= 0) {
      return const IosWindowTopUpDecision(
        needsTopUp: false,
        daysToAdd: 0,
        notificationsToAdd: 0,
      );
    }

    return IosWindowTopUpDecision(
      needsTopUp: true,
      daysToAdd: daysToAdd,
      notificationsToAdd: daysToAdd * perDayCount,
    );
  }

  /// معرّف مطلق لصلاة/تاريخ معيَّن — ثابت لكل (تاريخ، فهرس) بصرف
  /// النظر عن "اليوم الحالي"، بنفس فلسفة AlarmScheduler.idFor() في Kotlin.
  static int idFor(DateTime date, int prayerIndex) {
    final epochDay =
        DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return _idBase + (epochDay % _dayModulus) * 10 + prayerIndex;
  }

  // ════════════════════════════════════════════════════════════
  //  ② الأغلفة الحقيقية — I/O فعلي (SharedPreferences + adhan + منصّة)
  // ════════════════════════════════════════════════════════════

  /// يقرأ السجلّ المحفوظ (آخر تاريخ مُغطّى)، يُفوّض القرار لـ
  /// [decideTopUp]، ويُنفِّذ التجديد فعلياً إن احتاج الأمر.
  /// لا شيء يحدث على غير iOS. لا ترمي أبداً — تسجّل وتعود بأمان.
  static Future<void> topUpIfNeeded() async {
    if (!Platform.isIOS) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _dateOnly(DateTime.now());

      final scheduledThroughStr = prefs.getString(
        PrefKeys.iosWindowScheduledThroughDate,
      );
      final scheduledThrough = scheduledThroughStr == null
          ? null
          : DateTime.tryParse(scheduledThroughStr);

      final isStaleOrMissing =
          scheduledThrough == null || scheduledThrough.isBefore(today);
      final daysCurrentlyScheduled = isStaleOrMissing
          ? 0
          : scheduledThrough.difference(today).inDays + 1;

      final decision = decideTopUp(daysCurrentlyScheduled: daysCurrentlyScheduled);

      debugPrint(
        '🔍 IosNotificationWindow: مُغطّى=$daysCurrentlyScheduled يوم، $decision',
      );

      if (!decision.needsTopUp) return;

      final startDate = isStaleOrMissing
          ? today
          : scheduledThrough.add(const Duration(days: 1));

      final ok = await _scheduleDays(startDate: startDate, count: decision.daysToAdd);
      if (!ok) return; // فشل الحساب (لا موقع محفوظ) — لا نُحدّث السجلّ

      final newThrough = startDate.add(Duration(days: decision.daysToAdd - 1));
      await prefs.setString(
        PrefKeys.iosWindowScheduledThroughDate,
        newThrough.toIso8601String(),
      );

      debugPrint(
        '✅ IosNotificationWindow: أُضيف ${decision.daysToAdd} يوم '
        '(${decision.notificationsToAdd} إشعار) — مُغطّى حتى ${_fmt(newThrough)}',
      );
    } catch (e, st) {
      debugPrint('❌ IosNotificationWindow.topUpIfNeeded error: $e');
      debugPrint('$st');
    }
  }

  /// يُسجّل مهمّة الخلفية الدورية (BGAppRefreshTask عبر workmanager) —
  /// تُستدعى مرّة عند كل إقلاع (Future.microtask في main.dart)، بأمان
  /// للاستدعاء المتكرر (نفس معرّف = تحديث الطلب القائم لا تكراره).
  static Future<void> registerBackgroundTask() async {
    if (!Platform.isIOS) return;
    try {
      await Workmanager().registerPeriodicTask(
        backgroundTaskUniqueName,
        backgroundTaskName,
        frequency: backgroundTaskFrequency,
        initialDelay: backgroundTaskFrequency,
      );
      debugPrint('✅ IosNotificationWindow: سُجِّلت مهمّة الخلفية');
    } catch (e) {
      debugPrint('❌ IosNotificationWindow.registerBackgroundTask error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  الحساب والتسليح الفعلي — يقرأ الموقع/الإعدادات من SharedPreferences
  //  الخام مباشرةً (لا LocationService.instance ولا Riverpod) — يجب أن
  //  يعمل بأمان من سياق خلفي بلا شجرة widgets حيّة (BGAppRefreshTask
  //  عبر headless Flutter engine)، بنفس القيد الذي حكم تصميم
  //  AlarmScheduler.computeSchedule() في Kotlin.
  // ════════════════════════════════════════════════════════════
  static Future<bool> _scheduleDays({
    required DateTime startDate,
    required int count,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final lat = double.tryParse(prefs.getString(PrefKeys.lastLat) ?? '');
    final lng = double.tryParse(prefs.getString(PrefKeys.lastLng) ?? '');
    if (lat == null || lng == null) {
      debugPrint('❌ IosNotificationWindow: لا يوجد موقع محفوظ');
      return false;
    }

    final coords = Coordinates(lat, lng);
    final params = _resolveParams(prefs);
    final reciterSoundFileName = _resolveReciterSoundFileName(prefs);

    final notificationService = NotificationService();

    for (var i = 0; i < count; i++) {
      final date = startDate.add(Duration(days: i));
      final dateComponents = DateComponents.from(date);

      final PrayerTimes prayerTimes;
      try {
        prayerTimes = PrayerTimes(coords, dateComponents, params);
      } catch (e) {
        debugPrint('❌ IosNotificationWindow: فشل حساب $date: $e');
        continue;
      }

      final times = [
        prayerTimes.fajr,
        prayerTimes.dhuhr,
        prayerTimes.asr,
        prayerTimes.maghrib,
        prayerTimes.isha,
      ];

      for (final p in _prayers) {
        final prayerTime = times[p.index];
        final azanId = idFor(date, p.index);

        await notificationService.scheduleIosAzanNotification(
          id: azanId,
          prayerName: p.name,
          prayerTime: prayerTime,
          reciterSoundFileName: reciterSoundFileName,
        );
        await notificationService.schedulePrayerReminder(
          id: azanId + _reminderOffset,
          prayerName: p.name,
          prayerTime: prayerTime,
        );
      }

      await notificationService.scheduleIosShurooqNotification(
        id: idFor(date, _shurooqIndex),
        prayerName: 'الشروق',
        prayerTime: prayerTimes.sunrise,
      );
    }

    return true;
  }

  static CalculationParameters _resolveParams(SharedPreferences prefs) {
    // ⚠️ ملاحظة تدقيق المرحلة 7: لا كود Dart يكتب هذين المفتاحين حالياً
    // (grep شامل، صفر نتائج) — يبقيان دائماً null، فيسقط الحساب دوماً
    // إلى EGYPTIAN/SHAFI. نقرأهما دفاعياً بنفس نمط AlarmScheduler.kt
    // احتياطاً لإعدادات مستقبلية، ومطابقةً لما يعرضه prayer_provider.dart
    // فعلياً اليوم (EGYPTIAN/SHAFI مُثبَّتان هناك بلا قراءة إعدادات إطلاقاً).
    final methodKey = prefs.getString('settings_calculation_method');
    final madhabKey = prefs.getString('settings_madhab');

    final method = switch (methodKey?.toLowerCase()) {
      'makkah' || 'umm_al_qura' => CalculationMethod.umm_al_qura,
      'karachi' => CalculationMethod.karachi,
      'isna' || 'north_america' => CalculationMethod.north_america,
      'dubai' => CalculationMethod.dubai,
      'kuwait' => CalculationMethod.kuwait,
      'qatar' => CalculationMethod.qatar,
      'singapore' => CalculationMethod.singapore,
      _ => CalculationMethod.egyptian,
    };

    final params = method.getParameters();
    params.madhab =
        madhabKey?.toLowerCase() == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    return params;
  }

  /// اسم ملف مقطع الأذان الخاص بالمؤذن المختار (كما هو مُسجَّل في حزمة
  /// iOS، مثال: azan_abdelbaset.wav) — الجزء أ من تدقيق المرحلة 7.
  ///
  /// يقرأ المفتاح الخام 'settings_muezzin' مباشرةً (نفس نمط دفاعي مثل
  /// _resolveParams أعلاه؛ المفتاح يطابق SettingsNotifier._kMuezzin
  /// حرفياً في settings_provider.dart) لأن هذا السياق قد يعمل من خلفية
  /// بلا شجرة widgets حيّة (BGAppRefreshTask)، فلا يمكنه الاعتماد على
  /// Riverpod. يُحوَّل امتداد المصدر (.mp3) إلى (.wav) لمطابقة المقطع
  /// المقصوص المُسجَّل في ios/Runner/Resources/.
  static String _resolveReciterSoundFileName(SharedPreferences prefs) {
    final muezzinId = prefs.getString('settings_muezzin') ?? 'abdelbaset';
    final muezzin = kMuezzins.firstWhere(
      (m) => m.id == muezzinId,
      orElse: () => kMuezzins.first,
    );
    return muezzin.fileName.replaceAll('.mp3', '.wav');
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _PrayerSpec {
  const _PrayerSpec(this.name, this.index);
  final String name;
  final int index;
}
