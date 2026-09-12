import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_keys.dart';

// ════════════════════════════════════════════════════════════════
//  PrefsMigration — ترحيل المفاتيح ذات البادئة المزدوجة (مرّة واحدة)
//
//  الخلفية (plan_azan_reliability.md §1.8):
//
//  حزمة shared_preferences تُضيف 'flutter.' لكل مفتاح تحفظه.
//  الكود القديم كان يكتب المفتاح مسبوقاً بـ 'flutter.' أيضاً:
//
//      قديم:  prefs.setString('flutter.last_lat', v)
//             → مفتاح Android الفعلي: flutter.flutter.last_lat   ❌
//
//      جديد:  prefs.setString('last_lat', v)
//             → مفتاح Android الفعلي: flutter.last_lat           ✅
//
//  الناتيف يقرأ "flutter.last_lat" — لذلك لم يكن يجد شيئاً أبداً.
//
//  من داخل Dart تبقى القيمة القديمة قابلة للقراءة باسمها القديم
//  ('flutter.last_lat') لأن الحزمة تُضيف بادئتها الخاصة عند القراءة أيضاً.
//  إذاً الترحيل من منظور Dart هو ببساطة:
//
//      get('flutter.X')  →  set('X', value)  →  remove('flutter.X')
//
//  ما يُنتج على مستوى Android:
//
//      flutter.flutter.X  →  flutter.X   (وهو ما يقرأه Kotlin)
// ════════════════════════════════════════════════════════════════
class PrefsMigration {
  PrefsMigration._();

  static const String _legacyPrefix = 'flutter.';

  /// مفاتيح تُحذف بدل أن تُرحَّل قيمتها.
  ///
  /// `pending_navigation` حالة تنقّل عابرة (وجهة نقرة إشعار)، وليست بيانات
  /// تستحق الحفظ. نسخ قيمة قديمة إلى المفتاح الصحيح قد يفتح شاشة عشوائية
  /// عند أول تشغيل بعد التحديث — لذلك نحذفها فقط.
  static const Set<String> _deleteInsteadOfMigrate = {
    'flutter.pending_navigation',
  };

  // ════════════════════════════════════════════════════════════
  //  نقطة الدخول — تُستدعى مرة واحدة في بداية main()
  // ════════════════════════════════════════════════════════════
  /// ينقل كل مفتاح مزدوج البادئة إلى اسمه الصحيح.
  ///
  /// آمنة للاستدعاء المتكرر: محروسة بعلم [PrefKeys.migrationV1Done].
  /// لا ترمي استثناءات أبداً — فشل الترحيل يجب ألّا يمنع إقلاع التطبيق.
  static Future<void> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.getBool(PrefKeys.migrationV1Done) ?? false) {
        return;
      }

      // نسخة ثابتة من المفاتيح — نُعدّل الخزنة أثناء التكرار
      final legacyKeys = prefs
          .getKeys()
          .where((k) => k.startsWith(_legacyPrefix))
          .toList(growable: false);

      var migrated = 0;
      var skipped = 0;
      var removed = 0;
      var discarded = 0;

      for (final legacyKey in legacyKeys) {
        final newKey = legacyKey.substring(_legacyPrefix.length);

        // مفتاح مثل 'flutter.' وحده — لا اسم بعده
        if (newKey.isEmpty) continue;

        // حالة عابرة: تُحذف ولا تُنسخ
        if (_deleteInsteadOfMigrate.contains(legacyKey)) {
          await prefs.remove(legacyKey);
          discarded++;
          removed++;
          continue;
        }

        try {
          final value = prefs.get(legacyKey);

          if (value == null) {
            await prefs.remove(legacyKey);
            removed++;
            continue;
          }

          // لا نطمس قيمة صحيحة موجودة أصلاً.
          // مثال: last_sound_file_scheduled كان يُكتب بالاسمين معاً
          // (unified_azan_service بالاسم الصحيح، وغيره بالاسم المزدوج).
          if (prefs.containsKey(newKey)) {
            await prefs.remove(legacyKey);
            skipped++;
            removed++;
            continue;
          }

          final written = await _writeTyped(prefs, newKey, value);

          if (written) {
            await prefs.remove(legacyKey);
            migrated++;
            removed++;
          } else {
            debugPrint(
              '⚠️ PrefsMigration: نوع غير مدعوم لـ "$legacyKey" '
              '(${value.runtimeType}) — تُرك كما هو',
            );
          }
        } catch (e) {
          // مفتاح واحد فاشل يجب ألّا يوقف بقية الترحيل
          debugPrint('⚠️ PrefsMigration: فشل ترحيل "$legacyKey": $e');
        }
      }

      await prefs.setBool(PrefKeys.migrationV1Done, true);

      debugPrint(
        '✅ PrefsMigration v1: مُرحَّل=$migrated، '
        'متجاوَز(موجود أصلاً)=$skipped، مُهمَل(عابر)=$discarded، '
        'محذوف=$removed، إجمالي المفحوص=${legacyKeys.length}',
      );
    } catch (e, st) {
      // الترحيل ليس حرجاً لبدء التشغيل — نُسجّل ونُكمل
      debugPrint('❌ PrefsMigration: خطأ عام: $e');
      debugPrint('$st');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  كتابة القيمة بنوعها الأصلي
  // ════════════════════════════════════════════════════════════
  static Future<bool> _writeTyped(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (value is String) {
      await prefs.setString(key, value);
      return true;
    }
    if (value is int) {
      await prefs.setInt(key, value);
      return true;
    }
    if (value is double) {
      await prefs.setDouble(key, value);
      return true;
    }
    if (value is bool) {
      await prefs.setBool(key, value);
      return true;
    }
    if (value is List<String>) {
      await prefs.setStringList(key, value);
      return true;
    }
    return false;
  }

  // ════════════════════════════════════════════════════════════
  //  أداة تشخيص — تُستخدم من شاشة الفحص عند الحاجة
  // ════════════════════════════════════════════════════════════
  /// يُعيد المفاتيح المزدوجة البادئة المتبقية (يجب أن تكون فارغة بعد الترحيل).
  static Future<List<String>> findRemainingLegacyKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs
          .getKeys()
          .where((k) => k.startsWith(_legacyPrefix))
          .toList();
    } catch (e) {
      debugPrint('⚠️ PrefsMigration.findRemainingLegacyKeys: $e');
      return const [];
    }
  }
}
