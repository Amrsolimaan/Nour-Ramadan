// ════════════════════════════════════════════════════════════════
//  QuranDataService — بيانات السور والجزء والصفحات
//  المصدر: بيانات ثابتة مدمجة (لا تحتاج API)
//  يشمل: اسم السورة + ترتيبها + عدد آياتها + نوعها + رقم جزئها
// ════════════════════════════════════════════════════════════════

class QuranDataService {
  QuranDataService._();
  static final instance = QuranDataService._();

  // ── بيانات السور الـ 114 ────────────────────────────────────────
  static const List<SurahInfo> surahs = [
    SurahInfo(1,  'الفاتحة',       'Al-Fatihah',    7,   1,  1,  SurahType.makki),
    SurahInfo(2,  'البقرة',        'Al-Baqarah',    286, 1,  2,  SurahType.madani),
    SurahInfo(3,  'آل عمران',      'Ali \'Imran',   200, 3,  4,  SurahType.madani),
    SurahInfo(4,  'النساء',        'An-Nisa\'',     176, 4,  5,  SurahType.madani),
    SurahInfo(5,  'المائدة',       'Al-Ma\'idah',   120, 6,  6,  SurahType.madani),
    SurahInfo(6,  'الأنعام',       'Al-An\'am',     165, 7,  7,  SurahType.makki),
    SurahInfo(7,  'الأعراف',       'Al-A\'raf',     206, 8,  8,  SurahType.makki),
    SurahInfo(8,  'الأنفال',       'Al-Anfal',      75,  9,  10, SurahType.madani),
    SurahInfo(9,  'التوبة',        'At-Tawbah',     129, 10, 10, SurahType.madani),
    SurahInfo(10, 'يونس',          'Yunus',         109, 11, 11, SurahType.makki),
    SurahInfo(11, 'هود',           'Hud',           123, 11, 12, SurahType.makki),
    SurahInfo(12, 'يوسف',          'Yusuf',         111, 12, 12, SurahType.makki),
    SurahInfo(13, 'الرعد',         'Ar-Ra\'d',      43,  13, 13, SurahType.madani),
    SurahInfo(14, 'إبراهيم',       'Ibrahim',       52,  13, 13, SurahType.makki),
    SurahInfo(15, 'الحجر',         'Al-Hijr',       99,  14, 14, SurahType.makki),
    SurahInfo(16, 'النحل',         'An-Nahl',       128, 14, 14, SurahType.makki),
    SurahInfo(17, 'الإسراء',       'Al-Isra\'',     111, 15, 15, SurahType.makki),
    SurahInfo(18, 'الكهف',         'Al-Kahf',       110, 15, 16, SurahType.makki),
    SurahInfo(19, 'مريم',          'Maryam',        98,  16, 16, SurahType.makki),
    SurahInfo(20, 'طه',            'Ta-Ha',         135, 16, 16, SurahType.makki),
    SurahInfo(21, 'الأنبياء',      'Al-Anbiya\'',   112, 17, 17, SurahType.makki),
    SurahInfo(22, 'الحج',          'Al-Hajj',       78,  17, 17, SurahType.madani),
    SurahInfo(23, 'المؤمنون',      'Al-Mu\'minun',  118, 18, 18, SurahType.makki),
    SurahInfo(24, 'النور',         'An-Nur',        64,  18, 18, SurahType.madani),
    SurahInfo(25, 'الفرقان',       'Al-Furqan',     77,  18, 19, SurahType.makki),
    SurahInfo(26, 'الشعراء',       'Ash-Shu\'ara\'',227, 19, 19, SurahType.makki),
    SurahInfo(27, 'النمل',         'An-Naml',       93,  19, 20, SurahType.makki),
    SurahInfo(28, 'القصص',         'Al-Qasas',      88,  20, 20, SurahType.makki),
    SurahInfo(29, 'العنكبوت',      'Al-\'Ankabut',  69,  20, 21, SurahType.makki),
    SurahInfo(30, 'الروم',         'Ar-Rum',        60,  21, 21, SurahType.makki),
    SurahInfo(31, 'لقمان',         'Luqman',        34,  21, 21, SurahType.makki),
    SurahInfo(32, 'السجدة',        'As-Sajdah',     30,  21, 21, SurahType.makki),
    SurahInfo(33, 'الأحزاب',       'Al-Ahzab',      73,  21, 22, SurahType.madani),
    SurahInfo(34, 'سبإ',           'Saba\'',        54,  22, 22, SurahType.makki),
    SurahInfo(35, 'فاطر',          'Fatir',         45,  22, 22, SurahType.makki),
    SurahInfo(36, 'يس',            'Ya-Sin',        83,  22, 23, SurahType.makki),
    SurahInfo(37, 'الصافات',       'As-Saffat',     182, 23, 23, SurahType.makki),
    SurahInfo(38, 'ص',             'Sad',           88,  23, 23, SurahType.makki),
    SurahInfo(39, 'الزمر',         'Az-Zumar',      75,  23, 24, SurahType.makki),
    SurahInfo(40, 'غافر',          'Ghafir',        85,  24, 24, SurahType.makki),
    SurahInfo(41, 'فصلت',          'Fussilat',      54,  24, 24, SurahType.makki),
    SurahInfo(42, 'الشورى',        'Ash-Shura',     53,  25, 25, SurahType.makki),
    SurahInfo(43, 'الزخرف',        'Az-Zukhruf',    89,  25, 25, SurahType.makki),
    SurahInfo(44, 'الدخان',        'Ad-Dukhan',     59,  25, 25, SurahType.makki),
    SurahInfo(45, 'الجاثية',       'Al-Jathiyah',   37,  25, 25, SurahType.makki),
    SurahInfo(46, 'الأحقاف',       'Al-Ahqaf',      35,  26, 26, SurahType.makki),
    SurahInfo(47, 'محمد',          'Muhammad',      38,  26, 26, SurahType.madani),
    SurahInfo(48, 'الفتح',         'Al-Fath',       29,  26, 26, SurahType.madani),
    SurahInfo(49, 'الحجرات',       'Al-Hujurat',    18,  26, 26, SurahType.madani),
    SurahInfo(50, 'ق',             'Qaf',           45,  26, 26, SurahType.makki),
    SurahInfo(51, 'الذاريات',      'Adh-Dhariyat',  60,  26, 27, SurahType.makki),
    SurahInfo(52, 'الطور',         'At-Tur',        49,  27, 27, SurahType.makki),
    SurahInfo(53, 'النجم',         'An-Najm',       62,  27, 27, SurahType.makki),
    SurahInfo(54, 'القمر',         'Al-Qamar',      55,  27, 27, SurahType.makki),
    SurahInfo(55, 'الرحمن',        'Ar-Rahman',     78,  27, 27, SurahType.madani),
    SurahInfo(56, 'الواقعة',       'Al-Waqi\'ah',   96,  27, 27, SurahType.makki),
    SurahInfo(57, 'الحديد',        'Al-Hadid',      29,  27, 27, SurahType.madani),
    SurahInfo(58, 'المجادلة',      'Al-Mujadila',   22,  28, 28, SurahType.madani),
    SurahInfo(59, 'الحشر',         'Al-Hashr',      24,  28, 28, SurahType.madani),
    SurahInfo(60, 'الممتحنة',      'Al-Mumtahanah', 13,  28, 28, SurahType.madani),
    SurahInfo(61, 'الصف',          'As-Saf',        14,  28, 28, SurahType.madani),
    SurahInfo(62, 'الجمعة',        'Al-Jumu\'ah',   11,  28, 28, SurahType.madani),
    SurahInfo(63, 'المنافقون',     'Al-Munafiqun',  11,  28, 28, SurahType.madani),
    SurahInfo(64, 'التغابن',       'At-Taghabun',   18,  28, 28, SurahType.madani),
    SurahInfo(65, 'الطلاق',        'At-Talaq',      12,  28, 28, SurahType.madani),
    SurahInfo(66, 'التحريم',       'At-Tahrim',     12,  28, 28, SurahType.madani),
    SurahInfo(67, 'الملك',         'Al-Mulk',       30,  29, 29, SurahType.makki),
    SurahInfo(68, 'القلم',         'Al-Qalam',      52,  29, 29, SurahType.makki),
    SurahInfo(69, 'الحاقة',        'Al-Haqqah',     52,  29, 29, SurahType.makki),
    SurahInfo(70, 'المعارج',       'Al-Ma\'arij',   44,  29, 29, SurahType.makki),
    SurahInfo(71, 'نوح',           'Nuh',           28,  29, 29, SurahType.makki),
    SurahInfo(72, 'الجن',          'Al-Jinn',       28,  29, 29, SurahType.makki),
    SurahInfo(73, 'المزمل',        'Al-Muzzammil',  20,  29, 29, SurahType.makki),
    SurahInfo(74, 'المدثر',        'Al-Muddaththir',56,  29, 29, SurahType.makki),
    SurahInfo(75, 'القيامة',       'Al-Qiyamah',    40,  29, 29, SurahType.makki),
    SurahInfo(76, 'الإنسان',       'Al-Insan',      31,  29, 29, SurahType.madani),
    SurahInfo(77, 'المرسلات',      'Al-Mursalat',   50,  29, 29, SurahType.makki),
    SurahInfo(78, 'النبأ',         'An-Naba\'',     40,  30, 30, SurahType.makki),
    SurahInfo(79, 'النازعات',      'An-Nazi\'at',   46,  30, 30, SurahType.makki),
    SurahInfo(80, 'عبس',           '\'Abasa',       42,  30, 30, SurahType.makki),
    SurahInfo(81, 'التكوير',       'At-Takwir',     29,  30, 30, SurahType.makki),
    SurahInfo(82, 'الانفطار',      'Al-Infitar',    19,  30, 30, SurahType.makki),
    SurahInfo(83, 'المطففين',      'Al-Mutaffifin', 36,  30, 30, SurahType.makki),
    SurahInfo(84, 'الانشقاق',      'Al-Inshiqaq',   25,  30, 30, SurahType.makki),
    SurahInfo(85, 'البروج',        'Al-Buruj',      22,  30, 30, SurahType.makki),
    SurahInfo(86, 'الطارق',        'At-Tariq',      17,  30, 30, SurahType.makki),
    SurahInfo(87, 'الأعلى',        'Al-A\'la',      19,  30, 30, SurahType.makki),
    SurahInfo(88, 'الغاشية',       'Al-Ghashiyah',  26,  30, 30, SurahType.makki),
    SurahInfo(89, 'الفجر',         'Al-Fajr',       30,  30, 30, SurahType.makki),
    SurahInfo(90, 'البلد',         'Al-Balad',      20,  30, 30, SurahType.makki),
    SurahInfo(91, 'الشمس',         'Ash-Shams',     15,  30, 30, SurahType.makki),
    SurahInfo(92, 'الليل',         'Al-Layl',       21,  30, 30, SurahType.makki),
    SurahInfo(93, 'الضحى',         'Ad-Duhaa',      11,  30, 30, SurahType.makki),
    SurahInfo(94, 'الشرح',         'Ash-Sharh',     8,   30, 30, SurahType.makki),
    SurahInfo(95, 'التين',         'At-Tin',        8,   30, 30, SurahType.makki),
    SurahInfo(96, 'العلق',         'Al-\'Alaq',     19,  30, 30, SurahType.makki),
    SurahInfo(97, 'القدر',         'Al-Qadr',       5,   30, 30, SurahType.makki),
    SurahInfo(98, 'البينة',        'Al-Bayyinah',   8,   30, 30, SurahType.madani),
    SurahInfo(99, 'الزلزلة',       'Az-Zalzalah',   8,   30, 30, SurahType.madani),
    SurahInfo(100,'العاديات',      'Al-\'Adiyat',   11,  30, 30, SurahType.makki),
    SurahInfo(101,'القارعة',       'Al-Qari\'ah',   11,  30, 30, SurahType.makki),
    SurahInfo(102,'التكاثر',       'At-Takathur',   8,   30, 30, SurahType.makki),
    SurahInfo(103,'العصر',         'Al-\'Asr',      3,   30, 30, SurahType.makki),
    SurahInfo(104,'الهمزة',        'Al-Humazah',    9,   30, 30, SurahType.makki),
    SurahInfo(105,'الفيل',         'Al-Fil',        5,   30, 30, SurahType.makki),
    SurahInfo(106,'قريش',          'Quraysh',       4,   30, 30, SurahType.makki),
    SurahInfo(107,'الماعون',       'Al-Ma\'un',     7,   30, 30, SurahType.makki),
    SurahInfo(108,'الكوثر',        'Al-Kawthar',    3,   30, 30, SurahType.makki),
    SurahInfo(109,'الكافرون',      'Al-Kafirun',    6,   30, 30, SurahType.makki),
    SurahInfo(110,'النصر',         'An-Nasr',       3,   30, 30, SurahType.madani),
    SurahInfo(111,'المسد',         'Al-Masad',      5,   30, 30, SurahType.makki),
    SurahInfo(112,'الإخلاص',       'Al-Ikhlas',     4,   30, 30, SurahType.makki),
    SurahInfo(113,'الفلق',         'Al-Falaq',      5,   30, 30, SurahType.makki),
    SurahInfo(114,'الناس',         'An-Nas',        6,   30, 30, SurahType.makki),
  ];

  // ── السور حسب الجزء ────────────────────────────────────────────
  List<SurahInfo> surahsByJuz(int juz) =>
      surahs.where((s) => s.juz == juz).toList();

  // ── جلب سورة بالرقم ────────────────────────────────────────────
  SurahInfo surahById(int id) =>
      surahs.firstWhere((s) => s.number == id);

  // ── بحث ────────────────────────────────────────────────────────
  List<SurahInfo> search(String q) {
    if (q.isEmpty) return surahs;
    return surahs.where((s) =>
      s.name.contains(q) || s.nameEn.toLowerCase().contains(q.toLowerCase())
    ).toList();
  }

  // ── أسماء الأجزاء الثلاثين ─────────────────────────────────────
  static const juzNames = <String>[
    'الجزء الأول',   'الجزء الثاني',   'الجزء الثالث',
    'الجزء الرابع',  'الجزء الخامس',   'الجزء السادس',
    'الجزء السابع',  'الجزء الثامن',   'الجزء التاسع',
    'الجزء العاشر',  'الجزء الحادي عشر','الجزء الثاني عشر',
    'الجزء الثالث عشر','الجزء الرابع عشر','الجزء الخامس عشر',
    'الجزء السادس عشر','الجزء السابع عشر','الجزء الثامن عشر',
    'الجزء التاسع عشر','الجزء العشرون', 'الجزء الحادي والعشرون',
    'الجزء الثاني والعشرون','الجزء الثالث والعشرون','الجزء الرابع والعشرون',
    'الجزء الخامس والعشرون','الجزء السادس والعشرون','الجزء السابع والعشرون',
    'الجزء الثامن والعشرون','الجزء التاسع والعشرون','الجزء الثلاثون',
  ];
}

// ════════════════════════════════════════════════════════════════
//  SurahInfo — بيانات السورة
// ════════════════════════════════════════════════════════════════

class SurahInfo {
  const SurahInfo(
    this.number,
    this.name,
    this.nameEn,
    this.ayahCount,
    this.juz,
    this.page,
    this.type,
  );

  final int        number;
  final String     name;
  final String     nameEn;
  final int        ayahCount;
  final int        juz;       // رقم الجزء الذي تبدأ فيه
  final int        page;      // رقم الصفحة الأولى
  final SurahType  type;

  String get typeLabel => type == SurahType.makki ? 'مكية' : 'مدنية';
}

enum SurahType { makki, madani }
