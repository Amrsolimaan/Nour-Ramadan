import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nour_ramadan/features/messages/models/app_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../painting/cairo_street_painter.dart';
import '../../../painting/lantern_painter.dart';
import '../../../shared/animations/reveal_animation.dart';
import '../providers/messages_provider.dart';
import '../widgets/message_card.dart';

// ════════════════════════════════════════════════════════════════
//  MessagesScreen — شاشة الرسائل من Firebase
//  "رسائل منا لك.. 💜"
// ════════════════════════════════════════════════════════════════

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ تحديد الرسائل المعروضة كمقروءة عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesProvider.notifier).markDisplayedAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 1. خلفية مباني القاهرة ────────────────────────────
          Positioned.fill(child: CairoStreetBackground(isNight: true)),

          // ── 2. فوانيس ─────────────────────────────────────────
          const _MessagesLanterns(),

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

                // ─ العنوان الرئيسي ───────────────────────────────
                RevealAnimation(
                  delay: const Duration(milliseconds: 100),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      children: [
                        Text(
                          'رسائل منا لك.. ',
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldLight,
                            shadows: [
                              Shadow(
                                color: AppColors.goldGlow.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 6.h),
                        // ✅ إصلاح: إضافة خلفية داكنة للنص
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'نتواصل معك لنشارك أخبار التطبيق وتحديثاته',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11.sp,
                              color: AppColors.goldLight,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                // ─ أزرار الفلترة ──────────────────────────────────
                RevealAnimation(
                  delay: const Duration(milliseconds: 150),
                  child: _FilterTabs(
                    selectedFilter: state.selectedFilter,
                    onFilterChanged: (type) =>
                        ref.read(messagesProvider.notifier).setFilter(type),
                  ),
                ),

                SizedBox(height: 16.h),

                // ─ محتوى الصفحة ──────────────────────────────────
                Expanded(
                  child: state.isLoading
                      ? const _LoadingIndicator()
                      : state.hasError && state.messages.isEmpty
                      ? _ErrorView(
                          error: state.error!,
                          onRetry: () =>
                              ref.read(messagesProvider.notifier).refresh(),
                        )
                      : state.filteredMessages.isEmpty
                      ? _EmptyView(selectedFilter: state.selectedFilter)
                      : Column(
                          children: [
                            // بانر الخطأ فقط للأخطاء الحقيقية (permission-denied, failed-precondition)
                            if (state.hasError &&
                                (state.error!.contains('صلاحية') ||
                                    state.error!.contains('الفهرس')))
                              _ErrorBanner(
                                message: state.error!,
                                isOffline: state.isOffline,
                                onRetry: () => ref
                                    .read(messagesProvider.notifier)
                                    .refresh(),
                              ),
                            // قائمة الرسائل
                            Expanded(
                              child: _MessagesList(
                                messages: state.filteredMessages,
                                onDelete: (id) => _confirmDelete(context, id),
                              ),
                            ),
                          ],
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
    final state = ref.watch(messagesProvider);
    final isRefreshing = state.loadingState == MessageLoadingState.syncing;

    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 45.h, // ✅ زيادة المسافة من الأعلى
        bottom: 20.h,
      ),
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
          const Spacer(),
          // زر تحديد الكل كمقروء
          GestureDetector(
            onTap: () => ref.read(messagesProvider.notifier).markAllAsRead(),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: AppColors.borderGold),
                color: AppColors.goldWarm.withValues(alpha: 0.08),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.done_all,
                    color: AppColors.goldLight,
                    size: 16.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'تحديد الكل كمقروء',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.sp,
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // زر التحديث
          GestureDetector(
            onTap: isRefreshing
                ? null
                : () => ref.read(messagesProvider.notifier).refresh(),
            child: Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderGold),
                color: AppColors.goldWarm.withValues(alpha: 0.08),
              ),
              child: isRefreshing
                  ? Padding(
                      padding: EdgeInsets.all(8.r),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.goldLight,
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      color: AppColors.goldLight,
                      size: 16.sp,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── تأكيد الحذف ─────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context, String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.nightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'حذف الرسالة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 16.sp,
            color: AppColors.goldLight,
          ),
        ),
        content: Text(
          'هل تريد حذف هذه الرسالة؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13.sp,
            color: AppColors.textDim,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'حذف',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(messagesProvider.notifier).deleteMessage(messageId);
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  _MessagesList — قائمة الرسائل
// ════════════════════════════════════════════════════════════════

class _MessagesList extends ConsumerWidget {
  const _MessagesList({required this.messages, required this.onDelete});

  final List messages;
  final Function(String) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readIds = ref.read(messagesProvider.notifier).getReadMessageIds();
    final state = ref.watch(messagesProvider);
    
    return RefreshIndicator(
      onRefresh: () => ref.read(messagesProvider.notifier).refresh(),
      color: AppColors.goldWarm,
      backgroundColor: AppColors.nightCard,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 40.h),
        itemCount: messages.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          // زر "تحميل المزيد" في النهاية
          if (i == messages.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: ElevatedButton(
                  onPressed: () => ref.read(messagesProvider.notifier).loadMore(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldWarm.withValues(alpha: 0.15),
                    foregroundColor: AppColors.goldLight,
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                      side: BorderSide(color: AppColors.borderGold),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.expand_more, size: 18.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'تحميل المزيد',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          
          final message = messages[i];
          final isRead = readIds.contains(message.id);
          
          return RevealAnimation(
            delay: Duration(milliseconds: i * 50),
            child: MessageCard(
              message: message,
              isRead: isRead,
              onDelete: () => onDelete(message.id),
              onMarkAsRead: () {
                // ✅ تحديد الرسالة كمقروءة عند الضغط المطول
                ref.read(messagesProvider.notifier).markAsRead(message.id);
              },
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _EmptyView — عرض فارغ
// ════════════════════════════════════════════════════════════════

class _EmptyView extends StatelessWidget {
  const _EmptyView({this.selectedFilter});
  
  final MessageType? selectedFilter;

  @override
  Widget build(BuildContext context) {
    // رسائل مخصصة حسب نوع الفلتر
    String emoji;
    String title;
    String subtitle;

    switch (selectedFilter) {
      case MessageType.update:
        emoji = '🔄';
        title = 'لا توجد تحديثات حالياً';
        subtitle = 'سنخبرك بأي تحديثات جديدة للتطبيق';
        break;
      case MessageType.help:
        emoji = '🔍';
        title = 'جاري البحث عن أشخاص يحتاجون للمساعدة';
        subtitle = 'سنعرض هنا المشاكل التي تحتاج لمساعدتك بشكل دقيق';
        break;
      case MessageType.info:
        emoji = 'ℹ️';
        title = 'لا توجد معلومات حالياً';
        subtitle = 'سنشارك معك معلومات مفيدة هنا';
        break;
      case MessageType.announcement:
        emoji = '📢';
        title = 'لا توجد إعلانات حالياً';
        subtitle = 'سنخبرك بأي إعلانات مهمة';
        break;
      default:
        emoji = '📭';
        title = 'لا توجد رسائل حالياً';
        subtitle = 'سنرسل لك رسائل مهمة هنا';
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 48.sp)),
            SizedBox(height: 16.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 16.sp,
                color: AppColors.textDim,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.sp,
                color: AppColors.textDim.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _ErrorBanner — بانر الخطأ في الأعلى
// ════════════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.isOffline,
    required this.onRetry,
  });

  final String message;
  final bool isOffline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isOffline
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isOffline
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.wifi_off : Icons.error_outline,
            color: isOffline ? Colors.orange : Colors.red,
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.sp,
                color: isOffline ? Colors.orange : Colors.red,
              ),
            ),
          ),
          if (!isOffline)
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  'إعادة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.sp,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _ErrorView — عرض الخطأ
// ════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('⚠️', style: TextStyle(fontSize: 48.sp)),
          SizedBox(height: 16.h),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13.sp,
              color: AppColors.textDim,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldWarm,
              foregroundColor: AppColors.nightDeep,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              'إعادة المحاولة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _LoadingIndicator — مؤشر التحميل
// ════════════════════════════════════════════════════════════════

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 32.r,
        height: 32.r,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.goldWarm,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _FilterTabs — أزرار الفلترة
// ════════════════════════════════════════════════════════════════

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final MessageType? selectedFilter;
  final Function(MessageType?) onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        children: [
          _FilterChip(
            label: 'الكل',
            icon: '',
            isSelected: selectedFilter == null,
            onTap: () => onFilterChanged(null),
          ),
          SizedBox(width: 8.w),
          _FilterChip(
            label: 'تحديثات',
            icon: '',
            isSelected: selectedFilter == MessageType.update,
            onTap: () => onFilterChanged(MessageType.update),
          ),
          SizedBox(width: 8.w),
          _FilterChip(
            label: 'معلومات',
            icon: '',
            isSelected: selectedFilter == MessageType.info,
            onTap: () => onFilterChanged(MessageType.info),
          ),
          SizedBox(width: 8.w),
          _FilterChip(
            label: 'مساعدة',
            icon: '',
            isSelected: selectedFilter == MessageType.help,
            onTap: () => onFilterChanged(MessageType.help),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _FilterChip — زر فلتر واحد
// ════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        splashColor: AppColors.goldWarm.withValues(alpha: 0.3),
        highlightColor: AppColors.goldLight.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.goldWarm.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected
                  ? AppColors.goldWarm
                  : AppColors.borderGold.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: TextStyle(fontSize: 14.sp)),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.goldLight : AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _MessagesLanterns — فوانيس شاشة الرسائل
// ════════════════════════════════════════════════════════════════

class _MessagesLanterns extends StatelessWidget {
  const _MessagesLanterns();

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
