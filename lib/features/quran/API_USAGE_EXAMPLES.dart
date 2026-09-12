/// ==================== أمثلة استخدام Quran.com API ====================
///
/// هذا الملف يحتوي على أمثلة عملية لاستخدام خدمة Quran.com في التطبيق

import 'package:nour_ramadan/core/services/quran_api_service.dart';
import 'package:nour_ramadan/core/services/audio_service.dart';

// ════════════════════════════════════════════════════════════════════════════

/// مثال 1: جلب كل السور
///
/// ```dart
/// Future<void> getAllSurahs() async {
///   final api = QuranApiService();
///   final surahs = await api.getAllSurahs(language: 'ar');
///   
///   for (var surah in surahs) {
///     print('${surah.id} - ${surah.name}');
///     // Output: 1 - الفاتحة
///     //         2 - البقرة
///     //         ...
///   }
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// مثال 2: جلب آيات سورة محددة
///
/// ```dart
/// Future<void> getSurahAyahs() async {
///   final api = QuranApiService();
///   
///   // السورة رقم 1 (الفاتحة)
///   final ayahs = await api.getSurahAyahs(
///     surahNumber: 1,
///     textType: 'text_imlaei', // الرسم الإملائي
///   );
///   
///   for (var ayah in ayahs) {
///     print('الآية ${ayah.numberInSurah}:');
///     print('${ayah.text}');
///     print('---');
///     
///     // Output:
///     // الآية 1:
///     // الحمد لله رب العالمين
///     // ---
///   }
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// مثال 3: جلب رابط صوت آية محددة
///
/// ```dart
/// Future<void> getAyahAudio() async {
///   final api = QuranApiService();
///   
///   // الآية الأولى من السورة الأولى
///   final audioUrl = await api.getAyahAudio(
///     surahNumber: 1,      // الفاتحة
///     ayahNumber: 1,       // الآية الأولى
///     reciterId: '5',      // عبدالباسط
///   );
///   
///   print('رابط الصوت: $audioUrl');
///   // Output: https://cdn.IslamicNetwork.com/quran/...
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// مثال 4: تشغيل آية من الصوت
///
/// ```dart
/// Future<void> playAyahAudio() async {
///   final api = QuranApiService();
///   final audioService = AudioService();
///   
///   // 1. جلب رابط الصوت
///   final url = await api.getAyahAudio(
///     surahNumber: 1,
///     ayahNumber: 1,
///     reciterId: '5',
///   );
///   
///   if (url != null) {
///     // 2. تشغيل الصوت
///     await audioService.playAyah(url);
///     print('▶️ جاري التشغيل...');
///   }
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// مثال 5: تشغيل عدة آيات بالترتيب
///
/// ```dart
/// Future<void> playMultipleAyahs() async {
///   final api = QuranApiService();
///   final audioService = AudioService();
///   
///   // الآيات المراد تشغيلها
///   final ayahNumbers = [1, 2, 3, 4];
///   
///   for (var ayahNum in ayahNumbers) {
///     // 1. جلب الصوت
///     final url = await api.getAyahAudio(
///       surahNumber: 1,      // الفاتحة
///       ayahNumber: ayahNum,
///       reciterId: '5',
///     );
///     
///     if (url != null) {
///       // 2. تشغيل الصوت
///       print('▶️ الآية $ayahNum');
///       await audioService.playAyah(url);
///       
///       // 3. الانتظار لانتهاء التشغيل (تقريباً 10-20 ثانية)
///       await Future.delayed(Duration(seconds: 20));
///       print('✅ انتهت الآية $ayahNum');
///     }
///   }
///   
///   print('🎉 انتهى التشغيل!');
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// مثال 6: معلومات السورة الكاملة
///
/// ```dart
/// Future<void> getSurahInfo() async {
///   final api = QuranApiService();
///   
///   final info = await api.getSurahInfo(2); // السورة 2 (البقرة)
///   
///   if (info != null) {
///     print('اسم السورة: ${info.name}');
///     print('الاسم الإنجليزي: ${info.englishName}');
///     print('عدد الآيات: ${info.ayahCount}');
///     print('نوع التنزيل: ${info.revelationType}');
///     
///     // Output:
///     // اسم السورة: البقرة
///     // الاسم الإنجليزي: Al-Baqarah
///     // عدد الآيات: 286
///     // نوع التنزيل: Madani
///   }
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// مثال 7: معالجة الأخطاء
///
/// ```dart
/// Future<void> handleErrors() async {
///   final api = QuranApiService();
///   
///   try {
///     // محاولة جلب آيات سورة غير موجودة
///     final ayahs = await api.getSurahAyahs(
///       surahNumber: 999, // لا توجد!
///     );
///     
///   } catch (e) {
///     // معالجة الخطأ
///     print('❌ حدث خطأ: $e');
///     
///     // إظهار رسالة للمستخدم
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('فشل تحميل السورة: $e')),
///     );
///   }
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// مثال 8: استخدام مع Riverpod (State Management)
///
/// ```dart
/// import 'package:flutter_riverpod/flutter_riverpod.dart';
///
/// // Provider للـ API
/// final quranApiProvider = Provider((ref) => QuranApiService());
///
/// // Provider لجلب السور
/// final surahsProvider = FutureProvider((ref) async {
///   final api = ref.watch(quranApiProvider);
///   return api.getAllSurahs();
/// });
///
/// // Provider لجلب آيات سورة محددة
/// final surahAyahsProvider = FutureProvider.family((ref, int surahNum) async {
///   final api = ref.watch(quranApiProvider);
///   return api.getSurahAyahs(surahNumber: surahNum);
/// });
///
/// // الاستخدام في Widget:
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final surahs = ref.watch(surahsProvider);
///     
///     return surahs.when(
///       data: (data) => ListView.builder(
///         itemCount: data.length,
///         itemBuilder: (context, i) => Text(data[i].name),
///       ),
///       loading: () => CircularProgressIndicator(),
///       error: (err, st) => Text('Error: $err'),
///     );
///   }
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// مثال 9: البحث عن سورة
///
/// ```dart
/// Future<void> searchSurah() async {
///   final api = QuranApiService();
///   
///   final allSurahs = await api.getAllSurahs();
///   
///   // البحث عن "البقرة"
///   final result = allSurahs.where((s) => 
///     s.name.contains('البقرة') ||
///     s.englishName.toLowerCase().contains('baqarah')
///   ).toList();
///   
///   for (var surah in result) {
///     print('${surah.name} - ${surah.englishName}');
///   }
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// مثال 10: التدفق الكامل (بدءاً من اختيار السورة إلى التشغيل)
///
/// ```dart
/// Future<void> completeFlow() async {
///   final api = QuranApiService();
///   final audioService = AudioService();
///   
///   // 1. جلب السور
///   print('📖 جاري جلب السور...');
///   final surahs = await api.getAllSurahs();
///   print('✅ تم جلب ${surahs.length} سورة');
///   
///   // 2. اختيار السورة الأولى (الفاتحة)
///   final selectedSurah = surahs[0];
///   print('\n📕 اخترت: ${selectedSurah.name}');
///   
///   // 3. جلب معلوماتها
///   final info = await api.getSurahInfo(selectedSurah.id);
///   print('   عدد الآيات: ${info?.ayahCount}');
///   
///   // 4. جلب الآيات
///   print('\n📝 جاري جلب الآيات...');
///   final ayahs = await api.getSurahAyahs(
///     surahNumber: selectedSurah.id,
///   );
///   print('✅ تم جلب ${ayahs.length} آية');
///   
///   // 5. تشغيل الآية الأولى
///   if (ayahs.isNotEmpty) {
///     print('\n🎤 الآية الأولى:');
///     print('   ${ayahs[0].text}');
///     
///     final audioUrl = await api.getAyahAudio(
///       surahNumber: selectedSurah.id,
///       ayahNumber: 1,
///       reciterId: '5',
///     );
///     
///     if (audioUrl != null) {
///       print('\n▶️ تشغيل الآية...');
///       await audioService.playAyah(audioUrl);
///     }
///   }
///   
///   print('\n🎉 انتهى!');
/// }
/// ```

// ════════════════════════════════════════════════════════════════════════════

/// نصائح برمجية:
/// 
/// 1. استخدم async/await دائماً
/// 2. تعامل مع الأخطاء مع try/catch
/// 3. استخدم null safety (??)
/// 4. استخدم Riverpod لإدارة الحالة
/// 5. اختبر الاتصال بالإنترنت قبل الطلب
/// 6. عدّل عناصر الـ UI فقط عندما تكون mounted
/// 7. استخدم const constructors عندما يكون ممكناً
/// 8. احفظ البيانات محلياً لتجنب الطلبات المتكررة

// ════════════════════════════════════════════════════════════════════════════

/// الخطاطيف المفيدة:
/// 
/// initState(() {
///   _loadData();
/// });
///
/// Future<void> _loadData() async {
///   setState(() => _isLoading = true);
///   try {
///     _data = await _service.getData();
///   } catch (e) {
///     _showError(e);
///   } finally {
///     setState(() => _isLoading = false);
///   }
/// }

// ════════════════════════════════════════════════════════════════════════════

/// استمتع بالبرمجة! 💻
/// تم بإذن من Almighty! 📖
