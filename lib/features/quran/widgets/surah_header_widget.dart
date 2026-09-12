import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/local_quran_service.dart';

// ════════════════════════════════════════════════════════════════
//  SurahHeaderWidget — رأس السورة المدمج
//  يعرض: اسم السورة، مكان النزول، عدد الآيات
// ════════════════════════════════════════════════════════════════

class SurahHeaderWidget extends StatelessWidget {
  final SurahInfo surahInfo;
  
  const SurahHeaderWidget({
    super.key,
    required this.surahInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.goldWarm.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // معلومات السورة في المنتصف
          Column(
            children: [
              // اسم السورة
              Text(
                'سورة ${surahInfo.name}',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mushafInk,
                ),
              ),
              
              SizedBox(height: 6.h),
              
              // معلومات السورة
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoChip(
                    icon: Icons.location_on_outlined,
                    text: surahInfo.type == 'meccan' ? 'مكية' : 'مدنية',
                  ),
                  SizedBox(width: 8.w),
                  _buildInfoChip(
                    icon: Icons.format_list_numbered_rounded,
                    text: '${surahInfo.totalVerses} آية',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.goldWarm.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10.sp,
            color: AppColors.goldWarm,
          ),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 9.sp,
              color: AppColors.mushafInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
