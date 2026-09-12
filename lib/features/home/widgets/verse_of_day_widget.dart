import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/animations/reveal_animation.dart';
import '../../../shared/widgets/ornament_divider.dart';

// ════════════════════════════════════════════════════════════════
//  VerseOfDayWidget — بطاقة آية اليوم
//  مطابق لـ HTML: .verse-of-day-card
//  البيانات من Firestore: app_config/daily → verseOfDay + verseReference
// ════════════════════════════════════════════════════════════════

class VerseOfDayWidget extends StatefulWidget {
  const VerseOfDayWidget({
    super.key,
    required this.verse,
    required this.reference,
    this.title = 'آية اليوم', // ✅ إضافة title مع قيمة افتراضية
  });

  final String verse;
  final String reference;
  final String title; // ✅ العنوان من Firebase

  @override
  State<VerseOfDayWidget> createState() => _VerseOfDayWidgetState();
}

class _VerseOfDayWidgetState extends State<VerseOfDayWidget>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  AnimationController? _autoScrollController;
  Animation<double>? _autoScrollAnimation;
  Timer? _resumeTimer;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    // ننتظر حتى يتم بناء الـ widget ثم نفحص إذا كان النص طويل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartAutoScroll();
    });
  }

  @override
  void didUpdateWidget(VerseOfDayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ عند تحديث النص من Firebase، نفحص ونبدأ auto-scroll
    if (oldWidget.verse != widget.verse) {
      // ننتظر قليلاً حتى يتم إعادة بناء الـ UI
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _checkAndStartAutoScroll();
        }
      });
    }
  }

  void _checkAndStartAutoScroll() {
    // إيقاف الـ animation القديم إن وُجد
    _autoScrollController?.dispose();
    _autoScrollController = null;

    // فحص إذا كان هناك محتوى قابل للتمرير
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      debugPrint('🔍 Verse maxScrollExtent: $maxScroll');
      
      if (maxScroll > 10) {
        // ✅ ننتظر 12 ثانية قبل البدء
        debugPrint('⏳ Waiting 12 seconds before auto-scroll...');
        Future.delayed(const Duration(seconds: 12), () {
          if (mounted && !_isUserInteracting) {
            debugPrint('✅ Starting auto-scroll for verse');
            _startAutoScroll();
          }
        });
      } else {
        debugPrint('⏸️ No scroll needed, text is short');
      }
    } else {
      debugPrint('⚠️ ScrollController not ready yet');
    }
  }

  void _startAutoScroll() {
    if (_autoScrollController != null) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    // ✅ مدة متوسطة = حركة مريحة (20-35 ثانية)
    final duration = Duration(
      milliseconds: (maxScroll * 100).toInt().clamp(20000, 35000),
    );

    debugPrint('🎬 Auto-scroll duration: ${duration.inSeconds}s');

    _autoScrollController = AnimationController(
      vsync: this,
      duration: duration,
    );

    _autoScrollAnimation = Tween<double>(
      begin: 0.0,
      end: maxScroll,
    ).animate(CurvedAnimation(
      parent: _autoScrollController!,
      curve: Curves.linear,
    ))
      ..addListener(() {
        if (!_isUserInteracting && _scrollController.hasClients) {
          _scrollController.jumpTo(_autoScrollAnimation!.value);
        }
      })
      ..addStatusListener((status) {
        // عند الوصول للنهاية، نرجع للبداية ونعيد
        if (status == AnimationStatus.completed && !_isUserInteracting) {
          _autoScrollController?.reset();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isUserInteracting) {
              _autoScrollController?.forward();
            }
          });
        }
      });

    _autoScrollController!.forward();
  }

  void _stopAutoScroll() {
    _autoScrollController?.stop();
    _resumeTimer?.cancel();
  }

  void _onUserInteractionStart() {
    setState(() => _isUserInteracting = true);
    _stopAutoScroll();
    _resumeTimer?.cancel();
  }

  void _onUserInteractionEnd() {
    // ✅ ننتظر 12 ثانية ثم نستأنف
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() => _isUserInteracting = false);
        // نستأنف من الموقع الحالي
        if (_autoScrollController != null && _scrollController.hasClients) {
          final currentScroll = _scrollController.offset;
          final maxScroll = _scrollController.position.maxScrollExtent;
          final progress = currentScroll / maxScroll;
          _autoScrollController!.value = progress;
          _autoScrollController!.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _autoScrollController?.dispose();
    _resumeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RevealAnimation(
      delay: const Duration(milliseconds: 200),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        // ✅ حجم ثابت للبطاقة
        constraints: BoxConstraints(
          maxHeight: 280.h, // الحد الأقصى للارتفاع
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF241A38), Color(0xFF1A1228)],
          ),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.borderGold, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldWarm.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── عنوان ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10.r,
                    height: 10.r,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.goldWarm, AppColors.goldLight],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('', style: TextStyle(fontSize: 12.sp)),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    widget.title, // ✅ استخدام العنوان من Firebase
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    width: 10.r,
                    height: 10.r,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.goldLight, AppColors.goldWarm],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('', style: TextStyle(fontSize: 12.sp)),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 14.h),
              const GeoBorderDivider(),
              SizedBox(height: 14.h),

              // ✅ نص الآية مع auto-scroll ذكي (بدون scrollbar)
              Flexible(
                child: GestureDetector(
                  onPanDown: (_) => _onUserInteractionStart(),
                  onPanEnd: (_) => _onUserInteractionEnd(),
                  onPanCancel: () => _onUserInteractionEnd(),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      widget.verse.isNotEmpty
                          ? widget.verse
                          : 'شَهْرُ رَمَضَانَ الَّذِي أُنزِلَ فِيهِ الْقُرْآنُ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 18.sp,
                        height: 1.8,
                        color: AppColors.textPrimary,
                        shadows: [
                          Shadow(
                            color: AppColors.goldGlow.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 14.h),

              // ── المصدر ──────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.goldWarm, AppColors.goldDim],
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  widget.reference.isNotEmpty ? widget.reference : 'البقرة: ١٨٥',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
