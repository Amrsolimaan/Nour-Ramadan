import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ornament_divider.dart';

class PrayerCountdownWidget extends StatelessWidget {
  const PrayerCountdownWidget({
    super.key,
    required this.prayerName,
    required this.timeLeft,
    required this.progress,
    this.hijriDate = '',
    this.gregorianDate = '',
    this.onTap,
  });

  final String prayerName;
  final String timeLeft;
  final double progress;
  final String hijriDate;
  final String gregorianDate;
  final VoidCallback? onTap;

  bool _isMainPrayer(String name) {
    const mainPrayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    return mainPrayers.contains(name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF2A1E4A), Color(0xFF1C1230)],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowGold,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: Padding(
            padding: EdgeInsets.all(18.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hijriDate,
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 13.sp,
                            color: AppColors.goldLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          gregorianDate,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.sp,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderGoldStrong),
                        borderRadius: BorderRadius.circular(20.r),
                        color: AppColors.goldWarm.withValues(alpha: 0.08),
                      ),
                      child: Text(
                        ' وقت الصلاة 🕌',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10.sp,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                const GeoBorderDivider(),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isMainPrayer(prayerName))
                          Text(
                            'الصلاة القادمة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10.sp,
                              color: AppColors.textDim,
                              letterSpacing: 1,
                            ),
                          ),
                        if (_isMainPrayer(prayerName)) SizedBox(height: 4.h),
                        Text(
                          prayerName,
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            shadows: [
                              Shadow(
                                color: AppColors.goldGlow.withValues(
                                  alpha: 0.40,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'المتبقي',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.sp,
                            color: AppColors.textDim,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          timeLeft,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                _PrayerProgressBar(progress: progress),
                SizedBox(height: 6.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9.sp,
                        color: AppColors.goldWarm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrayerProgressBar extends StatelessWidget {
  const _PrayerProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6.h,
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3.r),
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
              borderRadius: BorderRadius.circular(3.r),
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
    );
  }
}
