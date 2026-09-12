import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'unified_azan_service.dart';
import 'location_service.dart';
import 'notification_permission_service.dart';
import 'prefs_keys.dart';

// ════════════════════════════════════════════════════════════════
//  Boot Test Service — اختبار محاكاة إعادة التشغيل
//  للتحقق من عمل AzanBootReceiver
// ════════════════════════════════════════════════════════════════

class BootTestService {
  
  // ════════════════════════════════════════════════════════════
  //  محاكاة سيناريو إعادة التشغيل
  // ════════════════════════════════════════════════════════════
  static Future<BootTestResult> simulateBootScenario() async {
    debugPrint('🔄 Simulating boot scenario...');
    
    try {
      // 1. التحقق من المتطلبات الأساسية
      final hasLocation = LocationService.instance.hasLocation;
      final hasPermission = await NotificationPermissionService.hasPermission();
      
      if (!hasLocation || !hasPermission) {
        return BootTestResult(
          success: false,
          message: 'المتطلبات الأساسية غير متوفرة',
          details: 'Location: $hasLocation, Permission: $hasPermission',
          savedAzans: [],
        );
      }

      // 2. جدولة أذان تجريبي
      final testAzan = await _scheduleTestAzan();
      if (!testAzan.success) {
        return BootTestResult(
          success: false,
          message: 'فشل في جدولة الأذان التجريبي',
          details: testAzan.error ?? 'Unknown error',
          savedAzans: [],
        );
      }

      // 3. التحقق من حفظ البيانات
      final savedAzans = await _checkSavedAzanData();
      
      // 4. محاكاة قراءة البيانات (كما يفعل AzanBootReceiver)
      final bootReadResult = await _simulateBootReceiverRead();
      
      // 5. تنظيف البيانات التجريبية
      await _cleanupTestAzan();
      
      return BootTestResult(
        success: bootReadResult.success,
        message: bootReadResult.success 
          ? 'محاكاة إعادة التشغيل نجحت - الأذان سيعمل بعد إعادة التشغيل'
          : 'محاكاة إعادة التشغيل فشلت - قد لا يعمل الأذان بعد إعادة التشغيل',
        details: bootReadResult.details,
        savedAzans: savedAzans,
      );
      
    } catch (e) {
      return BootTestResult(
        success: false,
        message: 'خطأ في محاكاة إعادة التشغيل',
        details: e.toString(),
        savedAzans: [],
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  جدولة أذان تجريبي
  // ════════════════════════════════════════════════════════════
  static Future<TestAzanResult> _scheduleTestAzan() async {
    try {
      final azanService = UnifiedAzanService();
      final testTime = DateTime.now().add(const Duration(hours: 2));
      
      await azanService.scheduleAzan(
        id: 998, // ID تجريبي
        prayerName: 'اختبار إعادة التشغيل',
        prayerTime: testTime,
        muezzinFileName: 'azan_abdelbaset.mp3',
      );
      
      return TestAzanResult(success: true);
    } catch (e) {
      return TestAzanResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════
  //  التحقق من البيانات المحفوظة
  // ════════════════════════════════════════════════════════════
  static Future<List<SavedAzanData>> _checkSavedAzanData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    final azanKeys =
        keys.where((key) => key.startsWith(PrefKeys.azanPrefix)).toList();
    final savedAzans = <SavedAzanData>[];
    
    // تجميع البيانات حسب ID
    final azanIds = <int>{};
    for (final key in azanKeys) {
      final match = PrefKeys.azanKeyPattern.firstMatch(key);
      if (match != null) {
        azanIds.add(int.parse(match.group(1)!));
      }
    }
    
    for (final id in azanIds) {
      // ⚠️ الوقت يُحفظ كـ String (توافقاً مع getString في Kotlin) — لا getInt
      final time = int.tryParse(prefs.getString(PrefKeys.azanTime(id)) ?? '');
      final sound = prefs.getString(PrefKeys.azanSound(id));
      final prayer = prefs.getString(PrefKeys.azanPrayer(id));
      
      if (time != null && sound != null && prayer != null) {
        savedAzans.add(SavedAzanData(
          id: id,
          time: DateTime.fromMillisecondsSinceEpoch(time),
          sound: sound,
          prayer: prayer,
        ));
      }
    }
    
    return savedAzans;
  }

  // ════════════════════════════════════════════════════════════
  //  محاكاة قراءة AzanBootReceiver
  // ════════════════════════════════════════════════════════════
  static Future<BootReadResult> _simulateBootReceiverRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // محاكاة منطق AzanBootReceiver.readSavedAzanTimes()
      final ids = [100, 101, 102, 103, 104, 150, 998]; // إضافة ID التجريبي
      final foundAzans = <int>[];
      
      for (final id in ids) {
        // ⚠️ الوقت يُحفظ كـ String (توافقاً مع getString في Kotlin) — لا getInt
        final timeMillis =
            int.tryParse(prefs.getString(PrefKeys.azanTime(id)) ?? '');
        final soundFile = prefs.getString(PrefKeys.azanSound(id));
        final prayerName = prefs.getString(PrefKeys.azanPrayer(id));
        
        if (timeMillis != null && timeMillis > 0 && 
            soundFile != null && prayerName != null) {
          foundAzans.add(id);
        }
      }
      
      // التحقق من وجود الأذان التجريبي
      final testAzanFound = foundAzans.contains(998);
      
      return BootReadResult(
        success: testAzanFound,
        details: testAzanFound 
          ? 'AzanBootReceiver سيجد ${foundAzans.length} أذان محفوظ'
          : 'AzanBootReceiver لن يجد الأذان التجريبي - مشكلة في المفاتيح',
        foundAzanIds: foundAzans,
      );
      
    } catch (e) {
      return BootReadResult(
        success: false,
        details: 'خطأ في محاكاة قراءة البيانات: $e',
        foundAzanIds: [],
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  تنظيف الأذان التجريبي
  // ════════════════════════════════════════════════════════════
  static Future<void> _cleanupTestAzan() async {
    try {
      final azanService = UnifiedAzanService();
      await azanService.cancelAzan(998);
      debugPrint('✅ Test azan cleaned up');
    } catch (e) {
      debugPrint('⚠️ Error cleaning test azan: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  فحص البيانات المحفوظة الحالية
  // ════════════════════════════════════════════════════════════
  static Future<List<SavedAzanData>> getCurrentSavedAzans() async {
    return await _checkSavedAzanData();
  }

  // ════════════════════════════════════════════════════════════
  //  تنظيف جميع البيانات القديمة
  // ════════════════════════════════════════════════════════════
  static Future<void> cleanupOldAzanData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // ⚠️ المفاتيح القديمة = مزدوجة البادئة (flutter.azan_*) من قبل ترحيل v1.
      // المفاتيح الصحيحة الآن هي azan_* — يجب عدم حذفها إطلاقاً.
      final oldKeys = keys
          .where((key) => key.startsWith('flutter.${PrefKeys.azanPrefix}'))
          .toList();
      
      for (final key in oldKeys) {
        await prefs.remove(key);
      }
      
      debugPrint('✅ Cleaned up ${oldKeys.length} old azan keys');
    } catch (e) {
      debugPrint('⚠️ Error cleaning old data: $e');
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  Data Models
// ════════════════════════════════════════════════════════════════

class BootTestResult {
  final bool success;
  final String message;
  final String details;
  final List<SavedAzanData> savedAzans;
  
  BootTestResult({
    required this.success,
    required this.message,
    required this.details,
    required this.savedAzans,
  });
}

class TestAzanResult {
  final bool success;
  final String? error;
  
  TestAzanResult({required this.success, this.error});
}

class BootReadResult {
  final bool success;
  final String details;
  final List<int> foundAzanIds;
  
  BootReadResult({
    required this.success,
    required this.details,
    required this.foundAzanIds,
  });
}

class SavedAzanData {
  final int id;
  final DateTime time;
  final String sound;
  final String prayer;
  
  SavedAzanData({
    required this.id,
    required this.time,
    required this.sound,
    required this.prayer,
  });
  
  bool get isInFuture => time.isAfter(DateTime.now());
  
  String get timeString => 
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}