import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/animations/reveal_animation.dart';
import '../../../shared/widgets/gold_card.dart';
import '../logic/hifz_scheduler.dart';
import '../models/hifz_models.dart';
import '../providers/hifz_provider.dart';
import '../widgets/hifz_app_bar.dart';
import '../widgets/hifz_section_header.dart';
import '../widgets/hifz_stat_card.dart';

// ════════════════════════════════════════════════════════════════
//  HifzStatsScreen — السجل والإحصائيات (المرحلة 5 — plan_hifz.md §4.5)
//  شاشة عرض فقط: تُستهلَك من hifzProvider (pages/meta/sessions) دون
//  أي كتابة. سجل المراجعات مصدره الحقيقي HifzReviewSession التي كانت
//  تُسجَّل بالفعل منذ المرحلة 1 (_appendSession في hifz_provider.dart
//  عند كل markNewlyMemorized/gradePage) — لا حاجة لإضافة تسجيل جديد،
//  ولا بيانات تاريخية وهمية هنا: القائمة فارغة حتى يستخدم المستخدم
//  التطبيق فعلياً.
// ════════════════════════════════════════════════════════════════

class HifzStatsScreen extends ConsumerWidget {
  const HifzStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hifz = ref.watch(hifzProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            const HifzAppBar(title: 'السجل والإحصائيات'),
            Expanded(
              child: hifz.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.goldWarm),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                      children: [
                        RevealAnimation(child: _StatTilesCard(hifz: hifz)),
                        SizedBox(height: 14.h),
                        RevealAnimation(
                          delay: const Duration(milliseconds: 60),
                          child: _WeeklyProgressCard(pages: hifz.pages),
                        ),
                        SizedBox(height: 14.h),
                        RevealAnimation(
                          delay: const Duration(milliseconds: 120),
                          child: _SessionLogSection(sessions: hifz.sessions),
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
//  بطاقة إحصاءات علوية — plan §4.5: إجمالي الصفحات المحفوظة، ٪ من
//  المصحف، الصفحات المتقَنة، متوسط طول دورة المراجعة، أطول سلسلة.
// ════════════════════════════════════════════════════════════════
class _StatTilesCard extends StatelessWidget {
  const _StatTilesCard({required this.hifz});

  final HifzState hifz;

  /// متوسط طول دورة المراجعة الدورية بالأيام — تقدير (وليس قياساً
  /// دقيقاً لكل دورة على حدة، لأن HifzMeta الحالي لا يخزّن تاريخ بداية
  /// كل دورة منفردة، فقط عدّاد الدورات الكلي farCycleCount وتاريخ أول
  /// استخدام createdAt): إجمالي الأيام منذ createdAt ÷ عدد الدورات
  /// المكتملة. يُعرض "لم تكتمل دورة بعد" حين farCycleCount == 0 بدل
  /// رقم مضلِّل. لم تتم إضافة أي حقل جديد لـ HifzMeta لهذا الغرض —
  /// انظر تقرير المرحلة 5 لملاحظة هذا القيد صراحةً.
  int? get _avgCycleDays {
    if (hifz.meta.farCycleCount <= 0) return null;
    final elapsed = HifzScheduler.daysBetween(hifz.meta.createdAt, DateTime.now());
    return (elapsed / hifz.meta.farCycleCount).round();
  }

  @override
  Widget build(BuildContext context) {
    final avgCycle = _avgCycleDays;

    return GoldCard(
      margin: EdgeInsets.zero,
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 16.h,
        spacing: 6.w,
        children: [
          SizedBox(
            width: 92.w,
            child: HifzStatCard(
              icon: '📖',
              label: 'صفحات محفوظة',
              value: '${hifz.memorizedPageCount}',
            ),
          ),
          SizedBox(
            width: 92.w,
            child: HifzStatCard(
              icon: '📊',
              label: '٪ من المصحف',
              value: '${(hifz.simpleFraction * 100).round()}٪',
            ),
          ),
          SizedBox(
            width: 92.w,
            child: HifzStatCard(
              icon: '🏅',
              label: 'صفحات متقَنة',
              value: '${hifz.masteredPageCount}',
            ),
          ),
          SizedBox(
            width: 92.w,
            child: HifzStatCard(
              icon: '🔄',
              label: 'متوسط طول الدورة',
              value: avgCycle == null ? 'لم تكتمل دورة بعد' : '$avgCycle يوم',
              valueFontSize: avgCycle == null ? 10.sp : 16.sp,
            ),
          ),
          SizedBox(
            width: 92.w,
            child: HifzStatCard(
              icon: '🏆',
              label: 'أطول سلسلة',
              value: '${hifz.meta.longestStreak} يوم',
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  التقدّم الأسبوعي — رسم أعمدة يدوي (Container فقط، بلا مكتبة رسوم
//  بيانية) لعدد الصفحات التي أُضيفت كحفظ جديد كل أسبوع، آخر 8 أسابيع،
//  مُشتقّ من هستوغرام firstMemorizedAt.
// ════════════════════════════════════════════════════════════════
class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({required this.pages});

  final Map<int, HifzPageState> pages;

  static const int _weeks = 8;

  Map<DateTime, int> _weeklyHistogram() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final thisWeekStart = todayOnly.subtract(Duration(days: todayOnly.weekday - 1));
    final firstWeekStart = thisWeekStart.subtract(Duration(days: 7 * (_weeks - 1)));

    final buckets = <DateTime, int>{
      for (var i = 0; i < _weeks; i++) firstWeekStart.add(Duration(days: 7 * i)): 0,
    };

    for (final state in pages.values) {
      final d = state.firstMemorizedAt;
      if (d == null) continue;
      final dOnly = DateTime(d.year, d.month, d.day);
      if (dOnly.isBefore(firstWeekStart)) continue;
      final weekIndex = dOnly.difference(firstWeekStart).inDays ~/ 7;
      if (weekIndex < 0 || weekIndex >= _weeks) continue;
      final key = firstWeekStart.add(Duration(days: 7 * weekIndex));
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final histogram = _weeklyHistogram();
    final weeks = histogram.keys.toList(); // مرتَّبة تصاعدياً بحكم بناء الـ Map أعلاه
    final maxCount = histogram.values.fold<int>(0, (a, b) => a > b ? a : b);
    const barAreaHeight = 90.0;

    return GoldCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'التقدّم الأسبوعي (حفظ جديد)',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 14.h),
          if (maxCount == 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              child: Center(
                child: Text(
                  'لا حفظ جديد مسجَّل في آخر 8 أسابيع بعد',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.sp, color: AppColors.textDim),
                ),
              ),
            )
          else
            SizedBox(
              height: barAreaHeight.h + 24.h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final weekStart in weeks)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${histogram[weekStart]}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 9.sp,
                                color: AppColors.textDim,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Container(
                              height:
                                  (barAreaHeight *
                                          (histogram[weekStart]! / maxCount).clamp(0.06, 1.0))
                                      .h,
                              decoration: BoxDecoration(
                                color: AppColors.goldWarm.withValues(
                                  alpha: histogram[weekStart]! == 0 ? 0.15 : 0.85,
                                ),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(4.r)),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              DateFormat('d/M').format(weekStart),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 8.sp,
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
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
//  سجل المراجعات — قائمة عكسية زمنياً فوق HifzReviewSession الحقيقية.
// ════════════════════════════════════════════════════════════════
class _SessionLogSection extends StatelessWidget {
  const _SessionLogSection({required this.sessions});

  final List<HifzReviewSession> sessions;

  static String _kindLabel(String kind) => switch (kind) {
    'new' => 'حفظ جديد',
    'near' => 'تثبيت',
    'far' => 'مراجعة دورية',
    _ => kind,
  };

  static Color _kindColor(String kind) => switch (kind) {
    'new' => AppColors.goldWarm,
    'near' => AppColors.goldLight,
    'far' => AppColors.goldGlow,
    _ => AppColors.textDim,
  };

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HifzSectionHeader('سجل المراجعات'),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Center(
              child: Text(
                'لا سجل بعد — ابدأ رحلة الحفظ لتظهر جلساتك هنا',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp, color: AppColors.textDim),
              ),
            ),
          ),
        ],
      );
    }

    final sorted = [...sessions]..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HifzSectionHeader('سجل المراجعات'),
        for (final session in sorted) _SessionRow(session: session),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final HifzReviewSession session;

  String _gradeBreakdown() {
    if (session.grades.isEmpty) return '';
    var strong = 0, medium = 0, weak = 0;
    for (final g in session.grades.values) {
      switch (g) {
        case HifzGrade.strong:
          strong++;
        case HifzGrade.medium:
          medium++;
        case HifzGrade.weak:
          weak++;
      }
    }
    return '$strong قوي · $medium متوسط · $weak ضعيف';
  }

  @override
  Widget build(BuildContext context) {
    final color = _SessionLogSection._kindColor(session.kind);
    final breakdown = _gradeBreakdown();
    final pageDesc = session.pages.isEmpty
        ? '—'
        : session.pages.length == 1
        ? 'صفحة ${session.pages.first}'
        : '${session.pages.length} صفحة (${session.pages.first}–${session.pages.last})';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('yyyy/MM/dd').format(session.date),
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _SessionLogSection._kindLabel(session.kind),
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  pageDesc,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.sp, color: AppColors.textDim),
                ),
                if (breakdown.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    breakdown,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.sp, color: AppColors.textDim),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
