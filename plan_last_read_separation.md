# خطة فصل الحفظ اليدوي عن الاستئناف التلقائي لكل سورة

> الهدف: حل تضارب `آخر قراءة يدوية آية 6 → تلقائي 1` ومطابقة معيار كبار التطبيقات (شارة مثبتة + استئناف صفحة لكل سورة) بدون مفاجآت للمستخدم.

---

## 0. الوضع الحالي — التشخيص

| المكون | الملف | السطر | السلوك الحالي |
|---|---|---|---|
| الحفظ اليدوي | `lib/features/quran/screens/quran_reader_screen.dart` | `1334:_saveSelectionAsLastRead` | يكتب `LastReadPosition(surah,ayah)` في `last_read_by_surah` عبر `lastReadProvider.savePosition` ويظهر `SnackBar 6` |
| الحفظ التلقائي | `lib/features/quran/screens/quran_reader_screen.dart` | `207:_updateVisibleAyah` → `218:_scheduleLastReadSave` → `237:_flushPendingLastRead` | كل `800ms` يكتب نفس المفتاح `last_read_by_surah` من `VisibilityDetector` في `paragraph_quran_text.dart:111` أو `justified_quran_text.dart:51` |
| التخزين | `lib/core/services/last_read_service.dart` | `13:_keyBySurah` `39:saveLastRead` | مفتاح واحد `last_read_by_surah` لكلا المسارين → الأخير يفوز |
| العرض في القائمة | `lib/features/quran/screens/surah_list_screen.dart` | `178:ayahForSurah` | يقرأ `bySurah[surah]` (المشترك) |
| الفتح | `lib/features/quran/screens/quran_reader_screen.dart` | `128:_lastReadAyahMarker = ayahForSurah` | يعتمد على نفس المفتاح المشترك |
| المشكلة الموثقة | — | — | بعد حفظ يدوي `6` يعيد التلقائي جدولة `1` (أول آية مرئية) من `page-1` فيعيد الكتابة بعد `800ms` → `6→1` |

---

## 1. الهدف النهائي — فصل كامل (المعيار)

*   **يدوي `Manual`**: `Map<surah, ayah>` → شارة `آخر قراءة: آية 6` في القائمة + تظليل عند الفتح. يثبت حتى يغيره المستخدم يدوياً فقط.
*   **تلقائي `Auto`**: `Map<surah, {page, ayah, surah}>` → استئناف **لكل سورة** لصفحتها. يكتب كل `800ms` ولا يمس الشارة.
*   **أولوية الفتح**: `initialAyah ?? manual[surah] ?? auto[surah] ?? 1`

الدليل على المعيار: `iQuran: Automatic Last Reading Sessions + Bookmarks` و `Quran App: resume where you left` منفصل عن `bookmark` (انظر تقرير البحث السابق).

---

## 2. خريطة الملفات المعنية

```
lib/core/services/last_read_service.dart          # فصل المفاتيح + هجرة
lib/features/quran/providers/last_read_provider.dart # يبقى Manual فقط
lib/features/quran/providers/auto_resume_provider.dart # جديد Auto Map
lib/features/quran/screens/quran_reader_screen.dart    # تصحيح الكتابة + الفتح
lib/features/quran/widgets/paragraph_quran_text.dart   # لا تغيير (مصدر الإظهار فقط)
lib/features/quran/widgets/justified_quran_text.dart   # لا تغيير
lib/features/quran/screens/surah_list_screen.dart      # يقرأ Manual فقط (يبقى)
```

---

## 3. المراحل بالتسلسل الصحيح

### المرحلة 1 — التخزين `last_read_service.dart`

**المهام:**
1.  الإبقاء على `13:_keyBySurah = 'last_read_by_surah'` للـ **يدوي** فقط (توضيح بالتعليق).
2.  إضافة `14:_keyAutoBySurah = 'last_auto_page_by_surah'` جديد للـ **تلقائي**.
3.  إضافة `saveManual(LastReadPosition)` → يكتب `last_read_global` + `last_read_by_surah` (السلوك الحالي لكن باسم واضح).
4.  إضافة `saveAuto(LastReadPosition)` → يكتب فقط `last_auto_page_by_surah` (Map<String,int> للصفحة أو Map كامل).
5.  إضافة `getAutoBySurah() -> Map<int,int>` و `getAutoForSurah(surah) -> int? page` و `getAutoPosition(surah) -> LastReadPosition?` (حسب الحاجة للصفحة).
6.  إضافة `clearManualForSurah(surah)` و `clearAutoForSurah(surah)` للمسح الانتقائي.
7.  هجرة صامتة في `init()`: إذا كان `last_read_by_surah` موجود و `last_auto_page_by_surah` فارغ → انسخ القيمة الحالية إلى التلقائي لمرة واحدة حتى لا يفقد المستخدم موضعه الحالي.

**معيار القبول:** `Hive Box` يحتوي مفتاحين منفصلين ولا يحدث كتابة متقاطعة.

### المرحلة 2 — المزودات

**2A — الإبقاء على Manual:**
*   `lib/features/quran/providers/last_read_provider.dart` يبقى `LastReadState.bySurah` للشارة فقط.
*   تعديل `56:savePosition` ليستدعي `saveManual` فقط وتحديث التعليق.

**2B — إنشاء Auto الجديد:**
*   ملف جديد `lib/features/quran/providers/auto_resume_provider.dart`:
    *   `class AutoResumeState { Map<int,int> pageBySurah; Map<int,LastReadPosition> posBySurah; }`
    *   `AutoResumeNotifier` يحمّل من `getAutoBySurah()` في `_load()` ويوفر `saveAutoPosition(LastReadPosition)` + `clear(surah)` + `reload()`.
    *   `Provider: autoResumeProvider`.

**معيار القبول:** `ref.watch(lastReadProvider).ayahForSurah(1)==6` لا يتغير عند كتابة `autoResumeProvider`.

### المرحلة 3 — فصل الكتابة في القارئ `quran_reader_screen.dart`

**3A — اليدوي:**
*   `1334:_saveSelectionAsLastRead` يبقى يكتب `lastReadProvider.savePosition` (Manual) فقط.
*   يلغي فقط `Timer` التلقائي المعلق لحظياً `1343` لمنع كتابة كانت مجدولة قبل النقر (يبقى السطر لكن لا يمس الجديد بعد الآن).
*   يحدث `_lastReadAyahMarker` محلياً للشارة الفورية.

**3B — التلقائي:**
*   `207:_updateVisibleAyah` → `218:_scheduleLastReadSave` → `237:_flushPendingLastRead` تُعدل لتكتب `autoResumeProvider.saveAutoPosition` بدل `lastReadProvider`.
*   `pending` يبقى `LastReadPosition` لكن يُخزن في `auto` فقط.
*   لا يمس `Manual` إطلاقاً.

**معيار القبول:** بعد تسلسل `schedule(1) → saveManual(6) → schedule(1)` القيمة النهائية `manual[1]==6` و `auto[1]==1`.

### المرحلة 4 — منطق الفتح `quran_reader_screen.dart:109 _loadSurah`

**الترتيب الجديد في `109`:**
```
_lastReadAyahMarker = ref.read(lastReadProvider).ayahForSurah(surah) // Manual
_autoPageMarker = ref.read(autoResumeProvider).pageForSurah(surah) // Auto

if (widget.initialAyah != null) scrollTo(initialAyah)
else if (_lastReadAyahMarker != null) scrollTo(_lastReadAyahMarker) + تظليل
else if (_autoPageMarker != null) scrollTo(firstAyahOfPage(_autoPageMarker))
else scrollTo(1)
```
*   لا تغيير في `WidgetsBinding.addPostFrameCallback` الحالي، فقط مصدر البيانات.
*   إضافة حقل `int? _autoPageMarker` بجانب `_lastReadAyahMarker:88`.

**معيار القبول:** فتح سورة لها يدوي 6 وتلقائي صفحة 10 يفتح على 6 متظللة.

### المرحلة 5 — العرض

*   `surah_list_screen.dart:178` يبقى يقرأ `lastReadProvider` فقط (الشارة الذهبية).
*   **اختياري مستقبلاً:** إضافة شارة رمادية `متابعة صفحة X` من `autoResumeProvider` بجانب الذهبية — ليس في هذه الخطة الأساسية.

**معيار القبول:** القائمة لا تتأثر بالتمرير التلقائي.

### المرحلة 6 — المسح اليدوي (إكمال اليدوي)

*   إضافة دالة `clearManualForSurah` في `last_read_provider.dart`.
*   في `quran_reader_screen.dart` بجانب `bookmark_border` إضافة إجراء طويل الضغط أو قائمة صغيرة `إلغاء آخر قراءة` تستدعي `clear` وتُصفر `_lastReadAyahMarker` وتظهر `Toast`.

**معيار القبول:** بعد المسح `ayahForSurah==null` والفتح التالي يعود للتلقائي.

### المرحلة 7 — التحقق الشامل

| السيناريو | الخطوات | المتوقع |
|---|---|---|
| حفظ يدوي يثبت | افتح فاتحة → المس 6 → 🔖 → خروج للقائمة | `آخر قراءة: آية 6` |
| تلقائي لا يمحو يدوي | بعد 6 → مرر لنهاية الفاتحة وابق 2 ثانية → خروج | القائمة ما زالت `6` |
| كل سورة تتذكر | افتح بقرة لصفحة 10 → اخرج → افتح آل عمران لصفحة 5 → اخرج → افتح بقرة | بقرة في 10 وآل عمران في 5 |
| أولوية يدوي | بقرة لها يدوي 6 وتلقائي 10 → افتح بقرة | يفتح على 6 متظللة |
| بعد مسح يدوي | امسح يدوي بقرة → افتح بقرة | يفتح على تلقائي 10 |
| هجرة | مستخدم محدث من نسخة قديمة لها `1` | تلقائي يُنسخ `1` لمرة واحدة ولا يفقد |

### المرحلة 8 — التنظيف والتوثيق

*   تحديث تعليقات `last_read_service.dart:13` و `quran_reader_screen.dart:27 disableAutoAdvance` (أصبح Legacy).
*   إزالة `cancel` المتبادل غير الضروري بعد الفصل.
*   تحديث `plan_last_read_separation.md` بنتائج كل مرحلة.

---

## 4. المخاطر والتخفيف

| الخطر | التخفيف |
|---|---|
| فقدان موضع المستخدم الحالي عند التحديث | هجرة صامتة في `init()` نسخ لمرة واحدة |
| كتابة متزامنة من قارئين مفتوحين | كل كتابة تستخدم `Map.from(state)` + `Hive.put` الذري |
| استهلاك Hive | `Map<114,int>` لا يذكر |

---

## 5. التسليم المرحلي المطلوب منك

بعد كل مرحلة أقدم لك تقريراً يحتوي:
*   الملفات المعدلة `file:line`
*   ناتج `dart analyze`
*   لقطة سيناريو التحقق لتلك المرحلة

**بانتظار أمرك `ابدأ المرحلة 1` للتنفيذ.**
