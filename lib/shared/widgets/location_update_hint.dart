import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  LocationUpdateHint — تلميح بسيط لتحديث الموقع
//  يظهر بشكل أنيق في أعلى الصفحة الرئيسية
//  بدون تخريب التصميم الجميل
// ════════════════════════════════════════════════════════════════

class LocationUpdateHint extends StatelessWidget {
  const LocationUpdateHint({
    super.key,
    required this.onUpdateLocation,
  });

  final VoidCallback onUpdateLocation;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft, // محاذاة لليسار
      child: Container(
        width: 0.6.sw, // 60% من عرض الشاشة
        margin: EdgeInsets.only(left: 20.w, top: 8.h, bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.goldWarm.withValues(alpha: 0.15),
              AppColors.goldLight.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.goldWarm.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // أيقونة
            Icon(
              Icons.location_on_rounded,
              color: AppColors.goldWarm,
              size: 14.sp,
            ),
            
            SizedBox(width: 8.w),
            
            // النص
            Expanded(
              child: Text(
                'انتقلت لمدينة أخرى؟',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.sp,
                  color: AppColors.goldLight,
                  height: 1.2,
                ),
              ),
            ),
            
            SizedBox(width: 6.w),
            
            // زر صغير
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onUpdateLocation,
                borderRadius: BorderRadius.circular(6.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldWarm.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'تحديث',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.goldWarm,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
