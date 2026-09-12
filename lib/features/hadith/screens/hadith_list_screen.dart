import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../models/hadith_collection.dart';
import '../providers/hadith_provider.dart';
import '../providers/hadith_favorites_provider.dart';
import 'hadith_detail_screen.dart';

// ════════════════════════════════════════════════════════════════
//  HadithListScreen — قائمة الأحاديث مع Pagination و Search
// ════════════════════════════════════════════════════════════════

class HadithListScreen extends ConsumerStatefulWidget {
  const HadithListScreen({super.key, required this.collection});
  final HadithCollection collection;

  @override
  ConsumerState<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends ConsumerState<HadithListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _searchQuery = '';
  Timer? _debounce;

  // Pagination
  static const int _itemsPerPage = 20;
  int _currentPage = 0;
  List<Hadith> _filteredHadiths = [];
  final List<Hadith> _displayedHadiths = [];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    // Load collection after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCollection();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCollection() async {
    try {
      debugPrint('🚀 _loadCollection: Starting for ${widget.collection.id}');
      await ref
          .read(hadithProvider.notifier)
          .loadCollection(widget.collection.id);
      // Wait a frame to ensure state is updated
      if (mounted) {
        await Future.delayed(Duration.zero);
        if (mounted) {
          debugPrint('🔄 _loadCollection: Calling _applyFilter');
          setState(() {
            _applyFilter();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _loadCollection: $e');
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onSearchChanged(String query) {
    // Debounce 300ms
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
          _currentPage = 0;
          _applyFilter();
        });
      }
    });
  }

  void _applyFilter() {
    final hadithState = ref.read(hadithProvider);
    final allHadiths = hadithState.hadiths;

    debugPrint(
      '🔍 _applyFilter called: ${allHadiths.length} hadiths available, isLoading: ${hadithState.isLoading}, error: ${hadithState.error}',
    );

    if (_searchQuery.isEmpty) {
      _filteredHadiths = allHadiths;
    } else {
      _filteredHadiths = allHadiths.where((h) {
        // البحث في نص الحديث
        final textMatch = h.text.contains(_searchQuery);
        
        // البحث في عنوان الباب الأصلي (الإنجليزي)
        final chapterOriginalMatch = h.chapter?.contains(_searchQuery) ?? false;
        
        // البحث في عنوان الباب المترجم (العربي)
        final chapterTranslatedMatch = 
            widget.collection.translateChapter(h.chapter).contains(_searchQuery);
        
        return textMatch || chapterOriginalMatch || chapterTranslatedMatch;
      }).toList();
    }

    debugPrint('📊 Filtered: ${_filteredHadiths.length} hadiths');
    _loadMore(reset: true);
  }

  void _loadMore({bool reset = false}) {
    if (reset) {
      _currentPage = 0;
      _displayedHadiths.clear();
    }

    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _filteredHadiths.length);

    debugPrint(
      '📄 _loadMore: page=$_currentPage, start=$start, end=$end, total=${_filteredHadiths.length}',
    );

    if (start < _filteredHadiths.length) {
      setState(() {
        _displayedHadiths.addAll(_filteredHadiths.sublist(start, end));
        _currentPage++;
      });
      debugPrint('✅ Now displaying ${_displayedHadiths.length} hadiths');
    } else {
      debugPrint('⚠️ No more hadiths to load');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hadithState = ref.watch(hadithProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ────────────────────────────────────────────
            _HadithListAppBar(
              title: widget.collection.arabicName,
              onBack: () => Navigator.of(context).pop(),
            ),

            // ── شريط البحث ────────────────────────────────────────
            _SearchBar(controller: _searchCtrl, onChanged: _onSearchChanged),

            // ── القائمة ───────────────────────────────────────────
            Expanded(
              child: hadithState.isLoading && _displayedHadiths.isEmpty
                  ? const _LoadingWidget()
                  : hadithState.error != null
                  ? _ErrorWidget(error: hadithState.error!)
                  : _displayedHadiths.isEmpty
                  ? const _EmptyWidget()
                  : _HadithList(
                      hadiths: _displayedHadiths,
                      hasMore:
                          _displayedHadiths.length < _filteredHadiths.length,
                      collection: widget.collection,
                      scrollController: _scrollCtrl,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  AppBar
// ════════════════════════════════════════════════════════════════
class _HadithListAppBar extends StatelessWidget {
  const _HadithListAppBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderGold),
                color: AppColors.goldWarm.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.goldLight,
                size: 14.sp,
              ),
            ),
          ),
          const Spacer(),
          Expanded(
            flex: 3,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.agedPlaster,
              ),
            ),
          ),
          const Spacer(),
          Icon(Icons.menu_book_rounded, color: AppColors.goldWarm, size: 18.sp),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  شريط البحث
// ════════════════════════════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Container(
        height: 40.h,
        decoration: BoxDecoration(
          color: AppColors.goldWarm.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.18)),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.agedPlaster,
            fontSize: 13.sp,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث في الأحاديث...',
            hintTextDirection: TextDirection.rtl,
            hintStyle: TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textDim,
              fontSize: 12.sp,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.textDim,
              size: 18.sp,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10.h),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  قائمة الأحاديث
// ════════════════════════════════════════════════════════════════
class _HadithList extends StatelessWidget {
  const _HadithList({
    required this.hadiths,
    required this.hasMore,
    required this.collection,
    required this.scrollController,
  });
  final List<Hadith> hadiths;
  final bool hasMore;
  final HadithCollection collection;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      itemCount: hadiths.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == hadiths.length) {
          // Loading indicator for pagination
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Center(
              child: SizedBox(
                width: 24.w,
                height: 24.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.goldWarm,
                ),
              ),
            ),
          );
        }

        return _HadithCard(hadith: hadiths[index], collection: collection);
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  بطاقة الحديث
// ════════════════════════════════════════════════════════════════
class _HadithCard extends ConsumerWidget {
  const _HadithCard({required this.hadith, required this.collection});
  final Hadith hadith;
  final HadithCollection collection;

  String get _hadithId => '${collection.id}_${hadith.number}';

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: hadith.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الحديث',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.agedPlaster,
          ),
        ),
        backgroundColor: const Color(0xFF1A1535),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.4)),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HadithDetailScreen(
          hadith: hadith,
          collection: collection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(hadithFavoritesProvider).contains(_hadithId);
    final favNotifier = ref.read(hadithFavoritesProvider.notifier);

    // إذا كان النص طويلاً → اعرض مختصراً
    const maxChars = 200;
    final isLong = hadith.text.length > maxChars;
    final displayText = isLong
        ? '${hadith.text.substring(0, maxChars)}...'
        : hadith.text;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221A40), Color(0xFF1C1535)],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── رقم الحديث ────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.goldWarm.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'حديث رقم ${hadith.arabicNumber}',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10.sp,
                  color: AppColors.goldLight,
                ),
              ),
            ),
            SizedBox(height: 8.h),

            // ── نص الحديث ─────────────────────────────────────
            Text(
              displayText,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 14.sp,
                height: 2.0,
                color: AppColors.agedPlaster,
              ),
            ),

            // ── زر المزيد ─────────────────────────────────────
            if (isLong) ...[
              SizedBox(height: 6.h),
              GestureDetector(
                onTap: () => _openDetail(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldWarm.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'اقرأ المزيد',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldWarm,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_back_ios,
                        size: 10.sp,
                        color: AppColors.goldWarm,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: 8.h),

            // ── Footer ─────────────────────────────────────────
            Container(
              padding: EdgeInsets.only(top: 8.h),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.goldWarm.withValues(alpha: 0.10),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // ─ زر النسخ ────────────────────────────────
                  _HadithBtn(
                    icon: Icons.copy_rounded,
                    onTap: () => _copy(context),
                  ),
                  SizedBox(width: 6.w),
                  // ─ زر المفضلة ──────────────────────────────
                  _HadithBtn(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    onTap: () => favNotifier.toggle(_hadithId),
                    color: isFavorite ? Colors.redAccent : null,
                  ),

                  const Spacer(),

                  // ─ الباب ──────────────────────────────────
                  if (hadith.chapter != null && hadith.chapter!.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.only(right: 7.w),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: AppColors.goldWarm,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          collection.translateChapter(hadith.chapter),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.sp,
                            color: AppColors.goldWarm,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  زر في بطاقة الحديث
// ════════════════════════════════════════════════════════════════
class _HadithBtn extends StatelessWidget {
  const _HadithBtn({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.goldWarm.withValues(alpha: 0.05),
          border: Border.all(
            color: (color ?? AppColors.goldWarm).withValues(alpha: 0.30),
          ),
        ),
        child: Icon(icon, size: 13.sp, color: color ?? AppColors.goldWarm),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  حالات التحميل/خطأ/فارغ
// ════════════════════════════════════════════════════════════════
class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32.w,
            height: 32.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.goldWarm,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'جاري تحميل الأحاديث...',
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textDim,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'خطأ في تحميل البيانات',
        style: TextStyle(
          fontFamily: 'Tajawal',
          color: AppColors.textDim,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  const _EmptyWidget();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔍', style: TextStyle(fontSize: 32.sp)),
          SizedBox(height: 12.h),
          Text(
            'لا توجد نتائج',
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textDim,
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }
}
