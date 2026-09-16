import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/data/hifz_page_index.dart';
import '../../../core/services/quran_service.dart';
import '../../../core/theme/app_colors.dart';
import '../logic/hifz_scheduler.dart';
import '../models/hifz_models.dart';
import '../providers/hifz_provider.dart';
import '../providers/hifz_settings_provider.dart';
import '../widgets/hifz_app_bar.dart';
import '../widgets/hifz_toast.dart';

// ════════════════════════════════════════════════════════════════
//  HifzNewMemorizationScreen — حفظ جديد (المرحلة 4 — plan_hifz.md §4.3)
//  اختيار صفحة/سورة/جزء لتعليمها "حفظ حديث" اليوم، بثلاث طرق اختيار
//  مقروءة في تبويب واحد (نفس قوالب _buildTabBar/_buildNavRow من
//  المرحلة 1)، مع معاينة حيّة وتراجع فوري بعد التأكيد.
// ════════════════════════════════════════════════════════════════

enum _PickerMode { byPage, bySurah, byJuz }

class HifzNewMemorizationScreen extends ConsumerStatefulWidget {
  const HifzNewMemorizationScreen({super.key});

  @override
  ConsumerState<HifzNewMemorizationScreen> createState() =>
      _HifzNewMemorizationScreenState();
}

class _HifzNewMemorizationScreenState
    extends ConsumerState<HifzNewMemorizationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  int _fromPage = 1;
  int _toPage = 1;
  int? _selectedSurah;
  int? _selectedJuz;

  /// يمنع تكرار إطلاق _confirm عند نقر مزدوج سريع قبل انتهاء الكتابة
  /// في Hive — لا علاقة له بمنطق التراجع/markNewlyMemorized نفسه.
  bool _isSubmitting = false;

  _PickerMode get _mode => _PickerMode.values[_tabs.index];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);

    final hifz = ref.read(hifzProvider);
    final settings = ref.read(hifzSettingsProvider);
    final suggested =
        _suggestedFirstPage(hifz.pages, settings.startPreference) ?? 1;
    _fromPage = suggested;
    _toPage = suggested;
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  //  "الجبهة" — أعلى صفحة متتبَّعة حالياً (أو 1 إن لم يُحفظ شيء بعد)،
  //  ثم أول صفحة notStarted عند/بعد تلك النقطة (مع لفّ للبحث عن أي
  //  فجوات سابقة إن لم توجد صفحة صالحة للأمام). عند عدم وجود أي حفظ
  //  بعد، تُحترَم startPreference لاختيار نقطة الانطلاق:
  //   • fromFatihah → الصفحة 1
  //   • fromJuzAmma  → أول صفحة في الجزء 30
  //   • custom       → لا يوجد حقل "بداية مخصّصة" منفصل في HifzSettings
  //     الحالي، فنتراجع لمنطق الجبهة العادي (الصفحة 1) — رصدناها في
  //     تقرير هذه المرحلة كملاحظة تصميم مفتوحة.
  // ══════════════════════════════════════════════════════════════
  static int? _suggestedFirstPage(
    Map<int, HifzPageState> pages,
    HifzStartPreference pref,
  ) {
    final trackedPages = pages.entries
        .where((e) => e.value.stage != HifzStage.notStarted)
        .map((e) => e.key);

    final int start;
    if (trackedPages.isEmpty) {
      start = switch (pref) {
        HifzStartPreference.fromJuzAmma =>
          HifzPageIndex.pagesInJuz(30).isNotEmpty
              ? HifzPageIndex.pagesInJuz(30).first
              : 1,
        HifzStartPreference.fromFatihah || HifzStartPreference.custom => 1,
      };
    } else {
      start = math.min(trackedPages.reduce(math.max) + 1, HifzPageIndex.pageCount);
    }

    bool notStarted(int p) => (pages[p]?.stage ?? HifzStage.notStarted) == HifzStage.notStarted;

    for (var p = start; p <= HifzPageIndex.pageCount; p++) {
      if (notStarted(p)) return p;
    }
    for (var p = 1; p < start; p++) {
      if (notStarted(p)) return p;
    }
    return null; // كل صفحات المصحف متتبَّعة بالفعل
  }

  bool _isNotStarted(HifzState hifz, int page) =>
      (hifz.pages[page]?.stage ?? HifzStage.notStarted) == HifzStage.notStarted;

  Set<int> _resolvePending(HifzState hifz) {
    switch (_mode) {
      case _PickerMode.byPage:
        final lo = math.min(_fromPage, _toPage);
        final hi = math.max(_fromPage, _toPage);
        return {
          for (var p = lo; p <= hi; p++)
            if (_isNotStarted(hifz, p)) p,
        };
      case _PickerMode.bySurah:
        final s = _selectedSurah;
        if (s == null) return {};
        return HifzPageIndex.pagesOfSurah(s).where((p) => _isNotStarted(hifz, p)).toSet();
      case _PickerMode.byJuz:
        final j = _selectedJuz;
        if (j == null) return {};
        return HifzPageIndex.pagesInJuz(j).where((p) => _isNotStarted(hifz, p)).toSet();
    }
  }

  String _previewText(HifzState hifz) {
    switch (_mode) {
      case _PickerMode.byPage:
        final pending = _resolvePending(hifz);
        final lo = math.min(_fromPage, _toPage);
        final hi = math.max(_fromPage, _toPage);
        if (pending.isEmpty) return 'كل صفحات هذا النطاق محفوظة بالفعل';
        return 'ستضيف ${_pageCountLabel(pending.length)} (من $lo إلى $hi)';

      case _PickerMode.bySurah:
        final s = _selectedSurah;
        if (s == null) return 'اختر سورة لعرض صفحاتها';
        final raw = HifzPageIndex.pagesOfSurah(s);
        final pending = _resolvePending(hifz);
        final name = QuranDataService.instance.surahById(s).name;
        if (pending.isEmpty) return 'كل صفحات سورة $name محفوظة بالفعل';
        final skipped = raw.length - pending.length;
        return 'ستضيف ${_pageCountLabel(pending.length)} — سورة $name'
            '${skipped > 0 ? ' ($skipped محفوظة مسبقاً)' : ''}';

      case _PickerMode.byJuz:
        final j = _selectedJuz;
        if (j == null) return 'اختر جزءاً لعرض صفحاته';
        final raw = HifzPageIndex.pagesInJuz(j);
        final pending = _resolvePending(hifz);
        if (pending.isEmpty) return 'كل صفحات هذا الجزء محفوظة بالفعل';
        final skipped = raw.length - pending.length;
        return 'ستضيف ${_pageCountLabel(pending.length)} — الجزء $j'
            '${skipped > 0 ? ' ($skipped محفوظة مسبقاً)' : ''}';
    }
  }

  static String _pageCountLabel(int n) => n == 1 ? 'صفحة واحدة' : '$n صفحة';

  static String _unitLabel(HifzPortionUnit unit) => switch (unit) {
    HifzPortionUnit.page => 'صفحة',
    HifzPortionUnit.quarterHizb => 'ربع حزب',
    HifzPortionUnit.halfHizb => 'نصف حزب',
    HifzPortionUnit.hizb => 'حزب',
  };

  Future<void> _confirm(HifzState hifz) async {
    // يمنع تكرار الإطلاق عند نقر مزدوج سريع قبل انتهاء الكتابة في Hive.
    if (_isSubmitting) return;

    final pending = _resolvePending(hifz);
    if (pending.isEmpty) {
      showHifzToast(context, 'لا صفحات جديدة لإضافتها');
      return;
    }

    setState(() => _isSubmitting = true);
    final previous = await ref.read(hifzProvider.notifier).markNewlyMemorized(pending);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (previous == null) return;

    final count = pending.length;
    showHifzUndoToast(
      context,
      message: 'تمت إضافة ${_pageCountLabel(count)} إلى الحفظ',
      actionLabel: 'تراجع',
      onAction: () => ref.read(hifzProvider.notifier).undoMarkNewlyMemorized(previous),
    );

    setState(() {
      // تحديث المقترَح التالي بعد الإضافة (خصوصاً في وضع "بحسب الصفحة").
      final updated = ref.read(hifzProvider);
      final suggested = _suggestedFirstPage(
        updated.pages,
        ref.read(hifzSettingsProvider).startPreference,
      );
      if (suggested != null) {
        _fromPage = suggested;
        _toPage = suggested;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hifz = ref.watch(hifzProvider);
    final settings = ref.watch(hifzSettingsProvider);
    final pending = _resolvePending(hifz);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            const HifzAppBar(title: 'حفظ جديد'),
            if (!hifz.isLoading) ...[
              SizedBox(height: 10.h),
              Builder(
                builder: (_) {
                  final suggestedFirst = _suggestedFirstPage(
                    hifz.pages,
                    settings.startPreference,
                  );
                  if (suggestedFirst == null) return const SizedBox.shrink();

                  final portionPages = HifzScheduler.pagesForPortion(
                    settings.newPortionUnit,
                    settings.newPortionCount,
                    startCursor: suggestedFirst,
                  );

                  return _SuggestedPortionBanner(
                    unitLabel: _unitLabel(settings.newPortionUnit),
                    firstPage: suggestedFirst,
                    onTap: () => setState(() {
                      _tabs.animateTo(_PickerMode.byPage.index);
                      _fromPage = portionPages.first;
                      _toPage = portionPages.last;
                    }),
                  );
                },
              ),
            ],
            SizedBox(height: 10.h),
            _buildModeTabBar(),
            SizedBox(height: 10.h),
            Expanded(
              child: hifz.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.goldWarm),
                    )
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _PageRangeTab(
                          from: _fromPage,
                          to: _toPage,
                          onFromChanged: (v) => setState(() {
                            _fromPage = v;
                            if (_toPage < _fromPage) _toPage = _fromPage;
                          }),
                          onToChanged: (v) => setState(() {
                            _toPage = v;
                            if (_fromPage > _toPage) _fromPage = _toPage;
                          }),
                        ),
                        _SurahTab(
                          hifz: hifz,
                          selected: _selectedSurah,
                          onSelect: (s) => setState(() => _selectedSurah = s),
                        ),
                        _JuzTab(
                          hifz: hifz,
                          selected: _selectedJuz,
                          onSelect: (j) => setState(() => _selectedJuz = j),
                        ),
                      ],
                    ),
            ),
            if (!hifz.isLoading)
              _ConfirmBar(
                previewText: _previewText(hifz),
                enabled: pending.isNotEmpty && !_isSubmitting,
                onConfirm: () => _confirm(hifz),
              ),
          ],
        ),
      ),
    );
  }

  // ── صف التبويبات الثلاثة — نفس قالب _buildTabBar/_buildNavRow (المرحلة 1) ──
  Widget _buildModeTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      height: 44.h,
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold, width: 1.0),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: BoxDecoration(
          color: AppColors.goldWarm.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.borderGoldStrong),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp),
        labelColor: AppColors.goldLight,
        unselectedLabelColor: AppColors.textDim,
        tabs: const [
          Tab(text: 'بحسب الصفحة'),
          Tab(text: 'بحسب السورة'),
          Tab(text: 'بحسب الجزء'),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  بانر الورد المقترَح — "وردك: <وحدة> — الصفحة N التالية"
//  نقره يملأ تبويب "بحسب الصفحة" بنطاق الورد المقترَح تلقائياً.
// ════════════════════════════════════════════════════════════════
class _SuggestedPortionBanner extends StatelessWidget {
  const _SuggestedPortionBanner({
    required this.unitLabel,
    required this.firstPage,
    required this.onTap,
  });

  final String unitLabel;
  final int firstPage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          splashColor: AppColors.goldWarm.withValues(alpha: 0.15),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.goldWarm.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.goldWarm, size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'وردك المقترح: $unitLabel — الصفحة $firstPage التالية',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.goldLight,
                    ),
                  ),
                ),
                Icon(Icons.arrow_back_ios_new, color: AppColors.goldWarm, size: 11.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  تبويب "بحسب الصفحة" — عدّادان (من/إلى)
// ════════════════════════════════════════════════════════════════
class _PageRangeTab extends StatelessWidget {
  const _PageRangeTab({
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
  });

  final int from;
  final int to;
  final ValueChanged<int> onFromChanged;
  final ValueChanged<int> onToChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      children: [
        _PageStepper(label: 'من صفحة', value: from, onChanged: onFromChanged),
        SizedBox(height: 12.h),
        _PageStepper(label: 'إلى صفحة', value: to, onChanged: onToChanged),
      ],
    );
  }
}

class _PageStepper extends StatelessWidget {
  const _PageStepper({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp, color: AppColors.textPrimary),
          ),
          const Spacer(),
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 44.w,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.goldWarm,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: value < HifzPageIndex.pageCount ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 30.r,
          height: 30.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.goldWarm.withValues(alpha: enabled ? 0.12 : 0.04),
            border: Border.all(
              color: AppColors.goldWarm.withValues(alpha: enabled ? 0.4 : 0.15),
            ),
          ),
          child: Icon(
            icon,
            size: 16.sp,
            color: enabled ? AppColors.goldWarm : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  تبويب "بحسب السورة"
// ════════════════════════════════════════════════════════════════
class _SurahTab extends StatelessWidget {
  const _SurahTab({required this.hifz, required this.selected, required this.onSelect});

  final HifzState hifz;
  final int? selected;
  final ValueChanged<int> onSelect;

  bool _isNotStarted(int page) =>
      (hifz.pages[page]?.stage ?? HifzStage.notStarted) == HifzStage.notStarted;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: QuranDataService.surahs.length,
      itemBuilder: (context, index) {
        final surah = QuranDataService.surahs[index];
        final rawPages = HifzPageIndex.pagesOfSurah(surah.number);
        final pendingCount = rawPages.where(_isNotStarted).length;
        final allTracked = pendingCount == 0;
        final isSelected = selected == surah.number;

        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.goldWarm.withValues(alpha: 0.12) : AppColors.nightCard,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? AppColors.goldWarm : AppColors.borderGold,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Opacity(
            opacity: allTracked ? 0.5 : 1.0,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
              child: InkWell(
                onTap: allTracked ? null : () => onSelect(surah.number),
                borderRadius: BorderRadius.circular(12.r),
                splashColor: AppColors.goldWarm.withValues(alpha: 0.15),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  child: Row(
                    children: [
                      Container(
                        width: 34.r,
                        height: 34.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.goldWarm.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            '${surah.number}',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldWarm,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              surah.name,
                              style: TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              allTracked
                                  ? '${rawPages.length} صفحة — محفوظة بالفعل'
                                  : '${rawPages.length} صفحة'
                                        '${pendingCount < rawPages.length ? ' · $pendingCount متبقية' : ''}',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10.sp,
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, color: AppColors.goldWarm, size: 20.sp)
                      else if (allTracked)
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18)
                      else
                        Icon(Icons.arrow_back_ios_new, color: AppColors.textDim, size: 12.sp),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  تبويب "بحسب الجزء" — شبكة 6×5، نفس شكل خلية JuzCompletionMap
//  (مُعاد بناؤها هنا محلياً لأن _JuzCell خاصة بذلك الملف) لكن قابلة
//  للاختيار بدل كونها عرضاً فقط.
// ════════════════════════════════════════════════════════════════
class _JuzTab extends StatelessWidget {
  const _JuzTab({required this.hifz, required this.selected, required this.onSelect});

  final HifzState hifz;
  final int? selected;
  final ValueChanged<int> onSelect;

  bool _isNotStarted(int page) =>
      (hifz.pages[page]?.stage ?? HifzStage.notStarted) == HifzStage.notStarted;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: 30,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        final juz = i + 1;
        final rawPages = HifzPageIndex.pagesInJuz(juz);
        final pendingCount = rawPages.where(_isNotStarted).length;
        final allTracked = pendingCount == 0;
        final isSelected = selected == juz;

        return Opacity(
          opacity: allTracked ? 0.4 : 1.0,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
            child: InkWell(
              onTap: allTracked ? null : () => onSelect(juz),
              borderRadius: BorderRadius.circular(10.r),
              splashColor: AppColors.goldWarm.withValues(alpha: 0.2),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.goldWarm : AppColors.nightCard,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isSelected ? AppColors.goldGlow : AppColors.borderGold,
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$juz',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.nightDeep : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  الشريط السفلي الثابت — نص المعاينة الحيّة + زر التأكيد.
// ════════════════════════════════════════════════════════════════
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.previewText,
    required this.enabled,
    required this.onConfirm,
  });

  final String previewText;
  final bool enabled;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        border: Border(top: BorderSide(color: AppColors.borderGold)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            previewText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enabled ? onConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldWarm,
                disabledBackgroundColor: AppColors.goldWarm.withValues(alpha: 0.25),
                padding: EdgeInsets.symmetric(vertical: 13.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'أضِف إلى الحفظ',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.nightDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
