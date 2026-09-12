// ════════════════════════════════════════════════════════════════
//  بيانات الأجزاء الثلاثين - كما في المصحف الشريف
//  المصدر: المصحف المدني (مصحف المدينة النبوية)
// ════════════════════════════════════════════════════════════════

class JuzData {
  // محتويات كل جزء من الأجزاء الثلاثين
  static const Map<int, List<JuzSection>> juzContent = {
    // الجزء الأول
    1: [
      JuzSection(surahNumber: 1, surahName: 'الفاتحة', fromAyah: 1, toAyah: 7, page: 1),
      JuzSection(surahNumber: 2, surahName: 'البقرة', fromAyah: 1, toAyah: 141, page: 2),
    ],
    
    // الجزء الثاني
    2: [
      JuzSection(surahNumber: 2, surahName: 'البقرة', fromAyah: 142, toAyah: 252, page: 22),
    ],
    
    // الجزء الثالث
    3: [
      JuzSection(surahNumber: 2, surahName: 'البقرة', fromAyah: 253, toAyah: 286, page: 42),
      JuzSection(surahNumber: 3, surahName: 'آل عمران', fromAyah: 1, toAyah: 92, page: 50),
    ],
    
    // الجزء الرابع
    4: [
      JuzSection(surahNumber: 3, surahName: 'آل عمران', fromAyah: 93, toAyah: 200, page: 62),
      JuzSection(surahNumber: 4, surahName: 'النساء', fromAyah: 1, toAyah: 23, page: 77),
    ],
    
    // الجزء الخامس
    5: [
      JuzSection(surahNumber: 4, surahName: 'النساء', fromAyah: 24, toAyah: 147, page: 82),
    ],
    
    // الجزء السادس
    6: [
      JuzSection(surahNumber: 4, surahName: 'النساء', fromAyah: 148, toAyah: 176, page: 102),
      JuzSection(surahNumber: 5, surahName: 'المائدة', fromAyah: 1, toAyah: 81, page: 106),
    ],
    
    // الجزء السابع
    7: [
      JuzSection(surahNumber: 5, surahName: 'المائدة', fromAyah: 82, toAyah: 120, page: 121),
      JuzSection(surahNumber: 6, surahName: 'الأنعام', fromAyah: 1, toAyah: 110, page: 128),
    ],
    
    // الجزء الثامن
    8: [
      JuzSection(surahNumber: 6, surahName: 'الأنعام', fromAyah: 111, toAyah: 165, page: 142),
      JuzSection(surahNumber: 7, surahName: 'الأعراف', fromAyah: 1, toAyah: 87, page: 151),
    ],
    
    // الجزء التاسع
    9: [
      JuzSection(surahNumber: 7, surahName: 'الأعراف', fromAyah: 88, toAyah: 206, page: 162),
      JuzSection(surahNumber: 8, surahName: 'الأنفال', fromAyah: 1, toAyah: 40, page: 177),
    ],
    
    // الجزء العاشر
    10: [
      JuzSection(surahNumber: 8, surahName: 'الأنفال', fromAyah: 41, toAyah: 75, page: 182),
      JuzSection(surahNumber: 9, surahName: 'التوبة', fromAyah: 1, toAyah: 92, page: 187),
    ],
    
    // الجزء الحادي عشر
    11: [
      JuzSection(surahNumber: 9, surahName: 'التوبة', fromAyah: 93, toAyah: 129, page: 201),
      JuzSection(surahNumber: 10, surahName: 'يونس', fromAyah: 1, toAyah: 109, page: 208),
      JuzSection(surahNumber: 11, surahName: 'هود', fromAyah: 1, toAyah: 5, page: 221),
    ],
    
    // الجزء الثاني عشر
    12: [
      JuzSection(surahNumber: 11, surahName: 'هود', fromAyah: 6, toAyah: 123, page: 221),
      JuzSection(surahNumber: 12, surahName: 'يوسف', fromAyah: 1, toAyah: 52, page: 235),
    ],
    
    // الجزء الثالث عشر
    13: [
      JuzSection(surahNumber: 12, surahName: 'يوسف', fromAyah: 53, toAyah: 111, page: 242),
      JuzSection(surahNumber: 13, surahName: 'الرعد', fromAyah: 1, toAyah: 43, page: 249),
      JuzSection(surahNumber: 14, surahName: 'إبراهيم', fromAyah: 1, toAyah: 52, page: 255),
    ],
    
    // الجزء الرابع عشر
    14: [
      JuzSection(surahNumber: 15, surahName: 'الحجر', fromAyah: 1, toAyah: 99, page: 262),
      JuzSection(surahNumber: 16, surahName: 'النحل', fromAyah: 1, toAyah: 128, page: 267),
    ],
    
    // الجزء الخامس عشر
    15: [
      JuzSection(surahNumber: 17, surahName: 'الإسراء', fromAyah: 1, toAyah: 111, page: 282),
      JuzSection(surahNumber: 18, surahName: 'الكهف', fromAyah: 1, toAyah: 74, page: 293),
    ],
    
    // الجزء السادس عشر
    16: [
      JuzSection(surahNumber: 18, surahName: 'الكهف', fromAyah: 75, toAyah: 110, page: 302),
      JuzSection(surahNumber: 19, surahName: 'مريم', fromAyah: 1, toAyah: 98, page: 305),
      JuzSection(surahNumber: 20, surahName: 'طه', fromAyah: 1, toAyah: 135, page: 312),
    ],
    
    // الجزء السابع عشر
    17: [
      JuzSection(surahNumber: 21, surahName: 'الأنبياء', fromAyah: 1, toAyah: 112, page: 322),
      JuzSection(surahNumber: 22, surahName: 'الحج', fromAyah: 1, toAyah: 78, page: 332),
    ],
    
    // الجزء الثامن عشر
    18: [
      JuzSection(surahNumber: 23, surahName: 'المؤمنون', fromAyah: 1, toAyah: 118, page: 342),
      JuzSection(surahNumber: 24, surahName: 'النور', fromAyah: 1, toAyah: 64, page: 350),
      JuzSection(surahNumber: 25, surahName: 'الفرقان', fromAyah: 1, toAyah: 20, page: 359),
    ],
    
    // الجزء التاسع عشر
    19: [
      JuzSection(surahNumber: 25, surahName: 'الفرقان', fromAyah: 21, toAyah: 77, page: 360),
      JuzSection(surahNumber: 26, surahName: 'الشعراء', fromAyah: 1, toAyah: 227, page: 367),
      JuzSection(surahNumber: 27, surahName: 'النمل', fromAyah: 1, toAyah: 55, page: 377),
    ],
    
    // الجزء العشرون
    20: [
      JuzSection(surahNumber: 27, surahName: 'النمل', fromAyah: 56, toAyah: 93, page: 382),
      JuzSection(surahNumber: 28, surahName: 'القصص', fromAyah: 1, toAyah: 88, page: 385),
      JuzSection(surahNumber: 29, surahName: 'العنكبوت', fromAyah: 1, toAyah: 45, page: 396),
    ],
    
    // الجزء الحادي والعشرون
    21: [
      JuzSection(surahNumber: 29, surahName: 'العنكبوت', fromAyah: 46, toAyah: 69, page: 401),
      JuzSection(surahNumber: 30, surahName: 'الروم', fromAyah: 1, toAyah: 60, page: 404),
      JuzSection(surahNumber: 31, surahName: 'لقمان', fromAyah: 1, toAyah: 34, page: 411),
      JuzSection(surahNumber: 32, surahName: 'السجدة', fromAyah: 1, toAyah: 30, page: 415),
      JuzSection(surahNumber: 33, surahName: 'الأحزاب', fromAyah: 1, toAyah: 30, page: 418),
    ],
    
    // الجزء الثاني والعشرون
    22: [
      JuzSection(surahNumber: 33, surahName: 'الأحزاب', fromAyah: 31, toAyah: 73, page: 422),
      JuzSection(surahNumber: 34, surahName: 'سبأ', fromAyah: 1, toAyah: 54, page: 428),
      JuzSection(surahNumber: 35, surahName: 'فاطر', fromAyah: 1, toAyah: 45, page: 434),
      JuzSection(surahNumber: 36, surahName: 'يس', fromAyah: 1, toAyah: 27, page: 440),
    ],
    
    // الجزء الثالث والعشرون
    23: [
      JuzSection(surahNumber: 36, surahName: 'يس', fromAyah: 28, toAyah: 83, page: 442),
      JuzSection(surahNumber: 37, surahName: 'الصافات', fromAyah: 1, toAyah: 182, page: 446),
      JuzSection(surahNumber: 38, surahName: 'ص', fromAyah: 1, toAyah: 88, page: 453),
      JuzSection(surahNumber: 39, surahName: 'الزمر', fromAyah: 1, toAyah: 31, page: 458),
    ],
    
    // الجزء الرابع والعشرون
    24: [
      JuzSection(surahNumber: 39, surahName: 'الزمر', fromAyah: 32, toAyah: 75, page: 462),
      JuzSection(surahNumber: 40, surahName: 'غافر', fromAyah: 1, toAyah: 85, page: 467),
      JuzSection(surahNumber: 41, surahName: 'فصلت', fromAyah: 1, toAyah: 46, page: 477),
    ],
    
    // الجزء الخامس والعشرون
    25: [
      JuzSection(surahNumber: 41, surahName: 'فصلت', fromAyah: 47, toAyah: 54, page: 482),
      JuzSection(surahNumber: 42, surahName: 'الشورى', fromAyah: 1, toAyah: 53, page: 483),
      JuzSection(surahNumber: 43, surahName: 'الزخرف', fromAyah: 1, toAyah: 89, page: 489),
      JuzSection(surahNumber: 44, surahName: 'الدخان', fromAyah: 1, toAyah: 59, page: 496),
      JuzSection(surahNumber: 45, surahName: 'الجاثية', fromAyah: 1, toAyah: 37, page: 499),
    ],
    
    // الجزء السادس والعشرون
    26: [
      JuzSection(surahNumber: 46, surahName: 'الأحقاف', fromAyah: 1, toAyah: 35, page: 502),
      JuzSection(surahNumber: 47, surahName: 'محمد', fromAyah: 1, toAyah: 38, page: 507),
      JuzSection(surahNumber: 48, surahName: 'الفتح', fromAyah: 1, toAyah: 29, page: 511),
      JuzSection(surahNumber: 49, surahName: 'الحجرات', fromAyah: 1, toAyah: 18, page: 515),
      JuzSection(surahNumber: 50, surahName: 'ق', fromAyah: 1, toAyah: 45, page: 518),
      JuzSection(surahNumber: 51, surahName: 'الذاريات', fromAyah: 1, toAyah: 30, page: 520),
    ],
    
    // الجزء السابع والعشرون
    27: [
      JuzSection(surahNumber: 51, surahName: 'الذاريات', fromAyah: 31, toAyah: 60, page: 522),
      JuzSection(surahNumber: 52, surahName: 'الطور', fromAyah: 1, toAyah: 49, page: 523),
      JuzSection(surahNumber: 53, surahName: 'النجم', fromAyah: 1, toAyah: 62, page: 526),
      JuzSection(surahNumber: 54, surahName: 'القمر', fromAyah: 1, toAyah: 55, page: 528),
      JuzSection(surahNumber: 55, surahName: 'الرحمن', fromAyah: 1, toAyah: 78, page: 531),
      JuzSection(surahNumber: 56, surahName: 'الواقعة', fromAyah: 1, toAyah: 96, page: 534),
      JuzSection(surahNumber: 57, surahName: 'الحديد', fromAyah: 1, toAyah: 29, page: 537),
    ],
    
    // الجزء الثامن والعشرون
    28: [
      JuzSection(surahNumber: 58, surahName: 'المجادلة', fromAyah: 1, toAyah: 22, page: 542),
      JuzSection(surahNumber: 59, surahName: 'الحشر', fromAyah: 1, toAyah: 24, page: 545),
      JuzSection(surahNumber: 60, surahName: 'الممتحنة', fromAyah: 1, toAyah: 13, page: 549),
      JuzSection(surahNumber: 61, surahName: 'الصف', fromAyah: 1, toAyah: 14, page: 551),
      JuzSection(surahNumber: 62, surahName: 'الجمعة', fromAyah: 1, toAyah: 11, page: 553),
      JuzSection(surahNumber: 63, surahName: 'المنافقون', fromAyah: 1, toAyah: 11, page: 554),
      JuzSection(surahNumber: 64, surahName: 'التغابن', fromAyah: 1, toAyah: 18, page: 556),
      JuzSection(surahNumber: 65, surahName: 'الطلاق', fromAyah: 1, toAyah: 12, page: 558),
      JuzSection(surahNumber: 66, surahName: 'التحريم', fromAyah: 1, toAyah: 12, page: 560),
    ],
    
    // الجزء التاسع والعشرون
    29: [
      JuzSection(surahNumber: 67, surahName: 'الملك', fromAyah: 1, toAyah: 30, page: 562),
      JuzSection(surahNumber: 68, surahName: 'القلم', fromAyah: 1, toAyah: 52, page: 564),
      JuzSection(surahNumber: 69, surahName: 'الحاقة', fromAyah: 1, toAyah: 52, page: 566),
      JuzSection(surahNumber: 70, surahName: 'المعارج', fromAyah: 1, toAyah: 44, page: 568),
      JuzSection(surahNumber: 71, surahName: 'نوح', fromAyah: 1, toAyah: 28, page: 570),
      JuzSection(surahNumber: 72, surahName: 'الجن', fromAyah: 1, toAyah: 28, page: 572),
      JuzSection(surahNumber: 73, surahName: 'المزمل', fromAyah: 1, toAyah: 20, page: 574),
      JuzSection(surahNumber: 74, surahName: 'المدثر', fromAyah: 1, toAyah: 56, page: 575),
      JuzSection(surahNumber: 75, surahName: 'القيامة', fromAyah: 1, toAyah: 40, page: 577),
      JuzSection(surahNumber: 76, surahName: 'الإنسان', fromAyah: 1, toAyah: 31, page: 578),
      JuzSection(surahNumber: 77, surahName: 'المرسلات', fromAyah: 1, toAyah: 50, page: 580),
    ],
    
    // الجزء الثلاثون (جزء عم)
    30: [
      JuzSection(surahNumber: 78, surahName: 'النبأ', fromAyah: 1, toAyah: 40, page: 582),
      JuzSection(surahNumber: 79, surahName: 'النازعات', fromAyah: 1, toAyah: 46, page: 583),
      JuzSection(surahNumber: 80, surahName: 'عبس', fromAyah: 1, toAyah: 42, page: 585),
      JuzSection(surahNumber: 81, surahName: 'التكوير', fromAyah: 1, toAyah: 29, page: 586),
      JuzSection(surahNumber: 82, surahName: 'الانفطار', fromAyah: 1, toAyah: 19, page: 587),
      JuzSection(surahNumber: 83, surahName: 'المطففين', fromAyah: 1, toAyah: 36, page: 587),
      JuzSection(surahNumber: 84, surahName: 'الانشقاق', fromAyah: 1, toAyah: 25, page: 589),
      JuzSection(surahNumber: 85, surahName: 'البروج', fromAyah: 1, toAyah: 22, page: 590),
      JuzSection(surahNumber: 86, surahName: 'الطارق', fromAyah: 1, toAyah: 17, page: 591),
      JuzSection(surahNumber: 87, surahName: 'الأعلى', fromAyah: 1, toAyah: 19, page: 591),
      JuzSection(surahNumber: 88, surahName: 'الغاشية', fromAyah: 1, toAyah: 26, page: 592),
      JuzSection(surahNumber: 89, surahName: 'الفجر', fromAyah: 1, toAyah: 30, page: 593),
      JuzSection(surahNumber: 90, surahName: 'البلد', fromAyah: 1, toAyah: 20, page: 594),
      JuzSection(surahNumber: 91, surahName: 'الشمس', fromAyah: 1, toAyah: 15, page: 595),
      JuzSection(surahNumber: 92, surahName: 'الليل', fromAyah: 1, toAyah: 21, page: 595),
      JuzSection(surahNumber: 93, surahName: 'الضحى', fromAyah: 1, toAyah: 11, page: 596),
      JuzSection(surahNumber: 94, surahName: 'الشرح', fromAyah: 1, toAyah: 8, page: 596),
      JuzSection(surahNumber: 95, surahName: 'التين', fromAyah: 1, toAyah: 8, page: 597),
      JuzSection(surahNumber: 96, surahName: 'العلق', fromAyah: 1, toAyah: 19, page: 597),
      JuzSection(surahNumber: 97, surahName: 'القدر', fromAyah: 1, toAyah: 5, page: 598),
      JuzSection(surahNumber: 98, surahName: 'البينة', fromAyah: 1, toAyah: 8, page: 598),
      JuzSection(surahNumber: 99, surahName: 'الزلزلة', fromAyah: 1, toAyah: 8, page: 599),
      JuzSection(surahNumber: 100, surahName: 'العاديات', fromAyah: 1, toAyah: 11, page: 599),
      JuzSection(surahNumber: 101, surahName: 'القارعة', fromAyah: 1, toAyah: 11, page: 600),
      JuzSection(surahNumber: 102, surahName: 'التكاثر', fromAyah: 1, toAyah: 8, page: 600),
      JuzSection(surahNumber: 103, surahName: 'العصر', fromAyah: 1, toAyah: 3, page: 601),
      JuzSection(surahNumber: 104, surahName: 'الهمزة', fromAyah: 1, toAyah: 9, page: 601),
      JuzSection(surahNumber: 105, surahName: 'الفيل', fromAyah: 1, toAyah: 5, page: 601),
      JuzSection(surahNumber: 106, surahName: 'قريش', fromAyah: 1, toAyah: 4, page: 602),
      JuzSection(surahNumber: 107, surahName: 'الماعون', fromAyah: 1, toAyah: 7, page: 602),
      JuzSection(surahNumber: 108, surahName: 'الكوثر', fromAyah: 1, toAyah: 3, page: 602),
      JuzSection(surahNumber: 109, surahName: 'الكافرون', fromAyah: 1, toAyah: 6, page: 603),
      JuzSection(surahNumber: 110, surahName: 'النصر', fromAyah: 1, toAyah: 3, page: 603),
      JuzSection(surahNumber: 111, surahName: 'المسد', fromAyah: 1, toAyah: 5, page: 603),
      JuzSection(surahNumber: 112, surahName: 'الإخلاص', fromAyah: 1, toAyah: 4, page: 604),
      JuzSection(surahNumber: 113, surahName: 'الفلق', fromAyah: 1, toAyah: 5, page: 604),
      JuzSection(surahNumber: 114, surahName: 'الناس', fromAyah: 1, toAyah: 6, page: 604),
    ],
  };
}

// ════════════════════════════════════════════════════════════════
//  JuzSection — قسم من الجزء (سورة أو جزء من سورة)
// ════════════════════════════════════════════════════════════════
class JuzSection {
  final int surahNumber;
  final String surahName;
  final int fromAyah;
  final int toAyah;
  final int page;

  const JuzSection({
    required this.surahNumber,
    required this.surahName,
    required this.fromAyah,
    required this.toAyah,
    required this.page,
  });
}
