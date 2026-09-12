import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  HifzSectionHeader — عنوان قسم موحَّد لشاشات الحفظ.
//  إعادة بناء متعمَّدة لنمط _SectionHeader الخاص (private) بـ
//  khatmah_tracking_screen.dart (لا يمكن استيراده مباشرة)، معمَّمة
//  بنص عنوان قابل للتخصيص بدل النص الثابت 'السور' — plan_hifz.md §4.2
//  ("التثبيت" / "المراجعة الدورية").
// ════════════════════════════════════════════════════════════════

class HifzSectionHeader extends StatelessWidget {
  const HifzSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 4.h, bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.goldLight,
          ),
        ),
      ),
    );
  }
}
