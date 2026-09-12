import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ════════════════════════════════════════════════════════════════
//  VerseOfDayState — حالة آية اليوم فقط
// ════════════════════════════════════════════════════════════════

class VerseOfDayState {
  const VerseOfDayState({
    this.verseTitle = '',
    this.verseOfDay = '',
    this.verseReference = '',
    this.isLoading = true,
    this.isOffline = false,
  });

  final String verseTitle;
  final String verseOfDay;
  final String verseReference;
  final bool isLoading;
  final bool isOffline;

  VerseOfDayState copyWith({
    String? verseTitle,
    String? verseOfDay,
    String? verseReference,
    bool? isLoading,
    bool? isOffline,
  }) {
    return VerseOfDayState(
      verseTitle: verseTitle ?? this.verseTitle,
      verseOfDay: verseOfDay ?? this.verseOfDay,
      verseReference: verseReference ?? this.verseReference,
      isLoading: isLoading ?? this.isLoading,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  VerseOfDayNotifier
// ════════════════════════════════════════════════════════════════
class VerseOfDayNotifier extends StateNotifier<VerseOfDayState> {
  VerseOfDayNotifier() : super(const VerseOfDayState()) {
    _init();
  }

  static const _cacheBoxName = 'verse_cache_v2';
  Box<Map>? _cacheBox;
  StreamSubscription<DocumentSnapshot>? _verseSubscription;
  Timer? _timeoutTimer;

  Future<void> _init() async {
    try {
      _cacheBox = await Hive.openBox<Map>(_cacheBoxName);

      // ✅ 1. عرض الكاش فوراً (بدون انتظار Firebase)
      final hasCachedData = _loadFromCache();

      if (!hasCachedData) {
        // ✅ FIX 1: إضافة isLoading: false في الـ else
        // لا كاش → نص افتراضي + isLoading: false
        state = state.copyWith(
          verseTitle: 'آية اليوم',
          verseOfDay:
              'شَهْرُ رَمَضَانَ الَّذِي أُنزِلَ فِيهِ الْقُرْآنُ هُدًى لِّلنَّاسِ',
          verseReference: 'البقرة: ١٨٥',
          isLoading: false, // ✅ FIX: كان ناقصاً — isLoading تبقى true بدونه
        );
      }

      // ✅ 2. Stream حي من Firebase (في الخلفية دائماً)
      _setupRealtimeListener();
    } catch (e) {
      debugPrint('خطأ في تهيئة VerseOfDayNotifier: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // ── 1. تحميل من الكاش المحلي ──────────────────────────────────
  bool _loadFromCache() {
    try {
      final cached = _cacheBox?.get('daily');
      if (cached == null) return false;

      // ✅ FIX: استخدام toString() بدل cast مباشر لتجنب CastError في Hive
      final title = cached['title']?.toString() ?? '';
      final verse = cached['verseOfDay']?.toString() ?? '';
      final ref   = cached['verseReference']?.toString() ?? '';

      // ✅ title اختياري — الافتراضي "آية اليوم" يكفي. المهم verse + reference فقط
      if (verse.isEmpty || ref.isEmpty) return false;
      final effectiveTitle = title.isEmpty ? 'آية اليوم' : title;

      state = state.copyWith(
        verseTitle: effectiveTitle,
        verseOfDay: verse,
        verseReference: ref,
        isLoading: false,
      );

      debugPrint('✅ Verse loaded from cache: $effectiveTitle');
      return true;
    } catch (e) {
      debugPrint('خطأ في تحميل كاش الآية: $e');
      return false;
    }
  }

  // ── 2. Stream حي من Firebase ──────────────────────────────────
  void _setupRealtimeListener() {
    _timeoutTimer?.cancel();

    // timeout فقط للتحميل الأولي
    if (state.isLoading) {
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (state.isLoading) {
          state = state.copyWith(isLoading: false, isOffline: true);
        }
      });
    }

    _verseSubscription?.cancel();

    // ✅ FIX 2: حذف includeMetadataChanges: true — كان يُشغّل الـ stream مرتين
    // (مرة من local Firebase cache ومرة من server) مما يتداخل مع منطق التحديث
    _verseSubscription = FirebaseFirestore.instance
        .collection('app_config')
        .doc('daily')
        .snapshots() // ✅ FIX: بدون includeMetadataChanges
        .listen(
          (snapshot) {
            _timeoutTimer?.cancel();
            if (!snapshot.exists || snapshot.data() == null) return;

            debugPrint('📡 آية اليوم: snapshot من Firebase');
            _handleVerseUpdate(snapshot.data()!);
          },
          onError: (error) {
            _timeoutTimer?.cancel();
            debugPrint('خطأ في stream الآية: $error');

            if (state.verseOfDay.isEmpty) {
              state = state.copyWith(isLoading: false, isOffline: true);
            } else {
              debugPrint('⚠️ خطأ في المزامنة لكن الكاش متوفر، تجاهل الخطأ');
            }
          },
        );
  }

  // ── معالجة تحديث الآية من Firebase ────────────────────────────
  void _handleVerseUpdate(Map<String, dynamic> data) {
    try {
      final title = data['title']?.toString() ?? '';
      final verse = data['verseOfDay']?.toString() ?? '';
      final ref   = data['verseReference']?.toString() ?? '';

      // ✅ title اختياري — لا نرفض التحديث لو ناقص، نستخدم الافتراضي
      if (verse.isEmpty || ref.isEmpty) {
        debugPrint('⚠️ بيانات ناقصة من Firebase — verseOfDay أو verseReference فارغ');
        return;
      }
      final effectiveTitle = title.isEmpty ? 'آية اليوم' : title;

      // ✅ FIX 3: حذف equality check كلياً
      // كان يمنع التحديث لو Firebase أرجع نفس النص الافتراضي
      // والأهم: كان يمنع حفظ البيانات في الكاش → يسبب مشكلة في الفتح التالي
      debugPrint('🔄 آية اليوم: تحديث من Firebase');
      debugPrint('   العنوان: $effectiveTitle');
      debugPrint('   المرجع: $ref');

      // ✅ دائماً احفظ في الكاش عند كل تحديث من Firebase
      _cacheBox?.put('daily', {
        'title': effectiveTitle,
        'verseOfDay': verse,
        'verseReference': ref,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // ✅ دائماً حدّث الحالة
      state = state.copyWith(
        verseTitle: effectiveTitle,
        verseOfDay: verse,
        verseReference: ref,
        isLoading: false,
        isOffline: false,
      );
    } catch (e) {
      debugPrint('خطأ في معالجة تحديث الآية: $e');
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _verseSubscription?.cancel();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════
final verseOfDayProvider =
    StateNotifierProvider<VerseOfDayNotifier, VerseOfDayState>((ref) {
  return VerseOfDayNotifier();
});