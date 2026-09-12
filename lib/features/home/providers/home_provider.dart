import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/quran_progress_service.dart';
import '../../../core/services/dua_tracking_service.dart';
import '../../../core/services/tasbih_tracking_service.dart';

// ════════════════════════════════════════════════════════════════
//  HomeState — حالة شاشة الرئيسية
// ════════════════════════════════════════════════════════════════

enum HomeLoadingState {
  initial,  // أول مرة
  cached,   // محمّل من الكاش
  syncing,  // يزامن في الخلفية
  error,    // خطأ
  offline,  // بدون نت
}

class HomeState {
  const HomeState({
    this.hijriDate = '',
    this.gregorianDate = '',
    this.city = 'القاهرة',
    this.prayerName = '',
    this.prayerTimeLeft = '',
    this.prayerProgress = 0.0,
    this.verseTitle = '',
    this.verseOfDay = '',
    this.verseReference = '',
    this.loadingState = HomeLoadingState.initial,
    this.isOffline = false,
    this.completedDays = 0,
    this.totalDays = 30,
    this.readSurahs = 0,
    this.duasRead = 0,
    this.tasbihCount = 0,
    this.hijriMonth = 1,
    this.hijriYear = 1446,
    this.laylatQadrEnabled = true,
  });

  final String hijriDate;
  final String gregorianDate;
  final String city;
  final String prayerName;
  final String prayerTimeLeft;
  final double prayerProgress;
  final String verseTitle;
  final String verseOfDay;
  final String verseReference;
  final HomeLoadingState loadingState;
  final bool isOffline;
  final int completedDays;
  final int totalDays;
  final int readSurahs;
  final int duasRead;
  final int tasbihCount;
  final int hijriMonth;
  final int hijriYear;
  final bool laylatQadrEnabled;

  // ── للتوافق مع الكود القديم ──────────────────────────────────
  bool get isLoading => loadingState == HomeLoadingState.initial;

  HomeState copyWith({
    String? hijriDate,
    String? gregorianDate,
    String? city,
    String? prayerName,
    String? prayerTimeLeft,
    double? prayerProgress,
    String? verseTitle,
    String? verseOfDay,
    String? verseReference,
    HomeLoadingState? loadingState,
    bool? isOffline,
    int? completedDays,
    int? totalDays,
    int? readSurahs,
    int? duasRead,
    int? tasbihCount,
    int? hijriMonth,
    int? hijriYear,
    bool? laylatQadrEnabled,
  }) {
    return HomeState(
      hijriDate: hijriDate ?? this.hijriDate,
      gregorianDate: gregorianDate ?? this.gregorianDate,
      city: city ?? this.city,
      prayerName: prayerName ?? this.prayerName,
      prayerTimeLeft: prayerTimeLeft ?? this.prayerTimeLeft,
      prayerProgress: prayerProgress ?? this.prayerProgress,
      verseTitle: verseTitle ?? this.verseTitle,
      verseOfDay: verseOfDay ?? this.verseOfDay,
      verseReference: verseReference ?? this.verseReference,
      loadingState: loadingState ?? this.loadingState,
      isOffline: isOffline ?? this.isOffline,
      completedDays: completedDays ?? this.completedDays,
      totalDays: totalDays ?? this.totalDays,
      readSurahs: readSurahs ?? this.readSurahs,
      duasRead: duasRead ?? this.duasRead,
      tasbihCount: tasbihCount ?? this.tasbihCount,
      hijriMonth: hijriMonth ?? this.hijriMonth,
      hijriYear: hijriYear ?? this.hijriYear,
      laylatQadrEnabled: laylatQadrEnabled ?? this.laylatQadrEnabled,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  HomeNotifier
// ════════════════════════════════════════════════════════════════
class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier(this._firebase, this._location) : super(const HomeState()) {
    _init();
  }

  final FirebaseService _firebase;
  final LocationService _location;
  Timer? _timer;

  // ── كاش الآية بنفس أسلوب messages_provider ───────────────────
  static const _cacheBoxName = 'verse_cache_v2'; // v2 لتجنب تعارض الكاش القديم
  static const _featuresCacheBoxName = 'features_cache_v1'; // كاش للميزات
  Box<Map>? _cacheBox;
  Box<Map>? _featuresCacheBox;
  StreamSubscription<DocumentSnapshot>? _verseSubscription;
  StreamSubscription<DocumentSnapshot>? _featuresSubscription;
  Timer? _timeoutTimer;

  Future<void> _init() async {
    try {
      // فتح كاش منظم (Map) زي messages_provider
      _cacheBox = await Hive.openBox<Map>(_cacheBoxName);
      _featuresCacheBox = await Hive.openBox<Map>(_featuresCacheBoxName);

      // تحميل الموقع المحفوظ
      await _location.loadSaved();

      _loadDates();
      _updatePrayer();
      await _loadProgress();

      // ✅ 1. عرض الكاش فوراً (بدون انتظار Firebase)
      final hasCachedData = _loadFromCache();
      _loadFeaturesFromCache(); // تحميل الميزات من الكاش

      if (hasCachedData) {
        // كاش موجود → عرض فوري
        state = state.copyWith(
          loadingState: HomeLoadingState.cached,
          city: _location.city,
        );
      } else {
        // لا كاش → نص افتراضي + انتظار Firebase
        state = state.copyWith(
          verseTitle: 'آية اليوم',
          verseOfDay:
              'شَهْرُ رَمَضَانَ الَّذِي أُنزِلَ فِيهِ الْقُرْآنُ هُدًى لِّلنَّاسِ',
          verseReference: 'البقرة: ١٨٥',
          city: _location.city,
        );
      }

      // ✅ 2. Stream حي من Firebase (في الخلفية دائماً)
      _setupRealtimeListener();
      _setupFeaturesListener();

      // تحديث أوقات الصلاة كل 30 ثانية
      _timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _updatePrayer(),
      );

      // تحديث التاريخ كل ساعة
      Timer.periodic(const Duration(hours: 1), (_) => _loadDates());

      // الاستماع لتغييرات Hive
      _setupHiveListeners();
    } catch (e) {
      debugPrint('خطأ في تهيئة HomeNotifier: $e');
      state = state.copyWith(
        loadingState: HomeLoadingState.error,
        city: _location.city,
      );
    }
  }

  // ── 1. تحميل من الكاش المحلي (نفس أسلوب messages_provider) ──
  bool _loadFromCache() {
    try {
      final cached = _cacheBox?.get('daily');
      if (cached == null) return false;

      final title = cached['title'] as String? ?? '';
      final verse = cached['verseOfDay'] as String? ?? '';
      final ref   = cached['verseReference'] as String? ?? '';

      if (verse.isEmpty || ref.isEmpty) return false;
      final effectiveTitle = title.isEmpty ? 'آية اليوم' : title;

      state = state.copyWith(
        verseTitle: effectiveTitle,
        verseOfDay: verse,
        verseReference: ref,
        loadingState: HomeLoadingState.cached,
      );

      return true;
    } catch (e) {
      debugPrint('خطأ في تحميل كاش الآية: $e');
      return false;
    }
  }

  // ── تحميل الميزات من الكاش ─────────────────────────────────
  bool _loadFeaturesFromCache() {
    try {
      final cached = _featuresCacheBox?.get('features');
      if (cached == null) return false;

      final laylatQadrEnabled = cached['laylatQadrEnabled'] as bool? ?? true;

      state = state.copyWith(
        laylatQadrEnabled: laylatQadrEnabled,
      );

      debugPrint('✅ تم تحميل الميزات من الكاش: laylatQadr=$laylatQadrEnabled');
      return true;
    } catch (e) {
      debugPrint('خطأ في تحميل كاش الميزات: $e');
      return false;
    }
  }

  // ── 2. Stream حي من Firebase (نفس أسلوب messages_provider) ───
  void _setupRealtimeListener() {
    _timeoutTimer?.cancel();

    // timeout فقط للتحميل الأولي
    if (state.loadingState == HomeLoadingState.initial) {
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (state.loadingState == HomeLoadingState.initial) {
          state = state.copyWith(
            loadingState: HomeLoadingState.offline,
            isOffline: true,
          );
        }
      });
    }

    _verseSubscription?.cancel();

    _verseSubscription = FirebaseFirestore.instance
        .collection('app_config')
        .doc('daily')
        .snapshots(includeMetadataChanges: true) // ✅ نحتاج metadata لمعرفة المصدر
        .listen(
          (snapshot) {
            _timeoutTimer?.cancel();
            if (!snapshot.exists) return;
            
            // ✅ تشخيص: معرفة مصدر البيانات
            final isFromCache = snapshot.metadata.isFromCache;
            
            debugPrint('📡 آية اليوم (HomeProvider) - من الكاش: $isFromCache');
            
            // ✅ الإصلاح: نقبل كل التحديثات، _handleVerseUpdate يفحص التكرار
            _handleVerseUpdate(snapshot.data()!, isFromCache);
          },
          onError: (error) {
            _timeoutTimer?.cancel();
            debugPrint('خطأ في stream الآية: $error');

            // إذا في كاش → تجاهل الخطأ واستمر في العرض
            if (state.verseOfDay.isEmpty) {
              state = state.copyWith(
                loadingState: HomeLoadingState.offline,
                isOffline: true,
              );
            } else {
              debugPrint('⚠️ خطأ في المزامنة لكن الكاش متوفر، تجاهل الخطأ');
            }
          },
        );
  }

  // ── معالجة تحديث الآية من Firebase ────────────────────────────
  void _handleVerseUpdate(Map<String, dynamic> data, bool isFromCache) {
    try {
      final title = data['title'] as String? ?? '';
      final verse = data['verseOfDay'] as String? ?? '';
      final ref   = data['verseReference'] as String? ?? '';

      if (verse.isEmpty || ref.isEmpty) return;
      final effectiveTitle = title.isEmpty ? 'آية اليوم' : title;

      // ✅ فحص إذا كانت البيانات مختلفة فعلاً (تجنب التحديثات المكررة)
      if (state.verseTitle == effectiveTitle && 
          state.verseOfDay == verse && 
          state.verseReference == ref) {
        debugPrint('📌 آية اليوم (HomeProvider): لا تغيير في البيانات');
        return;
      }

      debugPrint('🔄 آية اليوم (HomeProvider): تحديث ${isFromCache ? "(كاش)" : "(سيرفر)"}');

      // ✅ حفظ في الكاش كـ Map منظم (نفس أسلوب messages_provider)
      _cacheBox?.put('daily', {
        'title': effectiveTitle,
        'verseOfDay': verse,
        'verseReference': ref,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // تحديث الحالة فوراً
      state = state.copyWith(
        verseTitle: effectiveTitle,
        verseOfDay: verse,
        verseReference: ref,
        loadingState: HomeLoadingState.cached,
        isOffline: false,
      );
    } catch (e) {
      debugPrint('خطأ في معالجة تحديث الآية: $e');
    }
  }

  // ── Stream للميزات من Firebase ────────────────────────────────
  void _setupFeaturesListener() {
    _featuresSubscription?.cancel();

    _featuresSubscription = FirebaseFirestore.instance
        .collection('app_config')
        .doc('features')
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) {
              debugPrint('⚠️ مستند features غير موجود، استخدام القيم الافتراضية');
              return;
            }
            _handleFeaturesUpdate(snapshot.data()!);
          },
          onError: (error) {
            debugPrint('خطأ في stream الميزات: $error');
          },
        );
  }

  // ── معالجة تحديث الميزات من Firebase ───────────────────────────
  void _handleFeaturesUpdate(Map<String, dynamic> data) {
    try {
      final laylatQadrEnabled = data['laylatQadrEnabled'] as bool? ?? true;

      // ✅ حفظ في الكاش
      _featuresCacheBox?.put('features', {
        'laylatQadrEnabled': laylatQadrEnabled,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // تحديث الحالة فوراً
      state = state.copyWith(
        laylatQadrEnabled: laylatQadrEnabled,
      );

      debugPrint('✅ تم تحديث الميزات: laylatQadr=$laylatQadrEnabled');
    } catch (e) {
      debugPrint('خطأ في معالجة تحديث الميزات: $e');
    }
  }

  // ── الاستماع لتغييرات Hive ─────────────────────────────────
  void _setupHiveListeners() {
    QuranProgressService.getBox()?.listenable().addListener(() {
      _loadProgress();
    });

    DuaTrackingService.getBox()?.listenable().addListener(() {
      _loadProgress();
    });

    TasbihTrackingService.getBox()?.listenable().addListener(() {
      _loadProgress();
    });
  }

  // ── التاريخ ────────────────────────────────────────────────────
  void _loadDates() {
    final now = DateTime.now();

    HijriCalendar.setLocal('ar');
    final correctedDate = now.subtract(const Duration(days: 1));
    final hijri = HijriCalendar.fromDate(correctedDate);

    final weekdays = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final hijriMonths = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الثانية',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    int completedDays = 0;
    int totalDays = 30;

    debugPrint(
      '📅 التاريخ الهجري المحسوب: ${hijri.hDay} ${hijriMonths[hijri.hMonth - 1]} ${hijri.hYear}',
    );
    debugPrint('📅 الشهر الهجري: ${hijri.hMonth} (9 = رمضان)');
    debugPrint('📅 اليوم الهجري: ${hijri.hDay}');

    if (hijri.hMonth == 9) {
      completedDays = hijri.hDay;
      totalDays = 30;
      debugPrint(
        '✅ نحن في رمضان! اليوم: $completedDays/$totalDays (${(completedDays / totalDays * 100).toStringAsFixed(1)}%)',
      );
    } else if (hijri.hMonth > 9) {
      completedDays = 30;
      totalDays = 30;
      debugPrint('✅ رمضان انتهى: $completedDays/$totalDays');
    } else {
      debugPrint(
        '⏳ قبل رمضان (الشهر ${hijri.hMonth}): $completedDays/$totalDays',
      );
    }

    state = state.copyWith(
      hijriDate:
          '${hijri.hDay} ${hijriMonths[hijri.hMonth - 1]} ${hijri.hYear}',
      gregorianDate:
          '${weekdays[now.weekday % 7]}، ${now.day} ${months[now.month - 1]} ${now.year}',
      completedDays: completedDays,
      totalDays: totalDays,
      hijriMonth: hijri.hMonth,
      hijriYear: hijri.hYear,
    );
  }

  // ── أوقات الصلاة ────────────────────────────────────────────────
  void _updatePrayer() {
    try {
      final result = _location.nextPrayer();
      state = state.copyWith(
        prayerName: result.name,
        prayerTimeLeft: _location.formatTimeLeft(result.time),
        prayerProgress: result.progress,
        city: _location.city,
      );
    } catch (_) {
      state = state.copyWith(prayerName: '...');
    }
  }

  // ── تحميل التقدم ────────────────────────────────────────────────
  Future<void> _loadProgress() async {
    try {
      final readSurahs = await QuranProgressService.getReadSurahsCount();
      final duasRead = await DuaTrackingService.getTotalDuasCount();
      final tasbihCount = await TasbihTrackingService.getAllTimeCount();

      state = state.copyWith(
        readSurahs: readSurahs,
        duasRead: duasRead,
        tasbihCount: tasbihCount,
      );
    } catch (e) {
      debugPrint('خطأ في تحميل التقدم: $e');
    }
  }

  // ── تحديث بعد تغيير المدينة ─────────────────────────────────────
  void refreshAfterCityChange() {
    _updatePrayer();
    state = state.copyWith(city: _location.city);
  }

  // ── تحديث التقدم يدوياً ────────────────────────────────────────
  Future<void> refreshProgress() async {
    await _loadProgress();
  }

  // ── إعادة جدولة الإشعارات ─────────────────────────────────────
  Future<void> manualRescheduleNotifications() async {
    debugPrint('🔄 Manual reschedule requested from HomeProvider');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeoutTimer?.cancel();
    _verseSubscription?.cancel();
    _featuresSubscription?.cancel();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════
//  Providers
// ════════════════════════════════════════════════════════════════
final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(FirebaseService.instance, LocationService.instance);
});