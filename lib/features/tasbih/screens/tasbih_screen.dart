import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../providers/tasbih_provider.dart';

// ════════════════════════════════════════════════════════════════
//  TasbihScreen — شاشة التسبيح
// ════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════
//  دالة تنسيق الأرقام الكبيرة (موحدة)
//  1,000 → 1.0K
//  1,000,000 → 1.0M
//  1,000,000,000 → 1.0B
// ════════════════════════════════════════════════════════════════
String _formatLargeNumber(int number) {
  if (number >= 1000000000) {
    return '${(number / 1000000000).toStringAsFixed(1)}B';
  } else if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toString();
}
class TasbihScreen extends ConsumerStatefulWidget {
  const TasbihScreen({super.key});

  @override
  ConsumerState<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends ConsumerState<TasbihScreen> {
  late AudioPlayer _bellPlayer;

  @override
  void initState() {
    super.initState();
    _bellPlayer = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      // تحميل صوت الجرس فقط
      await _bellPlayer.setAsset('assets/audio/gentle_bell.mp3');
      await _bellPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint('Error loading tasbih sounds: $e');
    }
  }

  Future<void> _playBell() async {
    try {
      await _bellPlayer.seek(Duration.zero);
      await _bellPlayer.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _bellPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasbihProvider);
    final notifier = ref.read(tasbihProvider.notifier);

    return Scaffold(
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 4),
      backgroundColor: AppColors.nightDeep,
      body: Container(
        // .tasbih-bg
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.3,
            colors: [Color(0xFF1C1040), Color(0xFF08061A)],
            stops: [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // ── AppBar ─────────────────────────────────────────
                    _TasbihAppBar(onBack: () => Navigator.of(context).pop()),

                    if (state.isLoading)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      // ── إحصائيات ─────────────────────────────────────
                      _StatsHeader(
                        daily: state.dailyTotal,
                        monthly: state.monthlyTotal,
                      ),

                      SizedBox(height: 16.h),

                      SizedBox(height: 24.h),

                      // ── الزر الكبير (المسبحة) ────────────────────────
                      _BeadButton(
                        count: state.activeItem.count,
                        target: state.activeItem.target,
                        label: state.activeItem.label,
                        onTap: () async {
                          // التحقق مما إذا كان سيتم الوصول للهدف في هذه الضغطة
                          final willReachTarget =
                              state.activeItem.target > 0 &&
                              state.activeItem.count + 1 ==
                                  state.activeItem.target;

                          notifier.increment();

                          if (willReachTarget) {
                            _playBell();
                            if (await Vibration.hasVibrator() ?? false) {
                              Vibration.vibrate(duration: 100);
                            }
                          } else {
                            // تمت إزالة صوت النقر بناءً على طلب المستخدم
                            if (await Vibration.hasVibrator() ?? false) {
                              Vibration.vibrate(duration: 30);
                            }
                          }
                        },
                        onReset: () => notifier.resetItem(state.activeItem.id),
                      ),

                      SizedBox(height: 8.h),

                      // ── قائمة الأذكار (الأسفل) ───────────────────────
                      _BottomControls(
                        items: state.items,
                        activeIndex: state.activeIndex,
                        onSelect: (index) => notifier.setActive(index),
                        onAdd: () => _showAddDialog(context, notifier),
                        onLongPress: (item) =>
                            _showEditDeleteDialog(context, notifier, item),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, TasbihNotifier notifier) {
    final textController = TextEditingController();
    final countController = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (_) => _TasbihDialog(
        title: 'إضافة ذكر جديد',
        confirmText: 'إضافة',
        textController: textController,
        countController: countController,
        onConfirm: () {
          if (textController.text.isNotEmpty) {
            notifier.addZekr(
              textController.text,
              int.tryParse(countController.text) ?? 33,
            );
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showEditDeleteDialog(
    BuildContext context,
    TasbihNotifier notifier,
    TasbihItem item,
  ) {
    final textController = TextEditingController(text: item.label);
    final countController = TextEditingController(text: item.target.toString());

    showDialog(
      context: context,
      builder: (_) => _TasbihDialog(
        title: 'تعديل الذكر',
        confirmText: 'حفظ',
        isEdit: true,
        textController: textController,
        countController: countController,
        onConfirm: () {
          if (textController.text.isNotEmpty) {
            notifier.editZekr(
              item.id,
              textController.text,
              int.tryParse(countController.text) ?? 33,
            );
            Navigator.pop(context);
          }
        },
        onDelete: () {
          notifier.deleteZekr(item.id);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  AppBar
// ════════════════════════════════════════════════════════════════
class _TasbihAppBar extends StatelessWidget {
  const _TasbihAppBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child:Container(
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
            'السبحة الإلكترونية',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.agedPlaster,
            ),
          ),
          const Spacer(),
          // Icon(Icons.volunteer_activism_rounded) removed per user request
          SizedBox(width: 20.w), // Keep spacing consistent
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Stats Header (Daily/Monthly)
// ════════════════════════════════════════════════════════════════
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.daily, required this.monthly});
  final int daily;
  final int monthly;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'مجموع اليوم', value: daily),
          Container(
            width: 1,
            height: 30.h,
            color: AppColors.goldWarm.withValues(alpha: 0.2),
          ),
          _StatItem(label: 'مجموع الشهر', value: monthly),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _formatLargeNumber(value), // ✅ تطبيق التنسيق
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: 22.sp,
            color: AppColors.goldLight,
            height: 1.0,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10.sp,
            color: AppColors.textDim,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Bead Button (The Big One)
// ════════════════════════════════════════════════════════════════
class _BeadButton extends StatelessWidget {
  const _BeadButton({
    required this.count,
    required this.target,
    required this.label,
    required this.onTap,
    required this.onReset,
  });

  final int count;
  final int target;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? count / target : 0.0;

    return Column(
      children: [
        // اسم الذكر - ارتفاع ثابت
        SizedBox(
          height: 50.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Center(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.agedPlaster,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // الزر الدائري مع شريط التقدم
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // شريط التقدم الدائري
              SizedBox(
                width: 180.w,
                height: 180.w,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6.w,
                  backgroundColor: AppColors.goldWarm.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.goldWarm,
                  ),
                ),
              ),
              // الدائرة الرئيسية
              Container(
                width: 160.w,
                height: 160.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.3),
                    colors: [
                      Color(0xFFF0C060),
                      Color(0xFFC8922A),
                      Color(0xFF8B6520),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldWarm.withValues(alpha: 0.4),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 145.w,
                    height: 145.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.nightDeep.withValues(alpha: 0.95),
                          Colors.black,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 52.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.goldLight,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: AppColors.goldWarm.withValues(alpha: 0.6),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'الهدف: $target',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11.sp,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
              .animate(target: count > 0 ? 1 : 0)
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(0.96, 0.96),
                duration: 100.ms,
                curve: Curves.easeInOut,
              ),
        ),

        SizedBox(height: 24.h),

        // إعادة التعيين
        IconButton(
          onPressed: onReset,
          icon: Icon(
            Icons.refresh_rounded,
            color: AppColors.textDim.withValues(alpha: 0.6),
            size: 24.sp,
          ),
          tooltip: 'تصفير العداد',
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Bottom Controls (List + Add Button)
// ════════════════════════════════════════════════════════════════
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.items,
    required this.activeIndex,
    required this.onSelect,
    required this.onAdd,
    required this.onLongPress,
  });

  final List<TasbihItem> items;
  final int activeIndex;
  final Function(int) onSelect;
  final Function(TasbihItem) onLongPress;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.03),
        border: Border(
          top: BorderSide(
            color: AppColors.goldWarm.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // عنوان القسم
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الأذكار المحفوظة',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.sp,
                  color: AppColors.textDim,
                ),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.goldWarm.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        color: AppColors.goldLight,
                        size: 16.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'إضافة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.sp,
                          color: AppColors.goldLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          
          // Grid الأزرار - 3 في كل صف
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            alignment: WrapAlignment.end, // من اليمين
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = index == activeIndex;
              return GestureDetector(
                onTap: () => onSelect(index),
                onLongPress: () => onLongPress(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: (MediaQuery.of(context).size.width - 52.w) / 3, // 3 أزرار في الصف
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            colors: [
                              AppColors.goldWarm.withValues(alpha: 0.25),
                              AppColors.goldWarm.withValues(alpha: 0.15),
                            ],
                          )
                        : null,
                    color: isActive ? null : AppColors.goldWarm.withValues(alpha: 0.05),
                    border: Border.all(
                      color: isActive
                          ? AppColors.goldWarm
                          : AppColors.goldWarm.withValues(alpha: 0.2),
                      width: isActive ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.goldWarm.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // المحتوى الرئيسي
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // النص بارتفاع ثابت
                          SizedBox(
                            height: 32.h,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.only(right: 20.w), // مساحة للأيقونة من اليمين
                                child: Text(
                                  item.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'NotoNaskhArabic',
                                    fontSize: 12.sp, // زيادة من 11 إلى 12
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                    color: isActive ? AppColors.goldLight : AppColors.textDim,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${item.count}/${item.target}',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11.sp, // زيادة من 10 إلى 11
                              color: isActive
                                  ? AppColors.goldWarm
                                  : AppColors.textDim.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      // أيقونة التعديل - في الزاوية اليمنى العلوية
                      Positioned(
                        top: 2.h,
                        right: 2.w,
                        child: GestureDetector(
                          onTap: () => onLongPress(item),
                          child: Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: isActive 
                                  ? AppColors.goldWarm.withValues(alpha: 0.3)
                                  : AppColors.goldWarm.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: AppColors.goldWarm.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 10.sp,
                              color: AppColors.goldLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Dialog
// ════════════════════════════════════════════════════════════════
class _TasbihDialog extends StatelessWidget {
  const _TasbihDialog({
    required this.title,
    required this.confirmText,
    required this.textController,
    required this.countController,
    required this.onConfirm,
    this.isEdit = false,
    this.onDelete,
  });

  final String title;
  final String confirmText;
  final bool isEdit;
  final TextEditingController textController;
  final TextEditingController countController;
  final VoidCallback onConfirm;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1040),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
        side: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 18.sp,
                  color: AppColors.goldLight,
                ),
              ),
              SizedBox(height: 20.h),

              // حقل الاسم
              TextField(
                controller: textController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'نص الذكر',
                  labelStyle: TextStyle(color: AppColors.textDim),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.textDim),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.goldWarm),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // حقل العدد
              TextField(
                controller: countController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'العدد المستهدف',
                  labelStyle: TextStyle(color: AppColors.textDim),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.textDim),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.goldWarm),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              Row(
                children: [
                  if (isEdit) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        child: const Text('حذف'),
                      ),
                    ),
                    SizedBox(width: 8.w),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldWarm,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
