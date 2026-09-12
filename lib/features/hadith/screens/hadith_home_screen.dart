import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../models/hadith_collection.dart';
import 'hadith_list_screen_v2.dart';

// ════════════════════════════════════════════════════════════════
//  HadithHomeScreen — شاشة مجموعات الأحاديث
//  مطابق لـ DuaHomeScreen
// ════════════════════════════════════════════════════════════════

class HadithHomeScreen extends StatelessWidget {
  const HadithHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ────────────────────────────────────────────
            _HadithAppBar(onBack: () => Navigator.of(context).pop()),

            // ── القائمة الرئيسية ──────────────────────────────────
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10.w,
                  mainAxisSpacing: 10.h,
                  childAspectRatio: 1.1,
                ),
                itemCount: kHadithCollections.length,
                itemBuilder: (context, index) {
                  final collection = kHadithCollections[index];
                  return _CollectionCard(
                    collection: collection,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HadithListScreenV2(
                            collection: collection,
                          ),
                        ),
                      );
                    },
                  );
                },
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
class _HadithAppBar extends StatelessWidget {
  const _HadithAppBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
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
            'الأحاديث',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.agedPlaster,
            ),
          ),
          const Spacer(),
          Icon(Icons.menu_book_rounded, color: AppColors.goldWarm, size: 18.sp),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Collection Card — بطاقة المجموعة
// ════════════════════════════════════════════════════════════════
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.onTap,
  });
  final HadithCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF221A40), Color(0xFF1C1535)],
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── الأيقونة ──────────────────────────────────────
              Text(
                collection.icon,
                style: TextStyle(fontSize: 32.sp),
              ),
              SizedBox(height: 8.h),

              // ── الاسم العربي ──────────────────────────────────
              Text(
                collection.arabicName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.agedPlaster,
                ),
              ),
              SizedBox(height: 4.h),

              // ── عدد الأحاديث ──────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.goldWarm.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: AppColors.goldWarm.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${collection.totalHadiths} حديث',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.sp,
                    color: AppColors.goldLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
