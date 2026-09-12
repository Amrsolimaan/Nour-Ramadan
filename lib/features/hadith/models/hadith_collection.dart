// ════════════════════════════════════════════════════════════════
//  Hadith Collection Models
// ════════════════════════════════════════════════════════════════

import '../data/bukhari_sections_ar.dart';
import '../data/muslim_sections_ar.dart';
import '../data/tirmidhi_sections_ar.dart';

class HadithCollection {
  final String id;
  final String arabicName;
  final String englishName;
  final String fileName;
  final String icon;
  final int totalHadiths;

  const HadithCollection({
    required this.id,
    required this.arabicName,
    required this.englishName,
    required this.fileName,
    required this.icon,
    required this.totalHadiths,
  });
  
  /// ترجمة عنوان الباب إلى العربية (للبخاري ومسلم والترمذي)
  String translateChapter(String? chapter) {
    if (chapter == null || chapter.isEmpty) return '';
    
    // إذا كان البخاري، ترجم العنوان
    if (id == 'bukhari') {
      return bukhariSectionsArabic[chapter] ?? chapter;
    }
    
    // إذا كان مسلم، ترجم العنوان
    if (id == 'muslim') {
      return muslimSectionsArabic[chapter] ?? chapter;
    }
    
    // إذا كان الترمذي، ترجم العنوان
    if (id == 'tirmidhi') {
      return tirmidhiSectionsArabic[chapter] ?? chapter;
    }
    
    // باقي الكتب تعرض العنوان كما هو
    return chapter;
  }
}

// ════════════════════════════════════════════════════════════════
//  Predefined Collections
// ════════════════════════════════════════════════════════════════
const kHadithCollections = [
  HadithCollection(
    id: 'bukhari',
    arabicName: 'صحيح البخاري',
    englishName: 'Sahih al-Bukhari',
    fileName: 'ara-bukhari.json',
    icon: '📖',
    totalHadiths: 7563,
  ),
  HadithCollection(
    id: 'muslim',
    arabicName: 'صحيح مسلم',
    englishName: 'Sahih Muslim',
    fileName: 'ara-muslim.json',
    icon: '📗',
    totalHadiths: 7563,
  ),
  HadithCollection(
    id: 'tirmidhi',
    arabicName: 'سنن الترمذي',
    englishName: 'Jami` at-Tirmidhi',
    fileName: 'ara-tirmidhi.json',
    icon: '📘',
    totalHadiths: 3956,
  ),
  HadithCollection(
    id: 'abudawud',
    arabicName: 'سنن أبي داود',
    englishName: 'Sunan Abi Dawud',
    fileName: 'abudawud.json',
    icon: '📙',
    totalHadiths: 5274,
  ),
  HadithCollection(
    id: 'ibnmajah',
    arabicName: 'سنن ابن ماجه',
    englishName: 'Sunan Ibn Majah',
    fileName: 'ibnmajah.json',
    icon: '📕',
    totalHadiths: 4341,
  ),
  HadithCollection(
    id: 'nasai',
    arabicName: 'سنن النسائي',
    englishName: "Sunan an-Nasa'i",
    fileName: 'nasai.json',
    icon: '📗',
    totalHadiths: 5758,
  ),
  HadithCollection(
    id: 'malik',
    arabicName: 'موطأ مالك',
    englishName: 'Muwatta Malik',
    fileName: 'malik.json',
    icon: '📗',
    totalHadiths: 1594,
  ),
  HadithCollection(
    id: 'qudsi40',
    arabicName: 'الأربعون القدسية',
    englishName: '40 Hadith Qudsi',
    fileName: 'qudsi40.json',
    icon: '📘',
    totalHadiths: 40,
  ),
  HadithCollection(
    id: 'riyad',
    arabicName: 'رياض الصالحين',
    englishName: 'Riyad as-Salihin',
    fileName: 'riyad_assalihin.json',
    icon: '📙',
    totalHadiths: 1896,
  ),
];

// ════════════════════════════════════════════════════════════════
//  Hadith Model
// ════════════════════════════════════════════════════════════════
class Hadith {
  final int number;
  final String arabicNumber;
  final String text;
  final String? chapter;
  final String? reference;

  const Hadith({
    required this.number,
    required this.arabicNumber,
    required this.text,
    this.chapter,
    this.reference,
  });

  factory Hadith.fromBukhariMuslim(
    Map<String, dynamic> json,
    String? chapterName,
  ) {
    return Hadith(
      number: (json['hadithnumber'] as num).toInt(),
      arabicNumber: json['arabicnumber']?.toString() ?? '',
      text: json['text'] as String? ?? '',
      chapter: chapterName,
      reference: json['reference']?['book']?.toString(),
    );
  }

  factory Hadith.fromRiyad(Map<String, dynamic> json, String? chapterName) {
    return Hadith(
      number: (json['id'] as num).toInt(),
      arabicNumber: json['idInBook']?.toString() ?? '',
      text: json['arabic'] as String? ?? '',
      chapter: chapterName,
      reference: null,
    );
  }
}
