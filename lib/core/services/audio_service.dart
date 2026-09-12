import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ════════════════════════════════════════════════════════════════
//  AudioService — تشغيل التسجيلات الصوتية
//  يدعم: التشغيل/الإيقاف، الانتظار بين الآيات، الكنترول الكامل
// ════════════════════════════════════════════════════════════════

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  AudioService._internal() {
    _player = AudioPlayer();
  }

  late final AudioPlayer _player;
  String? _currentUrl;
  bool _isPlaying = false;

  AudioPlayer get player => _player;

  bool get isPlaying => _isPlaying;

  // ── تشغيل آية من URL ────────────────────────────────────────
  Future<void> playAyah(String audioUrl) async {
    try {
      if (_currentUrl != audioUrl || !_isPlaying) {
        _currentUrl = audioUrl;

        // تحقق من أن الرابط صحيح
        if (!audioUrl.startsWith('http')) {
          print('❌ رابط صوت غير صالح: $audioUrl');
          return;
        }

        print('▶ تشغيل: $audioUrl');
        await _player.setUrl(audioUrl);
        await _player.play();
        _isPlaying = true;
      }
    } catch (e) {
      print('❌ خطأ في التشغيل: $e');
      _isPlaying = false;
    }
  }

  // ── إيقاف التشغيل ──────────────────────────────────────────
  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
  }

  // ── استئناف التشغيل ────────────────────────────────────────
  Future<void> resume() async {
    await _player.play();
    _isPlaying = true;
  }

  // ── إيقاف كامل وإعادة تعيين ────────────────────────────────
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _currentUrl = null;
  }

  // ── الاستماع لأحداث التشغيل ─────────────────────────────────
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // ── الموضع الحالي ─────────────────────────────────────────
  Stream<Duration> get positionStream => _player.positionStream;

  // ── المدة الكلية ───────────────────────────────────────────
  Duration? get duration => _player.duration;

  // ── تشغيل آية من Quran.com ─────────────────────────────────
  Future<void> playAudio(String url) async {
    await playAyah(url);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

// Provider للخدمة
final audioServiceProvider = Provider((ref) => AudioService());
