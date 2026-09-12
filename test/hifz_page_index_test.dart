// اختبارات HifzPageIndex — بنية المصحف المشتقة (604 صفحة).
// دوال نقية بالكامل، لا تحتاج Flutter bindings.

import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/core/data/hifz_page_index.dart';
import 'package:nour_ramadan/core/data/quran_page_data.dart';

void main() {
  group('HifzPageIndex — أساسيات', () {
    test('إجمالي عدد الصفحات = 604 (مصحف المدينة)', () {
      expect(HifzPageIndex.pageCount, 604);
    });

    test('الصفحة 1 تبدأ بالفاتحة 1:1، والصفحة 604 تنتهي بآخر سورة', () {
      final first = HifzPageIndex.firstAyahOfPage(1);
      expect(first.surah, 1);
      expect(first.ayah, 1);

      final lastPageSurahs = HifzPageIndex.surahRangeOnPage(604);
      expect(lastPageSurahs.lastSurah, 114);
    });
  });

  group('HifzPageIndex — جزء ↔ صفحة', () {
    test('كل الأجزاء الثلاثين غير فارغة ومتصلة (contiguous) بلا فجوات', () {
      for (var j = 1; j <= 30; j++) {
        final pages = HifzPageIndex.pagesInJuz(j);
        expect(pages, isNotEmpty, reason: 'الجزء $j فارغ');
        final sorted = [...pages]..sort();
        expect(pages, sorted, reason: 'الجزء $j غير مرتّب');
        for (var i = 1; i < sorted.length; i++) {
          expect(
            sorted[i],
            sorted[i - 1] + 1,
            reason: 'فجوة داخل الجزء $j بين ${sorted[i - 1]} و ${sorted[i]}',
          );
        }
      }
    });

    test('اتحاد صفحات كل الأجزاء الثلاثين = 604 صفحة بلا تكرار وبلا نقص', () {
      final all = <int>{};
      for (var j = 1; j <= 30; j++) {
        for (final p in HifzPageIndex.pagesInJuz(j)) {
          expect(all.contains(p), isFalse, reason: 'الصفحة $p ضمن أكثر من جزء');
          all.add(p);
        }
      }
      expect(all.length, 604);
      expect(all.reduce((a, b) => a < b ? a : b), 1);
      expect(all.reduce((a, b) => a > b ? a : b), 604);
    });

    test('juzOfPage يطابق pagesInJuz (اتساق ثنائي الاتجاه)', () {
      for (var j = 1; j <= 30; j++) {
        for (final p in HifzPageIndex.pagesInJuz(j)) {
          expect(HifzPageIndex.juzOfPage(p), j);
        }
      }
    });
  });

  group('HifzPageIndex — ربع الحزب/الحزب ↔ صفحة', () {
    test('اتحاد pagesInQuarter لكل الـ240 ربعاً يقسّم الـ604 صفحة تماماً', () {
      final all = <int>{};
      for (var q = 1; q <= 240; q++) {
        for (final p in HifzPageIndex.pagesInQuarter(q)) {
          expect(all.contains(p), isFalse, reason: 'الصفحة $p ضمن أكثر من ربع');
          all.add(p);
        }
      }
      expect(all.length, 604);
    });

    test('quarterOfPage يطابق pagesInQuarter (اتساق ثنائي الاتجاه)', () {
      for (var q = 1; q <= 240; q++) {
        for (final p in HifzPageIndex.pagesInQuarter(q)) {
          expect(HifzPageIndex.quarterOfPage(p), q);
        }
      }
    });

    test('pagesInHizb(h) = اتحاد الأرباع الأربعة المكوِّنة له', () {
      for (var h = 1; h <= 60; h++) {
        final expected = <int>{};
        final firstQuarter = (h - 1) * 4 + 1;
        for (var q = firstQuarter; q <= firstQuarter + 3; q++) {
          expected.addAll(HifzPageIndex.pagesInQuarter(q));
        }
        expect(HifzPageIndex.pagesInHizb(h).toSet(), expected);
      }
    });

    test('hizbOfPage = ((quarterOfPage-1) ~/ 4) + 1 لكل صفحة', () {
      for (var p = 1; p <= HifzPageIndex.pageCount; p++) {
        final q = HifzPageIndex.quarterOfPage(p);
        expect(HifzPageIndex.hizbOfPage(p), ((q - 1) ~/ 4) + 1);
      }
    });
  });

  group('HifzPageIndex — جولة كاملة (round-trip) ضد QuranPageData', () {
    test('أول آية في كل صفحة تُرجِع نفس رقم الصفحة عند مراجعتها في QuranPageData', () {
      for (var p = 1; p <= HifzPageIndex.pageCount; p++) {
        final first = HifzPageIndex.firstAyahOfPage(p);
        final info = QuranPageData.getAyahInfo(first.surah, first.ayah);
        expect(info, isNotNull, reason: 'لا بيانات للآية ${first.surah}:${first.ayah}');
        expect(info!.page, p);
        expect(HifzPageIndex.juzOfPage(p), info.juz);
        expect(HifzPageIndex.quarterOfPage(p), info.hizbQuarter);
      }
    });

    test('pagesOfSurah(1) = [1] (الفاتحة بأكملها في الصفحة الأولى)', () {
      expect(HifzPageIndex.pagesOfSurah(1), [1]);
    });

    test('pagesOfSurah(114) تنتهي بالصفحة 604 (الناس آخر سورة)', () {
      final pages = HifzPageIndex.pagesOfSurah(114);
      expect(pages, isNotEmpty);
      expect(pages.last, 604);
    });

    test('pagesOfSurah مرتّبة تصاعدياً بلا تكرار لكل السور الـ114', () {
      for (var s = 1; s <= 114; s++) {
        final pages = HifzPageIndex.pagesOfSurah(s);
        expect(pages, isNotEmpty, reason: 'السورة $s بلا صفحات');
        final sorted = [...pages]..sort();
        expect(pages, sorted, reason: 'صفحات السورة $s غير مرتّبة');
        expect(pages.toSet().length, pages.length, reason: 'تكرار في صفحات السورة $s');
      }
    });
  });
}
