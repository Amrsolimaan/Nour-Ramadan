// ════════════════════════════════════════════════════════════════
//  hifz_models.dart — نماذج بيانات نظام تتبع الحفظ
//  التسلسل (serialization) يطابق نمط LastReadService/LastReadPosition
//  تماماً: enum → .name، DateTime → toIso8601String()، وكل fromMap
//  دفاعي (قيمة مفقودة/تالفة → قيمة افتراضية آمنة، لا يرمي استثناءً أبداً).
// ════════════════════════════════════════════════════════════════

// ── Enums ─────────────────────────────────────────────────────────

/// مرحلة حفظ الصفحة.
enum HifzStage { notStarted, newlyMemorized, underReview, mastered }

/// التقييم الذاتي بعد مراجعة صفحة.
enum HifzGrade { weak, medium, strong }

/// وحدة عرض/قياس مقدار الورد.
enum HifzPortionUnit { page, quarterHizb, halfHizb, hizb }

/// تفضيل نقطة بداية الحفظ الجديد (تُستخدم فقط كمُرشِّح للترتيب في
/// شاشة "حفظ جديد" — لا تؤثر على أي منطق تخزين أو جدولة).
enum HifzStartPreference { fromFatihah, fromJuzAmma, custom }

// ── مساعدات تسلسل دفاعية (خاصة بهذا الملف) ─────────────────────────

T _enumFrom<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is String) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
  }
  return fallback;
}

T? _enumFromOrNull<T extends Enum>(List<T> values, Object? raw) {
  if (raw is String) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
  }
  return null;
}

DateTime? _dateFrom(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

int _intFrom(Object? raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? fallback;
  return fallback;
}

double _doubleFrom(Object? raw, [double fallback = 0]) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? fallback;
  return fallback;
}

bool _boolFrom(Object? raw, [bool fallback = false]) => raw is bool ? raw : fallback;

List<int> _intListFrom(Object? raw) {
  if (raw is! List) return const [];
  final out = <int>[];
  for (final e in raw) {
    if (e is int) {
      out.add(e);
    } else if (e is num) {
      out.add(e.toInt());
    } else if (e is String) {
      final v = int.tryParse(e);
      if (v != null) out.add(v);
    }
  }
  return out;
}

/// قيمة حارسة (sentinel) لتمييز "لم يُمرَّر" عن "مُرِّر null صراحةً"
/// في copyWith للحقول القابلة للـ null.
const Object _undefined = Object();

// ── HifzPageState ───────────────────────────────────────────────
//  حالة صفحة واحدة (1..604) من صفحات المصحف.

class HifzPageState {
  final int page;
  final HifzStage stage;

  /// تاريخ أول حفظ لهذه الصفحة — لا يُعاد ضبطه أبداً بعد تحديده.
  final DateTime? firstMemorizedAt;
  final DateTime? lastReviewedAt;
  final int reviewCount;
  final HifzGrade? lastGrade;

  /// عدد التقييمات "قوي" المتتالية منذ آخر تقييم غير قوي.
  final int consecutiveStrong;

  /// متى بدأت المرحلة الحالية (stage) — يقود نافذة "حفظ حديث".
  final DateTime? stageEnteredAt;

  /// عدد دورات المراجعة الدورية المكتملة دون تقييم "ضعيف".
  final int farCyclesSurvived;

  /// إن كانت مضبوطة ولم تنتهِ بعد، تُدرِج الصفحة قسراً في قائمة
  /// التثبيت اليومية (تعافي بعد تقييم ضعيف).
  final DateTime? priorityUntil;

  const HifzPageState({
    required this.page,
    this.stage = HifzStage.notStarted,
    this.firstMemorizedAt,
    this.lastReviewedAt,
    this.reviewCount = 0,
    this.lastGrade,
    this.consecutiveStrong = 0,
    this.stageEnteredAt,
    this.farCyclesSurvived = 0,
    this.priorityUntil,
  });

  HifzPageState copyWith({
    HifzStage? stage,
    Object? firstMemorizedAt = _undefined,
    Object? lastReviewedAt = _undefined,
    int? reviewCount,
    Object? lastGrade = _undefined,
    int? consecutiveStrong,
    Object? stageEnteredAt = _undefined,
    int? farCyclesSurvived,
    Object? priorityUntil = _undefined,
  }) {
    return HifzPageState(
      page: page,
      stage: stage ?? this.stage,
      firstMemorizedAt: identical(firstMemorizedAt, _undefined)
          ? this.firstMemorizedAt
          : firstMemorizedAt as DateTime?,
      lastReviewedAt: identical(lastReviewedAt, _undefined)
          ? this.lastReviewedAt
          : lastReviewedAt as DateTime?,
      reviewCount: reviewCount ?? this.reviewCount,
      lastGrade: identical(lastGrade, _undefined) ? this.lastGrade : lastGrade as HifzGrade?,
      consecutiveStrong: consecutiveStrong ?? this.consecutiveStrong,
      stageEnteredAt: identical(stageEnteredAt, _undefined)
          ? this.stageEnteredAt
          : stageEnteredAt as DateTime?,
      farCyclesSurvived: farCyclesSurvived ?? this.farCyclesSurvived,
      priorityUntil: identical(priorityUntil, _undefined)
          ? this.priorityUntil
          : priorityUntil as DateTime?,
    );
  }

  Map<String, dynamic> toMap() => {
    'page': page,
    'stage': stage.name,
    'firstMemorizedAt': firstMemorizedAt?.toIso8601String(),
    'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    'reviewCount': reviewCount,
    'lastGrade': lastGrade?.name,
    'consecutiveStrong': consecutiveStrong,
    'stageEnteredAt': stageEnteredAt?.toIso8601String(),
    'farCyclesSurvived': farCyclesSurvived,
    'priorityUntil': priorityUntil?.toIso8601String(),
  };

  /// يبني الكائن من Map مخزَّنة في Hive — لا يرمي أبداً؛ بيانات
  /// تالفة أو ناقصة تُستبدل بقيم افتراضية آمنة (نفس نمط LastReadPosition.fromMap).
  static HifzPageState fromMap(Map? map, {required int page}) {
    if (map == null) return HifzPageState(page: page);
    return HifzPageState(
      page: page,
      stage: _enumFrom(HifzStage.values, map['stage'], HifzStage.notStarted),
      firstMemorizedAt: _dateFrom(map['firstMemorizedAt']),
      lastReviewedAt: _dateFrom(map['lastReviewedAt']),
      reviewCount: _intFrom(map['reviewCount']),
      lastGrade: _enumFromOrNull(HifzGrade.values, map['lastGrade']),
      consecutiveStrong: _intFrom(map['consecutiveStrong']),
      stageEnteredAt: _dateFrom(map['stageEnteredAt']),
      farCyclesSurvived: _intFrom(map['farCyclesSurvived']),
      priorityUntil: _dateFrom(map['priorityUntil']),
    );
  }

  @override
  String toString() =>
      'HifzPageState(page: $page, stage: ${stage.name}, reviewCount: $reviewCount)';
}

// ── HifzSettings ─────────────────────────────────────────────────
//  الورد اليومي — قابل للتعديل الحر في أي وقت (انظر plan_hifz.md §3.4).

class HifzSettings {
  final HifzPortionUnit newPortionUnit;
  final double newPortionCount;
  final HifzPortionUnit reviewPortionUnit;
  final double reviewPortionCount;
  final bool autoEscalateReview;
  final HifzPortionUnit reviewPortionMaxUnit;
  final int newlyMemorizedWindowDays;
  final int promoteAfterConsecutiveStrong;
  final int masterAfterFarCycles;
  final int weakRecoveryDays;
  final HifzStartPreference startPreference;
  final List<int> restWeekdays;
  final bool countReviewTowardWird;
  final bool countNewTowardWird;

  /// تفعيل تذكير الورد اليومي (إشعار محلي) — معطَّل افتراضياً (اختياري
  /// صراحةً من المستخدم)، نفس نهج suhoorReminderEnabled/iftarReminderEnabled
  /// في SettingsState الرئيسي للتطبيق.
  final bool wirdReminderEnabled;

  /// ساعة/دقيقة التذكير اليومي (24 ساعة) — افتراضياً 20:00 (8 مساءً)
  /// كوقت ثابت معقول لا يتطلّب أي ربط بأوقات الصلاة (plan_hifz.md
  /// Phase 6: "a simple fixed default time is acceptable").
  final int wirdReminderHour;
  final int wirdReminderMinute;

  final int schemaVersion;

  const HifzSettings({
    this.newPortionUnit = HifzPortionUnit.page,
    this.newPortionCount = 1,
    this.reviewPortionUnit = HifzPortionUnit.quarterHizb,
    this.reviewPortionCount = 1,
    this.autoEscalateReview = true,
    this.reviewPortionMaxUnit = HifzPortionUnit.hizb,
    this.newlyMemorizedWindowDays = 14,
    this.promoteAfterConsecutiveStrong = 7,
    this.masterAfterFarCycles = 3,
    this.weakRecoveryDays = 3,
    this.startPreference = HifzStartPreference.fromFatihah,
    this.restWeekdays = const [],
    this.countReviewTowardWird = true,
    this.countNewTowardWird = true,
    this.wirdReminderEnabled = false,
    this.wirdReminderHour = 20,
    this.wirdReminderMinute = 0,
    this.schemaVersion = 1,
  });

  HifzSettings copyWith({
    HifzPortionUnit? newPortionUnit,
    double? newPortionCount,
    HifzPortionUnit? reviewPortionUnit,
    double? reviewPortionCount,
    bool? autoEscalateReview,
    HifzPortionUnit? reviewPortionMaxUnit,
    int? newlyMemorizedWindowDays,
    int? promoteAfterConsecutiveStrong,
    int? masterAfterFarCycles,
    int? weakRecoveryDays,
    HifzStartPreference? startPreference,
    List<int>? restWeekdays,
    bool? countReviewTowardWird,
    bool? countNewTowardWird,
    bool? wirdReminderEnabled,
    int? wirdReminderHour,
    int? wirdReminderMinute,
    int? schemaVersion,
  }) {
    return HifzSettings(
      newPortionUnit: newPortionUnit ?? this.newPortionUnit,
      newPortionCount: newPortionCount ?? this.newPortionCount,
      reviewPortionUnit: reviewPortionUnit ?? this.reviewPortionUnit,
      reviewPortionCount: reviewPortionCount ?? this.reviewPortionCount,
      autoEscalateReview: autoEscalateReview ?? this.autoEscalateReview,
      reviewPortionMaxUnit: reviewPortionMaxUnit ?? this.reviewPortionMaxUnit,
      newlyMemorizedWindowDays: newlyMemorizedWindowDays ?? this.newlyMemorizedWindowDays,
      promoteAfterConsecutiveStrong:
          promoteAfterConsecutiveStrong ?? this.promoteAfterConsecutiveStrong,
      masterAfterFarCycles: masterAfterFarCycles ?? this.masterAfterFarCycles,
      weakRecoveryDays: weakRecoveryDays ?? this.weakRecoveryDays,
      startPreference: startPreference ?? this.startPreference,
      restWeekdays: restWeekdays ?? this.restWeekdays,
      countReviewTowardWird: countReviewTowardWird ?? this.countReviewTowardWird,
      countNewTowardWird: countNewTowardWird ?? this.countNewTowardWird,
      wirdReminderEnabled: wirdReminderEnabled ?? this.wirdReminderEnabled,
      wirdReminderHour: wirdReminderHour ?? this.wirdReminderHour,
      wirdReminderMinute: wirdReminderMinute ?? this.wirdReminderMinute,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
    'newPortionUnit': newPortionUnit.name,
    'newPortionCount': newPortionCount,
    'reviewPortionUnit': reviewPortionUnit.name,
    'reviewPortionCount': reviewPortionCount,
    'autoEscalateReview': autoEscalateReview,
    'reviewPortionMaxUnit': reviewPortionMaxUnit.name,
    'newlyMemorizedWindowDays': newlyMemorizedWindowDays,
    'promoteAfterConsecutiveStrong': promoteAfterConsecutiveStrong,
    'masterAfterFarCycles': masterAfterFarCycles,
    'weakRecoveryDays': weakRecoveryDays,
    'startPreference': startPreference.name,
    'restWeekdays': restWeekdays,
    'countReviewTowardWird': countReviewTowardWird,
    'countNewTowardWird': countNewTowardWird,
    'wirdReminderEnabled': wirdReminderEnabled,
    'wirdReminderHour': wirdReminderHour,
    'wirdReminderMinute': wirdReminderMinute,
    'schemaVersion': schemaVersion,
  };

  static HifzSettings fromMap(Map? map) {
    if (map == null) return const HifzSettings();
    const d = HifzSettings();
    return HifzSettings(
      newPortionUnit: _enumFrom(HifzPortionUnit.values, map['newPortionUnit'], d.newPortionUnit),
      newPortionCount: _doubleFrom(map['newPortionCount'], d.newPortionCount),
      reviewPortionUnit:
          _enumFrom(HifzPortionUnit.values, map['reviewPortionUnit'], d.reviewPortionUnit),
      reviewPortionCount: _doubleFrom(map['reviewPortionCount'], d.reviewPortionCount),
      autoEscalateReview: _boolFrom(map['autoEscalateReview'], d.autoEscalateReview),
      reviewPortionMaxUnit:
          _enumFrom(HifzPortionUnit.values, map['reviewPortionMaxUnit'], d.reviewPortionMaxUnit),
      newlyMemorizedWindowDays:
          _intFrom(map['newlyMemorizedWindowDays'], d.newlyMemorizedWindowDays),
      promoteAfterConsecutiveStrong:
          _intFrom(map['promoteAfterConsecutiveStrong'], d.promoteAfterConsecutiveStrong),
      masterAfterFarCycles: _intFrom(map['masterAfterFarCycles'], d.masterAfterFarCycles),
      weakRecoveryDays: _intFrom(map['weakRecoveryDays'], d.weakRecoveryDays),
      startPreference:
          _enumFrom(HifzStartPreference.values, map['startPreference'], d.startPreference),
      restWeekdays: _intListFrom(map['restWeekdays']),
      countReviewTowardWird: _boolFrom(map['countReviewTowardWird'], d.countReviewTowardWird),
      countNewTowardWird: _boolFrom(map['countNewTowardWird'], d.countNewTowardWird),
      wirdReminderEnabled: _boolFrom(map['wirdReminderEnabled'], d.wirdReminderEnabled),
      wirdReminderHour: _intFrom(map['wirdReminderHour'], d.wirdReminderHour).clamp(0, 23).toInt(),
      wirdReminderMinute: _intFrom(
        map['wirdReminderMinute'],
        d.wirdReminderMinute,
      ).clamp(0, 59).toInt(),
      schemaVersion: _intFrom(map['schemaVersion'], d.schemaVersion),
    );
  }
}

// ── HifzReviewSession ────────────────────────────────────────────
//  سجل جلسة مراجعة/حفظ واحدة — append-only، لعرضها في شاشة الإحصائيات.

class HifzReviewSession {
  final DateTime date;

  /// 'near' (تثبيت) | 'far' (مراجعة دورية) | 'new' (حفظ جديد)
  final String kind;
  final List<int> pages;
  final Map<int, HifzGrade> grades;
  final int? durationSec;

  const HifzReviewSession({
    required this.date,
    required this.kind,
    this.pages = const [],
    this.grades = const {},
    this.durationSec,
  });

  HifzReviewSession copyWith({
    List<int>? pages,
    Map<int, HifzGrade>? grades,
    int? durationSec,
  }) {
    return HifzReviewSession(
      date: date,
      kind: kind,
      pages: pages ?? this.pages,
      grades: grades ?? this.grades,
      durationSec: durationSec ?? this.durationSec,
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'kind': kind,
    'pages': pages,
    'grades': grades.map((k, v) => MapEntry(k.toString(), v.name)),
    'durationSec': durationSec,
  };

  static HifzReviewSession fromMap(Map? map) {
    if (map == null) {
      return HifzReviewSession(date: DateTime.now(), kind: 'near');
    }
    final rawGrades = map['grades'];
    final grades = <int, HifzGrade>{};
    if (rawGrades is Map) {
      rawGrades.forEach((k, v) {
        final page = int.tryParse(k.toString());
        final grade = _enumFromOrNull(HifzGrade.values, v);
        if (page != null && grade != null) grades[page] = grade;
      });
    }
    return HifzReviewSession(
      date: _dateFrom(map['date']) ?? DateTime.now(),
      kind: map['kind'] is String ? map['kind'] as String : 'near',
      pages: _intListFrom(map['pages']),
      grades: grades,
      durationSec: map['durationSec'] == null ? null : _intFrom(map['durationSec']),
    );
  }
}

// ── HifzMeta ──────────────────────────────────────────────────────
//  بيانات وصفية عامة: مؤشر دورة المراجعة الدورية + سلسلة المواظبة.

class HifzMeta {
  final DateTime createdAt;

  /// مؤشر الحلقة: رقم الصفحة التالية في دورة المراجعة الدورية.
  final int farReviewCursor;
  final int farCycleCount;

  /// متوسط تقييم آخر دورة مكتملة (0=ضعيف .. 2=قوي) — يقود التصعيد.
  final double lastCycleAvgGrade;
  final DateTime? lastActivityDate;

  /// آخر يوم تحقّق فيه "ورد اليوم" فعلاً (حفظ أو مراجعة بحسب الإعدادات)
  /// — يقود حساب سلسلة المواظبة بدقة (انظر plan_hifz.md §3.5).
  final DateTime? lastWirdMetDate;
  final int currentStreak;
  final int longestStreak;
  final int todayNewPages;
  final int todayReviewPages;
  final List<int> doneToday;
  final int schemaVersion;

  const HifzMeta({
    required this.createdAt,
    this.farReviewCursor = 1,
    this.farCycleCount = 0,
    this.lastCycleAvgGrade = 0,
    this.lastActivityDate,
    this.lastWirdMetDate,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.todayNewPages = 0,
    this.todayReviewPages = 0,
    this.doneToday = const [],
    this.schemaVersion = 1,
  });

  factory HifzMeta.initial() => HifzMeta(createdAt: DateTime.now());

  HifzMeta copyWith({
    int? farReviewCursor,
    int? farCycleCount,
    double? lastCycleAvgGrade,
    Object? lastActivityDate = _undefined,
    Object? lastWirdMetDate = _undefined,
    int? currentStreak,
    int? longestStreak,
    int? todayNewPages,
    int? todayReviewPages,
    List<int>? doneToday,
    int? schemaVersion,
  }) {
    return HifzMeta(
      createdAt: createdAt,
      farReviewCursor: farReviewCursor ?? this.farReviewCursor,
      farCycleCount: farCycleCount ?? this.farCycleCount,
      lastCycleAvgGrade: lastCycleAvgGrade ?? this.lastCycleAvgGrade,
      lastActivityDate: identical(lastActivityDate, _undefined)
          ? this.lastActivityDate
          : lastActivityDate as DateTime?,
      lastWirdMetDate: identical(lastWirdMetDate, _undefined)
          ? this.lastWirdMetDate
          : lastWirdMetDate as DateTime?,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      todayNewPages: todayNewPages ?? this.todayNewPages,
      todayReviewPages: todayReviewPages ?? this.todayReviewPages,
      doneToday: doneToday ?? this.doneToday,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
    'createdAt': createdAt.toIso8601String(),
    'farReviewCursor': farReviewCursor,
    'farCycleCount': farCycleCount,
    'lastCycleAvgGrade': lastCycleAvgGrade,
    'lastActivityDate': lastActivityDate?.toIso8601String(),
    'lastWirdMetDate': lastWirdMetDate?.toIso8601String(),
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'todayNewPages': todayNewPages,
    'todayReviewPages': todayReviewPages,
    'doneToday': doneToday,
    'schemaVersion': schemaVersion,
  };

  static HifzMeta fromMap(Map? map) {
    if (map == null) return HifzMeta.initial();
    return HifzMeta(
      createdAt: _dateFrom(map['createdAt']) ?? DateTime.now(),
      farReviewCursor: _intFrom(map['farReviewCursor'], 1),
      farCycleCount: _intFrom(map['farCycleCount']),
      lastCycleAvgGrade: _doubleFrom(map['lastCycleAvgGrade']),
      lastActivityDate: _dateFrom(map['lastActivityDate']),
      lastWirdMetDate: _dateFrom(map['lastWirdMetDate']),
      currentStreak: _intFrom(map['currentStreak']),
      longestStreak: _intFrom(map['longestStreak']),
      todayNewPages: _intFrom(map['todayNewPages']),
      todayReviewPages: _intFrom(map['todayReviewPages']),
      doneToday: _intListFrom(map['doneToday']),
      schemaVersion: _intFrom(map['schemaVersion'], 1),
    );
  }
}
