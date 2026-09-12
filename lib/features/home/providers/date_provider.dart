import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

// ════════════════════════════════════════════════════════════════
//  DateState — حالة التاريخ فقط
// ════════════════════════════════════════════════════════════════

class DateState {
  const DateState({
    this.hijriDate = '',
    this.gregorianDate = '',
    this.completedDays = 0,
    this.totalDays = 30,
    this.hijriMonth = 1,
    this.hijriYear = 1446,
    this.isLoading = true,
  });

  final String hijriDate;
  final String gregorianDate;
  final int completedDays;
  final int totalDays;
  final int hijriMonth;
  final int hijriYear;
  final bool isLoading;

  DateState copyWith({
    String? hijriDate,
    String? gregorianDate,
    int? completedDays,
    int? totalDays,
    int? hijriMonth,
    int? hijriYear,
    bool? isLoading,
  }) {
    return DateState(
      hijriDate: hijriDate ?? this.hijriDate,
      gregorianDate: gregorianDate ?? this.gregorianDate,
      completedDays: completedDays ?? this.completedDays,
      totalDays: totalDays ?? this.totalDays,
      hijriMonth: hijriMonth ?? this.hijriMonth,
      hijriYear: hijriYear ?? this.hijriYear,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  DateNotifier
// ════════════════════════════════════════════════════════════════
class DateNotifier extends StateNotifier<DateState> {
  DateNotifier() : super(const DateState()) {
    _init();
  }

  Timer? _timer;

  Future<void> _init() async {
    try {
      _loadDates();

      // تحديث التاريخ كل ساعة
      _timer = Timer.periodic(const Duration(hours: 1), (_) => _loadDates());

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('خطأ في تهيئة DateNotifier: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // ── التاريخ ────────────────────────────────────────────────────
  void _loadDates() {
    final now = DateTime.now();

    HijriCalendar.setLocal('ar');
    final correctedDate = now.subtract(const Duration(days: 1));
    final hijri = HijriCalendar.fromDate(correctedDate);

    final weekdays = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final hijriMonths = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الثانية',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    int completedDays = 0;
    int totalDays = 30;

    debugPrint(
      '📅 التاريخ الهجري المحسوب: ${hijri.hDay} ${hijriMonths[hijri.hMonth - 1]} ${hijri.hYear}',
    );
    debugPrint('📅 الشهر الهجري: ${hijri.hMonth} (9 = رمضان)');
    debugPrint('📅 اليوم الهجري: ${hijri.hDay}');

    if (hijri.hMonth == 9) {
      completedDays = hijri.hDay;
      totalDays = 30;
      debugPrint(
        '✅ نحن في رمضان! اليوم: $completedDays/$totalDays (${(completedDays / totalDays * 100).toStringAsFixed(1)}%)',
      );
    } else if (hijri.hMonth > 9) {
      completedDays = 30;
      totalDays = 30;
      debugPrint('✅ رمضان انتهى: $completedDays/$totalDays');
    } else {
      debugPrint(
        '⏳ قبل رمضان (الشهر ${hijri.hMonth}): $completedDays/$totalDays',
      );
    }

    state = state.copyWith(
      hijriDate:
          '${hijri.hDay} ${hijriMonths[hijri.hMonth - 1]} ${hijri.hYear}',
      gregorianDate:
          '${weekdays[now.weekday % 7]}، ${now.day} ${months[now.month - 1]} ${now.year}',
      completedDays: completedDays,
      totalDays: totalDays,
      hijriMonth: hijri.hMonth,
      hijriYear: hijri.hYear,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════
final dateProvider = StateNotifierProvider<DateNotifier, DateState>((ref) {
  return DateNotifier();
});
