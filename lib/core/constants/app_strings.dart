/// كل النصوص العربية للتطبيق في مكان واحد
class AppStrings {
  AppStrings._();

  // ─── اسم التطبيق ───────────────────────────────────────
  static const appName       = 'نور رمضان';
  static const appNameLatin  = 'NOUR RAMADAN';
  static const appTagline    = 'روح الشهر الكريم';
  static const loading       = 'جارٍ التحميل...';

  // ─── شريط التنقل ───────────────────────────────────────
  static const navHome      = 'الرئيسية';
  static const navQuran     = 'القرآن';
  static const navDua       = 'أدعية';
  static const navTasbih    = 'تسبيح';
  static const navProgress  = 'تقدمي';
  static const navQibla     = 'القبلة';
  static const navAthkar    = 'أذكار';

  // ─── الرئيسية ───────────────────────────────────────────
  static const dateCity          = 'القاهرة';
  static const verseOfDay        = 'آية اليوم';
  static const prayerTimes       = 'أوقات الصلاة';
  static const nowBadge          = 'الآن';
  static const nextPrayerIn      = 'العصر بعد';

  // ─── الصلوات ────────────────────────────────────────────
  static const fajr    = 'الفجر';
  static const shorouk = 'الشروق';
  static const dhuhr   = 'الظهر';
  static const asr     = 'العصر';
  static const maghrib = 'المغرب';
  static const isha    = 'العشاء';

  // ─── القسط (Grid) الرئيسية ──────────────────────────────
  static const featQuran       = 'القرآن الكريم';
  static const featQuranDesc   = 'تصفح كامل المصحف';
  static const featDua         = 'الأدعية';
  static const featDuaDesc     = 'مئات الأدعية';
  static const featPrayer      = 'أوقات الصلاة';
  static const featPrayerDesc  = 'تذكير تلقائي';
  static const featQibla       = 'القبلة';
  static const featQiblaDesc   = 'بدقة عالية';
  static const featTasbih      = 'التسبيح';
  static const featTasbihDesc  = 'سبحة تفاعلية';
  static const featLaylat      = 'ليلة القدر';
  static const featLaylatDesc  = 'العشر الأواخر';
  static const featAthkar      = 'الأذكار';
  static const featAthkarDesc  = 'صباحاً ومساءً';
  static const featProgress    = 'تقدمي';
  static const featProgressDesc = 'تابع مستواك';

  // ─── القرآن ─────────────────────────────────────────────
  static const quranTitle       = 'القرآن الكريم';
  static const tabSurahs        = 'سور';
  static const tabJuz           = 'أجزاء';
  static const tabSearch        = 'بحث';
  static const changeReciter    = 'تغيير';
  static const bismillah        = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';
  static const makkiyya         = 'مكية';
  static const madaniyya        = 'مدنية';
  static const verses           = 'آية';
  static const versesSuffix     = 'آيات';

  // ─── الأدعية ────────────────────────────────────────────
  static const duaTitle        = '🤲 أدعية مختارة';
  static const catAll          = 'الكل';
  static const catRamadan      = 'رمضانية';
  static const catIftar        = 'الإفطار';
  static const catSuhoor       = 'السحور';
  static const catLaylat       = 'ليلة القدر';
  static const catMorning      = 'الصباح';
  static const catEvening      = 'المساء';
  static const catRizq         = 'الرزق';
  static const catShifa        = 'الشفاء';

  // ─── الأذكار ────────────────────────────────────────────
  static const athkarTitle      = '🌿 الأذكار';
  static const athkarMorning    = 'الصباح';
  static const athkarEvening    = 'المساء';
  static const athkarSleep      = 'النوم';
  static const athkarWakeUp     = 'الاستيقاظ';
  static const athkarAfterPray  = 'بعد الصلاة';
  static const athkarEating     = 'الأكل';
  static const athkarTravel     = 'السفر';
  static const athkarMisc       = 'متنوعة';

  // ─── التسبيح ────────────────────────────────────────────
  static const tasbihTitle     = 'التسبيح';
  static const tasbihSub1      = 'سبحان الله';
  static const tasbihSub2      = 'الحمد لله';
  static const tasbihSub3      = 'الله أكبر';
  static const tasbihTarget    = 'الهدف:';
  static const tasbihNote      = 'اضغط للتسبيح • اهتزاز عند كل نقرة';
  static const tasbihToday     = 'اليوم';
  static const tasbihRamadan   = 'رمضان';
  static const reset           = '↺';

  // ─── القبلة ─────────────────────────────────────────────
  static const qiblaTitle      = 'اتجاه القبلة';
  static const qiblaFromCity   = '🗺️ اتجاه القبلة من';
  static const qiblaHint       = 'وجّه جهازك ليتحرك معك 🧲';
  static const compassN        = 'ش';
  static const compassS        = 'ج';
  static const compassE        = 'غ';
  static const compassW        = 'ش.غ';

  // ─── الإعدادات ──────────────────────────────────────────
  static const settingsTitle        = 'إعدادات الصلاة';
  static const settingsAlerts       = 'التنبيهات';
  static const settingsPrayerAlert  = 'تنبيه أوقات الصلاة';
  static const settingsBeforeMin    = 'تذكير قبل الصلاة';
  static const settingsSuhoor       = 'تنبيه السحور';
  static const settingsIftar        = 'تنبيه الإفطار';
  static const settingsAdhanSound   = 'صوت الأذان';
  static const settingsReciter      = 'شيخ التلاوة';
  static const settingsSelected     = '● محدد';
  static const settingsMinutes      = 'دقيقة';

  // ─── التقدم ─────────────────────────────────────────────
  static const progressTitle    = '⭐ تقدمي في رمضان';
  static const statKhatmas      = 'ختمات القرآن';
  static const statTasbih       = 'تسبيحة';
  static const statDua          = 'دعاء مقروء';
  static const statPrayer       = 'صلاة في موعدها';
  static const statQiyam        = 'قيام ليل';
  static const statBadge        = 'شارة نجاح';
  static const badgesTitle      = '🏅 شاراتي';
  static const badgeLocked      = 'قريباً';
  static const badgeKhatma      = 'ختمة';
  static const badgeMudawim     = 'مداوم';
  static const badgeMuhafiz     = 'محافظ';
  static const badgeQaim        = 'قائم';

  // ─── زخرفة ──────────────────────────────────────────────
  static const ornament     = '❋ ✦ ❋';
  static const ornamentFull = '❋ ✦ ❋ ✦ ❋ ✦ ❋';
  static const diamond      = '❖';
}
