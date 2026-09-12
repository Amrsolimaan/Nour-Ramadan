// اختبارات HifzScheduler — محرك جدولة المراجعة، نقي بالكامل.
// لا Hive ولا Riverpod هنا؛ فقط دوال ونماذج bare Dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/core/data/hifz_page_index.dart';
import 'package:nour_ramadan/features/hifz/logic/hifz_scheduler.dart';
import 'package:nour_ramadan/features/hifz/models/hifz_models.dart';

void main() {
  group('الترقية من "حفظ حديث" إلى "قيد المراجعة" (§3.2)', () {
    test('لا تترقّى إلا عند بلوغ العتبتين معاً: نافذة الأيام + عدد التقييمات القوية', () {
      final settings = const HifzSettings(
        newlyMemorizedWindowDays: 14,
        promoteAfterConsecutiveStrong: 7,
      );
      var meta = HifzMeta.initial();
      final start = DateTime(2026, 1, 1);
      var state = HifzScheduler.createNewlyMemorized(10, start);

      var today = start;
      for (var i = 0; i < 6; i++) {
        today = today.add(const Duration(days: 3));
        final res = HifzScheduler.gradeNearPage(
          state: state,
          grade: HifzGrade.strong,
          settings: settings,
          meta: meta,
          today: today,
        );
        state = res.page;
        meta = res.meta;
      }
      // بعد 6 تقييمات قوية متتالية (والنافذة انقضت منذ التقييم الخامس):
      // العدد لم يبلغ 7 بعد، فلا ترقية.
      expect(state.consecutiveStrong, 6);
      expect(state.stage, HifzStage.newlyMemorized);

      // التقييم السابع يكمل الشرطين معاً → ترقية فورية.
      today = today.add(const Duration(days: 3));
      final res = HifzScheduler.gradeNearPage(
        state: state,
        grade: HifzGrade.strong,
        settings: settings,
        meta: meta,
        today: today,
      );
      state = res.page;
      expect(state.stage, HifzStage.underReview);
      expect(state.consecutiveStrong, 0);
      expect(state.farCyclesSurvived, 0);
      expect(state.stageEnteredAt, HifzScheduler.dateOnly(today));
    });

    test('عدم انقضاء نافذة الأيام يمنع الترقية حتى لو اكتمل عدد التقييمات القوية', () {
      final settings = const HifzSettings(
        newlyMemorizedWindowDays: 14,
        promoteAfterConsecutiveStrong: 7,
      );
      var meta = HifzMeta.initial();
      final start = DateTime(2026, 1, 1);
      var state = HifzScheduler.createNewlyMemorized(20, start);

      var today = start;
      for (var i = 0; i < 7; i++) {
        today = today.add(const Duration(days: 1)); // يوم واحد فقط بين كل تقييم
        final res = HifzScheduler.gradeNearPage(
          state: state,
          grade: HifzGrade.strong,
          settings: settings,
          meta: meta,
          today: today,
        );
        state = res.page;
        meta = res.meta;
      }
      // مرّت 7 أيام فقط (أقل من نافذة الـ14 يوماً) رغم اكتمال العدد المطلوب.
      expect(state.consecutiveStrong, 7);
      expect(state.stage, HifzStage.newlyMemorized);
    });
  });

  group('التثبيت الطارئ بعد تقييم "ضعيف" (§3.2/§3.3)', () {
    test('يظهر في قائمة اليوم التالي ويُزال بعد تقييمين قويين متتاليين، بلا مساس بتاريخ الحفظ الأول', () {
      final settings = const HifzSettings(weakRecoveryDays: 3);
      final today0 = DateTime(2026, 2, 1);
      var state = HifzPageState(
        page: 30,
        stage: HifzStage.underReview,
        stageEnteredAt: today0,
        firstMemorizedAt: today0,
      );
      var meta = HifzMeta.initial();

      final weakRes = HifzScheduler.gradeFarPage(
        state: state,
        grade: HifzGrade.weak,
        settings: settings,
        meta: meta,
        today: today0,
      );
      state = weakRes.page;
      meta = weakRes.meta;
      expect(state.priorityUntil, isNotNull);
      expect(state.stage, HifzStage.underReview); // لا يرتدّ تحت الحد الأدنى
      expect(state.firstMemorizedAt, today0); // لم يتغيّر إطلاقاً

      // بعد دوران اليوم (doneToday يُصفَّر) تظهر الصفحة في التثبيت رغم أنها underReview.
      final today1 = today0.add(const Duration(days: 1));
      final rolledMeta = HifzScheduler.rollDay(meta: meta, settings: settings, today: today1);
      final queue = HifzScheduler.buildTodayQueue(
        pages: {30: state},
        settings: settings,
        meta: rolledMeta,
        today: today1,
      );
      expect(queue.near.map((e) => e.page), contains(30));

      // تقييم قوي واحد لا يكفي للتعافي.
      final s1 = HifzScheduler.gradeNearPage(
        state: state,
        grade: HifzGrade.strong,
        settings: settings,
        meta: rolledMeta,
        today: today1,
      );
      state = s1.page;
      expect(state.priorityUntil, isNotNull);

      // تقييمان قويان متتاليان → التثبيت يزول.
      final today2 = today1.add(const Duration(days: 1));
      final s2 = HifzScheduler.gradeNearPage(
        state: state,
        grade: HifzGrade.strong,
        settings: settings,
        meta: s1.meta,
        today: today2,
      );
      state = s2.page;
      expect(state.priorityUntil, isNull);
      expect(state.firstMemorizedAt, today0); // ما زال بلا تغيير
    });

    test('تقييم "ضعيف" على صفحة "متقن" ينزلها إلى "قيد المراجعة" فقط (لا يرتدّ إلى حفظ حديث)', () {
      final settings = const HifzSettings(weakRecoveryDays: 3);
      final today0 = DateTime(2026, 2, 1);
      final state = HifzPageState(
        page: 40,
        stage: HifzStage.mastered,
        farCyclesSurvived: 5,
        firstMemorizedAt: DateTime(2025, 1, 1),
      );
      final res = HifzScheduler.gradeFarPage(
        state: state,
        grade: HifzGrade.weak,
        settings: settings,
        meta: HifzMeta.initial(),
        today: today0,
      );
      expect(res.page.stage, HifzStage.underReview);
      expect(res.page.farCyclesSurvived, 0);
      expect(res.page.firstMemorizedAt, DateTime(2025, 1, 1)); // غير ممسوس
    });
  });

  group('المراجعة الدورية — اكتمال الدورة والتصعيد/التراجع (§3.3)', () {
    test('اكتمال الدورة (وصول المؤشر لآخر صفحة في المجموعة) يزيد عدّاد الدورات ويُصعِّد المقدار عند متوسط مرتفع', () {
      final settings = const HifzSettings(
        reviewPortionUnit: HifzPortionUnit.quarterHizb,
        reviewPortionCount: 1,
        autoEscalateReview: true,
        reviewPortionMaxUnit: HifzPortionUnit.hizb,
      );
      final today = DateTime(2026, 3, 1);
      final pages = <int, HifzPageState>{
        1: HifzPageState(page: 1, stage: HifzStage.underReview, lastGrade: HifzGrade.strong),
        2: HifzPageState(page: 2, stage: HifzStage.underReview, lastGrade: HifzGrade.strong),
        3: HifzPageState(page: 3, stage: HifzStage.underReview, lastGrade: HifzGrade.strong),
      };
      final meta = HifzMeta.initial().copyWith(farReviewCursor: 3);

      final result = HifzScheduler.advanceFarCursor(
        pages: pages,
        meta: meta,
        settings: settings,
        gradedPage: 3, // آخر صفحة في المجموعة — يُفترض أن يُغلِق الدورة
        today: today,
      );

      expect(result.cycleCompleted, isTrue);
      expect(result.meta.farCycleCount, 1);
      expect(result.meta.farReviewCursor, 1); // يعود لأول صفحة في المجموعة
      expect(result.settings.reviewPortionUnit, HifzPortionUnit.halfHizb); // تصعيد خطوة واحدة
      expect(result.settings.reviewPortionCount, 1);
      // صفحة قيد المراجعة نجت من الدورة (تقييم قوي) دون بلوغ عتبة الإتقان (3) بعد.
      expect(result.pages[1]!.farCyclesSurvived, 1);
      expect(result.pages[1]!.stage, HifzStage.underReview);
    });

    test('لا يتحرّك المؤشر إن وُجدت صفحة أكبر لم تُراجَع بعد ضمن نفس الدورة', () {
      final settings = const HifzSettings();
      final pages = <int, HifzPageState>{
        1: HifzPageState(page: 1, stage: HifzStage.underReview),
        5: HifzPageState(page: 5, stage: HifzStage.underReview),
      };
      final meta = HifzMeta.initial().copyWith(farReviewCursor: 1);
      final result = HifzScheduler.advanceFarCursor(
        pages: pages,
        meta: meta,
        settings: settings,
        gradedPage: 1,
        today: DateTime(2026, 3, 1),
      );
      expect(result.cycleCompleted, isFalse);
      expect(result.meta.farReviewCursor, 5);
    });

    test('escalateReviewPortion: تصعيد/تراجع تدريجي ولا ينزل أبداً تحت ربع حزب واحد', () {
      // متوسط منخفض والعدد > 1 → يُخفَّض العدد أولاً قبل الوحدة.
      final down1 = HifzScheduler.escalateReviewPortion(
        const HifzSettings(
          reviewPortionUnit: HifzPortionUnit.halfHizb,
          reviewPortionCount: 2,
          autoEscalateReview: true,
        ),
        0.33,
      );
      expect(down1.reviewPortionUnit, HifzPortionUnit.halfHizb);
      expect(down1.reviewPortionCount, 1);

      // العدد بالفعل 1 → تُخفَّض الوحدة خطوة واحدة.
      final down2 = HifzScheduler.escalateReviewPortion(
        const HifzSettings(
          reviewPortionUnit: HifzPortionUnit.halfHizb,
          reviewPortionCount: 1,
          autoEscalateReview: true,
        ),
        0.0,
      );
      expect(down2.reviewPortionUnit, HifzPortionUnit.quarterHizb);
      expect(down2.reviewPortionCount, 1);

      // عند الحد الأدنى بالفعل (ربع حزب × 1) → لا مزيد من التراجع.
      final atFloor = HifzScheduler.escalateReviewPortion(
        const HifzSettings(
          reviewPortionUnit: HifzPortionUnit.quarterHizb,
          reviewPortionCount: 1,
          autoEscalateReview: true,
        ),
        0.0,
      );
      expect(atFloor.reviewPortionUnit, HifzPortionUnit.quarterHizb);
      expect(atFloor.reviewPortionCount, 1);

      // autoEscalateReview = false → لا يتغيّر شيء أياً كان المتوسط.
      final unchanged = HifzScheduler.escalateReviewPortion(
        const HifzSettings(
          reviewPortionUnit: HifzPortionUnit.quarterHizb,
          reviewPortionCount: 3,
          autoEscalateReview: false,
        ),
        2.0,
      );
      expect(unchanged.reviewPortionUnit, HifzPortionUnit.quarterHizb);
      expect(unchanged.reviewPortionCount, 3);
    });
  });

  group('HifzScheduler.pagesForPortion — دقة مطابقة لبنية المصحف الفعلية', () {
    test('page: بالضبط count صفحة متتالية بدءاً من startCursor', () {
      final pages = HifzScheduler.pagesForPortion(HifzPortionUnit.page, 3, startCursor: 10);
      expect(pages, [10, 11, 12]);
    });

    test('quarterHizb: يطابق تماماً HifzPageIndex.pagesInQuarter للربع الذي تبدأ فيه startCursor', () {
      const startPage = 5;
      final q = HifzPageIndex.quarterOfPage(startPage);
      final expected = HifzPageIndex.pagesInQuarter(q);
      final pages = HifzScheduler.pagesForPortion(
        HifzPortionUnit.quarterHizb,
        1,
        startCursor: startPage,
      );
      expect(pages, expected);
    });

    test('hizb: يطابق تماماً HifzPageIndex.pagesInHizb عند البدء من أول صفحة في ذلك الحزب', () {
      const h = 5;
      final hizbPages = HifzPageIndex.pagesInHizb(h);
      final pages = HifzScheduler.pagesForPortion(
        HifzPortionUnit.hizb,
        1,
        startCursor: hizbPages.first,
      );
      expect(pages, hizbPages);
    });

    test('halfHizb عند نفس البداية مجموعة فرعية من hizb، وأصغر منها أو تساويها حجماً', () {
      final half = HifzScheduler.pagesForPortion(HifzPortionUnit.halfHizb, 1, startCursor: 1);
      final full = HifzScheduler.pagesForPortion(HifzPortionUnit.hizb, 1, startCursor: 1);
      expect(half.length, lessThanOrEqualTo(full.length));
      expect(full.toSet().containsAll(half), isTrue);
    });
  });

  group('تغيير الإعدادات لا يُعدِّل أي HifzPageState إطلاقاً (§3.4)', () {
    test('onSettingsChanged يُثبِّت مؤشر المراجعة الدورية فقط، ولا يمسّ الصفحات', () {
      final pages = <int, HifzPageState>{
        5: HifzPageState(page: 5, stage: HifzStage.underReview, reviewCount: 3, lastGrade: HifzGrade.strong),
      };
      final before = pages[5]!;
      final meta = HifzMeta.initial().copyWith(farReviewCursor: 9999); // خارج المدى عمداً
      final settings = const HifzSettings(
        reviewPortionUnit: HifzPortionUnit.hizb,
        reviewPortionCount: 5,
      );

      final newMeta = HifzScheduler.onSettingsChanged(pages: pages, meta: meta, settings: settings);

      expect(identical(pages[5], before), isTrue); // نفس المرجع تماماً — لم يُبنَ كائن جديد
      expect(pages[5]!.reviewCount, 3);
      expect(newMeta.farReviewCursor, HifzPageIndex.pageCount);
    });

    test('تغيير مقدار الورد لا يُعيد كتابة أي تاريخ حفظ أو عدّاد — فقط يُغيِّر حصة الغد', () {
      final smallSettings = const HifzSettings(
        reviewPortionUnit: HifzPortionUnit.quarterHizb,
        reviewPortionCount: 1,
      );
      final largeSettings = const HifzSettings(
        reviewPortionUnit: HifzPortionUnit.hizb,
        reviewPortionCount: 2,
      );
      final pages = <int, HifzPageState>{
        for (final p in HifzPageIndex.pagesInJuz(1))
          p: HifzPageState(page: p, stage: HifzStage.underReview, lastGrade: HifzGrade.strong),
      };
      final meta = HifzMeta.initial();
      final today = DateTime(2026, 3, 1);

      final smallQueue = HifzScheduler.buildTodayQueue(
        pages: pages,
        settings: smallSettings,
        meta: meta,
        today: today,
      );
      final largeQueue = HifzScheduler.buildTodayQueue(
        pages: pages,
        settings: largeSettings,
        meta: meta,
        today: today,
      );

      // تغيّر حجم حصة اليوم فقط — الصفحات نفسها لم تتغيّر (لم يُستدعَ عليها أي grade).
      expect(largeQueue.far.length, greaterThan(smallQueue.far.length));
      for (final p in pages.values) {
        expect(p.reviewCount, 0);
        expect(p.lastReviewedAt, isNull);
      }
    });
  });

  group('إثبات شامل: "الورد القابل للتعديل الحر" (§3.4 — المرحلة 5)', () {
    test(
      'صفحة بتاريخ حفظ حقيقي تبقى بلا أي مساس بعد تغيير شامل للإعدادات '
      'منتصف الرحلة، وقائمة الغد المشتقة تعكس الهدف الجديد فوراً',
      () {
        final today = DateTime(2026, 7, 1);
        final firstMemorized = DateTime(2026, 5, 1);

        // (1) صفحة بتاريخ حفظ ومراجعة حقيقيَين — منتصف رحلة حفظ فعلية،
        // وليست بيانات جديدة صفرية.
        final realPage = HifzPageState(
          page: 50,
          stage: HifzStage.underReview,
          firstMemorizedAt: firstMemorized,
          lastReviewedAt: today,
          reviewCount: 5,
          lastGrade: HifzGrade.strong,
          consecutiveStrong: 3,
          stageEnteredAt: firstMemorized,
          farCyclesSurvived: 2,
        );
        final pages = <int, HifzPageState>{
          realPage.page: realPage,
          for (final p in HifzPageIndex.pagesInJuz(2))
            p: HifzPageState(page: p, stage: HifzStage.underReview, lastGrade: HifzGrade.strong),
        };

        final oldSettings = const HifzSettings(
          reviewPortionUnit: HifzPortionUnit.quarterHizb,
          reviewPortionCount: 1,
          newlyMemorizedWindowDays: 14,
          autoEscalateReview: true,
        );
        final meta = HifzMeta.initial().copyWith(farReviewCursor: realPage.page);

        // قائمة "مراجعة اليوم" المشتقة *قبل* أي تغيير في الإعدادات.
        final queueBefore = HifzScheduler.buildTodayQueue(
          pages: pages,
          settings: oldSettings,
          meta: meta,
          today: today,
        );

        // (2) المستخدم يغيّر إعداداته منتصف الرحلة — تغيير شامل متعمَّد
        // يشمل وحدة/عدد ورد المراجعة، نافذة التثبيت، والتصعيد التلقائي.
        final newSettings = oldSettings.copyWith(
          reviewPortionUnit: HifzPortionUnit.hizb,
          reviewPortionCount: 2,
          newlyMemorizedWindowDays: 21,
          autoEscalateReview: false,
        );
        final clampedMeta = HifzScheduler.onSettingsChanged(
          pages: pages,
          meta: meta,
          settings: newSettings,
        );

        // (3) الصفحة الحقيقية لم تتغيّر إطلاقاً — لا مرجعها ولا أي حقل
        // منها (تاريخ الحفظ الأول تحديداً، الذي يجب ألا يتحرّك أبداً).
        expect(identical(pages[realPage.page], realPage), isTrue);
        expect(realPage.firstMemorizedAt, firstMemorized);
        expect(realPage.lastReviewedAt, today);
        expect(realPage.reviewCount, 5);
        expect(realPage.lastGrade, HifzGrade.strong);
        expect(realPage.consecutiveStrong, 3);
        expect(realPage.farCyclesSurvived, 2);
        // المؤشر كان صالحاً أصلاً ضمن [1, 604] فلم يحتج تثبيتاً — نفس المرجع تماماً.
        expect(identical(clampedMeta, meta), isTrue);

        // (4) قائمة الغد المشتقة بالإعدادات الجديدة تُظهر حصة مراجعة
        // دورية أكبر فوراً (حزب×2 > ربع حزب×1) — بلا أي ترحيل بيانات
        // وبلا إعادة كتابة لأي HifzPageState.
        final queueAfter = HifzScheduler.buildTodayQueue(
          pages: pages,
          settings: newSettings,
          meta: clampedMeta,
          today: today.add(const Duration(days: 1)),
        );
        expect(queueAfter.far.length, greaterThan(queueBefore.far.length));

        // والصفحة الحقيقية ما زالت بلا أي تعديل حتى بعد بناء القائمتين.
        expect(identical(pages[realPage.page], realPage), isTrue);
      },
    );
  });

  group('دوران اليوم وسلسلة المواظبة (§3.5)', () {
    test('نفس اليوم: لا تغيير في البيانات الوصفية', () {
      final today = DateTime(2026, 4, 10);
      final meta = HifzMeta.initial().copyWith(
        lastActivityDate: today,
        currentStreak: 3,
        todayNewPages: 2,
      );
      final rolled = HifzScheduler.rollDay(meta: meta, settings: const HifzSettings(), today: today);
      expect(identical(rolled, meta), isTrue);
    });

    test('اليوم التالي مباشرة بعد تحقيق الورد أمس: السلسلة تبقى، وعدادات اليوم تُصفَّر', () {
      final yesterday = DateTime(2026, 4, 10);
      final today = DateTime(2026, 4, 11);
      final meta = HifzMeta.initial().copyWith(
        lastActivityDate: yesterday,
        lastWirdMetDate: yesterday,
        currentStreak: 5,
        longestStreak: 5,
        todayNewPages: 2,
        doneToday: [1, 2],
      );
      final rolled = HifzScheduler.rollDay(meta: meta, settings: const HifzSettings(), today: today);
      expect(rolled.currentStreak, 5);
      expect(rolled.todayNewPages, 0);
      expect(rolled.doneToday, isEmpty);
    });

    test('تخطّي يوم كامل دون تحقيق الورد: السلسلة تُصفَّر', () {
      final twoDaysAgo = DateTime(2026, 4, 10);
      final today = DateTime(2026, 4, 13);
      final meta = HifzMeta.initial().copyWith(
        lastActivityDate: twoDaysAgo,
        lastWirdMetDate: twoDaysAgo,
        currentStreak: 5,
        longestStreak: 5,
      );
      final rolled = HifzScheduler.rollDay(meta: meta, settings: const HifzSettings(), today: today);
      expect(rolled.currentStreak, 0);
    });

    test('لم يتحقّق الورد قط: السلسلة تبقى صفراً بعد الدوران', () {
      final rolled = HifzScheduler.rollDay(
        meta: HifzMeta.initial(),
        settings: const HifzSettings(),
        today: DateTime(2026, 4, 20),
      );
      expect(rolled.currentStreak, 0);
    });

    test('registerActivity: السلسلة تزداد فقط عند أوّل تحقيق للورد في اليوم، لا عند كل نشاط', () {
      final settings = const HifzSettings(
        newPortionUnit: HifzPortionUnit.page,
        newPortionCount: 2,
        countNewTowardWird: true,
        countReviewTowardWird: false,
      );
      var meta = HifzMeta.initial().copyWith(
        lastActivityDate: DateTime(2026, 5, 9),
        lastWirdMetDate: DateTime(2026, 5, 9),
        currentStreak: 3,
        longestStreak: 3,
      );
      final today = DateTime(2026, 5, 10);

      meta = HifzScheduler.registerActivity(meta: meta, settings: settings, today: today, newPages: 1);
      expect(meta.currentStreak, 3); // صفحة واحدة فقط من هدف صفحتين — لم يتحقق بعد

      meta = HifzScheduler.registerActivity(meta: meta, settings: settings, today: today, newPages: 1);
      expect(meta.currentStreak, 4); // اكتمل الهدف الآن، والأمس كان متصلاً

      meta = HifzScheduler.registerActivity(meta: meta, settings: settings, today: today, newPages: 1);
      expect(meta.currentStreak, 4); // تحقّق مسبقاً اليوم — لا زيادة مضاعفة
    });
  });

  group('registerActivity — عدّاد مراجعات اليوم todayReviewPages (إصلاح المرحلة 3)', () {
    test('يزداد مع كل صفحة مراجعة جديدة اليوم، ولا يُحتسب تكرار نفس الصفحة مرتين', () {
      final settings = const HifzSettings();
      var meta = HifzMeta.initial();
      final today = DateTime(2026, 6, 1);

      meta = HifzScheduler.registerActivity(
        meta: meta,
        settings: settings,
        today: today,
        reviewedPages: [10],
      );
      expect(meta.todayReviewPages, 1);
      expect(meta.doneToday, [10]);

      // 10 مكرَّرة (سبق تقييمها) و11 جديدة — العدّاد يعكس الصفحات المميَّزة فقط.
      meta = HifzScheduler.registerActivity(
        meta: meta,
        settings: settings,
        today: today,
        reviewedPages: [10, 11],
      );
      expect(meta.todayReviewPages, 2);
      expect(meta.doneToday, [10, 11]);
    });

    test('gradeNearPage و gradeFarPage يزيدان todayReviewPages فعلياً، ولا يمسّان todayNewPages', () {
      final settings = const HifzSettings();
      final today = DateTime(2026, 6, 2);
      var meta = HifzMeta.initial();

      final nearState = HifzScheduler.createNewlyMemorized(5, today);
      final nearRes = HifzScheduler.gradeNearPage(
        state: nearState,
        grade: HifzGrade.strong,
        settings: settings,
        meta: meta,
        today: today,
      );
      meta = nearRes.meta;
      expect(meta.todayReviewPages, 1);

      final farState = HifzPageState(page: 6, stage: HifzStage.underReview);
      final farRes = HifzScheduler.gradeFarPage(
        state: farState,
        grade: HifzGrade.strong,
        settings: settings,
        meta: meta,
        today: today,
      );
      meta = farRes.meta;
      expect(meta.todayReviewPages, 2);
      expect(meta.todayNewPages, 0); // عمليات التقييم لا تُحرِّك عدّاد الحفظ الجديد إطلاقاً
    });

    test('todayNewPages يزداد بالحفظ الجديد فقط دون أن تخلطه عمليات التقييم به (لم يتأثر بالإصلاح)', () {
      final settings = const HifzSettings();
      final today = DateTime(2026, 6, 3);
      final meta = HifzScheduler.registerNewMemorization(
        meta: HifzMeta.initial(),
        settings: settings,
        pages: [1, 2],
        today: today,
      );
      expect(meta.todayNewPages, 2);
      expect(meta.todayReviewPages, 0); // لم تُراجَع أي صفحة بعد
    });

    test('rollDay يُصفِّر todayReviewPages مع todayNewPages وdoneToday في يوم جديد', () {
      final today = DateTime(2026, 6, 4);
      final tomorrow = today.add(const Duration(days: 1));
      final meta = HifzMeta.initial().copyWith(
        lastActivityDate: today,
        todayNewPages: 3,
        todayReviewPages: 2,
        doneToday: [1, 2],
      );
      final rolled = HifzScheduler.rollDay(meta: meta, settings: const HifzSettings(), today: tomorrow);
      expect(rolled.todayReviewPages, 0);
      expect(rolled.todayNewPages, 0);
      expect(rolled.doneToday, isEmpty);
    });
  });

  group('إحصاءات مشتقة للوحة التحكم (القرارات #4 و#10)', () {
    test('simpleFraction تُحسب من عدد الصفحات التي بدأ حفظها فقط', () {
      final pages = <int, HifzPageState>{
        1: HifzPageState(page: 1, stage: HifzStage.newlyMemorized),
        2: HifzPageState(page: 2, stage: HifzStage.mastered),
      };
      expect(HifzScheduler.memorizedPageCount(pages), 2);
      expect(HifzScheduler.simpleFraction(pages), 2 / HifzPageIndex.pageCount);
    });

    test('consolidatedFraction مرجَّحة بحسب رسوخ المرحلة (0.5 / 0.8 / 1.0)', () {
      final pages = <int, HifzPageState>{
        1: HifzPageState(page: 1, stage: HifzStage.newlyMemorized), // 0.5
        2: HifzPageState(page: 2, stage: HifzStage.underReview), // 0.8
        3: HifzPageState(page: 3, stage: HifzStage.mastered), // 1.0
      };
      final expected = (0.5 + 0.8 + 1.0) / HifzPageIndex.pageCount;
      expect(HifzScheduler.consolidatedFraction(pages), closeTo(expected, 1e-9));
    });

    test('juzCompletion: جزء بلا أي صفحة متتبَّعة = صفر، وجزء مكتمل بالكامل = 1', () {
      final juz1Pages = HifzPageIndex.pagesInJuz(1);
      final pages = <int, HifzPageState>{
        for (final p in juz1Pages) p: HifzPageState(page: p, stage: HifzStage.mastered),
      };
      final completion = HifzScheduler.juzCompletion(pages);
      expect(completion[1], 1.0);
      expect(completion[2], 0.0);
    });
  });
}
