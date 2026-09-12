import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/hifz_page_index.dart';
import '../../../core/services/hifz_service.dart';
import '../logic/hifz_reminder_scheduler.dart';
import '../logic/hifz_scheduler.dart';
import '../models/hifz_models.dart';
import 'hifz_settings_provider.dart';

// ════════════════════════════════════════════════════════════════
//  hifzProvider — حالة تتبع الحفظ (صفحات + بيانات وصفية + سجل جلسات)
//  منمذج على QuranProgressNotifier/LastReadNotifier: state notifier
//  غير قابل للتغيير + copyWith، تحميل في المُنشئ، كل عملية كتابة
//  تمرّ عبر HifzService ثم تُحدِّث الحالة في الذاكرة.
// ════════════════════════════════════════════════════════════════

class HifzState {
  final Map<int, HifzPageState> pages;
  final HifzMeta meta;
  final List<HifzReviewSession> sessions;
  final bool isLoading;

  HifzState({
    this.pages = const {},
    HifzMeta? meta,
    this.sessions = const [],
    this.isLoading = true,
  }) : meta = meta ?? HifzMeta.initial();

  HifzState copyWith({
    Map<int, HifzPageState>? pages,
    HifzMeta? meta,
    List<HifzReviewSession>? sessions,
    bool? isLoading,
  }) {
    return HifzState(
      pages: pages ?? this.pages,
      meta: meta ?? this.meta,
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  // ── إحصاءات مشتقة جاهزة للوحة التحكم (مرحلة لاحقة) — القرارات #4 و#10 ──
  int get memorizedPageCount => HifzScheduler.memorizedPageCount(pages);
  double get simpleFraction => HifzScheduler.simpleFraction(pages);
  double get consolidatedFraction => HifzScheduler.consolidatedFraction(pages);
  int get masteredPageCount => HifzScheduler.masteredPageCount(pages);
  Map<int, double> juzCompletion({bool weighted = false}) =>
      HifzScheduler.juzCompletion(pages, weighted: weighted);
}

class HifzNotifier extends StateNotifier<HifzState> {
  HifzNotifier(this._ref) : super(HifzState(isLoading: true)) {
    _load();
  }

  final Ref _ref;

  // ══════════════════════════════════════════════════════════════
  //  ✅ متابعة المرحلة 5: إعادة جدولة تذكير الورد من خارج هذا الملف
  //
  //  نفس نمط الاستدعاء الثلاثي المُكرَّر في markNewlyMemorized/
  //  undoMarkNewlyMemorized أدناه — أُفرِد كدالة عامة كي يستدعيها
  //  TimezoneFixRescheduleMigration من main.dart دون تكرار حساب
  //  isWirdMet هناك (ولا حاجة لاعتمادية جديدة على HifzScheduler هناك).
  // ══════════════════════════════════════════════════════════════
  Future<void> rescheduleReminderNow() async {
    final settings = _ref.read(hifzSettingsProvider);
    await HifzReminderScheduler.reschedule(
      settings: settings,
      wirdMetToday: HifzScheduler.isWirdMet(
        settings,
        state.meta.todayNewPages,
        state.meta.todayReviewPages,
      ),
    );
  }

  void _load() {
    final pages = HifzService.loadPages();
    final loadedMeta = HifzService.loadMeta();
    final sessions = HifzService.loadSessions();
    final settings = _ref.read(hifzSettingsProvider);

    final rolledMeta = HifzScheduler.rollDay(
      meta: loadedMeta,
      settings: settings,
      today: DateTime.now(),
    );
    if (!identical(rolledMeta, loadedMeta)) {
      // لا ننتظر الكتابة — الحالة في الذاكرة صحيحة فوراً، والتخزين يلحق بها.
      HifzService.saveMeta(rolledMeta);
    }

    state = HifzState(pages: pages, meta: rolledMeta, sessions: sessions, isLoading: false);
  }

  /// إعادة التحميل من التخزين المحلي (مثلاً بعد تغيير الإعدادات).
  Future<void> reload() async {
    _load();
  }

  // ══════════════════════════════════════════════════════════════
  //  حفظ جديد — إنشاء HifzPageState(newlyMemorized) لكل صفحة غير متتبَّعة
  // ══════════════════════════════════════════════════════════════

  /// يُعيد لقطة (snapshot) للحالة كما كانت **قبل** هذا الاستدعاء عند
  /// إضافة صفحة واحدة على الأقل بنجاح (لتغذية زر "تراجع" في شاشة حفظ
  /// جديد — المرحلة 4)، أو `null` إن لم تُضَف أي صفحة (كلها كانت
  /// متتبَّعة مسبقاً أو خارج المدى، أو كانت المجموعة فارغة أصلاً).
  Future<HifzState?> markNewlyMemorized(Set<int> pageNumbers, {DateTime? now}) async {
    if (pageNumbers.isEmpty) return null;
    final previous = state;

    final today = HifzScheduler.dateOnly(now ?? DateTime.now());
    final settings = _ref.read(hifzSettingsProvider);

    final pages = Map<int, HifzPageState>.from(state.pages);
    final added = <int>[];
    for (final p in pageNumbers) {
      if (p < 1 || p > HifzPageIndex.pageCount) continue;
      final existing = pages[p];
      if (existing != null && existing.stage != HifzStage.notStarted) {
        continue; // حماية من التكرار — صفحة متتبَّعة مسبقاً
      }
      pages[p] = HifzScheduler.createNewlyMemorized(p, today);
      added.add(p);
    }
    if (added.isEmpty) return null;
    added.sort();

    final meta = HifzScheduler.registerNewMemorization(
      meta: state.meta,
      settings: settings,
      pages: added,
      today: today,
    );

    final sessions = _appendSession(
      state.sessions,
      date: today,
      kind: 'new',
      pages: added,
      grades: const {},
    );

    await HifzService.savePages(pages);
    await HifzService.saveMeta(meta);
    await HifzService.saveSessions(sessions);
    state = state.copyWith(pages: pages, meta: meta, sessions: sessions);

    // ✅ تذكير الورد اليومي: قد يكون هذا الحفظ الجديد قد حقّق ورد اليوم
    // بذاته — نُعيد الجدولة فوراً لكبت إشعار اليوم إن كان كذلك (يُعيد
    // استخدام HifzScheduler.isWirdMet نفسه، لا حساباً موازياً).
    await HifzReminderScheduler.reschedule(
      settings: settings,
      wirdMetToday: HifzScheduler.isWirdMet(settings, meta.todayNewPages, meta.todayReviewPages),
    );

    return previous;
  }

  // ══════════════════════════════════════════════════════════════
  //  تراجع كامل عن آخر markNewlyMemorized (المرحلة 4) — يُعيد الصفحات
  //  المُضافة + عدّادات اليوم/المواظبة + سجل الجلسات معاً إلى ما كانا
  //  عليه قبل الإضافة، عبر استعادة لقطة الحالة كاملةً. يتعمَّد عدم
  //  استخدام resetPage هنا: resetPage يُصفِّر صفحة واحدة بمعزل عن أي
  //  تراجع في HifzMeta (todayNewPages/المواظبة)، فتكرارها لكل صفحة
  //  مضافة كان سيترك عدّادات اليوم مرتفعة رغم التراجع عن الإضافة —
  //  استعادة اللقطة الكاملة تتجنّب هذه الفجوة تماماً.
  // ══════════════════════════════════════════════════════════════
  Future<void> undoMarkNewlyMemorized(HifzState previousState) async {
    await HifzService.savePages(previousState.pages);
    await HifzService.saveMeta(previousState.meta);
    await HifzService.saveSessions(previousState.sessions);
    state = previousState;

    // التراجع قد يُعيد اليوم إلى "لم يتحقّق الورد بعد" — نُعيد الجدولة
    // كي يرجع إشعار اليوم إن كان قد كُبِت بسبب الإضافة المتراجَع عنها.
    final settings = _ref.read(hifzSettingsProvider);
    await HifzReminderScheduler.reschedule(
      settings: settings,
      wirdMetToday: HifzScheduler.isWirdMet(
        settings,
        previousState.meta.todayNewPages,
        previousState.meta.todayReviewPages,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  تقييم صفحة — يحدِّد تلقائياً إن كانت في قائمة التثبيت أم
  //  المراجعة الدورية، ويطبّق منطق hifz_scheduler المطابق.
  // ══════════════════════════════════════════════════════════════

  Future<void> gradePage(int page, HifzGrade grade, {DateTime? now}) async {
    final current = state.pages[page];
    if (current == null || current.stage == HifzStage.notStarted) return;

    final today = HifzScheduler.dateOnly(now ?? DateTime.now());
    final settings = _ref.read(hifzSettingsProvider);
    final pages = Map<int, HifzPageState>.from(state.pages);

    final pinned = current.priorityUntil != null &&
        !HifzScheduler.dateOnly(current.priorityUntil!).isBefore(today);
    final isNear = current.stage == HifzStage.newlyMemorized || pinned;

    String kind;
    HifzMeta meta;
    HifzSettings settingsAfter = settings;

    if (isNear) {
      final res = HifzScheduler.gradeNearPage(
        state: current,
        grade: grade,
        settings: settings,
        meta: state.meta,
        today: today,
      );
      pages[page] = res.page;
      meta = res.meta;
      kind = 'near';
    } else {
      final graded = HifzScheduler.gradeFarPage(
        state: current,
        grade: grade,
        settings: settings,
        meta: state.meta,
        today: today,
      );
      pages[page] = graded.page;

      final cursor = HifzScheduler.advanceFarCursor(
        pages: pages,
        meta: graded.meta,
        settings: settings,
        gradedPage: page,
        today: today,
      );
      pages
        ..clear()
        ..addAll(cursor.pages);
      meta = cursor.meta;
      settingsAfter = cursor.settings;
      kind = 'far';
    }

    final sessions = _appendSession(
      state.sessions,
      date: today,
      kind: kind,
      pages: [page],
      grades: {page: grade},
    );

    await HifzService.savePages(pages);
    await HifzService.saveMeta(meta);
    await HifzService.saveSessions(sessions);
    state = state.copyWith(pages: pages, meta: meta, sessions: sessions);

    if (!identical(settingsAfter, settings)) {
      await _ref.read(hifzSettingsProvider.notifier).applyEscalated(settingsAfter);
    }

    // ✅ تذكير الورد اليومي: هذا التقييم قد يكون حقّق ورد اليوم بذاته —
    // نُعيد الجدولة فوراً لكبت إشعار اليوم إن كان كذلك.
    await HifzReminderScheduler.reschedule(
      settings: settingsAfter,
      wirdMetToday: HifzScheduler.isWirdMet(
        settingsAfter,
        meta.todayNewPages,
        meta.todayReviewPages,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  إعادة ضبط صفحة (تصحيح/تراجع — الأداة الوحيدة المطلوبة للمرحلة 1)
  // ══════════════════════════════════════════════════════════════

  Future<void> resetPage(int page) async {
    if (!state.pages.containsKey(page)) return;
    final pages = Map<int, HifzPageState>.from(state.pages)..remove(page);
    await HifzService.savePages(pages);
    state = state.copyWith(pages: pages);
  }

  // ── دمج تقييم/إضافة ضمن جلسة اليوم لنفس النوع، أو إنشاء جلسة جديدة ──
  List<HifzReviewSession> _appendSession(
    List<HifzReviewSession> sessions, {
    required DateTime date,
    required String kind,
    required List<int> pages,
    required Map<int, HifzGrade> grades,
  }) {
    final d = HifzScheduler.dateOnly(date);
    for (var i = sessions.length - 1; i >= 0; i--) {
      final s = sessions[i];
      if (s.kind == kind && HifzScheduler.dateOnly(s.date) == d) {
        final mergedPages = {...s.pages, ...pages}.toList()..sort();
        final mergedGrades = {...s.grades, ...grades};
        final updated = s.copyWith(pages: mergedPages, grades: mergedGrades);
        final out = List<HifzReviewSession>.from(sessions);
        out[i] = updated;
        return out;
      }
    }
    return [...sessions, HifzReviewSession(date: d, kind: kind, pages: pages, grades: grades)];
  }
}

final hifzProvider = StateNotifierProvider<HifzNotifier, HifzState>(
  (ref) => HifzNotifier(ref),
);
