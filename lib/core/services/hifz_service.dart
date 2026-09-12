import 'package:hive_flutter/hive_flutter.dart';

import '../../features/hifz/models/hifz_models.dart';

// ════════════════════════════════════════════════════════════════
//  HifzService — خدمة تتبع حفظ القرآن (تخزين محلي عبر Hive)
//  نفس نمط QuranProgressService/LastReadService تماماً: صندوق Hive
//  خام، مفاتيح ثابتة، وقراءة دفاعية لا تفشل أبداً على بيانات تالفة.
//
//  مستقلّة تماماً عن quran_progress_box (ختم القرآن) — انظر plan_hifz.md §2.6.
// ════════════════════════════════════════════════════════════════

class HifzService {
  static const String _boxName = 'hifz_box';
  static const String _keyPages = 'pages';
  static const String _keySettings = 'settings';
  static const String _keySessions = 'sessions';
  static const String _keyMeta = 'meta';

  /// أقصى عدد جلسات محفوظة في السجل — الأقدم يُحذف تلقائياً.
  static const int _maxSessions = 400;

  static Box? _box;

  /// تهيئة الخدمة (تُستدعى مرة واحدة عند بدء التطبيق).
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _getBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('HifzService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// الحصول على Box للاستماع للتغييرات.
  static Box? getBox() => _box;

  // ══════════════════════════════════════════════════════════════
  //  حالة الصفحات
  // ══════════════════════════════════════════════════════════════

  /// قراءة كل حالات الصفحات المخزَّنة — Map متفرّقة (فقط الصفحات
  /// التي بدأ حفظها)، بمفاتيح int بعد تحويلها من نصوص Hive.
  static Map<int, HifzPageState> loadPages() {
    final raw = _getBox.get(_keyPages);
    if (raw is! Map) return <int, HifzPageState>{};

    final out = <int, HifzPageState>{};
    raw.forEach((key, value) {
      final page = key is int ? key : int.tryParse(key.toString());
      if (page == null) return;
      if (value is Map) {
        out[page] = HifzPageState.fromMap(value, page: page);
      }
    });
    return out;
  }

  /// حفظ كل حالات الصفحات — لا تُكتَب الصفحات notStarted (نفس نمط
  /// read_surahs المتفرّق في QuranProgressService).
  static Future<void> savePages(Map<int, HifzPageState> pages) async {
    final serialized = <String, dynamic>{};
    pages.forEach((page, state) {
      if (state.stage != HifzStage.notStarted) {
        serialized[page.toString()] = state.toMap();
      }
    });
    await _getBox.put(_keyPages, serialized);
  }

  // ══════════════════════════════════════════════════════════════
  //  إعدادات الورد
  // ══════════════════════════════════════════════════════════════

  static HifzSettings loadSettings() {
    final raw = _getBox.get(_keySettings);
    if (raw is Map) return HifzSettings.fromMap(raw);
    return const HifzSettings();
  }

  static Future<void> saveSettings(HifzSettings settings) async {
    await _getBox.put(_keySettings, settings.toMap());
  }

  // ══════════════════════════════════════════════════════════════
  //  البيانات الوصفية / المواظبة
  // ══════════════════════════════════════════════════════════════

  static HifzMeta loadMeta() {
    final raw = _getBox.get(_keyMeta);
    if (raw is Map) return HifzMeta.fromMap(raw);
    return HifzMeta.initial();
  }

  static Future<void> saveMeta(HifzMeta meta) async {
    await _getBox.put(_keyMeta, meta.toMap());
  }

  // ══════════════════════════════════════════════════════════════
  //  سجل جلسات المراجعة
  // ══════════════════════════════════════════════════════════════

  static List<HifzReviewSession> loadSessions() {
    final raw = _getBox.get(_keySessions);
    if (raw is! List) return <HifzReviewSession>[];
    return raw.whereType<Map>().map(HifzReviewSession.fromMap).toList();
  }

  /// حفظ سجل الجلسات — يُقصّ إلى آخر [_maxSessions] جلسة لضبط حجم الصندوق.
  static Future<void> saveSessions(List<HifzReviewSession> sessions) async {
    final trimmed = sessions.length > _maxSessions
        ? sessions.sublist(sessions.length - _maxSessions)
        : sessions;
    await _getBox.put(_keySessions, trimmed.map((s) => s.toMap()).toList());
  }

  // ══════════════════════════════════════════════════════════════
  //  مسح البيانات
  // ══════════════════════════════════════════════════════════════

  static Future<void> clearAll() async {
    await _getBox.delete(_keyPages);
    await _getBox.delete(_keySettings);
    await _getBox.delete(_keySessions);
    await _getBox.delete(_keyMeta);
  }
}
