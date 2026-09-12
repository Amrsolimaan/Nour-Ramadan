import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/data/hifz_page_index.dart';
import '../../../core/theme/app_colors.dart';
import '../../quran/screens/quran_reader_screen.dart';
import '../models/hifz_models.dart';
import '../providers/hifz_provider.dart';
import '../providers/hifz_today_provider.dart';
import '../widgets/grade_selector_sheet.dart';
import '../widgets/hifz_app_bar.dart';
import '../widgets/hifz_page_tile.dart';
import '../widgets/hifz_section_header.dart';
import '../widgets/hifz_toast.dart';

// ════════════════════════════════════════════════════════════════
//  HifzTodayReviewScreen — مراجعة اليوم (المرحلة 3 — plan_hifz.md §4.2)
//  أول تدفّق حفظ فعلي بالكامل: عرض الطابور → فتح القارئ الحالي بلا
//  أي تعديل عليه → تقييم ذاتي → hifzProvider.gradePage يُطبِّق محرك
//  الجدولة (§3.2/§3.3) → العدّادات/المواظبة تتحرّك فوراً عبر Riverpod.
// ════════════════════════════════════════════════════════════════

class HifzTodayReviewScreen extends ConsumerWidget {
  const HifzTodayReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hifz = ref.watch(hifzProvider);
    final queue = ref.watch(hifzTodayProvider);

    final pendingTotal = queue.total;
    final doneCount = hifz.meta.doneToday.length;
    final grandTotal = pendingTotal + doneCount;
    final nothingAtAll = !hifz.isLoading && grandTotal == 0;

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            const HifzAppBar(title: 'مراجعة اليوم'),
            if (!hifz.isLoading && !nothingAtAll)
              _ProgressBar(doneCount: doneCount, total: grandTotal),
            Expanded(
              child: hifz.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.goldWarm),
                    )
                  : nothingAtAll
                      ? const _EmptyState()
                      : ListView(
                          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
                          children: [
                            if (pendingTotal == 0) const _AllDoneBanner(),
                            if (queue.near.isNotEmpty) ...[
                              const HifzSectionHeader('التثبيت'),
                              for (final item in queue.near)
                                HifzPageTile(
                                  page: item.page,
                                  stage: hifz.pages[item.page]?.stage ?? HifzStage.notStarted,
                                  onTap: () => _openAndGrade(context, ref, item.page),
                                ),
                            ],
                            if (queue.far.isNotEmpty) ...[
                              SizedBox(height: queue.near.isNotEmpty ? 4.h : 0),
                              const HifzSectionHeader('المراجعة الدورية'),
                              for (final item in queue.far)
                                HifzPageTile(
                                  page: item.page,
                                  stage: hifz.pages[item.page]?.stage ?? HifzStage.notStarted,
                                  onTap: () => _openAndGrade(context, ref, item.page),
                                ),
                            ],
                            if (doneCount > 0) ...[
                              SizedBox(height: pendingTotal > 0 ? 4.h : 0),
                              const HifzSectionHeader('أُنجزت اليوم'),
                              for (final page in hifz.meta.doneToday)
                                HifzPageTile(
                                  page: page,
                                  stage: hifz.pages[page]?.stage ?? HifzStage.notStarted,
                                  trailing: HifzPageTileTrailing.done,
                                ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  فتح القارئ الحالي (ModernQuranReaderV2) بلا أي تعديل عليه، مروراً
//  بالآية الأولى للصفحة، ثم عرض شيت التقييم عند العودة، ثم تطبيق
//  التقييم عبر hifzProvider.gradePage، ثم تأكيد عائم موحَّد (hifz_toast.dart).
// ════════════════════════════════════════════════════════════════
Future<void> _openAndGrade(BuildContext context, WidgetRef ref, int page) async {
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
  if (!context.mounted) return;

  final grade = await showGradeSelectorSheet(context, subtitle: 'صفحة $page');
  if (grade == null || !context.mounted) return;

  await ref.read(hifzProvider.notifier).gradePage(page, grade);
  if (!context.mounted) return;

  showHifzToast(context, 'تم — أحسنت');
}

// ════════════════════════════════════════════════════════════════
//  شريط التقدّم — doneToday / (near+far الكلي) — plan_hifz.md §4.2
// ════════════════════════════════════════════════════════════════
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.doneCount, required this.total});

  final int doneCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التقدّم اليوم',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.sp, color: AppColors.textDim),
              ),
              Text(
                '$doneCount/$total',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8.h,
              backgroundColor: AppColors.nightCard,
              valueColor: const AlwaysStoppedAnimation(AppColors.goldWarm),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  حالة فارغة تماماً — لا صفحات متتبَّعة إطلاقاً بعد.
// ════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.goldWarm.withValues(alpha: 0.6),
              size: 44.sp,
            ),
            SizedBox(height: 14.h),
            Text(
              'لا مراجعة اليوم — أحسنت',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.goldLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  شريط تهنئة يظهر أعلى القائمة عندما تُنجَز كل مراجعات اليوم لكن
//  تبقى بعض الصفحات في قسم "أُنجزت اليوم" أسفله للعرض فقط.
// ════════════════════════════════════════════════════════════════
class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.green),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'أحسنت — أنجزت مراجعة اليوم كاملة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
