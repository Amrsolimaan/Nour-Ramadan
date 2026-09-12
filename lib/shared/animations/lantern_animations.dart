import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// حركة تأرجح + وميض الفانوس
/// مطابق لـ @keyframes swayPage + @keyframes flickerPage في HTML
class LanternSwayAnimation extends StatefulWidget {
  const LanternSwayAnimation({
    super.key,
    required this.child,
    this.swayDuration,
    this.flickerDuration,
    this.swayDelay,
  });

  final Widget child;
  final Duration? swayDuration;
  final Duration? flickerDuration;
  final Duration? swayDelay;

  @override
  State<LanternSwayAnimation> createState() => _LanternSwayAnimationState();
}

class _LanternSwayAnimationState extends State<LanternSwayAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _swayCtrl;
  late final AnimationController _flickerCtrl;
  late final Animation<double> _swayAnim;
  late final Animation<double> _flickerAnim;

  @override
  void initState() {
    super.initState();

    // Sway: -4° → +4° (من HTML: rotate(-4deg) → rotate(4deg))
    _swayCtrl = AnimationController(
      vsync: this,
      duration: widget.swayDuration ?? const Duration(milliseconds: 3500),
    );
    _swayAnim = Tween<double>(
      begin: -0.07,
      end: 0.07,
    ).animate(CurvedAnimation(parent: _swayCtrl, curve: Curves.easeInOut));

    // Flicker: opacity 0.7 → 1.0
    _flickerCtrl = AnimationController(
      vsync: this,
      duration: widget.flickerDuration ?? const Duration(milliseconds: 2000),
    );
    _flickerAnim = Tween<double>(
      begin: 0.70,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _flickerCtrl, curve: Curves.easeInOut));

    // Start with optional delay
    Future.delayed(widget.swayDelay ?? Duration.zero, () {
      if (mounted) {
        _swayCtrl.repeat(reverse: true);
        _flickerCtrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _swayCtrl.dispose();
    _flickerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_swayCtrl, _flickerCtrl]),
      builder: (_, child) {
        return Transform.rotate(
          angle: _swayAnim.value,
          alignment: Alignment.topCenter,
          child: Opacity(opacity: _flickerAnim.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// فانوس كامل متأرجح — يُستخدم في Home + Splash
class SwayingLantern extends StatelessWidget {
  const SwayingLantern({
    super.key,
    required this.color,
    required this.glowColor,
    this.width = 14,
    this.height = 24,
    this.stringHeight = 15,
    this.swayDuration = const Duration(milliseconds: 3500),
    this.swayDelay = Duration.zero,
  });

  final Color color;
  final Color glowColor;
  final double width;
  final double height;
  final double stringHeight;
  final Duration swayDuration;
  final Duration swayDelay;

  @override
  Widget build(BuildContext context) {
    return LanternSwayAnimation(
      swayDuration: swayDuration,
      swayDelay: swayDelay,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── الخيط ──
          Container(
            width: 1,
            height: stringHeight.h,
            color: Colors.brown.withOpacity(0.60),
          ),
          // ── جسم الفانوس ──
          _LanternBody(
            color: color,
            glowColor: glowColor,
            width: width,
            height: height,
          ),
        ],
      ),
    );
  }
}

class _LanternBody extends StatefulWidget {
  const _LanternBody({
    required this.color,
    required this.glowColor,
    required this.width,
    required this.height,
  });
  final Color color;
  final Color glowColor;
  final double width;
  final double height;

  @override
  State<_LanternBody> createState() => _LanternBodyState();
}

class _LanternBodyState extends State<_LanternBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) {
        return Container(
          width: widget.width.w,
          height: widget.height.h,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.width.r * 0.4),
              topRight: Radius.circular(widget.width.r * 0.4),
              bottomLeft: Radius.circular(widget.width.r * 0.5),
              bottomRight: Radius.circular(widget.width.r * 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(0.80 * _glowAnim.value),
                blurRadius: 12 * _glowAnim.value,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: widget.glowColor.withOpacity(0.35 * _glowAnim.value),
                blurRadius: 25 * _glowAnim.value,
                spreadRadius: 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  CandleFlickerWidget — شمعة 🕯️ بوميض مضيء
//  مطابقة لـ .splash-candle + @keyframes cf في HTML:
//    filter: drop-shadow(0 0 10px rgba(255,150,0,0.6))  →
//    filter: drop-shadow(0 0 25px rgba(255,200,0,1.0))
//  مدة الوميض: 1s ease-in-out infinite alternate
// ════════════════════════════════════════════════════════════════
class CandleFlickerWidget extends StatefulWidget {
  const CandleFlickerWidget({super.key, this.size = 52});

  /// حجم الشمعة — مقابل font-size: 3.5rem في HTML
  final double size;

  @override
  State<CandleFlickerWidget> createState() => _CandleFlickerWidgetState();
}

class _CandleFlickerWidgetState extends State<CandleFlickerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // shadowBlur: 10px → 25px (مطابق لـ HTML بالضبط)
  late final Animation<double> _blurAnim;
  // shadowOpacity: 0.60 → 1.0
  late final Animation<double> _opacityAnim;
  // تكبير خفيف للشمعة نفسها مع الوميض: 1.0 → 1.06
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // 1000ms ease-in-out infinite alternate — مطابق لـ @keyframes cf
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _blurAnim = Tween<double>(
      begin: 10,
      end: 25,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacityAnim = Tween<double>(
      begin: 0.60,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Container(
            // drop-shadow مطابق لـ HTML بالضبط
            decoration: BoxDecoration(
              boxShadow: [
                // الهالة الداخلية الدافئة
                BoxShadow(
                  color: const Color(
                    0xFFFF9600,
                  ).withValues(alpha: _opacityAnim.value * 0.65),
                  blurRadius: _blurAnim.value,
                  spreadRadius: 0,
                ),
                // الهالة الخارجية الصفراء
                BoxShadow(
                  color: const Color(
                    0xFFFFC800,
                  ).withValues(alpha: _opacityAnim.value * 0.40),
                  blurRadius: _blurAnim.value * 1.8,
                  spreadRadius: 2,
                ),
              ],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '🕯️',
              style: TextStyle(
                fontSize: widget.size.sp,
                // drop-shadow عبر shadows بديل لـ filter في CSS
                shadows: [
                  Shadow(
                    color: const Color(
                      0xFFFF9600,
                    ).withValues(alpha: _opacityAnim.value),
                    blurRadius: _blurAnim.value,
                  ),
                  Shadow(
                    color: const Color(
                      0xFFFFC800,
                    ).withValues(alpha: _opacityAnim.value * 0.55),
                    blurRadius: _blurAnim.value * 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
