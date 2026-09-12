import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'location_service.dart';

// ════════════════════════════════════════════════════════════════
//  LocationDetectorService — خدمة كشف الموقع التلقائي
//  يمكن استخدامها من أي مكان في التطبيق
// ════════════════════════════════════════════════════════════════

class LocationDetectorService {
  LocationDetectorService._();
  static final instance = LocationDetectorService._();

  /// كشف الموقع التلقائي بدقة عالية
  /// يرجع: (cityName, lat, lng) أو null في حالة الفشل
  Future<LocationResult?> detectLocation(BuildContext context) async {
    try {
      // 1. فحص تفعيل GPS
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError(
          context,
          'يرجى تفعيل GPS من الإعدادات',
          showSettings: true,
        );
        return null;
      }

      // 2. فحص الصلاحيات
      var status = await Permission.locationWhenInUse.status;

      if (status.isPermanentlyDenied) {
        _showGoToSettings(context);
        return null;
      }

      if (status.isDenied) {
        status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          _showError(context, 'تم رفض صلاحية الموقع');
          return null;
        }
      }

      // 3. جلب الإحداثيات بدقة عالية
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 4. تحويل الإحداثيات إلى اسم مدينة حقيقي
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // استخدام locality (المدينة) أو administrativeArea (المحافظة)
        final cityName = place.locality ??
            place.administrativeArea ??
            place.subAdministrativeArea ??
            'موقع غير معروف';

        // حفظ الموقع
        await LocationService.instance.setManualLocation(
          lat: position.latitude,
          lng: position.longitude,
          city: cityName,
        );

        _showSuccess(context, 'تم تحديد موقعك: $cityName');

        return LocationResult(
          city: cityName,
          lat: position.latitude,
          lng: position.longitude,
        );
      } else {
        _showError(context, 'تعذر تحديد اسم المدينة');
        return null;
      }
    } catch (e) {
      _showError(context, 'تعذر تحديد موقعك، حاول مجدداً');
      return null;
    }
  }

  void _showSuccess(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(
    BuildContext context,
    String msg, {
    bool showSettings = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
        action: showSettings
            ? SnackBarAction(
                label: 'الإعدادات',
                textColor: Colors.white,
                onPressed: () => Geolocator.openLocationSettings(),
              )
            : null,
      ),
    );
  }

  void _showGoToSettings(BuildContext context) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF221A40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800)),
            SizedBox(width: 8),
            Text(
              'الوصول محظور',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: Color(0xFFF5F5DC),
              ),
            ),
          ],
        ),
        content: const Text(
          'يمكنك السماح بالوصول للموقع من إعدادات التطبيق.',
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: Color(0xFFB8B8A0),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Color(0xFFB8B8A0)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'الإعدادات',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  LocationResult — نتيجة كشف الموقع
// ════════════════════════════════════════════════════════════════
class LocationResult {
  final String city;
  final double lat;
  final double lng;

  LocationResult({
    required this.city,
    required this.lat,
    required this.lng,
  });
}
