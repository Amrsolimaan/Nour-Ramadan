import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ════════════════════════════════════════════════════════════════
//  QuranApiService — الاتصال بـ Quran.com API
//  يوفر: نصوص الآيات، التسجيلات الصوتية، معلومات السور
// ════════════════════════════════════════════════════════════════

class QuranApiService {
  static const String _baseUrl = 'https://api.quran.com/api/v4';

  final Dio _dio = Dio();

  // ── الحصول على كل السور ──────────────────────────────────────
  Future<List<Surah>> getAllSurahs({String language = 'ar'}) async {
    try {
      final response = await _dio.get('$_baseUrl/chapters?language=$language');
      if (response.statusCode == 200) {
        final chapters = (response.data['chapters'] as List)
            .map((ch) => Surah.fromJson(ch))
            .toList();
        return chapters;
      }
    } catch (e) {
      print('❌ خطأ في جلب السور: $e');
    }
    return [];
  }

  // ── الحصول على آيات السورة مع التشكيل ──────────────────────────
  Future<List<Ayah>> getSurahAyahs({
    required int surahNumber,
    String textType = 'text_imlaei', // text_indopak / text_uthmani
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/quran/verses/$textType?chapter_number=$surahNumber&fields=text_madina,chapter&per_page=300',
      );
      if (response.statusCode == 200) {
        final verses = (response.data['verses'] as List)
            .map((v) => Ayah.fromJson(v))
            .toList();
        return verses;
      }
    } catch (e) {
      print('❌ خطأ في جلب الآيات: $e');
    }
    return [];
  }

  // ── الحصول على رابط الصوت للشيخ (عبدالباسط) ──────────────────
  Future<String?> getAyahAudio({
    required int surahNumber,
    required int ayahNumber,
    String reciterId = '5', // عبدالباسط (ID: 5)
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/quran/recitations/$reciterId/by_verse/$surahNumber:$ayahNumber',
      );
      if (response.statusCode == 200) {
        final audioUrl =
            response.data['verse_timings'][0]['url'] ??
            response.data['audio_url'];
        if (audioUrl != null) {
          // التأكد من أن الرابط يبدأ بـ https
          if (!audioUrl.toString().startsWith('http')) {
            return 'https://cdn.islamic.network$audioUrl';
          }
          return audioUrl.toString();
        }
      }
    } catch (e) {
      print('❌ خطأ في جلب رابط الصوت: $e');
    }
    return null;
  }

  // ── الحصول على معلومات السورة ────────────────────────────────
  Future<SurahInfo?> getSurahInfo(int surahNumber) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/chapters/$surahNumber?language=ar',
      );
      if (response.statusCode == 200) {
        final chapter = response.data['chapter'];
        return SurahInfo(
          number: chapter['id'] ?? surahNumber,
          name:
              chapter['name_arabic'] ??
              chapter['name'] ??
              'السورة $surahNumber',
          englishName: chapter['name'] ?? 'Surah $surahNumber',
          ayahCount: chapter['verses_count'] ?? 0,
          revelationType: chapter['revelation_type'] ?? 'Unknown',
        );
      }
    } catch (e) {
      print('❌ خطأ في جلب معلومات السورة: $e');
    }
    return null;
  }

  // ── الحصول على محتوى الجزء ────────────────────────────────────
  Future<List<JuzAyah>> getJuzContent(int juzNumber) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/verses/by_juz/$juzNumber?words=false&translations=false&audio=false&tafsirs=false&fields=text_uthmani,chapter_id,verse_number,verse_key,page_number,hizb_number,juz_number',
      );
      
      if (response.statusCode == 200) {
        final verses = (response.data['verses'] as List)
            .map((v) => JuzAyah.fromJson(v))
            .toList();
        return verses;
      }
    } catch (e) {
      print('❌ خطأ في جلب محتوى الجزء: $e');
    }
    return [];
  }
}

// ── نماذج البيانات ──────────────────────────────────────────────
class Surah {
  final int id;
  final String name;
  final String englishName;
  final int versesCount;
  final String? revelationType;

  Surah({
    required this.id,
    required this.name,
    required this.englishName,
    required this.versesCount,
    this.revelationType,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      id: json['id'] as int? ?? 0,
      name: (json['name_arabic'] ?? json['name'] ?? 'Unknown') as String,
      englishName: (json['name'] ?? 'Surah') as String,
      versesCount: json['verses_count'] as int? ?? 0,
      revelationType: json['revelation_type'] as String?,
    );
  }
}

class Ayah {
  final int ayahNumber;
  final int surahNumber;
  final String text;
  final int numberInSurah;

  Ayah({
    required this.ayahNumber,
    required this.surahNumber,
    required this.text,
    required this.numberInSurah,
  });

  factory Ayah.fromJson(Map<String, dynamic> json) {
    // استخراج رقم الآية من verse_key إذا كان موجوداً (مثال: "1:1" -> 1)
    int verseNum = json['verse_number'] as int? ?? 0;
    if (verseNum == 0 && json['verse_key'] != null) {
      final parts = json['verse_key'].toString().split(':');
      if (parts.length == 2) {
        verseNum = int.tryParse(parts[1]) ?? 0;
      }
    }
    
    return Ayah(
      ayahNumber: json['id'] as int? ?? 0,
      surahNumber: json['chapter_id'] as int? ?? 0,
      text:
          (json['text_uthmani'] ?? json['text_madina'] ?? json['text_imlaei'] ?? json['text'] ?? '')
              as String,
      numberInSurah: verseNum,
    );
  }
}

class SurahInfo {
  final int number;
  final String name;
  final String englishName;
  final int ayahCount;
  final String? revelationType;

  SurahInfo({
    required this.number,
    required this.name,
    required this.englishName,
    required this.ayahCount,
    this.revelationType,
  });
}

// ── نموذج آية في الجزء ──────────────────────────────────────────
class JuzAyah {
  final int pageNumber;
  final String text;
  final int chapterId;
  final int verseNumber;
  final String verseKey;
  final int hizbNumber;
  final int juzNumber;

  JuzAyah({
    required this.pageNumber,
    required this.text,
    required this.chapterId,
    required this.verseNumber,
    required this.verseKey,
    required this.hizbNumber,
    required this.juzNumber,
  });

  factory JuzAyah.fromJson(Map<String, dynamic> json) {
    return JuzAyah(
      pageNumber: json['page_number'] as int? ?? 0,
      text: (json['text_uthmani'] ?? json['text'] ?? '') as String,
      chapterId: json['chapter_id'] as int? ?? 0,
      verseNumber: json['verse_number'] as int? ?? 0,
      verseKey: (json['verse_key'] ?? '') as String,
      hizbNumber: json['hizb_number'] as int? ?? 0,
      juzNumber: json['juz_number'] as int? ?? 0,
    );
  }

  // حساب ربع الحزب بشكل صحيح
  String get hizbQuarter {
    // كل حزب = 4 أرباع
    // hizbNumber من 1 إلى 240 (60 حزب × 4 أرباع)
    final hizbNum = ((hizbNumber - 1) ~/ 4) + 1; // رقم الحزب (1-60)
    final quarter = ((hizbNumber - 1) % 4) + 1; // رقم الربع (1-4)
    
    return 'حزب $hizbNum - ربع $quarter';
  }
}

// ── Providers ──────────────────────────────────────────────────────
final quranApiProvider = Provider((ref) => QuranApiService());
