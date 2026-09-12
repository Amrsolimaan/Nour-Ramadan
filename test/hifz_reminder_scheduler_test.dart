// اختبارات HifzReminderScheduler.computeNextFireDate — الجزء النقي
// الوحيد من منطق تذكير الورد اليومي (بلا أي إشعارات/I-O حقيقية).

import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/features/hifz/logic/hifz_reminder_scheduler.dart';

void main() {
  group('HifzReminderScheduler.computeNextFireDate', () {
    test('الوقت لم يحن بعد اليوم والورد لم يتحقّق: يُطلَق اليوم في الساعة المحدَّدة', () {
      final now = DateTime(2026, 8, 10, 15, 0); // الساعة 3 عصراً
      final fire = HifzReminderScheduler.computeNextFireDate(
        hour: 20,
        minute: 0,
        wirdMetToday: false,
        now: now,
      );
      expect(fire, DateTime(2026, 8, 10, 20, 0));
    });

    test('الوقت فات اليوم: يُطلَق غداً في نفس الساعة، حتى لو لم يتحقّق الورد', () {
      final now = DateTime(2026, 8, 10, 21, 30); // بعد الساعة 20:00 بالفعل
      final fire = HifzReminderScheduler.computeNextFireDate(
        hour: 20,
        minute: 0,
        wirdMetToday: false,
        now: now,
      );
      expect(fire, DateTime(2026, 8, 11, 20, 0));
    });

    test('الورد تحقّق اليوم بالفعل: يُكبَت إطلاق اليوم ويُؤجَّل لغد حتى لو الوقت لم يحن بعد', () {
      final now = DateTime(2026, 8, 10, 10, 0); // صباحاً — قبل موعد التذكير بكثير
      final fire = HifzReminderScheduler.computeNextFireDate(
        hour: 20,
        minute: 0,
        wirdMetToday: true,
        now: now,
      );
      expect(fire, DateTime(2026, 8, 11, 20, 0));
    });

    test('الورد تحقّق والوقت فات معاً: يبقى غداً (لا يتضاعف التأجيل)', () {
      final now = DateTime(2026, 8, 10, 23, 0);
      final fire = HifzReminderScheduler.computeNextFireDate(
        hour: 20,
        minute: 0,
        wirdMetToday: true,
        now: now,
      );
      expect(fire, DateTime(2026, 8, 11, 20, 0));
    });

    test('اللحظة نفسها بالضبط تُعامَل كأنها فائتة (تحفُّظ آمن) — تُؤجَّل لغد', () {
      final now = DateTime(2026, 8, 10, 20, 0);
      final fire = HifzReminderScheduler.computeNextFireDate(
        hour: 20,
        minute: 0,
        wirdMetToday: false,
        now: now,
      );
      expect(fire, DateTime(2026, 8, 11, 20, 0));
    });

    test('يعمل بشكل صحيح عبر حدود الشهر/السنة', () {
      final now = DateTime(2025, 12, 31, 21, 0); // بعد وقت التذكير في آخر يوم بالسنة
      final fire = HifzReminderScheduler.computeNextFireDate(
        hour: 20,
        minute: 0,
        wirdMetToday: false,
        now: now,
      );
      expect(fire, DateTime(2026, 1, 1, 20, 0));
    });
  });
}
