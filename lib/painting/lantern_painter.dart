import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  LanternPainter — رسّام الفانوس الكامل بـ CustomPainter
//  مصدر: .lantern CSS في HTML
//  يشمل: رأس فوقي + خيط + جسم + نافذة زجاجية + قاعدة + ضوء
// ════════════════════════════════════════════════════════════════

class LanternPainter extends CustomPainter {
  LanternPainter({
    required this.bodyColor,
    required this.glowColor,
    required this.glowIntensity, // 0.0 → 1.0
    required this.stringLength,
  });

  final Color bodyColor;
  final Color glowColor;
  final double glowIntensity; // يتغير مع animation الوميض
  final double stringLength;  // طول الخيط بالنسبة لارتفاع الـ canvas

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // الخيط
    final stringH = h * stringLength;
    _drawString(canvas, w, stringH);

    // الرأس العلوي (cap top)
    _drawTopCap(canvas, w, stringH);

    // الجسم الرئيسي
    _drawBody(canvas, w, stringH, h);

    // الزجاج الداخلي (نور الشمعة)
    _drawInnerGlow(canvas, w, stringH, h);

    // القاعدة السفلية (cap bottom)
    _drawBottomCap(canvas, w, h);

    // هالة الضوء الخارجية
    _drawOuterGlow(canvas, w, stringH, h);
  }

  // ── الخيط ─────────────────────────────────────────────────
  void _drawString(Canvas canvas, double w, double stringH) {
    final paint = Paint()
      ..color = Colors.brown.shade700.withOpacity(0.70)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, stringH), paint);
  }

  // ── الرأس العلوي ───────────────────────────────────────────
  void _drawTopCap(Canvas canvas, double w, double stringH) {
    final paint = Paint()..color = bodyColor.withOpacity(0.90);

    // مستطيل مع حواف دائرية قليلاً
    final capH = w * 0.25;
    final capW = w * 0.65;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (w - capW) / 2,
        stringH,
        capW,
        capH,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, paint);

    // خط ذهبي فوقي
    final linePaint = Paint()
      ..color = AppColors.goldWarm.withOpacity(0.60)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset((w - capW) / 2, stringH + capH),
      Offset((w + capW) / 2, stringH + capH),
      linePaint,
    );
  }

  // ── الجسم الرئيسي للفانوس ──────────────────────────────────
  void _drawBody(Canvas canvas, double w, double stringH, double h) {
    final topCapH = w * 0.25;
    final bodyTop = stringH + topCapH;
    final bottomCapH = w * 0.20;
    final bodyH = h - bodyTop - bottomCapH;
    final bodyW = w * 0.90;

    // تدرج الجسم (من فوق داكن للمنتصف فاتح)
    final bodyRect = Rect.fromLTWH((w - bodyW) / 2, bodyTop, bodyW, bodyH);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          bodyColor.withOpacity(0.85),
          bodyColor,
          bodyColor.withOpacity(0.80),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bodyRect);

    final rr = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.1));
    canvas.drawRRect(rr, bodyPaint);

    // إطار ذهبي
    final framePaint = Paint()
      ..color = AppColors.goldWarm.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rr, framePaint);

    // خطوط عمودية داخلية (أعمدة الفانوس الزجاجية) — 3 أعمدة
    final colPaint = Paint()
      ..color = bodyColor.withOpacity(0.70)
      ..strokeWidth = 1.0;
    final cols = [0.33, 0.66];
    for (final col in cols) {
      canvas.drawLine(
        Offset((w - bodyW) / 2 + bodyW * col, bodyTop + 2),
        Offset((w - bodyW) / 2 + bodyW * col, bodyTop + bodyH - 2),
        colPaint,
      );
    }
  }

  // ── نور الشمعة الداخلي ─────────────────────────────────────
  void _drawInnerGlow(Canvas canvas, double w, double stringH, double h) {
    final topCapH = w * 0.25;
    final bodyTop = stringH + topCapH + 6;
    final bottomCapH = w * 0.20;
    final bodyH = h - stringH - topCapH - bottomCapH - 8;
    final bodyW = w * 0.75;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.3),
        colors: [
          glowColor.withOpacity(0.55 * glowIntensity),
          glowColor.withOpacity(0.25 * glowIntensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromLTWH((w - bodyW) / 2, bodyTop, bodyW, bodyH),
      );

    canvas.drawOval(
      Rect.fromLTWH((w - bodyW) / 2 + 2, bodyTop, bodyW - 4, bodyH),
      glowPaint,
    );
  }

  // ── القاعدة السفلية ────────────────────────────────────────
  void _drawBottomCap(Canvas canvas, double w, double h) {
    final capH = w * 0.20;
    final capW = w * 0.50;
    final capTop = h - capH;
    final paint = Paint()..color = bodyColor.withOpacity(0.90);

    // الجسم
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH((w - capW) / 2, capTop, capW, capH * 0.7),
      const Radius.circular(2),
    );
    canvas.drawRRect(rr, paint);

    // رأس مخروط أسفل
    final path = Path()
      ..moveTo((w - capW) / 2, capTop + capH * 0.7)
      ..lineTo(w / 2, h)
      ..lineTo((w + capW) / 2, capTop + capH * 0.7)
      ..close();
    canvas.drawPath(path, paint);
  }

  // ── هالة الضوء الخارجية ────────────────────────────────────
  void _drawOuterGlow(Canvas canvas, double w, double stringH, double h) {
    final cx = w / 2;
    final cy = (stringH + h) / 2;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withOpacity(0.45 * glowIntensity),
          glowColor.withOpacity(0.18 * glowIntensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(
        Rect.fromCenter(center: Offset(cx, cy), width: w * 3, height: h * 1.5),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: w * 1.8, height: h * 0.8),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(LanternPainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity;
}

// ════════════════════════════════════════════════════════════════
//  LanternWidget — Widget يجمع الـ Painter مع Animation
// ════════════════════════════════════════════════════════════════

class LanternWidget extends StatefulWidget {
  const LanternWidget({
    super.key,
    required this.color,
    required this.glowColor,
    required this.size,
    this.swayDuration = const Duration(milliseconds: 3500),
    this.swayDelay = Duration.zero,
    this.stringLength = 0.25,
  });

  final Color color;
  final Color glowColor;
  final double size; // عرض الـ widget
  final Duration swayDuration;
  final Duration swayDelay;
  final double stringLength; // 0→1 كنسبة من الارتفاع

  @override
  State<LanternWidget> createState() => _LanternWidgetState();
}

class _LanternWidgetState extends State<LanternWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late final AnimationController _swayCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _swayAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _swayCtrl = AnimationController(
      vsync: this,
      duration: widget.swayDuration,
    );
    _swayAnim = Tween<double>(begin: -0.07, end: 0.07).animate(
      CurvedAnimation(parent: _swayCtrl, curve: Curves.easeInOut),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _glowAnim = Tween<double>(begin: 0.60, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    Future.delayed(widget.swayDelay, () {
      if (mounted) {
        _swayCtrl.repeat(reverse: true);
        _glowCtrl.repeat(reverse: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // إيقاف الـ animations عند الخلفية
      _swayCtrl.stop();
      _glowCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      // استئناف الـ animations عند العودة
      if (!_swayCtrl.isAnimating) {
        _swayCtrl.repeat(reverse: true);
      }
      if (!_glowCtrl.isAnimating) {
        _glowCtrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _swayCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_swayCtrl, _glowCtrl]),
      builder: (context, child) {
        return Transform.rotate(
          angle: _swayAnim.value,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: widget.size,
            height: widget.size * 2.2,
            child: CustomPaint(
              painter: LanternPainter(
                bodyColor: widget.color,
                glowColor: widget.glowColor,
                glowIntensity: _glowAnim.value,
                stringLength: widget.stringLength,
              ),
            ),
          ),
        );
      },
    );
  }
}
