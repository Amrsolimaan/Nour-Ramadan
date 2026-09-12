import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'azan_service.dart';

// ════════════════════════════════════════════════════════════════
//  Background Azan Handler — معالج الأذان في الخلفية
// ════════════════════════════════════════════════════════════════
// ملاحظة: تشغيل الأذان في الخلفية يتطلب:
// 1. Foreground Service على Android
// 2. Background Audio على iOS
// 3. أو استخدام الإشعارات فقط مع صوت قصير

class BackgroundAzanHandler {
  static final BackgroundAzanHandler _instance = BackgroundAzanHandler._internal();
  factory BackgroundAzanHandler() => _instance;
  BackgroundAzanHandler._internal();

  final AzanService _azanService = AzanService();

  // ── معالجة الإشعار عند النقر عليه ──
  Future<void> handleNotificationTap(NotificationResponse response) async {
    debugPrint('Notification tapped: ${response.payload}');
    
    // إذا كان الإشعار خاص بالأذان، شغل الصوت
    if (response.payload != null && response.payload!.startsWith('azan_')) {
      final parts = response.payload!.split('_');
      if (parts.length >= 3) {
        final prayerName = parts[1];
        final muezzinFile = parts[2];
        
        await _azanService.playAzan(
          muezzinFileName: muezzinFile,
          prayerName: prayerName,
        );
      }
    }
  }

  // ── تهيئة المعالج ──
  Future<void> initialize() async {
    final FlutterLocalNotificationsPlugin notifications = 
        FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: handleNotificationTap,
    );
  }
}
