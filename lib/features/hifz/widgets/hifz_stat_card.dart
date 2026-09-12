import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  HifzStatCard — بطاقة إحصاء صغيرة (أيقونة/رمز + تسمية + قيمة)
//  إعادة بناء متعمَّدة لنمط _StatItem الخاص بـ khatmah_tracking_screen.dart
//  (شارة مربّعة ذهبية شفافة + تسمية خافتة + قيمة بارزة) — لا يمكن
//  استيراد _StatItem مباشرةً لأنه خاص (private) بذلك الملف، فأُعيد
//  إنتاج نفس القيم البصرية هنا كوحدة عامة يعاد استخدامها عبر لوحة
//  تحكم الحفظ وبطاقة الورد والمواظبة (plan_hifz.md §4.1 "Reuse: _StatItem").
// ════════════════════════════════════════════════════════════════

class HifzStatCard extends StatelessWidget {
  const HifzStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueFontSize,
    this.iconWidget,
  });

  /// رمز/إيموجي صغير يُعرض داخل شارة — يمكن إخفاؤه بتمرير ''.
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;
  final double? valueFontSize;
  /// ويدجت بديلة راقية (مثل أيقونة ذهبية) — إذا وُجدت تُعرض بدل النص
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    final hasIcon = iconWidget != null || icon.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasIcon)
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.goldWarm.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: iconWidget ?? Text(icon, style: TextStyle(fontSize: 22.sp)),
          )
        else
          // حشوة راقية بدون أيقونة تافهة — خط ذهبي رفيع يليق بروح التطبيق
          Container(
            width: 28.w,
            height: 2.h,
            margin: EdgeInsets.only(bottom: 2.h),
            decoration: BoxDecoration(
              color: AppColors.goldWarm.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(1.r),
            ),
          ),
        SizedBox(height: 6.h),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10.sp,
            color: AppColors.textDim,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: valueFontSize ?? 16.sp,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.goldWarm,
          ),
        ),
      ],
    );
  }
}
