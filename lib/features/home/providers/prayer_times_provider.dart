import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/location_service.dart';

// ════════════════════════════════════════════════════════════════
//  PrayerTimesState — حالة أوقات الصلاة فقط
// ════════════════════════════════════════════════════════════════

class PrayerTimesState {
  const PrayerTimesState({
    this.city = 'القاهرة',
    this.prayerName = '',
    this.prayerTimeLeft = '',
    this.prayerProgress = 0.0,
    this.isLoading = true,
  });

  final String city;
  final String prayerName;
  final String prayerTimeLeft;
  final double prayerProgress;
  final bool isLoading;

  PrayerTimesState copyWith({
    String? city,
    String? prayerName,
    String? prayerTimeLeft,
    double? prayerProgress,
    bool? isLoading,
  }) {
    return PrayerTimesState(
      city: city ?? this.city,
      prayerName: prayerName ?? this.prayerName,
      prayerTimeLeft: prayerTimeLeft ?? this.prayerTimeLeft,
      prayerProgress: prayerProgress ?? this.prayerProgress,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  PrayerTimesNotifier
// ════════════════════════════════════════════════════════════════
class PrayerTimesNotifier extends StateNotifier<PrayerTimesState> {
  PrayerTimesNotifier(this._location) : super(const PrayerTimesState()) {
    _init();
  }

  final LocationService _location;
  Timer? _timer;
  Timer? _locationWatcher; // ⏱ يراقب الموقع حتى يُتاح

  Future<void> _init() async {
    try {
      // تحميل الموقع المحفوظ
      await _location.loadSaved();

      // تحديث المدينة فوراً بعد التحميل
      state = state.copyWith(city: _location.city);

      _updatePrayer();

      // ✅ إذا لم يُحدَّد الموقع بعد (أول تثبيت أو تخطي)،
      // نراقب كل ثانية حتى يُتاح الموقع ثم نحدث العداد فوراً
      if (!_location.hasLocation) {
        _startLocationWatcher();
      }

      // تحديث أوقات الصلاة كل 30 ثانية
      _timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _updatePrayer(),
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('خطأ في تهيئة PrayerTimesNotifier: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // ── مراقبة الموقع حتى يُتاح ────────────────────────────────────
  void _startLocationWatcher() {
    _locationWatcher?.cancel();
    _locationWatcher = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_location.hasLocation) {
        t.cancel();
        _locationWatcher = null;
        _updatePrayer();
        debugPrint(
          '✅ PrayerTimesNotifier: الموقع مُتاح الآن — تم تحديث العداد',
        );
      }
    });
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

  // ── تحديث بعد تغيير المدينة ─────────────────────────────────────
  void refreshAfterCityChange() {
    // إذا كان المراقب شغّالاً، أوقفه — الموقع أصبح متاحاً
    _locationWatcher?.cancel();
    _locationWatcher = null;
    _updatePrayer();
    state = state.copyWith(city: _location.city);
  }

  // ── إعادة جدولة الإشعارات ─────────────────────────────────────
  Future<void> manualRescheduleNotifications() async {
    debugPrint('🔄 Manual reschedule requested from PrayerTimesProvider');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationWatcher?.cancel();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════
final prayerTimesProvider =
    StateNotifierProvider<PrayerTimesNotifier, PrayerTimesState>((ref) {
      return PrayerTimesNotifier(LocationService.instance);
    });
