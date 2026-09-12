import 'package:hive_flutter/hive_flutter.dart';

// ════════════════════════════════════════════════════════════════
//  QuranProgressService — خدمة تتبع ختم القرآن
//  تستخدم Hive للتخزين المحلي
// ════════════════════════════════════════════════════════════════

class QuranProgressService {
  static const String _boxName = 'quran_progress_box';
  static const String _keyReadSurahs = 'read_surahs';
  static const String _keyReadJuz = 'read_juz';
  static const String _keyKhatmahCount = 'khatmah_count';
  static const String _keyLastKhatmahDate = 'last_khatmah_date';

  static Box? _box;

  /// تهيئة الخدمة (يتم استدعاؤها مرة واحدة عند بدء التطبيق)
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _getBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('QuranProgressService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// الحصول على Box للاستماع للتغييرات
  static Box? getBox() => _box;

  // ══════════════════════════════════════════════════════════════
  //  السور المقروءة
  // ══════════════════════════════════════════════════════════════

  /// حفظ قائمة السور المقروءة
  static Future<void> saveReadSurahs(Set<int> surahs) async {
    await _getBox.put(_keyReadSurahs, surahs.toList());
  }

  /// قراءة قائمة السور المقروءة
  static Future<Set<int>> loadReadSurahs() async {
    final List<dynamic>? list = _getBox.get(_keyReadSurahs);
    if (list == null) return {};
    return list.cast<int>().toSet();
  }

  /// تبديل حالة سورة (مقروءة/غير مقروءة)
  static Future<bool> toggleSurah(int surahNumber) async {
    final surahs = await loadReadSurahs();
    if (surahs.contains(surahNumber)) {
      surahs.remove(surahNumber);
      await saveReadSurahs(surahs);
      return false;
    } else {
      surahs.add(surahNumber);
      await saveReadSurahs(surahs);
      
      // التحقق إذا أكمل 114 سورة
      if (surahs.length == 114) {
        await _completeKhatmah();
      }
      
      return true;
    }
  }

  /// التحقق إذا كانت السورة مقروءة
  static Future<bool> isSurahRead(int surahNumber) async {
    final surahs = await loadReadSurahs();
    return surahs.contains(surahNumber);
  }

  // ══════════════════════════════════════════════════════════════
  //  الأجزاء المقروءة
  // ══════════════════════════════════════════════════════════════

  /// حفظ قائمة الأجزاء المقروءة
  static Future<void> saveReadJuz(Set<int> juz) async {
    await _getBox.put(_keyReadJuz, juz.toList());
  }

  /// قراءة قائمة الأجزاء المقروءة
  static Future<Set<int>> loadReadJuz() async {
    final List<dynamic>? list = _getBox.get(_keyReadJuz);
    if (list == null) return {};
    return list.cast<int>().toSet();
  }

  /// تبديل حالة جزء (مقروء/غير مقروء)
  static Future<bool> toggleJuz(int juzNumber) async {
    final juz = await loadReadJuz();
    if (juz.contains(juzNumber)) {
      juz.remove(juzNumber);
      await saveReadJuz(juz);
      return false;
    } else {
      juz.add(juzNumber);
      await saveReadJuz(juz);
      return true;
    }
  }

  /// التحقق إذا كان الجزء مقروء
  static Future<bool> isJuzRead(int juzNumber) async {
    final juz = await loadReadJuz();
    return juz.contains(juzNumber);
  }

  // ══════════════════════════════════════════════════════════════
  //  الختمات
  // ══════════════════════════════════════════════════════════════

  /// حفظ عدد الختمات
  static Future<void> saveKhatmahCount(int count) async {
    await _getBox.put(_keyKhatmahCount, count);
  }

  /// قراءة عدد الختمات
  static Future<int> loadKhatmahCount() async {
    return _getBox.get(_keyKhatmahCount, defaultValue: 0);
  }

  /// حفظ تاريخ آخر ختمة
  static Future<void> saveLastKhatmahDate(DateTime date) async {
    await _getBox.put(_keyLastKhatmahDate, date.toIso8601String());
  }

  /// قراءة تاريخ آخر ختمة
  static Future<DateTime?> loadLastKhatmahDate() async {
    final String? dateStr = _getBox.get(_keyLastKhatmahDate);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  /// إكمال ختمة (يُستدعى تلقائياً عند 114 سورة)
  static Future<void> _completeKhatmah() async {
    final count = await loadKhatmahCount();
    await saveKhatmahCount(count + 1);
    await saveLastKhatmahDate(DateTime.now());
  }

  /// بدء ختمة جديدة (يدوي - يُستدعى من المستخدم)
  static Future<void> startNewKhatmah() async {
    await saveReadSurahs({});
    await saveReadJuz({});
  }

  // ══════════════════════════════════════════════════════════════
  //  إحصائيات
  // ══════════════════════════════════════════════════════════════

  /// الحصول على نسبة التقدم (0.0 - 1.0)
  static Future<double> getProgress() async {
    final surahs = await loadReadSurahs();
    return surahs.length / 114.0;
  }

  /// الحصول على عدد السور المقروءة
  static Future<int> getReadSurahsCount() async {
    final surahs = await loadReadSurahs();
    return surahs.length;
  }

  /// الحصول على عدد الأجزاء المقروءة
  static Future<int> getReadJuzCount() async {
    final juz = await loadReadJuz();
    return juz.length;
  }

  // ══════════════════════════════════════════════════════════════
  //  مسح البيانات
  // ══════════════════════════════════════════════════════════════

  /// مسح جميع البيانات
  static Future<void> clearAll() async {
    await _getBox.delete(_keyReadSurahs);
    await _getBox.delete(_keyReadJuz);
    await _getBox.delete(_keyKhatmahCount);
    await _getBox.delete(_keyLastKhatmahDate);
  }
}
