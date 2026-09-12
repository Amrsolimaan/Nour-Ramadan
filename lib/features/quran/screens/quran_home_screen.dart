import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nour_ramadan/core/data/juz_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/quran_service.dart';
import '../../../painting/cairo_street_painter.dart';
import '../../../shared/animations/reveal_animation.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../settings/providers/settings_provider.dart';
import 'surah_list_screen.dart';
import 'quran_reader_screen.dart';
import 'khatmah_tracking_screen.dart';
import '../../hifz/screens/hifz_dashboard_screen.dart';

import 'juz_view_screen_v2.dart';

// ════════════════════════════════════════════════════════════════
//  QuranHomeScreen — الصفحة الرئيسية لقسم القرآن
//  تبويبات: سور | أجزاء | آخر قراءة
//  + شريط الشيخ المختار حالياً
// ════════════════════════════════════════════════════════════════

class QuranHomeScreen extends ConsumerStatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  ConsumerState<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends ConsumerState<QuranHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sheikh = settings.sheikh;

    return Scaffold(
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
      backgroundColor: AppColors.nightDeep,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── خلفية ─────────────────────────────────────────────
          Positioned.fill(child: CairoStreetBackground(isNight: true)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    AppColors.nightDeep.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),

          // ── المحتوى ───────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ─ صف الهوية: العنوان + الشيخ فقط ──────────────────
                _buildIdentityRow(context, sheikh),

                SizedBox(height: 8.h),

                // ─ صف التنقّل: ختم القرآن | الحفظ ──────────────────
                _buildNavRow(context),

                SizedBox(height: 8.h),

                // ─ شريط التبويبات ─────────────────────────────────
                _buildTabBar(),

                // ─ محتوى التبويب ─────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      // تبويب السور
                      _buildSurahTab(),
                      // تبويب الأجزاء
                      _buildJuzTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── صف الهوية (back + العنوان + الشيخ) ───────────────────────────
  //  ملاحظة: زر الرجوع يبقى هنا عمداً — إنه من "chrome" التنقّل العام
  //  للشاشة، وليس مدخلاً لقسم دلالي كأزرار صف التنقّل (plan_hifz.md §9 #1).
  Widget _buildIdentityRow(BuildContext context, Sheikh sheikh) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
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
          // العنوان
          Text(
            'القرآن الكريم',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.goldLight,
            ),
          ),
          const Spacer(),
          // الشيخ الحالي
          GestureDetector(
            onTap: () => _showSheikhPicker(context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderGold),
                borderRadius: BorderRadius.circular(20.r),
                color: AppColors.goldWarm.withValues(alpha: 0.08),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.record_voice_over_rounded,
                    color: AppColors.goldLight,
                    size: 12.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    sheikh.name.split(' ').take(2).join(' '),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 9.sp,
                      color: AppColors.goldLight,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.goldLight,
                    size: 14.sp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── صف التنقّل: ختم القرآن | الحفظ ─────────────────────────────────
  //  يعيد استخدام "قوالب" شريط التبويبات (_buildTabBar) الحرفية —
  //  نفس الحاوية (nightCard / 20.r / borderGold) ونفس نمط النص
  //  (Tajawal 12.sp w600 / goldLight) — نص فقط بلا أيقونات، لأن هذين
  //  زرّا تنقّل (ينتقلان لشاشة أخرى) وليسا تبديل عرض كالتبويب أسفلهما.
  Widget _buildNavRow(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      height: 38.h,
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold, width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildNavCell(
              'ختم القرآن',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const KhatmahTrackingScreen(),
                  ),
                );
              },
            ),
          ),
          Container(width: 1, height: 38.h, color: AppColors.borderGold),
          Expanded(
            child: _buildNavCell(
              'الحفظ',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HifzDashboardScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavCell(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        splashColor: AppColors.goldWarm.withValues(alpha: 0.15),
        highlightColor: AppColors.goldWarm.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.goldLight,
            ),
          ),
        ),
      ),
    );
  }

  // ── TabBar ──────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      height: 38.h,
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold, width: 1.0),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: BoxDecoration(
          color: AppColors.goldWarm.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.borderGoldStrong),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp),
        labelColor: AppColors.goldLight,
        unselectedLabelColor: AppColors.textDim,
        tabs: const [
          Tab(text: 'السور'),
          Tab(text: 'الأجزاء'),
        ],
      ),
    );
  }

  // ── تبويب السور ─────────────────────────────────────────────────
  Widget _buildSurahTab() {
    return SurahListScreen(
      embedded: true,
      onSurahTap: (surah) => _openReader(surah),
    );
  }

  // ── تبويب الأجزاء ───────────────────────────────────────────────
  Widget _buildJuzTab() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 40.h),
      itemCount: 30,
      itemBuilder: (context, i) {
        final juz = i + 1;

        // الحصول على معلومات الجزء من juz_data
        String startInfo = '';
        final juzSections = JuzData.juzContent[juz];
        if (juzSections != null && juzSections.isNotEmpty) {
          final firstSection = juzSections.first;
          if (firstSection.fromAyah == 1) {
            // يبدأ من أول السورة
            startInfo = firstSection.surahName;
          } else {
            // يبدأ من منتصف السورة
            startInfo = '${firstSection.surahName} (استكمال)';
          }
        }

        return RevealAnimation(
          delay: Duration(milliseconds: i * 30),
          child: Container(
            margin: EdgeInsets.only(bottom: 8.h),
            decoration: BoxDecoration(
              color: AppColors.nightCard,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.borderGold, width: 0.8),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
              child: InkWell(
                onTap: () {
                  // فتح شاشة عرض الجزء الجديدة
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => JuzViewScreenV2(juzNumber: juz),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12.r),
                splashColor: AppColors.goldWarm.withValues(alpha: 0.3),
                highlightColor: AppColors.goldLight.withValues(alpha: 0.1),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    children: [
                      // رقم الجزء
                      Container(
                        width: 38.r,
                        height: 38.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.goldWarm, AppColors.goldDim],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$juz',
                            style: TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.nightDeep,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            QuranDataService.juzNames[i],
                            style: TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 13.sp,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'يبدأ من: $startInfo',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10.sp,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.textDim,
                        size: 12.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── فتح القارئ ──────────────────────────────────────────────────
  void _openReader(SurahInfo? surah) {
    if (surah == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModernQuranReaderV2(surahNumber: surah.number),
      ),
    );
  }

  // ── اختيار الشيخ ────────────────────────────────────────────────
  void _showSheikhPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.nightCard,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        side: BorderSide(color: AppColors.borderGold),
      ),
      builder: (_) => _SheikhPickerSheet(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _SheikhPickerSheet — Bottom Sheet لاختيار الشيخ
// ════════════════════════════════════════════════════════════════
class _SheikhPickerSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(settingsProvider).sheikId;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.borderGold,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'اختر الشيخ',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 8.h),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: kSheikhs.length,
              itemBuilder: (context, index) {
                final sheikh = kSheikhs[index];
                final selected = sheikh.id == current;
                return ListTile(
                  onTap: () {
                    ref.read(settingsProvider.notifier).setSheikh(sheikh.id);
                    Navigator.pop(context);
                  },
                  title: Text(
                    sheikh.name,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 13.sp,
                      color: selected
                          ? AppColors.goldLight
                          : AppColors.textPrimary,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    sheikh.style,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10.sp,
                      color: AppColors.textDim,
                    ),
                  ),
                  trailing: selected
                      ? Icon(
                          Icons.check_circle,
                          color: AppColors.goldLight,
                          size: 18.sp,
                        )
                      : null,
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16.h),
        ],
      ),
    );
  }
}
