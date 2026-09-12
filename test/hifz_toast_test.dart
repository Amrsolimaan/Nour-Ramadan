// اختبارات hifz_toast.dart — الآلية الموحَّدة الوحيدة لكل توستات ميزة
// الحفظ (ScaffoldMessenger.showSnackBar القياسية في فلاتر، بسياسة
// "إلغاء ثم عرض" موحَّدة). اختبارات widget حقيقية (تحاكي مرور الوقت
// عبر tester.pump) وليست محاكاة منفصلة — تستدعي showHifzToast/
// showHifzUndoToast من الملف الفعلي المستخدَم في كل شاشات الحفظ.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/features/hifz/widgets/hifz_toast.dart';

void main() {
  group('ثوابت المدة', () {
    test('kHifzToastDuration = ثانيتان', () {
      expect(kHifzToastDuration, const Duration(seconds: 2));
    });

    test('kHifzUndoToastDuration = 3 ثوانٍ صراحةً (وليس بلا حدّ زمني)', () {
      expect(kHifzUndoToastDuration, const Duration(seconds: 3));
    });
  });

  group('showHifzUndoToast — الإخفاء التلقائي', () {
    testWidgets('يختفي تلقائياً بعد نحو 3 ثوانٍ إن لم يُنقر على "تراجع"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHifzUndoToast(
                  context,
                  message: 'تمت الإضافة',
                  actionLabel: 'تراجع',
                  onAction: () {},
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump(); // بدء ظهور السناكبار
      await tester.pump(const Duration(milliseconds: 300)); // اكتمال حركة الدخول
      expect(find.text('تمت الإضافة'), findsOneWidget);

      // ما زال ظاهراً بعد ثانية واحدة فقط — قبل انقضاء المدة المحدَّدة (3 ثوانٍ) بكثير.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('تمت الإضافة'), findsOneWidget);

      // ⚠️ يجب تجاوز الـ3 ثوانٍ ثم إكمال حركة الخروج في نداءي pump
      // منفصلَين وليس نداءً واحداً ضخماً: مؤقّت الإخفاء (Timer) الذي
      // يبدأ حركة الخروج (AnimationController.reverse) يُطلَق أثناء
      // FakeAsync.elapse خارج دورة الإطار الحالية، فتُسجَّل نقطة بداية
      // حركة الخروج (Ticker._startTime) عند أول "تيكة" فعلية لاحقة لا
      // عند لحظة إطلاق المؤقّت — أول تيكة كهذه تُقاس بعنصر مرور صفري
      // (raw Ticker.start يشترط أن يكون داخل إطار جارٍ ليُسجِّل الوقت
      // فوراً؛ خارج الإطار يبقى null فيُستخدم أول timestamp تالٍ كبداية
      // عبر `_startTime ??= timeStamp` في ticker.dart) ولا تُقدِّم
      // الحركة أي تقدُّم عندها. نداء pump ضخم واحد لا يمنح سوى تيكة
      // واحدة (إطار واحد) عند نهايته، فتبقى حركة الخروج عالقة عند
      // البداية إلى الأبد ضمن ذلك النداء — يلزم نداء pump منفصل تالٍ
      // ليمنحها تيكة ثانية بزمن منقضٍ حقيقي فتكتمل وتُزال السناكبار
      // فعلياً. (تحقَّق تجريبياً: نداء pump واحد بمدة 4 ثوانٍ يُبقي
      // العنصر ظاهراً إلى الأبد؛ نداءان منفصلان يُزيلانه خلال ~3.8 ثانية.)
      await tester.pump(const Duration(seconds: 2)); // total ~3.3s — يُطلق المؤقّت، يبدأ حركة الخروج (تيكة أولى بلا تقدُّم)
      await tester.pump(const Duration(milliseconds: 500)); // نداء منفصل — يُكمل حركة الخروج فعلياً
      expect(find.text('تمت الإضافة'), findsNothing);
    });

    testWidgets('النقر على "تراجع" قبل انتهاء المؤقّت يستدعي الإجراء ويُخفي التوست', (
      tester,
    ) async {
      var undone = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHifzUndoToast(
                  context,
                  message: 'تمت الإضافة',
                  actionLabel: 'تراجع',
                  onAction: () => undone = true,
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('تمت الإضافة'), findsOneWidget);

      // نقر "تراجع" بعد ثانية واحدة فقط — قبل انتهاء مؤقّت الـ3 ثوانٍ بكثير.
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('تراجع'));
      await tester.pump();

      expect(undone, isTrue, reason: 'إجراء التراجع نفسه يجب أن يُستدعى فوراً عند النقر');

      await tester.pump(const Duration(milliseconds: 300)); // اكتمال حركة الإخفاء بعد النقر
      expect(find.text('تمت الإضافة'), findsNothing);
    });
  });

  group('showHifzToast — الاستبدال الفوري بدل الطابور', () {
    testWidgets('توستان متتاليان: يظهر نص الأحدث فقط، لا يُعرض الأول مطلقاً بعده', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => showHifzToast(context, 'رسالة أولى'),
                    child: const Text('A'),
                  ),
                  ElevatedButton(
                    onPressed: () => showHifzToast(context, 'رسالة ثانية'),
                    child: const Text('B'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // الرسالة الأولى تظهر أولاً...
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('رسالة أولى'), findsOneWidget);

      // ...ثم تصل الثانية قبل أن تنتهي الأولى من تلقاء نفسها (مدتها ثانيتان).
      await tester.tap(find.text('B'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // النتيجة: الثانية فقط ظاهرة — لا طابور، ولا ظهور متتابع للأولى بعدها.
      expect(find.text('رسالة أولى'), findsNothing);
      expect(find.text('رسالة ثانية'), findsOneWidget);

      // وتبقى وحدها الظاهرة حتى بعد انقضاء ما كانت ستستغرقه الأولى أصلاً.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('رسالة أولى'), findsNothing);
    });

    testWidgets('توست تأكيد بسيط لاحق يستبدل توست تراجع سابق (سلوك مقصود وموثَّق)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => showHifzUndoToast(
                      context,
                      message: 'تمت الإضافة',
                      actionLabel: 'تراجع',
                      onAction: () {},
                    ),
                    child: const Text('undo'),
                  ),
                  ElevatedButton(
                    onPressed: () => showHifzToast(context, 'لا صفحات جديدة لإضافتها'),
                    child: const Text('plain'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('undo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('تمت الإضافة'), findsOneWidget);

      await tester.tap(find.text('plain'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('تمت الإضافة'), findsNothing);
      expect(find.text('لا صفحات جديدة لإضافتها'), findsOneWidget);
    });
  });
}
