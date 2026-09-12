// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:just_audio/just_audio.dart';
// import '../../../core/theme/app_colors.dart';
// import '../../../core/services/offline_quran_service.dart';
// import '../../../core/services/local_quran_service.dart';
// import '../../settings/providers/settings_provider.dart';
// import '../widgets/surah_header_widget.dart';
// import '../widgets/justified_quran_text.dart';
// import '../widgets/paragraph_quran_text.dart';

// // ════════════════════════════════════════════════════════════════
// //  ModernQuranReaderV2 — قارئ المصحف Offline-First
// //  • نصوص محلية من JSON (بدون إنترنت)
// //  • صوت ذكي مع LRU Cache (50MB)
// //  • تنبيه احترافي عند عدم وجود إنترنت
// //  • تبديل بين نمط السطور ونمط الفقرة
// // ════════════════════════════════════════════════════════════════

// class ModernQuranReaderV2 extends ConsumerStatefulWidget {
//   final int surahNumber;
//   final int? initialAyah;

//   const ModernQuranReaderV2({
//     super.key,
//     required this.surahNumber,
//     this.initialAyah,
//   });

//   @override
//   ConsumerState<ModernQuranReaderV2> createState() =>
//       _ModernQuranReaderV2State();
// }

// class _ModernQuranReaderV2State extends ConsumerState<ModernQuranReaderV2> {
//   final AudioPlayer _player = AudioPlayer();
//   final ScrollController _scrollController = ScrollController();
//   final Map<int, GlobalKey> _ayahKeys = {};

//   List<LocalAyah> _ayahs = [];
//   SurahInfo? _surahInfo;
//   bool _isLoading = true;
//   String? _error;

//   // البحث
//   bool _isSearching = false;
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   // ── نمط العرض ──
//   bool _isParagraphMode = true; // الوضع الافتراضي: مسترسل

//   // ── التحديد ──
//   int? _selStart;
//   int? _selEnd;

//   // ── الصوت ──
//   int _playingAyah = 0;
//   bool _isPlaying = false;
//   bool _isLoadingAudio = false;
//   bool _repeatEnabled = false;
//   bool _isStopping = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadSurah();
//   }

//   @override
//   void dispose() {
//     _isStopping = true;
//     _player.dispose();
//     _scrollController.dispose();
//     _searchController.dispose();
//     super.dispose();
//   }

//   // ════════════════════════════════════════════════════════════════
//   //  تحميل البيانات من الملفات المحلية
//   // ════════════════════════════════════════════════════════════════

//   Future<void> _loadSurah() async {
//     setState(() {
//       _isLoading = true;
//       _error = null;
//     });

//     try {
//       final service = ref.read(offlineQuranServiceProvider);

//       // تحميل معلومات السورة
//       _surahInfo = await service.getSurahInfo(widget.surahNumber);

//       // تحميل الآيات من الملف المحلي
//       _ayahs = await service.getSurahAyahs(widget.surahNumber);

//       if (_ayahs.isEmpty) {
//         _error = 'لم يتم العثور على آيات لهذه السورة';
//       } else {
//         // إنشاء مفاتيح للآيات
//         for (var ayah in _ayahs) {
//           _ayahKeys[ayah.numberInSurah] = GlobalKey();
//         }

//         // الانتقال للآية المحددة
//         if (widget.initialAyah != null) {
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             _scrollToAyah(widget.initialAyah!);
//           });
//         }
//       }
//     } catch (e) {
//       _error = 'خطأ في تحميل السورة: $e';
//     }

//     if (mounted) setState(() => _isLoading = false);
//   }

//   void _scrollToAyah(int ayahNumber) {
//     final key = _ayahKeys[ayahNumber];
//     if (key?.currentContext != null) {
//       Scrollable.ensureVisible(
//         key!.currentContext!,
//         duration: const Duration(milliseconds: 500),
//         curve: Curves.easeInOut,
//         alignment: 0.2,
//       );

//       setState(() {
//         _selStart = ayahNumber;
//         _selEnd = ayahNumber;
//       });
//     }
//   }

//   // ════════════════════════════════════════════════════════════════
//   //  التحديد (التظليل)
//   // ════════════════════════════════════════════════════════════════

//   bool _isSelected(int ayahNum) {
//     if (_selStart == null) return false;
//     final end = _selEnd ?? _selStart!;
//     final mn = _selStart! < end ? _selStart! : end;
//     final mx = _selStart! < end ? end : _selStart!;
//     return ayahNum >= mn && ayahNum <= mx;
//   }

//   void _onAyahTap(int ayahNum) {
//     setState(() {
//       if (_selStart == null) {
//         // لا يوجد تحديد - ابدأ تحديد جديد
//         _selStart = ayahNum;
//         _selEnd = ayahNum;
//       } else if (_selStart == ayahNum && _selEnd == ayahNum) {
//         // الضغط على نفس الآية الوحيدة المحددة - إلغاء التحديد
//         _selStart = null;
//         _selEnd = null;
//       } else if (_selEnd == ayahNum) {
//         // الضغط على آخر آية محددة - إلغاء آخر آية
//         if (_selStart == _selEnd) {
//           // كانت آية واحدة فقط - إلغاء كل شيء
//           _selStart = null;
//           _selEnd = null;
//         } else {
//           // تقليل النطاق بآية واحدة
//           if (_selStart! < _selEnd!) {
//             _selEnd = _selEnd! - 1;
//           } else {
//             _selEnd = _selEnd! + 1;
//           }
//         }
//       } else if (_selStart == ayahNum) {
//         // الضغط على أول آية محددة - إلغاء أول آية
//         if (_selStart == _selEnd) {
//           // كانت آية واحدة فقط - إلغاء كل شيء
//           _selStart = null;
//           _selEnd = null;
//         } else {
//           // تقليل النطاق من البداية
//           if (_selStart! < _selEnd!) {
//             _selStart = _selStart! + 1;
//           } else {
//             _selStart = _selStart! - 1;
//           }
//         }
//       } else {
//         // الضغط على آية جديدة - توسيع النطاق
//         _selEnd = ayahNum;
//       }
//     });
//   }

//   void _onAyahLongPress(int ayahNum) {
//     setState(() {
//       _selStart = ayahNum;
//       _selEnd = ayahNum;
//     });
//   }

//   void _clearSelection() async {
//     // إيقاف الصوت إذا كان يعمل
//     if (_isPlaying) {
//       await _stopPlayback();
//     }
//     setState(() {
//       _selStart = null;
//       _selEnd = null;
//     });
//   }

//   // ════════════════════════════════════════════════════════════════
//   //  تشغيل الصوت — Offline-First مع Smart Cache
//   // ════════════════════════════════════════════════════════════════

//   Future<void> _playSelection() async {
//     if (_selStart == null) return;

//     final service = ref.read(offlineQuranServiceProvider);
//     final settings = ref.read(settingsProvider);
//     final delay = settings.ayahDelay;

//     final end = _selEnd ?? _selStart!;
//     final from = _selStart! < end ? _selStart! : end;
//     final to = _selStart! < end ? end : _selStart!;

//     _isStopping = false;
//     bool hasShownNoInternetMessage = false; // لتجنب عرض الرسالة أكثر من مرة

//     do {
//       setState(() {
//         _isPlaying = true;
//         _isLoadingAudio = false;
//       });

//       for (var i = from; i <= to; i++) {
//         if (_isStopping) break;
//         setState(() {
//           _playingAyah = i;
//           _isLoadingAudio = true;
//         });

//         try {
//           // الحصول على ملف الصوت (من الكاش أو التحميل)
//           final audioResult = await service.getAyahAudio(
//             surahNumber: widget.surahNumber,
//             ayahNumber: i,
//             reciter: settings.sheikh.reciterCode,
//           );

//           if (!audioResult.success) {
//             if (audioResult.needsInternet &&
//                 mounted &&
//                 !hasShownNoInternetMessage) {
//               hasShownNoInternetMessage = true;
//               _showNoInternetDialog(
//                 i > from
//                     ? 'تم تشغيل ${i - from} آية/آيات من أصل ${to - from + 1}.\n\n${audioResult.errorMessage!}'
//                     : audioResult.errorMessage!,
//               );
//               await _stopPlayback();
//               return;
//             }
//             if (audioResult.needsInternet) {
//               await _stopPlayback();
//               return;
//             }
//             // خطأ غير متعلق بالشبكة — تخطي الآية والمتابعة
//             continue;
//           }

//           // تشغيل الملف
//           await _player.setFilePath(audioResult.file!.path);
//           setState(() => _isLoadingAudio = false);

//           await _player.play();

//           // انتظار انتهاء التشغيل
//           await _player.playerStateStream.firstWhere(
//             (s) => s.processingState == ProcessingState.completed,
//           );
//         } catch (e) {
//           print('❌ خطأ في تشغيل الآية $i: $e');
//           setState(() => _isLoadingAudio = false);
//         }

//         // وقفة بين الآيات
//         if (i < to && !_isStopping) {
//           await Future.delayed(Duration(milliseconds: delay));
//         }
//       }
//     } while (_repeatEnabled && !_isStopping);

//     if (mounted) {
//       setState(() {
//         _playingAyah = 0;
//         _isPlaying = false;
//         _isLoadingAudio = false;
//       });
//     }
//   }

//   Future<void> _stopPlayback() async {
//     _isStopping = true;
//     await _player.stop();
//     if (mounted) {
//       setState(() {
//         _playingAyah = 0;
//         _isPlaying = false;
//         _isLoadingAudio = false;
//       });
//     }
//   }

//   // ── عرض رسالة عدم وجود إنترنت ──────────────────────────────────
//   void _showNoInternetDialog(String message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: AppColors.mushafPaper,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16.r),
//         ),
//         title: Row(
//           children: [
//             Icon(
//               Icons.wifi_off_rounded,
//               color: AppColors.goldWarm,
//               size: 24.sp,
//             ),
//             SizedBox(width: 8.w),
//             Text(
//               'لا يوجد اتصال',
//               style: TextStyle(
//                 fontFamily: 'Tajawal',
//                 fontSize: 18.sp,
//                 fontWeight: FontWeight.bold,
//                 color: AppColors.mushafInk,
//               ),
//             ),
//           ],
//         ),
//         content: Text(
//           message,
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             fontFamily: 'Tajawal',
//             fontSize: 14.sp,
//             color: AppColors.textDim,
//             height: 1.6,
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               'حسناً',
//               style: TextStyle(
//                 fontFamily: 'Tajawal',
//                 fontSize: 14.sp,
//                 color: AppColors.goldWarm,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ════════════════════════════════════════════════════════════════
//   //  واجهة المستخدم
//   // ════════════════════════════════════════════════════════════════

//   @override
//   Widget build(BuildContext context) {
//     final settings = ref.watch(settingsProvider);
//     final sheikh = settings.sheikh;

//     return Scaffold(
//       backgroundColor: AppColors.mushafPaper,
//       body: _isLoading
//           ? const Center(
//               child: CircularProgressIndicator(color: AppColors.goldWarm),
//             )
//           : _error != null
//           ? _buildError()
//           : Stack(
//               children: [
//                 Column(
//                   children: [
//                     _buildHeader(sheikh),
//                     Expanded(child: _buildMushafBody()),
//                   ],
//                 ),
//                 if (_selStart != null) _buildAudioBar(sheikh),
//               ],
//             ),
//     );
//   }

//   Widget _buildError() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.error_outline, size: 64.sp, color: AppColors.textDim),
//           SizedBox(height: 16.h),
//           Text(
//             _error!,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontFamily: 'Tajawal',
//               fontSize: 16.sp,
//               color: AppColors.textDim,
//             ),
//           ),
//           SizedBox(height: 24.h),
//           ElevatedButton(
//             onPressed: _loadSurah,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.goldWarm,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12.r),
//               ),
//             ),
//             child: Text(
//               'إعادة المحاولة',
//               style: TextStyle(fontFamily: 'Tajawal', fontSize: 14.sp),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildHeader(Sheikh sheikh) {
//     return Container(
//       color: AppColors.mushafPaper,
//       padding: EdgeInsets.only(
//         top: MediaQuery.of(context).padding.top + 8.h,
//         bottom: 10.h,
//         left: 16.w,
//         right: 16.w,
//       ),
//       child: Column(
//         children: [
//           // الصف الأول: زر الرجوع، البحث، قائمة الآيات، الشيخ
//           Row(
//             children: [
//               // زر الرجوع
//               GestureDetector(
//                 onTap: () => Navigator.pop(context),
//                 child: Container(
//                   width: 36.r,
//                   height: 36.r,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: AppColors.goldWarm.withValues(alpha: 0.1),
//                     border: Border.all(
//                       color: AppColors.goldWarm.withValues(alpha: 0.3),
//                       width: 1,
//                     ),
//                   ),
//                   child: Icon(
//                     Icons.arrow_back_ios_new,
//                     color: AppColors.mushafInk,
//                     size: 16.sp,
//                   ),
//                 ),
//               ),

//               SizedBox(width: 8.w),

//               // زر البحث
//               GestureDetector(
//                 onTap: () => setState(() => _isSearching = !_isSearching),
//                 child: Container(
//                   width: 36.r,
//                   height: 36.r,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: _isSearching
//                         ? AppColors.goldWarm.withValues(alpha: 0.2)
//                         : AppColors.goldWarm.withValues(alpha: 0.1),
//                     border: Border.all(
//                       color: AppColors.goldWarm.withValues(alpha: 0.3),
//                       width: 1,
//                     ),
//                   ),
//                   child: Icon(
//                     Icons.search_rounded,
//                     color: AppColors.mushafInk,
//                     size: 18.sp,
//                   ),
//                 ),
//               ),

//               const Spacer(),

//               // قائمة الآيات
//               if (_surahInfo != null)
//                 GestureDetector(
//                   onTap: _showAyahPicker,
//                   child: Container(
//                     padding: EdgeInsets.symmetric(
//                       horizontal: 10.w,
//                       vertical: 6.h,
//                     ),
//                     decoration: BoxDecoration(
//                       color: AppColors.goldWarm.withValues(alpha: 0.1),
//                       borderRadius: BorderRadius.circular(18.r),
//                       border: Border.all(
//                         color: AppColors.goldWarm.withValues(alpha: 0.3),
//                         width: 1,
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(
//                           Icons.format_list_numbered_rounded,
//                           size: 14.sp,
//                           color: AppColors.goldWarm,
//                         ),
//                         SizedBox(width: 4.w),
//                         Text(
//                           '${_surahInfo!.totalVerses}',
//                           style: TextStyle(
//                             fontFamily: 'Tajawal',
//                             fontSize: 11.sp,
//                             color: AppColors.mushafInk,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         Icon(
//                           Icons.arrow_drop_down_rounded,
//                           size: 16.sp,
//                           color: AppColors.mushafInk,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),

//               SizedBox(width: 8.w),

//               // زر اختيار الشيخ
//               GestureDetector(
//                 onTap: () => _showSheikhPicker(context),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(
//                     horizontal: 10.w,
//                     vertical: 6.h,
//                   ),
//                   decoration: BoxDecoration(
//                     color: AppColors.goldWarm.withValues(alpha: 0.1),
//                     borderRadius: BorderRadius.circular(18.r),
//                     border: Border.all(
//                       color: AppColors.goldWarm.withValues(alpha: 0.3),
//                       width: 1,
//                     ),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         Icons.record_voice_over_rounded,
//                         size: 14.sp,
//                         color: AppColors.goldWarm,
//                       ),
//                       SizedBox(width: 4.w),
//                       Text(
//                         sheikh.name.split(' ').last,
//                         style: TextStyle(
//                           fontFamily: 'Tajawal',
//                           fontSize: 11.sp,
//                           color: AppColors.mushafInk,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           // الصف الثاني: زر تبديل نمط العرض (بين الزرين العلويين)
//           SizedBox(height: 8.h),
//           Row(
//             children: [
//               SizedBox(width: 44.w), // محاذاة مع الزرين العلويين
//               Expanded(
//                 child: Center(
//                   child: GestureDetector(
//                     onTap: () =>
//                         setState(() => _isParagraphMode = !_isParagraphMode),
//                     child: Container(
//                       padding: EdgeInsets.symmetric(
//                         horizontal: 12.w,
//                         vertical: 8.h,
//                       ),
//                       decoration: BoxDecoration(
//                         color: AppColors.goldWarm.withValues(alpha: 0.1),
//                         borderRadius: BorderRadius.circular(18.r),
//                         border: Border.all(
//                           color: AppColors.goldWarm.withValues(alpha: 0.3),
//                           width: 1,
//                         ),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             _isParagraphMode
//                                 ? Icons.view_headline_rounded
//                                 : Icons.view_stream_rounded,
//                             size: 16.sp,
//                             color: AppColors.goldWarm,
//                           ),
//                           SizedBox(width: 6.w),
//                           Text(
//                             _isParagraphMode ? 'نمط مسترسل' : 'نمط سطور',
//                             style: TextStyle(
//                               fontFamily: 'Tajawal',
//                               fontSize: 12.sp,
//                               color: AppColors.mushafInk,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               SizedBox(width: 44.w), // محاذاة متساوية
//             ],
//           ),

//           // شريط البحث (يظهر عند الضغط على زر البحث)
//           if (_isSearching) ...[
//             SizedBox(height: 8.h),
//             Container(
//               height: 40.h,
//               decoration: BoxDecoration(
//                 color: AppColors.mushafPaper,
//                 borderRadius: BorderRadius.circular(20.r),
//                 border: Border.all(
//                   color: AppColors.goldWarm.withValues(alpha: 0.3),
//                   width: 1,
//                 ),
//               ),
//               child: TextField(
//                 controller: _searchController,
//                 textDirection: TextDirection.ltr,
//                 keyboardType: TextInputType.number,
//                 style: TextStyle(
//                   fontFamily: 'Tajawal',
//                   fontSize: 13.sp,
//                   color: AppColors.mushafInk,
//                 ),
//                 decoration: InputDecoration(
//                   hintText: 'رقم الآية...',
//                   hintStyle: TextStyle(
//                     fontFamily: 'Tajawal',
//                     fontSize: 13.sp,
//                     color: AppColors.textDim,
//                   ),
//                   prefixIcon: Icon(
//                     Icons.tag_rounded,
//                     color: AppColors.goldWarm,
//                     size: 18.sp,
//                   ),
//                   suffixIcon: _searchQuery.isNotEmpty
//                       ? IconButton(
//                           icon: Icon(
//                             Icons.clear_rounded,
//                             color: AppColors.textDim,
//                             size: 18.sp,
//                           ),
//                           onPressed: () {
//                             _searchController.clear();
//                             setState(() => _searchQuery = '');
//                           },
//                         )
//                       : null,
//                   border: InputBorder.none,
//                   contentPadding: EdgeInsets.symmetric(
//                     horizontal: 16.w,
//                     vertical: 10.h,
//                   ),
//                 ),
//                 onChanged: (value) {
//                   setState(() => _searchQuery = value);
//                 },
//                 onSubmitted: (value) {
//                   if (value.isNotEmpty) {
//                     _searchByAyahNumber(value);
//                   }
//                 },
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   // ── عرض قائمة الآيات ──────────────────────────────────────────
//   void _showAyahPicker() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: AppColors.mushafPaper,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
//       ),
//       builder: (context) => Container(
//         height: 400.h,
//         padding: EdgeInsets.symmetric(vertical: 16.h),
//         child: Column(
//           children: [
//             // العنوان
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   IconButton(
//                     icon: Icon(Icons.close_rounded, color: AppColors.textDim),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                   Text(
//                     'اختر الآية',
//                     style: TextStyle(
//                       fontFamily: 'Tajawal',
//                       fontSize: 16.sp,
//                       fontWeight: FontWeight.bold,
//                       color: AppColors.mushafInk,
//                     ),
//                   ),
//                   SizedBox(width: 48.w),
//                 ],
//               ),
//             ),

//             Divider(color: AppColors.mushafBorder),

//             // قائمة الآيات
//             Expanded(
//               child: ListView.builder(
//                 itemCount: _ayahs.length,
//                 itemBuilder: (context, index) {
//                   final ayah = _ayahs[index];
//                   return ListTile(
//                     onTap: () {
//                       Navigator.pop(context);
//                       _scrollToAyah(ayah.numberInSurah);
//                     },
//                     leading: Container(
//                       width: 36.r,
//                       height: 36.r,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: AppColors.goldWarm.withValues(alpha: 0.1),
//                         border: Border.all(
//                           color: AppColors.goldWarm.withValues(alpha: 0.3),
//                         ),
//                       ),
//                       child: Center(
//                         child: Text(
//                           '${ayah.numberInSurah}',
//                           style: TextStyle(
//                             fontFamily: 'Tajawal',
//                             fontSize: 12.sp,
//                             fontWeight: FontWeight.bold,
//                             color: AppColors.goldWarm,
//                           ),
//                         ),
//                       ),
//                     ),
//                     title: Text(
//                       ayah.text.length > 50
//                           ? '${ayah.text.substring(0, 50)}...'
//                           : ayah.text,
//                       textDirection: TextDirection.rtl,
//                       style: TextStyle(
//                         fontFamily: 'Amiri',
//                         fontSize: 14.sp,
//                         color: AppColors.mushafInk,
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── البحث برقم الآية ──────────────────────────────────────────
//   void _searchByAyahNumber(String query) {
//     final ayahNumber = int.tryParse(query);

//     if (ayahNumber == null) {
//       _showErrorMessage('الرجاء إدخال رقم صحيح');
//       return;
//     }

//     if (ayahNumber < 1 || ayahNumber > _ayahs.length) {
//       _showErrorMessage(
//         'الآية رقم $ayahNumber غير موجودة في هذه السورة\nالسورة تحتوي على ${_ayahs.length} آية فقط',
//       );
//       return;
//     }

//     _scrollToAyah(ayahNumber);
//     setState(() {
//       _isSearching = false;
//       _searchController.clear();
//       _searchQuery = '';
//     });
//   }

//   // ── عرض رسالة خطأ ────────────────────────────────────────────
//   void _showErrorMessage(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           message,
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             fontFamily: 'Tajawal',
//             fontSize: 13.sp,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: AppColors.goldWarm,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12.r),
//         ),
//         margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }

//   Widget _buildMushafBody() {
//     return SingleChildScrollView(
//       controller: _scrollController,
//       padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
//       child: Column(
//         children: [
//           // رأس السورة المزخرف
//           if (_surahInfo != null) SurahHeaderWidget(surahInfo: _surahInfo!),

//           SizedBox(height: 8.h), // تقليل من 16 إلى 8
//           // البسملة (إلا سورة التوبة)
//           if (widget.surahNumber != 9 && widget.surahNumber != 1)
//             Padding(
//               padding: EdgeInsets.only(bottom: 16.h), // تقليل من 24 إلى 16
//               child: Container(
//                 width: double.infinity,
//                 padding: EdgeInsets.symmetric(
//                   vertical: 10.h,
//                   horizontal: 16.w,
//                 ), // تقليل من 16/20 إلى 10/16
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       AppColors.goldWarm.withValues(alpha: 0.05),
//                       AppColors.mushafPaper,
//                       AppColors.goldWarm.withValues(alpha: 0.05),
//                     ],
//                   ),
//                   borderRadius: BorderRadius.circular(12.r),
//                   border: Border.all(
//                     color: AppColors.goldWarm.withValues(alpha: 0.2),
//                     width: 1,
//                   ),
//                 ),
//                 child: Text(
//                   'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontFamily: 'Amiri',
//                     fontSize: 22.sp, // تصغير من 28 إلى 22
//                     color: AppColors.mushafInk,
//                     height: 1.6, // تقليل من 2.0 إلى 1.6
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),

//           // النص القرآني المحسّن
//           _isParagraphMode
//               ? ParagraphQuranText(
//                   ayahs: _ayahs,
//                   onAyahTap: _onAyahTap,
//                   onAyahLongPress: _onAyahLongPress,
//                   isSelected: _isSelected,
//                   playingAyah: _playingAyah,
//                   ayahKeys: _ayahKeys,
//                 )
//               : JustifiedQuranText(
//                   ayahs: _ayahs,
//                   onAyahTap: _onAyahTap,
//                   onAyahLongPress: _onAyahLongPress,
//                   isSelected: _isSelected,
//                   playingAyah: _playingAyah,
//                   ayahKeys: _ayahKeys,
//                 ),

//           SizedBox(height: _selStart != null ? 120.h : 40.h),
//         ],
//       ),
//     );
//   }

//   Widget _buildAudioBar(Sheikh sheikh) {
//     final from = _selStart!;
//     final to = _selEnd ?? _selStart!;
//     final range = from == to ? 'الآية $from' : 'من $from إلى $to';

//     return Positioned(
//       bottom: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         padding: EdgeInsets.only(
//           left: 16.w,
//           right: 16.w,
//           top: 12.h,
//           bottom:
//               MediaQuery.of(context).padding.bottom + 12.h, // إضافة safe area
//         ),
//         decoration: BoxDecoration(
//           color: AppColors.mushafPaper,
//           border: Border(
//             top: BorderSide(color: AppColors.mushafBorder, width: 1),
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.1),
//               blurRadius: 8,
//               offset: const Offset(0, -2),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             // زر التشغيل/الإيقاف
//             GestureDetector(
//               onTap: _isPlaying ? _stopPlayback : _playSelection,
//               child: Container(
//                 width: 48.w,
//                 height: 48.w,
//                 decoration: BoxDecoration(
//                   color: AppColors.goldWarm,
//                   shape: BoxShape.circle,
//                 ),
//                 child: _isLoadingAudio
//                     ? Padding(
//                         padding: EdgeInsets.all(12.w),
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           valueColor: AlwaysStoppedAnimation(
//                             AppColors.mushafPaper,
//                           ),
//                         ),
//                       )
//                     : Icon(
//                         _isPlaying
//                             ? Icons.stop_rounded
//                             : Icons.play_arrow_rounded,
//                         color: AppColors.mushafPaper,
//                         size: 28.sp,
//                       ),
//               ),
//             ),
//             SizedBox(width: 12.w),
//             // المعلومات
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     range,
//                     style: TextStyle(
//                       fontFamily: 'Tajawal',
//                       fontSize: 14.sp,
//                       fontWeight: FontWeight.bold,
//                       color: AppColors.mushafInk,
//                     ),
//                   ),
//                   Text(
//                     sheikh.name,
//                     style: TextStyle(
//                       fontFamily: 'Tajawal',
//                       fontSize: 11.sp,
//                       color: AppColors.textDim,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             // زر التكرار
//             GestureDetector(
//               onTap: () => setState(() => _repeatEnabled = !_repeatEnabled),
//               child: Container(
//                 padding: EdgeInsets.all(8.w),
//                 decoration: BoxDecoration(
//                   color: _repeatEnabled
//                       ? AppColors.goldWarm.withValues(alpha: 0.2)
//                       : Colors.transparent,
//                   borderRadius: BorderRadius.circular(8.r),
//                 ),
//                 child: Icon(
//                   Icons.repeat_rounded,
//                   color: _repeatEnabled
//                       ? AppColors.goldWarm
//                       : AppColors.textDim,
//                   size: 20.sp,
//                 ),
//               ),
//             ),
//             SizedBox(width: 8.w),
//             // زر الإغلاق
//             GestureDetector(
//               onTap: _clearSelection,
//               child: Icon(
//                 Icons.close_rounded,
//                 color: AppColors.textDim,
//                 size: 20.sp,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showSheikhPicker(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: AppColors.mushafPaper,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
//       ),
//       builder: (_) => _SheikhPickerSheet(),
//     );
//   }

//   String _toArabicNumber(int number) {
//     const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
//     return number
//         .toString()
//         .split('')
//         .map((d) => arabicDigits[int.parse(d)])
//         .join();
//   }
// }

// // ════════════════════════════════════════════════════════════════
// //  _SheikhPickerSheet — نافذة اختيار الشيخ
// // ════════════════════════════════════════════════════════════════
// class _SheikhPickerSheet extends ConsumerWidget {
//   const _SheikhPickerSheet();

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final current = ref.watch(settingsProvider).sheikId;

//     return Container(
//       constraints: BoxConstraints(
//         maxHeight: MediaQuery.of(context).size.height * 0.65,
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // ── المقبض العلوي ──
//           Padding(
//             padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
//             child: Container(
//               width: 40.w,
//               height: 4.h,
//               decoration: BoxDecoration(
//                 color: AppColors.goldWarm.withValues(alpha: 0.3),
//                 borderRadius: BorderRadius.circular(2.r),
//               ),
//             ),
//           ),

//           // ── العنوان ──
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'اختر القارئ',
//                   style: TextStyle(
//                     fontFamily: 'Tajawal',
//                     fontSize: 18.sp,
//                     fontWeight: FontWeight.bold,
//                     color: AppColors.mushafInk,
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: () => Navigator.pop(context),
//                   child: Container(
//                     padding: EdgeInsets.all(6.r),
//                     decoration: BoxDecoration(
//                       color: AppColors.goldWarm.withValues(alpha: 0.1),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(
//                       Icons.close,
//                       color: AppColors.textDim,
//                       size: 18.sp,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           Divider(color: AppColors.mushafBorder, height: 1, thickness: 1),

//           // ── قائمة القراء ──
//           Flexible(
//             child: ListView.builder(
//               shrinkWrap: true,
//               padding: EdgeInsets.only(
//                 top: 8.h,
//                 bottom: MediaQuery.of(context).padding.bottom + 16.h,
//               ),
//               itemCount: kSheikhs.length,
//               itemBuilder: (context, index) {
//                 final sheikh = kSheikhs[index];
//                 final selected = sheikh.id == current;

//                 return InkWell(
//                   onTap: () {
//                     ref.read(settingsProvider.notifier).setSheikh(sheikh.id);
//                     Navigator.pop(context);
//                   },
//                   child: Container(
//                     padding: EdgeInsets.symmetric(
//                       horizontal: 20.w,
//                       vertical: 14.h,
//                     ),
//                     decoration: BoxDecoration(
//                       color: selected
//                           ? AppColors.goldWarm.withValues(alpha: 0.15)
//                           : Colors.transparent,
//                       border: Border(
//                         bottom: BorderSide(
//                           color: AppColors.mushafBorder.withValues(alpha: 0.3),
//                           width: 0.5,
//                         ),
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         // أيقونة
//                         Container(
//                           width: 36.r,
//                           height: 36.r,
//                           decoration: BoxDecoration(
//                             color: selected
//                                 ? AppColors.goldWarm.withValues(alpha: 0.2)
//                                 : AppColors.goldWarm.withValues(alpha: 0.05),
//                             shape: BoxShape.circle,
//                           ),
//                           child: Icon(
//                             Icons.record_voice_over_rounded,
//                             color: selected
//                                 ? AppColors.goldWarm
//                                 : AppColors.textDim,
//                             size: 18.sp,
//                           ),
//                         ),
//                         SizedBox(width: 12.w),

//                         // النص
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 sheikh.name,
//                                 textDirection: TextDirection.rtl,
//                                 style: TextStyle(
//                                   fontFamily: 'Tajawal',
//                                   fontSize: 14.sp,
//                                   fontWeight: selected
//                                       ? FontWeight.bold
//                                       : FontWeight.w600,
//                                   color: selected
//                                       ? AppColors.goldWarm
//                                       : AppColors.mushafInk,
//                                 ),
//                               ),
//                               SizedBox(height: 2.h),
//                               Text(
//                                 sheikh.style,
//                                 textDirection: TextDirection.rtl,
//                                 style: TextStyle(
//                                   fontFamily: 'Tajawal',
//                                   fontSize: 11.sp,
//                                   color: AppColors.textDim,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),

//                         // علامة الاختيار
//                         if (selected)
//                           Icon(
//                             Icons.check_circle_rounded,
//                             color: AppColors.goldWarm,
//                             size: 22.sp,
//                           ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
