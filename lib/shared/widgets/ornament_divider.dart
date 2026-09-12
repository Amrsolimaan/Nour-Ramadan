import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

/// خط منقط ذهبي مع ❖ — مطابق لـ .geo-border-sm
class GeoBorderDivider extends StatelessWidget {
  const GeoBorderDivider({super.key, this.backgroundColor});
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFF130F2A);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: CustomPaint(
        size: Size(double.infinity, 2.h),
        painter: _GeoBorderPainter(bg: bg),
      ),
    );
  }
}

class _GeoBorderPainter extends CustomPainter {
  const _GeoBorderPainter({required this.bg});
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.goldWarm.withOpacity(0.40)
      ..strokeWidth = 1.5;

    // Dashed horizontal line
    double x = 20;
    while (x < size.width - 20) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 5, size.height / 2), paint);
      x += 11;
    }

    // ❖ decorators at edges (drawn as rotated rectangles)
    _drawDiamond(canvas, Offset(10, size.height / 2), paint);
    _drawDiamond(canvas, Offset(size.width - 10, size.height / 2), paint);
  }

  void _drawDiamond(Canvas canvas, Offset center, Paint paint) {
    final path = Path();
    const size = 5.0;
    path.moveTo(center.dx, center.dy - size);
    path.lineTo(center.dx + size * 0.6, center.dy);
    path.lineTo(center.dx, center.dy + size);
    path.lineTo(center.dx - size * 0.6, center.dy);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// زخرفة عربية ❋ ✦ ❋ — مطابقة لـ .ornament
class OrnamentText extends StatelessWidget {
  const OrnamentText({super.key, this.text = '❋ ✦ ❋'});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.goldWarm.withOpacity(0.35),
          fontSize: 10.sp,
          letterSpacing: 6,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }
}

/// عنوان قسم ذهبي مع خطوط جانبية — .gold-section-title + .settings-title
class GoldSectionTitle extends StatelessWidget {
  const GoldSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
      child: Row(
        children: [
          Container(width: 12.w, height: 1, color: AppColors.goldWarm),
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
          SizedBox(width: 6.w),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.goldWarm.withOpacity(0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط تقدم ذهبي رفيع
class GoldProgressBar extends StatelessWidget {
  const GoldProgressBar({super.key, required this.value, this.height = 2});
  final double value; // 0.0 → 1.0
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height.h,
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withOpacity(0.12),
        borderRadius: BorderRadius.circular(1.r),
      ),
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        alignment: Alignment.centerRight,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.goldWarm, AppColors.goldLight],
            ),
            borderRadius: BorderRadius.circular(1.r),
          ),
        ),
      ),
    );
  }
}

/// مؤشر دوار انتظار بلون ذهبي
class GoldCircularProgress extends StatelessWidget {
  const GoldCircularProgress({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: const AlwaysStoppedAnimation(AppColors.goldWarm),
      ),
    );
  }
}
