import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

// ════════════════════════════════════════════════════════════════
//  TimezoneService — المرحلة 5 (plan_azan_reliability.md §1.5 / §3.3)
//
//  ❌ المشكلة القديمة: main.dart كان يستدعي
//     tz_local.setLocalLocation(tz_local.local)
//     لكن tz.local getter لا يفعل شيئاً سوى إعادة حقل خاص يبدأ بـ UTC
//     ولا يرمي أبداً (راجع timezone/src/env.dart) — فالتطبيق كان يبقى
//     على UTC طوال دورة حياته، و catch الاحتياطي لـ Africa/Cairo كان
//     كوداً ميتاً لا يُنفَّذ إطلاقاً لأن الجملة التي يحرسها لا ترمي.
//
//  ✅ الحل: flutter_timezone يقرأ منطقة الجهاز الحقيقية من الطبقة
//     الناتيف (Android/iOS)، ثم نُطبّقها بـ tz.setLocalLocation() —
//     مع fallback فعلي هذه المرّة (اسم غير معروف أو فشل القناة).
//
//  نقاط الاستدعاء (المرحلة 5، البند 4 — إعادة استخدام خطّاف موجود
//  بدل إضافة خطّاف جديد):
//  • بدء التطبيق (main.dart، بعد tz.initializeTimeZones() مباشرةً).
//  • استئناف التطبيق: _AppRootState.didChangeAppLifecycleState()
//    الموجودة فعلاً لإعادة فحص الأذونات — لم نُضِف خطّافاً جديداً.
//  • rescheduleFromTimeChange: معالج القناة الموجود فعلاً في main.dart
//    (نقطة الدخول التاريخية لتغيّر الوقت/المنطقة من الناتيف — راجع
//    التعليق أعلاه في main.dart لملاحظة أن مُشغِّلها الناتيف الحالي
//    (TimeChangeReceiver) لا يستدعيه بعد إعادة كتابة المرحلة 2، لكن
//    المعالج نفسه لا يزال حياً ومسجَّلاً، وهذا يُبقيه صحيحاً لو أُعيد
//    ربطه لاحقاً أو استدعاه أي مسار آخر).
// ════════════════════════════════════════════════════════════════
class TimezoneService {
  TimezoneService._();

  static const String fallbackZoneName = 'Africa/Cairo';

  // ════════════════════════════════════════════════════════════
  //  ① القرار الصِرف (pure) — اختيار الاسم فقط، بلا فحص صحّته
  // ════════════════════════════════════════════════════════════

  /// يختار اسم IANA الذي يجب تجربته: اسم الجهاز إن وُجد وغير فارغ
  /// (بعد trim)، وإلا [fallback]. لا يفحص صحة الاسم نفسه — ذلك من
  /// مسؤولية [applyZoneWithFallback] عبر try/catch حول tz.getLocation().
  static String pickZoneName(
    String? deviceZoneName, {
    String fallback = fallbackZoneName,
  }) {
    if (deviceZoneName == null) return fallback;
    final trimmed = deviceZoneName.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  // ════════════════════════════════════════════════════════════
  //  ② التطبيق مع fallback — يلمس حالة tz العامة، لكن بلا أي قناة
  //  منصّة (flutter_timezone) ولا Context — قابل للاختبار بـ JUnit/
  //  flutter_test عادي بعد استدعاء tz.initializeTimeZones() مرّة.
  // ════════════════════════════════════════════════════════════

  /// يُطبّق [name] عبر tz.setLocalLocation(). إن كان [name] غير معروف
  /// في قاعدة بيانات timezone (tz.getLocation ترمي)، يُطبّق [fallback]
  /// بدلاً منه. يُعيد الاسم المُطبَّق فعلياً — [name] أو [fallback].
  static String applyZoneWithFallback(
    String name, {
    String fallback = fallbackZoneName,
  }) {
    try {
      tz.setLocalLocation(tz.getLocation(name));
      return name;
    } catch (e) {
      debugPrint(
        '⚠️ TimezoneService: منطقة غير معروفة "$name" ($e) — '
        'fallback إلى $fallback',
      );
      // ✅ fallback نفسه لا يُغلَّف بـ try/catch: Africa/Cairo ثابت في
      // قاعدة بيانات timezone دائماً — فشله يعني تلفاً حقيقياً في
      // قاعدة البيانات لا يمكن التعافي منه هنا.
      tz.setLocalLocation(tz.getLocation(fallback));
      return fallback;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  ③ الغلاف الحقيقي — flutter_timezone (قناة منصّة) + التطبيق
  // ════════════════════════════════════════════════════════════

  /// يجلب المنطقة الزمنية الحقيقية للجهاز عبر flutter_timezone ويُطبّقها.
  /// عند فشل القناة نفسها (نادر) يُعامَل كاسم مفقود — يذهب مباشرةً
  /// لـ fallback. يُعيد الاسم المُطبَّق فعلياً؛ لا يرمي أبداً.
  static Future<String> resolveAndApply() async {
    String? deviceZoneName;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      deviceZoneName = info.identifier;
    } catch (e) {
      debugPrint('⚠️ TimezoneService: فشل flutter_timezone: $e');
    }

    final chosen = pickZoneName(deviceZoneName);
    final applied = applyZoneWithFallback(chosen);

    if (applied == chosen) {
      debugPrint('✅ TimezoneService: المنطقة الزمنية المحلية = $applied');
    } else {
      debugPrint(
        '⚠️ TimezoneService: "$chosen" غير معروفة — استُخدم $applied بدلاً منها',
      );
    }
    return applied;
  }
}
