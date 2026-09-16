import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/data/hifz_page_index.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/animations/reveal_animation.dart';
import '../../../shared/widgets/gold_card.dart';
import '../models/hifz_models.dart';
import '../providers/hifz_provider.dart';
import '../providers/hifz_settings_provider.dart';
import '../providers/hifz_today_provider.dart';
import 'hifz_guide_screen.dart';
import 'hifz_juz_detail_screen.dart';
import 'hifz_new_memorization_screen.dart';
import 'hifz_settings_screen.dart';
import 'hifz_stats_screen.dart';
import 'hifz_today_review_screen.dart';
import '../widgets/hifz_app_bar.dart';
import '../widgets/hifz_stat_card.dart';
import '../widgets/juz_completion_map.dart';
import '../widgets/wird_streak_card.dart';

// ════════════════════════════════════════════════════════════════
//  HifzDashboardScreen — لوحة تحكم الحفظ (بُنيت في المرحلة 2 —
//  plan_hifz.md §4.1). شاشة عرض فقط (read-only) بالنسبة لبيانات
//  الحفظ نفسها: تقرأ hifzProvider/hifzSettingsProvider/hifzTodayProvider
//  ولا تستدعي أي دالة تُعدِّل بيانات الحفظ إطلاقاً.
//
//  اعتباراً من المرحلة 5، كل المداخل الخمسة (مراجعة اليوم/حفظ جديد/
//  الإحصائيات/إعدادات الحفظ عبر بطاقة الورد/خريطة الأجزاء) أصبحت
//  حقيقية بالكامل — آلية "التعطيل البصري" المؤقّتة (تعتيم + IgnorePointer)
//  التي استُخدمت في المراحل 2–4 للشاشات غير المبنيَّة بعد أُزيلت الآن
//  نهائياً؛ لا وجود لها في هذا الملف بعد اليوم.
// ════════════════════════════════════════════════════════════════

class HifzDashboardScreen extends ConsumerWidget {
  const HifzDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hifz = ref.watch(hifzProvider);
    final settings = ref.watch(hifzSettingsProvider);
    final todayQueue = ref.watch(hifzTodayProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            HifzAppBar(
              title: 'حفظ القرآن',
              trailing: _HifzHelpButton(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HifzGuideScreen()),
                  );
                },
              ),
            ),
            Expanded(
              child: hifz.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.goldWarm),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                      children: [
                        RevealAnimation(
                          child: _OverallProgressCard(hifz: hifz),
                        ),
                        SizedBox(height: 14.h),
                        RevealAnimation(
                          delay: const Duration(milliseconds: 60),
                          // ✅ المرحلة 6: خريطة الأجزاء أصبحت تنقل إلى
                          // شاشة تفاصيل الجزء — الترميز البصري للخلايا
                          // (JuzCompletionMap._JuzCell) لم يتغيّر إطلاقاً.
                          child: _JuzMapSection(
                            pages: hifz.pages,
                            onJuzTap: (juz) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => HifzJuzDetailScreen(juzNumber: juz),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 14.h),
                        RevealAnimation(
                          delay: const Duration(milliseconds: 120),
                          // ✅ المرحلة 3: شاشة "مراجعة اليوم" أصبحت حقيقية الآن —
                          // هذه هي البطاقة الوحيدة التي أُعيد تفعيلها هذه المرحلة.
                          child: _TodayReviewCard(
                            near: todayQueue.near.length,
                            far: todayQueue.far.length,
                            doneCount: hifz.meta.doneToday.length,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const HifzTodayReviewScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 14.h),
                        RevealAnimation(
                          delay: const Duration(milliseconds: 180),
                          // ✅ المرحلة 5: شاشة "إعدادات الحفظ" أصبحت حقيقية.
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16.r),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const HifzSettingsScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16.r),
                              splashColor: AppColors.goldWarm.withValues(alpha: 0.2),
                              child: WirdStreakCard(meta: hifz.meta, settings: settings),
                            ),
                          ),
                        ),
                        SizedBox(height: 14.h),
                        RevealAnimation(
                          delay: const Duration(milliseconds: 240),
                          child: _SecondaryActionsRow(),
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
//  نسبة الحفظ الإجمالية — القرار #4: الرقم الكبير من النسبة البسيطة
//  (stage != notStarted)، والسطر الثانوي من النسبة المرجَّحة
//  (consolidatedFraction: 0.5 حفظ حديث / 0.8 قيد المراجعة / 1.0 متقن).
// ════════════════════════════════════════════════════════════════
class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.hifz});

  final HifzState hifz;

  @override
  Widget build(BuildContext context) {
    final simplePct = (hifz.simpleFraction * 100).round();
    final consolidatedPct = (hifz.consolidatedFraction * 100).round();

    return GoldCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Text(
            'نسبة الحفظ',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.sp, color: AppColors.textDim),
          ),
          SizedBox(height: 6.h),
          Text(
            '$simplePct٪',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 34.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.goldWarm,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'الرسوخ المرجَّح: $consolidatedPct٪',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.sp, color: AppColors.textDim),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              HifzStatCard(
                icon: '📖',
                label: 'صفحات محفوظة',
                value: '${hifz.memorizedPageCount}/${HifzPageIndex.pageCount}',
              ),
              Container(width: 1, height: 45.h, color: AppColors.goldWarm.withValues(alpha: 0.2)),
              HifzStatCard(
                icon: '🏅',
                label: 'صفحات متقَنة',
                value: '${hifz.masteredPageCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  خريطة الأجزاء — بيانات حقيقية بلا أي تعتيم؛ كل خلية تنقل الآن إلى
//  شاشة تفاصيل الجزء (المرحلة 6) عبر onJuzTap — الترميز اللوني نفسه.
// ════════════════════════════════════════════════════════════════
class _JuzMapSection extends StatelessWidget {
  const _JuzMapSection({required this.pages, this.onJuzTap});

  final Map<int, HifzPageState> pages;
  final void Function(int juz)? onJuzTap;

  @override
  Widget build(BuildContext context) {
    return GoldCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خريطة الأجزاء',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 12.h),
          JuzCompletionMap(pages: pages, onJuzTap: onJuzTap),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  بطاقة "مراجعة اليوم" — أعداد حقيقية من hifzTodayProvider + meta.doneToday
// ════════════════════════════════════════════════════════════════
class _TodayReviewCard extends StatelessWidget {
  const _TodayReviewCard({
    required this.near,
    required this.far,
    required this.doneCount,
    required this.onTap,
  });

  final int near;
  final int far;
  final int doneCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = near + far + doneCount;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        splashColor: AppColors.goldWarm.withValues(alpha: 0.2),
        highlightColor: AppColors.goldLight.withValues(alpha: 0.08),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF2A1E4A), Color(0xFF1C1230)],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'مراجعة اليوم',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldLight,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_back_ios_new, color: AppColors.goldLight, size: 12.sp),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(child: HifzStatCard(icon: '📗', label: 'التثبيت', value: '$near')),
                  Expanded(
                    child: HifzStatCard(icon: '🔄', label: 'المراجعة الدورية', value: '$far'),
                  ),
                  Expanded(child: HifzStatCard(icon: '✅', label: 'أُنجز', value: '$doneCount/$total')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  صف الأزرار الثانوية — حفظ جديد / الإحصائيات (مراحل 4 و5 لاحقاً)
// ════════════════════════════════════════════════════════════════
class _SecondaryActionsRow extends StatelessWidget {
  const _SecondaryActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          // ✅ المرحلة 4: شاشة "حفظ جديد" أصبحت حقيقية — الزر الوحيد
          // الذي أُعيد تفعيله هذه المرحلة.
          child: _SecondaryActionButton(
            icon: Icons.add_circle_outline_rounded,
            label: 'حفظ جديد',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HifzNewMemorizationScreen(),
                ),
              );
            },
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          // ✅ المرحلة 5: شاشة "السجل والإحصائيات" أصبحت حقيقية.
          child: _SecondaryActionButton(
            icon: Icons.insights_outlined,
            label: 'الإحصائيات',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HifzStatsScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderGold, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.goldLight, size: 20.sp),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.goldLight,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        splashColor: AppColors.goldWarm.withValues(alpha: 0.2),
        child: content,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  زر الدخول إلى "دليل نظام الحفظ" — نفس شارة زر الرجوع الدائرية
//  حرفياً (38.r، حدّ goldWarm.alpha 0.35، تعبئة goldWarm.alpha 0.1)
//  كي يبقى شريط الرأس متوازناً بصرياً تلقائياً مع الطرف الآخر، ولأنه
//  نفس نمط زر أيقونة موجود ومُستقَر عليه أصلاً في التطبيق.
// ════════════════════════════════════════════════════════════════
class _HifzHelpButton extends StatelessWidget {
  const _HifzHelpButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38.r,
        height: 38.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.35), width: 1),
          color: AppColors.goldWarm.withValues(alpha: 0.1),
        ),
        child: Icon(Icons.help_outline_rounded, color: AppColors.goldLight, size: 18.sp),
      ),
    );
  }
}
