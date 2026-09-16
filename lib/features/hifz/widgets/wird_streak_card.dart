import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../logic/hifz_scheduler.dart';
import '../models/hifz_models.dart';
import 'hifz_stat_card.dart';

// ════════════════════════════════════════════════════════════════
//  WirdStreakCard — بطاقة الورد والمواظبة (plan_hifz.md §4.1)
//  سلسلة المواظبة الحالية/الأطول + تقدّم اليوم مقابل هدف الورد.
//  عرض فقط (لا كتابة) — الشاشة الأم (hifz_dashboard_screen) هي التي
//  تقرر ما إذا كانت البطاقة تفاعلية أم معطَّلة بصرياً.
// ════════════════════════════════════════════════════════════════

class WirdStreakCard extends StatelessWidget {
  const WirdStreakCard({super.key, required this.meta, required this.settings});

  final HifzMeta meta;
  final HifzSettings settings;

  static String _unitLabel(HifzPortionUnit unit) => switch (unit) {
    HifzPortionUnit.page => 'صفحة',
    HifzPortionUnit.quarterHizb => 'ربع حزب',
    HifzPortionUnit.halfHizb => 'نصف حزب',
    HifzPortionUnit.hizb => 'حزب',
  };

  static String _formatPortion(HifzPortionUnit unit, double count) {
    if (count == 1) return _unitLabel(unit);
    final n = count == count.roundToDouble()
        ? count.toInt().toString()
        : count.toStringAsFixed(1);
    return '$n ${_unitLabel(unit)}';
  }

  @override
  Widget build(BuildContext context) {
    final todayReview = meta.todayReviewPages;
    final newTarget =
        HifzScheduler.pagesForPortion(settings.newPortionUnit, settings.newPortionCount).length;
    final reviewTarget = HifzScheduler.pagesForPortion(
      settings.reviewPortionUnit,
      settings.reviewPortionCount,
    ).length;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF2A1E4A), Color(0xFF1C1230)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: HifzStatCard(
                  icon: '',
                  label: 'المواظبة الحالية',
                  value: '${meta.currentStreak} يوم',
                  iconWidget: Icon(
                    Icons.timelapse_rounded,
                    size: 20.sp,
                    color: AppColors.goldWarm,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 45.h,
                color: AppColors.goldWarm.withValues(alpha: 0.2),
              ),
              Expanded(
                child: HifzStatCard(
                  icon: '',
                  label: 'أطول سلسلة',
                  value: '${meta.longestStreak} يوم',
                  iconWidget: Icon(
                    Icons.workspace_premium_rounded,
                    size: 20.sp,
                    color: AppColors.goldWarm,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.goldWarm.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ورد اليوم: ${_formatPortion(settings.newPortionUnit, settings.newPortionCount)}',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldLight,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'الحفظ الجديد: ${meta.todayNewPages}/$newTarget · المراجعة: $todayReview/$reviewTarget',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.sp,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
