import '../../../core/services/notification_service.dart';
import '../models/hifz_models.dart';

// ════════════════════════════════════════════════════════════════
//  HifzReminderScheduler — تذكير الورد اليومي (Phase 6 polish note).
//
//  يعيش خارج hifz_scheduler.dart عمداً: hifz_scheduler.dart نقيّ
//  بالكامل (بلا Hive/Riverpod/إشعارات — plan_hifz.md §3)، بينما هذا
//  الملف يستدعي NotificationService (I/O حقيقي). إدخال أي اعتمادية
//  إشعارات داخل hifz_scheduler.dart كان سيكسر تلك النقاوة المتعمَّدة؛
//  لذلك أُفرِد له ملف خاص صغير، يُستدعى من طبقة الـ providers فقط
//  (hifz_settings_provider.dart وhifz_provider.dart)، تماماً كما يُستدعى
//  HifzService من تلك الطبقة نفسها ولا يُستدعى مباشرة من الواجهة.
//
//  آلية الجدولة: matchDateTimeComponents: DateTimeComponents.time في
//  NotificationService.scheduleDailyReminder تجعل نظام التشغيل يُكرِّر
//  الإشعار تلقائياً كل يوم في نفس الساعة/الدقيقة دون أي تدخّل لاحق من
//  التطبيق — مطابقة لما يفعله NotificationService بالفعل لصلاة الفجر/
//  السحور/الإفطار، إلا أن وقت الورد ثابت (لا يتغيّر يومياً مع الفلك)
//  فلا حاجة لإعادة حساب يومية كتلك الميزات.
//
//  كبت تذكير اليوم عند تحقّق الورد: flutter_local_notifications لا
//  يوفّر "ألغِ نسخة اليوم فقط من سلسلة متكرّرة" — الإلغاء بالمعرّف
//  يُلغي السلسلة كاملة. الحل المعتمَد هنا: reschedule() تُستدعى في كل
//  مرة يتغيّر فيها احتمال "هل تحقّق الورد اليوم؟" (من hifzProvider،
//  حصراً أثناء تشغيل التطبيق فعلياً — وهذا مضمون دائماً لأن تحقّق
//  الورد لا يحدث إلا عبر إجراء داخل التطبيق نفسه، لا في الخلفية)،
//  فتُلغي السلسلة الحالية وتُعيد جدولتها بحيث يكون أول إطلاق فعلي هو
//  الغد إن كان الورد قد تحقّق اليوم بالفعل — فيُكبَت إشعار اليوم فعلياً
//  دون أن ينقطع التذكير في الأيام التالية.
// ════════════════════════════════════════════════════════════════

/// معرّف إشعار تذكير الورد اليومي — خارج نطاق كل المعرّفات الأخرى
/// المستخدَمة في NotificationService (100–302) تفادياً لأي تصادم.
const int kHifzWirdReminderNotificationId = 900;

class HifzReminderScheduler {
  HifzReminderScheduler._();

  /// يحسب أول موعد إطلاق فعلي: اليوم في الساعة/الدقيقة المحدَّدة إن
  /// لم يحن الوقت بعد ولم يتحقّق الورد اليوم بعد، وإلا غداً في نفس
  /// الساعة/الدقيقة. دالة نقية بالكامل — قابلة للاختبار مباشرة.
  static DateTime computeNextFireDate({
    required int hour,
    required int minute,
    required bool wirdMetToday,
    required DateTime now,
  }) {
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (wirdMetToday || !target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  /// يُلغي أي جدولة سابقة دائماً أولاً (لا تكرار/تراكم)، ثم يُعيد
  /// الجدولة فقط إن كان التذكير مفعَّلاً في الإعدادات — محترماً حالة
  /// "الورد تحقّق اليوم بالفعل" بكبت إطلاق اليوم (انظر التعليق أعلاه).
  static Future<void> reschedule({
    required HifzSettings settings,
    required bool wirdMetToday,
    DateTime? now,
  }) async {
    await NotificationService().cancel(kHifzWirdReminderNotificationId);
    if (!settings.wirdReminderEnabled) return;

    final fireDate = computeNextFireDate(
      hour: settings.wirdReminderHour,
      minute: settings.wirdReminderMinute,
      wirdMetToday: wirdMetToday,
      now: now ?? DateTime.now(),
    );

    await NotificationService().scheduleDailyReminder(
      id: kHifzWirdReminderNotificationId,
      title: 'ورد الحفظ اليومي',
      // نص ثابت عام وليس ديناميكياً: الجدولة تتم مسبقاً (أحياناً ليوم
      // كامل قدماً) عبر zonedSchedule، وflutter_local_notifications لا
      // يوفّر آلية لحساب محتوى الإشعار لحظة إطلاقه الفعلي — أي رقم
      // ("تبقى عليك N صفحة") كان سيصبح على الأرجح غير دقيق (بالياً) عند
      // وصول الإشعار فعلياً، فاختير نص تشجيعي عام بدلاً من ذلك.
      body: 'لا تنسَ ورد الحفظ اليوم 🌙',
      firstFireTime: fireDate,
    );
  }

  /// إلغاء تذكير الورد نهائياً (تعطيل الإعداد، أو مسح كل بيانات الحفظ).
  static Future<void> cancel() => NotificationService().cancel(kHifzWirdReminderNotificationId);
}
