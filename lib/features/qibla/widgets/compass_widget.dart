import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  CompassWidget — البوصلة المرسومة بـ CustomPainter
//  تعادل: .compass-outer + .compass-needle + .compass-labels
// ════════════════════════════════════════════════════════════════

class CompassWidget extends StatefulWidget {
  /// زاوية إبرة القبلة (بالراديان) — 0 = شمال
  final double? qiblahRadians;

  /// هل البوصلة في وضع التحميل؟
  final bool isLoading;

  const CompassWidget({
    super.key,
    this.qiblahRadians,
    this.isLoading = false,
  });

  @override
  State<CompassWidget> createState() => _CompassWidgetState();
}

// ════════════════════════════════════════════════════════════════
//  دالة مساعدة لحساب إذا كان السهم موجه للقبلة
// ════════════════════════════════════════════════════════════════
bool _isPointingToQibla(double angleInRadians) {
  // تحويل الزاوية إلى درجات
  final degrees = (angleInRadians * 180 / math.pi) % 360;
  // نعتبر أن السهم موجه للقبلة إذا كان ضمن نطاق ±5 درجات من 0
  return degrees.abs() <= 5 || (360 - degrees).abs() <= 5;
}

class _CompassWidgetState extends State<CompassWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _needleAnim; // تغيير من late إلى nullable
  double _currentAngle = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    // تهيئة الزاوية الأولية إذا كانت موجودة
    if (widget.qiblahRadians != null) {
      _currentAngle = widget.qiblahRadians!;
    }
  }

  @override
  void didUpdateWidget(CompassWidget old) {
    super.didUpdateWidget(old);
    if (widget.qiblahRadians != null &&
        widget.qiblahRadians != old.qiblahRadians) {
      final target = widget.qiblahRadians!;
      _needleAnim = Tween<double>(
        begin: _currentAngle,
        end: target,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0);
      _currentAngle = target;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 200.w;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final angle = _needleAnim?.value ?? _currentAngle;
          final isAligned = _isPointingToQibla(angle);
          return CustomPaint(
            painter: _CompassPainter(
              needleAngle: angle,
              isAlignedWithQibla: isAligned,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── الكعبة في الأعلى (خارج الإبرة) ──────────────
                Positioned(
                  top: 16.w,
                  child: Text('🕋', style: TextStyle(fontSize: 16.sp)),
                ),
                // ── المركز الذهبي ─────────────────────────────────
                Container(
                  width: 14.w,
                  height: 14.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [AppColors.goldGlow, AppColors.goldWarm],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldWarm.withValues(
                          alpha: isAligned ? 0.9 : 0.6,
                        ),
                        blurRadius: isAligned ? 16 : 8,
                        spreadRadius: isAligned ? 2 : 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  CustomPainter — ترسم الدائرة والإبرة والتسميات
// ════════════════════════════════════════════════════════════════
class _CompassPainter extends CustomPainter {
  final double needleAngle; // بالراديان
  final bool isAlignedWithQibla; // هل السهم موجه للقبلة؟

  const _CompassPainter({
    required this.needleAngle,
    required this.isAlignedWithQibla,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── 1. الدائرة الخارجية مع توهج عند التوجه للقبلة ──────────
    // توهج خارجي إضافي عند التوجه للقبلة
    if (isAlignedWithQibla) {
      canvas.drawCircle(
        center,
        radius - 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = AppColors.goldGlow.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isAlignedWithQibla ? 3 : 2
        ..color = AppColors.goldWarm.withValues(
          alpha: isAlignedWithQibla ? 0.85 : 0.45,
        ),
    );

    // ── 2. الدائرة الداخلية (inset 8px كما في CSS) ────────────
    canvas.drawCircle(
      center,
      radius - 10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isAlignedWithQibla ? 1.2 : 0.8
        ..color = AppColors.goldWarm.withValues(
          alpha: isAlignedWithQibla ? 0.35 : 0.15,
        ),
    );

    // ── 3. تدرج الخلفية الشفاف مع توهج عند التوجه للقبلة ──────
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: isAlignedWithQibla
            ? [
                AppColors.goldGlow.withValues(alpha: 0.15),
                AppColors.goldWarm.withValues(alpha: 0.08),
                Colors.transparent,
              ]
            : [
                AppColors.goldWarm.withValues(alpha: 0.04),
                Colors.transparent,
              ],
        stops: isAlignedWithQibla ? [0.0, 0.5, 1.0] : null,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 2, bgPaint);

    // ── 4. أقسام التدريج (خطوط صغيرة على المحيط) ─────────────
    final tickPaint = Paint()
      ..color = AppColors.goldWarm.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (int i = 0; i < 36; i++) {
      final a = (i * 10) * math.pi / 180;
      final isMajor = i % 9 == 0;
      final inner = radius - (isMajor ? 16 : 10);
      final outer = radius - 3;
      canvas.drawLine(
        center + Offset(math.cos(a - math.pi / 2) * inner,
            math.sin(a - math.pi / 2) * inner),
        center + Offset(math.cos(a - math.pi / 2) * outer,
            math.sin(a - math.pi / 2) * outer),
        tickPaint
          ..strokeWidth = isMajor ? 1.5 : 0.7
          ..color = AppColors.goldWarm.withValues(alpha: isMajor ? 0.4 : 0.18),
      );
    }

    // ── 5. الإبرة الذهبية الموحدة ─────────────────────────────
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(needleAngle);

    // سهم واحد ذهبي بطول السهمين معاً (من الأسفل للأعلى)
    // الطول الكلي = 0.58 + 0.35 = 0.93 من نصف القطر
    _drawUnifiedNeedle(
      canvas,
      Offset(0, radius * 0.35), // نقطة البداية (الأسفل)
      Offset(0, -(radius * 0.58)), // نقطة النهاية (الأعلى)
      isAlignedWithQibla,
    );

    canvas.restore();

    // ── 6. تسميات الاتجاهات (N S E W) ────────────────────────
    _drawLabel(canvas, 'N', center + Offset(0, -(radius - 22)), true);
    _drawLabel(canvas, 'S', center + Offset(0, radius - 22), false);
    _drawLabel(canvas, 'E', center + Offset(-(radius - 22), 0), false);
    _drawLabel(canvas, 'W', center + Offset(radius - 22, 0), false);
  }

  void _drawUnifiedNeedle(Canvas canvas, Offset from, Offset to, bool isGlowing) {
    // رسم السهم الذهبي الموحد
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: isGlowing
            ? [
                AppColors.goldWarm,
                AppColors.goldGlow,
                const Color(0xFFFFE57F), // ذهبي ساطع عند التوجه للقبلة
              ]
            : [
                AppColors.goldWarm,
                AppColors.goldGlow,
              ],
      ).createShader(Rect.fromPoints(from, to))
      ..strokeWidth = isGlowing ? 4.5 : 3.5
      ..strokeCap = StrokeCap.round;

    // رسم الخط الرئيسي
    canvas.drawLine(from, to, paint);

    // إضافة توهج إضافي عند التوجه للقبلة
    if (isGlowing) {
      final glowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.goldWarm.withValues(alpha: 0.3),
            AppColors.goldGlow.withValues(alpha: 0.5),
            const Color(0xFFFFE57F).withValues(alpha: 0.6),
          ],
        ).createShader(Rect.fromPoints(from, to))
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(from, to, glowPaint);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, bool isNorth) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          color: isNorth
              ? const Color(0xFFEE5533)
              : AppColors.goldWarm.withValues(alpha: 0.8),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.needleAngle != needleAngle ||
      old.isAlignedWithQibla != isAlignedWithQibla;
}
