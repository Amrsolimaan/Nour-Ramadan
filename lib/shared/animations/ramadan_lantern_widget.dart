import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  RamadanLanternWidget — فانوس رمضاني 🏮 مبهج
//  يتأرجح ويتلألأ وله توهج ناعم جداً
// ════════════════════════════════════════════════════════════════
class RamadanLanternWidget extends StatefulWidget {
  const RamadanLanternWidget({super.key, this.size = 80});
  final double size;

  @override
  State<RamadanLanternWidget> createState() => _RamadanLanternWidgetState();
}

class _RamadanLanternWidgetState extends State<RamadanLanternWidget>
    with TickerProviderStateMixin {
  late final AnimationController _swayCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _sway;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _swayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _sway = Tween<double>(
      begin: -0.08,
      end: 0.08,
    ).animate(CurvedAnimation(parent: _swayCtrl, curve: Curves.easeInOut));
    _glow = Tween<double>(
      begin: 0.50,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _swayCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: Listenable.merge([_swayCtrl, _glowCtrl]),
      builder: (_, _) => Transform.rotate(
        angle: _sway.value,
        alignment: Alignment.topCenter,
        child: CustomPaint(
          size: Size(s * 0.72, s * 1.42),
          painter: _LanternPainter(glowIntensity: _glow.value),
        ),
      ),
    );
  }
}

// ── الرسام ─────────────────────────────────────────────────────
class _LanternPainter extends CustomPainter {
  const _LanternPainter({required this.glowIntensity});
  final double glowIntensity;

  static const _gold = AppColors.goldWarm; // #C8922A
  static const _goldL = AppColors.goldLight; // #F0C060
  static const _amber = Color(0xFFFF9A00);
  static const _darkAmber = Color(0xFF7A3500);

  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width;
    final h = sz.height;
    final cx = w / 2;

    // ─ 1. سلسلة التعليق ─────────────────────────────────────
    final chainP = Paint()
      ..color = _gold.withValues(alpha: 0.75)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, 0), Offset(cx, h * 0.07), chainP);
    // حلقات
    for (double y = h * 0.01; y < h * 0.065; y += h * 0.022) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, y), width: 5, height: 3.5),
        chainP,
      );
    }

    // ─ 2. رأس هرمي ───────────────────────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(cx, h * 0.07)
        ..lineTo(cx - w * 0.13, h * 0.175)
        ..lineTo(cx + w * 0.13, h * 0.175)
        ..close(),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_goldL.withValues(alpha: 0.90), _gold],
            ).createShader(
              Rect.fromLTWH(cx - w * 0.13, h * 0.07, w * 0.26, h * 0.105),
            ),
    );

    // ─ 3. شريط علوي ──────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.18),
          width: w * 0.76,
          height: h * 0.038,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = _gold,
    );

    // ─ 4. جسم الفانوس ───────────────────────────────────────
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.09, h * 0.20, w * 0.82, h * 0.61),
      topLeft: const Radius.circular(5),
      topRight: const Radius.circular(5),
      bottomLeft: const Radius.circular(22),
      bottomRight: const Radius.circular(22),
    );

    // تدرج دافئ يتغير مع شدة التوهج
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 0.85,
          colors: [
            _amber.withValues(alpha: (0.85 * glowIntensity).clamp(0.55, 0.90)),
            _amber.withValues(alpha: 0.55),
            _darkAmber.withValues(alpha: 0.72),
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(Rect.fromLTWH(0, h * 0.20, w, h * 0.61)),
    );

    // ─ 5. إطار ذهبي ──────────────────────────────────────────
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = _gold
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );

    // ─ 6. أعمدة رأسية (3 أقسام) ─────────────────────────────
    final colP = Paint()
      ..color = _gold.withValues(alpha: 0.60)
      ..strokeWidth = 1.2;
    for (final x in [w * 0.333, w * 0.666]) {
      canvas.drawLine(Offset(x, h * 0.21), Offset(x, h * 0.80), colP);
    }

    // ─ 7. شريط أفقي وسط ─────────────────────────────────────
    canvas.drawLine(
      Offset(w * 0.09, h * 0.505),
      Offset(w * 0.91, h * 0.505),
      Paint()
        ..color = _gold.withValues(alpha: 0.40)
        ..strokeWidth = 1.0,
    );

    // ─ 8. نجوم ديكور ─────────────────────────────────────────
    _star(canvas, Offset(cx, h * 0.35), 5.5, _goldL.withValues(alpha: 0.88));
    _star(
      canvas,
      Offset(w * 0.27, h * 0.35),
      3.5,
      _goldL.withValues(alpha: 0.62),
    );
    _star(
      canvas,
      Offset(w * 0.73, h * 0.35),
      3.5,
      _goldL.withValues(alpha: 0.62),
    );
    _star(canvas, Offset(cx, h * 0.635), 4.5, _goldL.withValues(alpha: 0.72));

    // ─ 9. توهج داخلي ناعم ────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.49),
        width: w * 0.76,
        height: h * 0.54,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _goldL.withValues(alpha: 0.18 * glowIntensity),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(cx, h * 0.49),
                width: w * 0.80,
                height: w * 0.80,
              ),
            ),
    );

    // ─ 10. شريط سفلي ─────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.823),
          width: w * 0.74,
          height: h * 0.038,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = _gold,
    );

    // ─ 11. شرابة ─────────────────────────────────────────────
    canvas.drawLine(
      Offset(cx, h * 0.843),
      Offset(cx, h * 0.96),
      Paint()
        ..color = _gold
        ..strokeWidth = 1.3,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.972), width: 6.5, height: 9),
      Paint()..color = _gold,
    );

    // ─ 12. هالة خارجية خفيفة جداً ────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.50),
        width: w * 1.45,
        height: h * 0.70,
      ),
      Paint()
        ..color = const Color(
          0xFFFFB830,
        ).withValues(alpha: 0.055 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // ─ 13. لمعات جانبية صغيرة ────────────────────────────────
    final sparkP = Paint()
      ..color = _goldL.withValues(alpha: 0.40 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(w * 0.05, h * 0.38), 2.0, sparkP);
    canvas.drawCircle(Offset(w * 0.95, h * 0.36), 1.8, sparkP);
    canvas.drawCircle(Offset(w * 0.04, h * 0.60), 1.5, sparkP);
    canvas.drawCircle(Offset(w * 0.96, h * 0.62), 1.5, sparkP);
  }

  // نجمة 4 نقاط بسيطة
  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    canvas.drawCircle(Offset(c.dx, c.dy - r), r * 0.28, p);
    canvas.drawCircle(Offset(c.dx, c.dy + r), r * 0.28, p);
    canvas.drawCircle(Offset(c.dx - r, c.dy), r * 0.28, p);
    canvas.drawCircle(Offset(c.dx + r, c.dy), r * 0.28, p);
    canvas.drawCircle(c, r * 0.44, p);
  }

  @override
  bool shouldRepaint(_LanternPainter old) => old.glowIntensity != glowIntensity;
}
