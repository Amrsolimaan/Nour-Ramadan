import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/quran_service.dart';
import '../providers/quran_progress_provider.dart';
import '../providers/last_read_provider.dart';
import 'quran_reader_screen.dart'; // ════════════════════════════════════════════════════════════════
//  SurahListScreen — قائمة السور الـ 114
//  يمكن استخدامها:
//  • مستقلة (شاشة كاملة)
//  • مدمجة داخل QuranHomeScreen (embedded: true)
// ════════════════════════════════════════════════════════════════

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key, this.embedded = false, this.onSurahTap});

  final bool embedded;
  final void Function(SurahInfo surah)? onSurahTap;

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  final _ctrl = TextEditingController();
  String _query = '';
  List<SurahInfo> get _list => QuranDataService.instance.search(_query);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (!widget.embedded) ...[_buildAppBar(context)],
        _buildSearch(),
        Expanded(child: _buildList()),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(child: content),
    );
  }

  // ── AppBar (للاستخدام المستقل فقط) ────────────────────────────
  Widget _buildAppBar(BuildContext context) {
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
            'السور',
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

  // ── بحث ────────────────────────────────────────────────────────
  Widget _buildSearch() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Container(
        height: 40.h,
        decoration: BoxDecoration(
          color: AppColors.nightCard,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.borderGold),
        ),
        child: TextField(
          controller: _ctrl,
          textDirection: TextDirection.rtl,
          onChanged: (v) => setState(() => _query = v.trim()),
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13.sp,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث عن سورة...',
            hintStyle: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.sp,
              color: AppColors.textDim,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppColors.textDim,
              size: 16.sp,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
          ),
        ),
      ),
    );
  }

  // ── القائمة ─────────────────────────────────────────────────────
  Widget _buildList() {
    final list = _list;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 40.h),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final surah = list[i];
        return _SurahTile(
          surah: surah,
          onTap: () {
            if (widget.onSurahTap != null) {
              widget.onSurahTap?.call(surah);
            } else {
              // الانتقال إلى القارئ الحديث
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ModernQuranReaderV2(surahNumber: surah.number),
                ),
              );
            }
          },
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _SurahTile — بطاقة السورة
// ════════════════════════════════════════════════════════════════
class _SurahTile extends ConsumerWidget {
  const _SurahTile({required this.surah, required this.onTap});
  final SurahInfo surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressState = ref.watch(quranProgressProvider);
    final isRead = progressState.readSurahs.contains(surah.number);
    final lastReadAyah = ref.watch(lastReadProvider).ayahForSurah(surah.number);

    return Container(
      margin: EdgeInsets.only(bottom: 7.h),
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isRead
              ? Colors.green.withValues(alpha: 0.5)
              : AppColors.borderGold,
          width: isRead ? 1.5 : 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          splashColor: AppColors.goldWarm.withValues(alpha: 0.3),
          highlightColor: AppColors.goldLight.withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Row(
              children: [
                // رقم السورة في إطار ماسي
                _NumberBadge(number: surah.number, isRead: isRead),
                SizedBox(width: 12.w),
                // الاسم والنوع
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        surah.name,
                        style: TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${surah.ayahCount} آية',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10.sp,
                              color: AppColors.textDim,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 1.h,
                            ),
                            decoration: BoxDecoration(
                              color: surah.type == SurahType.makki
                                  ? AppColors.goldWarm.withValues(alpha: 0.15)
                                  : const Color(0xFF1A4A2E),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              surah.typeLabel,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 9.sp,
                                color: surah.type == SurahType.makki
                                    ? AppColors.goldLight
                                    : const Color(0xFF34A862),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // ── شارة "آخر قراءة" (ذهبية — مميّزة عن مؤشر "مقروءة" الأخضر) ──
                      if (lastReadAyah != null) ...[
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 1.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goldWarm.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                              color: AppColors.goldWarm.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bookmark_border_rounded,
                                size: 10.sp,
                                color: AppColors.goldLight,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'آخر قراءة: آية $lastReadAyah',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 9.sp,
                                  color: AppColors.goldLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.textDim,
                  size: 11.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── رقم السورة ─────────────────────────────────────────────────
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, this.isRead = false});
  final int number;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40.r,
      height: 40.r,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // خلفية ماسية
          Transform.rotate(
            angle: 0.785, // 45°
            child: Container(
              width: 30.r,
              height: 30.r,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isRead
                      ? [
                          Colors.green.withValues(alpha: 0.50),
                          Colors.green.withValues(alpha: 0.30),
                        ]
                      : [
                          AppColors.goldWarm.withValues(alpha: 0.40),
                          AppColors.goldDim.withValues(alpha: 0.20),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isRead ? Colors.green : AppColors.borderGold,
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          Text(
            '$number',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: isRead ? Colors.green : AppColors.goldLight,
            ),
          ),
        ],
      ),
    );
  }
}
