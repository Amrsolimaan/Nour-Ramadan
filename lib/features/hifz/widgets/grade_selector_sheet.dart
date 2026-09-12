import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../models/hifz_models.dart';

// ════════════════════════════════════════════════════════════════
//  grade_selector_sheet — شيت اختيار التقييم الذاتي بعد المراجعة.
//  نفس نمط الشيتات الداكنة المستخدمة في التطبيق (مثال: _showSheikhPicker
//  في quran_home_screen.dart): bg nightCard، حواف علوية 20.r، حدّ
//  borderGold، ومقبض سحب 40×4. plan_hifz.md §4.2.
// ════════════════════════════════════════════════════════════════

/// يعرض شيت التقييم ويُعيد الدرجة المختارة، أو null إن أُغلق الشيت
/// دون اختيار (سحب للأسفل / نقر خارج الشيت).
Future<HifzGrade?> showGradeSelectorSheet(BuildContext context, {String? subtitle}) {
  return showModalBottomSheet<HifzGrade>(
    context: context,
    backgroundColor: AppColors.nightCard,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      side: BorderSide(color: AppColors.borderGold),
    ),
    builder: (_) => _GradeSelectorSheet(subtitle: subtitle),
  );
}

class _GradeSelectorSheet extends StatelessWidget {
  const _GradeSelectorSheet({this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              'كيف كانت المراجعة؟',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.goldLight,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4.h),
              Text(
                subtitle!,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.sp, color: AppColors.textDim),
              ),
            ],
            SizedBox(height: 18.h),
            _GradeButton(
              label: 'ضعيف',
              emoji: '😕',
              color: Colors.redAccent,
              onTap: () => Navigator.pop(context, HifzGrade.weak),
            ),
            SizedBox(height: 10.h),
            _GradeButton(
              label: 'متوسط',
              emoji: '🙂',
              color: AppColors.goldWarm,
              onTap: () => Navigator.pop(context, HifzGrade.medium),
            ),
            SizedBox(height: 10.h),
            _GradeButton(
              label: 'قوي',
              emoji: '💪',
              color: Colors.green,
              onTap: () => Navigator.pop(context, HifzGrade.strong),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String emoji;
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
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: TextStyle(fontSize: 18.sp)),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14.sp,
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
