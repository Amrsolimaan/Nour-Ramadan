import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

/// بانر "لا يوجد اتصال" يظهر في أعلى الشاشة
/// مطابق لـ offline_banner في الخطة
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: 6.h,
        horizontal: 16.w,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.goldDim.withOpacity(0.9),
            AppColors.stoneWarm.withOpacity(0.9),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 14.r,
            color: AppColors.textPrimary,
          ),
          SizedBox(width: 6.w),
          Text(
            'وضع بدون إنترنت — تعمل بيانات محفوظة',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 10.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
