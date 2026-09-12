import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';

// ════════════════════════════════════════════════════════════════
//  LocationPickerScreen — شاشة اختيار المدينة
//  محسّنة: تستخدم geocoding للحصول على الموقع الدقيق
// ════════════════════════════════════════════════════════════════

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.onCitySelected});

  /// ينتقل بعد اختيار المدينة
  final void Function(String city, double lat, double lng)? onCitySelected;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _detecting = false;
  String? _detectedCity;
  double? _detectedLat;
  double? _detectedLng;
  String? _errorMessage;

  // ── كشف الموقع التلقائي بدقة عالية ────────────────────────────
  Future<void> _detectLocation() async {
    setState(() {
      _detecting = true;
      _errorMessage = null;
    });

    try {
      // 1. فحص تفعيل GPS
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _detecting = false;
          _errorMessage = 'يرجى تفعيل GPS من الإعدادات';
        });
        _showError('يرجى تفعيل GPS من الإعدادات', showSettings: true);
        return;
      }

      // 2. فحص الصلاحيات
      var status = await Permission.locationWhenInUse.status;

      if (status.isPermanentlyDenied) {
        setState(() {
          _detecting = false;
          _errorMessage = 'تم رفض صلاحية الموقع بشكل دائم';
        });
        _showGoToSettings();
        return;
      }

      if (status.isDenied) {
        status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          setState(() {
            _detecting = false;
            _errorMessage = 'تم رفض صلاحية الموقع';
          });
          _showError('تم رفض صلاحية الموقع');
          return;
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
        final cityName =
            place.locality ??
            place.administrativeArea ??
            place.subAdministrativeArea ??
            'موقع غير معروف';

        setState(() {
          _detectedCity = cityName;
          _detectedLat = position.latitude;
          _detectedLng = position.longitude;
          _detecting = false;
          _errorMessage = null;
        });

        // حفظ الموقع
        await LocationService.instance.setManualLocation(
          lat: position.latitude,
          lng: position.longitude,
          city: cityName,
        );

        _showSuccess('تم تحديد موقعك: $cityName');
      } else {
        setState(() {
          _detecting = false;
          _errorMessage = 'تعذر تحديد اسم المدينة';
        });
        _showError('تعذر تحديد اسم المدينة');
      }
    } catch (e) {
      setState(() {
        _detecting = false;
        _errorMessage = 'خطأ: ${e.toString()}';
      });
      _showError('تعذر تحديد موقعك، حاول مجدداً');
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8.w),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String msg, {bool showSettings = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8.w),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ── قائمة المدن الشاملة مع إحداثياتها ─────────────────────────
  static const _cities = <_CityEntry>[
    // مصر
    _CityEntry('القاهرة', 30.0444, 31.2357),
    _CityEntry('الإسكندرية', 31.2001, 29.9187),
    _CityEntry('الجيزة', 30.0086, 31.2111),
    _CityEntry('المنصورة', 31.0409, 31.3824),
    _CityEntry('طنطا', 30.7865, 31.0004),
    _CityEntry('أسيوط', 27.1809, 31.1837),
    _CityEntry('بورسعيد', 31.2565, 32.2841),
    _CityEntry('السويس', 29.9668, 32.5498),
    _CityEntry('الزقازيق', 30.5877, 31.5022),
    _CityEntry('الإسماعيلية', 30.5965, 32.2715),
    _CityEntry('الفيوم', 29.3084, 30.8428),
    _CityEntry('أسوان', 24.0889, 32.8998),
    _CityEntry('الأقصر', 25.6872, 32.6396),
    _CityEntry('المنيا', 28.0871, 30.7618),
    _CityEntry('بني سويف', 29.0661, 31.0994),
    _CityEntry('سوهاج', 26.5590, 31.6957),
    _CityEntry('قنا', 26.1551, 32.7160),
    _CityEntry('شرم الشيخ', 27.9158, 34.3300),
    _CityEntry('الغردقة', 27.2579, 33.8116),
    _CityEntry('مرسى مطروح', 31.3543, 27.2373),
    _CityEntry('دمياط', 31.4165, 31.8133),
    _CityEntry('كفر الشيخ', 31.1107, 30.9388),
    _CityEntry('المحلة الكبرى', 30.9716, 31.1612),
    _CityEntry('شبين الكوم', 30.5608, 30.9756),
    _CityEntry('بنها', 30.4678, 31.1852),
    _CityEntry('الإبراهيمية', 30.6547, 31.5432),
    // دول عربية
    _CityEntry('مكة المكرمة', 21.3891, 39.8579),
    _CityEntry('المدينة المنورة', 24.5247, 39.5692),
    _CityEntry('الرياض', 24.7136, 46.6753),
    _CityEntry('جدة', 21.5433, 39.1728),
    _CityEntry('دبي', 25.2048, 55.2708),
    _CityEntry('أبوظبي', 24.4539, 54.3773),
    _CityEntry('الكويت', 29.3759, 47.9774),
    _CityEntry('بغداد', 33.3152, 44.3661),
    _CityEntry('عمّان', 31.9539, 35.9106),
    _CityEntry('بيروت', 33.8938, 35.5018),
    _CityEntry('دمشق', 33.5102, 36.2913),
    _CityEntry('الخرطوم', 15.5007, 32.5599),
    _CityEntry('تونس', 36.8190, 10.1658),
    _CityEntry('الجزائر', 36.7538, 3.0588),
    _CityEntry('الرباط', 34.0209, -6.8416),
    _CityEntry('الدار البيضاء', 33.5731, -7.5898),
    _CityEntry('طرابلس', 32.8872, 13.1913),
    _CityEntry('أديس أبابا', 8.9806, 38.7578),
    _CityEntry('نواكشوط', 18.0735, -15.9582),
  ];

  List<_CityEntry> get _filtered {
    if (_query.isEmpty) return _cities;
    return _cities.where((c) => c.name.contains(_query)).toList();
  }

  @override
  void initState() {
    super.initState();
    // تحميل الموقع المحفوظ عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedCity = LocationService.instance.city;
      if (savedCity.isNotEmpty && savedCity != 'القاهرة') {
        setState(() => _detectedCity = savedCity);
      }
    });
  }

  void _showGoToSettings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.nightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800)),
            SizedBox(width: 8.w),
            const Text(
              'الوصول محظور',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'يمكنك السماح بالوصول للموقع من إعدادات التطبيق.',
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppColors.textDim),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'الإعدادات',
              style: TextStyle(color: AppColors.goldLight),
            ),
          ),
        ],
      ),
    );
  }

  void _selectCity(_CityEntry city) async {
    await LocationService.instance.setManualLocation(
      lat: city.lat,
      lng: city.lng,
      city: city.name,
    );
    if (!mounted) return;
    widget.onCitySelected?.call(city.name, city.lat, city.lng);
    Navigator.of(context).pop(city.name);
  }

  void _selectDetectedLocation() async {
    if (_detectedCity != null && _detectedLat != null && _detectedLng != null) {
      await LocationService.instance.setManualLocation(
        lat: _detectedLat!,
        lng: _detectedLng!,
        city: _detectedCity!,
      );
      if (!mounted) return;
      widget.onCitySelected?.call(_detectedCity!, _detectedLat!, _detectedLng!);
      Navigator.of(context).pop(_detectedCity);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ─ AppBar مخصص ─────────────────────────────────────────
            _buildHeader(),

            // ─ بحث ────────────────────────────────────────────────
            _buildSearchBar(),

            // ─ الموقع الحالي ───────────────────────────────────────
            _buildCurrentLocation(),

            // ─ فاصل ───────────────────────────────────────────────
            Container(
              height: 1,
              color: AppColors.borderGold,
              margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            ),

            // ─ قائمة المدن ─────────────────────────────────────────
            Expanded(child: _buildCityList()),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.nightMid,
        border: Border(
          bottom: BorderSide(color: AppColors.borderGold, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderGold),
                color: AppColors.goldWarm.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Text(
                  '✕',
                  style: TextStyle(color: AppColors.goldLight, fontSize: 14.sp),
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'اختر مدينة',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // زر "دولة" — placeholder مستقبلي
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderGold),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🌍', style: TextStyle(fontSize: 12.sp)),
                SizedBox(width: 4.w),
                Text(
                  'دولة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.sp,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── شريط البحث ─────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Container(
        height: 44.h,
        decoration: BoxDecoration(
          color: AppColors.nightCard,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.borderGold, width: 1.0),
        ),
        child: TextField(
          controller: _searchController,
          textDirection: TextDirection.rtl,
          onChanged: (v) => setState(() => _query = v.trim()),
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13.sp,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث عن المدينة',
            hintStyle: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13.sp,
              color: AppColors.textDim,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppColors.textDim,
              size: 18.sp,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
          ),
        ),
      ),
    );
  }

  // ── قسم الموقع الحالي ──────────────────────────────────────────
  Widget _buildCurrentLocation() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              'الموقع الحالي',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.sp,
                color: AppColors.textDim,
              ),
            ),
          ),
          SizedBox(height: 8.h),

          // رسالة خطأ إن وجدت
          if (_errorMessage != null) ...[
            Container(
              padding: EdgeInsets.all(10.w),
              margin: EdgeInsets.only(bottom: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFD32F2F),
                    size: 18,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11.sp,
                        color: const Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // زر إعادة التحديد
              GestureDetector(
                onTap: _detecting ? null : _detectLocation,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldWarm.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.4),
                    ),
                  ),
                  child: _detecting
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14.r,
                              height: 14.r,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.goldWarm,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'جاري التحديد...',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11.sp,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location,
                              color: AppColors.goldLight,
                              size: 14.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'تحديد موقعي',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11.sp,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // المدينة المحددة
              GestureDetector(
                onTap: _detectedCity != null ? _selectDetectedLocation : null,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: _detectedCity != null
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                        : AppColors.goldWarm.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: _detectedCity != null
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
                          : AppColors.borderGoldStrong,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: _detectedCity != null
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF34A862),
                        size: 14.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _detectedCity ?? LocationService.instance.city,
                        style: TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 12.sp,
                          color: _detectedCity != null
                              ? const Color(0xFF2E7D32)
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_detectedLat != null && _detectedLng != null) ...[
                        SizedBox(width: 4.w),
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF2E7D32),
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // عرض الإحداثيات إذا تم التحديد
          if (_detectedLat != null && _detectedLng != null) ...[
            SizedBox(height: 6.h),
            Text(
              'الإحداثيات: ${_detectedLat!.toStringAsFixed(4)}, ${_detectedLng!.toStringAsFixed(4)}',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 9.sp,
                color: AppColors.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── قائمة المدن ─────────────────────────────────────────────────
  Widget _buildCityList() {
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13.sp,
            color: AppColors.textDim,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 40.h),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final city = list[i];
        final isCurrent = city.name == LocationService.instance.city;
        return _CityTile(
          city: city,
          isCurrent: isCurrent,
          onTap: () => _selectCity(city),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _CityTile — عنصر مدينة في القائمة
// ════════════════════════════════════════════════════════════════
class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.city,
    required this.isCurrent,
    required this.onTap,
  });
  final _CityEntry city;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.goldWarm.withValues(alpha: 0.10),
      highlightColor: AppColors.goldWarm.withValues(alpha: 0.05),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.borderGold.withValues(alpha: 0.30),
              width: 0.5,
            ),
          ),
          color: isCurrent
              ? AppColors.goldWarm.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isCurrent) ...[
              Icon(Icons.check_circle, color: AppColors.goldLight, size: 14.sp),
              SizedBox(width: 8.w),
            ],
            Text(
              city.name,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 14.sp,
                color: isCurrent ? AppColors.goldLight : AppColors.textPrimary,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _CityEntry — بيانات المدينة
// ════════════════════════════════════════════════════════════════
class _CityEntry {
  const _CityEntry(this.name, this.lat, this.lng);
  final String name;
  final double lat;
  final double lng;
}
