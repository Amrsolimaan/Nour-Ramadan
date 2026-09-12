import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// ════════════════════════════════════════════════════════════════
//  NotificationPermissionService — إدارة حالة أذونات الإشعارات
//  يحفظ: هل المستخدم سمح/رفض/لم يُسأل بعد
// ════════════════════════════════════════════════════════════════

class NotificationPermissionService {
  static const String _keyStatus = 'notification_permission_status';
  // القيم الممكنة: 'granted', 'denied', 'not_asked'

  // ══════════════════════════════════════════════════════════════
  //  الحصول على حالة الأذونات
  // ══════════════════════════════════════════════════════════════

  /// الحصول على حالة الأذونات المحفوظة
  static Future<String> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStatus) ?? 'not_asked';
  }

  /// حفظ حالة الأذونات
  static Future<void> setStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStatus, status);
  }

  /// التحقق من وجود أذونات الإشعارات
  static Future<bool> hasPermission() async {
    final status = await getStatus();
    return status == 'granted';
  }

  /// التحقق من أن المستخدم لم يُسأل بعد
  static Future<bool> shouldShowPermissionScreen() async {
    final status = await getStatus();
    return status == 'not_asked';
  }

  // ══════════════════════════════════════════════════════════════
  //  طلب الأذونات
  // ══════════════════════════════════════════════════════════════

  /// طلب أذونات الإشعارات من النظام
  static Future<bool> requestPermission() async {
    try {
      final granted = await NotificationService().requestPermissions();
      
      if (granted) {
        await setStatus('granted');
        return true;
      } else {
        await setStatus('denied');
        return false;
      }
    } catch (e) {
      await setStatus('denied');
      return false;
    }
  }

  /// تخطي طلب الأذونات (المستخدم اختار "تخطي")
  static Future<void> skipPermission() async {
    await setStatus('denied');
  }

  // ══════════════════════════════════════════════════════════════
  //  إعادة تعيين
  // ══════════════════════════════════════════════════════════════

  /// إعادة تعيين الحالة (للاختبار فقط)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStatus);
  }
}
