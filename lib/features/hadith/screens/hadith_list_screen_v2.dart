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
//  HadithListScreenV2 — عرض الأحاديث مجمعة حسب الأبواب
//  Scroll عمودي بين الأبواب + Scroll أفقي داخل كل باب
// ════════════════════════════════════════════════════════════════

class HadithListScreenV2 extends ConsumerStatefulWidget {
  const HadithListScreenV2({super.key, required this.collection});
  final HadithCollection collection;

  @override
  ConsumerState<HadithListScreenV2> createState() => _HadithListScreenV2State();
}

class _HadithListScreenV2State extends ConsumerState<HadithListScreenV2> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  // الأحاديث مجمعة حسب الباب
  Map<String, List<Hadith>> _groupedHadiths = {};
  Map<String, List<Hadith>> _filteredGroupedHadiths = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCollection();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCollection() async {
    try {
      await ref.read(hadithProvider.notifier).loadCollection(widget.collection.id);
      if (mounted) {
        await Future.delayed(Duration.zero);
        if (mounted) {
          setState(() {
            _groupHadiths();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading collection: $e');
    }
  }

  void _groupHadiths() {
    final hadithState = ref.read(hadithProvider);
    final allHadiths = hadithState.hadiths;

    _groupedHadiths.clear();

    for (final hadith in allHadiths) {
      final chapterName = widget.collection.translateChapter(hadith.chapter);
      final key = chapterName.isNotEmpty ? chapterName : 'أحاديث متنوعة';
      
      if (!_groupedHadiths.containsKey(key)) {
        _groupedHadiths[key] = [];
      }
      _groupedHadiths[key]!.add(hadith);
    }

    _applyFilter();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
          _applyFilter();
        });
      }
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredGroupedHadiths = Map.from(_groupedHadiths);
    } else {
      _filteredGroupedHadiths.clear();
      
      for (final entry in _groupedHadiths.entries) {
        final filtered = entry.value.where((h) {
          final textMatch = h.text.contains(_searchQuery);
          final chapterMatch = entry.key.contains(_searchQuery);
          return textMatch || chapterMatch;
        }).toList();

        if (filtered.isNotEmpty) {
          _filteredGroupedHadiths[entry.key] = filtered;
        }
      }
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
            _HadithListAppBar(
              title: widget.collection.arabicName,
              onBack: () => Navigator.of(context).pop(),
            ),
            _SearchBar(controller: _searchCtrl, onChanged: _onSearchChanged),
            Expanded(
              child: hadithState.isLoading && _groupedHadiths.isEmpty
                  ? const _LoadingWidget()
                  : hadithState.error != null
                  ? _ErrorWidget(error: hadithState.error!)
                  : _filteredGroupedHadiths.isEmpty
                  ? const _EmptyWidget()
                  : _ChaptersList(
                      groupedHadiths: _filteredGroupedHadiths,
                      collection: widget.collection,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  قائمة الأبواب (Scroll عمودي)
// ════════════════════════════════════════════════════════════════
class _ChaptersList extends StatelessWidget {
  const _ChaptersList({
    required this.groupedHadiths,
    required this.collection,
  });
  final Map<String, List<Hadith>> groupedHadiths;
  final HadithCollection collection;

  @override
  Widget build(BuildContext context) {
    final chapters = groupedHadiths.keys.toList();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapterName = chapters[index];
        final hadiths = groupedHadiths[chapterName]!;

        return _ChapterSection(
          chapterName: chapterName,
          hadiths: hadiths,
          collection: collection,
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  قسم الباب (عنوان + أحاديث أفقية)
// ════════════════════════════════════════════════════════════════
class _ChapterSection extends StatefulWidget {
  const _ChapterSection({
    required this.chapterName,
    required this.hadiths,
    required this.collection,
  });
  final String chapterName;
  final List<Hadith> hadiths;
  final HadithCollection collection;

  @override
  State<_ChapterSection> createState() => _ChapterSectionState();
}

class _ChapterSectionState extends State<_ChapterSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── عنوان الباب ──────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.goldWarm.withValues(alpha: 0.20),
                      AppColors.goldWarm.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: AppColors.goldWarm.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.goldWarm,
                      size: 16.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      widget.chapterName,
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.goldLight,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.goldWarm.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  '${widget.hadiths.length} حديث',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.sp,
                    color: AppColors.goldLight,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── الأحاديث أفقياً ────────────────────────────────────
        SizedBox(
          height: 280.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.hadiths.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: _HadithCard(
                  hadith: widget.hadiths[index],
                  collection: widget.collection,
                ),
              );
            },
          ),
        ),

        // ── مؤشر الموضع ────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'حديث ${_currentPage + 1} من ${widget.hadiths.length}',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.sp,
                  color: AppColors.textDim,
                ),
              ),
              SizedBox(width: 12.w),
              // نقاط المؤشر
              if (widget.hadiths.length <= 10)
                Row(
                  children: List.generate(
                    widget.hadiths.length,
                    (index) => Container(
                      width: 6.w,
                      height: 6.w,
                      margin: EdgeInsets.symmetric(horizontal: 2.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentPage
                            ? AppColors.goldWarm
                            : AppColors.goldWarm.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── خط فاصل ────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.goldWarm.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
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
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.agedPlaster),
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

    const maxChars = 250; // ← زيادة عدد الأحرف لعرض 3 أسطر
    final isLong = hadith.text.length > maxChars;
    final displayText = isLong
        ? '${hadith.text.substring(0, maxChars)}...'
        : hadith.text;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221A40), Color(0xFF1C1535)],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── رقم الحديث (في اليمين) ────────────────────────
            Align(
              alignment: Alignment.centerRight, // ← محاذاة لليمين
              child: Container(
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
            ),
            SizedBox(height: 16.h), // ← مسافة أكبر

            // ── نص الحديث ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  displayText,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 13.sp,
                    height: 2.2, // ← مسافة أكبر بين الأسطر
                    color: AppColors.agedPlaster,
                  ),
                ),
              ),
            ),

            // ── زر المزيد ─────────────────────────────────────
            if (isLong) ...[
              SizedBox(height: 10.h),
              GestureDetector(
                onTap: () => _openDetail(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
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

            SizedBox(height: 10.h),

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
                  _HadithBtn(
                    icon: Icons.copy_rounded,
                    onTap: () => _copy(context),
                  ),
                  SizedBox(width: 6.w),
                  _HadithBtn(
                    icon: isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    onTap: () => favNotifier.toggle(_hadithId),
                    color: isFavorite ? Colors.redAccent : null,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.swipe_rounded,
                    color: AppColors.textDim,
                    size: 16.sp,
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
