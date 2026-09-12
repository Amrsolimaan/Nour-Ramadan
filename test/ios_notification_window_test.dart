// اختبارات IosNotificationWindow — المرحلة 7، الجزء ب.
//
// يختبر المنطق الصِرف (pure) فقط: decideTopUp() و idFor(). كلاهما
// بلا أي I/O (لا SharedPreferences، لا adhan، لا flutter_local_notifications،
// لا workmanager) — دوال حسابية/منطقية بحتة.

import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/core/services/ios_notification_window.dart';

void main() {
  group('IosNotificationWindow.decideTopUp — القيم الافتراضية (N=5, عتبة=2)', () {
    test('نافذة فارغة (0 يوم) ⇒ تجديد كامل 5 أيام', () {
      final r = IosNotificationWindow.decideTopUp(daysCurrentlyScheduled: 0);
      expect(r.needsTopUp, isTrue);
      expect(r.daysToAdd, 5);
      expect(r.notificationsToAdd, 5 * 11);
    });

    test('نافذة سالبة (منتهية/تالفة) ⇒ تُعامَل كصفر، تجديد كامل', () {
      final r = IosNotificationWindow.decideTopUp(daysCurrentlyScheduled: -7);
      expect(r.needsTopUp, isTrue);
      expect(r.daysToAdd, 5);
      expect(r.notificationsToAdd, 55);
    });

    test('عند العتبة بالضبط (يومان متبقّيان) ⇒ يُجدِّد', () {
      final r = IosNotificationWindow.decideTopUp(daysCurrentlyScheduled: 2);
      expect(r.needsTopUp, isTrue);
      expect(r.daysToAdd, 3); // 5 - 2
      expect(r.notificationsToAdd, 3 * 11);
    });

    test('يوم واحد فوق العتبة (3 أيام متبقّية) ⇒ لا تجديد بعد', () {
      final r = IosNotificationWindow.decideTopUp(daysCurrentlyScheduled: 3);
      expect(r.needsTopUp, isFalse);
      expect(r.daysToAdd, 0);
      expect(r.notificationsToAdd, 0);
    });

    test('نافذة ممتلئة بالضبط (5 أيام) ⇒ لا تجديد', () {
      final r = IosNotificationWindow.decideTopUp(daysCurrentlyScheduled: 5);
      expect(r.needsTopUp, isFalse);
    });

    test('نافذة تتجاوز الهدف (6 أيام، مثلاً بعد تغيير الإعدادات) ⇒ لا تجديد', () {
      final r = IosNotificationWindow.decideTopUp(daysCurrentlyScheduled: 6);
      expect(r.needsTopUp, isFalse);
    });

    test('يوم واحد متبقٍّ ⇒ تجديد 4 أيام', () {
      final r = IosNotificationWindow.decideTopUp(daysCurrentlyScheduled: 1);
      expect(r.needsTopUp, isTrue);
      expect(r.daysToAdd, 4);
      expect(r.notificationsToAdd, 44);
    });
  });

  group('IosNotificationWindow.decideTopUp — معطيات مخصّصة', () {
    test('targetDays/thresholdDays/perDayCount مخصّصة تُحترَم بالكامل', () {
      final r = IosNotificationWindow.decideTopUp(
        daysCurrentlyScheduled: 1,
        targetDays: 3,
        thresholdDays: 1,
        perDayCount: 4,
      );
      expect(r.needsTopUp, isTrue);
      expect(r.daysToAdd, 2); // 3 - 1
      expect(r.notificationsToAdd, 8); // 2 * 4
    });

    test('عتبة مخصّصة = 0 ⇒ لا تجديد إلا عند الاستنفاد الكامل', () {
      final atOne = IosNotificationWindow.decideTopUp(
        daysCurrentlyScheduled: 1,
        thresholdDays: 0,
      );
      expect(atOne.needsTopUp, isFalse);

      final atZero = IosNotificationWindow.decideTopUp(
        daysCurrentlyScheduled: 0,
        thresholdDays: 0,
      );
      expect(atZero.needsTopUp, isTrue);
    });
  });

  group('IosNotificationWindow — قيمة الثوابت المُوثَّقة (حساب N)', () {
    test('perDayNotificationCount = 11 (5 أذان + 1 شروق + 5 تذكير)', () {
      expect(IosNotificationWindow.perDayNotificationCount, 11);
    });

    test('targetWindowDays × perDayNotificationCount + المحجوزات ≤ 64 بهامش', () {
      const reservedSlots = 3; // سحور + إفطار + تذكير ورد الحفظ
      final total = IosNotificationWindow.targetWindowDays *
              IosNotificationWindow.perDayNotificationCount +
          reservedSlots;
      expect(total, 58);
      expect(total, lessThan(64));
      expect(64 - total, greaterThanOrEqualTo(5)); // هامش أمان واضح
    });
  });

  group('IosNotificationWindow.idFor — المعرّفات المطلقة', () {
    test('تاريخان مختلفان بنفس فهرس الصلاة ⇒ معرّفان مختلفان', () {
      final d1 = DateTime(2026, 9, 11);
      final d2 = DateTime(2026, 9, 12);
      expect(
        IosNotificationWindow.idFor(d1, 0),
        isNot(IosNotificationWindow.idFor(d2, 0)),
      );
    });

    test('نفس التاريخ بفهارس صلاة مختلفة ⇒ معرّفات مختلفة', () {
      final d = DateTime(2026, 9, 11);
      final ids = List.generate(6, (i) => IosNotificationWindow.idFor(d, i));
      expect(ids.toSet().length, 6, reason: 'كل الفهارس يجب أن تُعطي معرّفات فريدة');
    });

    test('نفس (تاريخ، فهرس) ⇒ نفس المعرّف دائماً (حتمية)', () {
      final d = DateTime(2026, 9, 11);
      expect(IosNotificationWindow.idFor(d, 2), IosNotificationWindow.idFor(d, 2));
    });

    test('مكوّنات الوقت (ساعة/دقيقة) في التاريخ لا تُغيِّر المعرّف — التقويم فقط', () {
      final withTime = DateTime(2026, 9, 11, 23, 59, 59);
      final dateOnly = DateTime(2026, 9, 11);
      expect(
        IosNotificationWindow.idFor(withTime, 1),
        IosNotificationWindow.idFor(dateOnly, 1),
      );
    });

    test('المعرّفات لا تتصادم مع نطاق Dart القديم (100-301) ولا نطاق أندرويد (1,000,000+)', () {
      final id = IosNotificationWindow.idFor(DateTime(2026, 9, 11), 0);
      expect(id, greaterThanOrEqualTo(2000000));
      expect(id, lessThan(3000000));
    });
  });
}
