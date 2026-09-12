import 'dart:async';
import 'package:adhan/adhan.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_keys.dart';

// ════════════════════════════════════════════════════════════════
//  LocationService — خدمة الموقع وأوقات الصلاة
//
//  السياسة (Google Play):
//  • نطلب الصلاحية فقط عند تفاعل المستخدم (ليس تلقائياً)
//  • نستخدم LocationPermission.whileInUse (ليس always)
//  • نحترم denied / permanentlyDenied بدون إعادة طلب متكررة
//  • نحفظ آخر موقع ونستخدمه offline
// ════════════════════════════════════════════════════════════════

class LocationService {
  LocationService._();
  static final instance = LocationService._();

  static const _latKey = 'location_lat';
  static const _lngKey = 'location_lng';
  static const _cityKey = 'location_city';

  // ✅ المفاتيح التي تقرأها طبقة Kotlin (AlarmScheduler / AzanWorker)
  //
  // ⚠️ بدون بادئة 'flutter.' يدوية — حزمة shared_preferences تُضيفها
  // تلقائياً، فتُصبح القيمة المخزَّنة على Android هي flutter.last_lat
  // وهو بالضبط ما يقرأه الناتيف. كتابة البادئة يدوياً كانت تُنتج
  // flutter.flutter.last_lat ولا يجدها الناتيف أبداً.
  // راجع plan_azan_reliability.md §1.8 و prefs_keys.dart
  static final _nativeLatKey = PrefKeys.lastLat;
  static final _nativeLngKey = PrefKeys.lastLng;

  // ── آخر موقع محفوظ (null حتى يُقرأ) ──────────────────────────
  double? _lat;
  double? _lng;
  String _city = '';

  String get city => _city;
  double? get lat => _lat;
  double? get lng => _lng;

  // ✅ التحقق من وجود موقع محدد
  bool get hasLocation => _lat != null && _lng != null;

  // ════════════════════════════════════════════════════════════════
  //  تحميل آخر موقع محفوظ (يُنادى عند بدء التطبيق)
  // ════════════════════════════════════════════════════════════════
  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _lat = prefs.getDouble(_latKey);
    _lng = prefs.getDouble(_lngKey);
    _city = prefs.getString(_cityKey) ?? '';

    // ✅ لا نضع قيمة افتراضية - يجب على المستخدم تحديد موقعه
    if (_lat != null && _lng != null) {
      debugPrint('✅ Location loaded: $_city ($_lat, $_lng)');
    } else {
      debugPrint('⚠️ No location set yet');
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  طلب الموقع الحالي من GPS — يُنادى فقط عند ضغط المستخدم صراحةً
  //  يُعيد: null إذا رُفضت الصلاحية أو حدث خطأ
  // ════════════════════════════════════════════════════════════════
  Future<LocationResult> detectCurrentLocation() async {
    debugPrint('🔵 [LocationService] بدء detectCurrentLocation...');

    // 1) فحص ما إذا كان GPS مفعّلاً
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('🔵 [LocationService] GPS Service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      debugPrint('❌ [LocationService] GPS غير مفعّل');
      return LocationResult.serviceDisabled;
    }

    // 2) فحص حالة الصلاحية الحالية
    var status = await Permission.locationWhenInUse.status;
    debugPrint('🔵 [LocationService] Permission status: $status');

    if (status.isPermanentlyDenied) {
      debugPrint('❌ [LocationService] Permission permanently denied');
      return LocationResult.permanentlyDenied;
    }

    if (status.isDenied) {
      debugPrint('🔵 [LocationService] Requesting permission...');
      status = await Permission.locationWhenInUse.request();
      debugPrint('🔵 [LocationService] Permission after request: $status');
      if (!status.isGranted) {
        debugPrint('❌ [LocationService] Permission denied by user');
        return LocationResult.denied;
      }
    }

    // 3) جلب الإحداثيات
    try {
      debugPrint('🔵 [LocationService] Getting current position...');
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      debugPrint(
        '✅ [LocationService] Position: ${pos.latitude}, ${pos.longitude}',
      );
      _lat = pos.latitude;
      _lng = pos.longitude;

      // 4) بناء اسم المدينة — نفس منطق زر GPS في home_screen
      try {
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          _city =
              [
                    place.locality,
                    place.subAdministrativeArea,
                    place.administrativeArea,
                  ]
                  .map((s) => s?.trim() ?? '')
                  .firstWhere((s) => s.isNotEmpty, orElse: () => '');
        }
      } catch (e) {
        debugPrint('⚠️ [LocationService] geocoding failed: $e');
        _city = '';
      }
      debugPrint('✅ [LocationService] Address: $_city');

      // 5) حفظ محلياً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, _lat!);
      await prefs.setDouble(_lngKey, _lng!);
      await prefs.setString(_cityKey, _city);
      
      // ✅ حفظ بالمفتاح الذي يقرأه Kotlin (بدون بادئة يدوية)
      // نحفظ كـ String حتى يقرأها Kotlin بـ getString().toDoubleOrNull()
      // سبب التغيير: setInt() يكتب <int> في XML لكن getLong() يقرأ <long>
      // وهما نوعان منفصلان — getLong يُرجع MIN_VALUE دائماً على <int>
      await prefs.setString(_nativeLatKey, _lat!.toString());
      await prefs.setString(_nativeLngKey, _lng!.toString());

      debugPrint('✅ [LocationService] Location saved successfully');
      debugPrint('   📍 Coordinates: $_lat, $_lng');
      debugPrint('   🏙️ City: $_city');
      debugPrint('   💾 Saved to SharedPreferences with keys:');
      debugPrint('      - $_latKey = $_lat');
      debugPrint('      - $_lngKey = $_lng');
      debugPrint('      - $_nativeLatKey = ${_lat.toString()} (String for Kotlin)');
      debugPrint('      - $_nativeLngKey = ${_lng.toString()} (String for Kotlin)');
      
      return LocationResult.success;
    } catch (e) {
      debugPrint('❌ [LocationService] Error getting position: $e');
      return LocationResult.error;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  حفظ موقع يدوي (من صفحة اختيار المدينة)
  // ════════════════════════════════════════════════════════════════
  Future<void> setManualLocation({
    required double lat,
    required double lng,
    required String city,
  }) async {
    _lat = lat;
    _lng = lng;
    _city = city;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, lat);
    await prefs.setDouble(_lngKey, lng);
    await prefs.setString(_cityKey, city);
    
    // ✅ حفظ بالمفتاح الذي يقرأه Kotlin (بدون بادئة يدوية)
    // نحفظ كـ String حتى يقرأها Kotlin بـ getString().toDoubleOrNull()
    await prefs.setString(_nativeLatKey, lat.toString());
    await prefs.setString(_nativeLngKey, lng.toString());
    
    debugPrint('✅ [LocationService] Manual location saved: $city ($lat, $lng)');
  }

  // ════════════════════════════════════════════════════════════════
  //  حساب أوقات الصلاة الحقيقية بـ adhan
  // ════════════════════════════════════════════════════════════════
  PrayerTimes getPrayerTimes() {
    // ✅ التحقق من وجود موقع
    if (!hasLocation) {
      throw Exception('Location not set. Please set location first.');
    }

    final coords = Coordinates(_lat!, _lng!);
    final date = DateComponents.from(DateTime.now());

    // طريقة الحساب المصرية (الهيئة المصرية للمساحة)
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;

    return PrayerTimes(coords, date, params);
  }

  // ── اسم الصلاة التالية + وقتها ────────────────────────────────
  ({String name, DateTime time, double progress}) nextPrayer() {
    // ✅ التحقق من وجود موقع
    if (!hasLocation) {
      // إرجاع قيمة افتراضية للعرض فقط
      return (name: '...', time: DateTime.now(), progress: 0.0);
    }

    final times = getPrayerTimes();
    final now = DateTime.now();

    // قائمة الصلوات الست (مع الشروق)
    final schedule = <(String, DateTime?)>[
      ('الفجر', times.fajr),
      ('الشروق', times.sunrise),  // ✅ Added
      ('الظهر', times.dhuhr),
      ('العصر', times.asr),
      ('المغرب', times.maghrib),
      ('العشاء', times.isha),
    ];

    for (var i = 0; i < schedule.length; i++) {
      final t = schedule[i].$2;
      if (t == null) continue;
      if (now.isBefore(t)) {
        // حساب التقدم بين الصلاة السابقة والحالية
        DateTime? prev;

        if (i > 0) {
          // الصلاة السابقة في نفس اليوم
          prev = schedule[i - 1].$2;
        } else {
          // الفجر: نحسب من العشاء الأمس
          final yesterdayCoords = Coordinates(_lat ?? 30.0444, _lng ?? 31.2357);
          final yesterday = DateComponents.from(
            DateTime.now().subtract(const Duration(days: 1)),
          );
          final yesterdayParams = CalculationMethod.egyptian.getParameters();
          final yesterdayTimes = PrayerTimes(
            yesterdayCoords,
            yesterday,
            yesterdayParams,
          );
          prev = yesterdayTimes.isha;
        }

        double progress = 0.0;
        if (prev != null) {
          final total = t.difference(prev).inMinutes;
          final elapsed = now.difference(prev).inMinutes;
          progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
        }
        return (name: schedule[i].$1, time: t, progress: progress);
      }
    }

    // بعد العشاء → الفجر الغد
    final tomorrowCoords = Coordinates(_lat ?? 30.0444, _lng ?? 31.2357);
    final tomorrow = DateComponents.from(
      DateTime.now().add(const Duration(days: 1)),
    );
    final tomorrowParams = CalculationMethod.egyptian.getParameters();
    final tomorrowTimes = PrayerTimes(tomorrowCoords, tomorrow, tomorrowParams);
    final fajr = tomorrowTimes.fajr;

    // حساب التقدم بين العشاء والفجر الغد
    double progress = 0.0;
    final ishaTime = times.isha;
    if (ishaTime != null && fajr != null) {
      final total = fajr.difference(ishaTime).inMinutes;
      final elapsed = now.difference(ishaTime).inMinutes;
      progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
    }

    return (name: 'الفجر', time: fajr, progress: progress);
  }

  // ── الوقت المتبقي كنص ("٢ س ١٥ د") ──────────────────────────
  String formatTimeLeft(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return '٠ د';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '$h س $m د';
    return '$m د';
  }
}

// ════════════════════════════════════════════════════════════════
//  نتيجة طلب الموقع
// ════════════════════════════════════════════════════════════════
enum LocationResult {
  success,
  denied,
  permanentlyDenied,
  serviceDisabled,
  error,
}