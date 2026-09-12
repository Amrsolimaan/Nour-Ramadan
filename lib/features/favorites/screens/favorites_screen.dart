import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../dua/providers/azkar_provider.dart';
import '../../dua/providers/favorites_provider.dart';
import '../../hadith/providers/hadith_favorites_provider.dart';
import '../../hadith/models/hadith_collection.dart';
import '../../hadith/providers/hadith_provider.dart';
import '../../laylat_qadr/providers/laylat_qadr_provider.dart';

// ════════════════════════════════════════════════════════════════
//  FavoritesScreen — صفحة المفضلات
// ════════════════════════════════════════════════════════════════

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _selectedTab = 'الكل';

  @override
  Widget build(BuildContext context) {
    final duaFavorites = ref.watch(duaFavoritesProvider);
    final laylatQadrFavorites = ref.watch(laylatQadrFavoritesProvider);
    final hadithFavorites = ref.watch(hadithFavoritesProvider);
    final totalCount =
        duaFavorites.length +
        laylatQadrFavorites.length +
        hadithFavorites.length;

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(totalCount: totalCount),
            _TabBar(
              selected: _selectedTab,
              onSelect: (tab) => setState(() => _selectedTab = tab),
              duaCount: duaFavorites.length,
              laylatQadrCount: laylatQadrFavorites.length,
              hadithCount: hadithFavorites.length,
            ),
            Expanded(
              child: totalCount == 0
                  ? const _EmptyState()
                  : _FavoritesList(
                      selectedTab: _selectedTab,
                      duaFavorites: duaFavorites,
                      laylatQadrFavorites: laylatQadrFavorites,
                      hadithFavorites: hadithFavorites,
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  AppBar
// ════════════════════════════════════════════════════════════════
class _AppBar extends StatelessWidget {
  const _AppBar({required this.totalCount});
  final int totalCount;

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
          // زر الرجوع
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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
          Text(
            'المفضلات',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.agedPlaster,
            ),
          ),
          SizedBox(width: 6.w),
          if (totalCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.goldWarm.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$totalCount',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.sp,
                  color: AppColors.goldWarm,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  TabBar
// ════════════════════════════════════════════════════════════════
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.selected,
    required this.onSelect,
    required this.duaCount,
    required this.laylatQadrCount,
    required this.hadithCount,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final int duaCount;
  final int laylatQadrCount;
  final int hadithCount;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('الكل', duaCount + laylatQadrCount + hadithCount),
      ('الأدعية', duaCount),
      ('ليلة القدر', laylatQadrCount),
      ('الأحاديث', hadithCount),
    ];

    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Row(
        children: tabs.map((tab) {
          final isActive = selected == tab.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(tab.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.goldWarm.withValues(alpha: 0.20)
                      : AppColors.goldWarm.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isActive
                        ? AppColors.goldWarm
                        : AppColors.goldWarm.withValues(alpha: 0.22),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tab.$1,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.sp,
                          color: isActive
                              ? AppColors.goldLight
                              : AppColors.textDim,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      if (tab.$2 > 0) ...[
                        SizedBox(width: 4.w),
                        Text(
                          '(${tab.$2})',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.sp,
                            color: isActive
                                ? AppColors.goldWarm
                                : AppColors.textDim,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  قائمة المفضلات
// ════════════════════════════════════════════════════════════════
class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({
    required this.selectedTab,
    required this.duaFavorites,
    required this.laylatQadrFavorites,
    required this.hadithFavorites,
  });

  final String selectedTab;
  final Set<String> duaFavorites;
  final Set<String> laylatQadrFavorites;
  final Set<String> hadithFavorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final azkarState = ref.watch(azkarProvider);
    final laylatQadrState = ref.watch(laylatQadrProvider);

    if (azkarState.isLoading || laylatQadrState.isLoading) {
      return const _LoadingWidget();
    }

    // جلب البيانات الكاملة
    final allDuas = ref.watch(azkarProvider).byCategory;
    final allLaylatQadr = ref.read(laylatQadrProvider.notifier).items;

    // تصفية المفضلات
    final duaItems = <Zekr>[];
    final laylatQadrItems = <LaylatQadrItem>[];

    // جمع الأدعية المفضلة
    if (selectedTab == 'الكل' || selectedTab == 'الأدعية') {
      for (final category in allDuas.values) {
        for (final dua in category) {
          final duaId = '${dua.category}_${dua.zekr.hashCode}';
          if (duaFavorites.contains(duaId)) {
            duaItems.add(dua);
          }
        }
      }
    }

    // جمع أدعية ليلة القدر المفضلة
    if (selectedTab == 'الكل' || selectedTab == 'ليلة القدر') {
      for (final item in allLaylatQadr) {
        final itemId = '${item.category}_${item.zekr.hashCode}';
        if (laylatQadrFavorites.contains(itemId)) {
          laylatQadrItems.add(item);
        }
      }
    }

    // ─ جمع الأحاديث المفضلة
    final hadithFavItems = <Hadith>[];
    if (selectedTab == 'الكل' || selectedTab == 'الأحاديث') {
      final hadithState = ref.watch(hadithProvider);
      for (final h in hadithState.hadiths) {
        // نحتاج collection name — نستخدم hadithFavorites IDs مباشرة
        if (hadithFavorites.any((id) => id.endsWith('_${h.number}'))) {
          hadithFavItems.add(h);
        }
      }
    }

    if (duaItems.isEmpty && laylatQadrItems.isEmpty && hadithFavItems.isEmpty) {
      return const _EmptyState();
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      children: [
        // قسم الأدعية
        if (duaItems.isNotEmpty) ...[
          _SectionLabel(
            category: 'الأدعية',
            icon: '📿',
            count: duaItems.length,
          ),
          ...duaItems.map((dua) => _DuaCard(dua: dua)),
          SizedBox(height: 12.h),
        ],

        // قسم ليلة القدر
        if (laylatQadrItems.isNotEmpty) ...[
          _SectionLabel(
            category: 'ليلة القدر',
            icon: '🌙',
            count: laylatQadrItems.length,
          ),
          ...laylatQadrItems.map((item) => _LaylatQadrCard(item: item)),
          SizedBox(height: 12.h),
        ],

        // قسم الأحاديث
        if (hadithFavItems.isNotEmpty) ...[
          _SectionLabel(
            category: 'الأحاديث',
            icon: '📖',
            count: hadithFavItems.length,
          ),
          ...hadithFavItems.map(
            (h) => _HadithFavCard(
              hadith: h,
              hadithId: hadithFavorites.firstWhere(
                (id) => id.endsWith('_${h.number}'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  عنوان القسم
// ════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.category,
    required this.icon,
    required this.count,
  });
  final String category;
  final String icon;
  final int count;

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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppColors.goldWarm.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10.sp,
                color: AppColors.goldWarm,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Text(icon, style: TextStyle(fontSize: 13.sp)),
          SizedBox(width: 4.w),
          Text(
            category,
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

// ════════════════════════════════════════════════════════════════
//  بطاقة الدعاء
// ════════════════════════════════════════════════════════════════
class _DuaCard extends ConsumerStatefulWidget {
  const _DuaCard({required this.dua});
  final Zekr dua;

  @override
  ConsumerState<_DuaCard> createState() => _DuaCardState();
}

class _DuaCardState extends ConsumerState<_DuaCard> {
  bool _expanded = false;

  String get _duaId => '${widget.dua.category}_${widget.dua.zekr.hashCode}';

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.dua.zekr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم نسخ الدعاء',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Tajawal'),
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
    final dua = widget.dua;
    final favoritesNotifier = ref.read(duaFavoritesProvider.notifier);
    final isFavorite = ref.watch(duaFavoritesProvider).contains(_duaId);

    const maxChars = 200;
    final isLong = dua.zekr.length > maxChars;
    final displayText = _expanded || !isLong
        ? dua.zekr
        : '${dua.zekr.substring(0, maxChars)}...';

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
                      onTap: () => favoritesNotifier.toggle(_duaId),
                      color: isFavorite ? Colors.redAccent : null,
                    ),
                    const Spacer(),
                    if (dua.reference.isNotEmpty)
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
                          dua.reference,
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

// ════════════════════════════════════════════════════════════════
//  بطاقة ليلة القدر
// ════════════════════════════════════════════════════════════════
class _LaylatQadrCard extends ConsumerStatefulWidget {
  const _LaylatQadrCard({required this.item});
  final LaylatQadrItem item;

  @override
  ConsumerState<_LaylatQadrCard> createState() => _LaylatQadrCardState();
}

class _LaylatQadrCardState extends ConsumerState<_LaylatQadrCard> {
  bool _expanded = false;

  String get _itemId => '${widget.item.category}_${widget.item.zekr.hashCode}';

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.item.zekr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم نسخ النص',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Tajawal'),
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

// ════════════════════════════════════════════════════════════════
//  بطاقة الحديث في المفضلات
// ════════════════════════════════════════════════════════════════
class _HadithFavCard extends ConsumerWidget {
  const _HadithFavCard({required this.hadith, required this.hadithId});
  final Hadith hadith;
  final String hadithId;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: hadith.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم نسخ الحديث',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Tajawal'),
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

  void _share() {
    Share.share(hadith.text, subject: 'حديث رقم ${hadith.arabicNumber}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            // رقم الحديث
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

            // نص الحديث
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

            SizedBox(height: 8.h),

            // أزرار
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
                  _Btn(icon: Icons.copy_rounded, onTap: () => _copy(context)),
                  SizedBox(width: 5.w),
                  _Btn(icon: Icons.share_rounded, onTap: _share),
                  SizedBox(width: 5.w),
                  _Btn(
                    icon: Icons.favorite_rounded,
                    onTap: () => ref
                        .read(hadithFavoritesProvider.notifier)
                        .toggle(hadithId),
                    color: Colors.redAccent,
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
//  زر في البطاقة
// ════════════════════════════════════════════════════════════════
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

// ════════════════════════════════════════════════════════════════
//  حالة فارغة
// ════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 64.sp,
            color: AppColors.textDim,
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد مفضلات بعد',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16.sp,
              color: AppColors.textDim,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'ابدأ بإضافة أدعيتك المفضلة من صفحة الأدعية',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13.sp,
              color: AppColors.textDim.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  حالة التحميل
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
