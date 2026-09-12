import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../painting/cairo_street_painter.dart';
import '../../../painting/lantern_painter.dart';
import '../../../shared/animations/reveal_animation.dart';
import '../models/app_message.dart';

// ══════════════════════════════════════════════════════════════
//  MessageDetailScreen — صفحة تفاصيل الرسالة
//  تعرض رسالة واحدة بالكامل مع إمكانية التمرير للمحتوى الطويل
// ════════════════════════════════════════════════════════════════

class MessageDetailScreen extends StatelessWidget {
  const MessageDetailScreen({super.key, required this.message});

  final AppMessage message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 1. خلفية مباني القاهرة ────────────────────────────
          Positioned.fill(child: CairoStreetBackground(isNight: true)),

          // ── 2. فوانيس ─────────────────────────────────────────
          const _DetailLanterns(),

          // ── 3. تدرج فوق الخلفية ───────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    AppColors.nightDeep.withValues(alpha: 0.70),
                    AppColors.nightDeep.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),

          // ── 4. المحتوى ────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ─ AppBar ────────────────────────────────────────
                _buildAppBar(context),
                SizedBox(height: 20.h),

                // ─ المحتوى القابل للتمرير ────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 40.h),
                    child: RevealAnimation(
                      delay: const Duration(milliseconds: 100),
                      child: _MessageDetailCard(message: message),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: [
          // زر الرجوع
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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
          SizedBox(width: 12.w),
          // العنوان
          Expanded(
            child: Text(
              'تفاصيل الرسالة',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.goldLight,
                shadows: [
                  Shadow(
                    color: AppColors.goldGlow.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _MessageDetailCard — بطاقة تفاصيل الرسالة
// ════════════════════════════════════════════════════════════════

class _MessageDetailCard extends StatelessWidget {
  const _MessageDetailCard({required this.message});

  final AppMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF2A1E4A).withValues(alpha: 0.95),
            const Color(0xFF1C1230).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.borderGold,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowGold.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── الرأس: الأيقونة + النوع + التاريخ ──────────────
          Row(
            children: [
              // الأيقونة
              Container(
                width: 48.r,
                height: 48.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.goldWarm.withValues(alpha: 0.4),
                      AppColors.goldDim.withValues(alpha: 0.3),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.borderGold,
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    message.displayIcon,
                    style: TextStyle(fontSize: 24.sp),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // النوع
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldWarm.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: AppColors.borderGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        message.type.label,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.sp,
                          color: AppColors.goldLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    // التاريخ
                    Text(
                      _formatDate(message.timestamp),
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10.sp,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // ── خط فاصل زخرفي ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.borderGold.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // ── العنوان ────────────────────────────────────────
          Text(
            message.title,
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),

          SizedBox(height: 16.h),

          // ── المحتوى الكامل ─────────────────────────────────
          Text(
            message.body,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14.sp,
              height: 1.8,
              color: AppColors.textDim,
            ),
          ),

          SizedBox(height: 20.h),

          // ── خط فاصل زخرفي ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.borderGold.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // ── معلومات إضافية ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time,
                size: 12.sp,
                color: AppColors.textDim.withValues(alpha: 0.6),
              ),
              SizedBox(width: 4.w),
              Text(
                'تم الإرسال: ${_formatFullDate(message.timestamp)}',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10.sp,
                  color: AppColors.textDim.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'اليوم ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays == 1) {
      return 'أمس';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} أيام';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  String _formatFullDate(DateTime date) {
    return DateFormat('dd/MM/yyyy - HH:mm').format(date);
  }
}

// ════════════════════════════════════════════════════════════════
//  _DetailLanterns — فوانيس صفحة التفاصيل
// ════════════════════════════════════════════════════════════════

class _DetailLanterns extends StatelessWidget {
  const _DetailLanterns();

  static const _data = [
    (0.08, 38.0, Color(0xFF8B3A24), Color(0xFFFF7050)),
    (0.32, 30.0, Color(0xFF6B4A1C), Color(0xFFFFB040)),
    (0.68, 30.0, Color(0xFF3A2A60), Color(0xFF8860FF)),
    (0.92, 35.0, Color(0xFF6B4A1C), Color(0xFFFFAA30)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _data.map((l) {
        return Positioned(
          top: -l.$2 * 0.20,
          left: l.$1 * 1.sw - l.$2 / 2,
          child: LanternWidget(
            color: l.$3,
            glowColor: l.$4,
            size: l.$2.r,
            stringLength: 0.38,
            swayDuration: const Duration(milliseconds: 3600),
          ),
        );
      }).toList(),
    );
  }
}
