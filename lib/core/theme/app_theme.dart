import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.nightDeep,
      fontFamily: AppFonts.tajawal,

      // ─── Color Scheme ─────────────────────────
      colorScheme: const ColorScheme.dark(
        primary:        AppColors.goldWarm,
        secondary:      AppColors.goldLight,
        surface:        AppColors.nightCard,
        onPrimary:      AppColors.nightDeep,
        onSecondary:    AppColors.nightDeep,
        onSurface:      AppColors.textPrimary,
      ),

      // ─── AppBar ──────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor:  Colors.transparent,
        elevation:        0,
        centerTitle:      true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:            Colors.transparent,
          statusBarIconBrightness:   Brightness.light,
          statusBarBrightness:       Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily:  AppFonts.naskh,
          fontSize:    18,
          fontWeight:  FontWeight.w600,
          color:       AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.goldWarm),
      ),

      // ─── Bottom Navigation ────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:     Color(0xFA0D0A1A),
        selectedItemColor:   AppColors.goldWarm,
        unselectedItemColor: AppColors.textDim,
        type:                BottomNavigationBarType.fixed,
        elevation:           0,
        selectedLabelStyle:  TextStyle(
          fontFamily: AppFonts.tajawal,
          fontSize:   10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppFonts.tajawal,
          fontSize:   10,
        ),
      ),

      // ─── Text Theme ───────────────────────────
      textTheme: const TextTheme(
        // العناوين الكبيرة — شاشة Splash والعناوين الرئيسية
        displayLarge: TextStyle(
          fontFamily:  AppFonts.naskh,
          fontSize:    32,
          fontWeight:  FontWeight.w700,
          color:       AppColors.goldLight,
          height:      1.4,
        ),
        // عناوين الصفحات
        titleLarge: TextStyle(
          fontFamily:  AppFonts.naskh,
          fontSize:    20,
          fontWeight:  FontWeight.w600,
          color:       AppColors.textPrimary,
          height:      1.5,
        ),
        // العناوين الثانوية
        titleMedium: TextStyle(
          fontFamily:  AppFonts.tajawal,
          fontSize:    16,
          fontWeight:  FontWeight.w700,
          color:       AppColors.textPrimary,
        ),
        // نص القرآن الكريم
        bodyLarge: TextStyle(
          fontFamily:  AppFonts.naskh,
          fontSize:    22,
          height:      2.2,
          color:       AppColors.textPrimary,
        ),
        // النصوص العامة
        bodyMedium: TextStyle(
          fontFamily:  AppFonts.tajawal,
          fontSize:    14,
          color:       AppColors.textPrimary,
        ),
        // النصوص الصغيرة والتسميات
        bodySmall: TextStyle(
          fontFamily:  AppFonts.tajawal,
          fontSize:    12,
          color:       AppColors.textDim,
        ),
        // الأرقام (عربية) — العداد، الوقت
        displayMedium: TextStyle(
          fontFamily:  AppFonts.amiri,
          fontSize:    48,
          color:       AppColors.goldLight,
          height:      1.0,
        ),
        // الوقت والأرقام المتوسطة
        displaySmall: TextStyle(
          fontFamily:  AppFonts.amiri,
          fontSize:    28,
          color:       AppColors.goldLight,
          letterSpacing: 2,
        ),
      ),

      // ─── Divider ──────────────────────────────
      dividerTheme: const DividerThemeData(
        color:     AppColors.borderGold,
        thickness: 1,
      ),

      // ─── Icon ─────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.goldWarm,
        size:  24,
      ),

      // ─── Ripple Effect ────────────────────────
      splashColor:      AppColors.shadowGold,
      highlightColor:   Colors.transparent,
      splashFactory:    InkRipple.splashFactory,

      // ─── Page Transitions ─────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
