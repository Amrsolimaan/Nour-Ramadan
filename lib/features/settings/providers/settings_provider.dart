import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_permission_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/prefs_keys.dart';

// ════════════════════════════════════════════════════════════════
//  Sheikh — بيانات القارئ
// ════════════════════════════════════════════════════════════════

class Sheikh {
  const Sheikh({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.folder,
    required this.style,
  });

  final String id;
  final String name;    // الاسم بالعربي
  final String nameEn;  // للـ URL
  final String folder;  // مجلد everyayah.com
  final String style;   // مجوّد / مرتّل

  // للاستخدام مع AudioCacheService
  String get reciterCode => folder;

  String audioUrl(int surah, int ayah) {
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$s$a.mp3';
  }
}

// ── قائمة المشايخ المتاحين ──────────────────────────────────────
// تم التحقق من المجلدات على everyayah.com
const kSheikhs = <Sheikh>[
  Sheikh(
    id:     'alafasy',
    name:   'مشاري راشد العفاسي',
    nameEn: 'Mishary Alafasy',
    folder: 'Alafasy_128kbps',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'husary',
    name:   'محمود خليل الحصري',
    nameEn: 'Mahmoud Khalil Al-Husary',
    folder: 'Husary_128kbps',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'basit',
    name:   'عبد الباسط عبد الصمد',
    nameEn: 'Abdul Basit',
    folder: 'Abdul_Basit_Murattal_192kbps',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'basit_mujawwad',
    name:   'عبد الباسط عبد الصمد (مجود)',
    nameEn: 'Abdul Basit (Mujawwad)',
    folder: 'Abdul_Basit_Mujawwad_128kbps',
    style:  'مجوّد',
  ),
  Sheikh(
    id:     'fares_abbad',
    name:   'فارس عباد',
    nameEn: 'Fares Abbad',
    folder: 'Fares_Abbad_64kbps',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'ghamdi',
    name:   'سعد الغامدي',
    nameEn: 'Saad Al-Ghamdi',
    folder: 'Ghamadi_40kbps',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'muaiqly',
    name:   'ماهر المعيقلي',
    nameEn: 'Maher Al-Muaiqly',
    folder: 'MaherAlMuaiqly128kbps',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'sudais',
    name:   'عبد الرحمن السديس',
    nameEn: 'Abdul Rahman Al-Sudais',
    folder: 'Abdurrahmaan_As-Sudais_192kbps',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'minshawi',
    name:   'محمد صدّيق المنشاوي',
    nameEn: 'Mohamed Siddiq Al-Minshawi',
    folder: 'Minshawy_Murattal_128kbps',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'ajamy',
    name:   'أحمد بن علي العجمي',
    nameEn: 'Ahmed Al-Ajamy',
    folder: 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'shuraym',
    name:   'سعود الشريم',
    nameEn: 'Saud Al-Shuraim',
    folder: 'Saood_ash-Shuraym_128kbps',
    style:  'مرتّل',
  ),
  Sheikh(
    id:     'dosari',
    name:   'ياسر الدوسري',
    nameEn: 'Yasser Al-Dosari',
    folder: 'Yasser_Ad-Dussary_128kbps',
    style:  'مرتّل',
  ),
];

// ════════════════════════════════════════════════════════════════
//  SettingsState
// ════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════
//  Muezzin — بيانات المؤذن
// ════════════════════════════════════════════════════════════════

class Muezzin {
  const Muezzin({
    required this.id,
    required this.name,
    required this.fileName,
  });

  final String id;
  final String name;     // الاسم بالعربي
  final String fileName; // اسم ملف الصوت

  String get audioPath => 'assets/audio/$fileName';
}

// ── قائمة المؤذنين المتاحين ──────────────────────────────────────
const kMuezzins = <Muezzin>[
  Muezzin(
    id:       'abdelbaset',
    name:     'عبد الباسط عبد الصمد',
    fileName: 'azan_abdelbaset.mp3',
  ),
  Muezzin(
    id:       'mohamed_jazi',
    name:     'محمد الجازي',
    fileName: 'azan_mohamed_jazi.mp3',
  ),
  Muezzin(
    id:       'nasser_alqatami',
    name:     'ناصر القطامي',
    fileName: 'azan_nasser_alqatami.mp3',
  ),
];

class SettingsState {
  const SettingsState({
    this.sheikId = 'alafasy',
    this.muezzinId = 'abdelbaset',
    this.quranFontSize = 22.0,
    this.ayahDelay = 500,       // ms بين الآيات
    this.showTajweedColors = false,
    this.prayerReminderEnabled = true,
    this.suhoorReminderEnabled = false,
    this.iftarReminderEnabled = false,
  });

  final String sheikId;
  final String muezzinId;
  final double quranFontSize;
  final int    ayahDelay;         // مدة الوقف بين آيتين
  final bool   showTajweedColors;
  final bool   prayerReminderEnabled;  // تذكير قبل الصلاة 15 دقيقة
  final bool   suhoorReminderEnabled;  // تنبيه السحور
  final bool   iftarReminderEnabled;   // تنبيه الإفطار

  Sheikh get sheikh =>
      kSheikhs.firstWhere((s) => s.id == sheikId, orElse: () => kSheikhs.first);

  Muezzin get muezzin =>
      kMuezzins.firstWhere((m) => m.id == muezzinId, orElse: () => kMuezzins.first);

  SettingsState copyWith({
    String? sheikId,
    String? muezzinId,
    double? quranFontSize,
    int?    ayahDelay,
    bool?   showTajweedColors,
    bool?   prayerReminderEnabled,
    bool?   suhoorReminderEnabled,
    bool?   iftarReminderEnabled,
  }) => SettingsState(
    sheikId:               sheikId               ?? this.sheikId,
    muezzinId:             muezzinId             ?? this.muezzinId,
    quranFontSize:         quranFontSize         ?? this.quranFontSize,
    ayahDelay:             ayahDelay             ?? this.ayahDelay,
    showTajweedColors:     showTajweedColors     ?? this.showTajweedColors,
    prayerReminderEnabled: prayerReminderEnabled ?? this.prayerReminderEnabled,
    suhoorReminderEnabled: suhoorReminderEnabled ?? this.suhoorReminderEnabled,
    iftarReminderEnabled:  iftarReminderEnabled  ?? this.iftarReminderEnabled,
  );
}

// ════════════════════════════════════════════════════════════════
//  SettingsNotifier
// ════════════════════════════════════════════════════════════════

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  static const _kSheikh          = 'settings_sheikh';
  static const _kMuezzin         = 'settings_muezzin';
  static const _kFontSize        = 'settings_font_size';
  static const _kDelay           = 'settings_ayah_delay';
  static const _kPrayerReminder  = 'settings_prayer_reminder';
  static const _kSuhoorReminder  = 'settings_suhoor_reminder';
  static const _kIftarReminder   = 'settings_iftar_reminder';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // ✅ FIX: حفظ القيم الافتراضية إذا لم تكن موجودة
    final sheikId = prefs.getString(_kSheikh) ?? 'alafasy';
    final muezzinId = prefs.getString(_kMuezzin) ?? 'abdelbaset';
    
    // حفظ القيم الافتراضية إذا لم تكن محفوظة من قبل
    if (!prefs.containsKey(_kSheikh)) {
      await prefs.setString(_kSheikh, sheikId);
    }
    if (!prefs.containsKey(_kMuezzin)) {
      await prefs.setString(_kMuezzin, muezzinId);
    }
    
    state = state.copyWith(
      sheikId:               sheikId,
      muezzinId:             muezzinId,
      quranFontSize:         prefs.getDouble(_kFontSize)     ?? 22.0,
      ayahDelay:             prefs.getInt(_kDelay)           ?? 500,
      // ✅ FIX: تذكير الصلاة مفعل افتراضياً (حتى بدون أذونات)
      // سيتم التحقق من الأذونات عند الجدولة الفعلية
      prayerReminderEnabled: prefs.getBool(_kPrayerReminder) ?? true,
      suhoorReminderEnabled: prefs.getBool(_kSuhoorReminder) ?? false,
      iftarReminderEnabled:  prefs.getBool(_kIftarReminder)  ?? false,
    );
  }

  Future<void> setSheikh(String id) async {
    state = state.copyWith(sheikId: id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSheikh, id);
  }

  Future<void> setMuezzin(String id) async {
    state = state.copyWith(muezzinId: id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMuezzin, id);
    
    // ✅ FIX: تحديث صوت الأذان لكل الأذانات المجدولة
    final muezzin = kMuezzins.firstWhere((m) => m.id == id, orElse: () => kMuezzins.first);
    final soundFileName = muezzin.fileName
        .replaceAll('.mp3', '')
        .toLowerCase()
        .replaceAll('-', '_');
    
    // تحديث كل IDs الأذانات المجدولة (اليوم 0 + 7 أيام + فجر الغد)
    // ✅ FIX: قائمة كاملة تشمل كل IDs بما فيها الشروق (105, 215, 225...)
    // السبب: كانت تفتقد ID 105 (شروق اليوم 0) + شروق كل يوم (x5)
    // الشروق لا يُشغّل صوت مؤذن لكن نُحدّث قيمته لاتساق البيانات
    final azanIds = <int>[
      100, 101, 102, 103, 104, 105, 150, // اليوم 0 كامل + فجر الغد
      210, 211, 212, 213, 214, 215, // اليوم 1 كامل
      220, 221, 222, 223, 224, 225, // اليوم 2 كامل
      230, 231, 232, 233, 234, 235, // اليوم 3 كامل
      240, 241, 242, 243, 244, 245, // اليوم 4 كامل
      250, 251, 252, 253, 254, 255, // اليوم 5 كامل
      260, 261, 262, 263, 264, 265, // اليوم 6 كامل
    ];
    
    for (final azanId in azanIds) {
      await prefs.setString(PrefKeys.azanSound(azanId), soundFileName);
    }
    await prefs.setString(PrefKeys.lastSoundFileScheduled, soundFileName);
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(quranFontSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, size);
  }

  Future<void> setAyahDelay(int ms) async {
    state = state.copyWith(ayahDelay: ms);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDelay, ms);
  }

  Future<void> setPrayerReminder(bool enabled) async {
    // ✅ التحقق من الأذونات والموقع أولاً
    if (enabled && (!await NotificationPermissionService.hasPermission() || !LocationService.instance.hasLocation)) {
      return; // لا نفعّل إذا لم يكن هناك أذونات أو موقع
    }

    state = state.copyWith(prayerReminderEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrayerReminder, enabled);

    // ✅ FIX: إلغاء كل التذكيرات من AlarmManager عند التعطيل
    // السبب: AlarmManager يستمر في إيقاظ الجهاز رغم إيقاف الإعداد
    // ReminderAlarmReceiver يتجاهل الإشعار لكن الإيقاظ يستنزف البطارية
    if (!enabled) {
      await _cancelAllReminders();
    }
  }

  /// إلغاء كل التذكيرات المجدولة من AlarmManager عبر MethodChannel
  Future<void> _cancelAllReminders() async {
    try {
      final reminderIds = <int>[
        // reminder IDs = 8000 + alarm ID (نفس المعادلة في Kotlin)
        8100, 8101, 8102, 8103, 8104, 8105, 8150, // اليوم 0
        8210, 8211, 8212, 8213, 8214, 8215, // اليوم 1
        8220, 8221, 8222, 8223, 8224, 8225, // اليوم 2
        8230, 8231, 8232, 8233, 8234, 8235, // اليوم 3
        8240, 8241, 8242, 8243, 8244, 8245, // اليوم 4
        8250, 8251, 8252, 8253, 8254, 8255, // اليوم 5
        8260, 8261, 8262, 8263, 8264, 8265, // اليوم 6
      ];
      const channel = MethodChannel('com.nour_ramadan/azan_service');
      for (final id in reminderIds) {
        try {
          await channel.invokeMethod('cancelAlarm', {'id': id});
        } catch (_) {
          // تجاهل أخطاء IDs غير الموجودة
        }
      }
      debugPrint('✅ All reminders cancelled from AlarmManager');
    } catch (e) {
      debugPrint('❌ _cancelAllReminders error: $e');
    }
  }

  Future<void> setSuhoorReminder(bool enabled) async {
    // ✅ التحقق من الأذونات والموقع أولاً
    if (enabled && (!await NotificationPermissionService.hasPermission() || !LocationService.instance.hasLocation)) {
      return; // لا نفعّل إذا لم يكن هناك أذونات أو موقع
    }
    
    state = state.copyWith(suhoorReminderEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSuhoorReminder, enabled);
  }

  Future<void> setIftarReminder(bool enabled) async {
    // ✅ التحقق من الأذونات والموقع أولاً
    if (enabled && (!await NotificationPermissionService.hasPermission() || !LocationService.instance.hasLocation)) {
      return; // لا نفعّل إذا لم يكن هناك أذونات أو موقع
    }
    
    state = state.copyWith(iftarReminderEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIftarReminder, enabled);
  }

  // ══════════════════════════════════════════════════════════════
  //  إعادة تحميل الإعدادات (بعد تفعيل الأذونات)
  // ══════════════════════════════════════════════════════════════
  Future<void> reload() async {
    await _load();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);