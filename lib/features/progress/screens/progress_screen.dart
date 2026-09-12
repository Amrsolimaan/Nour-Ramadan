import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_colors.dart';
import '../../quran/providers/quran_progress_provider.dart';
import '../../prayer/providers/prayer_tracking_provider.dart';
import '../../tasbih/providers/tasbih_provider.dart';
import '../../../core/services/dua_tracking_service.dart';

// ════════════════════════════════════════════════════════════════
//  ProgressScreen — شاشة التقدم الشاملة
//  تعرض إحصائيات من: القرآن، الصلوات، الأدعية، التسبيح
// ════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════
//  دالة تنسيق الأرقام الكبيرة
//  1,000 → 1K
//  1,000,000 → 1M
//  1,000,000,000 → 1B
// ════════════════════════════════════════════════════════════════
String _formatLargeNumber(int number) {
  if (number >= 1000000000) {
    return '${(number / 1000000000).toStringAsFixed(1)}B';
  } else if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toString();
}

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _todayDuasCount = 0;
  int _weeklyDuasCount = 0;
  int _totalDuasCount = 0; // ✅ تصحيح: الإجمالي وليس الشهري فقط

  @override
  void initState() {
    super.initState();
    _loadDuaStats();
  }

  Future<void> _loadDuaStats() async {
    final today = await DuaTrackingService.getTodayDuasCount();
    final weekly = await DuaTrackingService.getWeeklyDuasCount();
    final total = await DuaTrackingService.getMonthlyDuasCount(); // ✅ هذا فعلياً الإجمالي

    if (mounted) {
      setState(() {
        _todayDuasCount = today;
        _weeklyDuasCount = weekly;
        _totalDuasCount = total; // ✅ تصحيح التسمية
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quranProgress = ref.watch(quranProgressProvider);
    final prayerTracking = ref.watch(prayerTrackingProvider);
    final tasbihState = ref.watch(tasbihProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF03020F), Color(0xFF0A0720), Color(0xFF120E2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ────────────────────────────────────────
              _buildAppBar(),

              // ── المحتوى ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  child: Column(
                    children: [
                      // ── تقدم القرآن ──────────────────────────
                      _QuranProgressCard(state: quranProgress),
                      SizedBox(height: 12.h),

                      // ── تقدم الصلوات ─────────────────────────
                      _PrayerProgressCard(state: prayerTracking),
                      SizedBox(height: 12.h),

                      // ── تقدم الأدعية ─────────────────────────
                      _DuaProgressCard(
                        todayCount: _todayDuasCount,
                        weeklyCount: _weeklyDuasCount,
                        totalCount: _totalDuasCount, // ✅ تصحيح التسمية
                      ),
                      SizedBox(height: 12.h),

                      // ── تقدم التسبيح ─────────────────────────
                      _TasbihProgressCard(state: tasbihState),
                      SizedBox(height: 12.h),

                      // ── رسالة تحفيزية ────────────────────────
                      _MotivationalMessage(),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
            'تقدمي',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.goldLight,
            ),
          ),
          const Spacer(),
          SizedBox(width: 36.r),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _QuranProgressCard — بطاقة تقدم القرآن
// ════════════════════════════════════════════════════════════════

class _QuranProgressCard extends StatelessWidget {
  const _QuranProgressCard({required this.state});
  final QuranProgressState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.readSurahsCount / 114.0;
    final lastDateStr = state.lastKhatmahDate != null
        ? intl.DateFormat('d MMM yyyy', 'ar').format(state.lastKhatmahDate!)
        : 'لم تكتمل بعد';

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221A40), Color(0xFF1C1535)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('📖', style: TextStyle(fontSize: 24.sp)),
              SizedBox(width: 10.w),
              Text(
                'القرآن الكريم',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // ── شريط التقدم ──────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10.h,
              backgroundColor: AppColors.goldWarm.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
          SizedBox(height: 10.h),

          // ── الإحصائيات ───────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'السور المقروءة',
                value: '${state.readSurahsCount}/114',
                icon: '',
              ),
              _StatItem(
                label: 'عدد الختمات',
                value: '${state.khatmahCount}',
                icon: '',
              ),
            ],
          ),
          SizedBox(height: 8.h),

          if (state.lastKhatmahDate != null)
            Row(
              children: [
                Text('', style: TextStyle(fontSize: 12.sp)),
                SizedBox(width: 6.w),
                Text(
                  'آخر ختمة: $lastDateStr',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.sp,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _PrayerProgressCard — بطاقة تقدم الصلوات
// ════════════════════════════════════════════════════════════════

class _PrayerProgressCard extends StatelessWidget {
  const _PrayerProgressCard({required this.state});
  final PrayerTrackingState state;

  @override
  Widget build(BuildContext context) {
    final todayProgress = state.todayCount / 5.0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221A40), Color(0xFF1C1535)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🕌', style: TextStyle(fontSize: 24.sp)),
              SizedBox(width: 10.w),
              Text(
                'الصلوات',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // ── شريط التقدم اليومي ───────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: todayProgress,
              minHeight: 10.h,
              backgroundColor: AppColors.goldWarm.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
          SizedBox(height: 10.h),

          // ── الإحصائيات ───────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'اليوم',
                value: '${state.todayCount}/5',
                icon: '',
              ),
              _StatItem(
                label: 'هذا الشهر',
                value: _formatLargeNumber(state.monthlyCount),
                icon: '',
              ),
              _StatItem(
                label: 'الإجمالي',
                value: _formatLargeNumber(state.totalCount),
                icon: '',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _DuaProgressCard — بطاقة تقدم الأدعية
// ════════════════════════════════════════════════════════════════

class _DuaProgressCard extends StatelessWidget {
  const _DuaProgressCard({
    required this.todayCount,
    required this.weeklyCount,
    required this.totalCount, // ✅ تصحيح التسمية
  });

  final int todayCount;
  final int weeklyCount;
  final int totalCount; // ✅ تصحيح التسمية

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221A40), Color(0xFF1C1535)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🤲', style: TextStyle(fontSize: 24.sp)),
              SizedBox(width: 10.w),
              Text(
                'الأدعية',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // ── الإحصائيات ───────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(label: 'اليوم', value: _formatLargeNumber(todayCount), icon: ''),
              _StatItem(label: 'هذا الأسبوع', value: _formatLargeNumber(weeklyCount), icon: ''),
              _StatItem(label: 'الإجمالي', value: _formatLargeNumber(totalCount), icon: ''), // ✅ تصحيح
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _TasbihProgressCard — بطاقة تقدم التسبيح
// ════════════════════════════════════════════════════════════════

class _TasbihProgressCard extends StatelessWidget {
  const _TasbihProgressCard({required this.state});
  final TasbihState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221A40), Color(0xFF1C1535)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('📿', style: TextStyle(fontSize: 24.sp)),
              SizedBox(width: 10.w),
              Text(
                'التسبيح',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // ── الإحصائيات ───────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'اليوم',
                value: _formatLargeNumber(state.dailyTotal),
                icon: '',
              ),
              _StatItem(
                label: 'هذا الشهر',
                value: _formatLargeNumber(state.monthlyTotal),
                icon: '',
              ),
              _StatItem(
                label: 'الإجمالي', // ✅ تصحيح: الإجمالي الكلي
                value: _formatLargeNumber(state.totalCount),
                icon: '',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _StatItem — عنصر إحصائية صغير
// ════════════════════════════════════════════════════════════════

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(icon, style: TextStyle(fontSize: 14.sp)),
            SizedBox(width: 4.w),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.goldLight,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10.sp,
            color: AppColors.textDim,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _MotivationalMessage — رسالة تحفيزية
// ════════════════════════════════════════════════════════════════

class _MotivationalMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text('', style: TextStyle(fontSize: 20.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'استمر في التقدم، كل خطوة تقربك من الله 💜',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.sp,
                color: AppColors.goldLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
