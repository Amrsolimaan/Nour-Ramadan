import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/data/hifz_page_index.dart';
import '../../../core/services/quran_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hifz_models.dart';

// ════════════════════════════════════════════════════════════════
//  HifzPageTile — صفّ صفحة واحدة (شارة رقم + وصف + شارة مرحلة +
//  حالة طرفية). مصمَّمة عمداً بلا أي ربط بنوع طابور خاص بشاشة معيّنة
//  (مثل HifzQueueItem الخاص بمراجعة اليوم) — تأخذ فقط page/stage/
//  trailing/onTap، لتُعاد استخدامها لاحقاً في شاشة تفاصيل الجزء
//  (plan_hifz.md §4.4) دون أي تعديل.
// ════════════════════════════════════════════════════════════════

/// حالة الطرف الأيسر من البلاطة: قيد الانتظار أم أُنجزت اليوم بالفعل.
enum HifzPageTileTrailing { pending, done }

class HifzPageTile extends StatelessWidget {
  const HifzPageTile({
    super.key,
    required this.page,
    required this.stage,
    this.trailing = HifzPageTileTrailing.pending,
    this.onTap,
    this.onLongPress,
  });

  final int page;
  final HifzStage stage;
  final HifzPageTileTrailing trailing;
  final VoidCallback? onTap;

  /// إجراء اختياري عند الضغط المطوَّل — تستخدمه شاشة تفاصيل الجزء
  /// (plan_hifz.md §4.4) لفتح شيت "علّمها محفوظة اليوم"/"قيّمها الآن"/
  /// "أعِد ضبطها". يبقى null افتراضياً فلا يتأثر أي استخدام حالي
  /// (شاشة مراجعة اليوم) بهذه الإضافة.
  final VoidCallback? onLongPress;

  static String _stageLabel(HifzStage stage) => switch (stage) {
    HifzStage.notStarted => 'لم يبدأ',
    HifzStage.newlyMemorized => 'حفظ حديث',
    HifzStage.underReview => 'قيد المراجعة',
    HifzStage.mastered => 'متقن',
  };

  static Color _stageColor(HifzStage stage) => switch (stage) {
    HifzStage.notStarted => AppColors.textDim,
    HifzStage.newlyMemorized => AppColors.goldWarm,
    HifzStage.underReview => AppColors.goldLight,
    HifzStage.mastered => AppColors.goldGlow,
  };

  String _subtitle() {
    final juz = HifzPageIndex.juzOfPage(page);
    String surahPart = '';
    try {
      final range = HifzPageIndex.surahRangeOnPage(page);
      final name = QuranDataService.instance.surahById(range.firstSurah).name;
      surahPart = ' · سورة $name';
    } catch (_) {
      // لا نكسر العرض إن تعذّر إيجاد اسم السورة لأي سبب — نعرض بلا اسم.
    }
    return 'صفحة $page · الجزء $juz$surahPart';
  }

  @override
  Widget build(BuildContext context) {
    final done = trailing == HifzPageTileTrailing.done;
    final stageColor = _stageColor(stage);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: done ? Colors.green.withValues(alpha: 0.4) : AppColors.borderGold,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14.r),
          splashColor: AppColors.goldWarm.withValues(alpha: 0.15),
          highlightColor: AppColors.goldLight.withValues(alpha: 0.08),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Row(
              children: [
                Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldWarm.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.35)),
                  ),
                  child: Center(
                    child: Text(
                      '$page',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldWarm,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _subtitle(),
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: stageColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: stageColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _stageLabel(stage),
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: stageColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  done ? Icons.check_circle_rounded : Icons.arrow_back_ios_new,
                  color: done ? Colors.green : AppColors.textDim,
                  size: done ? 22.sp : 12.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
