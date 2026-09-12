import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_quran_service.dart';
import 'audio_cache_service.dart';
import '../data/juz_data.dart';

// ════════════════════════════════════════════════════════════════
//  OfflineQuranService — الخدمة الرئيسية لنظام Offline-First
//  تجمع بين القراءة المحلية والصوت الذكي
// ════════════════════════════════════════════════════════════════

class OfflineQuranService {
  final LocalQuranService _localService;
  final AudioCacheService _audioService;

  OfflineQuranService(this._localService, this._audioService);

  // ══════════════════════════════════════════════════════════════
  //  قسم النصوص (Offline)
  // ══════════════════════════════════════════════════════════════

  /// الحصول على قائمة جميع السور
  Future<List<SurahInfo>> getAllSurahs() async {
    return await _localService.getAllSurahs();
  }

  /// الحصول على آيات سورة معينة
  Future<List<LocalAyah>> getSurahAyahs(int surahNumber) async {
    return await _localService.getSurahAyahs(surahNumber);
  }

  /// الحصول على معلومات سورة
  Future<SurahInfo?> getSurahInfo(int surahNumber) async {
    return await _localService.getSurahInfo(surahNumber);
  }

  /// الحصول على آيات جزء معين
  Future<List<LocalAyah>> getJuzAyahs(int juzNumber) async {
    final sections = JuzData.juzContent[juzNumber];
    if (sections == null || sections.isEmpty) {
      return [];
    }
    return await _localService.getJuzAyahs(sections);
  }

  /// الحصول على أقسام الجزء
  List<JuzSection>? getJuzSections(int juzNumber) {
    return JuzData.juzContent[juzNumber];
  }

  // ══════════════════════════════════════════════════════════════
  //  قسم الصوت (Online with Smart Cache)
  // ══════════════════════════════════════════════════════════════

  /// التحقق من وجود اتصال بالإنترنت
  Future<bool> hasInternetConnection() async {
    return await _audioService.hasInternetConnection();
  }

  /// الحصول على ملف صوت آية (من الكاش أو التحميل)
  Future<AudioResult> getAyahAudio({
    required int surahNumber,
    required int ayahNumber,
    String reciter = 'Abdul_Basit_Murattal_192kbps',
  }) async {
    // ── 1. هل الملف مخزن مسبقاً في الكاش؟ ──
    final isCached = await _audioService.isFileCached(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      reciter: reciter,
    );

    // ── 2. إذا لم يكن مخزناً، تحقق من الإنترنت قبل المحاولة ──
    if (!isCached) {
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        return AudioResult(
          success: false,
          needsInternet: true,
          errorMessage:
              'عذراً، تتطلب خدمة التلاوات الصوتية اتصالاً بالإنترنت.\n'
              'يمكنك الاستمرار في القراءة الآن، أو الاتصال بالشبكة للاستماع لشيخك المفضل.',
        );
      }
    }

    // ── 3. حاول الحصول على الملف (كاش أو تحميل) ──
    try {
      final file = await _audioService.getAudioFile(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        reciter: reciter,
      );

      if (file != null) {
        return AudioResult(success: true, file: file, fromCache: isCached);
      }

      // فشل غير متعلق بالشبكة (مثل HTTP 404)
      return AudioResult(
        success: false,
        errorMessage: 'الملف الصوتي غير متاح لهذه الآية',
      );
    } on AudioNetworkException {
      // ── الحالة الحرجة: connectivity_plus قالت "متصل" لكن التحميل فشل فعلياً ──
      // هذا هو سبب المشكلة الأصلية — نعيد هنا needsInternet: true بشكل صحيح
      return AudioResult(
        success: false,
        needsInternet: true,
        errorMessage:
            'عذراً، تتطلب خدمة التلاوات الصوتية اتصالاً بالإنترنت.\n'
            'يمكنك الاستمرار في القراءة الآن، أو الاتصال بالشبكة للاستماع لشيخك المفضل.',
      );
    }
  }

  /// الحصول على حجم الكاش الحالي
  Future<String> getCacheSizeFormatted() async {
    final bytes = await _audioService.getCacheSize();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// مسح الكاش
  Future<void> clearAudioCache() async {
    await _audioService.clearCache();
  }
}

// ── نتيجة طلب الصوت ──────────────────────────────────────────────
class AudioResult {
  final bool success;
  final File? file;
  final bool fromCache;
  final String? errorMessage;
  final bool needsInternet;

  AudioResult({
    required this.success,
    this.file,
    this.fromCache = false,
    this.errorMessage,
    this.needsInternet = false,
  });
}

// ── Provider ────────────────────────────────────────────────────
final offlineQuranServiceProvider = Provider((ref) {
  final localService = ref.watch(localQuranServiceProvider);
  final audioService = ref.watch(audioCacheServiceProvider);
  return OfflineQuranService(localService, audioService);
});
