import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/dua_tracking_service.dart';
import '../providers/azkar_provider.dart';
import '../providers/favorites_provider.dart';
import '../../laylat_qadr/screens/laylat_qadr_screen.dart';
import '../../home/providers/features_provider.dart';
import '../../home/providers/date_provider.dart';

// ════════════════════════════════════════════════════════════════
//  DuaHomeScreen — شاشة الأدعية
//  مطابق لـ HTML: .dua-bg
// ════════════════════════════════════════════════════════════════

class DuaHomeScreen extends ConsumerStatefulWidget {
  const DuaHomeScreen({super.key});

  @override
  ConsumerState<DuaHomeScreen> createState() => _DuaHomeScreenState();
}

class _DuaHomeScreenState extends ConsumerState<DuaHomeScreen> {
  String? _selectedCat; // null = الكل
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // أيقونات الفئات المعروفة
  static const _icons = <String, String>{
    'أذكار الصباح': '🌅',
    'أذكار المساء': '🌙',
    'دعاء الهم والحزن': '🤲',
    'دعاء الكرب': '🤲',
    'دعاء النوم': '😴',
    'دعاء السفر': '✈️',
    'دعاء الطعام': '🍽️',
    'دعاء الصلاة': '🕌',
    'دعاء المرض': '❤️‍🩹',
    'دعاء الاستخارة': '🤲',
    'دعاء دخول المسجد': '🕌',
    'دعاء دخول المنزل': '🏠',
    'دعاء رؤية الهلال': '🌙',
    'الدعاء عند إفطار الصائم': '🌙',
    'دعاء الريح': '🤲',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _iconFor(String cat) {
    for (final key in _icons.keys) {
      if (cat.contains(key.replaceAll('دعاء ', '').replaceAll('أذكار ', ''))) {
        return _icons[key]!;
      }
    }
    return '📿';
  }

  @override
  Widget build(BuildContext context) {
    final azkarState = ref.watch(azkarProvider);
    final duas = ref.watch(duasProvider);
    final categories = duas.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ────────────────────────────────────────────
            _DuaAppBar(onBack: () => Navigator.of(context).pop()),

            // ── شريط البحث ────────────────────────────────────────
            _SearchBar(
              controller: _searchCtrl,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),

            // ── تبويبات الفئات ────────────────────────────────────
            if (!azkarState.isLoading && duas.isNotEmpty)
              _CategoryPills(
                categories: categories,
                selected: _selectedCat,
                iconFor: _iconFor,
                onSelect: (cat) => setState(
                  () => _selectedCat = _selectedCat == cat ? null : cat,
                ),
              ),

            // ── القائمة الرئيسية ──────────────────────────────────
            Expanded(
              child: azkarState.isLoading
                  ? const _LoadingWidget()
                  : azkarState.error != null
                  ? _ErrorWidget(error: azkarState.error!)
                  : _DuaList(
                      duas: duas,
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

// ════════════════════════════════════════════════════════════════
//  AppBar
// ════════════════════════════════════════════════════════════════
class _DuaAppBar extends ConsumerWidget {
  const _DuaAppBar({required this.onBack});
  final VoidCallback onBack;

  void _showLaylatQadrDisabledMessage(BuildContext context, int hijriMonth) {
    String message;
    String emoji;

    if (hijriMonth == 9) {
      message = 'الميزة غير متاحة حالياً';
      emoji = '🔒';
    } else if (hijriMonth > 9) {
      message = 'انتهى رمضان، انتظر العام القادم ';
      emoji = '🌙';
    } else {
      message = 'قريباً في رمضان 🌙';
      emoji = '⏳';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: BorderSide(
            color: AppColors.goldWarm.withValues(alpha: 0.30),
            width: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 48.sp)),
            SizedBox(height: 16.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'حسناً',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 14.sp,
                color: AppColors.goldWarm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laylatQadrEnabled = ref.watch(
      featuresProvider.select((s) => s.laylatQadrEnabled),
    );
    final hijriMonth = ref.watch(dateProvider.select((s) => s.hijriMonth));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        children: [
          Row(
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
              Text(
                'الأدعية',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.agedPlaster,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.menu_book_rounded,
                color: AppColors.goldWarm,
                size: 18.sp,
              ),
            ],
          ),

          // Laylat Al-Qadr button (always visible, disabled when closed)
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () {
              if (laylatQadrEnabled) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LaylatQadrScreen()),
                );
              } else {
                _showLaylatQadrDisabledMessage(context, hijriMonth);
              }
            },
            child: Stack(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF221A40), Color(0xFF1C1535)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🌙', style: TextStyle(fontSize: 18.sp)),
                      SizedBox(width: 8.w),
                      Text(
                        'ليلة القدر',
                        style: TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldLight,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '• العشر الأواخر',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.sp,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                // Disabled overlay (matches home screen behavior)
                if (!laylatQadrEnabled)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
            hintText: 'ابحث في الأدعية...',
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
//  حبوب الفئات
// ════════════════════════════════════════════════════════════════
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
                    // اختصار الاسم إذا كان طويلاً
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

// ════════════════════════════════════════════════════════════════
//  قائمة الأدعية المجمّعة
// ════════════════════════════════════════════════════════════════
class _DuaList extends StatelessWidget {
  const _DuaList({
    required this.duas,
    required this.selectedCat,
    required this.searchQuery,
    required this.iconFor,
  });
  final Map<String, List<Zekr>> duas;
  final String? selectedCat;
  final String searchQuery;
  final String Function(String) iconFor;

  @override
  Widget build(BuildContext context) {
    // تصفية حسب الفئة أو البحث
    final filtered = <String, List<Zekr>>{};
    for (final entry in duas.entries) {
      if (selectedCat != null && entry.key != selectedCat) continue;
      final items = entry.value.where((z) {
        if (searchQuery.isEmpty) return true;
        return z.zekr.contains(searchQuery) ||
            z.description.contains(searchQuery) ||
            z.category.contains(searchQuery);
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
            // ─ عنوان الفئة ─────────────────────────────────────
            _SectionLabel(category: cat, icon: iconFor(cat)),
            // ─ بطاقات الأدعية ─────────────────────────────────
            ...items.map((dua) => _DuaCard(dua: dua)),
            SizedBox(height: 6.h),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  عنوان القسم — .ath-section-label
// ════════════════════════════════════════════════════════════════
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
          // خط قصير
          Container(width: 10.w, height: 1, color: AppColors.goldWarm),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  بطاقة الدعاء — .dua-card
// ════════════════════════════════════════════════════════════════
class _DuaCard extends ConsumerStatefulWidget {
  const _DuaCard({required this.dua});
  final Zekr dua;

  @override
  ConsumerState<_DuaCard> createState() => _DuaCardState();
}

class _DuaCardState extends ConsumerState<_DuaCard> {
  bool _expanded = false;

  // إنشاء ID فريد للدعاء (category + zekr)
  String get _duaId => '${widget.dua.category}_${widget.dua.zekr.hashCode}';

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.dua.zekr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الدعاء',
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
    final dua = widget.dua;
    final favoritesNotifier = ref.read(duaFavoritesProvider.notifier);
    final isFavorite = ref.watch(duaFavoritesProvider).contains(_duaId);

    // إذا كان النص طويلاً → اعرض مختصراً
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
              // ── نص الدعاء ────────────────────────────────────
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

              // ── المزيد / أقل ─────────────────────────────────
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

              // ── Footer ────────────────────────────────────────
              Container(
                padding: EdgeInsets.only(top: 8.h),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.goldWarm.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─ صف الأزرار ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // ─ زر النسخ ───────────────────────────
                        Expanded(
                          child: GestureDetector(
                            onTap: _copy,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              decoration: BoxDecoration(
                                color: AppColors.goldWarm.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: AppColors.goldWarm.withValues(
                                    alpha: 0.30,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 16.sp,
                                    color: AppColors.goldWarm,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'نسخ',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12.sp,
                                      color: AppColors.goldLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 8.w),

                        // ─ زر المفضلة ─────────────────────────
                        Expanded(
                          child: GestureDetector(
                            onTap: () => favoritesNotifier.toggle(_duaId),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              decoration: BoxDecoration(
                                color: isFavorite
                                    ? Colors.redAccent.withValues(alpha: 0.15)
                                    : AppColors.goldWarm.withValues(
                                        alpha: 0.08,
                                      ),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: isFavorite
                                      ? Colors.redAccent.withValues(alpha: 0.50)
                                      : AppColors.goldWarm.withValues(
                                          alpha: 0.30,
                                        ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 16.sp,
                                    color: isFavorite
                                        ? Colors.redAccent
                                        : AppColors.goldWarm,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    isFavorite ? 'محفوظ' : 'حفظ',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12.sp,
                                      color: isFavorite
                                          ? Colors.redAccent
                                          : AppColors.goldLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 8.w),

                        // ─ زر "قرأت" ─────────────────────────
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              DuaTrackingService.recordDuaRead(_duaId);
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
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              decoration: BoxDecoration(
                                color: AppColors.goldWarm.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: AppColors.goldWarm.withValues(
                                    alpha: 0.40,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16.sp,
                                    color: AppColors.goldLight,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'قرأت',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12.sp,
                                      color: AppColors.goldLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ─ المصدر ─────────────────────────────────
                    if (dua.reference.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.goldWarm.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: AppColors.goldWarm.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 12.sp,
                              color: AppColors.goldWarm,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              dua.reference,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11.sp,
                                color: AppColors.goldWarm,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
//  زر في بطاقة الدعاء — .dua-btn
// ════════════════════════════════════════════════════════════════
class _DuaBtn extends StatelessWidget {
  const _DuaBtn({required this.icon, required this.onTap, this.color});
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
//  حالات التحميل/خطأ
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
            'جاري تحميل الأدعية...',
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
