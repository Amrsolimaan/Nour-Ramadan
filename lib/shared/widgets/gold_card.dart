import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

/// بطاقة ذهبية مشتركة — مطابقة لـ .gold-card في HTML
class GoldCard extends StatelessWidget {
  const GoldCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xF2221A40), // rgba(34,26,64,0.95)
            Color(0xFA160F28), // rgba(22,17,40,0.98)
          ],
        ),
        border: Border.all(
          color: borderColor ?? AppColors.borderGold, // rgba(200,146,42,0.25)
          width: 1,
        ),
        borderRadius: BorderRadius.circular(borderRadius ?? 18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.40),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 18.r),
        child: Stack(
          children: [
            // ── Radial highlight (top-right corner) ──
            Positioned(
              top: -30.r,
              right: -30.r,
              child: Container(
                width: 100.r,
                height: 100.r,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x0FC8922A), // rgba(200,146,42,0.06)
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.7],
                  ),
                ),
              ),
            ),
            // ── Top inner glow line ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.goldWarm.withOpacity(0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // ── Content ──
            Padding(
              padding: padding ?? EdgeInsets.all(18.r),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius ?? 18.r),
        onTap: onTap,
        splashColor: AppColors.shadowGold,
        child: card,
      ),
    );
  }
}

/// عنوان القسم الذهبي — .card-label في HTML
class CardLabel extends StatelessWidget {
  const CardLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(width: 14.w, height: 1, color: AppColors.goldWarm),
          SizedBox(width: 6.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 9.sp,
              letterSpacing: 2,
              color: AppColors.goldWarm,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }
}
