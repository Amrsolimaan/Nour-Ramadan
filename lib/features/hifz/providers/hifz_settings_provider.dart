import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/hifz_service.dart';
import '../../../core/services/notification_permission_service.dart';
import '../logic/hifz_reminder_scheduler.dart';
import '../logic/hifz_scheduler.dart';
import '../models/hifz_models.dart';
import 'hifz_provider.dart';

// ════════════════════════════════════════════════════════════════
//  hifzSettingsProvider — إعدادات ورد الحفظ/المراجعة
//  قابلة للتعديل الحر في أي وقت (plan_hifz.md §2.3 + §3.4). التغيير
//  لا يُعدِّل أي HifzPageState إطلاقاً — فقط يُطبَّق على جدول الغد.
// ════════════════════════════════════════════════════════════════

class HifzSettingsNotifier extends StateNotifier<HifzSettings> {
  HifzSettingsNotifier(this._ref) : super(HifzService.loadSettings());

  final Ref _ref;

  /// تحديث الإعدادات يدوياً (شاشة إعدادات الحفظ — مرحلة لاحقة).
  /// يكتب في Hive، يُطبِّق onSettingsChanged (تثبيت مؤشر المراجعة
  /// الدورية فقط) على البيانات الوصفية، ثم يطلب من hifzProvider
  /// إعادة التحميل ليبقى متزامناً.
  Future<void> update(HifzSettings next) async {
    await HifzService.saveSettings(next);
    state = next;

    final pages = HifzService.loadPages();
    final meta = HifzService.loadMeta();
    final clampedMeta = HifzScheduler.onSettingsChanged(
      pages: pages,
      meta: meta,
      settings: next,
    );
    if (!identical(clampedMeta, meta)) {
      await HifzService.saveMeta(clampedMeta);
    }

    // يُبقي حالة hifzProvider (قائمة اليوم المشتقة منها) متوافقة مع
    // الإعدادات الجديدة دون الحاجة لإعادة بناء التطبيق بالكامل.
    if (_ref.exists(hifzProvider)) {
      await _ref.read(hifzProvider.notifier).reload();
    }

    // ✅ تذكير الورد اليومي: أي تغيير في الإعدادات (وقت التذكير، تفعيله/
    // تعطيله، أو حتى تغيير أهداف الورد نفسها التي تُحدِّد "هل تحقّق
    // اليوم؟") يُعاد حسابه هنا — إلغاء الجدولة القديمة وإعادة الجدولة
    // دائماً (بلا تكرار/تراكم)، مع كبت إشعار اليوم إن كان الورد متحقّقاً
    // بالفعل بحسب الإعدادات الجديدة.
    await HifzReminderScheduler.reschedule(
      settings: next,
      wirdMetToday: HifzScheduler.isWirdMet(next, clampedMeta.todayNewPages, clampedMeta.todayReviewPages),
    );
  }

  /// تحديث تذكير الورد اليومي تحديداً — تطلب إذن الإشعارات أولاً عند
  /// التفعيل إن لم يكن ممنوحاً (تُعيد استخدام تدفّق الإذن الموجود أصلاً
  /// في NotificationPermissionService/NotificationService، لا تدفّقاً
  /// موازياً)؛ إن رُفض الإذن، لا يُفعَّل التذكير. التغييرات الفعلية على
  /// HifzSettings + الجدولة تمرّ عبر update أعلاه — لا منطق مكرَّر هنا.
  ///
  /// تُعيد true إن نجح التحديث (سواء التفعيل أم التعطيل)، وfalse إن
  /// رُفض إذن الإشعارات عند محاولة التفعيل.
  Future<bool> setWirdReminder({bool? enabled, int? hour, int? minute}) async {
    final wantsEnabled = enabled ?? state.wirdReminderEnabled;

    if (wantsEnabled && !(await NotificationPermissionService.hasPermission())) {
      final granted = await NotificationPermissionService.requestPermission();
      if (!granted) return false;
    }

    await update(
      state.copyWith(
        wirdReminderEnabled: wantsEnabled,
        wirdReminderHour: hour,
        wirdReminderMinute: minute,
      ),
    );
    return true;
  }

  /// تُستدعى داخلياً من hifzProvider عند تصعيد/تراجع مقدار المراجعة
  /// الدورية تلقائياً بعد اكتمال دورة (§3.3) — تكتب فقط، دون إعادة
  /// تحميل hifzProvider (الذي هو من يستدعيها أصلاً).
  Future<void> applyEscalated(HifzSettings next) async {
    await HifzService.saveSettings(next);
    state = next;
  }

  /// إعادة الحالة في الذاكرة إلى القيم الافتراضية فقط — تُستخدم بعد
  /// HifzService.clearAll() (منطقة الخطر في شاشة إعدادات الحفظ —
  /// المرحلة 5) لإبقاء هذا الـ notifier متوافقاً مع صندوق Hive الفارغ
  /// الآن دون كتابة إضافية: غياب مفتاح الإعدادات في Hive يعني
  /// الافتراضي أصلاً (loadSettings يرجعه بنفسه عند التحميل التالي).
  void resetToDefaults() {
    state = const HifzSettings();
    // الافتراضي wirdReminderEnabled=false، فنُلغي أي جدولة قديمة كانت
    // قائمة قبل المسح الشامل (منطقة الخطر في شاشة إعدادات الحفظ).
    HifzReminderScheduler.cancel();
  }
}

final hifzSettingsProvider = StateNotifierProvider<HifzSettingsNotifier, HifzSettings>(
  (ref) => HifzSettingsNotifier(ref),
);
