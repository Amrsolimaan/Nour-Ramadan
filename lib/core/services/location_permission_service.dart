import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

// ════════════════════════════════════════════════════════════════
//  LocationPermissionService — إدارة حالة أذونات الموقع
//  يحفظ: هل المستخدم حدد موقعه/تخطى
// ════════════════════════════════════════════════════════════════

class LocationPermissionService {
  static const String _keyAsked = 'location_permission_asked';
  static const String _keySet = 'location_permission_set';

  // ══════════════════════════════════════════════════════════════
  //  التحقق من حالة الموقع
  // ══════════════════════════════════════════════════════════════

  /// هل يجب عرض صفحة طلب الموقع؟
  static Future<bool> shouldShowLocationScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool(_keyAsked) ?? false;
    
    // إذا لم يُسأل من قبل، اعرض الصفحة
    if (!asked) return true;
    
    // ✅ إذا سُئل من قبل (سواء حدد موقع أو تخطى)، لا تعرض الصفحة مرة أخرى
    // المستخدم اتخذ قراره بالفعل
    return false;
  }

  /// هل المستخدم حدد موقعه؟
  static Future<bool> hasLocationPermission() async {
    // التحقق من وجود موقع فعلي في LocationService
    return LocationService.instance.hasLocation;
  }

  // ══════════════════════════════════════════════════════════════
  //  حفظ الحالة
  // ══════════════════════════════════════════════════════════════

  /// حفظ أن المستخدم حدد موقعه بنجاح
  static Future<void> markLocationAsSet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAsked, true);
    await prefs.setBool(_keySet, true);
  }

  /// حفظ أن المستخدم تخطى تحديد الموقع
  static Future<void> skipLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAsked, true);
    await prefs.setBool(_keySet, false);
  }

  // ══════════════════════════════════════════════════════════════
  //  إعادة تعيين (للاختبار)
  // ══════════════════════════════════════════════════════════════

  /// إعادة تعيين الحالة (للاختبار فقط)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAsked);
    await prefs.remove(_keySet);
  }
}
