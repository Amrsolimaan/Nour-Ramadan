import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  HifzAppBar — شريط رأس موحَّد لشاشات الحفظ (زر رجوع دائري + عنوان)
//  مستخرج من نمط _AppBar في khatmah_tracking_screen.dart (plan_hifz.md §4)
//  ليُعاد استخدامه في كل شاشات lib/features/hifz دون تكرار الترميز.
// ════════════════════════════════════════════════════════════════

class HifzAppBar extends StatelessWidget {
  const HifzAppBar({super.key, required this.title, this.trailing});

  final String title;

  /// عنصر اختياري في الطرف المقابل لزر الرجوع — null افتراضياً، فيبقى
  /// السلوك الحالي (SizedBox موازن بعرض 38.r فقط) دون أي تغيير على أي
  /// شاشة حفظ حالية لا تمرّره. يُستخدم أول مرة في hifz_dashboard_screen.dart
  /// لزر الدليل (Icons.help_outline_rounded).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.35),
                  width: 1,
                ),
                color: AppColors.goldWarm.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.goldLight,
                size: 15.sp,
              ),
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.agedPlaster,
            ),
          ),
          const Spacer(),
          trailing ?? SizedBox(width: 38.r),
        ],
      ),
    );
  }
}
