import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/prayer_tracking_service.dart';

// ════════════════════════════════════════════════════════════════
//  PrayerTrackingState
// ════════════════════════════════════════════════════════════════

class PrayerTrackingState {
  final Map<String, bool> todayPrayers;
  final int todayCount;
  final int weeklyCount;
  final int monthlyCount;
  final int totalCount; // ← جديد: العدد الإجمالي
  final bool isLoading;

  const PrayerTrackingState({
    this.todayPrayers = const {},
    this.todayCount = 0,
    this.weeklyCount = 0,
    this.monthlyCount = 0,
    this.totalCount = 0, // ← جديد
    this.isLoading = true,
  });

  PrayerTrackingState copyWith({
    Map<String, bool>? todayPrayers,
    int? todayCount,
    int? weeklyCount,
    int? monthlyCount,
    int? totalCount, // ← جديد
    bool? isLoading,
  }) {
    return PrayerTrackingState(
      todayPrayers: todayPrayers ?? this.todayPrayers,
      todayCount: todayCount ?? this.todayCount,
      weeklyCount: weeklyCount ?? this.weeklyCount,
      monthlyCount: monthlyCount ?? this.monthlyCount,
      totalCount: totalCount ?? this.totalCount, // ← جديد
      isLoading: isLoading ?? this.isLoading,
    );
  }

  double get todayProgress => todayCount / 5.0;
}

// ════════════════════════════════════════════════════════════════
//  PrayerTrackingNotifier
// ════════════════════════════════════════════════════════════════

class PrayerTrackingNotifier extends StateNotifier<PrayerTrackingState> {
  PrayerTrackingNotifier() : super(const PrayerTrackingState()) {
    _load();
  }

  Future<void> _load() async {
    // ← جديد: فحص تغيير الوقت قبل التحميل
    await PrayerTrackingService.checkAndCleanupIfTimeChanged();
    
    final todayPrayers = <String, bool>{};
    for (final prayer in PrayerTrackingService.prayerNames) {
      todayPrayers[prayer] = await PrayerTrackingService.getPrayerStatus(prayer);
    }

    final todayCount = await PrayerTrackingService.getTodayPrayedCount();
    final weeklyCount = await PrayerTrackingService.getWeeklyPrayedCount();
    final monthlyCount = await PrayerTrackingService.getMonthlyPrayedCount();
    final totalCount = await PrayerTrackingService.getTotalPrayedCount(); // ← جديد

    state = PrayerTrackingState(
      todayPrayers: todayPrayers,
      todayCount: todayCount,
      weeklyCount: weeklyCount,
      monthlyCount: monthlyCount,
      totalCount: totalCount, // ← جديد
      isLoading: false,
    );
  }

  /// تبديل حالة صلاة
  Future<void> togglePrayer(String prayerName) async {
    final prayed = await PrayerTrackingService.togglePrayer(prayerName);
    
    final newTodayPrayers = Map<String, bool>.from(state.todayPrayers);
    newTodayPrayers[prayerName] = prayed;
    
    final newTodayCount = await PrayerTrackingService.getTodayPrayedCount();
    final newWeeklyCount = await PrayerTrackingService.getWeeklyPrayedCount();
    final newMonthlyCount = await PrayerTrackingService.getMonthlyPrayedCount();
    final newTotalCount = await PrayerTrackingService.getTotalPrayedCount(); // ← جديد

    state = state.copyWith(
      todayPrayers: newTodayPrayers,
      todayCount: newTodayCount,
      weeklyCount: newWeeklyCount,
      monthlyCount: newMonthlyCount,
      totalCount: newTotalCount, // ← جديد
    );
  }

  /// إعادة التحميل
  Future<void> reload() async {
    await _load();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════

final prayerTrackingProvider =
    StateNotifierProvider<PrayerTrackingNotifier, PrayerTrackingState>(
  (ref) => PrayerTrackingNotifier(),
);
