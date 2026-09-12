import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ════════════════════════════════════════════════════════════════
//  Azan Service — خدمة الأذان
// ════════════════════════════════════════════════════════════════

class AzanService {
  static final AzanService _instance = AzanService._internal();
  factory AzanService() => _instance;
  AzanService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  // ── تشغيل الأذان حسب المؤذن المختار ──────────────────────────
  Future<void> playAzan({
    required String muezzinFileName,
    required String prayerName,
  }) async {
    if (_isPlaying) {
      await stopAzan();
    }

    try {
      _isPlaying = true;
      debugPrint('Playing azan: $muezzinFileName for $prayerName');
      
      await _audioPlayer.setAsset('assets/audio/$muezzinFileName');
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();

      // الاستماع لانتهاء الأذان
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          debugPrint('Azan completed');
        }
      });
    } catch (e) {
      _isPlaying = false;
      debugPrint('Error playing azan: $e');
    }
  }

  // ── إيقاف الأذان ──────────────────────────────────────────────
  Future<void> stopAzan() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('Error stopping azan: $e');
    }
  }

  // ── إيقاف مؤقت ──────────────────────────────────────────────
  Future<void> pauseAzan() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('Error pausing azan: $e');
    }
  }

  // ── استئناف التشغيل ──────────────────────────────────────────
  Future<void> resumeAzan() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error resuming azan: $e');
    }
  }

  // ── الحصول على حالة التشغيل ──────────────────────────────────
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  // ── الحصول على موضع التشغيل ──────────────────────────────────
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  // ── تنظيف الموارد ──────────────────────────────────────────────
  void dispose() {
    _audioPlayer.dispose();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider للوصول السهل
// ════════════════════════════════════════════════════════════════

final azanServiceProvider = Provider<AzanService>((ref) {
  return AzanService();
});
