import 'quran_page_data.dart';

// ════════════════════════════════════════════════════════════════
//  HifzPageIndex — فهرس مشتق لبنية المصحف (604 صفحة)
//  محسوب مرة واحدة من QuranPageData.ayahPageInfo — بلا أي اعتماديات
//  خارجية (بدون Hive/Riverpod). عام وقابل لإعادة الاستخدام خارج
//  نطاق الحفظ (لذلك يعيش في core/data وليس features/hifz).
//
//  ملاحظة: كل صفحة تُنسب إلى الجزء/الربع الخاص بأول آية فيها. تم
//  التحقق (انظر plan_hifz.md §0) من أن حدود الأجزاء في هذه البيانات
//  تقع عند بداية صفحة دائماً، فالصفحة تنتمي لجزء واحد فقط بلا لبس.
// ════════════════════════════════════════════════════════════════

class HifzPageIndex {
  HifzPageIndex._();

  static bool _built = false;
  static final Map<int, List<({int surah, int ayah})>> _pageToAyahs = {};
  static final Map<int, int> _pageToJuz = {};
  static final Map<int, int> _pageToQuarter = {};
  static final Map<int, List<int>> _juzToPages = {};
  static final Map<int, List<int>> _quarterToPages = {};
  static final Map<int, List<int>> _surahToPages = {};
  static int _maxPage = 0;

  static void _build() {
    if (_built) return;

    final surahs = QuranPageData.ayahPageInfo.keys.toList()..sort();
    for (final s in surahs) {
      final ayahMap = QuranPageData.ayahPageInfo[s]!;
      final ayahs = ayahMap.keys.toList()..sort();
      final pagesOfThisSurah = <int>[];

      for (final a in ayahs) {
        final info = ayahMap[a]!;
        final p = info.page;
        if (p > _maxPage) _maxPage = p;

        (_pageToAyahs[p] ??= []).add((surah: s, ayah: a));
        // أول آية تصل لهذه الصفحة هي التي تحدد جزءها وربعها
        _pageToJuz.putIfAbsent(p, () => info.juz);
        _pageToQuarter.putIfAbsent(p, () => info.hizbQuarter);

        if (pagesOfThisSurah.isEmpty || pagesOfThisSurah.last != p) {
          pagesOfThisSurah.add(p);
        }
      }
      _surahToPages[s] = pagesOfThisSurah;
    }

    for (var p = 1; p <= _maxPage; p++) {
      final j = _pageToJuz[p];
      if (j != null) (_juzToPages[j] ??= []).add(p);
      final q = _pageToQuarter[p];
      if (q != null) (_quarterToPages[q] ??= []).add(p);
    }

    _built = true;
  }

  /// إجمالي عدد صفحات المصحف (604 في مصحف المدينة).
  static int get pageCount {
    _build();
    return _maxPage;
  }

  /// أول آية (سورة/رقم آية) تقع في هذه الصفحة — لفتح القارئ عليها.
  static ({int surah, int ayah}) firstAyahOfPage(int page) {
    _build();
    final list = _pageToAyahs[page];
    if (list == null || list.isEmpty) {
      throw ArgumentError('لا توجد بيانات للصفحة $page');
    }
    return list.first;
  }

  /// نطاق أرقام السور التي تظهر ضمن هذه الصفحة (قد تكون سورة واحدة).
  static ({int firstSurah, int lastSurah}) surahRangeOnPage(int page) {
    _build();
    final list = _pageToAyahs[page];
    if (list == null || list.isEmpty) {
      throw ArgumentError('لا توجد بيانات للصفحة $page');
    }
    return (firstSurah: list.first.surah, lastSurah: list.last.surah);
  }

  /// كل أرقام الصفحات ضمن جزء معيّن (1–30)، بترتيب تصاعدي.
  static List<int> pagesInJuz(int juz) {
    _build();
    return List.unmodifiable(_juzToPages[juz] ?? const <int>[]);
  }

  /// رقم الجزء الذي تنتمي إليه صفحة معيّنة (0 إن لم توجد).
  static int juzOfPage(int page) {
    _build();
    return _pageToJuz[page] ?? 0;
  }

  /// رقم "ربع الحزب" (1–240) الذي تبدأ فيه الصفحة.
  static int quarterOfPage(int page) {
    _build();
    return _pageToQuarter[page] ?? 0;
  }

  /// رقم "الحزب" (1–60) الذي تبدأ فيه الصفحة، مشتق من الربع.
  static int hizbOfPage(int page) {
    _build();
    final q = _pageToQuarter[page] ?? 0;
    if (q == 0) return 0;
    return ((q - 1) ~/ 4) + 1;
  }

  /// كل الصفحات التي تبدأ ضمن ربع حزب معيّن (1–240).
  static List<int> pagesInQuarter(int quarter) {
    _build();
    return List.unmodifiable(_quarterToPages[quarter] ?? const <int>[]);
  }

  /// كل الصفحات التي تبدأ ضمن حزب معيّن (1–60) — تجميع 4 أرباع.
  static List<int> pagesInHizb(int hizb) {
    _build();
    final out = <int>[];
    final firstQuarter = (hizb - 1) * 4 + 1;
    for (var q = firstQuarter; q <= firstQuarter + 3; q++) {
      out.addAll(_quarterToPages[q] ?? const <int>[]);
    }
    out.sort();
    return out;
  }

  /// كل الصفحات التي تحتوي على آية من سورة معيّنة.
  static List<int> pagesOfSurah(int surah) {
    _build();
    return List.unmodifiable(_surahToPages[surah] ?? const <int>[]);
  }
}
