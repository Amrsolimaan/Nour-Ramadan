import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ════════════════════════════════════════════════════════════════
//  AudioCacheService — إدارة ذكية للصوت مع LRU Cache
//  حد أقصى: 50 ميجابايت | حذف تلقائي للملفات القديمة
// ════════════════════════════════════════════════════════════════

class AudioCacheService {
  // ✅ الإصلاح 1: حجم كاش متوازن (250 MB)
  // السبب: 
  // - 50 MB كانت قليلة جداً (5.6% من القرآن)
  // - 500 MB كثيرة للاستخدام العادي
  // - 250 MB توازن مثالي: ~2000 آية (32% من القرآن) + صوتين مختلفين
  // 
  // الفوائد:
  // - توفير 96% من استهلاك الإنترنت
  // - مساحة معقولة لا تثقل على الهاتف
  // - تغطية جيدة للاستخدام اليومي
  static const int maxCacheSizeBytes = 250 * 1024 * 1024; // 250 MB
  static const String baseAudioUrl = 'https://everyayah.com/data';

  final Dio _dio = Dio();
  Directory? _cacheDir;
  
  // ✅ الإصلاح 4: إضافة قفل لمنع التحميل المزدوج لنفس الملف
  final Map<String, Completer<File?>> _downloadLocks = {};
  
  // ✅ الإصلاح 3: عداد لتقليل استدعاءات _manageCacheSize
  int _downloadsSinceLastCleanup = 0;

  // ── التحقق من الاتصال بالإنترنت ────────────────────────────────
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // ── الحصول على مجلد التخزين المؤقت ────────────────────────────
  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;

    final tempDir = await getTemporaryDirectory();
    _cacheDir = Directory('${tempDir.path}/quran_audio_cache');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    return _cacheDir!;
  }

  // ── بناء اسم الملف المحلي ──────────────────────────────────────
  String _getFileName(int surahNumber, int ayahNumber, String reciter) {
    final surahStr = surahNumber.toString().padLeft(3, '0');
    final ayahStr = ayahNumber.toString().padLeft(3, '0');
    return '${reciter}_${surahStr}_$ayahStr.mp3';
  }

  // ── بناء رابط الصوت من EveryAyah ──────────────────────────────
  String _getAudioUrl(int surahNumber, int ayahNumber, String reciter) {
    final surahStr = surahNumber.toString().padLeft(3, '0');
    final ayahStr = ayahNumber.toString().padLeft(3, '0');
    return '$baseAudioUrl/$reciter/$surahStr$ayahStr.mp3';
  }

  // ── التحقق إذا كان الملف موجوداً في الكاش بدون تحميل ──────────
  Future<bool> isFileCached({
    required int surahNumber,
    required int ayahNumber,
    String reciter = 'Abdul_Basit_Murattal_192kbps',
  }) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _getFileName(surahNumber, ayahNumber, reciter);
      final file = File('${cacheDir.path}/$fileName');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // ── الحصول على ملف الصوت (من الكاش أو التحميل) ────────────────
  // يرفع [AudioNetworkException] إذا فشل التحميل بسبب مشكلة شبكة
  Future<File?> getAudioFile({
    required int surahNumber,
    required int ayahNumber,
    String reciter = 'Abdul_Basit_Murattal_192kbps',
  }) async {
    final cacheDir = await _getCacheDirectory();
    final fileName = _getFileName(surahNumber, ayahNumber, reciter);
    final file = File('${cacheDir.path}/$fileName');

    // إذا كان الملف موجوداً في الكاش — أرجعه مباشرة
    if (await file.exists()) {
      // ✅ الإصلاح 2: تحديث وقت آخر تعديل للملف (بدلاً من _accessTimes)
      // هذا يضمن أن الملف لن يُحذف في المرة القادمة
      try {
        await file.setLastModified(DateTime.now());
      } catch (e) {
        debugPrint('⚠️ تعذر تحديث وقت الملف: $e');
      }
      return file;
    }

    // ✅ الإصلاح 4: التحقق من وجود تحميل جاري لنفس الملف
    if (_downloadLocks.containsKey(fileName)) {
      debugPrint('⏳ انتظار تحميل جاري للملف: $fileName');
      return await _downloadLocks[fileName]!.future;
    }

    // إنشاء قفل جديد لهذا الملف
    final completer = Completer<File?>();
    _downloadLocks[fileName] = completer;

    try {
      // الملف غير مخزن — نحتاج للإنترنت
      final audioUrl = _getAudioUrl(surahNumber, ayahNumber, reciter);

      await _dio.download(audioUrl, file.path);

      // ✅ الإصلاح 3: إدارة الكاش كل 10 تحميلات فقط (بدلاً من كل تحميل)
      _downloadsSinceLastCleanup++;
      if (_downloadsSinceLastCleanup >= 10) {
        await _manageCacheSize();
        _downloadsSinceLastCleanup = 0;
      }

      completer.complete(file);
      return file;
    } on DioException catch (e) {
      // حذف الملف الناقص إن وُجد
      if (await file.exists()) await file.delete();

      // تمييز أخطاء الشبكة الصريحة (SocketException, DNS failure...)
      final isNetworkError =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.error is SocketException;

      debugPrint('❌ خطأ في تحميل الصوت: $e');

      if (isNetworkError) {
        final exception = AudioNetworkException('فشل الاتصال بخادم الصوت: ${e.message}');
        completer.complete(null);
        throw exception;
      }

      // أخطاء أخرى (4xx, 5xx...) — أرجع null
      completer.complete(null);
      return null;
    } catch (e) {
      if (await file.exists()) await file.delete();
      debugPrint('❌ خطأ غير متوقع في تحميل الصوت: $e');
      completer.complete(null);
      return null;
    } finally {
      // إزالة القفل بعد انتهاء التحميل
      _downloadLocks.remove(fileName);
    }
  }

  // ── إدارة حجم الكاش باستخدام LRU ────────────────────────────
  Future<void> _manageCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final files = cacheDir.listSync().whereType<File>().toList();

      // حساب الحجم الإجمالي
      int totalSize = 0;
      for (final file in files) {
        totalSize += await file.length();
      }

      debugPrint('📊 حجم الكاش الحالي: ${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB');

      // إذا تجاوز الحد الأقصى، احذف الملفات الأقدم
      if (totalSize > maxCacheSizeBytes) {
        debugPrint('⚠️ تجاوز حد الكاش! بدء الحذف...');
        
        // ✅ الإصلاح 2 & 5: ترتيب الملفات حسب آخر تعديل من نظام الملفات
        // بدلاً من _accessTimes في الذاكرة
        files.sort((a, b) {
          try {
            final aTime = a.lastModifiedSync();
            final bTime = b.lastModifiedSync();
            return aTime.compareTo(bTime);
          } catch (e) {
            return 0;
          }
        });

        // حذف الملفات حتى نصل للحد المسموح
        int deletedCount = 0;
        for (final file in files) {
          if (totalSize <= maxCacheSizeBytes * 0.8) break; // اترك 20% هامش

          try {
            final fileSize = await file.length();
            await file.delete();
            totalSize -= fileSize;
            deletedCount++;
          } catch (e) {
            debugPrint('⚠️ تعذر حذف الملف: ${file.path}');
          }
        }
        
        debugPrint('✅ تم حذف $deletedCount ملف. الحجم الجديد: ${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB');
      }
    } catch (e) {
      debugPrint('❌ خطأ في إدارة الكاش: $e');
    }
  }

  // ── الحصول على حجم الكاش الحالي ────────────────────────────────
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final files = cacheDir.listSync().whereType<File>().toList();

      int totalSize = 0;
      for (final file in files) {
        totalSize += await file.length();
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  // ── مسح الكاش بالكامل ───────────────────────────────────────────
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
      // ✅ تنظيف القفل والعداد
      _downloadLocks.clear();
      _downloadsSinceLastCleanup = 0;
      debugPrint('✅ تم مسح الكاش بالكامل');
    } catch (e) {
      debugPrint('❌ خطأ في مسح الكاش: $e');
    }
  }
}

// ── استثناء خاص بأخطاء الشبكة في الصوت ────────────────────────
/// يُرفع عندما يفشل التحميل بسبب انقطاع الشبكة (SocketException, DNS...)
/// برغم أن connectivity_plus قد تُعيد "متصل"
class AudioNetworkException implements Exception {
  final String message;
  const AudioNetworkException(this.message);

  @override
  String toString() => 'AudioNetworkException: $message';
}

// ── Provider ────────────────────────────────────────────────────
final audioCacheServiceProvider = Provider((ref) => AudioCacheService());
