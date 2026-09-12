import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/data/hifz_page_index.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hifz_models.dart';

// ════════════════════════════════════════════════════════════════
//  JuzCompletionMap — خريطة الأجزاء الثلاثين (شبكة 6×5)
//  كل خلية لون واحد مُسطَّح (flat) بحسب نسبة اكتمال ذلك الجزء
//  (القرار المعتمَد #10 — plan_hifz.md §9): لا تدرّج، ولا شبكة نقاط.
//
//  البيانات حقيقية بالكامل (مُحسوبة من HifzPageIndex.pagesInJuz مقابل
//  حالات الصفحات الفعلية في hifzProvider) — لذلك الخلايا تُعرض بكامل
//  الوضوح دون أي تعتيم؛ فقط لا تتضمّن أي معالج نقر (شاشة تفاصيل
//  الجزء مرحلة لاحقة) — "لا تنتقل" وليس "معطّلة بصرياً كميزة مقفلة".
// ════════════════════════════════════════════════════════════════

class JuzCompletionMap extends StatelessWidget {
  const JuzCompletionMap({super.key, required this.pages, this.onJuzTap});

  final Map<int, HifzPageState> pages;

  /// استدعاء اختياري عند نقر خلية جزء — يبقى null افتراضياً فتبقى
  /// الخلايا غير تفاعلية تماماً كما في المرحلة 2 (عرض بلا تنقّل)، ما
  /// يُبقي هذا العنصر قابلاً لإعادة الاستخدام/الاختبار بلا استدعاء.
  /// شاشة تفاصيل الجزء (plan_hifz.md §4.4) هي من يمرّره من لوحة التحكم.
  final void Function(int juz)? onJuzTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 30,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        final juz = i + 1;
        final juzPages = HifzPageIndex.pagesInJuz(juz);

        var started = 0;
        var mastered = 0;
        for (final p in juzPages) {
          final stage = pages[p]?.stage ?? HifzStage.notStarted;
          if (stage != HifzStage.notStarted) started++;
          if (stage == HifzStage.mastered) mastered++;
        }
        final ratio = juzPages.isEmpty ? 0.0 : started / juzPages.length;
        final fullyMastered = juzPages.isNotEmpty && mastered == juzPages.length;

        return _JuzCell(
          juz: juz,
          ratio: ratio,
          fullyMastered: fullyMastered,
          onTap: onJuzTap == null ? null : () => onJuzTap!(juz),
        );
      },
    );
  }
}

class _JuzCell extends StatelessWidget {
  const _JuzCell({
    required this.juz,
    required this.ratio,
    required this.fullyMastered,
    this.onTap,
  });

  final int juz;
  final double ratio;
  final bool fullyMastered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color border;
    final Color textColor;

    if (fullyMastered) {
      // جزء اكتمل إتقانه بالكامل — لون مُسطَّح مميَّز عن التدرّج الجزئي.
      background = AppColors.goldGlow;
      border = AppColors.goldGlow;
      textColor = AppColors.nightDeep;
    } else if (ratio > 0) {
      // لون مُسطَّح واحد (goldWarm) تزداد شفافيته مع نسبة الاكتمال —
      // ليس تدرّجاً (gradient)، بل نفس اللون بقيمة alpha مختلفة.
      background = AppColors.goldWarm.withValues(alpha: 0.18 + ratio * 0.62);
      border = AppColors.goldWarm.withValues(alpha: 0.5);
      textColor = AppColors.textPrimary;
    } else {
      background = AppColors.nightCard;
      border = AppColors.borderGold;
      textColor = AppColors.textDim;
    }

    // نفس الترميز البصري تماماً كما في المرحلة 2 — لا تغيير هنا إطلاقاً.
    final cell = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: border, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        '$juz',
        style: TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );

    // فقط إن وُجد استدعاء تنقّل نُضيف طبقة تفاعل حول نفس الخلية —
    // بلا أي مساس بألوانها/حدودها/نصّها.
    if (onTap == null) return cell;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        splashColor: AppColors.goldWarm.withValues(alpha: 0.25),
        child: cell,
      ),
    );
  }
}
