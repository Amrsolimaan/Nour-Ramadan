import 'package:hive_flutter/hive_flutter.dart';

// ════════════════════════════════════════════════════════════════
//  LastReadService — خدمة تتبع "آخر قراءة" في المصحف
//  تستخدم Hive للتخزين المحلي (نفس نمط QuranProgressService)
//
//  المفاتيح المخزَّنة:
//   • last_read_global  → آخر موضع قراءة يدوي على مستوى التطبيق (Map) — شارة القائمة
//   • last_read_by_surah → Map<surahNumber, ayahNumber> يدوي (مفاتيح نصية) — شارة
//   • auto_resume_global  → آخر موضع تلقائي للاستئناف (Map) — لكل سورة صفحتها
//   • auto_resume_by_surah → Map<surahNumber, page> تلقائي — يُستخدم للرجوع لنفس الصفحة
//  الفصل يمنع سباق 800ms بين الحفظ اليدوي والتلقائي على نفس المفتاح
// ════════════════════════════════════════════════════════════════

class LastReadService {
  static const String _boxName = 'quran_last_read_box';
  static const String _keyGlobal = 'last_read_global';
  static const String _keyBySurah = 'last_read_by_surah';
  static const String _keyAutoGlobal = 'auto_resume_global';
  static const String _keyAutoBySurah = 'auto_resume_by_surah';

  static Box? _box;

  /// تهيئة الخدمة (تُستدعى مرة واحدة عند بدء التطبيق)
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    // هجرة صامتة لمرة واحدة: إذا كان هناك يدوي قديم ولا يوجد تلقائي، انسخه للتلقائي
    // حتى لا يفقد المستخدم موضعه الحالي عند التحديث
    try {
      final hasManual = _box!.containsKey(_keyBySurah);
      final hasAuto = _box!.containsKey(_keyAutoBySurah);
      if (hasManual && !hasAuto) {
        final rawManual = _box!.get(_keyBySurah);
        if (rawManual is Map && rawManual.isNotEmpty) {
          await _box!.put(_keyAutoBySurah, Map.from(rawManual));
        }
      }
      final hasGlobalManual = _box!.containsKey(_keyGlobal);
      final hasGlobalAuto = _box!.containsKey(_keyAutoGlobal);
      if (hasGlobalManual && !hasGlobalAuto) {
        final rawGlobal = _box!.get(_keyGlobal);
        if (rawGlobal is Map) {
          await _box!.put(_keyAutoGlobal, Map.from(rawGlobal));
        }
      }
    } catch (_) {}
  }

  static Box get _getBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('LastReadService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// الحصول على Box للاستماع للتغييرات
  static Box? getBox() => _box;

  // ══════════════════════════════════════════════════════════════
  //  حفظ — يدوي
  // ══════════════════════════════════════════════════════════════

  /// حفظ آخر موضع قراءة يدوي — يحدّث المفتاح العام + خريطة السور (للشارة)
  /// الاسم القديم saveLastRead مبقى للتوافق ويستدعي saveManual
  static Future<void> saveLastRead(LastReadPosition position) async {
    await saveManual(position);
  }

  static Future<void> saveManual(LastReadPosition position) async {
    await _getBox.put(_keyGlobal, position.toMap());

    final bySurah = getLastReadBySurah();
    bySurah[position.surahNumber] = position.ayahNumber;
    await _getBox.put(
      _keyBySurah,
      bySurah.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  حفظ — تلقائي (لكل سورة)
  // ══════════════════════════════════════════════════════════════

  /// حفظ موضع تلقائي للاستئناف — يكتب فقط في مفاتيح auto ولا يمس اليدوي أبداً
  static Future<void> saveAuto(LastReadPosition position) async {
    await _getBox.put(_keyAutoGlobal, position.toMap());

    final bySurah = getAutoBySurah();
    // نخزن رقم الصفحة كقيمة للخريطة السريعة، والكائن الكامل في global للفتح الدقيق
    // لكن للتبسيط نخزن ayahNumber كمرجع للصفحة (أول آية مرئية)
    // الأهم هو وجود Map لكل سورة
    bySurah[position.surahNumber] = position.ayahNumber;
    await _getBox.put(
      _keyAutoBySurah,
      bySurah.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  /// حفظ تلقائي مختصر من صفحة مباشرة (يستخدمه _scheduleLastReadSave)
  static Future<void> saveAutoForSurah(int surahNumber, int ayahNumber, {int pageNumber = 0, int juzNumber = 0}) async {
    final pos = LastReadPosition(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      pageNumber: pageNumber,
      juzNumber: juzNumber,
      updatedAt: DateTime.now(),
    );
    await saveAuto(pos);
  }

  // ══════════════════════════════════════════════════════════════
  //  قراءة — يدوي
  // ══════════════════════════════════════════════════════════════

  /// آخر موضع قراءة يدوي على مستوى التطبيق (أو null إن لم يوجد)
  static LastReadPosition? getGlobalLastRead() {
    final raw = _getBox.get(_keyGlobal);
    if (raw is Map) return LastReadPosition.fromMap(raw);
    return null;
  }

  /// خريطة آخر آية مقروءة يدوياً لكل سورة — {surahNumber: ayahNumber}
  static Map<int, int> getLastReadBySurah() {
    final raw = _getBox.get(_keyBySurah);
    if (raw is! Map) return <int, int>{};

    final result = <int, int>{};
    raw.forEach((key, value) {
      final k = key is int ? key : int.tryParse(key.toString());
      final v = value is int ? value : int.tryParse(value.toString());
      if (k != null && v != null) result[k] = v;
    });
    return result;
  }

  /// آخر آية مقروءة يدوياً في سورة معيّنة (أو null)
  static int? getLastReadAyahForSurah(int surahNumber) {
    return getLastReadBySurah()[surahNumber];
  }

  // ══════════════════════════════════════════════════════════════
  //  قراءة — تلقائي
  // ══════════════════════════════════════════════════════════════

  static LastReadPosition? getAutoGlobal() {
    final raw = _getBox.get(_keyAutoGlobal);
    if (raw is Map) return LastReadPosition.fromMap(raw);
    return null;
  }

  static Map<int, int> getAutoBySurah() {
    final raw = _getBox.get(_keyAutoBySurah);
    if (raw is! Map) return <int, int>{};
    final result = <int, int>{};
    raw.forEach((key, value) {
      final k = key is int ? key : int.tryParse(key.toString());
      final v = value is int ? value : int.tryParse(value.toString());
      if (k != null && v != null) result[k] = v;
    });
    return result;
  }

  static int? getAutoAyahForSurah(int surahNumber) {
    return getAutoBySurah()[surahNumber];
  }

  // ══════════════════════════════════════════════════════════════
  //  مسح البيانات
  // ══════════════════════════════════════════════════════════════

  /// مسح جميع بيانات "آخر قراءة" اليدوية فقط
  static Future<void> clearAll() async {
    await _getBox.delete(_keyGlobal);
    await _getBox.delete(_keyBySurah);
  }

  static Future<void> clearManualForSurah(int surahNumber) async {
    final bySurah = getLastReadBySurah();
    bySurah.remove(surahNumber);
    await _getBox.put(
      _keyBySurah,
      bySurah.map((k, v) => MapEntry(k.toString(), v)),
    );
    final global = getGlobalLastRead();
    if (global != null && global.surahNumber == surahNumber) {
      await _getBox.delete(_keyGlobal);
    }
  }

  static Future<void> clearAutoForSurah(int surahNumber) async {
    final bySurah = getAutoBySurah();
    bySurah.remove(surahNumber);
    await _getBox.put(
      _keyAutoBySurah,
      bySurah.map((k, v) => MapEntry(k.toString(), v)),
    );
    final global = getAutoGlobal();
    if (global != null && global.surahNumber == surahNumber) {
      await _getBox.delete(_keyAutoGlobal);
    }
  }

  static Future<void> clearAllAuto() async {
    await _getBox.delete(_keyAutoGlobal);
    await _getBox.delete(_keyAutoBySurah);
  }
}

// ════════════════════════════════════════════════════════════════
//  LastReadPosition — نموذج موضع القراءة
//  يُخزَّن كـ Map؛ التاريخ يُخزَّن كنص ISO8601 (نفس نمط الختمات)
// ════════════════════════════════════════════════════════════════

class LastReadPosition {
  final int surahNumber;
  final int ayahNumber;
  final int pageNumber;
  final int juzNumber;
  final DateTime updatedAt;

  const LastReadPosition({
    required this.surahNumber,
    required this.ayahNumber,
    required this.pageNumber,
    required this.juzNumber,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'surahNumber': surahNumber,
    'ayahNumber': ayahNumber,
    'pageNumber': pageNumber,
    'juzNumber': juzNumber,
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// يبني الكائن من Map مخزَّنة في Hive — يرجع null إن كانت البيانات تالفة
  static LastReadPosition? fromMap(Map? map) {
    if (map == null) return null;

    final surah = map['surahNumber'];
    final ayah = map['ayahNumber'];
    if (surah is! int || ayah is! int) return null;

    return LastReadPosition(
      surahNumber: surah,
      ayahNumber: ayah,
      pageNumber: (map['pageNumber'] as num?)?.toInt() ?? 0,
      juzNumber: (map['juzNumber'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'LastReadPosition(surah: $surahNumber, ayah: $ayahNumber, '
      'page: $pageNumber, juz: $juzNumber, at: ${updatedAt.toIso8601String()})';
}
