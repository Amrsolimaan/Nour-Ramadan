import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
//  CairoStreetPainter â€” ط®ظ„ظپظٹط© ط´ط§ط±ط¹ ط§ظ„ظ‚ط§ظ‡ط±ط© ط§ظ„ط±ظ…ط¶ط§ظ†ظٹط©
//  ظ…طµط¯ط± ط§ظ„ط¨ظٹط§ظ†ط§طھ: SVG ط¯ط§ط®ظ„ ظ…ظ„ظپ HTML (viewBox="0 0 296 160")
//  ظٹط´ظ…ظ„: ط³ظ…ط§ط، + ظ†ط¬ظˆظ… + ظ‚ظ…ط± + ظ…ط¨ط§ظ†ظٹ + ظ…ط¢ط°ظ† + ظ‚ط¨ط§ط¨ + ط´ط§ط±ط¹ + ط¶ظˆط،
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class CairoStreetPainter extends CustomPainter {
  CairoStreetPainter({
    required this.starPhases,
    required this.moonOffset,
    required this.isNight,
  });

  /// ظ‚ظٹظ… ظپظٹ [0,1] â€” ظˆط§ط­ط¯ط© ظ„ظƒظ„ ظ†ط¬ظ…ط© ظ„طھظˆظ„ظٹط¯ طھظ„ط£ظ„ط£ ظ…ظ†ظپطµظ„
  final List<double> starPhases;

  /// ط¥ط²ط§ط­ط© ط§ظ„ظ‚ظ…ط± (0â†’1) â†’ translateY(-14px)
  final double moonOffset;

  /// true = ظˆط¶ط¹ ط§ظ„ظ„ظٹظ„طŒ false = ط§ظ„ظ†ظ‡ط§ط±
  final bool isNight;

  // â”€â”€ ط£ظ„ظˆط§ظ† ط§ظ„ظˆط¶ط¹ ط§ظ„ظ„ظٹظ„ظٹ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const _bldDark = Color(0xFF3C2E1A);
  static const _bldDark2 = Color(0xFF38281A);
  static const _bldMid = Color(0xFF1A0E04);
  static const _archBrown = Color(0xFF4A3820);
  static const _minaret = Color(0xFF2E2818);
  static const _gold = AppColors.goldWarm;
  static const _windowGlow = Color(0x80FFD250);
  static const _streetDark = Color(0xFF1A1208);
  static const _streetGlow = Color(0x4CFFB432);

  // â”€â”€ ط£ظ„ظˆط§ظ† ط§ظ„ظˆط¶ط¹ ط§ظ„ظ†ظ‡ط§ط±ظٹ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const _bldDay = Color(0xFFD4A870);
  static const _bldDay2 = Color(0xFFCC9868);
  static const _winDay = Color(0xCCFFE88C);
  static const _streetDay = Color(0xFFD0A868);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 296;
    final sy = size.height / 160;

    _drawSky(canvas, size);
    _drawStars(canvas, size);
    _drawMoon(canvas, size, sx, sy);
    _drawStreet(canvas, size, sx, sy);
    _drawBuildings(canvas, size, sx, sy);
    _drawBuildingGlow(canvas, size);
  }

  // â”€â”€ 1. ط§ظ„ط³ظ…ط§ط، â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _drawSky(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    if (isNight) {
      paint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF03020F),
          Color(0xFF0A0720),
          Color(0xFF120E2E),
          Color(0xFF1A132A),
          Color(0xFF221A2E),
        ],
        stops: [0.0, 0.25, 0.50, 0.75, 1.0],
      ).createShader(rect);
    } else {
      paint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF8AAFD0),
          Color(0xFFC4DDF5),
          Color(0xFFE6D8BE),
          Color(0xFFD2BE96),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ).createShader(rect);
    }
    canvas.drawRect(rect, paint);
  }

  // â”€â”€ 2. ط§ظ„ظ†ط¬ظˆظ… â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _drawStars(Canvas canvas, Size size) {
    if (!isNight || starPhases.isEmpty) return;
    final rng = math.Random(42);
    final paint = Paint();
    for (int i = 0; i < math.min(starPhases.length, 60); i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.55;
      final r = rng.nextDouble() * 1.5 + 0.4;
      paint.color = Colors.white.withValues(
        alpha: (0.15 + starPhases[i] * 0.75).clamp(0.0, 1.0),
      );
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  // â”€â”€ 3. ط§ظ„ظ‚ظ…ط± â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _drawMoon(Canvas canvas, Size size, double sx, double sy) {
    if (!isNight) return;
    final moonX = size.width - 60 * sx;
    final r = 22 * sx;
    // ط§ظ„ظ‚ظ…ط± ظٹظ†ط²ظ„ ظ…ظ† ظپظˆظ‚ ظ‚ظ„ظٹظ„ط§ظ‹ (ظ…ظ† ط®ظ„ظپ ط­ط¨ظ„ ط§ظ„ظپظˆط§ظ†ظٹط³)
    // ظٹط¨ط¯ط£ ظ…ط®ظپظٹط§ظ‹ ظپظˆظ‚ ط§ظ„ط´ط§ط´ط© ط¨ظ…ظ‚ط¯ط§ط± ظ‚ط·ط±ظ‡ ظپظ‚ط· ط«ظ… ظٹظ†ط²ظ„ ط¥ظ„ظ‰ ظ…ظˆط¶ط¹ظ‡
    final targetY = 31.5 * sy;
    final startY =
        targetY -
        r * 3; // ظٹط¨ط¯ط£ 3 ط£ظ‚ط·ط§ط± ظپظˆظ‚ ظ…ظˆط¶ط¹ظ‡ ط§ظ„ظ†ظ‡ط§ط¦ظٹ â€” ط­ط±ظƒط© ط®ظپظٹظپط©
    final moonY = startY + (targetY - startY) * moonOffset;

    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.goldLight.withValues(alpha: 0.20),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(moonX, moonY), radius: r * 3),
          );
    canvas.drawCircle(Offset(moonX, moonY), r * 3, haloPaint);

    final moonPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: const [Color(0xFFFFF8DC), Color(0xFFF0C060), Color(0xFFC8922A)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(moonX, moonY), radius: r));

    // رسم الهلال بدلاً من الدائرة الكاملة
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(moonX, moonY), radius: r));

    // اقتطاع الجزء الداخلي ليصبح هلالاً
    final cutPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(moonX + r * 0.35, moonY - r * 0.08),
          radius: r * 0.75,
        ),
      );

    final crescent = Path.combine(PathOperation.difference, path, cutPath);
    canvas.drawPath(crescent, moonPaint);
  }

  // â”€â”€ 4. ط§ظ„ط´ط§ط±ط¹ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _drawStreet(Canvas canvas, Size size, double sx, double sy) {
    final streetPaint = Paint()..color = isNight ? _streetDark : _streetDay;
    final streetTop = 152 * sy;
    canvas.drawRect(
      Rect.fromLTWH(0, streetTop, size.width, size.height - streetTop),
      streetPaint,
    );

    if (isNight) {
      final glowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, _streetGlow],
        ).createShader(Rect.fromLTWH(0, 130 * sy, size.width, 30 * sy));
      canvas.drawRect(
        Rect.fromLTWH(0, 130 * sy, size.width, 30 * sy),
        glowPaint,
      );

      final blobPaint = Paint()..style = PaintingStyle.fill;
      for (final b in [
        (40.0, 158.0, 35.0, 4.0, 0.22),
        (100.0, 158.0, 40.0, 4.0, 0.18),
        (165.0, 158.0, 45.0, 4.0, 0.25),
        (232.0, 158.0, 45.0, 4.0, 0.20),
        (278.0, 158.0, 28.0, 4.0, 0.18),
      ]) {
        blobPaint.color = const Color(0xFFFFBE3C).withValues(alpha: b.$5);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(b.$1 * sx, b.$2 * sy),
            width: b.$3 * sx * 2,
            height: b.$4 * sy * 2,
          ),
          blobPaint,
        );
      }
    }
  }

  // â”€â”€ 5. ط§ظ„ظ…ط¨ط§ظ†ظٹ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _drawBuildings(Canvas canvas, Size size, double sx, double sy) {
    // ط§ظ„ظ…ط¨ط§ظ†ظٹ طھط£ط®ط° ~28% ظ…ظ† ط£ط³ظپظ„ ط§ظ„ط´ط§ط´ط© ظپظ‚ط·
    canvas.save();
    canvas.translate(0, size.height * 0.62);
    canvas.scale(1.0, 0.418);
    isNight
        ? _drawNightBuildings(canvas, sx, sy)
        : _drawDayBuildings(canvas, sx, sy);
    canvas.restore();
  }

  void _drawNightBuildings(Canvas canvas, double sx, double sy) {
    final bld = Paint()..style = PaintingStyle.fill;
    final win = Paint()..color = _windowGlow;

    // â”€â”€ B1 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    bld.color = _bldDark;
    canvas.drawRect(_r(0, 48, 58, 107, sx, sy), bld);
    _drawArch(canvas, 0, 49, 58, 7, sx, sy, bld);
    _drawArchWindow(canvas, 4, 50, 20, 19, sx, sy, win, 0.42);
    _drawArchWindow(canvas, 34, 50, 20, 19, sx, sy, win, 0.35);
    bld.color = _archBrown;
    canvas.drawRect(_r(0, 70, 58, 2, sx, sy), bld);
    bld.color = _bldMid;
    canvas.drawRect(_r(0, 72, 58, 19, sx, sy), bld);
    _drawMashrabiya(canvas, 2, 74, 16, 15, sx, sy, win, 0.25);
    _drawMashrabiya(canvas, 20, 74, 16, 15, sx, sy, win, 0.32);
    _drawMashrabiya(canvas, 38, 74, 17, 15, sx, sy, win, 0.20);
    bld.color = _archBrown;
    canvas.drawRect(_r(0, 91, 58, 2, sx, sy), bld);
    _drawArchWindow(canvas, 4, 93, 22, 16, sx, sy, win, 0.45);
    _drawArchWindow(canvas, 32, 93, 22, 16, sx, sy, win, 0.40);
    bld.color = const Color(0xFF221408);
    canvas.drawRect(_r(0, 112, 58, 43, sx, sy), bld);
    _drawArch(
      canvas,
      3,
      120,
      24,
      35,
      sx,
      sy,
      Paint()..color = const Color(0x26FFA028),
    );
    _drawArch(
      canvas,
      31,
      120,
      28,
      35,
      sx,
      sy,
      Paint()..color = const Color(0x26FFA028),
    );

    // â”€â”€ ظ…ط¦ط°ظ†ط© B1 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    bld.color = _minaret;
    canvas.drawRect(_r(58, 14, 7, 50, sx, sy), bld);
    _drawSpire(canvas, 57, 2, 66, 14, sx, sy);
    _drawGoldTip(canvas, 61.5, 0, sx, sy);

    // â”€â”€ B2 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    bld.color = _bldDark2;
    canvas.drawRect(_r(65, 28, 53, 127, sx, sy), bld);
    _drawGeometricBand(canvas, 69, 42, 45, 20, sx, sy);
    bld.color = _archBrown;
    canvas.drawRect(_r(65, 63, 53, 2, sx, sy), bld);
    _drawArchWindow(canvas, 67, 65, 14, 16, sx, sy, win, 0.50);
    _drawArchWindow(canvas, 85, 65, 14, 16, sx, sy, win, 0.55);
    bld.color = _bldMid;
    canvas.drawRect(_r(65, 85, 53, 18, sx, sy), bld);
    _drawMashrabiya(canvas, 67, 87, 15, 14, sx, sy, win, 0.30);
    _drawMashrabiya(canvas, 85, 87, 15, 14, sx, sy, win, 0.38);
    _drawMashrabiya(canvas, 103, 87, 13, 14, sx, sy, win, 0.22);
    bld.color = const Color(0xFF1C1008);
    canvas.drawRect(_r(65, 121, 53, 34, sx, sy), bld);

    // â”€â”€ B3 ظ…ط¹ ظ‚ط¨ط© â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    bld.color = const Color(0xFF3A2C18);
    canvas.drawRect(_r(118, 36, 54, 119, sx, sy), bld);
    _drawDome(canvas, 127, 20, 36, 16, sx, sy);
    _drawGoldTip(canvas, 145, 4, sx, sy);
    _drawGeometricBand(canvas, 121, 37, 48, 19, sx, sy);
    bld.color = _archBrown;
    canvas.drawRect(_r(118, 57, 54, 2, sx, sy), bld);
    _drawArchWindow(canvas, 120, 59, 14, 17, sx, sy, win, 0.55);
    _drawArchWindow(canvas, 138, 59, 16, 17, sx, sy, win, 0.60);
    bld.color = _bldMid;
    canvas.drawRect(_r(118, 79, 54, 17, sx, sy), bld);
    _drawMashrabiya(canvas, 120, 81, 17, 13, sx, sy, win, 0.32);
    _drawMashrabiya(canvas, 141, 81, 17, 13, sx, sy, win, 0.28);
    bld.color = const Color(0xFF1E1209);
    canvas.drawRect(_r(118, 118, 54, 37, sx, sy), bld);

    // â”€â”€ B4 ط¨ط±ط¬ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    bld.color = const Color(0xFF342818);
    canvas.drawRect(_r(172, 12, 24, 143, sx, sy), bld);
    _drawSmallDome(canvas, 171, 3, 26, 13, sx, sy);
    _drawGoldTip(canvas, 184, 0, sx, sy);
    win.color = _windowGlow.withValues(alpha: 0.40);
    canvas.drawRect(_r(178, 33, 12, 34, sx, sy), win);

    // â”€â”€ B5 ظƒط¨ظٹط± â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    bld.color = const Color(0xFF3C2E1C);
    canvas.drawRect(_r(196, 32, 69, 123, sx, sy), bld);
    _drawGeometricBand(canvas, 202, 44, 61, 20, sx, sy);
    bld.color = _archBrown;
    canvas.drawRect(_r(196, 65, 69, 2, sx, sy), bld);
    win.color = _windowGlow;
    _drawArchWindow(canvas, 199, 67, 14, 18, sx, sy, win, 0.50);
    _drawArchWindow(canvas, 217, 67, 16, 18, sx, sy, win, 0.55);
    _drawArchWindow(canvas, 235, 67, 16, 18, sx, sy, win, 0.42);
    _drawArchWindow(canvas, 250, 67, 14, 18, sx, sy, win, 0.45);
    bld.color = _bldMid;
    canvas.drawRect(_r(196, 88, 69, 18, sx, sy), bld);
    _drawMashrabiya(canvas, 199, 90, 18, 14, sx, sy, win, 0.28);
    _drawMashrabiya(canvas, 221, 90, 18, 14, sx, sy, win, 0.33);
    _drawMashrabiya(canvas, 243, 90, 18, 14, sx, sy, win, 0.22);
    bld.color = const Color(0xFF1E1008);
    canvas.drawRect(_r(196, 120, 69, 35, sx, sy), bld);

    // â”€â”€ B6 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    bld.color = const Color(0xFF362A18);
    canvas.drawRect(_r(265, 44, 31, 111, sx, sy), bld);
    _drawArchWindow(canvas, 267, 47, 12, 19, sx, sy, win, 0.48);
    _drawArchWindow(canvas, 281, 47, 11, 19, sx, sy, win, 0.42);
    bld.color = _bldMid;
    canvas.drawRect(_r(265, 69, 31, 17, sx, sy), bld);
    _drawMashrabiya(canvas, 267, 71, 12, 13, sx, sy, win, 0.30);
    _drawMashrabiya(canvas, 282, 71, 12, 13, sx, sy, win, 0.28);
    bld.color = const Color(0xFF1C1008);
    canvas.drawRect(_r(265, 108, 31, 47, sx, sy), bld);
  }

  void _drawDayBuildings(Canvas canvas, double sx, double sy) {
    final bld = Paint()..style = PaintingStyle.fill;
    final win = Paint()..color = _winDay;

    bld.color = _bldDay;
    canvas.drawRect(_r(0, 48, 58, 107, sx, sy), bld);
    _drawArchWindow(canvas, 6, 50, 16, 19, sx, sy, win, 0.70);
    _drawArchWindow(canvas, 36, 50, 16, 19, sx, sy, win, 0.65);

    bld.color = _bldDay2;
    canvas.drawRect(_r(65, 28, 53, 127, sx, sy), bld);
    _drawArchWindow(canvas, 69, 65, 10, 16, sx, sy, win, 0.75);
    _drawArchWindow(canvas, 87, 65, 10, 16, sx, sy, win, 0.70);

    bld.color = const Color(0xFFD49A70);
    canvas.drawRect(_r(118, 36, 54, 119, sx, sy), bld);
    _drawDome(canvas, 127, 20, 36, 16, sx, sy);
    _drawGoldTip(canvas, 145, 4, sx, sy);
    _drawArchWindow(canvas, 122, 59, 10, 17, sx, sy, win, 0.72);
    _drawArchWindow(canvas, 140, 59, 12, 17, sx, sy, win, 0.78);

    bld.color = const Color(0xFFC49068);
    canvas.drawRect(_r(172, 12, 24, 143, sx, sy), bld);

    bld.color = const Color(0xFFD8A278);
    canvas.drawRect(_r(196, 32, 69, 123, sx, sy), bld);
    _drawArchWindow(canvas, 201, 67, 10, 18, sx, sy, win, 0.72);
    _drawArchWindow(canvas, 219, 67, 12, 18, sx, sy, win, 0.75);

    bld.color = _bldDay2;
    canvas.drawRect(_r(265, 44, 31, 111, sx, sy), bld);
    _drawArchWindow(canvas, 269, 47, 8, 19, sx, sy, win, 0.68);

    bld.color = const Color(0xFFB08040);
    canvas.drawRect(_r(58, 14, 7, 50, sx, sy), bld);
    _drawSpire(canvas, 57, 2, 66, 14, sx, sy);
    _drawGoldTip(canvas, 61.5, 0, sx, sy);
  }

  // â”€â”€ 6. طھظˆظ‡ط¬ ظپظˆظ‚ ط§ظ„ظ…ط¨ط§ظ†ظٹ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _drawBuildingGlow(Canvas canvas, Size size) {
    final top = size.height * 0.37;
    final Paint glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isNight
            ? [
                Colors.transparent,
                const Color(0x0FC88C28),
                const Color(0x1FB47828),
                const Color(0x33A06414),
              ]
            : [
                Colors.transparent,
                const Color(0x14C89628),
                const Color(0x24B48028),
              ],
        stops: isNight ? const [0.0, 0.35, 0.65, 1.0] : const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, top, size.width, size.height - top));
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, size.height - top),
      glowPaint,
    );
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Rect _r(double x, double y, double w, double h, double sx, double sy) =>
      Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy);

  void _drawArchWindow(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double sx,
    double sy,
    Paint basePaint,
    double opacity,
  ) {
    final paint = Paint()
      ..color = basePaint.color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    final rect = _r(x, y, w, h, sx, sy);
    final radius = (w * sx) / 2;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      ),
      paint,
    );
  }

  void _drawArch(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double sx,
    double sy,
    Paint paint,
  ) {
    final path = Path()
      ..moveTo(x * sx, (y + h) * sy)
      ..lineTo(x * sx, y * sy)
      ..conicTo((x + w / 2) * sx, (y - h * 0.4) * sy, (x + w) * sx, y * sy, 0.7)
      ..lineTo((x + w) * sx, (y + h) * sy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawMashrabiya(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double sx,
    double sy,
    Paint basePaint,
    double opacity,
  ) {
    final paint = Paint()
      ..color = basePaint.color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRect(_r(x, y, w, h, sx, sy), paint);
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(x * sx, (y + h / 2) * sy),
      Offset((x + w) * sx, (y + h / 2) * sy),
      linePaint,
    );
    canvas.drawLine(
      Offset((x + w / 2) * sx, y * sy),
      Offset((x + w / 2) * sx, (y + h) * sy),
      linePaint,
    );
  }

  void _drawGeometricBand(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double sx,
    double sy,
  ) {
    final paint = Paint()
      ..color = AppColors.goldWarm.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final count = (w / 10).floor();
    for (int i = 0; i < count; i++) {
      final cx = (x + i * 10 + 5) * sx;
      final cy = (y + h / 2) * sy;
      final r = (h / 2) * sy * 0.8;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: r * 1.2,
          height: r * 1.2,
        ),
        paint,
      );
    }
  }

  void _drawDome(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double sx,
    double sy,
  ) {
    final paint = Paint()..color = const Color(0xFF28200E);
    final cy = (y + h) * sy;
    final cx2 = (x + w / 2) * sx;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx2, cy),
        width: w * sx,
        height: h * sy * 2,
      ),
      math.pi,
      math.pi,
      true,
      paint,
    );
    canvas.drawRect(
      _r(x, y + h - 2, w, 2, sx, sy),
      Paint()..color = const Color(0xFF2C2412),
    );
  }

  void _drawSmallDome(
    Canvas canvas,
    double x,
    double y,
    double w,
    double r,
    double sx,
    double sy,
  ) {
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset((x + w / 2) * sx, (y + r) * sy),
        width: w * sx,
        height: r * sy * 2,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF28200E),
    );
  }

  void _drawSpire(
    Canvas canvas,
    double x1,
    double ya,
    double x2,
    double yb,
    double sx,
    double sy,
  ) {
    final mid = (x1 + x2) / 2;
    canvas.drawPath(
      Path()
        ..moveTo(x1 * sx, yb * sy)
        ..lineTo(mid * sx, ya * sy)
        ..lineTo(x2 * sx, yb * sy)
        ..close(),
      Paint()..color = const Color(0xFF26220E),
    );
  }

  void _drawGoldTip(Canvas canvas, double cx, double cy, double sx, double sy) {
    canvas.drawLine(
      Offset(cx * sx, cy * sy),
      Offset(cx * sx, (cy + 2) * sy),
      Paint()
        ..color = _gold
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(cx * sx, cy * sy),
      1.5 * sx,
      Paint()..color = _gold,
    );
    canvas.drawCircle(
      Offset(cx * sx, cy * sy),
      3 * sx,
      Paint()
        ..color = _gold.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(CairoStreetPainter oldDelegate) =>
      oldDelegate.starPhases != starPhases ||
      oldDelegate.moonOffset != moonOffset ||
      oldDelegate.isNight != isNight;
}

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
//  CairoStreetBackground â€” Widget ظٹط¬ظ…ط¹ ط§ظ„ظ€ Painter ظ…ط¹ Animation
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class CairoStreetBackground extends StatefulWidget {
  const CairoStreetBackground({super.key, this.isNight = true, this.child});

  final bool isNight;
  final Widget? child;

  @override
  State<CairoStreetBackground> createState() => _CairoStreetBackgroundState();
}

class _CairoStreetBackgroundState extends State<CairoStreetBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _starCount = 60;
  late final AnimationController _starCtrl;
  late final AnimationController _moonCtrl;
  late final Animation<double> _moonAnim;
  late final List<Animation<double>> _starAnims;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final rng = math.Random(42);

    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _starAnims = List.generate(_starCount, (i) {
      final phase = rng.nextDouble();
      return Tween<double>(
        begin: phase * 0.4,
        end: phase,
      ).animate(CurvedAnimation(parent: _starCtrl, curve: Curves.easeInOut));
    });

    _moonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward(); // ظٹظ†ط²ظ„ ط§ظ„ظ‚ظ…ط± ظ…ظ† ط®ظ„ظپ ط­ط¨ظ„ ط§ظ„ظپظˆط§ظ†ظٹط³ ط¥ظ„ظ‰ ظ…ظˆط¶ط¹ظ‡ ط¨ط­ط±ظƒط© ط³ظ„ط³ط©
    _moonAnim = CurvedAnimation(parent: _moonCtrl, curve: Curves.easeOut);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // إيقاف الـ animations عند الخلفية
      _starCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      // استئناف الـ animations عند العودة
      if (!_starCtrl.isAnimating) {
        _starCtrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _starCtrl.dispose();
    _moonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_starCtrl, _moonCtrl]),
      builder: (context, child) {
        final phases = List<double>.generate(
          _starCount,
          (i) => _starAnims[i].value,
        );
        return CustomPaint(
          painter: CairoStreetPainter(
            starPhases: phases,
            moonOffset: _moonAnim.value,
            isNight: widget.isNight,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
