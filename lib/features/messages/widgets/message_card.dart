import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../models/app_message.dart';
import '../screens/message_detail_screen.dart';

// ════════════════════════════════════════════════════════════════
//  MessageCard — بطاقة الرسالة
// ════════════════════════════════════════════════════════════════

class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.message,
    required this.onDelete,
    required this.onMarkAsRead,
    this.isRead = false,
  });

  final AppMessage message;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsRead;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF2A1E4A).withValues(alpha: isRead ? 0.6 : 0.95),
            const Color(0xFF1C1230).withValues(alpha: isRead ? 0.6 : 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isRead
              ? AppColors.borderGold.withValues(alpha: 0.3)
              : AppColors.borderGold,
          width: isRead ? 0.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowGold.withValues(alpha: isRead ? 0.1 : 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          splashColor: AppColors.goldWarm.withValues(alpha: 0.2),
          highlightColor: AppColors.goldLight.withValues(alpha: 0.08),
          onTap: () {
            // فتح صفحة التفاصيل
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MessageDetailScreen(message: message),
              ),
            );
          },
          onLongPress: () {
            // ✅ الضغط المطول لتحديد الرسالة كمقروءة
            if (!isRead) {
              // Haptic feedback
              HapticFeedback.mediumImpact();
              onMarkAsRead();
              
              // إظهار رسالة تأكيد
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم تحديد الرسالة كمقروءة ✓',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.sp,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: AppColors.goldWarm,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                ),
              );
            }
          },
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── الرأس: الأيقونة + النوع + التاريخ + زر الحذف ──
                Row(
                  children: [
                    // الأيقونة
                    Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.goldWarm.withValues(alpha: 0.3),
                            AppColors.goldDim.withValues(alpha: 0.2),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.borderGold,
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          message.displayIcon,
                          style: TextStyle(fontSize: 16.sp),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    // النوع
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldWarm.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        message.type.label,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 9.sp,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // التاريخ
                    Text(
                      _formatDate(message.timestamp),
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9.sp,
                        color: AppColors.textDim,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // زر الحذف
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        width: 28.r,
                        height: 28.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red.withValues(alpha: 0.8),
                          size: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // ── العنوان ──────────────────────────────────────
                Text(
                  message.title,
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isRead
                        ? AppColors.textPrimary.withValues(alpha: 0.7)
                        : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6.h),
                // ── المحتوى (مقطوع بـ 3 أسطر) ──────────────────────
                Text(
                  message.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12.sp,
                    height: 1.6,
                    color: isRead
                        ? AppColors.textDim.withValues(alpha: 0.6)
                        : AppColors.textDim,
                  ),
                ),
                // ✅ مؤشر "جديد" - يظهر للرسائل غير المقروءة والحديثة (آخر 48 ساعة)
                // يختفي إما بالضغط المطول أو بعد 48 ساعة تلقائياً
                if (!isRead && _isRecent(message.timestamp)) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Container(
                        width: 6.r,
                        height: 6.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.goldLight,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldGlow,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'جديد',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 9.sp,
                          color: AppColors.goldLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      // تلميح بسيط للضغط المطول
                      Text(
                        '(اضغط مطولاً للتحديد كمقروء)',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 7.sp,
                          color: AppColors.textDim.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── التحقق من أن الرسالة حديثة (آخر 48 ساعة) ──────────────────
  bool _isRecent(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    return diff.inHours < 48;
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
}
