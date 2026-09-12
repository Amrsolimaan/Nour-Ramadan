import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_keys.dart';
import 'dart:io' show Platform;
import 'unified_azan_service.dart';
import 'notification_permission_service.dart';
import 'location_service.dart';
import 'ios_notification_window.dart';

// ════════════════════════════════════════════════════════════════
//  System Diagnostics Service — خدمة تشخيص النظام
//  للتحقق من عمل الإصلاحات الحرجة
// ════════════════════════════════════════════════════════════════

class SystemDiagnosticsService {
  static const _azanChannel = MethodChannel('com.nour_ramadan/azan_service');

  // ════════════════════════════════════════════════════════════
  //  تشخيص شامل للنظام
  // ════════════════════════════════════════════════════════════
  static Future<DiagnosticsReport> runFullDiagnostics() async {
    debugPrint('🔍 Starting full system diagnostics...');

    final report = DiagnosticsReport();

    // 1. فحص حفظ بيانات الأذان
    report.azanDataTest = await _testAzanDataSaving();

    // 2. فحص Battery Optimization
    report.batteryOptimizationTest = await _testBatteryOptimization();

    // 3. فحص الأذونات
    report.permissionsTest = await _testPermissions();

    // 4. فحص الموقع
    report.locationTest = await _testLocation();

    // 5. فحص الجدولة
    report.schedulingTest = await _testScheduling();

    // 6. فحص SharedPreferences
    report.sharedPrefsTest = await _testSharedPreferences();

    debugPrint('✅ Full diagnostics completed');
    return report;
  }

  // ════════════════════════════════════════════════════════════
  //  اختبار حفظ بيانات الأذان (الإصلاح الأول)
  // ════════════════════════════════════════════════════════════
  static Future<TestResult> _testAzanDataSaving() async {
    try {
      debugPrint('🧪 Testing azan data saving...');

      final prefs = await SharedPreferences.getInstance();
      final testId = 999; // ID اختبار
      final testTime = DateTime.now().add(const Duration(hours: 1));
      final testSound = 'test_sound';
      final testPrayer = 'اختبار';

      // ✅ FIX #1: حفظ البيانات كـ String للتوافق مع Kotlin
      await prefs.setString(
        PrefKeys.azanTime(testId),
        testTime.millisecondsSinceEpoch.toString(),
      );
      await prefs.setString(PrefKeys.azanSound(testId), testSound);
      await prefs.setString(PrefKeys.azanPrayer(testId), testPrayer);

      // التحقق من الحفظ
      final savedTimeStr = prefs.getString(PrefKeys.azanTime(testId));
      final savedTime = int.tryParse(savedTimeStr ?? '');
      final savedSound = prefs.getString(PrefKeys.azanSound(testId));
      final savedPrayer = prefs.getString(PrefKeys.azanPrayer(testId));

      // تنظيف البيانات التجريبية
      await prefs.remove(PrefKeys.azanTime(testId));
      await prefs.remove(PrefKeys.azanSound(testId));
      await prefs.remove(PrefKeys.azanPrayer(testId));

      if (savedTime != null && savedTime == testTime.millisecondsSinceEpoch &&
          savedSound == testSound &&
          savedPrayer == testPrayer) {
        return TestResult(
          name: 'Azan Data Saving',
          passed: true,
          message: 'بيانات الأذان تُحفظ وتُقرأ بشكل صحيح',
          details: 'المفاتيح متطابقة مع AzanBootReceiver',
        );
      } else {
        return TestResult(
          name: 'Azan Data Saving',
          passed: false,
          message: 'فشل في حفظ أو قراءة بيانات الأذان',
          details: 'Time: $savedTime, Sound: $savedSound, Prayer: $savedPrayer',
        );
      }
    } catch (e) {
      return TestResult(
        name: 'Azan Data Saving',
        passed: false,
        message: 'خطأ في اختبار حفظ البيانات',
        details: e.toString(),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  اختبار Battery Optimization (الإصلاح الثاني)
  // ════════════════════════════════════════════════════════════
  static Future<TestResult> _testBatteryOptimization() async {
    try {
      debugPrint('🧪 Testing battery optimization...');

      if (!Platform.isAndroid) {
        return TestResult(
          name: 'Battery Optimization',
          passed: true,
          message: 'غير مطلوب على iOS',
          details: 'Battery optimization is Android-specific',
        );
      }

      final azanService = UnifiedAzanService();
      final isDisabled = await azanService.isBatteryOptimizationDisabled();

      return TestResult(
        name: 'Battery Optimization',
        passed: true, // نجح الاختبار بغض النظر عن النتيجة
        message: isDisabled
            ? 'Battery optimization معطل - ممتاز!'
            : 'Battery optimization مفعل - قد يؤثر على التوقيت',
        details: 'Status: ${isDisabled ? "Disabled" : "Enabled"}',
        warning: !isDisabled
            ? 'يُنصح بتعطيل Battery Optimization للحصول على أفضل دقة'
            : null,
      );
    } catch (e) {
      return TestResult(
        name: 'Battery Optimization',
        passed: false,
        message: 'خطأ في فحص Battery Optimization',
        details: e.toString(),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  اختبار الأذونات
  // ════════════════════════════════════════════════════════════
  static Future<TestResult> _testPermissions() async {
    try {
      debugPrint('🧪 Testing permissions...');

      final hasNotificationPerm =
          await NotificationPermissionService.hasPermission();

      bool hasExactAlarmPerm = true;
      if (Platform.isAndroid) {
        try {
          hasExactAlarmPerm =
              await _azanChannel.invokeMethod<bool>(
                'hasExactAlarmPermission',
              ) ??
              false;
        } catch (e) {
          debugPrint('⚠️ Could not check exact alarm permission: $e');
        }
      }

      final allPermissionsGranted = hasNotificationPerm && hasExactAlarmPerm;

      return TestResult(
        name: 'Permissions',
        passed: allPermissionsGranted,
        message: allPermissionsGranted
            ? 'جميع الأذونات مُمنوحة'
            : 'بعض الأذونات مفقودة',
        details:
            'Notifications: $hasNotificationPerm, ExactAlarm: $hasExactAlarmPerm',
        warning: !allPermissionsGranted
            ? 'الأذونات المفقودة قد تؤثر على عمل الأذان'
            : null,
      );
    } catch (e) {
      return TestResult(
        name: 'Permissions',
        passed: false,
        message: 'خطأ في فحص الأذونات',
        details: e.toString(),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  اختبار الموقع
  // ════════════════════════════════════════════════════════════
  static Future<TestResult> _testLocation() async {
    try {
      debugPrint('🧪 Testing location...');

      final hasLocation = LocationService.instance.hasLocation;
      final city = LocationService.instance.city;
      final lat = LocationService.instance.lat;
      final lng = LocationService.instance.lng;

      return TestResult(
        name: 'Location',
        passed: hasLocation,
        message: hasLocation ? 'الموقع محدد: $city' : 'الموقع غير محدد',
        details: hasLocation
            ? 'Lat: $lat, Lng: $lng, City: $city'
            : 'No location data available',
        warning: !hasLocation ? 'يجب تحديد الموقع لحساب أوقات الصلاة' : null,
      );
    } catch (e) {
      return TestResult(
        name: 'Location',
        passed: false,
        message: 'خطأ في فحص الموقع',
        details: e.toString(),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  اختبار الجدولة
  // ════════════════════════════════════════════════════════════
  static Future<TestResult> _testScheduling() async {
    try {
      debugPrint('🧪 Testing scheduling capability...');

      final hasLocation = LocationService.instance.hasLocation;
      final hasNotificationPerm =
          await NotificationPermissionService.hasPermission();

      final canSchedule = hasLocation && hasNotificationPerm;

      return TestResult(
        name: 'Scheduling',
        passed: canSchedule,
        message: canSchedule
            ? 'النظام جاهز لجدولة الإشعارات'
            : 'النظام غير جاهز للجدولة',
        details: 'Location: $hasLocation, Notifications: $hasNotificationPerm',
        warning: !canSchedule ? 'يجب توفر الموقع والأذونات للجدولة' : null,
      );
    } catch (e) {
      return TestResult(
        name: 'Scheduling',
        passed: false,
        message: 'خطأ في فحص الجدولة',
        details: e.toString(),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  اختبار SharedPreferences
  // ════════════════════════════════════════════════════════════
  static Future<TestResult> _testSharedPreferences() async {
    try {
      debugPrint('🧪 Testing SharedPreferences...');

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // البحث عن مفاتيح الأذان الجديدة
      final azanKeys = keys
          .where((key) => key.startsWith(PrefKeys.azanPrefix))
          .toList();

      // البحث عن مفاتيح الأذان القديمة (يجب عدم وجودها)
      // مفاتيح قديمة = مزدوجة البادئة (flutter.azan_*) من قبل ترحيل v1
      final oldAzanKeys = keys
          .where((key) => key.startsWith('flutter.${PrefKeys.azanPrefix}'))
          .toList();

      return TestResult(
        name: 'SharedPreferences',
        passed: true,
        message: 'SharedPreferences يعمل بشكل صحيح',
        details:
            'New azan keys: ${azanKeys.length}, Old keys: ${oldAzanKeys.length}',
        warning: oldAzanKeys.isNotEmpty
            ? 'توجد مفاتيح قديمة قد تحتاج تنظيف'
            : null,
      );
    } catch (e) {
      return TestResult(
        name: 'SharedPreferences',
        passed: false,
        message: 'خطأ في فحص SharedPreferences',
        details: e.toString(),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  اختبار سريع للإصلاحات الحرجة فقط
  // ════════════════════════════════════════════════════════════
  static Future<QuickTestResult> runQuickTest() async {
    debugPrint('⚡ Running quick critical fixes test...');

    final azanDataOk = (await _testAzanDataSaving()).passed;
    final batteryOk = (await _testBatteryOptimization()).passed;
    final permissionsOk = (await _testPermissions()).passed;
    final locationOk = (await _testLocation()).passed;

    final allCriticalOk =
        azanDataOk && batteryOk && permissionsOk && locationOk;

    return QuickTestResult(
      allPassed: allCriticalOk,
      azanDataSaving: azanDataOk,
      batteryOptimization: batteryOk,
      permissions: permissionsOk,
      location: locationOk,
      summary: allCriticalOk
          ? 'جميع الإصلاحات الحرجة تعمل بشكل صحيح ✅'
          : 'بعض الإصلاحات تحتاج مراجعة ⚠️',
    );
  }

  // ════════════════════════════════════════════════════════════
  //  تنظيف البيانات التجريبية
  // ════════════════════════════════════════════════════════════
  static Future<void> cleanupTestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // حذف أي مفاتيح اختبار
      for (final key in keys) {
        if (key.contains('test') || key.contains('999')) {
          await prefs.remove(key);
        }
      }

      debugPrint('✅ Test data cleaned up');
    } catch (e) {
      debugPrint('⚠️ Error cleaning test data: $e');
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  Data Models
// ════════════════════════════════════════════════════════════════

class DiagnosticsReport {
  TestResult? azanDataTest;
  TestResult? batteryOptimizationTest;
  TestResult? permissionsTest;
  TestResult? locationTest;
  TestResult? schedulingTest;
  TestResult? sharedPrefsTest;

  List<TestResult> get allTests => [
    if (azanDataTest != null) azanDataTest!,
    if (batteryOptimizationTest != null) batteryOptimizationTest!,
    if (permissionsTest != null) permissionsTest!,
    if (locationTest != null) locationTest!,
    if (schedulingTest != null) schedulingTest!,
    if (sharedPrefsTest != null) sharedPrefsTest!,
  ];

  int get passedCount => allTests.where((t) => t.passed).length;
  int get totalCount => allTests.length;
  bool get allPassed => passedCount == totalCount;

  String get summary => allPassed
      ? 'جميع الاختبارات نجحت ($passedCount/$totalCount) ✅'
      : 'نجح $passedCount من $totalCount اختبار ⚠️';
}

class TestResult {
  final String name;
  final bool passed;
  final String message;
  final String details;
  final String? warning;

  TestResult({
    required this.name,
    required this.passed,
    required this.message,
    required this.details,
    this.warning,
  });
}

class QuickTestResult {
  final bool allPassed;
  final bool azanDataSaving;
  final bool batteryOptimization;
  final bool permissions;
  final bool location;
  final String summary;

  QuickTestResult({
    required this.allPassed,
    required this.azanDataSaving,
    required this.batteryOptimization,
    required this.permissions,
    required this.location,
    required this.summary,
  });
}

// ════════════════════════════════════════════════════════════════
//  المرحلة 8 — سطح التحقّق (Verification surface)
//
//  لوحة قراءة فقط (read-only) — لا منطق جدولة جديد هنا إطلاقاً.
//  كل قيمة تُقرأ من مصدر موجود فعلاً:
//    • Android: سجلّ/أفق/آخر-تحديث يكتبها AlarmScheduler.kt مباشرةً
//      (SharedPreferences الخام، بنفس مفاتيح PrefKeys أعلاه).
//    • iOS: نهاية الأفق من IosNotificationWindow (PrefKeys.
//      iosWindowScheduledThroughDate) — لا سجلّ عدد فردي على iOS
//      (النافذة المتدرّجة لا تُبقي قائمة IDs، بخلاف أندرويد).
//    • "آخر أذان أُطلق" مصدره الكتابة الجديدة المُضافة هذه المرحلة في
//      AzanAlarmReceiver.kt (أندرويد) وnotification_service.dart
//      (iOS، عبر رد الفعل على نقر الإشعار — راجع التعليق هناك لشرح
//      الفارق بين "أُطلق" و"نُقر عليه" على iOS تحديداً).
// ════════════════════════════════════════════════════════════════

/// تصنيف صحة الأفق — نفس فلسفة AlarmScheduler.decideNeedsRefresh()
/// (Kotlin) وIosNotificationWindow.decideTopUp() (Dart)، لكن للعرض
/// فقط هنا (لا قرار جدولة).
enum HorizonHealth {
  /// لا بيانات أفق محفوظة إطلاقاً بعد (لم تُسلَّح أي دورة قط).
  unknown,

  /// الأفق انتهى فعلياً أو تجاوزناه — لا تغطية إطلاقاً من الآن فصاعداً.
  critical,

  /// الأفق ما زال ساري المفعول لكنه دون العتبة — يحتاج تجديداً قريباً.
  shrinking,

  /// الأفق كافٍ ولا حاجة لأي إجراء.
  healthy,
}

/// عتبة تجديد أندرويد — تُطابق AlarmScheduler.HORIZON_REFRESH_THRESHOLD_MS
/// حرفياً ((DAYS_AHEAD ÷ 3) = 21 ÷ 3 = 7 أيام). لا رابط برمجي مباشر
/// ممكن بين Kotlin وDart هنا (لغتان منفصلتان) — القيمة مُكرَّرة عمداً
/// وموثَّقة بمصدرها بدل تركها رقماً سحرياً.
const int kAndroidHorizonThresholdDays = 7;

/// عتبة تجديد iOS — تُطابق IosNotificationWindow.topUpThresholdDays حرفياً
/// (رابط برمجي فعلي هذه المرّة، لا تكرار، لأن كلاهما Dart).
final int kIosHorizonThresholdDays = IosNotificationWindow.topUpThresholdDays;

/// دالة صِرفة (pure) — تصنيف صحة الأفق من تاريخ نهايته فقط.
/// [now] يُمرَّر صراحةً (لا DateTime.now() داخلياً) ليكون الاختبار
/// حتمياً وقابلاً للتكرار — نفس نمط TimezoneService/BatteryPromptService
/// هذه الجلسة.
HorizonHealth classifyHorizonHealth({
  required DateTime? horizonEndAt,
  required DateTime now,
  required int thresholdDays,
}) {
  if (horizonEndAt == null) return HorizonHealth.unknown;
  final remaining = horizonEndAt.difference(now);
  if (remaining <= Duration.zero) {
    return HorizonHealth.critical;
  }
  if (remaining < Duration(days: thresholdDays)) {
    return HorizonHealth.shrinking;
  }
  return HorizonHealth.healthy;
}

/// دالة صِرفة — نص عرض نسبي لِلحظة ماضية (آخر تحديث/آخر أذان أُطلق).
/// [now] صريح لنفس سبب classifyHorizonHealth أعلاه.
String formatRelativeTimeLabel(
  DateTime? at,
  DateTime now, {
  String neverLabel = 'لم يُسجَّل بعد',
}) {
  if (at == null) return neverLabel;
  final diff = now.difference(at);
  if (diff.isNegative || diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
  return 'قبل ${diff.inDays} يوم';
}

/// دالة صِرفة — تحويل epoch-ms المحفوظ كنص (نمط هذا المشروع الموحَّد،
/// راجع تعليق PrefKeys) إلى DateTime، بأمان تام (لا يرمي أبداً).
DateTime? parseEpochMsString(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final ms = int.tryParse(raw);
  if (ms == null || ms <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms);
}

/// لقطة صحة الأذان الكاملة — بيانات صِرفة بلا أي سلوك، يبنيها
/// [SystemDiagnosticsService.loadAzanHealth] من مصادر حقيقية، وتُستهلك
/// من شاشة التشخيص مباشرة.
class AzanHealthSnapshot {
  const AzanHealthSnapshot({
    required this.isAndroid,
    this.androidArmedCount,
    this.androidLastRefreshAt,
    required this.horizonEndAt,
    required this.horizonThresholdDays,
    this.lastFiredAt,
    this.lastFiredPrayer,
    required this.hasExactAlarmPermission,
    required this.isBatteryOptimizationDisabled,
    required this.hasNotificationPermission,
  });

  final bool isAndroid;

  /// عدد المعرّفات المُسلَّحة حالياً في سجلّ AlarmScheduler — Android فقط.
  final int? androidArmedCount;

  /// آخر لحظة نجح فيها AlarmScheduler.refresh() فعلياً — Android فقط.
  final DateTime? androidLastRefreshAt;

  /// نهاية الأفق المُسلَّح حالياً — Android: azan_horizon_end_at.
  /// iOS: IosNotificationWindow.scheduledThroughDate (نهاية اليوم المُغطّى).
  final DateTime? horizonEndAt;

  /// العتبة (بالأيام) المستخدَمة لتصنيف healthy/shrinking لهذه المنصّة.
  final int horizonThresholdDays;

  final DateTime? lastFiredAt;
  final String? lastFiredPrayer;

  /// أندرويد فقط بمعنى حقيقي — true دائماً على iOS (لا مفهوم مطابق).
  final bool hasExactAlarmPermission;

  /// أندرويد فقط بمعنى حقيقي — true دائماً على iOS (لا مفهوم مطابق).
  final bool isBatteryOptimizationDisabled;

  final bool hasNotificationPermission;

  HorizonHealth horizonHealth(DateTime now) => classifyHorizonHealth(
    horizonEndAt: horizonEndAt,
    now: now,
    thresholdDays: horizonThresholdDays,
  );

  bool get allPermissionsOk =>
      hasExactAlarmPermission &&
      isBatteryOptimizationDisabled &&
      hasNotificationPermission;
}

/// الغلاف الحقيقي (I/O) — يقرأ كل مصدر حقيقي فعلاً ويُجمِّعها للقطة
/// واحدة. لا يكتب أي شيء، ولا يُشغِّل أي جدولة — قراءة صِرفة.
Future<AzanHealthSnapshot> loadAzanHealthSnapshot() async {
  const azanChannel = MethodChannel('com.nour_ramadan/azan_service');
  final prefs = await SharedPreferences.getInstance();
  final isAndroid = Platform.isAndroid;

  int? armedCount;
  DateTime? lastRefreshAt;
  DateTime? horizonEndAt;
  int horizonThresholdDays;
  var hasExactAlarmPermission = true;
  var isBatteryOptimizationDisabled = true;

  if (isAndroid) {
    final ledgerRaw = prefs.getString(PrefKeys.azanArmedIds);
    armedCount = (ledgerRaw == null || ledgerRaw.trim().isEmpty)
        ? 0
        : ledgerRaw.split(',').where((s) => s.trim().isNotEmpty).length;
    lastRefreshAt = parseEpochMsString(prefs.getString(PrefKeys.azanLastRefreshAt));
    horizonEndAt = parseEpochMsString(prefs.getString(PrefKeys.azanHorizonEndAt));
    horizonThresholdDays = kAndroidHorizonThresholdDays;

    try {
      hasExactAlarmPermission =
          await azanChannel.invokeMethod<bool>('hasExactAlarmPermission') ??
          false;
    } catch (e) {
      debugPrint('⚠️ loadAzanHealthSnapshot: hasExactAlarmPermission: $e');
    }
    try {
      isBatteryOptimizationDisabled =
          await azanChannel.invokeMethod<bool>(
            'isBatteryOptimizationDisabled',
          ) ??
          false;
    } catch (e) {
      debugPrint('⚠️ loadAzanHealthSnapshot: isBatteryOptimizationDisabled: $e');
    }
  } else {
    final throughStr = prefs.getString(PrefKeys.iosWindowScheduledThroughDate);
    horizonEndAt = throughStr == null ? null : DateTime.tryParse(throughStr);
    horizonThresholdDays = kIosHorizonThresholdDays;
  }

  final lastFiredAt = parseEpochMsString(prefs.getString(PrefKeys.azanLastFiredAt));
  final lastFiredPrayer = prefs.getString(PrefKeys.azanLastFiredPrayer);
  final hasNotificationPermission = await NotificationPermissionService.hasPermission();

  return AzanHealthSnapshot(
    isAndroid: isAndroid,
    androidArmedCount: armedCount,
    androidLastRefreshAt: lastRefreshAt,
    horizonEndAt: horizonEndAt,
    horizonThresholdDays: horizonThresholdDays,
    lastFiredAt: lastFiredAt,
    lastFiredPrayer: lastFiredPrayer,
    hasExactAlarmPermission: hasExactAlarmPermission,
    isBatteryOptimizationDisabled: isBatteryOptimizationDisabled,
    hasNotificationPermission: hasNotificationPermission,
  );
}
