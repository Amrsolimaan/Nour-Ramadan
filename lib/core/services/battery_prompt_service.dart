import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/screens/battery_permission_screen.dart';
import 'alarm_permission_service.dart';
import 'prefs_keys.dart';
import 'unified_azan_service.dart';

// ════════════════════════════════════════════════════════════════
//  BatteryPromptService — المرحلة 4 (plan_azan_reliability.md §2.4)
//
//  تنبيه إعفاء البطارية السياقي — قرار §Q2 المحسوم:
//  • يظهر مرّة واحدة بعد أول تفعيل أذان (لا عند فتح التطبيق — المستخدم
//    لا يملك سياقاً وقتها). التحفيز الفعلي هو toggleNotification في
//    prayer_provider.dart، والاستدعاء من واجهة prayer_times_screen.dart
//    بعد تفعيله بنجاح.
//  • ليس Dialog يحجب — شاشة كاملة (BatteryPermissionScreen) مثل بقية
//    شاشات التطبيق.
//  • لا يُعاد عرضه إن كان الإعفاء ممنوحاً أصلاً.
//  • عند الرفض: لا يُعاد العرض قبل مرور 30 يوماً (raison d'être لهذا
//    الملف — القرار الصِرف مفصول تماماً عن أي I/O لسهولة الاختبار).
//
//  توجيه المصنّع (Xiaomi/Vivo/Oppo/Huawei):
//  زر "منح الصلاحية" في BatteryPermissionScreen يفحص
//  hasStrictOemRestrictions() أولاً — إن كان الجهاز من مصنّع معروف
//  بقيود صارمة يفتح إعداداته الخاصة (ManufacturerHelper، ناتيف بالكامل)
//  وإلا يطلب الإعفاء العام المباشر (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).
// ════════════════════════════════════════════════════════════════

/// أي إجراء يجب أن ينفّذه زرّ "منح الصلاحية"؟
enum BatteryGrantAction {
  /// جهاز من مصنّع معروف بقيود صارمة (Xiaomi/Vivo/Oppo/Huawei) —
  /// يفتح إعداداته الخاصة (autostart/protected apps) عبر ManufacturerHelper.
  manufacturerSpecific,

  /// أي جهاز آخر — طلب الإعفاء العام المباشر من نظام Android.
  generic,
}

class BatteryPromptService {
  BatteryPromptService._();
  static final instance = BatteryPromptService._();

  static const int _cooldownDays = 30;

  // ════════════════════════════════════════════════════════════
  //  ① القرار الصِرف (pure) — بلا أي I/O، قابل للاختبار مباشرةً
  // ════════════════════════════════════════════════════════════

  /// هل نعرض شاشة إعفاء البطارية الآن؟
  ///
  /// [isAlreadyExempted]: نتيجة UnifiedAzanService.isBatteryOptimizationDisabled()
  /// [lastDeclinedAtMs]: آخر رفض محفوظ (null = لم يُرفض إطلاقاً)
  /// [nowMs]: الوقت الحالي (يُمرَّر صريحاً لسهولة الاختبار — لا DateTime.now() هنا)
  static bool shouldPromptPure({
    required bool isAlreadyExempted,
    required int? lastDeclinedAtMs,
    required int nowMs,
    int cooldownDays = _cooldownDays,
  }) {
    if (isAlreadyExempted) return false;
    if (lastDeclinedAtMs == null) return true;

    final cooldownMs = cooldownDays * 24 * 60 * 60 * 1000;
    return nowMs - lastDeclinedAtMs >= cooldownMs;
  }

  /// أيّ إجراء يجب أن ينفّذه زر "منح الصلاحية"؟
  /// دالة صِرفة (pure) — قرار مجرّد بلا أي استدعاء ناتيف.
  static BatteryGrantAction pickGrantAction({
    required bool hasStrictOemRestrictions,
  }) => hasStrictOemRestrictions
      ? BatteryGrantAction.manufacturerSpecific
      : BatteryGrantAction.generic;

  // ════════════════════════════════════════════════════════════
  //  ② الأغلفة الحقيقية — I/O فعلي (SharedPreferences + MethodChannel)
  // ════════════════════════════════════════════════════════════

  /// هل نعرض الشاشة الآن؟ يقرأ الحالة الفعلية ويُفوّض القرار لـ
  /// [shouldPromptPure].
  Future<bool> shouldPromptNow() async {
    if (!Platform.isAndroid) return false;

    final isExempted = await UnifiedAzanService().isBatteryOptimizationDisabled();
    final prefs = await SharedPreferences.getInstance();
    final lastDeclinedStr = prefs.getString(PrefKeys.batteryPromptLastDeclinedAt);
    final lastDeclinedAtMs = lastDeclinedStr == null
        ? null
        : int.tryParse(lastDeclinedStr);

    return shouldPromptPure(
      isAlreadyExempted: isExempted,
      lastDeclinedAtMs: lastDeclinedAtMs,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// يُسجّل رفضاً الآن — يُؤخّر أي عرض لاحق 30 يوماً.
  Future<void> recordDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefKeys.batteryPromptLastDeclinedAt,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// أيّ إجراء يجب أن ينفّذه زر "منح الصلاحية" — يفحص المصنّع الفعلي.
  Future<BatteryGrantAction> resolveGrantAction() async {
    final hasStrictOem = await AlarmPermissionService.instance
        .hasStrictOemRestrictions();
    return pickGrantAction(hasStrictOemRestrictions: hasStrictOem);
  }

  // ════════════════════════════════════════════════════════════
  //  ③ نقطة الدخول — تُستدعى من واجهة المستخدم بعد تفعيل الأذان
  // ════════════════════════════════════════════════════════════

  /// يفحص [shouldPromptNow] ويعرض [BatteryPermissionScreen] عند الحاجة.
  ///
  /// أي خروج من الشاشة دون منح الإعفاء (زر "لاحقاً"، أو زر الرجوع، أو
  /// أي مسار آخر) يُسجَّل رفضاً — راجع BatteryPermissionScreen، النتيجة
  /// المُعادة عند pop هي `true` فقط عند تأكيد منح الإعفاء فعلياً.
  Future<void> maybeShow(BuildContext context) async {
    if (!await shouldPromptNow()) return;
    if (!context.mounted) return;

    final granted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BatteryPermissionScreen()),
    );

    if (granted != true) {
      await recordDeclined();
    }
  }
}
