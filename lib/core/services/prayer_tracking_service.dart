import 'package:hive_flutter/hive_flutter.dart';

// ════════════════════════════════════════════════════════════════
//  PrayerTrackingService — خدمة تتبع الصلوات
//  تستخدم Hive للتخزين المحلي
// ════════════════════════════════════════════════════════════════

class PrayerTrackingService {
  static const String _boxName = 'prayer_tracking_box';
  static const List<String> prayerNames = [
    'الفجر',
    'الظهر',
    'العصر',
    'المغرب',
    'العشاء',
  ];

  static Box? _box;

  /// تهيئة الخدمة (يتم استدعاؤها مرة واحدة عند بدء التطبيق)
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _getBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('PrayerTrackingService not initialized. Call init() first.');
    }
    return _box!;
  }

  // ══════════════════════════════════════════════════════════════
  //  مفاتيح التخزين
  // ══════════════════════════════════════════════════════════════

  static String _getDayKey(DateTime date) {
    return 'prayer_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _getPrayerKey(DateTime date, String prayerName) {
    return '${_getDayKey(date)}_$prayerName';
  }

  // ══════════════════════════════════════════════════════════════
  //  تسجيل الصلاة
  // ══════════════════════════════════════════════════════════════

  /// تسجيل أن الصلاة تمت
  static Future<void> markPrayerAsPrayed(String prayerName, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final key = _getPrayerKey(targetDate, prayerName);
    await _getBox.put(key, true);
  }

  /// إلغاء تسجيل الصلاة
  static Future<void> unmarkPrayer(String prayerName, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final key = _getPrayerKey(targetDate, prayerName);
    await _getBox.delete(key);
  }

  /// تبديل حالة الصلاة (صليت / لم أصلي)
  static Future<bool> togglePrayer(String prayerName, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final key = _getPrayerKey(targetDate, prayerName);
    final currentStatus = _getBox.get(key, defaultValue: false);
    
    if (currentStatus) {
      await _getBox.delete(key);
      return false;
    } else {
      await _getBox.put(key, true);
      return true;
    }
  }

  /// التحقق من حالة الصلاة
  static Future<bool> getPrayerStatus(String prayerName, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final key = _getPrayerKey(targetDate, prayerName);
    return _getBox.get(key, defaultValue: false);
  }

  // ══════════════════════════════════════════════════════════════
  //  الإحصائيات
  // ══════════════════════════════════════════════════════════════

  /// عدد الصلوات المؤداة اليوم
  static Future<int> getTodayPrayedCount() async {
    final today = DateTime.now();
    int count = 0;
    
    for (final prayerName in prayerNames) {
      final prayed = await getPrayerStatus(prayerName, date: today);
      if (prayed) count++;
    }
    
    return count;
  }

  /// عدد الصلوات المؤداة هذا الأسبوع
  static Future<int> getWeeklyPrayedCount() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    int count = 0;
    
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      if (date.isAfter(now)) break;
      
      for (final prayerName in prayerNames) {
        final prayed = await getPrayerStatus(prayerName, date: date);
        if (prayed) count++;
      }
    }
    
    return count;
  }

  /// عدد الصلوات المؤداة هذا الشهر
  static Future<int> getMonthlyPrayedCount() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    int count = 0;
    
    for (int day = 1; day <= now.day; day++) {
      final date = DateTime(now.year, now.month, day);
      
      for (final prayerName in prayerNames) {
        final prayed = await getPrayerStatus(prayerName, date: date);
        if (prayed) count++;
      }
    }
    
    return count;
  }

  /// الحصول على حالة جميع الصلوات لليوم
  static Future<Map<String, bool>> getTodayPrayers() async {
    final today = DateTime.now();
    final Map<String, bool> prayers = {};
    
    for (final prayerName in prayerNames) {
      prayers[prayerName] = await getPrayerStatus(prayerName, date: today);
    }
    
    return prayers;
  }

  // ══════════════════════════════════════════════════════════════
  //  مسح البيانات
  // ══════════════════════════════════════════════════════════════

  /// مسح جميع البيانات
  static Future<void> clearAll() async {
    await _getBox.clear();
  }

  /// مسح بيانات يوم معين
  static Future<void> clearDay(DateTime date) async {
    for (final prayerName in prayerNames) {
      final key = _getPrayerKey(date, prayerName);
      await _getBox.delete(key);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  إحصائيات إضافية (جديدة)
  // ══════════════════════════════════════════════════════════════

  /// عدد الصلوات المؤداة الإجمالي (منذ البداية)
  static Future<int> getTotalPrayedCount() async {
    int count = 0;
    final allKeys = _getBox.keys;
    
    for (final key in allKeys) {
      final keyStr = key.toString();
      // التحقق من أن المفتاح يخص صلاة وليس إعدادات أخرى
      if (keyStr.startsWith('prayer_') && 
          keyStr.contains('_') && 
          !keyStr.endsWith('_timestamp') &&
          _getBox.get(key) == true) {
        count++;
      }
    }
    
    return count;
  }

  // ══════════════════════════════════════════════════════════════
  //  كشف تغيير الوقت والتنظيف الذكي
  // ══════════════════════════════════════════════════════════════

  /// حفظ آخر وقت تم فيه تسجيل صلاة
  static Future<void> _saveLastRecordedTime() async {
    final now = DateTime.now();
    await _getBox.put('last_recorded_time', now.toIso8601String());
  }

  /// الحصول على آخر وقت مسجل
  static DateTime? _getLastRecordedTime() {
    final timeStr = _getBox.get('last_recorded_time');
    if (timeStr == null) return null;
    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }

  /// فحص تغيير الوقت وتنظيف الصلوات المستقبلية إذا لزم الأمر
  static Future<void> checkAndCleanupIfTimeChanged() async {
    final lastRecordedTime = _getLastRecordedTime();
    final currentTime = DateTime.now();
    
    if (lastRecordedTime != null) {
      // إذا الوقت الحالي أقدم من آخر وقت مسجل (رجع المستخدم بالوقت)
      if (currentTime.isBefore(lastRecordedTime)) {
        await _cleanupFuturePrayers(currentTime);
      }
    }
    
    // تحديث آخر وقت مسجل
    await _saveLastRecordedTime();
  }

  /// حذف جميع الصلوات التي تم تسجيلها بعد الوقت المحدد
  static Future<void> _cleanupFuturePrayers(DateTime currentTime) async {
    final allKeys = _getBox.keys.toList();
    
    for (final key in allKeys) {
      final keyStr = key.toString();
      
      // التحقق من أن المفتاح يخص صلاة
      if (keyStr.startsWith('prayer_') && keyStr.contains('_')) {
        try {
          // استخراج التاريخ من المفتاح: prayer_YYYY-MM-DD_prayerName
          final parts = keyStr.split('_');
          if (parts.length >= 4) {
            final datePart = '${parts[1]}-${parts[2]}-${parts[3]}';
            final prayerDate = DateTime.parse(datePart);
            
            // إذا تاريخ الصلاة بعد الوقت الحالي، احذفها
            if (prayerDate.isAfter(currentTime)) {
              await _getBox.delete(key);
            }
          }
        } catch (e) {
          // تجاهل الأخطاء في parsing
          continue;
        }
      }
    }
  }
}
