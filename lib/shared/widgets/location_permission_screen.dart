import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nour_ramadan/painting/lantern_painter.dart';
import '../../core/theme/app_colors.dart';
import '../../painting/cairo_street_painter.dart';
import '../../core/services/location_service.dart';

// ════════════════════════════════════════════════════════════════
//  LocationPermissionScreen
//  ✅ الإصلاح: إضافة زر "استخدام GPS" إلى جانب "اختيار يدوي"
//  الشاشة الآن تعطي 3 خيارات:
//    1) استخدام GPS (الموقع التلقائي)
//    2) اختيار مدينة يدوياً
//    3) تخطي
// ════════════════════════════════════════════════════════════════

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({
    super.key,
    required this.onGpsSelected,
    required this.onManualSelection,
    required this.onSkip,
  });

  /// ✅ جديد: تُستدعى عند نجاح GPS مع lat/lng
  final void Function(double lat, double lng, String city) onGpsSelected;
  final VoidCallback onManualSelection;
  final VoidCallback onSkip;

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── طلب GPS ────────────────────────────────────────────────────
  Future<void> _requestGps() async {
    debugPrint('🔵 [LocationPermissionScreen] بدء طلب GPS...');
    setState(() => _isLoadingGps = true);

    try {
      debugPrint('🔵 [LocationPermissionScreen] استدعاء detectCurrentLocation...');
      final result = await LocationService.instance.detectCurrentLocation();

      debugPrint('🔵 [LocationPermissionScreen] نتيجة GPS: $result');
      if (!mounted) {
        debugPrint('⚠️ [LocationPermissionScreen] Widget not mounted, returning');
        return;
      }

      switch (result) {
        case LocationResult.success:
          final lat = LocationService.instance.lat!;
          final lng = LocationService.instance.lng!;
          final city = LocationService.instance.city;
          debugPrint('✅ [LocationPermissionScreen] GPS success: $city ($lat, $lng)');
          debugPrint('🔵 [LocationPermissionScreen] استدعاء onGpsSelected...');
          widget.onGpsSelected(lat, lng, city);
          debugPrint('🔵 [LocationPermissionScreen] تم استدعاء onGpsSelected بنجاح');
          return;

        case LocationResult.denied:
          _showMessage(
            'لم يُسمح بالوصول للموقع.\nيمكنك اختيار المدينة يدوياً.',
          );
          break;

        case LocationResult.permanentlyDenied:
          _showMessageWithAction(
            'الوصول للموقع محظور.\nيرجى فتح إعدادات التطبيق وتفعيله يدوياً.',
            actionLabel: 'فتح الإعدادات',
            onAction: () async {
              await Geolocator.openAppSettings();
            },
          );
          break;

        case LocationResult.serviceDisabled:
          _showMessageWithAction(
            'خدمة GPS غير مفعّلة.\nيرجى تفعيل الموقع من إعدادات الجهاز.',
            actionLabel: 'فتح إعدادات GPS',
            onAction: () async {
              await Geolocator.openLocationSettings();
            },
          );
          break;

        case LocationResult.error:
          _showMessage(
            'حدث خطأ في تحديد الموقع.\nتأكد من تفعيل GPS وأذونات الموقع، ثم حاول مرة أخرى.',
          );
          break;
      }
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 15.sp,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: AppColors.nightDeep,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showMessageWithAction(
    String msg, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 15.sp,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: AppColors.nightDeep,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: actionLabel,
          textColor: AppColors.goldWarm,
          onPressed: onAction,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: CairoStreetBackground(isNight: true)),
          _buildBackLanterns(),

          // ظلام تدريجي
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

          // المحتوى
          Positioned.fill(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    _buildLocationIcon(),
                    SizedBox(height: 24.h),

                    Text(
                      'تحديد الموقع',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w600,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Color(0xFFFFD97D), Color(0xFFC8922A)],
                          ).createShader(Rect.fromLTWH(0, 0, 200.w, 70.h)),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.w),
                      child: Text(
                        'لحساب أوقات الصلاة بدقة، نحتاج إلى معرفة موقعك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15.sp,
                          color: AppColors.textDim,
                          height: 1.6,
                        ),
                      ),
                    ),

                    SizedBox(height: 32.h),
                    _buildBenefitsList(),
                    const Spacer(flex: 3),
                    _buildButtons(),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  UI Components
  // ════════════════════════════════════════════════════════════════

  Widget _buildBackLanterns() {
    const lanterns = [
      (0.15, 30.0, Color(0xFF8B3A24), Color(0xFFFF6040), 0),
      (0.40, 24.0, Color(0xFF6B4A1C), Color(0xFFFFAA30), 500),
      (0.65, 28.0, Color(0xFF3A6B2A), Color(0xFF60E840), 300),
      (0.85, 26.0, Color(0xFF8B3A24), Color(0xFFFF6040), 700),
    ];
    return Stack(
      children: lanterns
          .map(
            (l) => Positioned(
              top: -l.$2 * 0.2,
              left: l.$1 * 1.sw - l.$2 / 2,
              child: LanternWidget(
                color: l.$3,
                glowColor: l.$4,
                size: l.$2.r,
                stringLength: 0.25,
                swayDuration: Duration(milliseconds: 3200 + l.$5),
                swayDelay: Duration(milliseconds: l.$5),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildLocationIcon() {
    return Container(
      width: 100.r,
      height: 100.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.goldWarm.withValues(alpha: 0.15),
            AppColors.goldWarm.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 70.r,
          height: 70.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.goldWarm.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.goldWarm.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.location_on_rounded,
            size: 40.sp,
            color: AppColors.goldWarm,
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      ('-', 'حساب أوقات الصلاة بدقة'),
      ('-', 'الأذان في الوقت الصحيح'),
      ('-', 'تحديد اتجاه القبلة'),
    ];
    return Column(
      children: benefits
          .map(
            (b) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 50.w, vertical: 8.h),
              child: Row(
                children: [
                  Text(b.$1, style: TextStyle(fontSize: 24.sp)),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Text(
                      b.$2,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Column(
        children: [
          // ── زر GPS ───────────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoadingGps ? null : _requestGps,
              borderRadius: BorderRadius.circular(16.r),
              child: Ink(
                width: double.infinity,
                height: 54.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.goldWarm, AppColors.goldLight],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldWarm.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoadingGps
                      ? SizedBox(
                          width: 24.r,
                          height: 24.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.nightDeep,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              size: 20.sp,
                              color: AppColors.nightDeep,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'تحديد موقعي تلقائياً',
                              style: TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.nightDeep,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // ── زر التخطي ─────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                debugPrint('🔵 [LocationPermissionScreen] تم الضغط على زر تخطي');
                // ✅ الإصلاح: استدعاء onSkip فقط بدون navigation مباشر
                // onSkip في main.dart سيتولى الانتقال بشكل صحيح
                widget.onSkip();
                debugPrint('🔵 [LocationPermissionScreen] تم استدعاء widget.onSkip');
              },
              borderRadius: BorderRadius.circular(16.r),
              child: Ink(
                width: double.infinity,
                height: 48.h,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Center(
                  child: Text(
                    'تخطي ',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textDim.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
