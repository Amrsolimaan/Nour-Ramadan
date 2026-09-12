import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/local_quran_service.dart';

// ════════════════════════════════════════════════════════════════
//  JustifiedQuranText — نص قرآني محاذي بالكامل
//  يستخدم TextAlign.justify مع تحسينات للكشيدة
// ════════════════════════════════════════════════════════════════

class JustifiedQuranText extends StatelessWidget {
  final List<LocalAyah> ayahs;
  final Function(int) onAyahTap;
  final Function(int) onAyahLongPress;
  final bool Function(int) isSelected;
  final int playingAyah;

  /// آية "آخر قراءة" — تحصل على علامة إشارة مرجعية خفيفة (اختياري)
  final int? lastReadAyah;
  final Map<int, GlobalKey> ayahKeys;
  final Function(int)? onVisibilityChanged;
  final Widget Function(LocalAyah, int)? dividerBuilder;

  const JustifiedQuranText({
    super.key,
    required this.ayahs,
    required this.onAyahTap,
    required this.onAyahLongPress,
    required this.isSelected,
    required this.playingAyah,
    this.lastReadAyah,
    required this.ayahKeys,
    this.onVisibilityChanged,
    this.dividerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(ayahs.length, (index) {
        final ayah = ayahs[index];
        final isAyahSelected = isSelected(ayah.numberInSurah);
        final isCurrentlyPlaying = playingAyah == ayah.numberInSurah;
        final isLastRead = lastReadAyah == ayah.numberInSurah;

        return Column(
          children: [
            // الآية مع VisibilityDetector
            VisibilityDetector(
              key: Key('ayah-justified-${ayah.numberInSurah}'),
              onVisibilityChanged: (info) {
                if (info.visibleFraction > 0.5 && onVisibilityChanged != null) {
                  onVisibilityChanged!(ayah.numberInSurah);
                }
              },
              child: GestureDetector(
                key: ayahKeys[ayah.numberInSurah],
                onTap: () => onAyahTap(ayah.numberInSurah),
                onLongPress: () => onAyahLongPress(ayah.numberInSurah),
                child: Container(
                  margin: EdgeInsets.only(bottom: 6.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentlyPlaying
                        ? AppColors.goldWarm.withValues(alpha: 0.2)
                        : isAyahSelected
                        ? AppColors.mushafHighlight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12.r),
                    border: isAyahSelected
                        ? Border.all(
                            color: AppColors.goldWarm.withValues(alpha: 0.5),
                            width: 2,
                          )
                        : null,
                    boxShadow: isCurrentlyPlaying
                        ? [
                            BoxShadow(
                              color: AppColors.goldWarm.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: RichText(
                    textAlign: TextAlign.justify,
                    textDirection: TextDirection.rtl,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: ayah.text,
                          style: TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: 24.sp,
                            color: AppColors.mushafInk,
                            height: 2.2,
                            letterSpacing: 0.3,
                            wordSpacing: 1.5,
                          ),
                        ),
                        TextSpan(
                          text: ' ',
                          style: TextStyle(fontSize: 6.sp),
                        ),
                        // علامة "آخر قراءة" — إشارة مرجعية خفيفة قبل رقم الآية
                        if (isLastRead)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2.w),
                              child: Icon(
                                Icons.bookmark_border_rounded,
                                size: 16.sp,
                                color: AppColors.goldWarm,
                              ),
                            ),
                          ),
                        TextSpan(
                          text: '﴿${_toArabicNumber(ayah.numberInSurah)}﴾',
                          style: TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: 22.sp,
                            color: AppColors.goldWarm,
                            height: 2.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // إضافة الفاصل بعد الآية إذا كانت نهاية صفحة
            if (dividerBuilder != null)
              dividerBuilder!(ayah, index),
          ],
        );
      }),
    );
  }

  String _toArabicNumber(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join();
  }
}
