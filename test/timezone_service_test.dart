// اختبارات TimezoneService — المرحلة 5 من خطة موثوقية الأذان.
//
// يختبر المنطق الصِرف (pure) فقط:
//   • pickZoneName() — بلا أي I/O إطلاقاً.
//   • applyZoneWithFallback() — يلمس حالة tz العامة (tz.setLocalLocation)
//     لكن بلا أي قناة منصّة (flutter_timezone) ولا Context؛ يحتاج فقط
//     tz.initializeTimeZones() في setUpAll (قاعدة بيانات في الذاكرة،
//     لا شيء ناتيف).
//
// ما لا يُختبر هنا عمداً: resolveAndApply() نفسها تستدعي
// FlutterTimezone.getLocalTimezone() (قناة منصّة حقيقية) — نفس القيد
// المقبول على كل أغلفة I/O الحقيقية في هذه الجلسة (راجع
// prefs_migration_test.dart، battery_prompt_service_test.dart، إلخ).

import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/core/services/timezone_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('TimezoneService.pickZoneName — اختيار الاسم (pure)', () {
    test('اسم صحيح غير فارغ يُعاد كما هو', () {
      expect(TimezoneService.pickZoneName('Europe/London'), 'Europe/London');
    });

    test('اسم يحمل مسافات زائدة يُعاد بعد trim', () {
      expect(TimezoneService.pickZoneName('  Asia/Riyadh  '), 'Asia/Riyadh');
    });

    test('null ⇒ fallback الافتراضي (Africa/Cairo)', () {
      expect(TimezoneService.pickZoneName(null), 'Africa/Cairo');
    });

    test('سلسلة فارغة ⇒ fallback', () {
      expect(TimezoneService.pickZoneName(''), 'Africa/Cairo');
    });

    test('سلسلة مسافات فقط ⇒ fallback (تُعامَل كفارغة بعد trim)', () {
      expect(TimezoneService.pickZoneName('   '), 'Africa/Cairo');
    });

    test('fallback مخصّص يُحترَم', () {
      expect(TimezoneService.pickZoneName(null, fallback: 'UTC'), 'UTC');
      expect(TimezoneService.pickZoneName('', fallback: 'UTC'), 'UTC');
    });
  });

  group('TimezoneService.applyZoneWithFallback — التطبيق الفعلي مع fallback', () {
    test('اسم IANA صحيح ومعروف يُطبَّق كما هو ويُعاد بلا تغيير', () {
      final applied = TimezoneService.applyZoneWithFallback('Europe/London');
      expect(applied, 'Europe/London');
      expect(tz.local.name, 'Europe/London');
    });

    test('اسم غير معروف تماماً ⇒ يسقط إلى Africa/Cairo فعلياً', () {
      final applied = TimezoneService.applyZoneWithFallback(
        'Not/A_Real_Timezone',
      );
      expect(applied, 'Africa/Cairo');
      expect(tz.local.name, 'Africa/Cairo');
    });

    test('سلسلة فارغة مُمرَّرة مباشرةً (تجاوز pickZoneName) ⇒ fallback أيضاً', () {
      // دفاعي: أي مستدعٍ يتجاوز pickZoneName بالخطأ يجب أن يحصل على
      // نفس ضمان عدم الانهيار — tz.getLocation('') ترمي، فيُقبض عليها.
      final applied = TimezoneService.applyZoneWithFallback('');
      expect(applied, 'Africa/Cairo');
      expect(tz.local.name, 'Africa/Cairo');
    });

    test('fallback مخصّص يُطبَّق فعلياً عند اسم غير معروف', () {
      final applied = TimezoneService.applyZoneWithFallback(
        'Not/A_Real_Timezone',
        fallback: 'UTC',
      );
      expect(applied, 'UTC');
      expect(tz.local.name, 'UTC');
    });

    test('اسم صحيح لا يلمس fallback إطلاقاً حتى لو مُرِّر fallback مختلف', () {
      final applied = TimezoneService.applyZoneWithFallback(
        'Asia/Tokyo',
        fallback: 'UTC',
      );
      expect(applied, 'Asia/Tokyo');
      expect(tz.local.name, 'Asia/Tokyo');
    });
  });
}
