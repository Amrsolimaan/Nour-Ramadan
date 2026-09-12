import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nour_ramadan/painting/lantern_painter.dart';
import '../../core/theme/app_colors.dart';
import '../../painting/cairo_street_painter.dart';

// ════════════════════════════════════════════════════════════════
//  NotificationPermissionScreen — صفحة طلب أذونات الإشعارات
//  تظهر بعد LoadingScreen مباشرة (مرة واحدة فقط)
//  التصميم متناسق مع LoadingScreen
// ════════════════════════════════════════════════════════════════

class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({
    super.key,
    required this.onAllow,
    required this.onSkip,
  });

  final VoidCallback onAllow;
  final VoidCallback onSkip;

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: Stack(
        children: [
          // ── 1. خلفية مباني القاهرة ────────────────────────
          const Positioned.fill(child: CairoStreetBackground(isNight: true)),

          // ── 2. فوانيس خلفية ─────────────────────────────────
          _buildBackLanterns(),

          // ── 3. ظلام تدريجي ──────────────────────────────────
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

          // ── 4. المحتوى الرئيسي ──────────────────────────────
          Positioned.fill(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // ── أيقونة الجرس ──────────────────────────
                    _buildBellIcon(),
                    SizedBox(height: 24.h),

                    // ── العنوان ────────────────────────────────
                    Text(
                      'تفعيل الإشعارات',
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

                    // ── النص التوضيحي ──────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.w),
                      child: Text(
                        'للحصول على تجربة كاملة، نحتاج إلى إذنك لإرسال الإشعارات',
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

                    // ── قائمة الفوائد ───────────────────────────
                    _buildBenefitsList(),

                    const Spacer(flex: 3),

                    // ── الأزرار ────────────────────────────────
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

  // ══════════════════════════════════════════════════════════════
  //  UI Components
  // ══════════════════════════════════════════════════════════════

  Widget _buildBackLanterns() {
    const lanterns = [
      (0.15, 30.0, Color(0xFF8B3A24), Color(0xFFFF6040), 0),
      (0.40, 24.0, Color(0xFF6B4A1C), Color(0xFFFFAA30), 500),
      (0.65, 28.0, Color(0xFF3A6B2A), Color(0xFF60E840), 300),
      (0.85, 26.0, Color(0xFF8B3A24), Color(0xFFFF6040), 700),
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
            stringLength: 0.25,
            swayDuration: Duration(milliseconds: 3200 + l.$5),
            swayDelay: Duration(milliseconds: l.$5),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBellIcon() {
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
            Icons.notifications_active_rounded,
            size: 40.sp,
            color: AppColors.goldWarm,
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      ('', 'الأذان في مواعيد الصلاة'),
      ('', 'تذكير قبل الصلاة بـ 15 دقيقة'),
      ('', 'تنبيه السحور والإفطار'),
      ('', 'تذكيرات الأذكار والأدعية'),
    ];

    return Column(
      children: benefits.map((benefit) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 50.w, vertical: 8.h),
          child: Row(
            children: [
              Text(benefit.$1, style: TextStyle(fontSize: 24.sp)),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  benefit.$2,
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
        );
      }).toList(),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Column(
        children: [
          // ── زر السماح ──────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                debugPrint('🔔 Allow button tapped');
                widget.onAllow();
              },
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
                  child: Text(
                    'السماح بالإشعارات',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.nightDeep,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // ── زر التخطي ──────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                debugPrint('⏭️ Skip button tapped');
                widget.onSkip();
              },
              borderRadius: BorderRadius.circular(16.r),
              child: Ink(
                width: double.infinity,
                height: 54.h,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.textDim.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    'تخطي',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDim,
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
