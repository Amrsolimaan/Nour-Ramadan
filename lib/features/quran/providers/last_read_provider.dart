import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/last_read_service.dart';

// ════════════════════════════════════════════════════════════════
//  LastReadState — حالة "آخر قراءة" اليدوية فقط (شارة القائمة)
//  التلقائي أصبح في auto_resume_provider.dart منفصلاً
//  (منمذجة على QuranProgressState / quranProgressProvider)
// ════════════════════════════════════════════════════════════════

class LastReadState {
  final LastReadPosition? global;
  final Map<int, int> bySurah;
  final bool isLoading;

  const LastReadState({
    this.global,
    this.bySurah = const {},
    this.isLoading = true,
  });

  LastReadState copyWith({
    LastReadPosition? global,
    Map<int, int>? bySurah,
    bool? isLoading,
  }) {
    return LastReadState(
      global: global ?? this.global,
      bySurah: bySurah ?? this.bySurah,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// آخر آية مقروءة في سورة معيّنة (أو null) — للاستخدام لاحقاً في الشارة
  int? ayahForSurah(int surahNumber) => bySurah[surahNumber];
}

// ════════════════════════════════════════════════════════════════
//  LastReadNotifier
// ════════════════════════════════════════════════════════════════

class LastReadNotifier extends StateNotifier<LastReadState> {
  LastReadNotifier() : super(const LastReadState()) {
    _load();
  }

  void _load() {
    final global = LastReadService.getGlobalLastRead();
    final bySurah = LastReadService.getLastReadBySurah();
    state = LastReadState(
      global: global,
      bySurah: bySurah,
      isLoading: false,
    );
  }

  /// حفظ موضع قراءة يدوي جديد — يكتب فقط في bySurahManual ولا يمس التلقائي أبداً
  Future<void> savePosition(LastReadPosition position) async {
    await LastReadService.saveManual(position);

    final newBySurah = Map<int, int>.from(state.bySurah);
    newBySurah[position.surahNumber] = position.ayahNumber;

    state = state.copyWith(
      global: position,
      bySurah: newBySurah,
      isLoading: false,
    );
  }

  Future<void> clearForSurah(int surahNumber) async {
    await LastReadService.clearManualForSurah(surahNumber);
    final newMap = Map<int, int>.from(state.bySurah);
    newMap.remove(surahNumber);
    final newGlobal = state.global?.surahNumber == surahNumber ? null : state.global;
    state = LastReadState(
      global: newGlobal,
      bySurah: newMap,
      isLoading: false,
    );
  }

  /// إعادة التحميل من التخزين المحلي
  Future<void> reload() async {
    _load();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════

final lastReadProvider = StateNotifierProvider<LastReadNotifier, LastReadState>(
  (ref) => LastReadNotifier(),
);
