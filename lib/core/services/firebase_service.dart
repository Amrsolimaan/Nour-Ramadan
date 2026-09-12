import 'package:cloud_firestore/cloud_firestore.dart';

// ════════════════════════════════════════════════════════════════
//  FirebaseService — واجهة Firestore الوحيدة
//  Firebase Auth و Storage غير مستخدمَين
//  Collections:
//    • app_config → daily (verseOfDay + date)
//    • dua_categories
//    • duas
// ════════════════════════════════════════════════════════════════

class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  final _db = FirebaseFirestore.instance;

  // ── المراجع ──────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _appConfig =>
      _db.collection('app_config');
  CollectionReference<Map<String, dynamic>> get _duaCategories =>
      _db.collection('dua_categories');
  CollectionReference<Map<String, dynamic>> get _duas => _db.collection('duas');

  // ── app_config → daily ───────────────────────────────────────

  /// جلب آية اليوم + التاريخ من daily
  Future<DailyConfig?> getDailyConfig() async {
    try {
      final doc = await _appConfig.doc('daily').get();
      if (!doc.exists) return null;
      return DailyConfig.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  // ── dua_categories ───────────────────────────────────────────

  /// جلب كل التصنيفات المفعّلة مرتبة حسب order
  Future<List<Map<String, dynamic>>> getDuaCategories() async {
    try {
      final snap = await _duaCategories
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  // ── duas ─────────────────────────────────────────────────────

  /// جلب الأدعية المنشورة، مرتبة، مع فلتر اختياري بالتصنيف
  Future<List<Map<String, dynamic>>> getDuas({String? categoryId}) async {
    try {
      Query<Map<String, dynamic>> q = _duas
          .where('isPublished', isEqualTo: true)
          .orderBy('order');
      if (categoryId != null) {
        q = q.where('categoryId', isEqualTo: categoryId);
      }
      final snap = await q.get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      return [];
    }
  }

  /// زيادة readCount لدعاء معين (fire and forget)
  Future<void> incrementReadCount(String duaId) async {
    try {
      await _duas.doc(duaId).update({'readCount': FieldValue.increment(1)});
    } catch (_) {}
  }
}

// ════════════════════════════════════════════════════════════════
//  DailyConfig — نموذج app_config/daily
//  Fields: date (Timestamp), verseOfDay (String), verseReference (String)
// ════════════════════════════════════════════════════════════════
class DailyConfig {
  const DailyConfig({
    required this.date,
    required this.title,
    required this.verseOfDay,
    required this.verseReference,
  });

  final DateTime date;
  final String title; // عنوان يُعرض فوق الآية
  final String verseOfDay; // نص الآية
  final String verseReference; // المرجع مثل: «البقرة: 185»

  factory DailyConfig.fromMap(Map<String, dynamic> data) {
    return DailyConfig(
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: data['title'] as String? ?? '',
      verseOfDay: data['verseOfDay'] as String? ?? '',
      verseReference: data['verseReference'] as String? ?? '',
    );
  }

  /// التحقق أن الثلاث حقول الأساسية موجودة وغير فارغة
  bool get isComplete =>
      title.isNotEmpty && verseOfDay.isNotEmpty && verseReference.isNotEmpty;
}
