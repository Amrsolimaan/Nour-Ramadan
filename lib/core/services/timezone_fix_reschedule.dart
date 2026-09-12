import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_keys.dart';

// ════════════════════════════════════════════════════════════════
//  TimezoneFixRescheduleMigration — متابعة المرحلة 5
//
//  ⚠️ نطاق مُصحَّح بعد تحقّق فعلي في الكود (لا افتراض) — راجع
//  plan_azan_reliability.md، متابعة المرحلة 5، للتفاصيل الكاملة:
//
//  الافتراض الأصلي كان: كل إشعارات zonedSchedule (أذان iOS، تذكيرات،
//  السحور، الإفطار) حُسبت بلحظة زمنية خاطئة بسبب خلل tz.local
//  (المرحلة 5). ثبت هذا الافتراض **خاطئاً** بتتبّع الكود الفعلي:
//
//  • TZDateTime.from(dt, location) يحفظ اللحظة المطلقة عبر
//    dt.toUtc() — تحويل Dart الأصلي المعتمد على توقيت النظام
//    الحقيقي، لا على tz.local إطلاقاً (timezone/src/date_time.dart:219).
//  • flutter_local_notifications يُرسل (scheduledDateTime + timeZoneName)
//    معاً للطبقة الناتيف، والطرفان (Android: FlutterLocalNotificationsPlugin
//    .java:1345-1347 عبر ZonedDateTime.of(...)، iOS: .m:814-824 عبر
//    ISO8601 بإزاحة مضمَّنة) يُعيدان بناء اللحظة المطلقة من نفس الزوج
//    المُرسَل — فتكون صحيحة دائماً بصرف النظر عن هوية tz.local وقت
//    الجدولة. أي جدولة لمرّة واحدة (أذان/تذكير/سحور/إفطار/شروق) لم
//    تكن خاطئة أبداً.
//
//  الاستثناء الحقيقي الوحيد: matchDateTimeComponents: DateTimeComponents
//  .time (تكرار يومي تلقائي على مستوى نظام التشغيل، بلا أي تدخّل
//  لاحق من التطبيق) — المُستخدَم في مكان واحد فقط: تذكير ورد الحفظ
//  اليومي (HifzReminderScheduler، عبر notification_service.dart:426).
//  هنا الزيادة اليومية تحدث على الجهاز نفسه بمنطقة تُسلَّح وقت الجدولة
//  الأولى — فأي سلسلة أُسلِّحت قبل إصلاح المرحلة 5 (بمنطقة UTC خاطئة،
//  بلا توقيت صيفي) قد تنحرف ساعة كاملة عبر أي حدّ تغيير توقيت صيفي/
//  شتوي حتى تُعاد جدولتها.
//
//  ✅ لذلك هذا الملف يُعيد جدولة تذكير الورد فقط — وليس أي إشعار آخر.
//  إعادة جدولة الأذان/التذكيرات/السحور/الإفطار لن تُصحّح شيئاً (كانت
//  صحيحة أصلاً) وكانت ستكون عملاً بلا فائدة يحمل تعليقات مضلِّلة.
// ════════════════════════════════════════════════════════════════
class TimezoneFixRescheduleMigration {
  TimezoneFixRescheduleMigration._();

  /// يُنفّذ [rescheduleHifzReminder] مرّة واحدة فقط (محروسة بعلم
  /// [PrefKeys.timezoneFixRescheduleV1Done]).
  ///
  /// [rescheduleHifzReminder] قابلة للحقن عمداً لتسهيل الاختبار بلا
  /// أي اعتمادية على Riverpod/Hive الحقيقية — الاستخدام الحقيقي
  /// (main.dart) يمرّر إغلاقاً يستدعي HifzNotifier.rescheduleReminderNow()
  /// عبر ProviderContainer.
  ///
  /// ⚠️ خلافاً لـ PrefsMigration (المرحلة 1): لا يُعلَّم العلم "تمّ" إن
  /// فشل [rescheduleHifzReminder] — هذه عملية ذرّية واحدة (لا حلقة على
  /// مفاتيح متعدّدة)، ومُعيدة للمحاولة بأمان (reschedule() تُلغي ثم
  /// تُعيد التسليح دائماً، بلا أثر تراكمي)، فتُعاد المحاولة في الإقلاع
  /// التالي بدل تركها فاشلة للأبد.
  static Future<void> run(
    Future<void> Function() rescheduleHifzReminder,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.getBool(PrefKeys.timezoneFixRescheduleV1Done) ?? false) {
        return;
      }

      await rescheduleHifzReminder();
      await prefs.setBool(PrefKeys.timezoneFixRescheduleV1Done, true);

      debugPrint(
        '✅ TimezoneFixReschedule v1: أُعيدت جدولة تذكير الورد '
        'بعد إصلاح المنطقة الزمنية',
      );
    } catch (e) {
      // لا نُعلِّم العلم عند الفشل — سيُعاد المحاولة في الإقلاع التالي.
      debugPrint('⚠️ TimezoneFixReschedule v1: فشلت إعادة الجدولة: $e');
    }
  }
}
