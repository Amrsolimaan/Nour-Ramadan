import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/quran_service.dart';
import '../providers/quran_progress_provider.dart';

// ════════════════════════════════════════════════════════════════
//  KhatmahTrackingScreen — صفحة ختم القرآن
// ════════════════════════════════════════════════════════════════

class KhatmahTrackingScreen extends ConsumerStatefulWidget {
  const KhatmahTrackingScreen({super.key});

  @override
  ConsumerState<KhatmahTrackingScreen> createState() =>
      _KhatmahTrackingScreenState();
}

class _KhatmahTrackingScreenState extends ConsumerState<KhatmahTrackingScreen> {
  @override
  Widget build(BuildContext context) {
    final progressState = ref.watch(quranProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(onBack: () => Navigator.of(context).pop()),
            _StatsHeader(
              readSurahsCount: progressState.readSurahsCount,
              khatmahCount: progressState.khatmahCount,
              lastKhatmahDate: progressState.lastKhatmahDate,
              isComplete: progressState.isKhatmahComplete,
              onStartNew: () => _showStartNewDialog(context),
            ),
            _SectionHeader(),
            Expanded(child: _SurahsList(readSurahs: progressState.readSurahs)),
          ],
        ),
      ),
    );
  }

  void _showStartNewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.nightMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(
            color: AppColors.goldWarm.withValues(alpha: 0.3),
          ),
        ),
        title: Text(
          '🎉 مبروك!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 18.sp,
            color: AppColors.goldWarm,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'أكملت ختمة كاملة!\nهل تريد بدء ختمة جديدة؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14.sp,
            color: AppColors.agedPlaster,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13.sp,
                color: AppColors.textDim,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(quranProgressProvider.notifier).startNewKhatmah();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldWarm,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'ابدأ ختمة جديدة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13.sp,
                color: AppColors.nightDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  AppBar
// ════════════════════════════════════════════════════════════════
class _AppBar extends StatelessWidget {
  const _AppBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
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
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.35),
                  width: 1,
                ),
                color: AppColors.goldWarm.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.goldLight,
                size: 15.sp,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'ختم القرآن',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.agedPlaster,
            ),
          ),
          const Spacer(),
          Icon(Icons.menu_book_rounded, color: AppColors.goldWarm, size: 20.sp),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  StatsHeader
// ════════════════════════════════════════════════════════════════
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.readSurahsCount,
    required this.khatmahCount,
    required this.lastKhatmahDate,
    required this.isComplete,
    required this.onStartNew,
  });

  final int readSurahsCount;
  final int khatmahCount;
  final DateTime? lastKhatmahDate;
  final bool isComplete;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(14.w),
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
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: '📖',
                label: 'السور المقروءة',
                value: '$readSurahsCount/114',
              ),
              Container(
                width: 1,
                height: 45.h,
                color: AppColors.goldWarm.withValues(alpha: 0.2),
              ),
              _StatItem(icon: '🎯', label: 'عدد الختمات', value: '$khatmahCount'),
            ],
          ),
          if (lastKhatmahDate != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.goldWarm.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14.sp,
                    color: AppColors.goldWarm,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'آخر ختمة: ${DateFormat('yyyy/MM/dd').format(lastKhatmahDate!)}',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.sp,
                      color: AppColors.goldLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isComplete) ...[
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: onStartNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldWarm,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                '🎉 ابدأ ختمة جديدة',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.sp,
                  color: AppColors.nightDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColors.goldWarm.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(icon, style: TextStyle(fontSize: 24.sp)),
        ),
        SizedBox(height: 6.h),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10.sp,
            color: AppColors.textDim,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.goldWarm,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SectionHeader
// ════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.goldWarm.withValues(alpha: 0.25),
        ),
      ),
      child: Center(
        child: Text(
          'السور',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.goldLight,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SurahsList
// ════════════════════════════════════════════════════════════════
class _SurahsList extends ConsumerWidget {
  const _SurahsList({required this.readSurahs});
  final Set<int> readSurahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSurahs = QuranDataService.surahs;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      itemCount: allSurahs.length,
      itemBuilder: (context, index) {
        final surah = allSurahs[index];
        final isRead = readSurahs.contains(surah.number);

        return _SurahItem(
          surah: surah,
          isRead: isRead,
          onToggle: () {
            ref.read(quranProgressProvider.notifier).toggleSurah(surah.number);
          },
        );
      },
    );
  }
}

class _SurahItem extends StatelessWidget {
  const _SurahItem({
    required this.surah,
    required this.isRead,
    required this.onToggle,
  });

  final SurahInfo surah;
  final bool isRead;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRead
              ? [const Color(0xFF1A3A2A), const Color(0xFF0F2419)]
              : [const Color(0xFF221A40), const Color(0xFF1C1535)],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isRead
              ? Colors.green.withValues(alpha: 0.4)
              : AppColors.goldWarm.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        leading: Container(
          width: 42.w,
          height: 42.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRead
                ? Colors.green.withValues(alpha: 0.15)
                : AppColors.goldWarm.withValues(alpha: 0.1),
            border: Border.all(
              color: isRead ? Colors.green : AppColors.goldWarm,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '${surah.number}',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: isRead ? Colors.green : AppColors.goldWarm,
              ),
            ),
          ),
        ),
        title: Text(
          surah.name,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.agedPlaster,
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: Text(
            '${surah.ayahCount} آية',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.sp,
              color: AppColors.textDim,
            ),
          ),
        ),
        trailing: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(50.r),
          child: Icon(
            isRead ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 28.sp,
            color: isRead ? Colors.green : AppColors.goldWarm,
          ),
        ),
      ),
    );
  }
}
