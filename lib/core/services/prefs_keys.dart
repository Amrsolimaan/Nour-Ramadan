// ════════════════════════════════════════════════════════════════
//  PrefKeys — العقد الموحّد لمفاتيح SharedPreferences بين Dart و Kotlin
//
//  ⚠️ قاعدة حرجة — لا تكتب 'flutter.' يدوياً في أي مفتاح ⚠️
//
//  حزمة shared_preferences تُضيف البادئة 'flutter.' تلقائياً لكل مفتاح
//  تحفظه (راجع shared_preferences/lib/src/shared_preferences_legacy.dart:
//  `static String _prefix = 'flutter.'` ثم `'$_prefix$key'`).
//
//  لذلك:
//    Dart: setString('last_lat', v)            → مفتاح Android: flutter.last_lat        ✅
//    Dart: setString('flutter.last_lat', v)    → مفتاح Android: flutter.flutter.last_lat ❌
//
//  الكود الناتيف (AlarmScheduler.kt, AzanWorker.kt, AzanBootReceiver.kt ...)
//  يقرأ "flutter.last_lat" مباشرةً من SharedPreferences الخام.
//  البادئة المزدوجة كانت تعني أن الناتيف لا يجد أي بيانات إطلاقاً —
//  وهو السبب الجذري لتوقّف الأذان عندما لا يُفتح التطبيق.
//  (راجع plan_azan_reliability.md §1.8)
//
//  استخدم الثوابت والدوال هنا بدلاً من كتابة المفاتيح نصّاً.
// ════════════════════════════════════════════════════════════════

/// مفاتيح SharedPreferences المشتركة مع طبقة Kotlin.
///
/// كل مفتاح يمرّ عبر [guard] الذي يفشل في وضع debug إذا احتوى المفتاح
/// على البادئة 'flutter.' يدوياً — لمنع تكرار الخطأ الجذري.
class PrefKeys {
  PrefKeys._();

  // ── الموقع (يقرأها AlarmScheduler.kt + AzanWorker.kt) ──────────
  static final String lastLat = guard('last_lat');
  static final String lastLng = guard('last_lng');

  // ── آخر صوت مؤذّن مجدول (fallback للناتيف) ────────────────────
  static final String lastSoundFileScheduled = guard(
    'last_sound_file_scheduled',
  );

  // ── بيانات الأذان لكل معرّف ───────────────────────────────────
  //  يقرأها: AzanBootReceiver, AzanWorker, AzanAlarmReceiver
  //  (AzanJobService حُذف في المرحلة 6 — لم يكن له أي مُستدعٍ فعلي)
  static const String azanPrefix = 'azan_';

  static String azanTime(int id) => guard('$azanPrefix${id}_time');
  static String azanPrayer(int id) => guard('$azanPrefix${id}_prayer');
  static String azanSound(int id) => guard('$azanPrefix${id}_sound');

  /// يطابق أي مفتاح أذان صحيح (بعد إزالة بادئة الحزمة تلقائياً).
  /// مثال: `azan_100_time`
  static final RegExp azanKeyPattern = RegExp(r'^azan_(\d+)_(time|prayer|sound)$');

  /// علم إتمام ترحيل المفاتيح المزدوجة البادئة (مرة واحدة فقط).
  /// ⚠️ لا يبدأ بـ [azanPrefix] حتى لا يُحتسب ضمن مفاتيح الأذان في التشخيص.
  static final String migrationV1Done = guard('prefs_migration_v1_done');

  // ── المرحلة 4: تنبيه إعفاء البطارية السياقي ────────────────────
  /// آخر مرّة رفض المستخدم شاشة إعفاء البطارية (millisecondsSinceEpoch كـ String).
  /// null = لم يُرفض إطلاقاً. راجع BatteryPromptService.
  static final String batteryPromptLastDeclinedAt = guard(
    'battery_prompt_last_declined_at',
  );

  // ── متابعة المرحلة 5: إعادة جدولة تذكير الورد بعد إصلاح التوقيت ──
  /// علم إتمام إعادة جدولة تذكير الورد اليومي مرّة واحدة بعد إصلاح
  /// المنطقة الزمنية (كانت مُسلَّحة مُسبقاً بمنطقة UTC خاطئة، فتُخطئ
  /// دورة تكرارها اليومية عبر أي حدّ توقيت صيفي/شتوي). راجع
  /// TimezoneFixRescheduleMigration و plan_azan_reliability.md §Phase 5.
  static final String timezoneFixRescheduleV1Done = guard(
    'timezone_fix_reschedule_v1_done',
  );

  // ── المرحلة 7 (iOS): النافذة المتدرّجة ──────────────────────────
  /// آخر تاريخ مُغطّى بالنافذة المتدرّجة (ISO 8601، تاريخ فقط بلا وقت).
  /// null = لا نافذة مُسلَّحة إطلاقاً بعد. راجع IosNotificationWindow.
  static final String iosWindowScheduledThroughDate = guard(
    'ios_window_scheduled_through_date',
  );

  // ── المرحلة 8: سطح التحقّق (Verification surface) ──────────────
  //  يقرأها system_diagnostics_service.dart لعرض شاشة تشخيص الأذان.
  //  مفاتيح السجلّ/الأفق/آخر تحديث يكتبها AlarmScheduler.kt مباشرةً
  //  بنفس هذه الأسماء (بالبادئة الواحدة الصريحة flutter. على جانب
  //  Kotlin الخام، مطابقةً لِما ينتجه guard() هنا على جانب Dart).
  /// سجلّ المعرّفات المُسلَّحة حالياً (CSV مفصول بفواصل) — Android فقط.
  static final String azanArmedIds = guard('azan_armed_ids');

  /// آخر لحظة نجح فيها AlarmScheduler.refresh() فعلياً (epoch ms كنص).
  static final String azanLastRefreshAt = guard('azan_last_refresh_at');

  /// نهاية الأفق الحالي المُسلَّح (epoch ms كنص) — Android فقط.
  static final String azanHorizonEndAt = guard('azan_horizon_end_at');

  /// آخر أذان (غير الشروق) أُطلق فعلياً — يكتبها AzanAlarmReceiver.kt
  /// عند الإطلاق مباشرة على أندرويد، ودالة استجابة النقر على إشعار
  /// الأذان في notification_service.dart على iOS (أقرب إشارة متاحة
  /// فعلياً لفلاتر هناك — راجع التعليق هناك لتوضيح الفرق بين "أُطلق"
  /// و"نُقر عليه" على iOS تحديداً).
  static final String azanLastFiredAt = guard('azan_last_fired_at');
  static final String azanLastFiredPrayer = guard('azan_last_fired_prayer');

  // ── وجهة التنقّل المعلّقة (Kotlin → Dart) ─────────────────────
  /// يكتبه الناتيف عند نقر إشعار الأذان/التذكير:
  ///   MainActivity.kt:151 و ReminderAlarmReceiver.kt:100
  ///   → `prefs.putString("flutter.pending_navigation", ...)` على الخزنة الخام.
  ///
  /// من Dart نستخدم الاسم بلا بادئة ليُصبح المخزَّن `flutter.pending_navigation`
  /// وهو نفس ما يكتبه الناتيف تماماً.
  ///
  /// ⚠️ سابقاً كان Dart يقرأه بـ 'flutter.pending_navigation' فيُترجَم إلى
  /// `flutter.flutter.pending_navigation` — فلم تكن كتابة الناتيف تصل أبداً،
  /// ولم يكن نقر الإشعار يفتح الشاشة الصحيحة.
  static final String pendingNavigation = guard('pending_navigation');

  // ════════════════════════════════════════════════════════════
  //  الحارس — يمنع إعادة إدخال خطأ البادئة المزدوجة
  // ════════════════════════════════════════════════════════════

  /// يتحقق من أن [key] لا يحمل البادئة 'flutter.' يدوياً.
  ///
  /// يفشل بصوتٍ عالٍ في وضع debug (assert)؛ ولا يؤثر على الأداء في release.
  /// يُعيد [key] كما هو ليُستخدم مباشرةً في موضع الاستدعاء.
  static String guard(String key) {
    assert(
      !key.startsWith('flutter.'),
      'مفتاح SharedPreferences غير صالح: "$key"\n'
      'حزمة shared_preferences تُضيف البادئة "flutter." تلقائياً.\n'
      'كتابتها يدوياً تُنتج "flutter.$key" وهو مفتاح لا تقرأه طبقة Kotlin أبداً.\n'
      'استخدم "${key.substring('flutter.'.length)}" بدلاً منه.\n'
      'راجع plan_azan_reliability.md §1.8',
    );
    return key;
  }
}
