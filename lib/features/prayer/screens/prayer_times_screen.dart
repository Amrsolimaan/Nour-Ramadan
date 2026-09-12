import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' as intl;
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/notification_permission_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/battery_prompt_service.dart';
import '../../../core/services/prayer_notification_manager.dart';
import '../providers/prayer_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PrayerTimesScreen extends ConsumerStatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  ConsumerState createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends ConsumerState
    with WidgetsBindingObserver {
  String _cityName = '...';
  bool _detectingLocation = false;

  // ── Timer لاكتشاف تغيير اليوم (منتصف الليل أو تغيير الوقت يدوياً) ──
  Timer? _dayChangeTimer;
  DateTime? _lastKnownDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocation();
    _startDayChangeWatcher();

    // ✅ المرحلة 4 (تسوية): أُزيل استدعاء AlarmPermissionService
    // .checkAndPromptIfNeeded() من هنا — كان يعرض حواراً لإعفاء البطارية
    // (بالتوازي الآن مع BatteryPromptService الجديدة أعلى هذا الملف عند
    // تفعيل الأذان)، فأصبح المستخدم يرى تنبيهين مختلفين لنفس الصلاحية.
    //
    // تنبيه إعفاء البطارية الآن مسؤولية BatteryPromptService وحدها،
    // مُحفَّزاً بتفعيل الأذان لا بفتح هذه الشاشة (راجع onNotifToggle أدناه).
    //
    // ⚠️ فحص/طلب إذن SCHEDULE_EXACT_ALARM (الجزء الآخر من checkAndPromptIfNeeded)
    // كان يظهر أيضاً من هنا ضمن الدالة نفسها — لكنه مُغطّى بالفعل ومستقلّاً
    // في main.dart (يُفحص ويُطلب عند كل إقلاع، بلا حوار توضيحي). لا فجوة
    // فعلية في تغطية هذا الإذن، لكن الحوار التوضيحي الودود اختفى معها.
    //
    // AlarmPermissionService.checkAndPromptIfNeeded() نفسها لم تُحذف —
    // فقط استدعاؤها من هنا. راجع plan_azan_reliability.md، تسوية المرحلة 4.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayChangeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // ✅ عند العودة للتطبيق، أعد حساب أوقات الصلاة لتحديث UI فوراً
    if (state == AppLifecycleState.resumed && mounted) {
      final loc = LocationService.instance;
      if (loc.hasLocation && loc.lat != null && loc.lng != null) {
        ref
            .read(prayerProvider.notifier)
            .calculatePrayers(loc.lat!, loc.lng!, DateTime.now());
      }
    }
  }

  // ── مراقب تغيير اليوم ────────────────────────────────────────────
  // يفحص كل دقيقة إذا تغيّر اليوم بسبب منتصف الليل أو تغيير الوقت يدوياً
  // عند اكتشاف يوم جديد → يُعيد حساب الصلوات تلقائياً ويُحدِّث الصفحة
  void _startDayChangeWatcher() {
    _lastKnownDate = DateTime.now();
    _dayChangeTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      final now = DateTime.now();
      final last = _lastKnownDate;

      if (last != null &&
          (now.day != last.day ||
           now.month != last.month ||
           now.year != last.year)) {
        debugPrint('🌅 PrayerTimesScreen: Day changed → recalculating prayers');
        _lastKnownDate = now;

        final loc = LocationService.instance;
        if (loc.lat != null && loc.lng != null) {
          await ref
              .read(prayerProvider.notifier)
              .calculatePrayers(loc.lat!, loc.lng!, now);

          // ✅ إعادة جدولة عند تغيير اليوم (منتصف الليل فقط)
          // main.dart يتعامل مع تغيير الوقت اليدوي عبر TimeChangeReceiver
          if (mounted) {
            await ref
                .read(prayerNotificationManagerProvider)
                .manualReschedule();
          }
        }
      } else {
        _lastKnownDate = now;
      }
    });
  }

  Future _loadLocation() async {
    final saved = LocationService.instance;

    // ✅ تحميل الموقع المحفوظ أولاً (ضروري عند الفتح لأول مرة)
    await saved.loadSaved();

    if (!mounted) return;

    if (saved.hasLocation) {
      setState(() {
        _cityName = saved.city.isNotEmpty ? saved.city : 'موقعك الحالي';
      });

      // ✅ إعادة حساب الصلوات إذا كان الموقع موجوداً
      if (saved.lat != null && saved.lng != null) {
        await ref
            .read(prayerProvider.notifier)
            .calculatePrayers(saved.lat!, saved.lng!, DateTime.now());
        
        // ⚠️ لا نعيد الجدولة هنا - PrayerNotificationManager يستمع تلقائياً لتغيرات prayerProvider
        // إعادة الجدولة هنا تسبب إلغاء الأذانات في وقت غير مناسب
      }
    }
    // إذا لم يكن هناك موقع → الـ provider سيُعيّن hasLocation: false تلقائياً
  }

  // ── تحديد الموقع تلقائياً ────────────────────────────────────────
  Future _detectLocation() async {
    if (_detectingLocation) return;
    setState(() => _detectingLocation = true);

    try {
      final result = await LocationService.instance.detectCurrentLocation();
      if (!mounted) return;

      if (result == LocationResult.success) {
        final city = LocationService.instance.city;
        setState(() {
          _cityName = city;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديد الموقع: $city'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );

        final loc = LocationService.instance;
        if (loc.lat != null && loc.lng != null) {
          // ① إعادة حساب أوقات الصلاة للموقع الجديد
          await ref
              .read(prayerProvider.notifier)
              .calculatePrayers(loc.lat!, loc.lng!, DateTime.now());

          // ✅ ② إعادة جدولة كل الأذانات والإشعارات للموقع الجديد فوراً
          // بدون هذا السطر تبقى الأذانات مجدولة للمدينة القديمة
          if (mounted) {
            await ref
                .read(prayerNotificationManagerProvider)
                .manualReschedule();
          }
        }
      } else if (result == LocationResult.serviceDisabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى تفعيل GPS من الإعدادات'),
            backgroundColor: const Color(0xFFD32F2F),
            action: SnackBarAction(
              label: 'الإعدادات',
              textColor: Colors.white,
              onPressed: () => Geolocator.openLocationSettings(),
            ),
          ),
        );
      } else if (result == LocationResult.permanentlyDenied) {
        _showPermanentlyDeniedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديد الموقع، حاول مجدداً'),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _detectingLocation = false);
      }
    }
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800)),
            SizedBox(width: 8),
            Text(
              'الوصول محظور',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: Color(0xFFE8D5B0),
              ),
            ),
          ],
        ),
        content: const Text(
          'يمكنك السماح بالوصول للموقع من إعدادات التطبيق.',
          style: TextStyle(fontFamily: 'Tajawal', color: Color(0xFFE8D5B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Color(0xFF9B8A6E)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'الإعدادات',
              style: TextStyle(color: Color(0xFFC8922A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayerState = ref.watch(prayerProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF03020F),
              Color(0xFF0A0720),
              Color(0xFF120E2E),
              Color(0xFF1A132A),
              Color(0xFF221A2E),
            ],
            stops: [0.0, 0.25, 0.55, 0.8, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  'assets/images/stars_bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeroSection(prayerState),
                  _buildSuhoorIftarBanner(prayerState),
                  _buildDateNav(prayerState, ref),
                  const _GeoDivider(),
                  Expanded(
                    child: !prayerState.hasLocation
                        ? _buildLocationRequiredState()
                        : prayerState.isLoading || prayerState.prayers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 32.w,
                                  height: 32.w,
                                  child: const CircularProgressIndicator(
                                    color: AppColors.goldWarm,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'جاري تحميل المواقيت...',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12.sp,
                                    color: AppColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 8.h,
                            ),
                            itemCount: prayerState.prayers.length,
                            separatorBuilder: (_, _) => SizedBox(height: 8.h),
                            itemBuilder: (context, index) {
                              final item = prayerState.prayers[index];
                              return _PrayerRow(
                                item: item,
                                onCheckToggle: () => ref
                                    .read(prayerProvider.notifier)
                                    .toggleCheck(item.id),
                                onNotifToggle: () async {
                                  // ✅ المرحلة 4: هذا التبديل هو "أول تفعيل أذان"
                                  // إن كان مُعطَّلاً قبل الضغط — يُحدَّد هنا قبل
                                  // toggleNotification() لأنها لا تُعيد قيمة.
                                  final isEnabling = !item.isNotificationEnabled;

                                  if (isEnabling) {
                                    final hasPermission =
                                        await NotificationPermissionService.hasPermission();
                                    final hasLocation =
                                        LocationService.instance.hasLocation;

                                    if (!hasPermission || !hasLocation) {
                                      if (!context.mounted) return;
                                      _showPermissionRequiredDialog(
                                        context,
                                        hasPermission,
                                        hasLocation,
                                      );
                                      return;
                                    }
                                  }
                                  ref
                                      .read(prayerProvider.notifier)
                                      .toggleNotification(item.id);

                                  // ✅ المرحلة 4: تنبيه إعفاء البطارية السياقي —
                                  // مرّة واحدة بعد أول تفعيل أذان، لا عند فتح
                                  // التطبيق. BatteryPromptService يتولّى فحص
                                  // (هل ممنوح أصلاً؟ / هل رُفض خلال 30 يوماً؟)
                                  // داخلياً قبل أي عرض فعلي.
                                  if (isEnabling) {
                                    if (!context.mounted) return;
                                    await BatteryPromptService.instance
                                        .maybeShow(context);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                  _PrayerCountdownTimer(
                    targetTime: prayerState.nextPrayer?.time,
                    prayerName: prayerState.nextPrayer?.name,
                  ),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
            Positioned(
              top: 40.h,
              left: 330.w,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero: اسم الصلاة القادمة + وقتها ──────────────────────────────
  Widget _buildHeroSection(PrayerState state) {
    final next = state.nextPrayer ?? state.prayers.firstOrNull;

    return Padding(
      padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
      child: Column(
        children: [
          Text(
            next?.name ?? '...',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 22.sp,
              color: AppColors.goldLight,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: AppColors.goldWarm.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                next?.timeStr ?? '--:--',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 42.sp,
                  height: 1.0,
                  color: AppColors.goldGlow,
                  shadows: [
                    Shadow(
                      color: AppColors.goldWarm.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                next?.ampm ?? '',
                style: TextStyle(fontSize: 16.sp, color: AppColors.goldWarm),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 5.w,
                height: 5.w,
                decoration: const BoxDecoration(
                  color: AppColors.goldWarm,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                _cityName,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── بانر السحور والإفطار ───────────────────────────────────────────
  Widget _buildSuhoorIftarBanner(PrayerState state) {
    final suhoorStr = state.suhoorTime != null
        ? intl.DateFormat('h:mm').format(state.suhoorTime!)
        : '--:--';
    final iftarStr = state.iftarTime != null
        ? intl.DateFormat('h:mm').format(state.iftarTime!)
        : '--:--';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldWarm.withValues(alpha: 0.08),
            blurRadius: 25,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSIBlock('وقت السحور', suhoorStr, 'ص'),
          Container(
            width: 1,
            height: 34.h,
            color: AppColors.goldWarm.withValues(alpha: 0.4),
          ),
          _buildSIBlock('وقت الإفطار', iftarStr, 'م'),
        ],
      ),
    );
  }

  Widget _buildSIBlock(String label, String time, String ampm) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: AppColors.textDim),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              time,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 18.sp,
                color: AppColors.goldLight,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 2.w),
            Text(
              ampm,
              style: TextStyle(fontSize: 10.sp, color: AppColors.goldWarm),
            ),
          ],
        ),
      ],
    );
  }

  // ── شريط التنقل بين التواريخ ──────────────────────────────────────
  Widget _buildDateNav(PrayerState state, WidgetRef ref) {
    final hijri = state.hijriDate;
    final greg = state.selectedDate;
    final gregStr = intl.DateFormat('d MMMM yyyy', 'ar').format(greg);
    final hijriStr = '${hijri.hDay} ${hijri.longMonthName}، ${hijri.hYear} هـ';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1535).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavArrow(
            icon: Icons.arrow_back_ios_new,
            onTap: () => ref.read(prayerProvider.notifier).changeDate(1),
          ),
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 4.w,
                    decoration: const BoxDecoration(
                      color: AppColors.goldWarm,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    hijriStr,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14.sp,
                      color: AppColors.goldLight,
                    ),
                  ),
                ],
              ),
              Text(
                gregStr,
                style: TextStyle(fontSize: 10.sp, color: AppColors.textDim),
              ),
            ],
          ),
          _NavArrow(
            icon: Icons.arrow_forward_ios,
            onTap: () => ref.read(prayerProvider.notifier).changeDate(-1),
          ),
        ],
      ),
    );
  }

  // ── حالة: الموقع غير محدد ─────────────────────────────────────────
  Widget _buildLocationRequiredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_rounded,
            size: 48.sp,
            color: AppColors.goldWarm.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'لم يتم تحديد موقعك بعد',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'حدد موقعك لعرض مواقيت الصلاة',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.sp,
              color: AppColors.textDim,
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // زر: تحديد تلقائي
              GestureDetector(
                onTap: _detectingLocation ? null : _detectLocation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldWarm.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.4),
                    ),
                  ),
                  child: _detectingLocation
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            color: AppColors.goldWarm,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              color: AppColors.goldLight,
                              size: 15.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'تحديد تلقائي',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12.sp,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            
              // زر: اختيار يدوي
         ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// العداد التنازلي للصلاة القادمة
// ══════════════════════════════════════════════════════════════════════

class _PrayerCountdownTimer extends ConsumerStatefulWidget {
  final DateTime? targetTime;
  final String? prayerName;

  const _PrayerCountdownTimer({this.targetTime, this.prayerName});

  @override
  ConsumerState<_PrayerCountdownTimer> createState() =>
      _PrayerCountdownTimerState();
}

class _PrayerCountdownTimerState extends ConsumerState<_PrayerCountdownTimer> {
  String _timeLeft = '00:00:00';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PrayerCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ تحديث فوري عند تغير targetTime
    if (oldWidget.targetTime != widget.targetTime) {
      _updateTime();
    }
  }

  void _startTimer() {
    _updateTime();
    _timer?.cancel(); // ✅ إلغاء Timer القديم إن وجد
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  void _updateTime() {
    if (widget.targetTime == null) {
      if (mounted) setState(() => _timeLeft = '00:00:00');
      return;
    }

    final now = DateTime.now();
    final diff = widget.targetTime!.difference(now);

    // ✅ إذا أصبح الوقت سالباً، العداد يعرض 00:00:00
    // Provider سيحدّث تلقائياً كل دقيقة
    if (diff.isNegative) {
      if (mounted) {
        setState(() => _timeLeft = '00:00:00');
      }
      return;
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    if (mounted) {
      setState(() {
        _timeLeft =
            '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1535).withValues(alpha: 0.85),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        children: [
          Text(
            widget.prayerName == 'الشروق'
                ? 'الوقت المتبقي للشروق'
                : 'الوقت المتبقي للأذان القادم',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 9.sp,
              color: AppColors.textDim,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            _timeLeft,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 24.sp,
              color: AppColors.goldLight,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// زر التنقل بين التواريخ
// ══════════════════════════════════════════════════════════════════════

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34.w,
        height: 34.w,
        decoration: BoxDecoration(
          color: AppColors.goldWarm.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(9.r),
        ),
        child: Icon(icon, color: AppColors.goldLight, size: 16.sp),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// صف وقت الصلاة الواحدة
// ══════════════════════════════════════════════════════════════════════

class _PrayerRow extends StatelessWidget {
  final PrayerTimeItem item;
  final VoidCallback onCheckToggle;
  final VoidCallback onNotifToggle;

  const _PrayerRow({
    required this.item,
    required this.onCheckToggle,
    required this.onNotifToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 300.ms,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1535).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 65.w,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  item.timeStr,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 16.sp,
                    color: AppColors.goldLight,
                  ),
                ),
                SizedBox(width: 3.w),
                Text(
                  item.ampm,
                  style: TextStyle(fontSize: 9.sp, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                item.name,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.sp,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // ── أيقونة الجرس (الإشعار) ──
          GestureDetector(
            onTap: onNotifToggle,
            child: AnimatedContainer(
              duration: 200.ms,
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                color: item.isNotificationEnabled
                    ? AppColors.goldWarm.withValues(alpha: 0.15)
                    : Colors.transparent,
                border: Border.all(
                  color: item.isNotificationEnabled
                      ? AppColors.goldWarm.withValues(alpha: 0.5)
                      : AppColors.goldWarm.withValues(alpha: 0.15),
                  width: 1.2,
                ),
              ),
              child: Icon(
                item.isNotificationEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                size: 14.sp,
                color: item.isNotificationEnabled
                    ? AppColors.goldWarm
                    : AppColors.textDim,
              ),
            ),
          ),
          SizedBox(width: 8.w),

          // ── علامة الصح (الصلاة) أو مساحة فارغة للشروق ──
          item.id == 'shurooq'
              ? SizedBox(width: 22.w, height: 22.w) // مساحة فارغة للشروق
              : GestureDetector(
                  onTap: onCheckToggle,
                  child: AnimatedContainer(
                    duration: 200.ms,
                    width: 22.w,
                    height: 22.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: item.isChecked
                            ? AppColors.goldLight
                            : AppColors.goldWarm.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      gradient: item.isChecked
                          ? const LinearGradient(
                              colors: [AppColors.goldWarm, AppColors.goldLight],
                            )
                          : null,
                      color: item.isChecked
                          ? null
                          : AppColors.goldWarm.withValues(alpha: 0.04),
                    ),
                    child: item.isChecked
                        ? Icon(Icons.check, size: 14.sp, color: AppColors.nightDeep)
                        : null,
                  ),
                ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// الفاصل الزخرفي
// ══════════════════════════════════════════════════════════════════════

class _GeoDivider extends StatelessWidget {
  const _GeoDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      height: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(double.infinity, 1),
            painter: _DottedLinePainter(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '❖',
                style: TextStyle(
                  color: AppColors.goldWarm.withValues(alpha: 0.45),
                  fontSize: 10.sp,
                ),
              ),
              Text(
                '❖',
                style: TextStyle(
                  color: AppColors.goldWarm.withValues(alpha: 0.45),
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.goldWarm.withValues(alpha: 0.28)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════
// دالة عرض رسالة: يجب تفعيل الأذونات والموقع أولاً
// ══════════════════════════════════════════════════════════════════════

void _showPermissionRequiredDialog(
  BuildContext context,
  bool hasNotification,
  bool hasLocation,
) {
  String title;
  String message;
  IconData icon;

  if (!hasNotification && !hasLocation) {
    title = 'تفعيل الإشعارات والموقع مطلوب';
    message =
        'لاستخدام إشعارات الصلاة، يجب عليك السماح بإرسال الإشعارات وتحديد موقعك أولاً.';
    icon = Icons.notifications_off_rounded;
  } else if (!hasNotification) {
    title = 'تفعيل الإشعارات مطلوب';
    message =
        'لاستخدام إشعارات الصلاة، يجب عليك السماح بإرسال الإشعارات أولاً.';
    icon = Icons.notifications_off_rounded;
  } else {
    title = 'تحديد الموقع مطلوب';
    message =
        'لاستخدام إشعارات الصلاة، يجب عليك تحديد موقعك أولاً لحساب أوقات الصلاة بدقة.';
    icon = Icons.location_off_rounded;
  }

  showDialog(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, child) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFFC8922A).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Icon(icon, color: const Color(0xFFC8922A), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 18,
                  color: Color(0xFFE8D5B0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            color: Color(0xFFE8D5B0),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'إلغاء',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: Color(0xFF9B8A6E),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // تفعيل الإشعارات إذا لم تكن مفعلة
              if (!hasNotification) {
                final granted =
                    await NotificationPermissionService.requestPermission();
                if (granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تفعيل الإشعارات بنجاح'),
                      backgroundColor: Color(0xFFC8922A),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  ref.read(prayerProvider.notifier).changeDate(0);
                }
              }

              // تفعيل الموقع إذا لم يكن محدداً
              if (!hasLocation && context.mounted) {
                final state = context
                    .findAncestorStateOfType<_PrayerTimesScreenState>();
                if (state != null) {
                  await state._detectLocation();
                }
              }
            },
            child: const Text(
              'تفعيل الآن',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 15,
                color: Color(0xFFC8922A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}