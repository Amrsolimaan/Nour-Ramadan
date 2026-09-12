import 'dart:math' as math;

import '../../../core/data/hifz_page_index.dart';
import '../models/hifz_models.dart';

// ════════════════════════════════════════════════════════════════
//  HifzScheduler — محرك جدولة المراجعة، نقي بالكامل (pure).
//  بلا Hive وبلا Riverpod — قابل للاختبار مباشرة (test/hifz_scheduler_test.dart).
//
//  المبدأ الجوهري (plan_hifz.md §3.4): الجدول "مُشتَقّ" وليس "مخزَّناً".
//  لا نكتب أبداً "الصفحة X مستحقة بتاريخ Y" — فقط حقائق جوهرية لكل
//  صفحة (المرحلة/التواريخ/العدادات) + مؤشر واحد لا يعتمد على التقويم
//  (farReviewCursor). لذلك تغيير هدف الورد ينعكس فوراً على جدول الغد
//  دون أي ترحيل بيانات ودون المساس بتاريخ الحفظ الأصلي لأي صفحة.
// ════════════════════════════════════════════════════════════════

/// نوع عنصر في قائمة "مراجعة اليوم".
enum HifzQueueKind { near, far }

/// عنصر واحد في قائمة المراجعة اليومية.
class HifzQueueItem {
  final int page;
  final HifzQueueKind kind;
  final String subtitle;

  const HifzQueueItem({required this.page, required this.kind, required this.subtitle});
}

/// قائمة مراجعة اليوم المدمجة — تثبيت (near) ∪ مراجعة دورية (far).
class TodayQueue {
  final List<HifzQueueItem> near;
  final List<HifzQueueItem> far;

  const TodayQueue({this.near = const [], this.far = const []});

  int get total => near.length + far.length;
  bool get isEmpty => near.isEmpty && far.isEmpty;
}

/// نتيجة تقييم صفحة واحدة (تثبيت أو مراجعة دورية بدون تحريك المؤشر).
class HifzGradeResult {
  final HifzPageState page;
  final HifzMeta meta;

  const HifzGradeResult({required this.page, required this.meta});
}

/// نتيجة اكتمال دورة مراجعة دورية كاملة — قد تُحدِّث صفحات (الترقية
/// إلى "متقن") والإعدادات (التصعيد/التراجع في مقدار المراجعة).
class HifzCycleResult {
  final Map<int, HifzPageState> pages;
  final HifzMeta meta;
  final HifzSettings settings;

  const HifzCycleResult({required this.pages, required this.meta, required this.settings});
}

/// نتيجة تحريك مؤشر المراجعة الدورية بعد تقييم صفحة منها.
class HifzCursorResult {
  final Map<int, HifzPageState> pages;
  final HifzMeta meta;
  final HifzSettings settings;
  final bool cycleCompleted;

  const HifzCursorResult({
    required this.pages,
    required this.meta,
    required this.settings,
    this.cycleCompleted = false,
  });
}

class HifzScheduler {
  HifzScheduler._();

  // ── أدوات تاريخ صغيرة ──────────────────────────────────────────
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int daysBetween(DateTime a, DateTime b) =>
      dateOnly(b).difference(dateOnly(a)).inDays;

  static double _gradeValue(HifzGrade g) => switch (g) {
    HifzGrade.weak => 0,
    HifzGrade.medium => 1,
    HifzGrade.strong => 2,
  };

  static double _stageWeight(HifzStage s) => switch (s) {
    HifzStage.notStarted => 0.0,
    HifzStage.newlyMemorized => 0.5,
    HifzStage.underReview => 0.8,
    HifzStage.mastered => 1.0,
  };

  static String _subtitle(int page) {
    final juz = HifzPageIndex.juzOfPage(page);
    return 'صفحة $page · الجزء $juz';
  }

  // ══════════════════════════════════════════════════════════════
  //  تحويل وحدة الورد → قائمة صفحات دقيقة من فهرس المصحف
  // ══════════════════════════════════════════════════════════════

  /// يُرجع مجموعة صفحات دقيقة (مبنية على المصحف الفعلي) تمثّل
  /// `count` وحدة من `unit`، ابتداءً من `startCursor`. تُستخدم إما
  /// كاقتراح صفحات فعلي، أو (الاستخدام الأشيع) لأخذ `.length` منها
  /// كحصة (quota) يومية بلا تدوير تقريبي.
  static List<int> pagesForPortion(
    HifzPortionUnit unit,
    double count, {
    int startCursor = 1,
  }) {
    final pageCount = HifzPageIndex.pageCount;
    final start = startCursor.clamp(1, pageCount);

    if (unit == HifzPortionUnit.page) {
      final n = math.max(1, count.round());
      return [for (var p = start; p < start + n && p <= pageCount; p++) p];
    }

    final quartersPerUnit = switch (unit) {
      HifzPortionUnit.quarterHizb => 1,
      HifzPortionUnit.halfHizb => 2,
      HifzPortionUnit.hizb => 4,
      HifzPortionUnit.page => 1, // غير قابل للوصول (مُعالَج أعلاه)
    };
    final nQuarters = math.max(1, (count * quartersPerUnit).round());
    final qStart = HifzPageIndex.quarterOfPage(start);

    final pages = <int>{};
    for (var q = qStart; q < qStart + nQuarters && q <= 240; q++) {
      pages.addAll(HifzPageIndex.pagesInQuarter(q));
    }
    if (pages.isEmpty) pages.add(start);
    final sorted = pages.toList()..sort();
    return sorted;
  }

  // ══════════════════════════════════════════════════════════════
  //  قائمة مراجعة اليوم (§3.1–3.3)
  // ══════════════════════════════════════════════════════════════

  static TodayQueue buildTodayQueue({
    required Map<int, HifzPageState> pages,
    required HifzSettings settings,
    required HifzMeta meta,
    required DateTime today,
  }) {
    final td = dateOnly(today);
    final done = meta.doneToday.toSet();

    // ── التثبيت (near): حفظ حديث + أي صفحة عليها تثبيت طارئ ──
    final nearPages = <int>[];
    for (final st in pages.values) {
      if (done.contains(st.page)) continue;
      final isNewly = st.stage == HifzStage.newlyMemorized;
      final pinned = st.priorityUntil != null && !dateOnly(st.priorityUntil!).isBefore(td);
      if (isNewly || pinned) nearPages.add(st.page);
    }
    nearPages.sort();
    final near = [
      for (final p in nearPages)
        HifzQueueItem(page: p, kind: HifzQueueKind.near, subtitle: _subtitle(p)),
    ];
    final nearSet = nearPages.toSet();

    // ── المراجعة الدورية (far): مسح حلقي بترتيب المصحف الصارم ──
    final corpus =
        pages.values
            .where((s) => s.stage == HifzStage.underReview || s.stage == HifzStage.mastered)
            .map((s) => s.page)
            .toList()
          ..sort();

    final far = <HifzQueueItem>[];
    if (corpus.isNotEmpty) {
      final quota = pagesForPortion(settings.reviewPortionUnit, settings.reviewPortionCount).length;
      var startIdx = corpus.indexWhere((p) => p >= meta.farReviewCursor);
      if (startIdx < 0) startIdx = 0;

      final seen = <int>{};
      for (var i = 0; i < corpus.length && far.length < quota; i++) {
        final p = corpus[(startIdx + i) % corpus.length];
        if (done.contains(p) || seen.contains(p) || nearSet.contains(p)) continue;
        seen.add(p);
        far.add(HifzQueueItem(page: p, kind: HifzQueueKind.far, subtitle: _subtitle(p)));
      }
    }

    return TodayQueue(near: near, far: far);
  }

  // ══════════════════════════════════════════════════════════════
  //  تسجيل نشاط يومي (حفظ جديد و/أو مراجعة) + سلسلة المواظبة
  // ══════════════════════════════════════════════════════════════

  /// هل هدف "ورد اليوم" متحقق بهذين العدادين؟ (إما الحفظ أو
  /// المراجعة بحسب الإعدادات — القرار المعتمد #2). عامة (public) عمداً
  /// كي تُعاد استخدامها من hifz_reminder_scheduler.dart لكبت تذكير
  /// اليوم عند تحقّق الورد، بدل إعادة تنفيذ نفس الحساب هناك.
  static bool isWirdMet(HifzSettings settings, int todayNewPages, int todayReviewPages) {
    final newTarget = pagesForPortion(settings.newPortionUnit, settings.newPortionCount).length;
    final reviewTarget =
        pagesForPortion(settings.reviewPortionUnit, settings.reviewPortionCount).length;
    final newMet = settings.countNewTowardWird && todayNewPages >= newTarget;
    final reviewMet = settings.countReviewTowardWird && todayReviewPages >= reviewTarget;
    return newMet || reviewMet;
  }

  static HifzMeta registerActivity({
    required HifzMeta meta,
    required HifzSettings settings,
    required DateTime today,
    int newPages = 0,
    List<int> reviewedPages = const [],
  }) {
    final td = dateOnly(today);

    final newTotal = meta.todayNewPages + newPages;
    final doneSet = meta.doneToday.toSet()..addAll(reviewedPages);
    final reviewTotal = doneSet.length;

    final wasMet = isWirdMet(settings, meta.todayNewPages, meta.doneToday.length);
    final nowMet = isWirdMet(settings, newTotal, reviewTotal);

    var currentStreak = meta.currentStreak;
    var longestStreak = meta.longestStreak;
    var lastWirdMetDate = meta.lastWirdMetDate;

    if (!wasMet && nowMet) {
      final lastMet = meta.lastWirdMetDate == null ? null : dateOnly(meta.lastWirdMetDate!);
      if (lastMet != null && daysBetween(lastMet, td) == 1) {
        currentStreak = meta.currentStreak + 1;
      } else if (lastMet != null && daysBetween(lastMet, td) == 0) {
        currentStreak = meta.currentStreak == 0 ? 1 : meta.currentStreak;
      } else {
        currentStreak = 1;
      }
      longestStreak = math.max(longestStreak, currentStreak);
      lastWirdMetDate = td;
    }

    return meta.copyWith(
      todayNewPages: newTotal,
      // ✅ إصلاح المرحلة 3: كان هذا الحقل يبقى بلا تحديث رغم حساب
      // reviewTotal أعلاه بالفعل لاختبار تحقّق الورد — الآن يُكتب فعلياً.
      todayReviewPages: reviewTotal,
      doneToday: doneSet.toList()..sort(),
      lastActivityDate: td,
      lastWirdMetDate: lastWirdMetDate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  حفظ جديد
  // ══════════════════════════════════════════════════════════════

  static HifzPageState createNewlyMemorized(int page, DateTime today) {
    final td = dateOnly(today);
    return HifzPageState(
      page: page,
      stage: HifzStage.newlyMemorized,
      firstMemorizedAt: td,
      stageEnteredAt: td,
    );
  }

  static HifzMeta registerNewMemorization({
    required HifzMeta meta,
    required HifzSettings settings,
    required List<int> pages,
    required DateTime today,
  }) {
    return registerActivity(
      meta: meta,
      settings: settings,
      today: today,
      newPages: pages.length,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  تقييم صفحة في قائمة التثبيت (near) — §3.2
  // ══════════════════════════════════════════════════════════════

  static HifzGradeResult gradeNearPage({
    required HifzPageState state,
    required HifzGrade grade,
    required HifzSettings settings,
    required HifzMeta meta,
    required DateTime today,
  }) {
    final td = dateOnly(today);

    var stage = state.stage;
    var consecutiveStrong = state.consecutiveStrong;
    var stageEnteredAt = state.stageEnteredAt;
    var farCyclesSurvived = state.farCyclesSurvived;
    var priorityUntil = state.priorityUntil;

    switch (grade) {
      case HifzGrade.strong:
        final newConsec = state.consecutiveStrong + 1;
        final windowOk = state.stageEnteredAt != null &&
            daysBetween(state.stageEnteredAt!, td) >= settings.newlyMemorizedWindowDays;
        final promote = state.stage == HifzStage.newlyMemorized &&
            newConsec >= settings.promoteAfterConsecutiveStrong &&
            windowOk;
        if (promote) {
          stage = HifzStage.underReview;
          stageEnteredAt = td;
          consecutiveStrong = 0;
          farCyclesSurvived = 0;
        } else {
          consecutiveStrong = newConsec;
        }
        // تعافٍ من تثبيت طارئ بعد تقييمين قويين متتاليين (أو ترقية فورية)
        if (newConsec >= 2) priorityUntil = null;
        break;

      case HifzGrade.medium:
        consecutiveStrong = 0;
        break;

      case HifzGrade.weak:
        consecutiveStrong = 0;
        priorityUntil = td.add(Duration(days: settings.weakRecoveryDays));
        break;
    }

    final newState = state.copyWith(
      stage: stage,
      reviewCount: state.reviewCount + 1,
      lastReviewedAt: td,
      lastGrade: grade,
      consecutiveStrong: consecutiveStrong,
      stageEnteredAt: stageEnteredAt,
      farCyclesSurvived: farCyclesSurvived,
      priorityUntil: priorityUntil,
    );

    final newMeta = registerActivity(
      meta: meta,
      settings: settings,
      today: td,
      reviewedPages: [state.page],
    );

    return HifzGradeResult(page: newState, meta: newMeta);
  }

  // ══════════════════════════════════════════════════════════════
  //  تقييم صفحة في المراجعة الدورية (far) — §3.3
  // ══════════════════════════════════════════════════════════════

  static HifzGradeResult gradeFarPage({
    required HifzPageState state,
    required HifzGrade grade,
    required HifzSettings settings,
    required HifzMeta meta,
    required DateTime today,
  }) {
    final td = dateOnly(today);

    var stage = state.stage;
    var consecutiveStrong = state.consecutiveStrong;
    var farCyclesSurvived = state.farCyclesSurvived;
    var priorityUntil = state.priorityUntil;
    var stageEnteredAt = state.stageEnteredAt;

    switch (grade) {
      case HifzGrade.strong:
        consecutiveStrong += 1;
        break;
      case HifzGrade.medium:
        consecutiveStrong = 0;
        break;
      case HifzGrade.weak:
        consecutiveStrong = 0;
        farCyclesSurvived = 0;
        priorityUntil = td.add(Duration(days: settings.weakRecoveryDays));
        // حد الترقّي السفلي: "متقن" ينزل إلى "قيد المراجعة"،
        // و"قيد المراجعة" لا يرتدّ أبداً إلى "حفظ حديث".
        if (stage == HifzStage.mastered) {
          stage = HifzStage.underReview;
          stageEnteredAt = td;
        }
        break;
    }

    final newState = state.copyWith(
      stage: stage,
      reviewCount: state.reviewCount + 1,
      lastReviewedAt: td,
      lastGrade: grade,
      consecutiveStrong: consecutiveStrong,
      farCyclesSurvived: farCyclesSurvived,
      priorityUntil: priorityUntil,
      stageEnteredAt: stageEnteredAt,
    );

    final newMeta = registerActivity(
      meta: meta,
      settings: settings,
      today: td,
      reviewedPages: [state.page],
    );

    return HifzGradeResult(page: newState, meta: newMeta);
  }

  // ══════════════════════════════════════════════════════════════
  //  تحريك مؤشر المراجعة الدورية + اكتشاف اكتمال الدورة — §3.3
  // ══════════════════════════════════════════════════════════════

  static HifzCursorResult advanceFarCursor({
    required Map<int, HifzPageState> pages,
    required HifzMeta meta,
    required HifzSettings settings,
    required int gradedPage,
    required DateTime today,
  }) {
    final corpus =
        pages.values
            .where((s) => s.stage == HifzStage.underReview || s.stage == HifzStage.mastered)
            .map((s) => s.page)
            .toList()
          ..sort();

    if (corpus.isEmpty) {
      return HifzCursorResult(pages: pages, meta: meta, settings: settings);
    }

    int nextAfter = -1;
    for (final p in corpus) {
      if (p > gradedPage) {
        nextAfter = p;
        break;
      }
    }

    if (nextAfter == -1) {
      // لا توجد صفحة أكبر ضمن المجموعة — اكتملت دورة كاملة.
      final wrappedMeta = meta.copyWith(farReviewCursor: corpus.first);
      final cycle = onCycleComplete(
        pages: pages,
        meta: wrappedMeta,
        settings: settings,
        today: today,
      );
      return HifzCursorResult(
        pages: cycle.pages,
        meta: cycle.meta,
        settings: cycle.settings,
        cycleCompleted: true,
      );
    }

    return HifzCursorResult(
      pages: pages,
      meta: meta.copyWith(farReviewCursor: nextAfter),
      settings: settings,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  اكتمال دورة مراجعة دورية كاملة — ترقية "متقن" + تصعيد/تراجع — §3.3
  // ══════════════════════════════════════════════════════════════

  static HifzCycleResult onCycleComplete({
    required Map<int, HifzPageState> pages,
    required HifzMeta meta,
    required HifzSettings settings,
    required DateTime today,
  }) {
    final td = dateOnly(today);
    final corpus = pages.values
        .where((s) => s.stage == HifzStage.underReview || s.stage == HifzStage.mastered)
        .toList();

    double sum = 0;
    var n = 0;
    for (final s in corpus) {
      if (s.lastGrade != null) {
        sum += _gradeValue(s.lastGrade!);
        n++;
      }
    }
    final avg = n == 0 ? 0.0 : sum / n;

    // ملاحظة (قرار #3 المعتمد): "متقن" شارة فقط — تبقى نفس مجموعة
    // {underReview, mastered} ونفس دورة المسح؛ لا يوجد أي تخطٍّ لدورات
    // بديلة لصفحات "متقن" في هذا المنطق أو في أي مكان آخر بالمخطط.
    final updatedPages = Map<int, HifzPageState>.from(pages);
    for (final s in corpus) {
      // صفحة "نجت" من هذه الدورة إن كان آخر تقييم لها ليس "ضعيف"
      // (تقييم ضعيف أثناء الدورة يكون قد صفّر farCyclesSurvived فوراً).
      final survived = s.lastGrade != null && s.lastGrade != HifzGrade.weak;
      if (!survived) continue;
      var ns = s.copyWith(farCyclesSurvived: s.farCyclesSurvived + 1);
      if (ns.stage == HifzStage.underReview && ns.farCyclesSurvived >= settings.masterAfterFarCycles) {
        ns = ns.copyWith(stage: HifzStage.mastered, stageEnteredAt: td);
      }
      updatedPages[s.page] = ns;
    }

    final newMeta = meta.copyWith(
      farCycleCount: meta.farCycleCount + 1,
      lastCycleAvgGrade: avg,
    );
    final newSettings = escalateReviewPortion(settings, avg);

    return HifzCycleResult(pages: updatedPages, meta: newMeta, settings: newSettings);
  }

  /// تصعيد/تراجع مقدار الورد اليومي للمراجعة الدورية بحسب متوسط
  /// تقييم آخر دورة مكتملة (§3.3). لا يُغيّر أي شيء إن كان
  /// `autoEscalateReview = false` — يحترم القيمة التي ضبطها المستخدم يدوياً.
  static HifzSettings escalateReviewPortion(HifzSettings settings, double lastCycleAvgGrade) {
    if (!settings.autoEscalateReview) return settings;

    const order = [
      HifzPortionUnit.quarterHizb,
      HifzPortionUnit.halfHizb,
      HifzPortionUnit.hizb,
    ];

    var unit = settings.reviewPortionUnit == HifzPortionUnit.page
        ? HifzPortionUnit.quarterHizb
        : settings.reviewPortionUnit;
    var count = settings.reviewPortionCount;
    final maxUnit = settings.reviewPortionMaxUnit == HifzPortionUnit.page
        ? HifzPortionUnit.hizb
        : settings.reviewPortionMaxUnit;

    final unitIndex = order.indexOf(unit);
    final maxIndex = order.indexOf(maxUnit);

    if (lastCycleAvgGrade >= 1.6) {
      if (unitIndex < maxIndex) {
        unit = order[unitIndex + 1];
      } else {
        count = count + 1; // بلغنا السقف — نزيد العدد بدلاً من الوحدة
      }
    } else if (lastCycleAvgGrade < 0.8) {
      if (count > 1) {
        count = count - 1;
      } else if (unitIndex > 0) {
        unit = order[unitIndex - 1];
      }
      // لا ننزل أبداً تحت ربع حزب واحد يومياً.
    }

    return settings.copyWith(reviewPortionUnit: unit, reviewPortionCount: count);
  }

  // ══════════════════════════════════════════════════════════════
  //  تغيير الإعدادات مباشرة — §3.4: لا يُعدِّل أي HifzPageState إطلاقاً.
  // ══════════════════════════════════════════════════════════════

  static HifzMeta onSettingsChanged({
    required Map<int, HifzPageState> pages,
    required HifzMeta meta,
    required HifzSettings settings,
  }) {
    final clamped = meta.farReviewCursor.clamp(1, HifzPageIndex.pageCount);
    if (clamped == meta.farReviewCursor) return meta;
    return meta.copyWith(farReviewCursor: clamped);
  }

  // ══════════════════════════════════════════════════════════════
  //  دوران اليوم (day roll) — §3.5
  // ══════════════════════════════════════════════════════════════

  static HifzMeta rollDay({
    required HifzMeta meta,
    required HifzSettings settings,
    required DateTime today,
  }) {
    final td = dateOnly(today);
    final last = meta.lastActivityDate == null ? null : dateOnly(meta.lastActivityDate!);

    // نفس اليوم (أو لا نشاط بعد) — لا شيء يتغيّر.
    if (last != null && !last.isBefore(td)) return meta;

    var currentStreak = meta.currentStreak;
    final lastMet = meta.lastWirdMetDate == null ? null : dateOnly(meta.lastWirdMetDate!);
    if (lastMet == null) {
      currentStreak = 0;
    } else {
      final gap = daysBetween(lastMet, td);
      if (gap >= 2) currentStreak = 0; // مرّ يوم كامل دون تحقيق الورد
    }

    return meta.copyWith(
      todayNewPages: 0,
      todayReviewPages: 0,
      doneToday: const [],
      currentStreak: currentStreak,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  إحصاءات مشتقة (تُستهلك من hifzProvider في المرحلة 2) — القرارات #4 و#10
  // ══════════════════════════════════════════════════════════════

  /// عدد الصفحات التي بدأ حفظها (أي مرحلة غير notStarted).
  static int memorizedPageCount(Map<int, HifzPageState> pages) =>
      pages.values.where((s) => s.stage != HifzStage.notStarted).length;

  /// النسبة المئوية البسيطة (الرقم الكبير في لوحة التحكم) — القرار #4.
  static double simpleFraction(Map<int, HifzPageState> pages) =>
      memorizedPageCount(pages) / HifzPageIndex.pageCount;

  /// النسبة المرجَّحة (الخط الثانوي الأصغر) بحسب رسوخ كل مرحلة — القرار #4.
  static double consolidatedFraction(Map<int, HifzPageState> pages) {
    var sum = 0.0;
    for (final s in pages.values) {
      sum += _stageWeight(s.stage);
    }
    return sum / HifzPageIndex.pageCount;
  }

  static int masteredPageCount(Map<int, HifzPageState> pages) =>
      pages.values.where((s) => s.stage == HifzStage.mastered).length;

  /// نسبة اكتمال كل جزء (1..30) — تُستخدم لتلوين خريطة الأجزاء (القرار #10).
  /// `weighted=false` (الافتراضي): نسبة الصفحات التي بدأ حفظها فقط.
  /// `weighted=true`: نسبة مرجَّحة بحسب رسوخ المرحلة.
  static Map<int, double> juzCompletion(Map<int, HifzPageState> pages, {bool weighted = false}) {
    final out = <int, double>{};
    for (var j = 1; j <= 30; j++) {
      final juzPages = HifzPageIndex.pagesInJuz(j);
      if (juzPages.isEmpty) {
        out[j] = 0.0;
        continue;
      }
      var acc = 0.0;
      for (final p in juzPages) {
        final stage = pages[p]?.stage ?? HifzStage.notStarted;
        acc += weighted ? _stageWeight(stage) : (stage == HifzStage.notStarted ? 0.0 : 1.0);
      }
      out[j] = acc / juzPages.length;
    }
    return out;
  }
}
