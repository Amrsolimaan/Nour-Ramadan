import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  hifz_toast — نقطة عرض موحَّدة واحدة لكل توستات/سناكبارات ميزة
//  الحفظ (استُبدلت بها 4 دوال _showToast شبه متطابقة كانت مكرَّرة في
//  hifz_new_memorization_screen.dart، hifz_today_review_screen.dart،
//  hifz_juz_detail_screen.dart، hifz_settings_screen.dart — واحدة
//  منها فقط (حفظ جديد) كانت تستدعي clearSnackBars قبل هذا التوحيد).
//
//  الآلية: ScaffoldMessenger.showSnackBar القياسية في فلاتر — لا يوجد
//  أي Overlay مخصَّص. فلاتر تُصفّ (queue) السناكبارات افتراضياً: نداء
//  showSnackBar أثناء ظهور سناكبار آخر لا يستبدله، بل ينتظر دوره —
//  فتظهر توستات متتالية واحدة تلو الأخرى بدل أن يُلغي كل إجراء جديد
//  ما قبله فوراً. الإصلاح: clearSnackBars() قبل كل showSnackBar مباشرة.
//
//  توست التراجع (showHifzUndoToast) يحمل SnackBarAction — ومنذ إضافة
//  خاصية SnackBar.persist إلى فلاتر (framework/lib/src/material/
//  snack_bar.dart، راجع التوثيق هناك)، فإن وجود action وحده يجعل
//  persist يُفترض true افتراضياً («persist = persist ?? action !=
//  null» في مُنشئ SnackBar)، وpersist=true يعني تجاهل مؤقّت
//  الإخفاء التلقائي كليّاً في ScaffoldMessengerState (راجع
//  scaffold.dart: "if (snackBar.persist) return;" داخل مستمع
//  المؤقّت) — أي أن توست التراجع كان سيبقى ظاهراً للأبد دون تمرير
//  persist: false صراحةً، بصرف النظر عن duration. لذلك [_hifzSnackBar]
//  يمرّر persist: false دائماً لضمان الإخفاء التلقائي بعد duration
//  في الحالتين (مع أو بلا action)، والنقر على "تراجع" يبقى فعّالاً
//  قبل انتهاء المؤقّت (فلاتر تُخفي السناكبار تلقائياً عند الضغط على
//  action)، وكذلك السحب اليدوي للإخفاء — كلاهما سلوك SnackBar
//  الافتراضي، لم يُمسّ.
//
//  ⚠️ ملاحظة مقصودة (وليست قراراً صامتاً): لأن clearSnackBars تُلغي أي
//  سناكبار ظاهر بصرف النظر عن نوعه، فإن توست تأكيد عادي لاحق (مثال:
//  "لا صفحات جديدة لإضافتها" بعد محاولة إضافة فارغة) سيُلغي توست
//  تراجع سابق لا يزال ظاهراً — فيفقد المستخدم إمكانية التراجع بنقرة
//  واحدة لذلك الإجراء السابق تحديداً (البيانات نفسها تبقى سليمة؛ فقط
//  واجهة "تراجع" السريعة تختفي). هذا هو السلوك المختار عمداً هنا
//  للاتساق والقابلية للتنبؤ (نفس القناة، نفس سياسة الاستبدال دائماً)
//  بدل قاعدة استثناء خاصة، تماشياً مع "آخر إجراء فقط يجب أن يكون
//  ظاهراً". إن كان يلزم لاحقاً حماية توست تراجع من إلغاء توست غير
//  متعلّق به، هذا يحتاج قراراً منتجياً صريحاً، لا افتراضاً هنا.
// ════════════════════════════════════════════════════════════════

/// مدة توست التأكيد البسيط (بلا إجراء).
const Duration kHifzToastDuration = Duration(seconds: 2);

/// مدة توست التراجع (يحمل زر "تراجع") — أطول قليلاً من التوست البسيط
/// عمداً لإعطاء المستخدم وقتاً كافياً للنقر، لكن مؤقَّتة صراحةً وليست
/// بلا حدّ زمني.
const Duration kHifzUndoToastDuration = Duration(seconds: 3);

SnackBar _hifzSnackBar({
  required Widget content,
  required Duration duration,
  SnackBarAction? action,
}) {
  return SnackBar(
    content: content,
    backgroundColor: const Color(0xFF1A1535),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.4)),
    ),
    duration: duration,
    action: action,
    // ⚠️ صراحةً false — SnackBar.persist يُفترض true تلقائياً في فلاتر
    // متى وُجد action (راجع التعليق أعلى الملف)، ما كان سيُعطّل مؤقّت
    // الإخفاء التلقائي لتوست التراجع تحديداً لو تُرك ضمنياً.
    persist: false,
  );
}

/// توست تأكيد بسيط — يُلغي فوراً أي توست حفظ ظاهر حالياً (من أي نوع)
/// ويستبدله بهذا التوست الجديد، بدل الانتظار في طابور فلاتر الافتراضي.
void showHifzToast(
  BuildContext context,
  String message, {
  Duration duration = kHifzToastDuration,
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      _hifzSnackBar(
        duration: duration,
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.agedPlaster),
        ),
      ),
    );
}

/// توست تأكيد مع إجراء تراجع فوري (مثال: بعد "حفظ جديد"). نفس سياسة
/// الإلغاء والاستبدال الفوري أعلاه، إضافةً لمؤقّت إخفاء تلقائي صريح
/// (3 ثوانٍ افتراضياً — [kHifzUndoToastDuration]).
void showHifzUndoToast(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  Duration duration = kHifzUndoToastDuration,
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      _hifzSnackBar(
        duration: duration,
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.agedPlaster),
        ),
        action: SnackBarAction(
          label: actionLabel,
          textColor: AppColors.goldLight,
          onPressed: onAction,
        ),
      ),
    );
}
