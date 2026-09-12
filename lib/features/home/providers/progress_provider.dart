import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/services/quran_progress_service.dart';
import '../../../core/services/dua_tracking_service.dart';
import '../../../core/services/tasbih_tracking_service.dart';

// ════════════════════════════════════════════════════════════════
//  ProgressState — حالة التقدم فقط
// ════════════════════════════════════════════════════════════════

class ProgressState {
  const ProgressState({
    this.readSurahs = 0,
    this.duasRead = 0,
    this.tasbihCount = 0,
    this.isLoading = true,
  });

  final int readSurahs;
  final int duasRead;
  final int tasbihCount;
  final bool isLoading;

  ProgressState copyWith({
    int? readSurahs,
    int? duasRead,
    int? tasbihCount,
    bool? isLoading,
  }) {
    return ProgressState(
      readSurahs: readSurahs ?? this.readSurahs,
      duasRead: duasRead ?? this.duasRead,
      tasbihCount: tasbihCount ?? this.tasbihCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  ProgressNotifier
// ════════════════════════════════════════════════════════════════
class ProgressNotifier extends StateNotifier<ProgressState> {
  ProgressNotifier() : super(const ProgressState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      await _loadProgress();

      // الاستماع لتغييرات Hive
      _setupHiveListeners();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('خطأ في تهيئة ProgressNotifier: $e');
      state = state.copyWith(isLoading: false);
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

  // ── تحديث التقدم يدوياً ────────────────────────────────────────
  Future<void> refreshProgress() async {
    await _loadProgress();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════
final progressProvider =
    StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  return ProgressNotifier();
});
