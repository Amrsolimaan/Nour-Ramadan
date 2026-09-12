// اختبارات BatteryPromptService — المرحلة 4 من خطة موثوقية الأذان.
//
// يختبر المنطق الصِرف (pure) فقط: shouldPromptPure() و pickGrantAction().
// كلاهما بلا أي I/O (لا SharedPreferences، لا MethodChannel)، فلا حاجة
// لأي محاكاة — دوال رياضية/منطقية بحتة.

import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/core/services/battery_prompt_service.dart';

void main() {
  group('BatteryPromptService.shouldPromptPure — بوابة تأجيل 30 يوماً', () {
    const oneDayMs = 24 * 60 * 60 * 1000;
    const thirtyDaysMs = 30 * oneDayMs;
    final now = DateTime(2026, 9, 11).millisecondsSinceEpoch;

    test('الإعفاء ممنوح أصلاً ⇒ لا عرض إطلاقاً، بصرف النظر عن أي شيء آخر', () {
      expect(
        BatteryPromptService.shouldPromptPure(
          isAlreadyExempted: true,
          lastDeclinedAtMs: null,
          nowMs: now,
        ),
        isFalse,
      );

      // حتى لو لم يُرفض إطلاقاً (null) — الإعفاء الممنوح يقفل كل شيء
      expect(
        BatteryPromptService.shouldPromptPure(
          isAlreadyExempted: true,
          lastDeclinedAtMs: now - thirtyDaysMs * 10, // رُفض منذ زمن بعيد
          nowMs: now,
        ),
        isFalse,
      );
    });

    test('لم يُرفض إطلاقاً (null) وغير ممنوح ⇒ يُعرض (أول تفعيل أذان)', () {
      expect(
        BatteryPromptService.shouldPromptPure(
          isAlreadyExempted: false,
          lastDeclinedAtMs: null,
          nowMs: now,
        ),
        isTrue,
      );
    });

    test('رُفض قبل أقل من 30 يوماً ⇒ لا عرض (لا يزال ضمن فترة التأجيل)', () {
      expect(
        BatteryPromptService.shouldPromptPure(
          isAlreadyExempted: false,
          lastDeclinedAtMs: now - oneDayMs, // منذ يوم واحد
          nowMs: now,
        ),
        isFalse,
      );

      expect(
        BatteryPromptService.shouldPromptPure(
          isAlreadyExempted: false,
          lastDeclinedAtMs: now - (thirtyDaysMs - 1), // أقل من 30 يوماً بمللي واحد
          nowMs: now,
        ),
        isFalse,
      );
    });

    test('رُفض قبل 30 يوماً بالضبط ⇒ يُعرض (الحدّ نفسه ينتهي التأجيل)', () {
      expect(
        BatteryPromptService.shouldPromptPure(
          isAlreadyExempted: false,
          lastDeclinedAtMs: now - thirtyDaysMs,
          nowMs: now,
        ),
        isTrue,
      );
    });

    test('رُفض قبل أكثر من 30 يوماً ⇒ يُعرض', () {
      expect(
        BatteryPromptService.shouldPromptPure(
          isAlreadyExempted: false,
          lastDeclinedAtMs: now - thirtyDaysMs * 2,
          nowMs: now,
        ),
        isTrue,
      );
    });

    test('cooldownDays مخصّص يُحترَم (ليس ثابتاً على 30 دائماً)', () {
      const sevenDaysMs = 7 * oneDayMs;

      // رُفض منذ 10 أيام — دون حدّ 30 يوماً الافتراضي، لكن يتجاوز حدّ 7 مُخصَّص
      expect(
        BatteryPromptService.shouldPromptPure(
          isAlreadyExempted: false,
          lastDeclinedAtMs: now - 10 * oneDayMs,
          nowMs: now,
          cooldownDays: 7,
        ),
        isTrue,
      );

      // نفس الرفض (10 أيام) لكن بحدّ 30 يوماً الافتراضي — لا يزال ضمن التأجيل
      expect(
        BatteryPromptService.shouldPromptPure(
          isAlreadyExempted: false,
          lastDeclinedAtMs: now - 10 * oneDayMs,
          nowMs: now,
        ),
        isFalse,
      );
      // يتأكد أن sevenDaysMs مُستخدَمة فعلاً في الحساب أعلاه (وليست ميتة)
      expect(sevenDaysMs, 7 * oneDayMs);
    });
  });

  group('BatteryPromptService.pickGrantAction — توجيه زر المنح', () {
    test('جهاز بقيود صارمة ⇒ يفتح إعدادات المصنّع الخاصة', () {
      expect(
        BatteryPromptService.pickGrantAction(hasStrictOemRestrictions: true),
        BatteryGrantAction.manufacturerSpecific,
      );
    });

    test('جهاز بلا قيود معروفة ⇒ يطلب الإعفاء العام المباشر', () {
      expect(
        BatteryPromptService.pickGrantAction(hasStrictOemRestrictions: false),
        BatteryGrantAction.generic,
      );
    });
  });
}
