import 'package:hive_flutter/hive_flutter.dart';
import 'notification_permission_service.dart';

// ════════════════════════════════════════════════════════════════
//  AzanSettingsService — إعدادات الأذان الدائمة
//  يحفظ: أي صلوات مفعّل لها الأذان (دائم لكل الأيام)
// ════════════════════════════════════════════════════════════════

class AzanSettingsService {
  static const String _boxName = 'azan_settings_box';
  static const List<String> prayerIds = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  static Box? _box;

  /// تهيئة الخدمة (يتم استدعاؤها مرة واحدة عند بدء التطبيق)
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    
    // ✅ تعيين القيم الافتراضية - الأذان مفعّل افتراضياً
    for (final prayerId in prayerIds) {
      if (!_box!.containsKey(prayerId)) {
        // ✅ الأذان مفعّل افتراضياً لكل الصلوات
        await _box!.put(prayerId, true);
      }
    }
  }

  static Box get _getBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('AzanSettingsService not initialized. Call init() first.');
    }
    return _box!;
  }

  // ══════════════════════════════════════════════════════════════
  //  تفعيل/تعطيل الأذان لصلاة معينة
  // ══════════════════════════════════════════════════════════════

  /// تعيين حالة الأذان لصلاة معينة
  static Future<void> setAzanEnabled(String prayerId, bool enabled) async {
    await _getBox.put(prayerId, enabled);
  }

  /// التحقق من حالة الأذان لصلاة معينة
  static bool isAzanEnabled(String prayerId) {
    return _getBox.get(prayerId, defaultValue: true);
  }

  /// الحصول على جميع الصلوات المفعّل لها الأذان
  static Map<String, bool> getAllAzanSettings() {
    final Map<String, bool> settings = {};
    for (final prayerId in prayerIds) {
      settings[prayerId] = isAzanEnabled(prayerId);
    }
    return settings;
  }

  /// تفعيل الأذان لكل الصلوات
  static Future<void> enableAllAzan() async {
    for (final prayerId in prayerIds) {
      await setAzanEnabled(prayerId, true);
    }
  }

  /// تعطيل الأذان لكل الصلوات
  static Future<void> disableAllAzan() async {
    for (final prayerId in prayerIds) {
      await setAzanEnabled(prayerId, false);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  مسح البيانات
  // ══════════════════════════════════════════════════════════════

  /// إعادة تعيين إلى الإعدادات الافتراضية
  static Future<void> resetToDefaults() async {
    await enableAllAzan();
  }

  /// مسح جميع البيانات
  static Future<void> clearAll() async {
    await _getBox.clear();
    await resetToDefaults();
  }
}
