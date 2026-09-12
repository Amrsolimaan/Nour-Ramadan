import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/quran_progress_service.dart';

// ════════════════════════════════════════════════════════════════
//  QuranProgressState
// ════════════════════════════════════════════════════════════════

class QuranProgressState {
  final Set<int> readSurahs;
  final Set<int> readJuz;
  final int khatmahCount;
  final DateTime? lastKhatmahDate;
  final bool isLoading;

  const QuranProgressState({
    this.readSurahs = const {},
    this.readJuz = const {},
    this.khatmahCount = 0,
    this.lastKhatmahDate,
    this.isLoading = true,
  });

  QuranProgressState copyWith({
    Set<int>? readSurahs,
    Set<int>? readJuz,
    int? khatmahCount,
    DateTime? lastKhatmahDate,
    bool? isLoading,
  }) {
    return QuranProgressState(
      readSurahs: readSurahs ?? this.readSurahs,
      readJuz: readJuz ?? this.readJuz,
      khatmahCount: khatmahCount ?? this.khatmahCount,
      lastKhatmahDate: lastKhatmahDate ?? this.lastKhatmahDate,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get readSurahsCount => readSurahs.length;
  int get readJuzCount => readJuz.length;
  double get progress => readSurahs.length / 114.0;
  bool get isKhatmahComplete => readSurahs.length == 114;
}

// ════════════════════════════════════════════════════════════════
//  QuranProgressNotifier
// ════════════════════════════════════════════════════════════════

class QuranProgressNotifier extends StateNotifier<QuranProgressState> {
  QuranProgressNotifier() : super(const QuranProgressState()) {
    _load();
  }

  Future<void> _load() async {
    final readSurahs = await QuranProgressService.loadReadSurahs();
    final readJuz = await QuranProgressService.loadReadJuz();
    final khatmahCount = await QuranProgressService.loadKhatmahCount();
    final lastKhatmahDate = await QuranProgressService.loadLastKhatmahDate();

    state = QuranProgressState(
      readSurahs: readSurahs,
      readJuz: readJuz,
      khatmahCount: khatmahCount,
      lastKhatmahDate: lastKhatmahDate,
      isLoading: false,
    );
  }

  /// تبديل حالة سورة
  Future<void> toggleSurah(int surahNumber) async {
    final isRead = await QuranProgressService.toggleSurah(surahNumber);
    
    final newReadSurahs = Set<int>.from(state.readSurahs);
    if (isRead) {
      newReadSurahs.add(surahNumber);
    } else {
      newReadSurahs.remove(surahNumber);
    }

    // إذا أكمل 114 سورة، نحدث عداد الختمات
    if (newReadSurahs.length == 114) {
      final newCount = await QuranProgressService.loadKhatmahCount();
      final newDate = await QuranProgressService.loadLastKhatmahDate();
      state = state.copyWith(
        readSurahs: newReadSurahs,
        khatmahCount: newCount,
        lastKhatmahDate: newDate,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        readSurahs: newReadSurahs,
        isLoading: false,
      );
    }
  }

  /// تبديل حالة جزء
  Future<void> toggleJuz(int juzNumber) async {
    final isRead = await QuranProgressService.toggleJuz(juzNumber);
    
    final newReadJuz = Set<int>.from(state.readJuz);
    if (isRead) {
      newReadJuz.add(juzNumber);
    } else {
      newReadJuz.remove(juzNumber);
    }

    state = state.copyWith(
      readJuz: newReadJuz,
      isLoading: false,
    );
  }

  /// بدء ختمة جديدة
  Future<void> startNewKhatmah() async {
    await QuranProgressService.startNewKhatmah();
    state = state.copyWith(
      readSurahs: {},
      readJuz: {},
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

final quranProgressProvider =
    StateNotifierProvider<QuranProgressNotifier, QuranProgressState>(
  (ref) => QuranProgressNotifier(),
);
