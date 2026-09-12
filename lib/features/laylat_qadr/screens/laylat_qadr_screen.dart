import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/dua_tracking_service.dart'; // ← جديد
import '../providers/laylat_qadr_provider.dart';
import '../../dua/providers/favorites_provider.dart';

// ════════════════════════════════════════════════════════════════
//  LaylatQadrScreen — شاشة ليلة القدر
// ════════════════════════════════════════════════════════════════

class LaylatQadrScreen extends ConsumerStatefulWidget {
  const LaylatQadrScreen({super.key});

  @override
  ConsumerState<LaylatQadrScreen> createState() => _LaylatQadrScreenState();
}

class _LaylatQadrScreenState extends ConsumerState<LaylatQadrScreen> {
  String? _selectedCat;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  static const _icons = <String, String>{
    'أدعية ليلة القدر': '',
    'فضل ليلة القدر': '',
    'أدعية نبوية': '',
    'أدعية من القرآن': '',
    'أعمال ليلة القدر': '',
    'علامات ليلة القدر': '',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _iconFor(String cat) {
    for (final key in _icons.keys) {
      if (cat.contains(key)) return _icons[key]!;
    }
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(laylatQadrProvider);
    final content = ref.watch(laylatQadrContentProvider);
    final categories = content.keys.toList();

    // Debug: طباعة الحالة
    print(
      '🔍 LaylatQadr State - isLoading: ${state.isLoading}, error: ${state.error}',
    );
    print('🔍 Content categories: ${categories.length}');
    print(
      '🔍 Total items: ${content.values.fold(0, (sum, list) => sum + list.length)}',
    );

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(onBack: () => Navigator.of(context).pop()),

            // سورة القدر
            const _SurahAlQadr(),

            _SearchBar(
              controller: _searchCtrl,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
            if (!state.isLoading && content.isNotEmpty)
              _CategoryPills(
                categories: categories,
                selected: _selectedCat,
                iconFor: _iconFor,
                onSelect: (cat) => setState(
                  () => _selectedCat = _selectedCat == cat ? null : cat,
                ),
              ),
            Expanded(
              child: state.isLoading
                  ? const _LoadingWidget()
                  : state.error != null
                  ? _ErrorWidget(error: state.error!)
                  : _ContentList(
                      content: content,
                      selectedCat: _selectedCat,
                      searchQuery: _searchQuery,
                      iconFor: _iconFor,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.onBack});
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
          ),
          const Spacer(),
          Text(
            'ليلة القدر',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.agedPlaster,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

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
            hintText: 'ابحث في أدعية ليلة القدر...',
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

class _CategoryPills extends StatelessWidget {
  const _CategoryPills({
    required this.categories,
    required this.selected,
    required this.iconFor,
    required this.onSelect,
  });
  final List<String> categories;
  final String? selected;
  final String Function(String) iconFor;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 6.w),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isActive = selected == cat;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.goldWarm.withValues(alpha: 0.20)
                    : AppColors.goldWarm.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isActive
                      ? AppColors.goldWarm
                      : AppColors.goldWarm.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(iconFor(cat), style: TextStyle(fontSize: 12.sp)),
                  SizedBox(width: 4.w),
                  Text(
                    cat.length > 20 ? '${cat.substring(0, 20)}...' : cat,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.sp,
                      color: isActive ? AppColors.goldLight : AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ContentList extends StatelessWidget {
  const _ContentList({
    required this.content,
    required this.selectedCat,
    required this.searchQuery,
    required this.iconFor,
  });
  final Map<String, List<LaylatQadrItem>> content;
  final String? selectedCat;
  final String searchQuery;
  final String Function(String) iconFor;

  @override
  Widget build(BuildContext context) {
    final filtered = <String, List<LaylatQadrItem>>{};
    for (final entry in content.entries) {
      if (selectedCat != null && entry.key != selectedCat) continue;
      final items = entry.value.where((item) {
        if (searchQuery.isEmpty) return true;
        return item.zekr.contains(searchQuery) ||
            item.description.contains(searchQuery) ||
            item.category.contains(searchQuery);
      }).toList();
      if (items.isNotEmpty) filtered[entry.key] = items;
    }

    if (filtered.isEmpty) {
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

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      itemCount: filtered.keys.length,
      itemBuilder: (_, catIdx) {
        final cat = filtered.keys.elementAt(catIdx);
        final items = filtered[cat]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SectionLabel(category: cat, icon: iconFor(cat)),
            ...items.map((item) => _ContentCard(item: item)),
            SizedBox(height: 6.h),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.category, required this.icon});
  final String category;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.goldWarm.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Text(icon, style: TextStyle(fontSize: 13.sp)),
          SizedBox(width: 4.w),
          Text(
            category.length > 24 ? '${category.substring(0, 24)}...' : category,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.sp,
              letterSpacing: 0.5,
              color: AppColors.goldWarm,
            ),
          ),
          SizedBox(width: 6.w),
          Container(width: 10.w, height: 1, color: AppColors.goldWarm),
        ],
      ),
    );
  }
}

class _ContentCard extends ConsumerStatefulWidget {
  const _ContentCard({required this.item});
  final LaylatQadrItem item;

  @override
  ConsumerState<_ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends ConsumerState<_ContentCard> {
  bool _expanded = false;

  // إنشاء ID فريد للعنصر (category + zekr)
  String get _itemId => '${widget.item.category}_${widget.item.zekr.hashCode}';

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.item.zekr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ النص',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final favoritesNotifier = ref.read(laylatQadrFavoritesProvider.notifier);
    final isFavorite = ref.watch(laylatQadrFavoritesProvider).contains(_itemId);

    const maxChars = 200;
    final isLong = item.zekr.length > maxChars;
    final displayText = _expanded || !isLong
        ? item.zekr
        : '${item.zekr.substring(0, maxChars)}...';

    return GestureDetector(
      onTap: isLong ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
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
              if (isLong) ...[
                SizedBox(height: 4.h),
                Text(
                  _expanded ? 'أقل ▲' : 'المزيد ▾',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.sp,
                    color: AppColors.goldWarm,
                  ),
                ),
              ],
              SizedBox(height: 8.h),
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
                    _Btn(icon: Icons.copy_rounded, onTap: _copy),
                    SizedBox(width: 5.w),
                    _Btn(
                      icon: isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      onTap: () => favoritesNotifier.toggle(_itemId),
                      color: isFavorite ? Colors.redAccent : null,
                    ),
                    SizedBox(width: 5.w),
                    // ─ زر "قرأت" ─────────────────────────────
                    GestureDetector(
                      onTap: () {
                        DuaTrackingService.recordDuaRead(_itemId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              '✅ تم تسجيل قراءة الدعاء',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppColors.textDim,
                              ),
                            ),
                            backgroundColor: const Color(0xFF1A1535),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: AppColors.goldWarm.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.goldWarm.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: AppColors.goldWarm.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'قرأت',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11.sp,
                            color: AppColors.goldLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (item.reference.isNotEmpty)
                      Container(
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
                          item.reference,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.sp,
                            color: AppColors.goldWarm,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.onTap, this.color});
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
            'جاري التحميل...',
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

// ════════════════════════════════════════════════════════════════
//  سورة القدر
// ════════════════════════════════════════════════════════════════
class _SurahAlQadr extends StatelessWidget {
  const _SurahAlQadr();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF2A1E4A), Color(0xFF1C1230)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.goldWarm.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldWarm.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // البسملة
          Text(
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.goldLight,
              height: 2.0,
            ),
          ),

          SizedBox(height: 12.h),

          // خط فاصل
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.goldWarm.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // آيات السورة مع الترقيم
          RichText(
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.agedPlaster,
                height: 2.2,
                shadows: [
                  Shadow(
                    color: AppColors.goldGlow.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              children: [
                const TextSpan(
                  text: 'إِنَّا أَنزَلْنَاهُ فِي لَيْلَةِ الْقَدْرِ ',
                ),
                WidgetSpan(
                  child: _AyahNumber(number: 1),
                  alignment: PlaceholderAlignment.middle,
                ),
                const TextSpan(
                  text: ' وَمَا أَدْرَاكَ مَا لَيْلَةُ الْقَدْرِ ',
                ),
                WidgetSpan(
                  child: _AyahNumber(number: 2),
                  alignment: PlaceholderAlignment.middle,
                ),
                const TextSpan(
                  text: ' لَيْلَةُ الْقَدْرِ خَيْرٌ مِّنْ أَلْفِ شَهْرٍ ',
                ),
                WidgetSpan(
                  child: _AyahNumber(number: 3),
                  alignment: PlaceholderAlignment.middle,
                ),
                const TextSpan(
                  text:
                      ' تَنَزَّلُ الْمَلَائِكَةُ وَالرُّوحُ فِيهَا بِإِذْنِ رَبِّهِم مِّن كُلِّ أَمْرٍ ',
                ),
                WidgetSpan(
                  child: _AyahNumber(number: 4),
                  alignment: PlaceholderAlignment.middle,
                ),
                const TextSpan(
                  text: ' سَلَامٌ هِيَ حَتَّىٰ مَطْلَعِ الْفَجْرِ ',
                ),
                WidgetSpan(
                  child: _AyahNumber(number: 5),
                  alignment: PlaceholderAlignment.middle,
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // خط فاصل
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.goldWarm.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // اسم السورة
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.goldWarm.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.goldWarm.withValues(alpha: 0.25),
              ),
            ),

            child: Container(
              child: Text(
                'سورة القدر',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.sp,
                  color: AppColors.goldWarm,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  رقم الآية
// ════════════════════════════════════════════════════════════════
class _AyahNumber extends StatelessWidget {
  const _AyahNumber({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 3.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.goldWarm.withValues(alpha: 0.15),
        border: Border.all(
          color: AppColors.goldWarm.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        _toArabicNumber(number),
        style: TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 12.sp,
          color: AppColors.goldLight,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _toArabicNumber(int number) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((d) => arabic[int.parse(d)]).join();
  }
}
