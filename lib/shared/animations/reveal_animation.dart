import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// حركة ظهور تدريجي + انزلاق للأعلى
/// مناسبة لظهور الشاشات والعناصر
class RevealAnimation extends StatelessWidget {
  const RevealAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
    this.slideFrom = RevealSlide.bottom,
    this.distance = 20.0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final RevealSlide slideFrom;
  final double distance;

  @override
  Widget build(BuildContext context) {
    Offset begin;
    switch (slideFrom) {
      case RevealSlide.bottom:
        begin = Offset(0, distance);
        break;
      case RevealSlide.top:
        begin = Offset(0, -distance);
        break;
      case RevealSlide.left:
        begin = Offset(-distance, 0);
        break;
      case RevealSlide.right:
        begin = Offset(distance, 0);
        break;
      case RevealSlide.none:
        begin = Offset.zero;
        break;
    }

    return child
        .animate(delay: delay)
        .fade(duration: duration, curve: Curves.easeOut)
        .move(
          begin: begin,
          end: Offset.zero,
          duration: duration,
          curve: Curves.easeOut,
        );
  }
}

enum RevealSlide { bottom, top, left, right, none }

/// حركة نبض / ضربة قلب خفيفة — للعناصر التفاعلية
class PulseAnimation extends StatefulWidget {
  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
    this.minScale = 0.96,
    this.maxScale = 1.0,
  });

  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _scaleAnim = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
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
      animation: _scaleAnim,
      builder: (_, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// حركة تلألأ النجوم — مطابقة لـ @keyframes tw في HTML
class StarTwinkle extends StatefulWidget {
  const StarTwinkle({
    super.key,
    required this.child,
    this.duration,
    this.delay = Duration.zero,
    this.minOpacity = 0.15,
    this.maxOpacity = 0.9,
  });

  final Widget child;
  final Duration? duration;
  final Duration delay;
  final double minOpacity;
  final double maxOpacity;

  @override
  State<StarTwinkle> createState() => _StarTwinkleState();
}

class _StarTwinkleState extends State<StarTwinkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration ?? const Duration(milliseconds: 3000),
    );
    _opacityAnim = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (_, child) => Opacity(
        opacity: _opacityAnim.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}
