import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  QuickActionsGrid — شبكة الاختصارات السريعة (2×4)
//  مطابق لـ HTML: .features-grid
//  القرآن، الأدعية، التسبيح، القبلة،
//  أوقات الصلاة، ليلة القدر، الأذكار، تقدمي
// ════════════════════════════════════════════════════════════════

enum QuickAction { quran, dua, tasbih, qibla, prayer, laylat, athkar, progress, library }

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    super.key,
    required this.onTap,
    this.laylatQadrEnabled = true,
  });

  final void Function(QuickAction action) onTap;
  final bool laylatQadrEnabled;

  static const _actions = [
    // ── الصف الأول (الأصلية) ──────────────────────────────────
    _ActionItem(
      action: QuickAction.quran,
      icon: '📖',
      label: 'القرآن الكريم',
      subtitle: 'تلاوة وحفظ',
      gradientColors: [Color(0xFF1E3A2A), Color(0xFF122218)],
      glowColor: Color(0xFF34A862),
    ),
    _ActionItem(
      action: QuickAction.dua,
      icon: '🤲',
      label: 'أدعية وأذكار',
      subtitle: 'حصن المسلم',
      gradientColors: [Color(0xFF2A1E38), Color(0xFF1A1228)],
      glowColor: Color(0xFF9B59B6),
    ),
    _ActionItem(
      action: QuickAction.tasbih,
      icon: '📿',
      label: 'المسبحة',
      subtitle: 'ذكر الله',
      gradientColors: [Color(0xFF2A1A1A), Color(0xFF1A0E0E)],
      glowColor: Color(0xFFC0392B),
    ),
    _ActionItem(
      action: QuickAction.qibla,
      icon: '🧭',
      label: 'اتجاه القبلة',
      subtitle: 'البوصلة',
      gradientColors: [Color(0xFF1A2A3A), Color(0xFF0E1A28)],
      glowColor: Color(0xFF3498DB),
    ),
    // ── الصف الثاني (الجديدة) ─────────────────────────────────
    _ActionItem(
      action: QuickAction.prayer,
      icon: '🕌',
      label: 'أوقات الصلاة',
      subtitle: 'تذكير تلقائي',
      gradientColors: [Color(0xFF1E2A3A), Color(0xFF121820)],
      glowColor: Color(0xFF5DADE2),
    ),
    _ActionItem(
      action: QuickAction.laylat,
      icon: '🌙',
      label: 'ليلة القدر',
      subtitle: 'العشر الأواخر',
      gradientColors: [Color(0xFF1A1A3A), Color(0xFF0E0E28)],
      glowColor: Color(0xFFF0C060),
    ),
    _ActionItem(
      action: QuickAction.athkar,
      icon: '🌿',
      label: 'الأذكار',
      subtitle: 'صباحاً ومساءً',
      gradientColors: [Color(0xFF1A2E1A), Color(0xFF0E1E0E)],
      glowColor: Color(0xFF27AE60),
    ),
    _ActionItem(
      action: QuickAction.progress,
      icon: '⭐',
      label: 'تقدمي',
      subtitle: 'تابع مستواك',
      gradientColors: [Color(0xFF2A2A1A), Color(0xFF1A1A0E)],
      glowColor: Color(0xFFF39C12),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Text(
              'الخدمات السريعة',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.goldLight,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.45,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _actions
                .map(
                  (item) => _ActionCard(
                    item: item,
                    onTap: () => onTap(item.action),
                    isDisabled: item.action == QuickAction.laylat &&
                        !laylatQadrEnabled,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── بطاقة الخدمة ─────────────────────────────────────────────
class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.item,
    required this.onTap,
    this.isDisabled = false,
  });
  final _ActionItem item;
  final VoidCallback onTap;
  final bool isDisabled;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // ✅ تفاعلية دائماً (حتى عند التعطيل)
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Stack(
          children: [
            // ── البطاقة الأساسية ──────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: widget.item.gradientColors,
                ),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: widget.item.glowColor.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.item.glowColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(14.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── أيقونة ──────────────────────────────────
                  Container(
                    width: 38.r,
                    height: 38.r,
                    decoration: BoxDecoration(
                      color: widget.item.glowColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Center(
                      child: Text(
                        widget.item.icon,
                        style: TextStyle(fontSize: 20.sp),
                      ),
                    ),
                  ),
                  // ── نص ──────────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.label,
                        style: TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        widget.item.subtitle,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 9.sp,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ✅ ── طبقة التعطيل (overlay خفيف فقط) ─────────────
            if (widget.isDisabled)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.50),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.action,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.glowColor,
  });
  final QuickAction action;
  final String icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final Color glowColor;
}
