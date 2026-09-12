// اختبارات TimezoneFixRescheduleMigration — متابعة المرحلة 5.
//
// يختبر بوابة "مرّة واحدة فقط" حول [rescheduleHifzReminder] القابلة
// للحقن — بلا أي اعتمادية على Riverpod/Hive/HifzReminderScheduler
// الحقيقية. عدّاد استدعاءات بسيط يكفي لإثبات: يُستدعى في أول تشغيل،
// يُتخطّى في التشغيلات اللاحقة، ويُعاد المحاولة إن فشل أول استدعاء.

import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/core/services/prefs_keys.dart';
import 'package:nour_ramadan/core/services/timezone_fix_reschedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TimezoneFixRescheduleMigration.run()', () {
    test('التشغيل الأول: يستدعي rescheduleHifzReminder ويُعلِّم العلم', () async {
      var callCount = 0;

      await TimezoneFixRescheduleMigration.run(() async {
        callCount++;
      });

      expect(callCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PrefKeys.timezoneFixRescheduleV1Done), isTrue);
    });

    test('التشغيل الثاني: العلم مُعلَّم مسبقاً ⇒ لا يُستدعى الإغلاق ثانيةً', () async {
      var callCount = 0;

      // التشغيل الأول (يُنجَح ويُعلِّم العلم)
      await TimezoneFixRescheduleMigration.run(() async {
        callCount++;
      });
      expect(callCount, 1);

      // التشغيل الثاني (محاكاة إقلاع تالٍ) — يجب أن يكون no-op تماماً
      await TimezoneFixRescheduleMigration.run(() async {
        callCount++;
      });

      expect(callCount, 1, reason: 'التشغيل الثاني لا يجب أن يستدعي الإغلاق');
    });

    test('عدّة تشغيلات متتالية بعد النجاح تبقى كلها no-op', () async {
      var callCount = 0;
      Future<void> reschedule() async => callCount++;

      await TimezoneFixRescheduleMigration.run(reschedule);
      await TimezoneFixRescheduleMigration.run(reschedule);
      await TimezoneFixRescheduleMigration.run(reschedule);

      expect(callCount, 1);
    });

    test('فشل الاستدعاء الأول: لا يُعلَّم العلم، فيُعاد المحاولة في الإقلاع التالي', () async {
      var attempt = 0;

      // التشغيل الأول يفشل
      await TimezoneFixRescheduleMigration.run(() async {
        attempt++;
        throw Exception('فشل محاكى — مثلاً hifzProvider لم يُهيَّأ بعد');
      });
      expect(attempt, 1);

      final prefsAfterFailure = await SharedPreferences.getInstance();
      expect(
        prefsAfterFailure.getBool(PrefKeys.timezoneFixRescheduleV1Done),
        isNot(true),
        reason: 'الفشل يجب ألّا يُعلِّم العلم — نريد إعادة المحاولة',
      );

      // التشغيل الثاني (محاكاة إقلاع تالٍ) ينجح هذه المرّة
      await TimezoneFixRescheduleMigration.run(() async {
        attempt++;
      });
      expect(attempt, 2, reason: 'يجب أن يُعاد الاستدعاء لأن العلم لم يُعلَّم سابقاً');

      final prefsAfterSuccess = await SharedPreferences.getInstance();
      expect(prefsAfterSuccess.getBool(PrefKeys.timezoneFixRescheduleV1Done), isTrue);

      // تشغيل ثالث: نجح سابقاً، فيجب أن يكون no-op الآن
      await TimezoneFixRescheduleMigration.run(() async {
        attempt++;
      });
      expect(attempt, 2, reason: 'بعد النجاح، لا مزيد من الاستدعاءات');
    });

    test('لا يرمي أي استثناء للطرف المستدعي حتى عند فشل مستمر', () async {
      // run() نفسها يجب أن تُمتصّ أي استثناء من rescheduleHifzReminder —
      // فشل هذا الاستدعاء لا يجب أن يُعطِّل إقلاع main.dart.
      // ✅ await فعلي هنا (لا returnsNormally، الذي يفحص الرمي المتزامن
      // فقط ولن يكتشف استثناءً داخل Future غير مُنتظَر).
      await TimezoneFixRescheduleMigration.run(() async {
        throw Exception('فشل دائم');
      });
      // الوصول لهذا السطر دون رمي = نجاح الاختبار.
    });
  });
}
