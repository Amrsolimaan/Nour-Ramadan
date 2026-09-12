import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/azkar_provider.dart';

// ════════════════════════════════════════════════════════════════
//  AthkarScreen — شاشة الأذكار
//  مطابق لـ HTML: .athkar-bg
// ════════════════════════════════════════════════════════════════

class AthkarScreen extends ConsumerStatefulWidget {
  const AthkarScreen({super.key});

  @override
  ConsumerState<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends ConsumerState<AthkarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  static const _tabs = [
    ('أذكار الصباح', ''),
    ('أذكار المساء', ''),
    ('أذكار النوم', ''),
    ('أذكار الاستيقاظ من النوم', ''),
  ];

  // تتبع العدّاد لكل (tabIndex, zekrIndex)
  final Map<String, int> _counters = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (_tabController.index != _selectedTab) {
          setState(() => _selectedTab = _tabController.index);
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _counterKey(int tab, int idx) => '$tab:$idx';

  void _increment(int tab, int idx, int target) {
    final key = _counterKey(tab, idx);
    final current = _counters[key] ?? 0;
    if (current < target) {
      HapticFeedback.lightImpact();
      setState(() => _counters[key] = current + 1);
    }
  }

  void _reset(int tab, int idx) {
    final key = _counterKey(tab, idx);
    setState(() => _counters[key] = 0);
  }

  void _copyZekr(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الذكر',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
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

  @override
  Widget build(BuildContext context) {
    final azkarState = ref.watch(azkarProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ────────────────────────────────────────────
            _AthkarAppBar(onBack: () => Navigator.of(context).pop()),

            // ── تبويبات الفئات ────────────────────────────────────
            _TabsBar(
              tabs: _tabs,
              selectedIndex: _selectedTab,
              onTap: (i) {
                setState(() => _selectedTab = i);
                _tabController.animateTo(i);
              },
            ),

            // ── المحتوى ────────────────────────────────────────────
            Expanded(
              child: azkarState.isLoading
                  ? const _LoadingWidget()
                  : azkarState.error != null
                  ? _ErrorWidget(error: azkarState.error!)
                  : TabBarView(
                      controller: _tabController,
                      children: List.generate(
                        _tabs.length,
                        (ti) => _ZekrList(
                          azkar: azkarState.getCategory(_tabs[ti].$1),
                          tabIndex: ti,
                          counters: _counters,
                          onIncrement: _increment,
                          onReset: _reset,
                          onCopy: _copyZekr,
                        ),
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
class _AthkarAppBar extends StatelessWidget {
  const _AthkarAppBar({required this.onBack});
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
            'الأذكار',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.agedPlaster,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  شريط التبويبات
// ════════════════════════════════════════════════════════════════
class _TabsBar extends StatelessWidget {
  const _TabsBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });
  final List<(String, String)> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46.h,
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.12)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => SizedBox(width: 6.w),
        itemBuilder: (_, i) {
          final isActive = i == selectedIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.goldWarm.withValues(alpha: 0.18)
                    : AppColors.goldWarm.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isActive
                      ? AppColors.goldWarm
                      : AppColors.goldWarm.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tabs[i].$2, style: TextStyle(fontSize: 13.sp)),
                  SizedBox(width: 5.w),
                  Text(
                    // عرض مختصر للتبويب
                    tabs[i].$1.replaceAll('أذكار ', ''),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.sp,
                      color: isActive ? AppColors.goldLight : AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  قائمة الأذكار
// ════════════════════════════════════════════════════════════════
class _ZekrList extends StatelessWidget {
  const _ZekrList({
    required this.azkar,
    required this.tabIndex,
    required this.counters,
    required this.onIncrement,
    required this.onReset,
    required this.onCopy,
  });
  final List<Zekr> azkar;
  final int tabIndex;
  final Map<String, int> counters;
  final void Function(int tab, int idx, int target) onIncrement;
  final void Function(int tab, int idx) onReset;
  final void Function(String text) onCopy;

  @override
  Widget build(BuildContext context) {
    if (azkar.isEmpty) {
      return Center(
        child: Text(
          'لا توجد أذكار في هذه الفئة',
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.textDim,
            fontSize: 14.sp,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      physics: const BouncingScrollPhysics(),
      itemCount: azkar.length,
      itemBuilder: (_, i) {
        final key = '$tabIndex:$i';
        final current = counters[key] ?? 0;
        final target = azkar[i].count.clamp(1, 999);
        final done = current >= target;
        final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

        return _ZekrCard(
          zekr: azkar[i],
          current: current,
          target: target,
          done: done,
          progress: progress,
          onTap: () => onIncrement(tabIndex, i, target),
          onReset: () => onReset(tabIndex, i),
          onCopy: () => onCopy(azkar[i].zekr),
          index: i,
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  بطاقة الذكر — تعادل .ath-card في HTML
// ════════════════════════════════════════════════════════════════
class _ZekrCard extends StatelessWidget {
  const _ZekrCard({
    required this.zekr,
    required this.current,
    required this.target,
    required this.done,
    required this.progress,
    required this.onTap,
    required this.onReset,
    required this.onCopy,
    required this.index,
  });
  final Zekr zekr;
  final int current;
  final int target;
  final bool done;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onReset;
  final VoidCallback onCopy;
  final int index;

  // أول ثلاث بطاقات "Featured"
  bool get _isFeatured => index < 3;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: done
                ? [
                    const Color(0xFF0D2818).withValues(alpha: 0.95),
                    const Color(0xFF0A1F12).withValues(alpha: 0.98),
                  ]
                : _isFeatured
                ? [
                    const Color(0xFF2C224C).withValues(alpha: 0.95),
                    const Color(0xFF1E1638).withValues(alpha: 0.98),
                  ]
                : [
                    const Color(0xFF221A40).withValues(alpha: 0.92),
                    const Color(0xFF161128).withValues(alpha: 0.95),
                  ],
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: done
                ? const Color(0xFF34A862).withValues(alpha: 0.5)
                : _isFeatured
                ? AppColors.goldWarm.withValues(alpha: 0.38)
                : AppColors.goldWarm.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: done
              ? [
                  BoxShadow(
                    color: const Color(0xFF34A862).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: EdgeInsets.all(13.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── نص الذكر ───────────────────────────────────────
              Text(
                zekr.zekr,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 14.sp,
                  height: 2.0,
                  color: done ? const Color(0xFF6ADFA0) : AppColors.agedPlaster,
                ),
              ),

              // ── الفضل (إذا وُجد) ────────────────────────────────
              if (zekr.description.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.goldWarm.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    zekr.description,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.sp,
                      height: 1.7,
                      color: AppColors.textDim,
                    ),
                  ),
                ),
              ],

              SizedBox(height: 8.h),

              // ── شريط التقدم ────────────────────────────────────
              if (target > 1) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.r),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.goldWarm.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      done ? const Color(0xFF34A862) : AppColors.goldWarm,
                    ),
                    minHeight: 2.h,
                  ),
                ),
                SizedBox(height: 8.h),
              ],

              // ── Footer: المصدر + الأزرار ───────────────────────
              Row(
                children: [
                  // ─ أزرار ─────────────────────────────────────
                  _ActionBtn(
                    icon: Icons.copy_rounded,
                    onTap: onCopy,
                    tooltip: 'نسخ',
                  ),
                  SizedBox(width: 5.w),
                  if (current > 0)
                    _ActionBtn(
                      icon: Icons.refresh_rounded,
                      onTap: onReset,
                      tooltip: 'إعادة',
                      color: AppColors.goldWarm.withValues(alpha: 0.6),
                    ),

                  const Spacer(),

                  // ─ المصدر ──────────────────────────────────
                  if (zekr.reference.isNotEmpty)
                    Text(
                      zekr.reference,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10.sp,
                        color: AppColors.goldWarm,
                      ),
                    ),

                  SizedBox(width: 8.w),

                  // ─ العداد ──────────────────────────────────
                  GestureDetector(
                    onTap: done ? onReset : onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: done
                            ? const Color(0xFF34A862).withValues(alpha: 0.15)
                            : AppColors.goldWarm.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: done
                              ? const Color(0xFF34A862).withValues(alpha: 0.4)
                              : AppColors.goldWarm.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (done)
                            Icon(
                              Icons.check_rounded,
                              size: 12.sp,
                              color: const Color(0xFF34A862),
                            )
                          else
                            Icon(
                              Icons.touch_app_rounded,
                              size: 11.sp,
                              color: AppColors.goldLight,
                            ),
                          SizedBox(width: 4.w),
                          Text(
                            done ? 'تم ✓' : '$current / $target',
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12.sp,
                              color: done
                                  ? const Color(0xFF6ADFA0)
                                  : AppColors.goldLight,
                            ),
                          ),
                        ],
                      ),
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

// ════════════════════════════════════════════════════════════════
//  زر إجراء صغير
// ════════════════════════════════════════════════════════════════
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
    this.color,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.goldWarm.withValues(alpha: 0.04),
          border: Border.all(
            color: (color ?? AppColors.goldWarm).withValues(alpha: 0.25),
          ),
        ),
        child: Icon(icon, size: 13.sp, color: color ?? AppColors.goldWarm),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  حالات التحميل / الخطأ
// ════════════════════════════════════════════════════════════════
class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32.w,
            height: 32.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.goldWarm,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'جاري تحميل الأذكار...',
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textDim,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'خطأ في تحميل البيانات',
        style: TextStyle(
          fontFamily: 'Tajawal',
          color: AppColors.textDim,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}
