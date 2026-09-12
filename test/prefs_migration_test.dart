// اختبارات PrefsMigration + PrefKeys — المرحلة 1 من خطة موثوقية الأذان.
//
// الهدف: إثبات أن المفاتيح تنتهي حيث تقرأها طبقة Kotlin بالفعل.
//
// ملاحظة حرجة حول ما يُقاس هنا:
//   حزمة shared_preferences تُضيف بادئة 'flutter.' لكل مفتاح عند التخزين،
//   وتُزيلها عند القراءة. لذلك مفتاح Dart 'last_lat' يُخزَّن على Android
//   كـ 'flutter.last_lat' — وهو ما يقرأه AlarmScheduler.kt.
//   والمفتاح القديم 'flutter.last_lat' كان يُخزَّن 'flutter.flutter.last_lat'.
//
//   انظر مساعدَي legacyStored/correctStored أدناه للتفريق الدقيق بين
//   "مفتاح Dart" و"المفتاح المخزَّن خام على Android".
//   راجع plan_azan_reliability.md §1.8

import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/core/services/prefs_keys.dart';
import 'package:nour_ramadan/core/services/prefs_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ══════════════════════════════════════════════════════════════
  //  مساعدات — تفرّق بين "مفتاح Dart" و"المفتاح المخزَّن على Android"
  //
  //  setMockInitialValues يتعامل مع مفاتيحه كمفاتيح مخزَّنة خام:
  //  إن بدأ المفتاح بـ 'flutter.' يُترك كما هو، وإلا تُضاف البادئة.
  //  (shared_preferences_legacy.dart:278)
  //
  //  الحالة القديمة (قبل الإصلاح):
  //    Dart كتب 'flutter.last_lat' → الحزمة أضافت بادئتها
  //    → المخزَّن خام = 'flutter.flutter.last_lat'
  //    → ومن فضاء Dart يظهر باسم 'flutter.last_lat'   ← ما يرحّله الكود
  //
  //  الحالة الصحيحة (بعد الإصلاح):
  //    Dart يكتب 'last_lat' → المخزَّن خام = 'flutter.last_lat'
  //    → وهو بالضبط ما يقرأه AlarmScheduler.kt
  // ══════════════════════════════════════════════════════════════

  /// المفتاح المخزَّن خام لحالة ما قبل الإصلاح (بادئة مزدوجة).
  String legacyStored(String dartKey) => 'flutter.flutter.$dartKey';

  /// المفتاح المخزَّن خام للحالة الصحيحة (ما يقرأه Kotlin).
  String correctStored(String dartKey) => 'flutter.$dartKey';

  group('PrefKeys — العقد مع Kotlin', () {
    test('لا مفتاح يحمل البادئة "flutter." يدوياً', () {
      expect(PrefKeys.lastLat, 'last_lat');
      expect(PrefKeys.lastLng, 'last_lng');
      expect(PrefKeys.lastSoundFileScheduled, 'last_sound_file_scheduled');
      expect(PrefKeys.azanTime(100), 'azan_100_time');
      expect(PrefKeys.azanPrayer(100), 'azan_100_prayer');
      expect(PrefKeys.azanSound(150), 'azan_150_sound');

      for (final k in [
        PrefKeys.lastLat,
        PrefKeys.lastLng,
        PrefKeys.lastSoundFileScheduled,
        PrefKeys.migrationV1Done,
        PrefKeys.azanTime(100),
        PrefKeys.azanPrayer(100),
        PrefKeys.azanSound(100),
      ]) {
        expect(
          k.startsWith('flutter.'),
          isFalse,
          reason: 'المفتاح "$k" يحمل بادئة مزدوجة — راجع §1.8',
        );
      }
    });

    test('guard يفشل في debug على مفتاح مسبوق بـ flutter.', () {
      expect(() => PrefKeys.guard('flutter.last_lat'), throwsA(isA<AssertionError>()));
      expect(PrefKeys.guard('last_lat'), 'last_lat');
    });

    test('علم الترحيل خارج نطاق azan_ حتى لا يُحتسب مفتاح أذان', () {
      expect(PrefKeys.migrationV1Done.startsWith(PrefKeys.azanPrefix), isFalse);
    });

    test('azanKeyPattern يطابق مفاتيح الأذان فقط', () {
      expect(PrefKeys.azanKeyPattern.firstMatch('azan_100_time')?.group(1), '100');
      expect(PrefKeys.azanKeyPattern.firstMatch('azan_215_sound')?.group(1), '215');
      // لا يطابق: علم الترحيل، ولا المفتاح القديم مزدوج البادئة
      expect(PrefKeys.azanKeyPattern.hasMatch('prefs_migration_v1_done'), isFalse);
      expect(PrefKeys.azanKeyPattern.hasMatch('flutter.azan_100_time'), isFalse);
      expect(PrefKeys.azanKeyPattern.hasMatch('azan_settings_box'), isFalse);
    });
  });

  group('PrefsMigration.run()', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ينقل المفاتيح القديمة إلى أسمائها الصحيحة ويحذف القديمة', () async {
      SharedPreferences.setMockInitialValues({
        legacyStored('last_lat'): '30.0444',
        legacyStored('last_lng'): '31.2357',
        legacyStored('azan_100_time'): '1789000000000',
        legacyStored('azan_100_prayer'): 'الفجر',
        legacyStored('azan_100_sound'): 'azan_abdelbaset',
      });

      await PrefsMigration.run();
      final prefs = await SharedPreferences.getInstance();

      // الأسماء الجديدة موجودة بقيمها
      expect(prefs.getString(PrefKeys.lastLat), '30.0444');
      expect(prefs.getString(PrefKeys.lastLng), '31.2357');
      expect(prefs.getString(PrefKeys.azanTime(100)), '1789000000000');
      expect(prefs.getString(PrefKeys.azanPrayer(100)), 'الفجر');
      expect(prefs.getString(PrefKeys.azanSound(100)), 'azan_abdelbaset');

      // الأسماء القديمة اختفت
      expect(prefs.containsKey('flutter.last_lat'), isFalse);
      expect(prefs.containsKey('flutter.last_lng'), isFalse);
      expect(prefs.containsKey('flutter.azan_100_time'), isFalse);
      expect(prefs.containsKey('flutter.azan_100_prayer'), isFalse);
      expect(prefs.containsKey('flutter.azan_100_sound'), isFalse);
    });

    test('لا يطمس قيمة صحيحة موجودة أصلاً، لكنه يحذف القديمة', () async {
      SharedPreferences.setMockInitialValues({
        correctStored('last_sound_file_scheduled'): 'azan_nasser_alqatami',
        legacyStored('last_sound_file_scheduled'): 'azan_abdelbaset',
      });

      await PrefsMigration.run();
      final prefs = await SharedPreferences.getInstance();

      expect(
        prefs.getString(PrefKeys.lastSoundFileScheduled),
        'azan_nasser_alqatami',
      );
      expect(prefs.containsKey('flutter.last_sound_file_scheduled'), isFalse);
    });

    test('pending_navigation القديم يُحذف ولا تُنسخ قيمته العابرة', () async {
      SharedPreferences.setMockInitialValues({
        legacyStored('pending_navigation'): 'open_prayer_times',
      });

      await PrefsMigration.run();
      final prefs = await SharedPreferences.getInstance();

      // حُذف المفتاح القديم
      expect(prefs.containsKey('flutter.pending_navigation'), isFalse);
      // ولم تُنسخ قيمته — حتى لا تُفتح شاشة عشوائية بعد التحديث
      expect(prefs.getString(PrefKeys.pendingNavigation), isNull);
    });

    test('يحافظ على الأنواع غير النصّية', () async {
      SharedPreferences.setMockInitialValues({
        legacyStored('some_int'): 42,
        legacyStored('some_bool'): true,
        legacyStored('some_double'): 1.5,
        legacyStored('some_list'): <String>['a', 'b'],
      });

      await PrefsMigration.run();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt('some_int'), 42);
      expect(prefs.getBool('some_bool'), isTrue);
      expect(prefs.getDouble('some_double'), 1.5);
      expect(prefs.getStringList('some_list'), ['a', 'b']);
    });

    test('يعمل مرة واحدة فقط — لا يُعيد الترحيل بعد أول تشغيل', () async {
      SharedPreferences.setMockInitialValues({
        legacyStored('last_lat'): '30.0',
      });

      await PrefsMigration.run();
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PrefKeys.migrationV1Done), isTrue);

      // قيمة جديدة كُتبت بعد الترحيل بالاسم الصحيح
      await prefs.setString(PrefKeys.lastLat, '31.5');
      // ومفتاح قديم ظهر مجدداً (محاكاة نسخة قديمة مُثبَّتة فوقها)
      await prefs.setString('flutter.last_lat', '99.9');

      await PrefsMigration.run(); // يجب أن تكون no-op

      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefKeys.lastLat), '31.5');
      expect(prefs.getString('flutter.last_lat'), '99.9');
    });

    test('لا يمسّ قيمة pending_navigation التي كتبها الناتيف', () async {
      // الناتيف كتب المفتاح الخام الصحيح، وبجواره بقايا قديمة
      SharedPreferences.setMockInitialValues({
        correctStored('pending_navigation'): 'open_qibla',
        legacyStored('pending_navigation'): 'open_athkar',
      });

      await PrefsMigration.run();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString(PrefKeys.pendingNavigation), 'open_qibla');
      expect(prefs.containsKey('flutter.pending_navigation'), isFalse);
    });

    test('آمن على خزنة فارغة', () async {
      await PrefsMigration.run();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PrefKeys.migrationV1Done), isTrue);
    });

    test('findRemainingLegacyKeys فارغة بعد الترحيل', () async {
      SharedPreferences.setMockInitialValues({
        legacyStored('last_lat'): '30.0',
        legacyStored('azan_101_time'): '1789000000001',
        legacyStored('pending_navigation'): 'open_qibla', // مستثنى
      });

      await PrefsMigration.run();

      expect(await PrefsMigration.findRemainingLegacyKeys(), isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  عقد التسليم: Kotlin يكتب → Dart يقرأ
  // ══════════════════════════════════════════════════════════════
  group('pending_navigation — Kotlin ← → Dart', () {
    test(
      'قيمة كتبها الناتيف بـ "flutter.pending_navigation" يقرأها Dart',
      () async {
        // محاكاة MainActivity.kt:151 / ReminderAlarmReceiver.kt:100
        //   prefs.edit().putString("flutter.pending_navigation", ...)
        // على الخزنة الخام — أي مفتاح مخزَّن اسمه flutter.pending_navigation
        SharedPreferences.setMockInitialValues({
          'flutter.pending_navigation': 'open_prayer_times',
        });

        final prefs = await SharedPreferences.getInstance();

        // ✅ بعد الإصلاح: Dart يقرأه بنجاح
        expect(
          prefs.getString(PrefKeys.pendingNavigation),
          'open_prayer_times',
          reason: 'كتابة الناتيف يجب أن تصل إلى Dart',
        );
      },
    );

    test('المفتاح القديم المزدوج لم يكن يرى كتابة الناتيف (انحدار)', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.pending_navigation': 'open_prayer_times',
      });

      final prefs = await SharedPreferences.getInstance();

      // السلوك القديم: getString('flutter.pending_navigation')
      // → يبحث عن flutter.flutter.pending_navigation → null
      expect(
        prefs.getString('flutter.pending_navigation'),
        isNull,
        reason: 'هذا هو الخطأ الذي أُصلح — يجب أن يبقى null',
      );
    });

    test('ما يكتبه Dart يصل إلى المفتاح الخام الذي يقرأه الناتيف', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(PrefKeys.pendingNavigation, 'open_tasbih');

      // يظهر من فضاء Dart باسمه بلا بادئة
      expect(prefs.getString('pending_navigation'), 'open_tasbih');
      // ولا يظهر تحت الاسم المزدوج القديم
      expect(prefs.getString('flutter.pending_navigation'), isNull);
    });
  });
}
