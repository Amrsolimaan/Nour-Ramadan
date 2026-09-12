import 'dart:async';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/prayer_tracking_service.dart';
import '../../../core/services/notification_permission_service.dart';
import './prayer_tracking_provider.dart';

// ════════════════════════════════════════════════════════════════
//  Data Model
// ════════════════════════════════════════════════════════════════
class PrayerTimeItem {
  final String id;
  final String name;
  final DateTime time;
  final String timeStr;
  final String ampm;
  final bool isNotificationEnabled;
  final bool isChecked;

  PrayerTimeItem({
    required this.id,
    required this.name,
    required this.time,
    required this.timeStr,
    required this.ampm,
    this.isNotificationEnabled = true,
    this.isChecked = false,
  });

  PrayerTimeItem copyWith({bool? isNotificationEnabled, bool? isChecked}) {
    return PrayerTimeItem(
      id: id,
      name: name,
      time: time,
      timeStr: timeStr,
      ampm: ampm,
      isNotificationEnabled:
          isNotificationEnabled ?? this.isNotificationEnabled,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

class PrayerState {
  final bool isLoading;
  final bool hasLocation;
  final DateTime selectedDate;
  final HijriCalendar hijriDate;
  final List<PrayerTimeItem> prayers;
  final PrayerTimeItem? currentPrayer;
  final PrayerTimeItem? nextPrayer;
  final Duration timeUntilNext;
  final DateTime? suhoorTime;
  final DateTime? iftarTime;

  PrayerState({
    this.isLoading = true,
    this.hasLocation = false,
    required this.selectedDate,
    required this.hijriDate,
    required this.prayers,
    this.currentPrayer,
    this.nextPrayer,
    this.timeUntilNext = Duration.zero,
    this.suhoorTime,
    this.iftarTime,
  });

  PrayerState copyWith({
    bool? isLoading,
    bool? hasLocation,
    DateTime? selectedDate,
    HijriCalendar? hijriDate,
    List<PrayerTimeItem>? prayers,
    PrayerTimeItem? currentPrayer,
    PrayerTimeItem? nextPrayer,
    Duration? timeUntilNext,
    DateTime? suhoorTime,
    DateTime? iftarTime,
  }) {
    return PrayerState(
      isLoading: isLoading ?? this.isLoading,
      hasLocation: hasLocation ?? this.hasLocation,
      selectedDate: selectedDate ?? this.selectedDate,
      hijriDate: hijriDate ?? this.hijriDate,
      prayers: prayers ?? this.prayers,
      currentPrayer: currentPrayer ?? this.currentPrayer,
      nextPrayer: nextPrayer ?? this.nextPrayer,
      timeUntilNext: timeUntilNext ?? this.timeUntilNext,
      suhoorTime: suhoorTime ?? this.suhoorTime,
      iftarTime: iftarTime ?? this.iftarTime,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Notifier
// ════════════════════════════════════════════════════════════════
class PrayerNotifier extends StateNotifier<PrayerState> {
  PrayerNotifier(this.ref)
    : super(
        PrayerState(
          selectedDate: DateTime.now(),
          hijriDate: HijriCalendar.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          prayers: [],
        ),
      ) {
    _init();
  }

  final Ref ref;
  late Box _box;
  Timer? _updateTimer; // ✅ Timer للتحديث الدوري

  Future<void> _init() async {
    try {
      if (!Hive.isBoxOpen('prayer_settings')) {
        _box = await Hive.openBox('prayer_settings');
      } else {
        _box = Hive.box('prayer_settings');
      }

      final loc = LocationService.instance;
      
      // ✅ تحميل الموقع المحفوظ أولاً قبل التحقق
      await loc.loadSaved();
      
      // ✅ تحديث hasLocation مباشرة من LocationService
      final locationExists = loc.hasLocation;
      
      // تحقق من وجود الموقع
      if (!locationExists) {
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            hasLocation: false,
          );
        }
        return;
      }

      // ✅ الموقع موجود - نحدث الحالة ونحسب الصلوات
      if (loc.lat != null && loc.lng != null) {
        if (mounted) {
          state = state.copyWith(hasLocation: true);
        }
        // ✅ calculatePrayers تنتهي هنا ثم نوقف isLoading في finally
        await calculatePrayers(loc.lat!, loc.lng!, DateTime.now());
      } else {
        // لا يوجد موقع صالح
        if (mounted) {
          state = state.copyWith(isLoading: false, hasLocation: false);
        }
      }
    } catch (e) {
      debugPrint('Error init prayer provider: $e');
    } finally {
      // ✅ أوقف isLoading بعد انتهاء calculatePrayers (أو عند حدوث خطأ)
      if (mounted && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
      
      // ✅ بدء Timer للتحديث التلقائي كل دقيقة
      _startAutoUpdateTimer();
    }
  }

  /// ✅ Timer يحدّث current/next كل دقيقة بدون إعادة حساب كل الصلوات
  void _startAutoUpdateTimer() {
    _updateTimer?.cancel();
    
    // تحديث فوري أول مرة
    _updateCurrentAndNextPrayer();
    
    // ثم كل دقيقة
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _updateCurrentAndNextPrayer();
      }
    });
    
    debugPrint('✅ Prayer auto-update timer started');
  }

  /// ✅ تحديث current/next بناءً على الوقت الحالي (بدون إعادة حساب)
  void _updateCurrentAndNextPrayer() {
    final now = DateTime.now();
    
    // فقط للتاريخ الحالي
    if (state.selectedDate.year != now.year ||
        state.selectedDate.month != now.month ||
        state.selectedDate.day != now.day) {
      return;
    }
    
    if (state.prayers.isEmpty) return;
    
    PrayerTimeItem? current;
    PrayerTimeItem? next;
    
    // ابحث عن أول صلاة في المستقبل
    for (var i = 0; i < state.prayers.length; i++) {
      if (state.prayers[i].time.isAfter(now)) {
        next = state.prayers[i];
        current = i > 0 ? state.prayers[i - 1] : state.prayers.last;
        break;
      }
    }
    
    // ✅ إذا لم نجد صلاة في المستقبل اليوم، احسب صلاة الفجر للغد
    if (next == null) {
      current = state.prayers.last; // العشاء
      next = _calculateTomorrowFajr();
    }
    
    // تحديث الحالة فقط إذا تغيرت
    if (state.currentPrayer?.id != current?.id || 
        state.nextPrayer?.id != next?.id ||
        state.nextPrayer?.time != next?.time) {
      state = state.copyWith(
        currentPrayer: current,
        nextPrayer: next,
      );
      debugPrint('🔄 Updated: current=${current?.name}, next=${next?.name}');
    }
  }

  /// ✅ حساب صلاة الفجر للغد
  PrayerTimeItem? _calculateTomorrowFajr() {
    try {
      final loc = LocationService.instance;
      if (!loc.hasLocation || loc.lat == null || loc.lng == null) {
        return null;
      }
      
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final coords = Coordinates(loc.lat!, loc.lng!);
      final params = CalculationMethod.egyptian.getParameters();
      params.madhab = Madhab.shafi;
      
      final dateComponents = DateComponents.from(tomorrow);
      final prayerTimes = PrayerTimes(coords, dateComponents, params);
      
      final timeFormat = DateFormat('h:mm');
      final ampmFormat = DateFormat('a');
      
      return PrayerTimeItem(
        id: 'fajr',
        name: 'الفجر',
        time: prayerTimes.fajr,
        timeStr: timeFormat.format(prayerTimes.fajr),
        ampm: ampmFormat.format(prayerTimes.fajr) == 'AM' ? 'ص' : 'م',
        isNotificationEnabled: _box.get('fajr_notif', defaultValue: true) as bool,
        isChecked: false,
      );
    } catch (e) {
      debugPrint('❌ Error calculating tomorrow fajr: $e');
      return null;
    }
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> calculatePrayers(double lat, double lng, DateTime date) async {
    if (lat == 0 || lng == 0) return;

    // تحديث حالة الموقع
    if (mounted) {
      state = state.copyWith(hasLocation: true);
    }

    final coords = Coordinates(lat, lng);
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;

    final dateComponents = DateComponents.from(date);
    final prayerTimes = PrayerTimes(coords, dateComponents, params);
    final sunnahTimes = SunnahTimes(prayerTimes);

    final timeFormat = DateFormat('h:mm');
    final ampmFormat = DateFormat('a');
    final dateKey = DateFormat('yyyy-MM-dd').format(date);

    // ✅ الإصلاح: اقرأ الأذونات مرة واحدة خارج الحلقة
    final hasPermission = await NotificationPermissionService.hasPermission();
    final hasLocation = LocationService.instance.hasLocation;
    final notificationsActive = hasPermission && hasLocation;

    final list = [
      {'id': 'fajr', 'name': 'الفجر', 'time': prayerTimes.fajr},
      {'id': 'shurooq', 'name': 'الشروق', 'time': prayerTimes.sunrise},
      {'id': 'dhuhr', 'name': 'الظهر', 'time': prayerTimes.dhuhr},
      {'id': 'asr', 'name': 'العصر', 'time': prayerTimes.asr},
      {'id': 'maghrib', 'name': 'المغرب', 'time': prayerTimes.maghrib},
      {'id': 'isha', 'name': 'العشاء', 'time': prayerTimes.isha},
    ];

    List<PrayerTimeItem> items = [];

    for (var p in list) {
      final id = p['id'] as String;
      final name = p['name'] as String;
      final time = p['time'] as DateTime;

      // حالة الإشعار
      bool isNotif = notificationsActive
          ? _box.get('${id}_notif', defaultValue: true) as bool
          : false;

      // حالة الصلاة (هل صلّاها)
      bool isChecked = false;
      if (id != 'shurooq') {
        // أولاً: اقرأ من PrayerTrackingService
        isChecked = await PrayerTrackingService.getPrayerStatus(
          name,
          date: date,
        );
        // ثانياً: fallback للـ box القديم
        if (!isChecked) {
          isChecked =
              _box.get('${dateKey}_${id}_checked', defaultValue: false) as bool;
        }
      }

      items.add(
        PrayerTimeItem(
          id: id,
          name: name,
          time: time,
          timeStr: timeFormat.format(time),
          ampm: ampmFormat.format(time) == 'AM' ? 'ص' : 'م',
          isNotificationEnabled: isNotif,
          isChecked: isChecked,
        ),
      );
    }

    // ── التاريخ الهجري (مُصحَّح) ──────────────────────────────
    HijriCalendar.setLocal('ar');
    final correctedDate = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(const Duration(days: 1));
    final hijri = HijriCalendar.fromDate(correctedDate);

    // ── الصلاة الحالية والتالية ────────────────────────────────
    PrayerTimeItem? current;
    PrayerTimeItem? next;

    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      // ✅ ابحث عن أول صلاة في المستقبل (أبسط وأكثر أماناً)
      for (var i = 0; i < items.length; i++) {
        if (items[i].time.isAfter(now)) {
          next = items[i];
          current = i > 0 ? items[i - 1] : items.last;
          break;
        }
      }
      
      // ✅ إذا لم نجد صلاة في المستقبل اليوم، احسب صلاة الفجر للغد
      if (next == null) {
        current = items.last; // العشاء
        next = _calculateTomorrowFajr();
      }
    }

    state = state.copyWith(
      selectedDate: date,
      hijriDate: hijri,
      prayers: items,
      currentPrayer: current,
      nextPrayer: next,
      suhoorTime: sunnahTimes.lastThirdOfTheNight,
      iftarTime: prayerTimes.maghrib,
      // ✅ تأكد من إيقاف isLoading بعد انتهاء الحساب مباشرةً
      isLoading: false,
    );
  }

  Future<void> changeDate(int days) async {
    final newDate = state.selectedDate.add(Duration(days: days));
    final loc = LocationService.instance;
    if (loc.lat != null && loc.lng != null) {
      await calculatePrayers(loc.lat!, loc.lng!, newDate);
      
      // ✅ إعادة تشغيل Timer إذا رجعنا لليوم الحالي
      final now = DateTime.now();
      if (newDate.year == now.year &&
          newDate.month == now.month &&
          newDate.day == now.day) {
        _startAutoUpdateTimer();
      } else {
        // إيقاف Timer للتواريخ الأخرى
        _updateTimer?.cancel();
      }
    }
  }

  void toggleNotification(String id) async {
    final hasPermission = await NotificationPermissionService.hasPermission();
    final hasLocation = LocationService.instance.hasLocation;

    if (!hasPermission || !hasLocation) {
      debugPrint('⚠️ Cannot toggle notification - no permission or location');
      return;
    }

    final prayers = state.prayers.map((p) {
      if (p.id == id) {
        final newVal = !p.isNotificationEnabled;
        _box.put('${id}_notif', newVal);
        return p.copyWith(isNotificationEnabled: newVal);
      }
      return p;
    }).toList();
    state = state.copyWith(prayers: prayers);

    // ✅ FIX: إلغاء الأذان من AlarmManager عند إيقاف إشعار صلاة معينة
    // السبب: كان يُحدّث Hive فقط لكن AlarmManager يستمر في الجدولة
    // المستخدم يرى الإشعار معطلاً في UI لكن الأذان يستمر في الصوت
    final prayer = state.prayers.firstWhere(
      (p) => p.id == id,
      orElse: () => prayers.firstWhere((p) => p.id == id),
    );
    if (!prayer.isNotificationEnabled) {
      await _cancelPrayerAlarm(id);
    }
  }

  /// إلغاء أذان صلاة معينة من AlarmManager
  Future<void> _cancelPrayerAlarm(String prayerId) async {
    // خريطة prayer id → alarm IDs (اليوم الحالي فقط)
    const prayerToAlarmId = {
      'fajr':    100,
      'dhuhr':   101,
      'asr':     102,
      'maghrib': 103,
      'isha':    104,
      'shurooq': 105,
    };
    final alarmId = prayerToAlarmId[prayerId];
    if (alarmId == null) return;

    try {
      const channel = MethodChannel('com.nour_ramadan/azan_service');
      await channel.invokeMethod('cancelAlarm', {'id': alarmId});
      // إلغاء التذكير المرتبط أيضاً (8000 + alarmId)
      await channel.invokeMethod('cancelAlarm', {'id': 8000 + alarmId});
      debugPrint('✅ Cancelled alarm + reminder for $prayerId (id=$alarmId)');
    } catch (e) {
      debugPrint('❌ _cancelPrayerAlarm error: $e');
    }
  }

  void toggleCheck(String id) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(state.selectedDate);

    final prayerNameMap = {
      'fajr': 'الفجر',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
    };

    final prayers = state.prayers.map((p) {
      if (p.id == id) {
        final newVal = !p.isChecked;

        // حفظ في prayer_settings (القديم)
        _box.put('${dateKey}_${id}_checked', newVal);

        // حفظ في PrayerTrackingService
        if (prayerNameMap.containsKey(id)) {
          final prayerName = prayerNameMap[id]!;
          if (newVal) {
            PrayerTrackingService.markPrayerAsPrayed(
              prayerName,
              date: state.selectedDate,
            );
          } else {
            PrayerTrackingService.unmarkPrayer(
              prayerName,
              date: state.selectedDate,
            );
          }

          try {
            ref.read(prayerTrackingProvider.notifier).reload();
          } catch (e) {
            debugPrint('Could not reload prayer tracking: $e');
          }
        }

        return p.copyWith(isChecked: newVal);
      }
      return p;
    }).toList();

    state = state.copyWith(prayers: prayers);
  }
}

final prayerProvider = StateNotifierProvider<PrayerNotifier, PrayerState>((
  ref,
) {
  return PrayerNotifier(ref);
});