import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/last_read_service.dart';

// ════════════════════════════════════════════════════════════════
//  AutoResumeState — حالة "استئناف الصفحة" التلقائي لكل سورة
//  منفصل تماماً عن LastReadState اليدوي (شارة القائمة)
//  يُكتب كل 800ms من VisibilityDetector ولا يمس الشارة اليدوية
// ════════════════════════════════════════════════════════════════

class AutoResumeState {
  final LastReadPosition? global;
  final Map<int, int> pageBySurah; // surah -> ayahNumber (أول آية مرئية للصفحة)
  final bool isLoading;

  const AutoResumeState({
    this.global,
    this.pageBySurah = const {},
    this.isLoading = true,
  });

  AutoResumeState copyWith({
    LastReadPosition? global,
    Map<int, int>? pageBySurah,
    bool? isLoading,
  }) {
    return AutoResumeState(
      global: global ?? this.global,
      pageBySurah: pageBySurah ?? this.pageBySurah,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int? ayahForSurah(int surahNumber) => pageBySurah[surahNumber];
}

class AutoResumeNotifier extends StateNotifier<AutoResumeState> {
  AutoResumeNotifier() : super(const AutoResumeState()) {
    _load();
  }

  void _load() {
    final global = LastReadService.getAutoGlobal();
    final bySurah = LastReadService.getAutoBySurah();
    state = AutoResumeState(
      global: global,
      pageBySurah: bySurah,
      isLoading: false,
    );
  }

  /// حفظ موضع تلقائي لكل سورة — يكتب فقط في auto ولا يمس اليدوي أبداً
  Future<void> savePosition(LastReadPosition position) async {
    await LastReadService.saveAuto(position);

    final newMap = Map<int, int>.from(state.pageBySurah);
    newMap[position.surahNumber] = position.ayahNumber;

    state = state.copyWith(
      global: position,
      pageBySurah: newMap,
      isLoading: false,
    );
  }

  Future<void> clearForSurah(int surahNumber) async {
    await LastReadService.clearAutoForSurah(surahNumber);
    final newMap = Map<int, int>.from(state.pageBySurah);
    newMap.remove(surahNumber);
    final newGlobal = state.global?.surahNumber == surahNumber ? null : state.global;
    state = AutoResumeState(
      global: newGlobal,
      pageBySurah: newMap,
      isLoading: false,
    );
  }

  Future<void> reload() async {
    _load();
  }
}

final autoResumeProvider =
    StateNotifierProvider<AutoResumeNotifier, AutoResumeState>(
  (ref) => AutoResumeNotifier(),
);
