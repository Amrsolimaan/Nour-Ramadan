import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/quran/screens/quran_home_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/tasbih/screens/tasbih_screen.dart';
import '../../features/favorites/screens/favorites_screen.dart';

// ════════════════════════════════════════════════════════════════
//  AppBottomNavBar — شريط التنقل السفلي المشترك
//  يُستخدم في جميع الصفحات الرئيسية
// ════════════════════════════════════════════════════════════════

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, required this.currentIndex});

  final int currentIndex;

  static const _items = [
    ('🏠', 'الرئيسية', 0),
    ('📖', 'القرآن', 1),
    ('⭐', 'المفضل', 2),
    ('⚙️', 'الإعدادات', 3),
    ('📿', 'التسبيح', 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.nightMid.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: AppColors.borderGold, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldWarm.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _items.length,
              (i) => _NavItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                isActive: i == currentIndex,
                onTap: () => _onNavTap(context, _items[i].$3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onNavTap(BuildContext context, int index) {
    // إذا كنا بالفعل في نفس الصفحة، لا نفعل شيء
    if (index == currentIndex) return;

    switch (index) {
      case 0: // الرئيسية
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const HomeScreen()));
        break;
      case 1: // القرآن
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const QuranHomeScreen()));
        break;
      case 2: // المفضل
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FavoritesScreen()));
        break;
      case 3: // الإعدادات
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
      case 4: // التسبيح
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TasbihScreen()));
        break;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  _NavItem — عنصر واحد في شريط التنقل
// ════════════════════════════════════════════════════════════════

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.goldWarm.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: isActive
              ? Border.all(color: AppColors.borderGoldStrong, width: 1.0)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: 18.sp)),
            SizedBox(height: 3.h),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 9.sp,
                color: isActive ? AppColors.goldLight : AppColors.textDim,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
