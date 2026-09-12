import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/juz_data.dart';
import '../data/quran_page_data.dart';

// ════════════════════════════════════════════════════════════════
//  LocalQuranService — قراءة القرآن من ملفات JSON المحلية
//  نظام Offline-First بدون الحاجة للإنترنت
// ════════════════════════════════════════════════════════════════

class LocalQuranService {
  // ── تحميل قائمة السور من index.json ──────────────────────────
  Future<List<SurahInfo>> getAllSurahs() async {
    try {
      final jsonString = await rootBundle.loadString('assets/quran/index.json');
      final List<dynamic> data = json.decode(jsonString);
      
      return data.map((item) => SurahInfo.fromLocalJson(item)).toList();
    } catch (e) {
      // خطأ في تحميل قائمة السور
      return [];
    }
  }

  // ── حساب معلومات الصفحة والجزء والحزب للآية ──────────────────
  Map<String, int> _calculateAyahMetadata(int surahNumber, int ayahNumber) {
    // استخدام البيانات الدقيقة من QuranPageData
    final ayahInfo = QuranPageData.ayahPageInfo[surahNumber]?[ayahNumber];
    
    if (ayahInfo != null) {
      return {
        'page': ayahInfo.page,
        'juz': ayahInfo.juz,
        'hizb': ayahInfo.hizb,
      };
    }
    
    // Fallback: إذا لم تكن البيانات موجودة (لا يجب أن يحدث)
    return {
      'page': 0,
      'juz': 0,
      'hizb': 0,
    };
  }

  // ── تحميل آيات السورة من الملف المحلي ────────────────────────
  Future<List<LocalAyah>> getSurahAyahs(int surahNumber) async {
    try {
      final jsonString = await rootBundle.loadString('assets/quran/$surahNumber.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      
      final verses = (data['verses'] as List)
          .map((v) {
            final ayahNumber = v['id'] as int;
            final metadata = _calculateAyahMetadata(surahNumber, ayahNumber);
            
            return LocalAyah.fromJson(
              v,
              surahNumber,
              pageNumber: metadata['page']!,
              juzNumber: metadata['juz']!,
              hizbNumber: metadata['hizb']!,
            );
          })
          .toList();
      
      return verses;
    } catch (e) {
      // خطأ في تحميل آيات السورة
      return [];
    }
  }

  // ── تحميل معلومات السورة ──────────────────────────────────────
  Future<SurahInfo?> getSurahInfo(int surahNumber) async {
    try {
      final allSurahs = await getAllSurahs();
      return allSurahs.firstWhere(
        (s) => s.number == surahNumber,
        orElse: () => throw Exception('السورة غير موجودة'),
      );
    } catch (e) {
      // خطأ في تحميل معلومات السورة
      return null;
    }
  }

  // ── تحميل آيات الجزء من الملفات المحلية ──────────────────────
  Future<List<LocalAyah>> getJuzAyahs(List<JuzSection> sections) async {
    final List<LocalAyah> allAyahs = [];
    
    for (final section in sections) {
      try {
        final surahAyahs = await getSurahAyahs(section.surahNumber);
        
        // تصفية الآيات حسب النطاق المطلوب
        final filteredAyahs = surahAyahs.where((ayah) {
          return ayah.numberInSurah >= section.fromAyah && 
                 ayah.numberInSurah <= section.toAyah;
        }).toList();
        
        allAyahs.addAll(filteredAyahs);
      } catch (e) {
        // خطأ في تحميل آيات السورة
      }
    }
    
    return allAyahs;
  }
}

// ── نماذج البيانات المحلية ──────────────────────────────────────

class SurahInfo {
  final int number;
  final String name;
  final String transliteration;
  final String type;
  final int totalVerses;

  SurahInfo({
    required this.number,
    required this.name,
    required this.transliteration,
    required this.type,
    required this.totalVerses,
  });

  factory SurahInfo.fromLocalJson(Map<String, dynamic> json) {
    return SurahInfo(
      number: json['id'] as int,
      name: json['name'] as String,
      transliteration: json['transliteration'] as String,
      type: json['type'] as String,
      totalVerses: json['total_verses'] as int,
    );
  }
}

class LocalAyah {
  final int id;
  final int surahNumber;
  final int numberInSurah;
  final String text;
  final String transliteration;
  final int pageNumber;
  final int juzNumber;
  final int hizbNumber;

  LocalAyah({
    required this.id,
    required this.surahNumber,
    required this.numberInSurah,
    required this.text,
    required this.transliteration,
    this.pageNumber = 0,
    this.juzNumber = 0,
    this.hizbNumber = 0,
  });

  factory LocalAyah.fromJson(
    Map<String, dynamic> json,
    int surahNumber, {
    int pageNumber = 0,
    int juzNumber = 0,
    int hizbNumber = 0,
  }) {
    return LocalAyah(
      id: json['id'] as int,
      surahNumber: surahNumber,
      numberInSurah: json['id'] as int,
      text: json['text'] as String,
      transliteration: json['transliteration'] as String? ?? '',
      pageNumber: pageNumber,
      juzNumber: juzNumber,
      hizbNumber: hizbNumber,
    );
  }
}

// ── Provider ────────────────────────────────────────────────────
final localQuranServiceProvider = Provider((ref) => LocalQuranService());
