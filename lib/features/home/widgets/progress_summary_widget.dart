import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  ProgressSummaryWidget — ملخص التقدم الرمضاني
//  مطابق لـ HTML: .progress-summary-card (3 إحصاءات + شريط)
// ════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════
//  دالة تنسيق الأرقام الكبيرة (موحدة مع صفحة التقدم)
//  1,000 → 1.0K
//  1,000,000 → 1.0M
//  1,000,000,000 → 1.0B
// ════════════════════════════════════════════════════════════════
String _formatLargeNumber(int number) {
  if (number >= 1000000000) {
    return '${(number / 1000000000).toStringAsFixed(1)}B';
  } else if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toString();
}

class ProgressSummaryWidget extends StatelessWidget {
  const ProgressSummaryWidget({
    super.key,
    required this.completedDays,
    required this.totalDays,
    required this.readSurahs,
    required this.duasRead,
    required this.tasbihCount,
    required this.hijriMonth,
    required this.hijriYear,
  });

  final int completedDays;
  final int totalDays;
  final int readSurahs;
  final int duasRead;
  final int tasbihCount;
  final int hijriMonth;
  final int hijriYear;

  // ── تحديد العنوان حسب الشهر الهجري ──────────────────────
  String _getProgressTitle() {
    if (hijriMonth == 9) {
      return 'تقدمك في رمضان';
    } else if (hijriMonth > 9) {
      return 'إنجازاتك من رمضان';
    } else {
      return 'استعدادك لرمضان';
    }
  }

  // ── تحديد الأيقونة حسب الشهر ──────────────────────────────
  String _getTitleIcon() {
    if (hijriMonth == 9) {
      return '🌙';
    } else if (hijriMonth > 9) {
      return '✨';
    } else {
      return '🌙';
    }
  }

  // ── تحديد النص الفرعي ─────────────────────────────────────
  String _getSubtitle() {
    if (hijriMonth == 9) {
      return '$completedDays/$totalDays يوم';
    } else if (hijriMonth > 9) {
      return 'رمضان $hijriYear';
    } else {
      return 'قريباً';
    }
  }

  // ── هل نعرض شريط التقدم؟ ──────────────────────────────────
  bool _shouldShowProgressBar() {
    return hijriMonth == 9;
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalDays > 0 ? completedDays / totalDays : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF221A3C), Color(0xFF160F28)],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldWarm.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── عنوان ديناميكي ─────────────────────────────────
          Row(
            children: [
              Text(_getTitleIcon(), style: TextStyle(fontSize: 16.sp)),
              SizedBox(width: 8.w),
              Text(
                _getProgressTitle(),
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldLight,
                ),
              ),
              const Spacer(),
              Text(
                _getSubtitle(),
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.sp,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),

          // ── رسالة تحفيزية بعد رمضان ─────────────────────────
          if (hijriMonth > 9) ...[
            SizedBox(height: 8.h),
            Text(
              'استمر في العبادة! 💪',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.sp,
                color: AppColors.goldWarm,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // ── شريط التقدم (فقط أثناء رمضان) ───────────────────
          if (_shouldShowProgressBar()) ...[
            SizedBox(height: 12.h),
            _ProgressBar(progress: progress),
          ],

          SizedBox(height: 16.h),

          // ── الإحصاءات الثلاث ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: '📖',
                  value: _formatLargeNumber(readSurahs), // ✅ تطبيق التنسيق
                  label: 'سورة مقروءة',
                  color: const Color(0xFF34A862),
                ),
              ),
              _Divider(),
              Expanded(
                child: _StatItem(
                  icon: '🤲',
                  value: _formatLargeNumber(duasRead), // ✅ تطبيق التنسيق
                  label: 'دعاء مقروء',
                  color: const Color(0xFF9B59B6),
                ),
              ),
              _Divider(),
              Expanded(
                child: _StatItem(
                  icon: '📿',
                  value: _formatLargeNumber(tasbihCount), // ✅ تطبيق التنسيق
                  label: 'تسبيحة',
                  color: AppColors.goldWarm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 8.h,
          decoration: BoxDecoration(
            color: AppColors.goldWarm.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.01, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.goldWarm,
                      AppColors.goldLight,
                      AppColors.goldGlow,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowGold,
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 2.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'بداية رمضان',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 9.sp,
                color: AppColors.textDim,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 9.sp,
                color: AppColors.goldWarm,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'نهاية رمضان',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 9.sp,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final String icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: TextStyle(fontSize: 18.sp)),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 9.sp,
            color: AppColors.textDim,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50.h,
      color: AppColors.borderGold,
      margin: EdgeInsets.symmetric(horizontal: 8.w),
    );
  }
}
