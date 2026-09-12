import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/location_service.dart';
import '../../../painting/cairo_street_painter.dart';
import '../../../painting/lantern_painter.dart';
import '../../../shared/animations/reveal_animation.dart';
import '../../quran/screens/quran_home_screen.dart';
import '../../dua/screens/athkar_screen.dart';
import '../../dua/screens/dua_home_screen.dart';
import '../../qibla/screens/qibla_screen.dart';
import '../../prayer/screens/prayer_times_screen.dart';
import '../../tasbih/screens/tasbih_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../progress/screens/progress_screen.dart';
import '../../hadith/screens/hadith_home_screen.dart';
import '../../messages/screens/messages_screen.dart';
import '../../messages/providers/messages_provider.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/location_update_hint.dart';
import '../providers/prayer_times_provider.dart';
import '../providers/verse_of_day_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/date_provider.dart';
import '../widgets/prayer_countdown_widget.dart';
import '../widgets/verse_of_day_widget.dart';
import '../widgets/quick_actions_grid.dart'; // QuickAction enum
import '../widgets/progress_summary_widget.dart';

// ════════════════════════════════════════════════════════════════
//  HomeScreen — شاشة الرئيسية
//  مطابق لـ HTML: .home-screen
//  التسلسل: خلفية القاهرة → فوانيس → AppBar → محتوى قابل للتمرير
//  NavBar ثابت في الأسفل (5 عناصر)
// ════════════════════════════════════════════════════════════════

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late ScrollController _scrollController;
  bool _showAppBar = true;
  bool _detectingLocation = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // ✅ لا حاجة لفحص الأذونات هنا
    // النظام يجدول تلقائياً في main.dart عند resumed
  }

  void _onScroll() {
    final currentScroll = _scrollController.offset;
    // الاختفاء يبدأ عند 50.h (أسرع لتجنب التداخل)
    final shouldShow = currentScroll < 50.h;

    if (shouldShow != _showAppBar) {
      setState(() => _showAppBar = shouldShow);
    }
  }

  // ── تحديد الموقع تلقائياً بـ GPS (نفس وظيفة زر "تحديد موقعي" في LocationPickerScreen) ──
  Future<void> _detectLocation() async {
    if (_detectingLocation) return;
    setState(() => _detectingLocation = true);

    try {
      // 1. فحص تفعيل GPS
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _detectingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'يرجى تفعيل GPS من الإعدادات',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'الإعدادات',
                textColor: Colors.white,
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      // 2. فحص الصلاحيات
      var status = await Permission.locationWhenInUse.status;

      if (status.isPermanentlyDenied) {
        setState(() => _detectingLocation = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1A1035),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800)),
                  SizedBox(width: 8),
                  Text(
                    'الوصول محظور',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              content: const Text(
                'يمكنك السماح بالوصول للموقع من إعدادات التطبيق.',
                style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text(
                    'الإعدادات',
                    style: TextStyle(color: Color(0xFFD4A843)),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (status.isDenied) {
        status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          setState(() => _detectingLocation = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'تم رفض صلاحية الموقع',
                  style: TextStyle(fontFamily: 'Tajawal'),
                ),
                backgroundColor: const Color(0xFFD32F2F),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          return;
        }
      }

      // 3. جلب الإحداثيات بدقة عالية
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 4. تحويل الإحداثيات إلى اسم مدينة
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // ━━━ LOG: بيانات geocoding الخام ━━━
        debugPrint(
          '📍 [HOME_LOC] GPS: ${position.latitude}, ${position.longitude}',
        );
        debugPrint(
          '📍 [HOME_LOC] place.locality          = "${place.locality}"',
        );
        debugPrint(
          '📍 [HOME_LOC] place.administrativeArea = "${place.administrativeArea}"',
        );
        debugPrint(
          '📍 [HOME_LOC] place.subAdminArea       = "${place.subAdministrativeArea}"',
        );
        debugPrint(
          '📍 [HOME_LOC] place.country            = "${place.country}"',
        );

final cityName =
    [
      place.locality,
      place.subAdministrativeArea,  // ← subAdmin قبل administrativeArea
      place.administrativeArea,
    ]
        .map((s) => s?.trim() ?? '')   // ← trim أولاً
        .firstWhere(
          (s) => s.isNotEmpty,         // ← بعدين نتحقق من isEmpty
          orElse: () => 'موقع غير معروف',
        );

        debugPrint(
          '📍 [HOME_LOC] cityName المختار = "$cityName" (isEmpty=${cityName.isEmpty})',
        );

        // حفظ الموقع
        await LocationService.instance.setManualLocation(
          lat: position.latitude,
          lng: position.longitude,
          city: cityName,
        );

        // ━━━ LOG: حالة LocationService بعد الحفظ ━━━
        debugPrint('📍 [HOME_LOC] بعد setManualLocation:');
        debugPrint(
          '   → LocationService.city = "${LocationService.instance.city}"',
        );
        debugPrint(
          '   → LocationService.lat  = ${LocationService.instance.lat}',
        );

        // تحديث الـ Provider
        if (mounted) {
          ref.read(prayerTimesProvider.notifier).refreshAfterCityChange();

          // ━━━ LOG: قيمة الـ Provider بعد refresh ━━━
          final providerCity = ref.read(prayerTimesProvider).city;
          debugPrint(
            '📍 [HOME_LOC] prayerTimesProvider.city بعد refresh = "$providerCity"',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'تم تحديد موقعك: $cityName',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('❌ [HOME_LOC] placemarks فارغ — geocoding لم يُرجع نتائج');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'تعذر تحديد اسم المدينة',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذر تحديد موقعك، حاول مجدداً',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final messagesState = ref.watch(messagesProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 1. خلفية مباني القاهرة ────────────────────────────
          Positioned.fill(
            child: RepaintBoundary(child: CairoStreetBackground(isNight: true)),
          ),

          // ── 2. فوانيس ─────────────────────────────────────────
          RepaintBoundary(child: const _HomeLanterns()),

          // ── 3. تدرج فوق الخلفية لإبراز المحتوى ───────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    AppColors.nightDeep.withValues(alpha: 0.70),
                    AppColors.nightDeep.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),

          // ── 4. المحتوى الرئيسي (قبل AppBar في Stack) ──────────
          // ✅ الإصلاح: تم نقل المحتوى قبل AppBar حتى لا يحجب اللمسات
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ─ مساحة تحت الفوانيس والـ AppBar ────────────────
                SliverToBoxAdapter(child: SizedBox(height: 100.h)),

                // ─ تلميح تحديث الموقع (بسيط وأنيق) ────────────────
                SliverToBoxAdapter(
                  child: LocationUpdateHint(onUpdateLocation: _detectLocation),
                ),

                // ✅ تم حذف LoadingIndicator — البيانات تعرض فوراً من الكاش أو الافتراضي
                // ✅ Firebase يحدث البيانات في الخلفية تلقائياً عبر snapshots()

                // ─ آية اليوم ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: RevealAnimation(
                    delay: const Duration(milliseconds: 100),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final title = ref.watch(
                          verseOfDayProvider.select((s) => s.verseTitle),
                        );
                        final verse = ref.watch(
                          verseOfDayProvider.select((s) => s.verseOfDay),
                        );
                        final reference = ref.watch(
                          verseOfDayProvider.select((s) => s.verseReference),
                        );

                        return VerseOfDayWidget(
                          title: title.isNotEmpty ? title : 'آية اليوم',
                          verse: verse.isNotEmpty
                              ? verse
                              : 'شَهْرُ رَمَضَانَ الَّذِي أُنزِلَ فِيهِ الْقُرْآنُ هُدًى لِّلنَّاسِ',
                          reference: reference.isNotEmpty
                              ? reference
                              : 'البقرة: ١٨٥',
                        );
                      },
                    ),
                  ),
                ),

                // ─ زخرفة ─────────────────────────────────────────
                const SliverToBoxAdapter(child: _OrnamentDivider()),

                // ─ بطاقة الصلاة ───────────────────────────────────
                SliverToBoxAdapter(
                  child: RevealAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final prayerName = ref.watch(
                          prayerTimesProvider.select((s) => s.prayerName),
                        );
                        final timeLeft = ref.watch(
                          prayerTimesProvider.select((s) => s.prayerTimeLeft),
                        );
                        final progress = ref.watch(
                          prayerTimesProvider.select((s) => s.prayerProgress),
                        );
                        final hijriDate = ref.watch(
                          dateProvider.select((s) => s.hijriDate),
                        );
                        final gregorianDate = ref.watch(
                          dateProvider.select((s) => s.gregorianDate),
                        );

                        return PrayerCountdownWidget(
                          prayerName: prayerName.isNotEmpty
                              ? prayerName
                              : 'الفجر',
                          timeLeft: timeLeft.isNotEmpty ? timeLeft : '00:00:00',
                          progress: progress,
                          hijriDate: hijriDate.isNotEmpty
                              ? hijriDate
                              : '1 رمضان 1445',
                          gregorianDate: gregorianDate.isNotEmpty
                              ? gregorianDate
                              : 'الجمعة، 1 مارس 2024',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PrayerTimesScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                // ─ زخرفة ─────────────────────────────────────────
                const SliverToBoxAdapter(child: _OrnamentDivider()),

                // ─ الخدمات السريعة (8 بطاقات) ────────────────────
                SliverToBoxAdapter(
                  child: RevealAnimation(
                    delay: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Consumer(
                        builder: (context, ref, child) {
                          return _QuickActionsGrid(
                            onTap: (action) =>
                                _onQuickAction(context, ref, action),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // ─ زخرفة ─────────────────────────────────────────
                const SliverToBoxAdapter(child: _OrnamentDivider()),

                // ─ صورة الصلاة على النبي ─────────────────────────
                SliverToBoxAdapter(
                  child: RevealAnimation(
                    delay: const Duration(milliseconds: 350),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 12.h,
                      ),
                      child: _SalahImageCard(),
                    ),
                  ),
                ),

                // ─ زخرفة ─────────────────────────────────────────
                const SliverToBoxAdapter(child: _OrnamentDivider()),

                // ─ ملخص التقدم ────────────────────────────────────
                SliverToBoxAdapter(
                  child: RevealAnimation(
                    delay: const Duration(milliseconds: 400),
                    child: Consumer(
                      builder: (context, ref, child) {
                        // From dateProvider (4 fields)
                        final completedDays = ref.watch(
                          dateProvider.select((s) => s.completedDays),
                        );
                        final totalDays = ref.watch(
                          dateProvider.select((s) => s.totalDays),
                        );
                        final hijriMonth = ref.watch(
                          dateProvider.select((s) => s.hijriMonth),
                        );
                        final hijriYear = ref.watch(
                          dateProvider.select((s) => s.hijriYear),
                        );

                        // From progressProvider (3 fields)
                        final readSurahs = ref.watch(
                          progressProvider.select((s) => s.readSurahs),
                        );
                        final duasRead = ref.watch(
                          progressProvider.select((s) => s.duasRead),
                        );
                        final tasbihCount = ref.watch(
                          progressProvider.select((s) => s.tasbihCount),
                        );

                        return ProgressSummaryWidget(
                          completedDays: completedDays,
                          totalDays: totalDays,
                          readSurahs: readSurahs,
                          duasRead: duasRead,
                          tasbihCount: tasbihCount,
                          hijriMonth: hijriMonth,
                          hijriYear: hijriYear,
                        );
                      },
                    ),
                  ),
                ),

                // ─ مساحة النافي بار ───────────────────────────────
                SliverToBoxAdapter(child: SizedBox(height: 160.h)),
              ],
            ),
          ),

          // ── 5. الـ AppBar (آخر عنصر في Stack = فوق الكل) ──────
          // ✅ الإصلاح: AppBar الآن فوق CustomScrollView فيستقبل اللمسات أولاً
          AnimatedPositioned(
            top: _showAppBar ? 0 : -140.h,
            left: 0,
            right: 0,
            duration: const Duration(milliseconds: 150), // أسرع لتجنب التداخل
            curve: Curves.easeInOut, // منحنى سلس
            child: IgnorePointer(
              ignoring: !_showAppBar, // تجاهل اللمس عندما يكون مخفي
              child: SafeArea(
                bottom: false,
                child: Consumer(
                  builder: (context, ref, child) {
                    final city = ref.watch(
                      prayerTimesProvider.select((s) => s.city),
                    );

                    return _HomeAppBarContent(
                      city: city,
                      unreadCount: messagesState.unreadCount,
                      isDetectingLocation: _detectingLocation,
                      onLocationTap: () => _detectLocation(),
                      onNotificationTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MessagesScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      // ── شريط التنقل ───────────────────────────────────────────
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }
}

// ── معالج ضغطة الخدمة السريعة ──────────────────────────────────
void _onQuickAction(BuildContext context, WidgetRef ref, QuickAction action) {
  switch (action) {
    case QuickAction.quran:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const QuranHomeScreen()));
    case QuickAction.athkar:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AthkarScreen()));
    case QuickAction.dua:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DuaHomeScreen()));
    case QuickAction.qibla:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const QiblaScreen()));
    case QuickAction.tasbih:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TasbihScreen()));
    case QuickAction.library:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const HadithHomeScreen()));
    case QuickAction.prayer:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
    case QuickAction.progress:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ProgressScreen()));
    case QuickAction.laylat:
      // Not used in home screen anymore (moved to Dua screen)
      break;
  }
}

// ════════════════════════════════════════════════════════════════
//  _HomeAppBarContent — محتوى AppBar كـ Widget عادي
//  يُستخدم داخل SliverAppBar.flexibleSpace
// ════════════════════════════════════════════════════════════════
class _HomeAppBarContent extends StatelessWidget {
  const _HomeAppBarContent({
    required this.city,
    required this.unreadCount,
    required this.onLocationTap,
    required this.onNotificationTap,
    this.isDetectingLocation = false,
  });
  final String city;
  final int unreadCount;
  final VoidCallback onLocationTap;
  final VoidCallback onNotificationTap;
  final bool isDetectingLocation;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.transparent, // شفاف تماماً لإظهار المصابيح
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: topPadding + 40.h,
        bottom: 12.h,
      ),
      child: Row(
        children: [
          // ── اسم التطبيق ──────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.appName,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldLight,
                  shadows: [
                    Shadow(
                      color: AppColors.goldGlow.withValues(alpha: 0.50),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4.h),
              // ── اسم المدينة فقط (بدون زر) ──────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: const Color(0xFF34A862),
                    size: 11.sp,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    city,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.sp,
                      color: AppColors.goldLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // ── زر الإعدادات ─────────────────────────────────
          GestureDetector(
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            child: Container(
              width: 40.r,
              height: 40.r,
              margin: EdgeInsets.only(left: 8.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldWarm.withValues(alpha: 0.10),
                border: Border.all(color: AppColors.borderGold, width: 1.0),
              ),
              child: Center(
                child: Icon(
                  Icons.settings,
                  color: AppColors.goldWarm,
                  size: 20.sp,
                ),
              ),
            ),
          ),
          // ── زر الموقع (دائرة مثل الإشعارات) ─────────────
          GestureDetector(
            onTap: isDetectingLocation ? null : onLocationTap,
            child: Container(
              width: 40.r,
              height: 40.r,
              margin: EdgeInsets.only(left: 8.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldWarm.withValues(alpha: 0.10),
                border: Border.all(color: AppColors.borderGold, width: 1.0),
              ),
              child: Center(
                child: isDetectingLocation
                    ? SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF34A862),
                        ),
                      )
                    : Icon(
                        Icons.my_location,
                        color: const Color(0xFF34A862),
                        size: 20.sp,
                      ),
              ),
            ),
          ),
          // ── زر الإشعارات ─────────────────────────────────
          GestureDetector(
            onTap: onNotificationTap,
            child: Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldWarm.withValues(alpha: 0.10),
                border: Border.all(color: AppColors.borderGold, width: 1.0),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text('🔔', style: TextStyle(fontSize: 16.sp)),
                  ),
                  // نقطة حمراء بسيطة للإشارة لوجود رسائل جديدة
                  if (unreadCount > 0)
                    Positioned(
                      top: 6.h,
                      right: 6.w,
                      child: Container(
                        width: 8.r,
                        height: 8.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          border: Border.all(
                            color: AppColors.nightDeep,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _HomeLanterns — صف الفوانيس على الشاشة الرئيسية
// ════════════════════════════════════════════════════════════════
class _HomeLanterns extends StatelessWidget {
  const _HomeLanterns();

  static const _data = [
    // (x نسبة, حجم, لون, glow)
    (0.05, 42.0, Color(0xFF8B3A24), Color(0xFFFF7050)),
    (0.28, 33.0, Color(0xFF6B4A1C), Color(0xFFFFB040)),
    (0.52, 48.0, Color(0xFF8B3A24), Color(0xFFFF8060)),
    (0.74, 33.0, Color(0xFF3A2A60), Color(0xFF8860FF)),
    (0.93, 38.0, Color(0xFF6B4A1C), Color(0xFFFFAA30)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _data.map((l) {
        return Positioned(
          top: -l.$2 * 0.20,
          left: l.$1 * 1.sw - l.$2 / 2,
          child: LanternWidget(
            color: l.$3,
            glowColor: l.$4,
            size: l.$2.r,
            stringLength: 0.38,
            swayDuration: const Duration(milliseconds: 3600),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _OrnamentDivider — زخرفة إسلامية بين البطاقات
//  مطابق لـ HTML: .ornament + .geo-border-sm
// ════════════════════════════════════════════════════════════════
class _OrnamentDivider extends StatelessWidget {
  const _OrnamentDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── ❋ ✦ ❋ ──
          Text(
            '❋  ✦  ❋',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.goldWarm.withValues(alpha: 0.45),
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          // ── خط ──❖──────────────❖── ──
          Row(
            children: [
              // ❖ يسار
              Text(
                '❖',
                style: TextStyle(
                  fontSize: 8.sp,
                  color: AppColors.goldWarm.withValues(alpha: 0.50),
                ),
              ),
              SizedBox(width: 4.w),
              // خط متقطع
              Expanded(
                child: CustomPaint(
                  size: Size(double.infinity, 2.h),
                  painter: _DashedLinePainter(),
                ),
              ),
              SizedBox(width: 4.w),
              // ❖ يمين
              Text(
                '❖',
                style: TextStyle(
                  fontSize: 8.sp,
                  color: AppColors.goldWarm.withValues(alpha: 0.50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC8922A).withValues(alpha: 0.30)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double x = 0;
    final y = size.height / 2;

    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ════════════════════════════════════════════════════════════════
//  _QuickActionsGrid — شبكة الخدمات السريعة (8 بطاقات)
//  مطابق لـ HTML: .features-grid (2 عمود × 4 صفوف)
//  القرآن، الأدعية، أوقات الصلاة، القبلة،
//  التسبيح، ليلة القدر، الأذكار، تقدمي
// ════════════════════════════════════════════════════════════════
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.onTap});
  final void Function(QuickAction) onTap;

  // (icon, nameAr, desc, action)
  static const _items = [
    ('📖', 'القرآن الكريم', 'تصفح كامل المصحف', QuickAction.quran),
    ('🤲', 'الأدعية', 'مئات الأدعية', QuickAction.dua),
    ('🕌', 'أوقات الصلاة', 'تذكير تلقائي', QuickAction.prayer),
    ('🧭', 'القبلة', 'بدقة عالية', QuickAction.qibla),
    ('📿', 'التسبيح', 'سبحة تفاعلية', QuickAction.tasbih),
    ('📚', 'المكتبة', 'الأحاديث النبوية', QuickAction.library),
    ('🌿', 'الأذكار', 'صباحاً ومساءً', QuickAction.athkar),
    ('⭐', 'تقدمي', 'تابع مستواك', QuickAction.progress),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── تسمية القسم ──────────────────────────────────
          Padding(
            padding: EdgeInsets.only(bottom: 10.h, right: 4.w),
            child: Row(
              children: [
                Container(width: 14.w, height: 1, color: AppColors.goldWarm),
                SizedBox(width: 6.w),
                Text(
                  'استكشف',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.sp,
                    letterSpacing: 2,
                    color: AppColors.goldWarm,
                  ),
                ),
              ],
            ),
          ),
          // ── شبكة 2 عمود ──────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (_, i) {
              final item = _items[i];
              return _FeatureCard(
                icon: item.$1,
                name: item.$2,
                desc: item.$3,
                onTap: () => onTap(item.$4),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.name,
    required this.desc,
    required this.onTap,
  });
  final String icon;
  final String name;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xF0221A40), // nightCard مع شفافية عالية
            Color(0xF8160F28),
          ],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.goldWarm.withValues(alpha: 0.18),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          splashColor: AppColors.goldWarm.withValues(alpha: 0.3),
          highlightColor: AppColors.goldLight.withValues(alpha: 0.1),
          child: Stack(
            children: [
              // ── هالة ذهبية خفية في الزاوية ──────────────
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 70.r,
                  height: 70.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.goldWarm.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // ── المحتوى ──────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(icon, style: TextStyle(fontSize: 22.sp)),
                    SizedBox(height: 6.h),
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 11.sp,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      desc,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9.sp,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
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
//  _SalahImageCard — بطاقة الصلاة على النبي مع animation تفاعلي
// ════════════════════════════════════════════════════════════════
class _SalahImageCard extends StatefulWidget {
  const _SalahImageCard();

  @override
  State<_SalahImageCard> createState() => _SalahImageCardState();
}

class _SalahImageCardState extends State<_SalahImageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // ✅ Animation: دوران خفيف يمين ويسار (tilt effect)
    _tiltAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.03,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.03,
          end: -0.03,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.03,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playAnimation() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _playAnimation,
      child: AnimatedBuilder(
        animation: _tiltAnimation,
        builder: (context, child) {
          return Transform.rotate(angle: _tiltAnimation.value, child: child);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.goldWarm.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldGlow.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/sla_allah_ala_mohamed.jpg',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
