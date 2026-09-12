import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/local_quran_service.dart';

// ════════════════════════════════════════════════════════════════
//  ParagraphQuranText — نص قرآني مسترسل حقيقي (True Continuous Style)
//  يعرض السورة ككتلة نصية واحدة متصلة مع فواصل الصفحات
// ════════════════════════════════════════════════════════════════

class ParagraphQuranText extends StatelessWidget {
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

  const ParagraphQuranText({
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
    // تقسيم الآيات حسب الصفحات
    final pageGroups = _groupAyahsByPage();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: pageGroups.map((group) {
        return Column(
          children: [
            // النص المسترسل لكل صفحة
            _buildContinuousText(group),
            
            // الفاصل بعد نهاية الصفحة
            if (dividerBuilder != null && group.isNotEmpty) 
              _buildDividerIfNeeded(group),
          ],
        );
      }).toList(),
    );
  }

  // تقسيم الآيات حسب الصفحات
  List<List<LocalAyah>> _groupAyahsByPage() {
    if (ayahs.isEmpty) return [];
    
    final List<List<LocalAyah>> groups = [];
    List<LocalAyah> currentGroup = [ayahs[0]];
    
    for (int i = 1; i < ayahs.length; i++) {
      if (ayahs[i].pageNumber == ayahs[i - 1].pageNumber) {
        currentGroup.add(ayahs[i]);
      } else {
        groups.add(currentGroup);
        currentGroup = [ayahs[i]];
      }
    }
    
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }
    
    return groups;
  }

  // بناء النص المسترسل لمجموعة آيات
  Widget _buildContinuousText(List<LocalAyah> pageAyahs) {
    final List<InlineSpan> allSpans = [];
    
    for (int i = 0; i < pageAyahs.length; i++) {
      final ayah = pageAyahs[i];
      
      // إضافة WidgetSpan غير مرئي مع key للتمرير
      allSpans.add(
        WidgetSpan(
          child: Container(
            key: ayahKeys[ayah.numberInSurah],
            width: 0,
            height: 0,
          ),
        ),
      );
      
      // إضافة spans الآية
      allSpans.addAll(_buildAyahSpans(ayah));
      
      // إضافة مسافة بين الآيات (إلا بعد آخر آية)
      if (i < pageAyahs.length - 1) {
        allSpans.add(TextSpan(text: ' ', style: TextStyle(fontSize: 8.sp)));
      }
    }
    
    return VisibilityDetector(
      key: Key('page-${pageAyahs.first.pageNumber}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.3 && onVisibilityChanged != null) {
          // تحديث الآية المرئية بأول آية في الصفحة المرئية
          onVisibilityChanged!(pageAyahs.first.numberInSurah);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: RichText(
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          text: TextSpan(
            children: allSpans,
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 26.sp,
              color: AppColors.mushafInk,
              height: 2.4,
              letterSpacing: 0.3,
              wordSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }

  // بناء spans لآية واحدة
  List<InlineSpan> _buildAyahSpans(LocalAyah ayah) {
    final isAyahSelected = isSelected(ayah.numberInSurah);
    final isCurrentlyPlaying = playingAyah == ayah.numberInSurah;
    final isLastRead = lastReadAyah == ayah.numberInSurah;

    Color? backgroundColor;
    if (isCurrentlyPlaying) {
      backgroundColor = AppColors.goldWarm.withValues(alpha: 0.35);
    } else if (isAyahSelected) {
      backgroundColor = AppColors.mushafHighlight;
    }

    return [
      TextSpan(
        text: ayah.text,
        style: TextStyle(
          backgroundColor: backgroundColor,
          decoration: isAyahSelected ? TextDecoration.underline : null,
          decorationColor: AppColors.goldWarm.withValues(alpha: 0.5),
          decorationThickness: 2,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => onAyahTap(ayah.numberInSurah)
          ..onLongPress = () => onAyahLongPress(ayah.numberInSurah),
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
          height: 2.4,
          fontWeight: FontWeight.bold,
          backgroundColor: backgroundColor,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => onAyahTap(ayah.numberInSurah)
          ..onLongPress = () => onAyahLongPress(ayah.numberInSurah),
      ),
    ];
  }

  // بناء الفاصل إذا لزم الأمر
  Widget _buildDividerIfNeeded(List<LocalAyah> pageAyahs) {
    final lastAyah = pageAyahs.last;
    final index = ayahs.indexOf(lastAyah);
    
    // إذا كانت آخر آية في السورة، لا نعرض فاصل
    if (index >= ayahs.length - 1) return const SizedBox.shrink();
    
    // إذا كانت الآية التالية في صفحة مختلفة، نعرض الفاصل
    final nextAyah = ayahs[index + 1];
    if (nextAyah.pageNumber != lastAyah.pageNumber) {
      return dividerBuilder!(lastAyah, index);
    }
    
    return const SizedBox.shrink();
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
