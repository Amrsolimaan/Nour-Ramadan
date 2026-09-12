// اختبارات المرحلة 8 (plan_azan_reliability.md) — منطق صِرف فقط
// (تصنيف صحة الأفق، تنسيق النصوص النسبية، تحليل epoch-ms، ولقطة
// الصلاحيات) من system_diagnostics_service.dart. لا I/O، لا منصّة،
// لا SharedPreferences — كل دالة هنا تأخذ [now] صراحةً فتكون حتمية.

import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/core/services/system_diagnostics_service.dart';

void main() {
  group('classifyHorizonHealth', () {
    final now = DateTime(2026, 9, 11, 12, 0, 0);

    test('لا نهاية أفق محفوظة ⇒ unknown', () {
      final result = classifyHorizonHealth(
        horizonEndAt: null,
        now: now,
        thresholdDays: 7,
      );
      expect(result, HorizonHealth.unknown);
    });

    test('نهاية الأفق في الماضي ⇒ critical', () {
      final result = classifyHorizonHealth(
        horizonEndAt: now.subtract(const Duration(hours: 1)),
        now: now,
        thresholdDays: 7,
      );
      expect(result, HorizonHealth.critical);
    });

    test('نهاية الأفق = الآن تماماً ⇒ critical (حدّ)', () {
      final result = classifyHorizonHealth(
        horizonEndAt: now,
        now: now,
        thresholdDays: 7,
      );
      expect(result, HorizonHealth.critical);
    });

    test('المتبقي أقل من العتبة بدقيقة واحدة ⇒ shrinking (حدّ)', () {
      final result = classifyHorizonHealth(
        horizonEndAt: now.add(const Duration(days: 7) - const Duration(minutes: 1)),
        now: now,
        thresholdDays: 7,
      );
      expect(result, HorizonHealth.shrinking);
    });

    test('المتبقي يساوي العتبة تماماً ⇒ healthy (حدّ، ليس shrinking)', () {
      final result = classifyHorizonHealth(
        horizonEndAt: now.add(const Duration(days: 7)),
        now: now,
        thresholdDays: 7,
      );
      expect(result, HorizonHealth.healthy);
    });

    test('المتبقي أكثر من العتبة بكثير ⇒ healthy', () {
      final result = classifyHorizonHealth(
        horizonEndAt: now.add(const Duration(days: 20)),
        now: now,
        thresholdDays: 7,
      );
      expect(result, HorizonHealth.healthy);
    });

    test('عتبة iOS (يومان) مختلفة عن عتبة أندرويد (٧ أيام) لنفس الأفق', () {
      final horizonEnd = now.add(const Duration(days: 3));
      final androidResult = classifyHorizonHealth(
        horizonEndAt: horizonEnd,
        now: now,
        thresholdDays: kAndroidHorizonThresholdDays,
      );
      final iosResult = classifyHorizonHealth(
        horizonEndAt: horizonEnd,
        now: now,
        thresholdDays: kIosHorizonThresholdDays,
      );
      expect(androidResult, HorizonHealth.shrinking);
      expect(iosResult, HorizonHealth.healthy);
    });
  });

  group('formatRelativeTimeLabel', () {
    final now = DateTime(2026, 9, 11, 12, 0, 0);

    test('null ⇒ التسمية الافتراضية "لم يُسجَّل بعد"', () {
      expect(formatRelativeTimeLabel(null, now), 'لم يُسجَّل بعد');
    });

    test('null مع تسمية مخصّصة', () {
      expect(
        formatRelativeTimeLabel(null, now, neverLabel: 'custom'),
        'custom',
      );
    });

    test('أقل من دقيقة ⇒ "الآن"', () {
      final at = now.subtract(const Duration(seconds: 30));
      expect(formatRelativeTimeLabel(at, now), 'الآن');
    });

    test('وقت في المستقبل (انحراف ساعة) ⇒ "الآن" وليس استثناءً', () {
      final at = now.add(const Duration(seconds: 5));
      expect(formatRelativeTimeLabel(at, now), 'الآن');
    });

    test('45 دقيقة ⇒ "قبل 45 دقيقة"', () {
      final at = now.subtract(const Duration(minutes: 45));
      expect(formatRelativeTimeLabel(at, now), 'قبل 45 دقيقة');
    });

    test('عند حدّ الساعة (60 دقيقة) ⇒ ينتقل لعرض الساعات', () {
      final at = now.subtract(const Duration(minutes: 60));
      expect(formatRelativeTimeLabel(at, now), 'قبل 1 ساعة');
    });

    test('5 ساعات ⇒ "قبل 5 ساعة"', () {
      final at = now.subtract(const Duration(hours: 5));
      expect(formatRelativeTimeLabel(at, now), 'قبل 5 ساعة');
    });

    test('عند حدّ اليوم (24 ساعة) ⇒ ينتقل لعرض الأيام', () {
      final at = now.subtract(const Duration(hours: 24));
      expect(formatRelativeTimeLabel(at, now), 'قبل 1 يوم');
    });

    test('3 أيام ⇒ "قبل 3 يوم"', () {
      final at = now.subtract(const Duration(days: 3));
      expect(formatRelativeTimeLabel(at, now), 'قبل 3 يوم');
    });
  });

  group('parseEpochMsString', () {
    test('null ⇒ null', () {
      expect(parseEpochMsString(null), isNull);
    });

    test('سلسلة فارغة ⇒ null', () {
      expect(parseEpochMsString(''), isNull);
    });

    test('نص غير رقمي ⇒ null (لا يرمي استثناءً)', () {
      expect(parseEpochMsString('not_a_number'), isNull);
    });

    test('صفر ⇒ null (لا لحظة صالحة)', () {
      expect(parseEpochMsString('0'), isNull);
    });

    test('قيمة سالبة ⇒ null', () {
      expect(parseEpochMsString('-100'), isNull);
    });

    test('قيمة صحيحة ⇒ DateTime مطابق', () {
      final dt = DateTime(2026, 9, 11, 10, 30);
      final parsed = parseEpochMsString(
        dt.millisecondsSinceEpoch.toString(),
      );
      expect(parsed, dt);
    });
  });

  group('AzanHealthSnapshot', () {
    final now = DateTime(2026, 9, 11, 12, 0, 0);

    test('horizonHealth() يُفوّض لـ classifyHorizonHealth بنفس المدخلات', () {
      final snapshot = AzanHealthSnapshot(
        isAndroid: true,
        androidArmedCount: 58,
        androidLastRefreshAt: now,
        horizonEndAt: now.add(const Duration(days: 20)),
        horizonThresholdDays: 7,
        hasExactAlarmPermission: true,
        isBatteryOptimizationDisabled: true,
        hasNotificationPermission: true,
      );
      expect(snapshot.horizonHealth(now), HorizonHealth.healthy);
    });

    test('allPermissionsOk = true فقط عند منح الثلاثة معاً', () {
      final allGranted = AzanHealthSnapshot(
        isAndroid: true,
        horizonEndAt: null,
        horizonThresholdDays: 7,
        hasExactAlarmPermission: true,
        isBatteryOptimizationDisabled: true,
        hasNotificationPermission: true,
      );
      expect(allGranted.allPermissionsOk, isTrue);

      final oneMissing = AzanHealthSnapshot(
        isAndroid: true,
        horizonEndAt: null,
        horizonThresholdDays: 7,
        hasExactAlarmPermission: true,
        isBatteryOptimizationDisabled: false,
        hasNotificationPermission: true,
      );
      expect(oneMissing.allPermissionsOk, isFalse);
    });

    test('iOS: لا عدد منبهات ولا آخر تحديث — يبقيان null دون مشكلة', () {
      final snapshot = AzanHealthSnapshot(
        isAndroid: false,
        horizonEndAt: now.add(const Duration(days: 3)),
        horizonThresholdDays: kIosHorizonThresholdDays,
        hasExactAlarmPermission: true,
        isBatteryOptimizationDisabled: true,
        hasNotificationPermission: true,
      );
      expect(snapshot.androidArmedCount, isNull);
      expect(snapshot.androidLastRefreshAt, isNull);
      expect(snapshot.horizonHealth(now), HorizonHealth.healthy);
    });
  });
}
