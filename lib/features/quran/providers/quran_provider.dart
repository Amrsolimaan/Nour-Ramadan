import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/services/quran_service.dart';
import '../../settings/providers/settings_provider.dart';

// ════════════════════════════════════════════════════════════════
//  QuranState — حالة شاشة القارئ
// ════════════════════════════════════════════════════════════════

class QuranState {
  const QuranState({
    this.surah,
    this.currentAyah = 0,
    this.selectedStart,
    this.selectedEnd,
    this.isPlaying = false,
    this.isLoading = false,
    this.searchQuery = '',
  });

  final SurahInfo? surah;
  final int        currentAyah;
  final int?       selectedStart;
  final int?       selectedEnd;
  final bool       isPlaying;
  final bool       isLoading;
  final String     searchQuery;

  bool isSelected(int ayah) {
    final s = selectedStart;
    final e = selectedEnd;
    if (s == null) return false;
    final end = e ?? s;
    final min = s < end ? s : end;
    final max = s < end ? end : s;
    return ayah >= min && ayah <= max;
  }

  bool get hasSelection => selectedStart != null;

  QuranState copyWith({
    SurahInfo? surah,
    int?       currentAyah,
    int?       selectedStart,
    int?       selectedEnd,
    bool?      isPlaying,
    bool?      isLoading,
    String?    searchQuery,
    bool       clearSelection = false,
  }) {
    return QuranState(
      surah:         surah         ?? this.surah,
      currentAyah:   currentAyah   ?? this.currentAyah,
      selectedStart: clearSelection ? null : (selectedStart ?? this.selectedStart),
      selectedEnd:   clearSelection ? null : (selectedEnd   ?? this.selectedEnd),
      isPlaying:     isPlaying     ?? this.isPlaying,
      isLoading:     isLoading     ?? this.isLoading,
      searchQuery:   searchQuery   ?? this.searchQuery,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  QuranNotifier — التحكم في قارئ القرآن
// ════════════════════════════════════════════════════════════════

class QuranNotifier extends StateNotifier<QuranState> {
  QuranNotifier(this._ref) : super(const QuranState()) {
    _player = AudioPlayer();
  }

  final Ref _ref;
  late final AudioPlayer _player;
  Timer? _delayTimer;

  void openSurah(SurahInfo surah) {
    stopAudio();
    state = state.copyWith(
      surah: surah,
      currentAyah: 0,
      clearSelection: true,
    );
  }

  // ── التحديد ──
  void startSelection(int ayah) {
    state = state.copyWith(selectedStart: ayah, selectedEnd: ayah);
  }

  void extendSelection(int ayah) {
    if (state.selectedStart == null) {
      startSelection(ayah);
      return;
    }
    state = state.copyWith(selectedEnd: ayah);
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  // ── الصوت ──
  Future<void> playAudio() async {
    final surah = state.surah;
    if (surah == null) return;

    final settings = _ref.read(settingsProvider);
    final sheikh   = settings.sheikh;
    final delay    = settings.ayahDelay;

    int start, end;
    if (state.hasSelection) {
      final s = state.selectedStart!;
      final e = state.selectedEnd ?? s;
      start = s < e ? s : e;
      end   = s < e ? e : s;
    } else {
      start = 1;
      end   = surah.ayahCount;
    }

    state = state.copyWith(isPlaying: true, isLoading: true);

    for (var ayah = start; ayah <= end; ayah++) {
      if (!state.isPlaying) break;
      state = state.copyWith(currentAyah: ayah, isLoading: false);

      try {
        final url = sheikh.audioUrl(surah.number, ayah);
        await _player.setUrl(url);
        await _player.play();
        await _player.playerStateStream.firstWhere(
          (s) => s.processingState == ProcessingState.completed,
        );
      } catch (_) {}

      if (ayah < end && state.isPlaying) {
        await Future.delayed(Duration(milliseconds: delay));
      }
    }

    state = state.copyWith(isPlaying: false, currentAyah: 0);
  }

  Future<void> stopAudio() async {
    _delayTimer?.cancel();
    await _player.stop();
    state = state.copyWith(isPlaying: false, currentAyah: 0);
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await stopAudio();
    } else {
      await playAudio();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════

final quranProvider = StateNotifierProvider<QuranNotifier, QuranState>(
  (ref) => QuranNotifier(ref),
);
