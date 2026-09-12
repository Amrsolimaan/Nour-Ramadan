import 'package:hive_flutter/hive_flutter.dart';

// ════════════════════════════════════════════════════════════════
//  DuaTrackingService — خدمة تتبع قراءة الأدعية
//  تستخدم Hive للتخزين المحلي
// ════════════════════════════════════════════════════════════════

class DuaTrackingService {
  static const String _boxName = 'dua_tracking_box';

  static Box? _box;

  /// تهيئة الخدمة (يتم استدعاؤها مرة واحدة عند بدء التطبيق)
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _getBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('DuaTrackingService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// الحصول على Box للاستماع للتغييرات
  static Box? getBox() => _box;

  // ══════════════════════════════════════════════════════════════
  //  مفاتيح التخزين
  // ══════════════════════════════════════════════════════════════

  static String _getDayKey(DateTime date) {
    return 'dua_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ══════════════════════════════════════════════════════════════
  //  تسجيل قراءة الدعاء
  // ══════════════════════════════════════════════════════════════

  /// تسجيل قراءة دعاء (يُستدعى تلقائياً عند فتح الدعاء)
  static Future<void> recordDuaRead(String duaId, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final key = _getDayKey(targetDate);
    
    // الحصول على العدد الحالي لليوم
    final currentCount = _getBox.get(key, defaultValue: 0);
    
    // زيادة العدد
    await _getBox.put(key, currentCount + 1);
  }

  // ══════════════════════════════════════════════════════════════
  //  الإحصائيات
  // ══════════════════════════════════════════════════════════════

  /// عدد الأدعية المقروءة اليوم
  static Future<int> getTodayDuasCount() async {
    final today = DateTime.now();
    final key = _getDayKey(today);
    return _getBox.get(key, defaultValue: 0);
  }

  /// عدد الأدعية المقروءة هذا الأسبوع
  static Future<int> getWeeklyDuasCount() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    int count = 0;
    
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      if (date.isAfter(now)) break;
      
      final key = _getDayKey(date);
      count += _getBox.get(key, defaultValue: 0) as int;
    }
    
    return count;
  }

  /// عدد الأدعية المقروءة هذا الشهر
  static Future<int> getMonthlyDuasCount() async {
    final now = DateTime.now();
    int count = 0;
    
    for (int day = 1; day <= now.day; day++) {
      final date = DateTime(now.year, now.month, day);
      final key = _getDayKey(date);
      count += _getBox.get(key, defaultValue: 0) as int;
    }
    
    return count;
  }

  /// عدد الأدعية المقروءة في يوم معين
  static Future<int> getDuasCountForDate(DateTime date) async {
    final key = _getDayKey(date);
    return _getBox.get(key, defaultValue: 0);
  }

  /// إجمالي عدد الأدعية المقروءة (كل الوقت)
  static Future<int> getTotalDuasCount() async {
    int total = 0;
    
    // جمع كل القيم في الـ Box
    for (var key in _getBox.keys) {
      if (key.toString().startsWith('dua_')) {
        final count = _getBox.get(key, defaultValue: 0);
        if (count is int) {
          total += count;
        }
      }
    }
    
    return total;
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
    final key = _getDayKey(date);
    await _getBox.delete(key);
  }

  /// إعادة تعيين عداد اليوم
  static Future<void> resetToday() async {
    final today = DateTime.now();
    final key = _getDayKey(today);
    await _getBox.put(key, 0);
  }
}
