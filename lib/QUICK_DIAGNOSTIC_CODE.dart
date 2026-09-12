// ════════════════════════════════════════════════════════════════
//  كود التشخيص السريع - نسخ ولصق مباشرة
//  استخدم هذا الكود للتحقق من حالة نظام الإشعارات
// ════════════════════════════════════════════════════════════════

import 'package:flutter/services.dart';
import 'package:nour_ramadan/core/services/location_service.dart';
import 'package:nour_ramadan/core/services/prefs_keys.dart';
import 'package:nour_ramadan/core/services/notification_permission_service.dart';
import 'package:nour_ramadan/core/services/notification_service.dart';
import 'package:nour_ramadan/core/services/unified_azan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


// ════════════════════════════════════════════════════════════════
//  الطريقة 1: تشخيص سريع (5 دقائق)
// ════════════════════════════════════════════════════════════════

Future<void> quickDiagnostics() async {
  print('═══════════════════════════════════════');
  print('🔍 Quick Diagnostics - نظام الإشعارات');
  print('═══════════════════════════════════════');
  
  // 1. الموقع الجغرافي
  final hasLocation = LocationService.instance.hasLocation;
  final city = LocationService.instance.city ?? 'غير محدد';
  print('📍 الموقع: ${hasLocation ? "✅" : "❌"} $city');
  if (!hasLocation) {
    print('   ⚠️ المشكلة: لم يتم تحديد موقع - لن تعمل الإشعارات!');
    print('   💡 الحل: اذهب للإعدادات → الموقع → حدد مدينتك');
  }
  
  // 2. أذونات الإشعارات
  final hasNotifPerm = await NotificationPermissionService.hasPermission();
  print('🔔 أذونات الإشعارات: ${hasNotifPerm ? "✅" : "❌"}');
  if (!hasNotifPerm) {
    print('   ⚠️ المشكلة: لم يتم منح أذونات الإشعارات');
    print('   💡 الحل: إعدادات الهاتف → التطبيقات → نور رمضان → الأذونات → الإشعارات');
  }
  
  // 3. أذونات المنبهات الدقيقة (Android 12+)
  try {
    const azanChannel = MethodChannel('com.nour_ramadan/azan_service');  // ← تصحيح
    final hasAlarmPerm = await azanChannel.invokeMethod<bool>('hasExactAlarmPermission');
    print('⏰ أذونات المنبهات الدقيقة: ${hasAlarmPerm == true ? "✅" : "❌"}');
    if (hasAlarmPerm != true) {
      print('   ⚠️ المشكلة: لم يتم منح إذن المنبهات الدقيقة');
      print('   💡 الحل: سيتم طلب الإذن تلقائياً عند بدء التطبيق');
    }
  } catch (e) {
    print('⏰ أذونات المنبهات الدقيقة: ❌ خطأ في الفحص');
    print('   Error: $e');
  }
  
  // 4. إعفاء من توفير الطاقة
  try {
    final batteryOk = await UnifiedAzanService().isBatteryOptimizationDisabled();
    print('🔋 إعفاء من توفير الطاقة: ${batteryOk ? "✅" : "❌"}');
    if (!batteryOk) {
      print('   ⚠️ المشكلة: التطبيق خاضع لتوفير الطاقة - قد يؤثر على دقة الأذان');
      print('   💡 الحل: إعدادات الهاتف → البطارية → إعفاء التطبيقات → نور رمضان');
    }
  } catch (e) {
    print('🔋 إعفاء من توفير الطاقة: ❌ خطأ في الفحص');
    print('   Error: $e');
  }
  
  // 5. الإشعارات المجدولة حالياً
  try {
    final pending = await NotificationService().getPendingNotifications();
    print('📋 الإشعارات المجدولة: ${pending.length}');
    if (pending.isEmpty) {
      print('   ⚠️ لا توجد إشعارات مجدولة حالياً');
    } else {
      for (final n in pending) {
        print('   - ID ${n.id}: ${n.title ?? "بدون عنوان"}');
      }
    }
  } catch (e) {
    print('📋 الإشعارات المجدولة: ❌ خطأ في القراءة');
    print('   Error: $e');
  }
  
  // 6. بيانات الأذان المحفوظة
  try {
    final prefs = await SharedPreferences.getInstance();
    final azanIds = [100, 101, 102, 103, 104, 150];
    final azanNames = {
      100: 'الفجر',
      101: 'الظهر',
      102: 'العصر',
      103: 'المغرب',
      104: 'العشاء',
      150: 'فجر الغد',
    };
    
    int savedCount = 0;
    print('💾 بيانات الأذان المحفوظة:');
    for (final id in azanIds) {
      // ⚠️ الوقت محفوظ كـ String (توافقاً مع getString في Kotlin)
      final timeStr = prefs.getString(PrefKeys.azanTime(id));
      final time = int.tryParse(timeStr ?? '');
      if (time != null) {
        savedCount++;
        final sound = prefs.getString(PrefKeys.azanSound(id));
        final dateTime = DateTime.fromMillisecondsSinceEpoch(time);
        print('   - ${azanNames[id]}: ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} ($sound)');
      }
    }
    
    if (savedCount == 0) {
      print('   ⚠️ لا توجد بيانات أذان محفوظة');
      print('   💡 هذا طبيعي إذا لم يتم جدولة الأذانات بعد');
    } else {
      print('   ✅ تم حفظ $savedCount أذان');
    }
  } catch (e) {
    print('💾 بيانات الأذان المحفوظة: ❌ خطأ في القراءة');
    print('   Error: $e');
  }
  
  print('═══════════════════════════════════════');
  print('');
  
  // الخلاصة
  print('📊 الخلاصة:');
  if (hasLocation && hasNotifPerm) {
    print('✅ النظام جاهز - يجب أن تعمل الإشعارات');
  } else {
    print('❌ هناك مشاكل تمنع عمل الإشعارات:');
    if (!hasLocation) print('   - الموقع غير محدد');
    if (!hasNotifPerm) print('   - أذونات الإشعارات مرفوضة');
  }
  print('═══════════════════════════════════════');
}


// ════════════════════════════════════════════════════════════════
//  الطريقة 2: اختبار الجدولة (10 دقائق)
// ════════════════════════════════════════════════════════════════

Future<void> testScheduling() async {
  print('═══════════════════════════════════════');
  print('🧪 Testing Scheduling - اختبار الجدولة');
  print('═══════════════════════════════════════');
  
  // اختبار 1: إشعار عادي (بعد دقيقة واحدة)
  print('📝 اختبار 1: إشعار عادي (بعد دقيقة واحدة)');
  try {
    final testTime = DateTime.now().add(Duration(minutes: 1));
    await NotificationService().schedulePrayerReminder(
      id: 9999,
      prayerName: 'اختبار الإشعار',
      prayerTime: testTime,
    );
    print('✅ تم الجدولة للوقت: ${testTime.hour}:${testTime.minute.toString().padLeft(2, '0')}');
    
    // التحقق من الجدولة
    await Future.delayed(Duration(seconds: 2));
    final pending = await NotificationService().getPendingNotifications();
    final found = pending.any((n) => n.id == 9999);
    
    if (found) {
      print('✅ تم التحقق: الإشعار موجود في قائمة الانتظار');
      print('⏳ انتظر دقيقة واحدة لرؤية الإشعار...');
    } else {
      print('❌ فشل التحقق: الإشعار غير موجود في قائمة الانتظار');
      print('   💡 قد تكون هناك مشكلة في أذونات الإشعارات');
    }
  } catch (e) {
    print('❌ خطأ في جدولة الإشعار: $e');
  }
  
  print('');
  
  // اختبار 2: أذان (بعد دقيقتين)
  print('📝 اختبار 2: أذان (بعد دقيقتين)');
  try {
    final testTime = DateTime.now().add(Duration(minutes: 2));
    await UnifiedAzanService().scheduleAzan(
      id: 9998,
      prayerName: 'اختبار الأذان',
      prayerTime: testTime,
      muezzinFileName: 'azan_abdelbaset',
    );
    print('✅ تم الجدولة للوقت: ${testTime.hour}:${testTime.minute.toString().padLeft(2, '0')}');
    
    // التحقق من حفظ البيانات
    await Future.delayed(Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final savedTime =
        int.tryParse(prefs.getString(PrefKeys.azanTime(9998)) ?? '');
    
    if (savedTime != null) {
      print('✅ تم التحقق: البيانات محفوظة في SharedPreferences');
      final savedSound = prefs.getString(PrefKeys.azanSound(9998));
      final savedPrayer = prefs.getString(PrefKeys.azanPrayer(9998));
      final dateTime = DateTime.fromMillisecondsSinceEpoch(savedTime);
      print('   - الوقت: ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}');
      print('   - الصوت: $savedSound');
      print('   - الصلاة: $savedPrayer');
      print('⏳ انتظر دقيقتين لسماع الأذان...');
    } else {
      print('❌ فشل التحقق: البيانات غير محفوظة');
      print('   💡 قد تكون هناك مشكلة في AzanPlugin أو AlarmManager');
    }
  } catch (e) {
    print('❌ خطأ في جدولة الأذان: $e');
  }
  
  print('');
  print('═══════════════════════════════════════');
  print('⏳ انتظر الآن:');
  print('   - دقيقة واحدة → إشعار عادي');
  print('   - دقيقتان → أذان صوتي');
  print('═══════════════════════════════════════');
}

// ════════════════════════════════════════════════════════════════
//  الطريقة 3: تنظيف الاختبارات
// ════════════════════════════════════════════════════════════════

Future<void> cleanupTests() async {
  print('🧹 تنظيف الاختبارات...');
  
  try {
    // إلغاء الإشعار التجريبي
    await NotificationService().cancel(9999);
    print('✅ تم إلغاء الإشعار التجريبي (9999)');
  } catch (e) {
    print('❌ خطأ في إلغاء الإشعار: $e');
  }
  
  try {
    // إلغاء الأذان التجريبي
    await UnifiedAzanService().cancelAzan(9998);
    print('✅ تم إلغاء الأذان التجريبي (9998)');
  } catch (e) {
    print('❌ خطأ في إلغاء الأذان: $e');
  }
  
  print('✅ تم التنظيف');
}

// ════════════════════════════════════════════════════════════════
//  كيفية الاستخدام
// ════════════════════════════════════════════════════════════════

/*

1. في main.dart، أضف هذا الكود بعد runApp():

void main() async {
  // ... الكود الموجود ...
  
  runApp(const ProviderScope(child: NourRamadanApp()));
  
  // ✅ أضف هذا السطر
  Future.delayed(Duration(seconds: 3), () async {
    await quickDiagnostics();
    // await testScheduling();  // اختياري: لاختبار الجدولة
  });
}

2. شغّل التطبيق وانظر للـ console (في VS Code أو Android Studio)

3. ستظهر نتائج التشخيص مباشرة

4. إذا أردت اختبار الجدولة، فك التعليق عن testScheduling()

5. بعد الانتهاء من الاختبار، استخدم cleanupTests() للتنظيف

*/

// ════════════════════════════════════════════════════════════════
//  أو: إضافة كزر في شاشة الإعدادات
// ════════════════════════════════════════════════════════════════

/*

في settings_screen.dart، أضف:

ListTile(
  leading: Icon(Icons.bug_report),
  title: Text('تشخيص النظام'),
  subtitle: Text('فحص حالة الإشعارات والأذان'),
  onTap: () async {
    await quickDiagnostics();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('انظر للـ console لرؤية النتائج')),
    );
  },
),

ListTile(
  leading: Icon(Icons.science),
  title: Text('اختبار الجدولة'),
  subtitle: Text('جدولة إشعار وأذان تجريبيين'),
  onTap: () async {
    await testScheduling();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم جدولة الاختبارات - انتظر دقيقتين'),
        duration: Duration(seconds: 5),
      ),
    );
  },
),

*/
