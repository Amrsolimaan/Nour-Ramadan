import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nour_ramadan/QUICK_DIAGNOSTIC_CODE.dart';
import 'package:nour_ramadan/features/dua/screens/athkar_screen.dart';
import 'package:nour_ramadan/features/tasbih/screens/tasbih_screen.dart';
import 'package:nour_ramadan/features/prayer/screens/prayer_times_screen.dart';
import 'package:nour_ramadan/features/qibla/screens/qibla_screen.dart';
import 'package:nour_ramadan/features/home/providers/home_provider.dart';
import 'package:nour_ramadan/features/prayer/providers/prayer_provider.dart';
import 'package:nour_ramadan/features/hifz/providers/hifz_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'core/theme/app_theme.dart';
import 'shared/widgets/loading_screen.dart';
import 'shared/widgets/notification_permission_screen.dart';
import 'shared/widgets/location_permission_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/location/screens/location_picker_screen.dart';
import 'core/services/prefs_keys.dart';
import 'core/services/prefs_migration.dart';
import 'core/services/timezone_service.dart';
import 'core/services/timezone_fix_reschedule.dart';
import 'core/services/ios_notification_window.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_permission_service.dart';
import 'core/services/location_service.dart';
import 'core/services/location_permission_service.dart';
import 'core/services/unified_azan_service.dart';
import 'core/services/prayer_notification_manager.dart';
import 'core/services/quran_progress_service.dart';
import 'core/services/last_read_service.dart';
import 'core/services/hifz_service.dart';
import 'core/services/prayer_tracking_service.dart';
import 'core/services/dua_tracking_service.dart';
import 'core/services/tasbih_tracking_service.dart';
import 'core/services/azan_settings_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/services/app_logger.dart';
import 'package:nour_ramadan/features/dua/screens/dua_home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// ════════════════════════════════════════════════════════════════
//  المفاتيح العامة
// ════════════════════════════════════════════════════════════════
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ════════════════════════════════════════════════════════════════
//  Workmanager — دور مختلف تماماً على كل منصّة:
//
//  Android: ✅ FIX M13 — معطَّل لصالح AzanWorker في Kotlin، لأنه
//  أكثر موثوقية (يعمل بدون Flutter engine، لا يحتاج ProviderContainer).
//  المهمّة القديمة إن وُجدت تبقى مُسجَّلة للتوافق، لكن جسمها هنا لا
//  يفعل شيئاً — راجع plan_azan_reliability.md، تدقيق المرحلة 6.
//
//  iOS: ✅ المرحلة 7 — هذا هو المسار الوحيد الممكن أصلاً؛ لا معادل
//  لـ AlarmScheduler.kt على iOS (لا AlarmManager). BGAppRefreshTask
//  (مُسجَّل عبر AppDelegate.swift + هذا Workmanager) يستدعي هذا الجسم
//  في محرّك Flutter بلا واجهة (headless) — IosNotificationWindow
//  تُجدِّد نافذتها المتدرّجة من هنا عند كل استدعاء.
// ════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (Platform.isIOS) {
      await IosNotificationWindow.topUpIfNeeded();
    } else {
      // ✅ FIX M13: لا نُنفّذ شيئاً من Flutter على أندرويد — AzanWorker يتولى الأمر
      debugPrint('ℹ️ Flutter Workmanager task received but disabled (AzanWorker handles this)');
    }
    return true;
  });
}

// ════════════════════════════════════════════════════════════════
//  main
// ════════════════════════════════════════════════════════════════
Future<void> main() async {
  // ── Native Splash — الحفاظ على شاشة البداية حتى اكتمال التهيئة ──
  final WidgetsBinding widgetsBinding =
      WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await initializeDateFormatting('ar', null);

  // ── ترحيل مفاتيح SharedPreferences (مرّة واحدة) ───────────────
  // ⚠️ يجب أن يسبق أي قراءة/كتابة للموقع أو بيانات الأذان.
  // ينقل المفاتيح مزدوجة البادئة (flutter.flutter.*) إلى أسمائها
  // الصحيحة (flutter.*) التي تقرأها طبقة Kotlin.
  // راجع plan_azan_reliability.md §1.8 — المرحلة 1
  await PrefsMigration.run();

  // ── Timezone ──────────────────────────────────────────────────
  // ✅ المرحلة 5: حلّ فعلي للمنطقة الزمنية الحقيقية عبر flutter_timezone.
  //
  // ❌ السلوك القديم: tz_local.setLocalLocation(tz_local.local) — لكن
  // tz.local لا يفعل شيئاً سوى إعادة حقل خاص يبدأ بـ UTC ولا يرمي أبداً
  // (راجع package:timezone/src/env.dart)، فالتطبيق كان يبقى على UTC
  // دائماً، و catch الاحتياطي لـ Africa/Cairo كان كوداً ميتاً لا يُنفَّذ
  // إطلاقاً. راجع plan_azan_reliability.md §1.5.
  tz.initializeTimeZones();
  await TimezoneService.resolveAndApply();

  // ── Firebase ──────────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Firebase Crashlytics ──────────────────────────────────────
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // ── Remote Config ─────────────────────────────────────────────
  await RemoteConfigService().initialize();

  // ── Notification Service ──────────────────────────────────────
  await NotificationService().initialize();

  // ── App Logger ────────────────────────────────────────────────
  await logger.initialize();
  logger.info(LogCategory.system, 'App started');

  // ── Callback لأزرار الإشعارات ─────────────────────────────────
  onNotificationActionCallback = (actionId) {
    debugPrint('🎯 onNotificationActionCallback: $actionId');
    _navigateFromAction(actionId);
  };

  // ── MethodChannel: إشعارات من Kotlin ──────────────────────────
  // ✅ يُستخدم فقط عندما يكون التطبيق مفتوحاً (onNewIntent)
  // عند البدء البارد، نعتمد على SharedPreferences فقط
  const notificationChannel = MethodChannel(
    'com.nour_ramadan/notification_actions',
  );
  notificationChannel.setMethodCallHandler((call) async {
    debugPrint('🎯 notificationChannel received: ${call.method} with args: ${call.arguments}');
    if (call.method == 'onNotificationAction') {
      final actionId = call.arguments as String;
      debugPrint('🚀 Hot navigation (app already open): $actionId');
      _navigateFromAction(actionId);
    }
  });

  // ══════════════════════════════════════════════════════════════
  //  MethodChannel: الأذان — معالج إعادة الجدولة عند تغيير الوقت
  //  
  //  ✅ FIX: تحسين معالجة تغيير الوقت
  //  يُستدعى من TimeChangeReceiver عند تغيير وقت النظام
  //  
  //  الإجراء:
  //  1. إعادة حساب أوقات الصلاة من الصفر
  //  2. إعادة جدولة الأذانات بـ timestamps جديدة
  // ══════════════════════════════════════════════════════════════

  const azanChannel = MethodChannel('com.nour_ramadan/azan_service');
  azanChannel.setMethodCallHandler((call) async {
    debugPrint('📲 azanChannel (main): ${call.method}');
    if (call.method == 'rescheduleFromTimeChange') {
      debugPrint('🔄 Time/Timezone changed - recalculating and rescheduling');

      try {
        // ✅ المرحلة 5: إعادة حلّ المنطقة الزمنية أولاً — نفس نقطة
        // الدخول التاريخية لتغيّر الوقت/المنطقة من الناتيف. لم نُضِف
        // معالجاً جديداً؛ هذا المعالج موجود أصلاً (وإن كان TimeChangeReceiver
        // الحالي بعد إعادة كتابة المرحلة 2 لا يستدعيه مباشرةً — يبقى
        // صحيحاً لأي مسار آخر يستدعيه).
        await TimezoneService.resolveAndApply();

        // ✅ انتظار قصير لضمان استقرار النظام
        await Future.delayed(const Duration(milliseconds: 500));

        final context = navigatorKey.currentContext;
        if (context != null) {
          debugPrint('✅ Context available - triggering full recalculation');
          
          // الخطوة 1: إعادة حساب أوقات الصلاة
          final prayerNotifier = ProviderScope.containerOf(context)
              .read(prayerProvider.notifier);
          final loc = LocationService.instance;
          
          if (loc.hasLocation && loc.lat != null && loc.lng != null) {
            await prayerNotifier.calculatePrayers(
              loc.lat!,
              loc.lng!,
              DateTime.now(),
            );
            debugPrint('✅ Prayer times recalculated');
          }
          
          // الخطوة 2: إعادة جدولة الأذانات
          final manager = ProviderScope.containerOf(context)
              .read(prayerNotificationManagerProvider);
          await manager.manualReschedule();
          
          debugPrint('✅ Reschedule completed after time change');
        } else {
          debugPrint('⚠️ No context yet — will reschedule when app opens');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Reschedule failed: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
  });

  // ── UnifiedAzanService ────────────────────────────────────────
  await UnifiedAzanService().initialize();

  // ── التحقق من إذن المنبهات الدقيقة ──────────────────────────
  try {
    final hasAlarmPerm = await azanChannel.invokeMethod<bool>(
      'hasExactAlarmPermission',
    );
    if (hasAlarmPerm == false) {
      debugPrint('⚠️ SCHEDULE_EXACT_ALARM not granted - requesting...');
      await azanChannel.invokeMethod('requestExactAlarmPermission');
    }
  } catch (e) {
    debugPrint('⚠️ Alarm permission check: $e');
  }

  // ── التحقق من إذن Full Screen Intent (لإظهار الشاشة) ──────────
  try {
    final hasFullScreenPerm = await azanChannel.invokeMethod<bool>(
      'hasFullScreenIntentPermission',
    );
    if (hasFullScreenPerm == false) {
      debugPrint('⚠️ USE_FULL_SCREEN_INTENT not granted - requesting...');
      await azanChannel.invokeMethod('requestFullScreenIntentPermission');
    } else {
      debugPrint('✅ USE_FULL_SCREEN_INTENT granted - AdhanActivity will show');
    }
  } catch (e) {
    debugPrint('⚠️ Full screen intent permission check: $e');
  }

  // ── التحقق من Battery Optimization ──────────────────────────
  try {
    final azanService = UnifiedAzanService();
    final isBatteryOptimized = await azanService
        .isBatteryOptimizationDisabled();
    if (!isBatteryOptimized) {
      debugPrint('⚠️ Battery optimization is enabled - may affect azan timing');
      // ملاحظة: يمكن إضافة حوار للمستخدم هنا لاحقاً
      // await azanService.requestBatteryExemption();
    } else {
      debugPrint(
        '✅ Battery optimization disabled - azan timing should be accurate',
      );
    }
  } catch (e) {
    debugPrint('⚠️ Battery optimization check: $e');
  }

  // ── System UI ─────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF08061A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Hive ──────────────────────────────────────────────────────
  await Hive.initFlutter();
  
  // ✅ FIX: فتح verse_cache_v2 مسبقاً قبل runApp
  // بدون هذا السطر، Hive.openBox داخل Provider يفشل صامتاً
  // ويمنع Firebase من تحديث الآية تماماً
  try {
    await Hive.openBox<Map>('verse_cache_v2');
    debugPrint('✅ Hive verse_cache_v2 opened successfully');
  } catch (e) {
    debugPrint('⚠️ Hive verse_cache_v2 open failed: $e');
  }

  // ── تحميل الموقع المحفوظ والانتظار حتى اكتماله ─────────────────
  await LocationService.instance.loadSaved();
  debugPrint(
    '✅ Location service loaded: ${LocationService.instance.hasLocation ? LocationService.instance.city : 'No location'}',
  );

  // ── تهيئة خدمات التتبع بشكل متوازي ───────────────────────────────
  await Future.wait([
    QuranProgressService.init(),
    LastReadService.init(),
    HifzService.init(),
    PrayerTrackingService.init(),
    DuaTrackingService.init(),
    TasbihTrackingService.init(),
    AzanSettingsService.init(),
  ]);
  debugPrint('✅ All tracking services initialized');

  // ── Workmanager ───────────────────────────────────────────────
  // ✅ FIX M13: initialize فقط للتوافق — لا نُسجّل task جديد
  // AzanWorker.kt يتولى الجدولة الدورية كل 12 ساعة
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // ════════════════════════════════════════════════════════════
  // ✅ الإصلاح الجوهري — Cold Start:
  //    نقرأ pending_navigation هنا في main() قبل runApp
  //    بهذا تكون القيمة في الذاكرة جاهزة بعد انتهاء LoadingScreen
  //    ونتجنب كلياً مشكلة mounted / _AppRootState خارج الشجرة
  // ════════════════════════════════════════════════════════════
  final prefs = await SharedPreferences.getInstance();
  final earlyPendingAction = prefs.getString(PrefKeys.pendingNavigation);
  if (earlyPendingAction != null) {
    // احذفها فوراً حتى لا تُنفَّذ مرة ثانية عند أي resume
    await prefs.remove(PrefKeys.pendingNavigation);
    debugPrint('🔍 Early read & cleared pending_navigation = $earlyPendingAction');
  }

  // ✅ تشغيل التطبيق — سيتم إزالة Native Splash داخل _AppRootState.initState
  //    بعد رسم أول فريم لتفادي الشاشة السوداء
  runApp(ProviderScope(child: NourRamadanApp(pendingAction: earlyPendingAction)));

  // ✅ FIX M12: quickDiagnostics في debug mode فقط
  // السبب: كان يُشتغل عند كل launch في production — عبء غير ضروري
  assert(() {
    Future.delayed(const Duration(seconds: 3), () => quickDiagnostics());
    return true;
  }());
}

// ════════════════════════════════════════════════════════════════
//  دالة التنقل المشتركة
// ════════════════════════════════════════════════════════════════
void _navigateFromAction(String actionId) {
  debugPrint('🧭 DEBUG: _navigateFromAction called with: $actionId');
  final navigator = navigatorKey.currentState;
  debugPrint('🔍 DEBUG: navigatorKey.currentState = $navigator');
  
  if (navigator == null) {
    debugPrint('❌ Navigator is null - saving to SharedPreferences for later');
    // ✅ إذا لم يكن Navigator جاهزاً، احفظ في SharedPreferences
    // سيتم التحقق منه عند _checkPendingNavigation()
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(PrefKeys.pendingNavigation, actionId);
      debugPrint('🔍 DEBUG: Re-saved to SharedPreferences: pending_navigation=$actionId');
    });
    return;
  }

  debugPrint('🔍 DEBUG: Navigator is ready, determining target screen...');
  Widget? target;
  switch (actionId) {
    case 'open_athkar':
      debugPrint('✅ Navigating to Athkar');
      target = const AthkarScreen();
      break;
    case 'open_dua':
      debugPrint('✅ Navigating to Dua');
      target = const DuaHomeScreen();
      break;
    case 'open_qibla':
      debugPrint('✅ Navigating to Qibla');
      target = const QiblaScreen();
      break;
    case 'open_prayer_times':
      debugPrint('✅ Navigating to Prayer Times');
      target = const PrayerTimesScreen();
      break;
    case 'open_tasbih':
      debugPrint('✅ Navigating to Tasbih');
      target = const TasbihScreen();
      break;
    default:
      debugPrint('❌ Unknown action: $actionId');
      return;
  }

  debugPrint('🔍 DEBUG: Calling navigator.pushAndRemoveUntil...');
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => target!),
    (route) => route.isFirst,
  );
  debugPrint('✅ Navigation completed');
}

// ════════════════════════════════════════════════════════════════
//  App
// ════════════════════════════════════════════════════════════════
class NourRamadanApp extends StatelessWidget {
  const NourRamadanApp({super.key, this.pendingAction});

  /// ✅ القيمة المقروءة من SharedPreferences قبل runApp
  final String? pendingAction;

  static const _designSize = Size(390, 844);

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: _designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'نور رمضان',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          locale: const Locale('ar'),
          navigatorKey: navigatorKey,
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: child!,
              ),
            );
          },
          home: _AppRoot(pendingAction: pendingAction),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  AppRoot — جذر التطبيق ومدير التنقل الأولي
// ════════════════════════════════════════════════════════════════
class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot({this.pendingAction});

  /// ✅ pending action المقروء مسبقاً من main()
  final String? pendingAction;

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot>
    with WidgetsBindingObserver {
  bool _isHomeReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ الإصلاح: إزالة Native Splash بعد رسم أول فريم مباشرة
    //    هذا يضمن ظهور LoadingScreen قبل اختفاء الـ Splash
    //    فلا تظهر أي شاشة سوداء بينهما
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    Future.microtask(() async {
      // ✅ تهيئة PrayerNotificationManager مبكراً
      ref.read(prayerNotificationManagerProvider);
    });

    // ✅ متابعة المرحلة 5: إعادة جدولة تذكير الورد مرّة واحدة بعد إصلاح
    // المنطقة الزمنية — خطوة مستقلة عن TimezoneService.resolveAndApply()
    // (التي أُنجزت في main() قبل runApp())، تعمل هنا لأنها الأولى فعلاً
    // التي يتوفّر فيها ref (hifzProvider/hifzSettingsProvider). راجع
    // plan_azan_reliability.md — لماذا هذا النطاق فقط (لا أذان/تذكير/
    // سحور/إفطار: لم تكن خاطئة أصلاً).
    Future.microtask(() async {
      await TimezoneFixRescheduleMigration.run(() async {
        await ref.read(hifzProvider.notifier).rescheduleReminderNow();
      });
    });

    // ✅ المرحلة 7 (iOS): تسجيل مهمّة الخلفية (BGAppRefreshTask) وتجديد
    // فوري للنافذة المتدرّجة عند كل إقلاع — لا شيء يحدث على أندرويد
    // (كلا الاستدعاءين مُبوَّبان iOS فقط داخلياً).
    Future.microtask(() async {
      await IosNotificationWindow.registerBackgroundTask();
      await IosNotificationWindow.topUpIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔄 App lifecycle changed to: $state');
    
    if (state == AppLifecycleState.resumed) {
      // ✅ فحص الأذونات فوراً عند العودة للتطبيق (حتى قبل _isHomeReady)
      _recheckPermissionsAndReschedule();
      
      if (_isHomeReady) {
        _checkPendingNavigation();
      }
    }
  }

  /// فحص الأذونات وإعادة جدولة الإشعارات إذا تم منحها
  Future<void> _recheckPermissionsAndReschedule() async {
    try {
      // ✅ المرحلة 5: إعادة حلّ المنطقة الزمنية عند كل استئناف — نفس
      // الخطّاف الموجود فعلاً لإعادة فحص الأذونات، بلا خطّاف جديد.
      // يُغطّي حالة: المستخدم غيّر منطقته الزمنية/توقيته الصيفي بينما
      // كان التطبيق في الخلفية، ثم عاد إليه.
      await TimezoneService.resolveAndApply();

      // فحص إذن الإشعارات
      final hasNotification = await NotificationPermissionService.hasPermission();
      
      // فحص إذن الموقع
      final hasLocation = LocationService.instance.hasLocation;
      
      debugPrint('🔍 Permission recheck: notification=$hasNotification, location=$hasLocation');
      
      // إذا تم منح الأذونات، أعد جدولة الإشعارات
      if (hasNotification && hasLocation) {
        debugPrint('✅ Permissions granted - rescheduling notifications');
        
        // إعادة جدولة الإشعارات
        final manager = ref.read(prayerNotificationManagerProvider);
        await manager.manualReschedule();
        
        debugPrint('✅ Notifications rescheduled successfully');
      } else {
        debugPrint('⚠️ Permissions not fully granted - skipping reschedule');
      }
    } catch (e) {
      debugPrint('⚠️ Error rechecking permissions: $e');
    }
  }

  void _onHomeReady() {
    debugPrint('🏠 DEBUG: Home is ready - checking for pending navigation');
    debugPrint('🔍 DEBUG: _isHomeReady = $_isHomeReady');
    _isHomeReady = true;
    // ✅ فحص SharedPreferences فقط - مصدر الحقيقة الوحيد
    _checkPendingNavigation();
  }

  Future<void> _checkPendingNavigation() async {
    debugPrint('🔍 DEBUG: _checkPendingNavigation called');
    debugPrint('🔍 DEBUG: _isHomeReady = $_isHomeReady');
    
    if (!_isHomeReady) {
      debugPrint('⏳ Home not ready yet - skipping pending navigation check');
      return;
    }
    
    debugPrint('🔍 DEBUG: Getting SharedPreferences instance...');
    final prefs = await SharedPreferences.getInstance();
    debugPrint('🔍 DEBUG: SharedPreferences instance obtained');
    
    final pendingAction = prefs.getString(PrefKeys.pendingNavigation);
    debugPrint('🔍 DEBUG: Read from SharedPreferences: pending_navigation = $pendingAction');
    
    if (pendingAction != null && mounted) {
      debugPrint('🎯 Found pending navigation: $pendingAction');
      await prefs.remove(PrefKeys.pendingNavigation);
      debugPrint('🔍 DEBUG: Removed pending_navigation from SharedPreferences');
      
      // ✅ تأخير قصير للتأكد من اكتمال بناء الشاشة الرئيسية
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('🔍 DEBUG: Delay completed, checking mounted state...');
      
      if (mounted) {
        debugPrint('🚀 Executing pending navigation: $pendingAction');
        _navigateFromAction(pendingAction);
      } else {
        debugPrint('❌ Widget not mounted - cannot navigate');
      }
    } else {
      debugPrint('✅ No pending navigation found (pendingAction=$pendingAction, mounted=$mounted)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingScreen(
      isNight: true,
      onFinished: () async {
        // ── شاشة الإشعارات ────────────────────────────────────
        final shouldShowNotifPermission =
            await NotificationPermissionService.shouldShowPermissionScreen();

        if (!mounted) return;

        if (shouldShowNotifPermission) {
          _pushNotificationPermissionScreen();
        } else {
          _navigateToLocationOrHome();
        }
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  صفحة أذونات الإشعارات
  // ════════════════════════════════════════════════════════════
  void _pushNotificationPermissionScreen() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => NotificationPermissionScreen(
          onAllow: () async {
            // ✅ طلب الإذن فعلياً
            await NotificationPermissionService.requestPermission();
            _navigateToLocationOrHome();
          },
          onSkip: () async {
            // ✅ تسجيل الرفض
            await NotificationPermissionService.skipPermission();
            _navigateToLocationOrHome();
          },
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  التوجيه لصفحة الموقع أو الصفحة الرئيسية
  // ════════════════════════════════════════════════════════════
  Future<void> _navigateToLocationOrHome() async {
    final shouldShowLocation =
        await LocationPermissionService.shouldShowLocationScreen();

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (shouldShowLocation) {
      _pushLocationPermissionScreen();
    } else {
      _goHome();
    }
  }

  // ════════════════════════════════════════════════════════════
  //  صفحة أذونات الموقع — ✅ تدعم الآن GPS و اختيار يدوي و تخطي
  // ════════════════════════════════════════════════════════════
  void _pushLocationPermissionScreen() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => LocationPermissionScreen(
          // ── GPS تلقائي ──────────────────────────────────────
          onGpsSelected: (lat, lng, city) async {
            debugPrint('🟢 [STEP 1] onGpsSelected called: $city ($lat, $lng)');

            try {
              // ✅ حفظ حالة "تم تحديد الموقع"
              debugPrint('🟢 [STEP 2] Marking location as set...');
              await LocationPermissionService.markLocationAsSet();
              debugPrint('✅ [STEP 2] Location marked successfully');

              // ✅ الحصول على navigator
              debugPrint('🟢 [STEP 3] Getting navigator...');
              final nav = navigatorKey.currentState;
              debugPrint('🟢 [STEP 3] navigator = $nav');
              if (nav == null) {
                debugPrint('❌ [STEP 3] Navigator is NULL - RETURNING!');
                return;
              }
              debugPrint('✅ [STEP 3] Navigator is ready');

              // ✅ الانتقال للصفحة الرئيسية
              debugPrint('🟢 [STEP 4] Calling pushReplacement...');
              nav.pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, __) {
                    debugPrint('🟢 [STEP 5] Building HomeScreen...');
                    return const HomeScreen();
                  },
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 600),
                ),
              );
              debugPrint('✅ [STEP 4] pushReplacement called successfully');

              // ✅ جدولة الإشعارات بعد التنقل
              debugPrint('🟢 [STEP 6] Scheduling notifications...');
              Future.delayed(const Duration(milliseconds: 700), () async {
                debugPrint('🟢 [STEP 7] Delayed callback executing...');

                try {
                  // ✅ FIX: التحقق من أن context لا يزال صالحاً
                  final currentContext = navigatorKey.currentContext;
                  if (currentContext == null || !currentContext.mounted) {
                    debugPrint('⚠️ [STEP 7] Context disposed - skipping');
                    return;
                  }
                  
                  // استخدام ProviderScope بدلاً من ref المباشر
                  final container = ProviderScope.containerOf(currentContext);
                  
                  container.read(homeProvider.notifier).refreshAfterCityChange();
                  debugPrint('✅ [STEP 7] City name refreshed in homeProvider');

                  await container
                      .read(prayerNotificationManagerProvider)
                      .manualReschedule();
                  debugPrint('✅ [STEP 7] Notifications scheduled');
                } catch (e) {
                  debugPrint('❌ [STEP 7] Error scheduling notifications: $e');
                }
              });
              debugPrint('✅ [STEP 6] Delayed callback registered');

              debugPrint('✅ [FINAL] onGpsSelected completed successfully!');
            } catch (e, stackTrace) {
              debugPrint('❌ [ERROR] Exception in onGpsSelected: $e');
              debugPrint('❌ [ERROR] StackTrace: $stackTrace');
            }
          },
          // ── اختيار يدوي ─────────────────────────────────────
          onManualSelection: () async {
            final nav = navigatorKey.currentState;
            if (nav == null) return;

            await nav.push<String>(
              MaterialPageRoute(
                builder: (_) => LocationPickerScreen(
                  onCitySelected: (city, lat, lng) async {
                    await LocationPermissionService.markLocationAsSet();
                    Future.delayed(const Duration(milliseconds: 500), () async {
                      ref
                          .read(prayerNotificationManagerProvider)
                          .manualReschedule();

                      // ⚠️ PHASE 4: Countdown disabled
                      /*
                      if (LocationService.instance.hasLocation) {
                        final next = LocationService.instance.nextPrayer();
                        if (next.time != null) {
                          // ignore: deprecated_member_use
                          await UnifiedAzanService().startCountdownNotification(
                            prayerName: next.name,
                            prayerTime: next.time!,
                          );
                        }
                      }
                      */
                    });
                  },
                ),
              ),
            );

            // بعد اختيار المدينة أو الرجوع، تحقق من وجود موقع
            if (LocationService.instance.hasLocation) {
              _goHome();
            }
            // إذا لم يختر شيئاً، يبقى في نفس الصفحة
          },

          // ── تخطي ────────────────────────────────────────────
          onSkip: () async {
            await LocationPermissionService.skipLocation();
            _goHome();
          },
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ✅ تنفيذ التنقل الأولي بعد وصول HomeScreen
  //     يُستدعى من _goHome بعد اكتمال الانتقال
  //     لا يعتمد على mounted لأن pendingAction محفوظ في widget
  // ════════════════════════════════════════════════════════════
  void _executeInitialNavigation() {
    final action = widget.pendingAction;
    if (action == null) {
      debugPrint('✅ No pending action to execute');
      return;
    }
    debugPrint('🚀 Executing initial pending navigation: $action');
    // تنفيذ فوري بدون تأخير إضافي
    _navigateFromAction(action);
  }

  // ════════════════════════════════════════════════════════════
  //  الانتقال المباشر للصفحة الرئيسية
  // ════════════════════════════════════════════════════════════
  void _goHome() {
    debugPrint('🔍 DEBUG: _goHome called');
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // ✅ قراءة الـ providers بشكل آمن — mounted قد يكون false إذا جاء الاستدعاء
    //    من onSkip بعد pushReplacement (الـ _AppRootState خرج من الشجرة)
    //    لذا نقرأها بشكل شرطي ونستمر في التنقل بغض النظر
    final homeNotifier = mounted ? ref.read(homeProvider.notifier) : null;
    final prayerManager = mounted
        ? ref.read(prayerNotificationManagerProvider)
        : null;

    // ✅ تحديث homeProvider إن أمكن
    homeNotifier?.refreshAfterCityChange();

    debugPrint('🔍 DEBUG: Pushing HomeScreen...');
    navigator.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );

    // ✅ الإصلاح: بعد اكتمال انتقال HomeScreen نفّذ التنقل المعلّق
    //    بدلاً من الاعتماد على mounted (الذي يكون false بعد pushReplacement)
    Future.delayed(const Duration(milliseconds: 100), () async {
      debugPrint('🔍 DEBUG: HomeScreen ready, executing pending navigation...');
      _executeInitialNavigation();

      prayerManager?.manualReschedule();

      // ⚠️ PHASE 4: Countdown disabled
      /*
      if (LocationService.instance.hasLocation) {
        final next = LocationService.instance.nextPrayer();
        if (next.time != null) {
          // ignore: deprecated_member_use
          await UnifiedAzanService().startCountdownNotification(
            prayerName: next.name,
            prayerTime: next.time!,
          );
        }
      }
      */
    });
  }
}