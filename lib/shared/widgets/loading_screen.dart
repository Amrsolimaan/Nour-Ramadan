import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../painting/cairo_street_painter.dart';
import '../../painting/lantern_painter.dart';
import '../animations/ramadan_lantern_widget.dart';

// ════════════════════════════════════════════════════════════════
//  LoadingScreen — شاشة البداية الكاملة
//  مطابقة لـ HTML: .splash-screen (dark + light)
//  تحتوي على:
//   • خلفية CairoStreetBackground (مباني + نجوم + قمر)
//   • فوانيس متأرجحة مضيئة (صف أمامي + صف خلفي)
//   • شعار التطبيق (هلال + «نور رمضان» + tagline)
//   • شريط تحميل ذهبي
//   • ظلام تدريجي فوق المباني
//  يدعم وضع الليل والنهار
// ════════════════════════════════════════════════════════════════

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, this.onFinished, this.isNight = true});

  /// ينتقل للـ Home بعد انتهاء التحميل
  final VoidCallback? onFinished;

  /// وضع ليل=true / نهار=false
  final bool isNight;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  late final AnimationController _progressCtrl;
  late final AnimationController _brandCtrl;
  late final AnimationController _fadeOutCtrl;

  // ── Animations ───────────────────────────────────────────────
  late final Animation<double> _progressAnim; // شريط التقدم 0→1
  late final Animation<double> _brandFade; // ظهور الشعار
  late final Animation<Offset> _brandSlide; // انزلاق الشعار
  late final Animation<double> _fadeOutAnim; // تلاشي الشاشة

  static const _splashDuration = Duration(milliseconds: 3800);

  @override
  void initState() {
    super.initState();

    // ── شريط التقدم (0→1 في 3.5 ثانية) ───────────────────────
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));

    // ── ظهور الشعار (fade + slide في 0.9 ثانية) ───────────────
    _brandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _brandFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _brandCtrl, curve: Curves.easeOut));
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _brandCtrl, curve: Curves.easeOut));

    // ── تلاشي الشاشة عند الانتهاء ─────────────────────────────
    _fadeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeOutAnim = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeIn));

    // ── تسلسل الأنيميشن ───────────────────────────────────────
    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. ابدأ الشريط + الشعار معاً بعد 300ms
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _progressCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _brandCtrl.forward();

    // 2. انتظر انتهاء التحميل
    await Future.delayed(_splashDuration);
    if (!mounted) return;

    // 3. تلاشي
    await _fadeOutCtrl.forward();
    if (!mounted) return;

    // 4. انتقل للـ Home
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _brandCtrl.dispose();
    _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeOutAnim,
      builder: (context, child) =>
          Opacity(opacity: _fadeOutAnim.value, child: child),
      child: Scaffold(
        backgroundColor: AppColors.nightDeep,
        body: Stack(
          children: [
            // ── 1. خلفية مباني القاهرة ────────────────────────
            Positioned.fill(
              child: CairoStreetBackground(isNight: widget.isNight),
            ),

            // ── 2. فوانيس خلفية صغيرة ─────────────────────────
            _BackLanternRow(isNight: widget.isNight),

            // ── 3. فوانيس أمامية كبيرة ────────────────────────
            _FrontLanternRow(isNight: widget.isNight),

            // ── 4. ظلام تدريجي فوق كل شيء ────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.transparent,
                      Colors.transparent,
                      AppColors.nightDeep.withValues(alpha: 0.70),
                    ],
                    stops: const [0.0, 0.30, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // ── 5. شعار + تحميل (الشمعة فوق المباني) ────────────
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    // شمعة + نص تأخذ كل المساحة فوق شريط التحميل
                    Expanded(
                      child: Center(
                        child: _BrandSection(
                          fadeAnim: _brandFade,
                          slideAnim: _brandSlide,
                          isNight: widget.isNight,
                        ),
                      ),
                    ),
                    // شريط التحميل في الأسفل فوق المباني
                    Padding(
                      padding: EdgeInsets.only(bottom: 36.h),
                      child: _ProgressSection(progressAnim: _progressAnim),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _BackLanternRow — صف الفوانيس الصغيرة في الخلف
// ════════════════════════════════════════════════════════════════
class _BackLanternRow extends StatelessWidget {
  const _BackLanternRow({required this.isNight});
  final bool isNight;

  static const _lanterns = [
    // (x نسبة, ارتفاع خيط, حجم, لون, glow, تأخير ms)
    (0.08, 0.06, 27.0, Color(0xFF8B3A24), Color(0xFFFF6040), 900),
    (0.22, 0.05, 21.0, Color(0xFF6B4A1C), Color(0xFFFFAA30), 1700),
    (0.40, 0.07, 24.0, Color(0xFF3A6B2A), Color(0xFF60E840), 600),
    (0.60, 0.05, 21.0, Color(0xFF1C3A7A), Color(0xFF4080FF), 2100),
    (0.75, 0.06, 24.0, Color(0xFF8B3A24), Color(0xFFFF6040), 1300),
    (0.90, 0.05, 20.0, Color(0xFF6B4A1C), Color(0xFFFFAA30), 500),
  ];

  @override
  Widget build(BuildContext context) {
    if (!isNight) return const SizedBox.shrink();
    return Stack(
      children: _lanterns.map((l) {
        return Positioned(
          top: -l.$3 * 0.3,
          left: l.$1 * 1.sw - l.$3 / 2,
          child: LanternWidget(
            color: l.$4,
            glowColor: l.$5,
            size: l.$3.r,
            stringLength: l.$2,
            swayDuration: Duration(milliseconds: 3000 + l.$6 ~/ 5),
            swayDelay: Duration(milliseconds: l.$6),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _FrontLanternRow — صف الفوانيس الكبيرة في الأمام
// ════════════════════════════════════════════════════════════════
class _FrontLanternRow extends StatelessWidget {
  const _FrontLanternRow({required this.isNight});
  final bool isNight;

  // (x نسبة, حجم, لون, glow, تأخير ms)
  static const _lanterns = [
    (0.12, 40.0, Color(0xFF8B3A24), Color(0xFFFF7050), 0),
    (0.34, 34.0, Color(0xFF6B4A1C), Color(0xFFFFB040), 700),
    (0.55, 45.0, Color(0xFF8B3A24), Color(0xFFFF8060), 400),
    (0.74, 34.0, Color(0xFF6B4A1C), Color(0xFFFFAA30), 1100),
    (0.90, 38.0, Color(0xFF3A2A60), Color(0xFF8860FF), 200),
  ];

  @override
  Widget build(BuildContext context) {
    // في النهار فوانيس خضراء وألوان مختلفة
    final lanterns = isNight
        ? _lanterns
        : [
            (0.10, 36.0, const Color(0xFF2A6B1C), const Color(0xFF80E840), 0),
            (0.35, 30.0, const Color(0xFF1C3A6B), const Color(0xFF4090FF), 600),
            (0.60, 42.0, const Color(0xFF8B3A24), const Color(0xFFFF7050), 300),
            (0.80, 30.0, const Color(0xFF6B1C3A), const Color(0xFFFF50A0), 900),
          ];

    return Stack(
      children: lanterns.map((l) {
        return Positioned(
          top: -l.$2 * 0.2,
          left: l.$1 * 1.sw - l.$2 / 2,
          child: LanternWidget(
            color: l.$3,
            glowColor: l.$4,
            size: l.$2.r,
            stringLength: 0.30,
            swayDuration: Duration(milliseconds: 3400 + l.$5 ~/ 4),
            swayDelay: Duration(milliseconds: l.$5),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _BrandSection — الهوية البصرية (شمعة + اسم + tagline)
//  مطابق لـ HTML بالترتيب:
//    🕯️  → نور رمضان → NOUR RAMADAN → loading bar → جارٍ التحميل...
// ════════════════════════════════════════════════════════════════
class _BrandSection extends StatelessWidget {
  const _BrandSection({
    required this.fadeAnim,
    required this.slideAnim,
    required this.isNight,
  });

  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final bool isNight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fadeAnim,
      builder: (context, child) {
        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(position: slideAnim, child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 🏮 فانوس رمضاني متأرجح ─────────────────────────
          const RamadanLanternWidget(size: 80),
          SizedBox(height: 12.h),

          // ── نور رمضان — مطابق لـ .splash-title ──────────────
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFFFFD97D), // --gold-g
                Color(0xFFC8922A), // --gold
              ],
            ).createShader(bounds),
            child: Text(
              AppStrings.appName, // 'نور رمضان'
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 34.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white, // ShaderMask يطبق التدرج
                shadows: [
                  Shadow(
                    color: const Color(0xFFC8922A).withValues(alpha: 0.28),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 6.h),

          // ── NOUR RAMADAN — مطابق لـ .splash-sub ──────────────
          Text(
            AppStrings.appNameLatin, // 'NOUR RAMADAN'
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 9.sp,
              color: AppColors.textDim,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _CrescentMoon — هلال ذهبي مرسوم بـ CustomPaint
// ════════════════════════════════════════════════════════════════
class _CrescentMoon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70.r,
      height: 70.r,
      child: CustomPaint(painter: _CrescentPainter()),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // هالة خارجية
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.goldGlow.withValues(alpha: 0.30),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, haloPaint);

    // تدرج الهلال
    final moonPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: const [
          Color(0xFFFFF8DC),
          AppColors.goldLight,
          AppColors.goldWarm,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.7));

    // دائرة الهلال الرئيسية
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.65));

    // اقتطاع الجزء الداخلي ليصبح هلالاً
    final cutPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(cx + r * 0.22, cy - r * 0.05),
          radius: r * 0.51,
        ),
      );

    final crescent = Path.combine(PathOperation.difference, path, cutPath);
    canvas.drawPath(crescent, moonPaint);

    // نجمة صغيرة بجانب الهلال
    _drawStar(canvas, Offset(cx + r * 0.72, cy - r * 0.62), r * 0.08);
  }

  void _drawStar(Canvas canvas, Offset center, double r) {
    final paint = Paint()
      ..color = AppColors.goldLight
      ..style = PaintingStyle.fill;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 4 * math.pi / 5) - math.pi / 2;
      final innerAngle = outerAngle + 2 * math.pi / 10;
      final outerX = center.dx + r * math.cos(outerAngle);
      final outerY = center.dy + r * math.sin(outerAngle);
      final innerX = center.dx + r * 0.4 * math.cos(innerAngle);
      final innerY = center.dy + r * 0.4 * math.sin(innerAngle);
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════════
//  _ProgressSection — شريط التحميل الذهبي
//  مطابق لـ .loading-bar + .loading-bar-fill (CSS)
// ════════════════════════════════════════════════════════════════
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.progressAnim});
  final Animation<double> progressAnim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 50.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── شريط التقدم ─────────────────────────────────────
          AnimatedBuilder(
            animation: progressAnim,
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // نسبة التقدم
                  Text(
                    '${(progressAnim.value * 100).toInt()}%',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10.sp,
                      color: AppColors.goldWarm.withValues(alpha: 0.65),
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // الشريط
                  Container(
                    height: 3.h,
                    decoration: BoxDecoration(
                      color: AppColors.goldWarm.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FractionallySizedBox(
                        widthFactor: progressAnim.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.goldWarm,
                                AppColors.goldLight,
                                AppColors.goldGlow,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowGold,
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  // نص التحميل
                  Text(
                    AppStrings.loading,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10.sp,
                      color: AppColors.textDim.withValues(alpha: 0.55),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
