import 'package:flutter/material.dart';

/// ألوان تطبيق نور رمضان
/// مستوحاة من شوارع القاهرة الليلية في رمضان
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════
  // الذهبي — اللون الأساسي للتطبيق
  // ═══════════════════════════════════════
  static const Color goldWarm  = Color(0xFFC8922A); // ذهبي دافئ — الإطارات والأيقونات
  static const Color goldLight = Color(0xFFF0C060); // ذهبي فاتح — النصوص المضيئة
  static const Color goldGlow  = Color(0xFFFFD97D); // ذهبي لامع — التوهج
  static const Color goldDim   = Color(0xFF8B6520); // ذهبي داكن — الظلال

  // ═══════════════════════════════════════
  // الليل — خلفيات التطبيق
  // ═══════════════════════════════════════
  static const Color nightDeep    = Color(0xFF08061A); // الخلفية الرئيسية
  static const Color nightMid     = Color(0xFF130F2A); // خلفية ثانوية
  static const Color nightSurface = Color(0xFF1C1535); // الأسطح
  static const Color nightCard    = Color(0xFF221A40); // الكروت

  // ═══════════════════════════════════════
  // الحجر — مواد القاهرة القديمة
  // ═══════════════════════════════════════
  static const Color stoneWarm   = Color(0xFF3D2E1E); // المباني
  static const Color agedPlaster = Color(0xFFE8D5B0); // الجدران القديمة

  // ═══════════════════════════════════════
  // النصوص
  // ═══════════════════════════════════════
  static const Color textPrimary = Color(0xFFF5E6CC); // النص الرئيسي
  static const Color textDim     = Color(0xFF9B8A6E); // النص الخافت

  // ═══════════════════════════════════════
  // ألوان الفوانيس
  // ═══════════════════════════════════════
  static const Color lanternRed    = Color(0xFFCC3300);
  static const Color lanternBlue   = Color(0xFF004080);
  static const Color lanternGreen  = Color(0xFF006633);
  static const Color lanternPurple = Color(0xFF800080);
  static const Color lanternAmber  = Color(0xFFD4760A);

  // ═══════════════════════════════════════
  // تدرجات جاهزة للاستخدام
  // ═══════════════════════════════════════

  /// تدرج الذهب الرئيسي
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldGlow, goldWarm],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// تدرج خلفية السماء الليلية
  static const LinearGradient skyGradient = LinearGradient(
    colors: [Color(0xFF03020F), Color(0xFF0A0720), Color(0xFF160E30)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.4, 1.0],
  );

  /// تدرج خلفية الصفحات العادية
  static const LinearGradient pageGradient = LinearGradient(
    colors: [nightDeep, nightMid, Color(0xFF1A1020)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.6, 1.0],
  );

  /// تدرج الكرت الذهبي
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xF0221A40), Color(0xFA160F28)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════
  // ألوان الحدود
  // ═══════════════════════════════════════
  static const Color borderGold       = Color(0x40C8922A); // حدود ذهبية خفيفة
  static const Color borderGoldStrong = Color(0x99C8922A); // حدود ذهبية واضحة
  static const Color borderGoldGlow   = Color(0xFFFFD97D); // حدود مضيئة

  // ═══════════════════════════════════════
  // ألوان الظل
  // ═══════════════════════════════════════
  static const Color shadowGold  = Color(0x66C8922A);
  static const Color shadowDark  = Color(0x99000000);

  // ═══════════════════════════════════════
  // ألوان المصحف (النمط الفاتح)
  // ═══════════════════════════════════════
  static const Color mushafPaper     = Color(0xFFF8F5EE); // خلفية ورقية
  static const Color mushafInk       = Color(0xFF2C2418); // لون الحبر (بني داكن جداً)
  static const Color mushafHighlight = Color(0xFFEADBBE); // تظليل الآية المختارة
  static const Color mushafBorder    = Color(0xFFD4C8B0); // حدود زخرفية
}
