import 'package:hive_flutter/hive_flutter.dart';

// ════════════════════════════════════════════════════════════════
//  TasbihTrackingService — خدمة تتبع التسبيحات
//  تستخدم Hive للتخزين المحلي
// ════════════════════════════════════════════════════════════════

class TasbihTrackingService {
  static const String _boxName = 'tasbih_box';

  static Box? _box;

  /// تهيئة الخدمة (يتم استدعاؤها مرة واحدة عند بدء التطبيق)
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _getBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('TasbihTrackingService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// الحصول على Box للاستماع للتغييرات
  static Box? getBox() => _box;

  // ══════════════════════════════════════════════════════════════
  //  الإحصائيات
  // ══════════════════════════════════════════════════════════════

  /// عدد التسبيحات اليوم
  static Future<int> getTodayCount() async {
    return _getBox.get('daily_total', defaultValue: 0);
  }

  /// عدد التسبيحات هذا الشهر
  static Future<int> getMonthlyCount() async {
    return _getBox.get('monthly_total', defaultValue: 0);
  }

  /// إجمالي التسبيحات (كل الوقت)
  static Future<int> getTotalCount() async {
    return _getBox.get('total_count', defaultValue: 0);
  }

  /// إجمالي التسبيحات الكلي (بديل - يحسب من الـ Box مباشرة)
  static Future<int> getAllTimeCount() async {
    // نستخدم total_count إذا كان موجود
    final totalCount = _getBox.get('total_count', defaultValue: 0);
    if (totalCount > 0) return totalCount;
    
    // إذا لم يكن موجود، نحسب من daily و monthly
    final daily = _getBox.get('daily_total', defaultValue: 0);
    final monthly = _getBox.get('monthly_total', defaultValue: 0);
    
    // نستخدم الأكبر
    return monthly > daily ? monthly : daily;
  }
}
