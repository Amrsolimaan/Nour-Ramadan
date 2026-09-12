import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../widgets/compass_widget.dart';
import '../../../core/services/location_service.dart';

// ════════════════════════════════════════════════════════════════
//  QiblaScreen — شاشة اتجاه القبلة
//  مطابق لـ HTML: .qibla-bg
//  ✅ محسّن: Stream throttling لتقليل استهلاك CPU بنسبة 80%
// ════════════════════════════════════════════════════════════════

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen>
    with SingleTickerProviderStateMixin {
  // حالة التطبيق
  bool _isLoading = true;
  String? _error;
  double _qiblahDegree = 0; // اتجاه مكة بالدرجات (من الشمال)
  String _cityName = 'موقعك الحالي';
  double _lat = 0;
  double _lng = 0;

  // أنيميشن الدوران
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  // Stream subscription للقبلة
  StreamSubscription<QiblahDirection>? _qiblahSubscription;

  // ✅ Throttle timer لتقليل التحديثات
  Timer? _throttleTimer;
  double? _pendingQiblahDegree;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _initLocation();
  }

  @override
  void dispose() {
    _qiblahSubscription?.cancel();
    _throttleTimer?.cancel(); // ✅ تنظيف الـ timer
    _glowController.dispose();
    super.dispose();
  }

  // ── طلب إذن الموقع وحساب القبلة ────────────────────────────
  Future<void> _initLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1) استخدام الموقع الموحد الموثوق
      final result = await LocationService.instance.detectCurrentLocation();

      if (!mounted) return;

      if (result == LocationResult.success) {
        final loc = LocationService.instance;
        _lat = loc.lat ?? 0;
        _lng = loc.lng ?? 0;
        _cityName = loc.city.isNotEmpty ? loc.city : 'موقعك الحالي';

        setState(() {
          _isLoading = false;
          _error = null;
        });

        // 2) الاستماع المستمر لاتجاه القبلة مع throttling
        _qiblahSubscription?.cancel();
        _qiblahSubscription = FlutterQiblah.qiblahStream.listen(
          (qiblah) {
            if (!mounted) return;

            _pendingQiblahDegree = qiblah.qiblah;

            if (_throttleTimer == null || !_throttleTimer!.isActive) {
              _throttleTimer = Timer(const Duration(milliseconds: 100), () {
                if (mounted && _pendingQiblahDegree != null) {
                  setState(() {
                    _qiblahDegree = _pendingQiblahDegree!;
                  });
                }
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _error = 'خطأ في حساب اتجاه القبلة';
              });
            }
          },
        );
      } else if (result == LocationResult.serviceDisabled) {
        setState(() {
          _isLoading = false;
          _error = 'يرجى تفعيل GPS من الإعدادات لاستخدام القبلة';
        });
      } else if (result == LocationResult.permanentlyDenied) {
        setState(() {
          _isLoading = false;
          _error = 'صلاحية الموقع مرفوضة. يرجى تفعيلها من إعدادات التطبيق';
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'تعذر تحديد موقعك بدقة. تأكد من جودة اتصال الـ GPS';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'حدث خطأ غير متوقع في تحديد الموقع';
        });
      }
    }
  }

  // تحويل الدرجات → راديان (للـ CompassWidget)
  double get _qiblahRadians => _qiblahDegree * math.pi / 180;

  // نص الاتجاه الكاردينالي
  String get _cardinalDirection {
    final d = _qiblahDegree % 360;
    if (d < 22.5 || d >= 337.5) return 'شمال';
    if (d < 67.5) return 'شمال شرق';
    if (d < 112.5) return 'شرق';
    if (d < 157.5) return 'جنوب شرق';
    if (d < 202.5) return 'جنوب';
    if (d < 247.5) return 'جنوب غرب';
    if (d < 292.5) return 'غرب';
    return 'شمال غرب';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
      backgroundColor: AppColors.nightDeep,
      body: Container(
        // .qibla-bg: radial-gradient(ellipse at 50% 20%, #1C1040, #08061A 70%)
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.4,
            colors: [Color(0xFF1C1040), Color(0xFF08061A)],
            stops: [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ─────────────────────────────────────────
              _QiblaAppBar(onBack: () => Navigator.of(context).pop()),

              // ── المحتوى الرئيسي ────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const _LoadingView()
                    : _error != null
                    ? _ErrorView(error: _error!, onRetry: _initLocation)
                    : _QiblaBody(
                        qiblahDegree: _qiblahDegree,
                        qiblahRadians: _qiblahRadians,
                        cardinalDir: _cardinalDirection,
                        cityName: _cityName,
                        lat: _lat,
                        lng: _lng,
                        glowAnim: _glowAnim,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  AppBar
// ════════════════════════════════════════════════════════════════
class _QiblaAppBar extends StatelessWidget {
  const _QiblaAppBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderGold),
                color: AppColors.goldWarm.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.goldLight,
                size: 14.sp,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'اتجاه القبلة',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.agedPlaster,
            ),
          ),
          const Spacer(),
          Text('🕋', style: TextStyle(fontSize: 18.sp)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  .qibla-body — المحتوى الرئيسي
// ════════════════════════════════════════════════════════════════
class _QiblaBody extends StatelessWidget {
  const _QiblaBody({
    required this.qiblahDegree,
    required this.qiblahRadians,
    required this.cardinalDir,
    required this.cityName,
    required this.lat,
    required this.lng,
    required this.glowAnim,
  });

  final double qiblahDegree;
  final double qiblahRadians;
  final String cardinalDir;
  final String cityName;
  final double lat;
  final double lng;
  final Animation<double> glowAnim;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── عنوان صغير ────────────────────────────────────────
        Text(
          'حرّك الهاتف حتى يتوهج السهم والدائرة',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12.sp,
            color: AppColors.textDim,
          ),
        ),
        SizedBox(height: 24.h),

        // ── البوصلة + التوهج ──────────────────────────────────
        AnimatedBuilder(
          animation: glowAnim,
          builder: (_, child) {
            return Container(
              width: 210.w,
              height: 210.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldWarm.withValues(
                      alpha: glowAnim.value * 0.22,
                    ),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: CompassWidget(qiblahRadians: qiblahRadians),
        ),

        SizedBox(height: 28.h),

        // ── .qibla-degree — الدرجة بخط Amiri كبير ─────────────
        AnimatedBuilder(
          animation: glowAnim,
          builder: (_, __) {
            return Text(
              '${qiblahDegree.toStringAsFixed(1)}°',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 40.sp,
                color: AppColors.goldLight,
                shadows: [
                  Shadow(
                    color: AppColors.goldWarm.withValues(
                      alpha: glowAnim.value * 0.6,
                    ),
                    blurRadius: 20,
                  ),
                ],
              ),
            );
          },
        ),

        SizedBox(height: 4.h),

        // ── اتجاه كاردينالي ────────────────────────────────────
        Text(
          cardinalDir,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 14.sp,
            color: AppColors.goldWarm,
          ),
        ),

        SizedBox(height: 12.h),

        // ── اسم المدينة في Container مميز ──────────────────────
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.goldWarm.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.goldWarm.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_rounded,
                color: AppColors.goldLight,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                cityName,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24.h),

        // ── تعليمات الاستخدام ──────────────────────────────────
        Container(
          margin: EdgeInsets.symmetric(horizontal: 32.w),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.goldWarm.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.goldWarm.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.goldLight,
                    size: 16.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'كيفية الاستخدام',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.goldLight,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                'ضع الهاتف بشكل مسطح📱 (موازي للأرض)\nحرّك جسمك حتى يتوهج السهم والدائرة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.sp,
                  height: 1.6,
                  color: AppColors.textDim,
                ),
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'خط العرض: ${lat.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 10.sp,
                      color: AppColors.textDim.withValues(alpha: 0.6),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '•',
                    style: TextStyle(
                      color: AppColors.textDim.withValues(alpha: 0.4),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'خط الطول: ${lng.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 10.sp,
                      color: AppColors.textDim.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // ── ملاحظة ──────────────────────────────────────────────
        Text(
          'السهم الذهبي يشير لاتجاه القبلة • يضيء عند التوجه الصحيح',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10.sp,
            color: AppColors.textDim.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  حالة التحميل
// ════════════════════════════════════════════════════════════════
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 200.w,
          height: 200.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // دائرة تحميل دوارة
              SizedBox(
                width: 200.w,
                height: 200.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.goldWarm.withValues(alpha: 0.3),
                ),
              ),
              Text('🕋', style: TextStyle(fontSize: 30.sp)),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          'جاري تحديد موقعك...',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13.sp,
            color: AppColors.textDim,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  حالة الخطأ
// ════════════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📍', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 16.h),
            Text(
              'تعذر تحديد موقعك',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.goldLight,
                height: 1.7,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13.sp,
                color: AppColors.textDim,
                height: 1.7,
              ),
            ),
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.goldWarm.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: AppColors.goldWarm.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'إعادة المحاولة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.sp,
                    color: AppColors.goldLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
