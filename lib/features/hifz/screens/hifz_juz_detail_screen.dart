import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/data/hifz_page_index.dart';
import '../../../core/services/quran_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/animations/reveal_animation.dart';
import '../../../shared/widgets/gold_card.dart';
import '../../quran/screens/quran_reader_screen.dart';
import '../models/hifz_models.dart';
import '../providers/hifz_provider.dart';
import '../widgets/grade_selector_sheet.dart';
import '../widgets/hifz_app_bar.dart';
import '../widgets/hifz_page_tile.dart';
import '../widgets/hifz_toast.dart';

// ════════════════════════════════════════════════════════════════
//  HifzJuzDetailScreen — تفاصيل الجزء (plan_hifz.md §4.4)
//  تفصيل صفحات جزء واحد + تصحيحات يدوية سريعة. تُعيد استخدام
//  HifzPageTile وgrade_selector_sheet.dart من المرحلة 3 حرفياً (بلا
//  نسخ/تفريع)، وتستدعي فقط أفعال hifzProvider الموجودة أصلاً
//  (markNewlyMemorized/gradePage/resetPage) — لا مسار منطقي جديد.
// ════════════════════════════════════════════════════════════════

class HifzJuzDetailScreen extends ConsumerStatefulWidget {
  const HifzJuzDetailScreen({super.key, required this.juzNumber});

  final int juzNumber;

  @override
  ConsumerState<HifzJuzDetailScreen> createState() => _HifzJuzDetailScreenState();
}

class _HifzJuzDetailScreenState extends ConsumerState<HifzJuzDetailScreen> {
  /// null = "الكل"
  HifzStage? _filter;

  @override
  Widget build(BuildContext context) {
    final hifz = ref.watch(hifzProvider);
    final juzPages = HifzPageIndex.pagesInJuz(widget.juzNumber);
    final juzName = QuranDataService.juzNames[widget.juzNumber - 1];

    HifzStage stageOf(int page) => hifz.pages[page]?.stage ?? HifzStage.notStarted;

    final counts = <HifzStage, int>{
      for (final s in HifzStage.values) s: juzPages.where((p) => stageOf(p) == s).length,
    };
    final started = juzPages.length - counts[HifzStage.notStarted]!;
    final ratio = juzPages.isEmpty ? 0.0 : started / juzPages.length;

    final visiblePages = _filter == null
        ? juzPages
        : juzPages.where((p) => stageOf(p) == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            HifzAppBar(title: 'الجزء ${widget.juzNumber}'),
            if (!hifz.isLoading) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                child: RevealAnimation(
                  child: _JuzHeaderCard(
                    juzName: juzName,
                    ratio: ratio,
                    started: started,
                    total: juzPages.length,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              _FilterChipsRow(
                current: _filter,
                counts: counts,
                total: juzPages.length,
                onSelect: (s) => setState(() => _filter = s),
              ),
              SizedBox(height: 6.h),
            ],
            Expanded(
              child: hifz.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.goldWarm),
                    )
                  : visiblePages.isEmpty
                  ? Center(
                      child: Text(
                        'لا صفحات ضمن هذا التصنيف',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.sp,
                          color: AppColors.textDim,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 32.h),
                      itemCount: visiblePages.length,
                      itemBuilder: (context, index) {
                        final page = visiblePages[index];
                        final state = hifz.pages[page];
                        return _DetailedPageTile(
                          page: page,
                          state: state,
                          onTap: () => _openReader(context, page),
                          onLongPress: () => _showPageActions(context, ref, page, stageOf(page)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── فتح القارئ الحالي بلا أي تعديل عليه — نفس نمط المرحلة 3 ──────
  Future<void> _openReader(BuildContext context, int page) async {
    final ayah = HifzPageIndex.firstAyahOfPage(page);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModernQuranReaderV2(
          surahNumber: ayah.surah,
          initialAyah: ayah.ayah,
          disableAutoAdvance: true,
        ),
      ),
    );
  }

  // ── شيت الإجراءات عند الضغط المطوَّل — plan §4.4 ─────────────────
  Future<void> _showPageActions(
    BuildContext context,
    WidgetRef ref,
    int page,
    HifzStage stage,
  ) async {
    final isNotStarted = stage == HifzStage.notStarted;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.nightCard,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        side: BorderSide(color: AppColors.borderGold),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.borderGold,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                'صفحة $page',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldLight,
                ),
              ),
              SizedBox(height: 18.h),
              // "علّمها محفوظة اليوم" — فقط إن لم تُحفَظ بعد؛ لا يمكن
              // حفظها كـ"جديدة" مرتين — نفس حماية hifzProvider نفسه.
              if (isNotStarted)
                _SheetActionTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'علّمها محفوظة اليوم',
                  color: AppColors.goldWarm,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    // ✅ نفس المسار الحرفي الذي تستخدمه شاشة "حفظ جديد"
                    // (المرحلة 4) — بلا أي منطق موازٍ.
                    await ref.read(hifzProvider.notifier).markNewlyMemorized({page});
                    if (!context.mounted) return;
                    showHifzToast(context, 'تمت إضافة الصفحة $page إلى الحفظ');
                  },
                ),
              // "قيّمها الآن" — فقط للصفحات القابلة للتقييم فعلياً.
              if (!isNotStarted) ...[
                _SheetActionTile(
                  icon: Icons.rate_review_outlined,
                  label: 'قيّمها الآن',
                  color: AppColors.goldLight,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (!context.mounted) return;
                    // ✅ نفس شيت التقييم الحرفي من المرحلة 3 — بلا نسخ.
                    final grade = await showGradeSelectorSheet(context, subtitle: 'صفحة $page');
                    if (grade == null) return;
                    await ref.read(hifzProvider.notifier).gradePage(page, grade);
                    if (!context.mounted) return;
                    showHifzToast(context, 'تم — أحسنت');
                  },
                ),
                SizedBox(height: 10.h),
                _SheetActionTile(
                  icon: Icons.restore_rounded,
                  label: 'أعِد ضبطها',
                  color: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (!context.mounted) return;
                    final confirmed = await _confirmReset(context, page);
                    if (confirmed != true) return;
                    await ref.read(hifzProvider.notifier).resetPage(page);
                    if (!context.mounted) return;
                    showHifzToast(context, 'أُعيد ضبط الصفحة $page');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── تأكيد خفيف قبل "أعِد ضبطها" — إجراء صفحة واحدة، ليس مسحاً شاملاً،
  // فلا يحتاج التأكيد المكتوب الكامل لمنطقة الخطر في شاشة الإعدادات.
  Future<bool?> _confirmReset(BuildContext context, int page) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.nightMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.3)),
        ),
        title: Text(
          'إعادة ضبط الصفحة $page؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.goldWarm,
          ),
        ),
        content: Text(
          'سيُمسَح تقدّمها بالكامل (تاريخ الحفظ، التقييمات، عدد المراجعات) '
          'وتعود إلى "لم يبدأ". هل أنت متأكد؟',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp, color: AppColors.agedPlaster, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13.sp, color: AppColors.textDim),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            child: Text(
              'إعادة ضبط',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ════════════════════════════════════════════════════════════════
//  رأس الشاشة — اسم الجزء + نسبة الاكتمال. plan §4.4 يطلب "حلقة
//  اكتمال (ring)"؛ لا توجد أي حلقة/عجلة تقدّم مشتركة في التطبيق (حتى
//  _OverallProgressCard في لوحة التحكم نفسها رقم نسبة نصّي فقط) —
//  فاستُخدم رقم نسبة نصّي بنفس أسلوب تلك البطاقة تحديداً، دون اختراع
//  أي widget حلقي جديد لهذه الشاشة وحدها.
// ════════════════════════════════════════════════════════════════
class _JuzHeaderCard extends StatelessWidget {
  const _JuzHeaderCard({
    required this.juzName,
    required this.ratio,
    required this.started,
    required this.total,
  });

  final String juzName;
  final double ratio;
  final int started;
  final int total;

  @override
  Widget build(BuildContext context) {
    return GoldCard(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  juzName,
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '$started من $total صفحة',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.sp, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          Text(
            '${(ratio * 100).round()}٪',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.goldWarm,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  صف رقائق التصفية — نفس أسلوب رقائق الاختيار في شاشتَي المرحلتين
//  4 و5 (nightSurface/goldWarm.alpha0.2 عند التحديد، حدّ borderGold/
//  borderGoldStrong، Tajawal 11.sp) — مُعاد بناؤها محلياً هنا كما في
//  كل شاشة سابقة (النمط الثابت منذ المرحلة 2 لعناصر خاصة بملف واحد).
// ════════════════════════════════════════════════════════════════
class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.current,
    required this.counts,
    required this.total,
    required this.onSelect,
  });

  final HifzStage? current;
  final Map<HifzStage, int> counts;
  final int total;
  final ValueChanged<HifzStage?> onSelect;

  static String _label(HifzStage? stage) => switch (stage) {
    null => 'الكل',
    HifzStage.newlyMemorized => 'حفظ حديث',
    HifzStage.underReview => 'قيد المراجعة',
    HifzStage.mastered => 'متقن',
    HifzStage.notStarted => 'لم يبدأ',
  };

  @override
  Widget build(BuildContext context) {
    const order = <HifzStage?>[
      null,
      HifzStage.newlyMemorized,
      HifzStage.underReview,
      HifzStage.mastered,
      HifzStage.notStarted,
    ];

    return SizedBox(
      height: 34.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          for (final stage in order)
            Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: _FilterChip(
                label: '${_label(stage)} (${stage == null ? total : counts[stage]})',
                selected: current == stage,
                onTap: () => onSelect(stage),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        splashColor: AppColors.goldWarm.withValues(alpha: 0.15),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldWarm.withValues(alpha: 0.2) : AppColors.nightSurface,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: selected ? AppColors.borderGoldStrong : AppColors.borderGold,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.goldLight : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  غلاف حول HifzPageTile (من المرحلة 3، بلا أي تعديل على الودجت
//  نفسه سوى onLongPress الاختياري الجديد) يُضيف سطر
//  lastReviewedAt/reviewCount/lastGrade أسفل البلاطة كما يطلب §4.4 —
//  بإضافة، لا بتعديل مضمون HifzPageTile الداخلي.
// ════════════════════════════════════════════════════════════════
class _DetailedPageTile extends StatelessWidget {
  const _DetailedPageTile({
    required this.page,
    required this.state,
    required this.onTap,
    required this.onLongPress,
  });

  final int page;
  final HifzPageState? state;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static String _gradeLabel(HifzGrade grade) => switch (grade) {
    HifzGrade.weak => 'ضعيف',
    HifzGrade.medium => 'متوسط',
    HifzGrade.strong => 'قوي',
  };

  @override
  Widget build(BuildContext context) {
    final stage = state?.stage ?? HifzStage.notStarted;
    final detail = state == null
        ? null
        : [
            if (state!.reviewCount > 0) 'المراجعات: ${state!.reviewCount}',
            if (state!.lastReviewedAt != null)
              'آخر مراجعة: ${_formatDate(state!.lastReviewedAt!)}',
            if (state!.lastGrade != null) 'آخر تقييم: ${_gradeLabel(state!.lastGrade!)}',
          ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HifzPageTile(page: page, stage: stage, onTap: onTap, onLongPress: onLongPress),
        if (detail != null && detail.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(right: 14.w, bottom: 10.h, top: 0),
            child: Transform.translate(
              offset: Offset(0, -6.h),
              child: Text(
                detail,
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 9.sp, color: AppColors.textDim),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        splashColor: color.withValues(alpha: 0.2),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 13.h, horizontal: 14.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18.sp),
              SizedBox(width: 10.w),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
