import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/offline_quran_service.dart';
import '../../../core/data/juz_data.dart';
import 'quran_reader_screen.dart'; // ════════════════════════════════════════════════════════════════
//  JuzViewScreenV2 — عرض محتوى الجزء Offline-First
//  يستخدم البيانات المحلية من juz_data.dart
// ════════════════════════════════════════════════════════════════

class JuzViewScreenV2 extends ConsumerStatefulWidget {
  final int juzNumber;

  const JuzViewScreenV2({super.key, required this.juzNumber});

  @override
  ConsumerState<JuzViewScreenV2> createState() => _JuzViewScreenV2State();
}

class _JuzViewScreenV2State extends ConsumerState<JuzViewScreenV2> {
  List<JuzSection>? _sections;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJuzData();
  }

  Future<void> _loadJuzData() async {
    setState(() => _isLoading = true);

    final service = ref.read(offlineQuranServiceProvider);
    final sections = service.getJuzSections(widget.juzNumber);

    setState(() {
      _sections = sections;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.goldWarm,
                      ),
                    )
                  : _sections == null || _sections!.isEmpty
                  ? _buildEmpty()
                  : _buildContent(context, _sections!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.nightCard.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderGold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
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
            'جزء ${_toArabicNum(widget.juzNumber)}',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 20.sp,
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

  Widget _buildContent(BuildContext context, List<JuzSection> sections) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _buildSurahItem(context, section);
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        'لا توجد بيانات لهذا الجزء',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14.sp,
          color: AppColors.textDim,
        ),
      ),
    );
  }

  Widget _buildSurahItem(BuildContext context, JuzSection section) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ModernQuranReaderV2(
              surahNumber: section.surahNumber,
              initialAyah: section.fromAyah,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.goldWarm.withValues(alpha: 0.15),
              AppColors.nightCard.withValues(alpha: 0.5),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.borderGold.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50.w,
              height: 50.w,
              decoration: BoxDecoration(
                color: AppColors.goldWarm.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.borderGold.withValues(alpha: 0.5),
                ),
              ),
              child: Center(
                child: Text(
                  '${section.page}',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    section.surahName,
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldLight,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'من الآية ${section.fromAyah} إلى ${section.toAyah}',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.sp,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.goldLight.withValues(alpha: 0.5),
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  String _toArabicNum(int num) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return num.toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join();
  }
}
