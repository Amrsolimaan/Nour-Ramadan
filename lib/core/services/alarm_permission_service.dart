import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════
//  AlarmPermissionService
//
//  يفحص إذنين ضروريين لعمل الأذان بشكل موثوق:
//  ① SCHEDULE_EXACT_ALARM  (Android 12+)
//  ② Battery Optimization  (كل الإصدارات)
//
//  الاستخدام: استدعِ checkAndPromptIfNeeded() مرة واحدة عند فتح
//  التطبيق (مثلاً في initState لشاشة prayer_times_screen أو main.dart)
//
//  ✅ لا يتعارض مع أي ملف موجود — ملف جديد مستقل تماماً
// ════════════════════════════════════════════════════════════════

class AlarmPermissionService {
  AlarmPermissionService._();
  static final instance = AlarmPermissionService._();

  static const _channel = MethodChannel('com.nour_ramadan/azan_service');
  
  // ✅ مفاتيح SharedPreferences لحفظ حالة العرض
  static const _keyBatteryDialogShown = 'battery_dialog_shown';
  static const _keyExactAlarmDialogShown = 'exact_alarm_dialog_shown';

  // ════════════════════════════════════════════════════════════
  //  الدالة الرئيسية — استدعِها مرة واحدة عند فتح التطبيق
  //  ✅ FIX #7: فحص دوري كل 6 ساعات بدلاً من مرة واحدة فقط
  // ════════════════════════════════════════════════════════════
  Future<void> checkAndPromptIfNeeded(BuildContext context) async {
    if (!Platform.isAndroid) return;

    // ✅ فحص دوري - ليس مرة واحدة فقط
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt('last_battery_check') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // فحص كل 6 ساعات بدلاً من مرة واحدة
    if (now - lastCheck < 6 * 60 * 60 * 1000) {
      return; // تم الفحص مؤخراً
    }
    
    await prefs.setInt('last_battery_check', now);

    // فحص الإذنين بالتوازي
    final results = await Future.wait([
      _hasExactAlarmPermission(),
      _isBatteryOptimizationDisabled(),
    ]);

    final hasExactAlarm      = results[0];
    final batteryOptDisabled = results[1];

    if (!context.mounted) return;

    // ① أهم شيء: إذن المنبه الدقيق (Android 12+)
    if (!hasExactAlarm) {
      await _showExactAlarmDialog(context);
      return;
    }

    // ② Battery Optimization - عرض Dialog في كل مرة حتى يُمنح الإعفاء
    if (!batteryOptDisabled) {
      await _showBatteryDialog(context);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  فحص الأذونات
  // ════════════════════════════════════════════════════════════
  Future<bool> _hasExactAlarmPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasExactAlarmPermission');
      return result ?? true;
    } catch (_) {
      return true; // في حالة الخطأ نفترض الإذن موجود
    }
  }

  Future<bool> _isBatteryOptimizationDisabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  إعادة تعيين حالة الحوارات (للاختبار أو إعادة العرض)
  // ════════════════════════════════════════════════════════════
  Future<void> resetDialogState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBatteryDialogShown);
    await prefs.remove(_keyExactAlarmDialogShown);
  }

  // ════════════════════════════════════════════════════════════
  //  ① حوار إذن المنبه الدقيق (Android 12+)
  // ════════════════════════════════════════════════════════════
  Future<void> _showExactAlarmDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF221A40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.alarm_off, color: Color(0xFFFF9800), size: 28),
            SizedBox(width: 10),
            Text(
              'إذن الأذان مُعطَّل',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: Color(0xFFF5F5DC),
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'لكي يعمل الأذان في الوقت الصحيح تماماً،\n'
          'يحتاج التطبيق إذن "ضبط المنبهات الدقيقة".\n\n'
          'اضغط "السماح" ثم فعّل الخيار من الإعدادات.',
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: Color(0xFFB8B8A0),
            height: 1.6,
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً', style: TextStyle(color: Color(0xFFB8B8A0))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _channel.invokeMethod('requestExactAlarmPermission');
              } catch (e) {
                debugPrint('Error requesting exact alarm: $e');
              }
            },
            child: const Text('السماح', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ② حوار Battery Optimization (Samsung / Xiaomi / Huawei)
  // ════════════════════════════════════════════════════════════
  Future<void> _showBatteryDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF221A40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.battery_alert, color: Color(0xFFFF9800), size: 28),
            SizedBox(width: 10),
            Text(
              'لضمان الأذان دائماً',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: Color(0xFFF5F5DC),
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'بعض الهواتف (Samsung، Xiaomi، Huawei) قد تُوقف '
          'الأذان لتوفير البطارية.\n\n'
          'اضغط "إعفاء" لضمان عمل الأذان بدون انقطاع '
          'حتى عند إغلاق التطبيق.',
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: Color(0xFFB8B8A0),
            height: 1.6,
          ),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تجاهل', style: TextStyle(color: Color(0xFFB8B8A0))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _channel.invokeMethod('requestBatteryExemption');
              } catch (e) {
                debugPrint('Error requesting battery exemption: $e');
              }
            },
            child: const Text('إعفاء', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ✅ FIX #7: فحص دوري كل ساعة - يُستدعى من main.dart
  // ════════════════════════════════════════════════════════════
  static Future<void> startPeriodicCheck(BuildContext context) async {
    if (!Platform.isAndroid) return;
    
    // فحص فوري
    await instance.checkAndPromptIfNeeded(context);
    
    // فحص كل ساعة
    Timer.periodic(const Duration(hours: 1), (timer) async {
      if (context.mounted) {
        await instance.checkAndPromptIfNeeded(context);
      } else {
        timer.cancel();
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  //  ✅ المرحلة 4: هل الجهاز من مصنّع معروف بقيود صارمة؟
  //  (Xiaomi/Vivo/Oppo/Huawei — يستخدمها BatteryPromptService لتقرير
  //  زر "منح الصلاحية" في الشاشة السياقية)
  // ════════════════════════════════════════════════════════════
  Future<bool> hasStrictOemRestrictions() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasStrictOemRestrictions');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ hasStrictOemRestrictions error: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  ✅ FIX #8: فتح إعدادات المصنّع الخاصة (Xiaomi/Vivo/Oppo)
  // ════════════════════════════════════════════════════════════
  Future<void> openManufacturerSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openManufacturerSettings');
    } catch (e) {
      debugPrint('❌ openManufacturerSettings error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  الحصول على تعليمات المصنّع
  // ════════════════════════════════════════════════════════════
  Future<String> getManufacturerInstructions() async {
    if (!Platform.isAndroid) return '';
    try {
      final result = await _channel.invokeMethod<String>('getManufacturerInstructions');
      return result ?? '';
    } catch (e) {
      debugPrint('❌ getManufacturerInstructions error: $e');
      return '';
    }
  }
}
