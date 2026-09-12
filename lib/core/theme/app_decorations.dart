import 'package:flutter/material.dart';
import 'app_colors.dart';

/// زخارف وتزيينات جاهزة للاستخدام في كل التطبيق
class AppDecorations {
  AppDecorations._();

  /// الكرت الذهبي الرئيسي — يُستخدم في كل أقسام التطبيق
  static BoxDecoration get goldCard => BoxDecoration(
    gradient: AppColors.cardGradient,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: AppColors.borderGold,
      width: 1,
    ),
    boxShadow: const [
      BoxShadow(
        color:       AppColors.shadowDark,
        blurRadius:  30,
        offset:      Offset(0, 10),
      ),
      BoxShadow(
        color:       Color(0x1AC8922A),
        blurRadius:  0,
        offset:      Offset(0, 1),
        spreadRadius: -1,
      ),
    ],
  );

  /// كرت الميزات الصغير — شبكة الميزات في الرئيسية
  static BoxDecoration get featureCard => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xE6221A40), Color(0xF2160F28)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: AppColors.borderGold,
      width: 1,
    ),
  );

  /// صف الصلاة النشط
  static BoxDecoration get activePrayerRow => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0x26C8922A), Color(0x0DF0C060)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(
      color: AppColors.borderGoldStrong,
      width: 1,
    ),
  );

  /// صف الصلاة العادي
  static BoxDecoration get prayerRow => BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    border: Border.all(
      color: Colors.transparent,
      width: 1,
    ),
  );

  /// بلوك العداد التنازلي
  static BoxDecoration get countdownBlock => BoxDecoration(
    color: const Color(0x14C8922A),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: const Color(0x26C8922A),
      width: 1,
    ),
  );

  /// حاوية الشيخ / الإعداد
  static BoxDecoration get settingRow => BoxDecoration(
    color: const Color(0xCC221A40),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: const Color(0x1FC8922A),
      width: 1,
    ),
  );

  /// خيار الشيخ المحدد
  static BoxDecoration get selectedSheikhOption => BoxDecoration(
    color: const Color(0x1AC8922A),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: AppColors.goldWarm,
      width: 1,
    ),
  );

  /// خيار الشيخ العادي
  static BoxDecoration get sheikhOption => BoxDecoration(
    color: const Color(0xCC221A40),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: const Color(0x1FC8922A),
      width: 1,
    ),
  );

  /// رمز رقم السورة
  static BoxDecoration get surahNumber => BoxDecoration(
    color: const Color(0x1AC8922A),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: const Color(0x4DC8922A),
      width: 1,
    ),
  );

  /// شريط الشيخ في أعلى القرآن
  static BoxDecoration get sheikhBar => const BoxDecoration(
    color: Color(0x0FC8922A),
    border: Border(
      bottom: BorderSide(
        color: Color(0x1AC8922A),
        width: 1,
      ),
    ),
  );

  /// شريط الصوت السفلي
  static BoxDecoration get audioPlayerBar => const BoxDecoration(
    color: Color(0x14C8922A),
    border: Border(
      top: BorderSide(
        color: Color(0x26C8922A),
        width: 1,
      ),
    ),
  );

  /// حاوية بوصلة القبلة
  static BoxDecoration get compassOuter => BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(
      colors: [
        AppColors.goldWarm.withOpacity(0.04),
        Colors.transparent,
      ],
    ),
    border: Border.all(
      color: const Color(0x66C8922A),
      width: 2,
    ),
    boxShadow: const [
      BoxShadow(
        color:      Color(0x1AC8922A),
        blurRadius: 30,
        spreadRadius: 0,
      ),
    ],
  );

  /// زر السبحة الكروي
  static BoxDecoration get tasbihBead => BoxDecoration(
    shape: BoxShape.circle,
    gradient: const RadialGradient(
      colors: [AppColors.goldLight, AppColors.goldWarm, AppColors.goldDim],
      stops: [0.0, 0.6, 1.0],
      center: Alignment(-0.3, -0.3),
    ),
    boxShadow: const [
      BoxShadow(
        color:      AppColors.shadowGold,
        blurRadius: 30,
        spreadRadius: 0,
      ),
      BoxShadow(
        color:      Color(0x33C8922A),
        blurRadius: 60,
        spreadRadius: 0,
      ),
    ],
  );

  /// شريط التقدم الذهبي
  static BoxDecoration get progressBar => BoxDecoration(
    color: const Color(0x26C8922A),
    borderRadius: BorderRadius.circular(2),
  );

  static BoxDecoration get progressBarFill => BoxDecoration(
    gradient: AppColors.goldGradient,
    borderRadius: BorderRadius.circular(2),
  );

  /// حاوية التلميح / المعلومة
  static BoxDecoration get hintBox => BoxDecoration(
    color: const Color(0x14C8922A),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(
      color: const Color(0x26C8922A),
      width: 1,
    ),
  );

  /// شريط نافبار السفلي
  static BoxDecoration get navBar => const BoxDecoration(
    color: Color(0xFA0D0A1A),
    border: Border(
      top: BorderSide(
        color: Color(0x1AC8922A),
        width: 1,
      ),
    ),
  );
}
