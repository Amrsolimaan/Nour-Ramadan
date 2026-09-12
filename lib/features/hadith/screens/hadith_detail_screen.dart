import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../models/hadith_collection.dart';
import '../providers/hadith_favorites_provider.dart';

// ════════════════════════════════════════════════════════════════
//  HadithDetailScreen — صفحة عرض الحديث كاملاً
// ════════════════════════════════════════════════════════════════

class HadithDetailScreen extends ConsumerWidget {
  const HadithDetailScreen({
    super.key,
    required this.hadith,
    required this.collection,
  });

  final Hadith hadith;
  final HadithCollection collection;

  String get _hadithId => '${collection.id}_${hadith.number}';

  void _copyHadith(BuildContext context) {
    Clipboard.setData(ClipboardData(text: hadith.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الحديث',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.agedPlaster,
          ),
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

  void _shareHadith() {
    final text =
        '${hadith.text}\n\n— ${collection.arabicName} (حديث رقم ${hadith.arabicNumber})';
    Share.share(text, subject: collection.arabicName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(hadithFavoritesProvider).contains(_hadithId);
    final favNotifier = ref.read(hadithFavoritesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ────────────────────────────────────────────
            _DetailAppBar(
              title: collection.arabicName,
              onBack: () => Navigator.of(context).pop(),
            ),

            // ── محتوى الحديث ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── بطاقة رقم الحديث ──────────────────────────
                    _HadithNumberCard(
                      number: hadith.arabicNumber,
                      chapter: collection.translateChapter(hadith.chapter),
                    ),

                    SizedBox(height: 20.h),

                    // ── نص الحديث ─────────────────────────────────
                    _HadithTextCard(text: hadith.text),

                    SizedBox(height: 16.h),

                    // ── أزرار الإجراءات ───────────────────────────
                    _ActionButtons(
                      onCopy: () => _copyHadith(context),
                      onShare: _shareHadith,
                      isFavorite: isFavorite,
                      onFavorite: () => favNotifier.toggle(_hadithId),
                    ),

                    SizedBox(height: 20.h),
                  ],
                ),
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
class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.nightDeep,
            AppColors.nightDeep.withValues(alpha: 0.95),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.15)),
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
                border: Border.all(color: AppColors.borderGold),
                color: AppColors.goldWarm.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.goldLight,
                size: 16.sp,
              ),
            ),
          ),
          const Spacer(),
          Expanded(
            flex: 3,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.agedPlaster,
              ),
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
//  بطاقة رقم الحديث والباب
// ════════════════════════════════════════════════════════════════
class _HadithNumberCard extends StatelessWidget {
  const _HadithNumberCard({required this.number, this.chapter});
  final String number;
  final String? chapter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.goldWarm.withValues(alpha: 0.12),
            AppColors.goldWarm.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.goldWarm.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: AppColors.goldWarm,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'حديث رقم $number',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldLight,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.format_quote_rounded,
                color: AppColors.goldWarm,
                size: 18.sp,
              ),
            ],
          ),
          if (chapter != null && chapter!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.nightDeep.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_rounded,
                    color: AppColors.goldWarm,
                    size: 14.sp,
                  ),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      chapter!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12.sp,
                        color: AppColors.goldLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  بطاقة نص الحديث
// ════════════════════════════════════════════════════════════════
class _HadithTextCard extends StatelessWidget {
  const _HadithTextCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221A40), Color(0xFF1C1535)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.goldWarm.withValues(alpha: 0.20),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldWarm.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.goldWarm.withValues(alpha: 0.0),
                    AppColors.goldWarm,
                    AppColors.goldWarm.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            text,
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 16.sp,
              height: 2.2,
              color: AppColors.agedPlaster,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 16.h),
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.goldWarm.withValues(alpha: 0.0),
                    AppColors.goldWarm,
                    AppColors.goldWarm.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  أزرار الإجراءات — نسخ + مشاركة + مفضلة
// ════════════════════════════════════════════════════════════════
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onCopy,
    required this.onShare,
    required this.isFavorite,
    required this.onFavorite,
  });
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final bool isFavorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.copy_rounded,
            label: 'نسخ',
            onTap: onCopy,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _ActionButton(
            icon: Icons.share_rounded,
            label: 'مشاركة',
            onTap: onShare,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _ActionButton(
            icon: isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: isFavorite ? 'في المفضلة' : 'مفضلة',
            onTap: onFavorite,
            color: isFavorite ? Colors.redAccent : null,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.goldWarm;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              effectiveColor.withValues(alpha: 0.15),
              effectiveColor.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: effectiveColor, size: 18.sp),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: color != null ? effectiveColor : AppColors.goldLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
