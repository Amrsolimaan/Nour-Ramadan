import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

/// نص عربي قابل للتخصيص بخط NotoNaskhArabic
class ArabicText extends StatelessWidget {
  const ArabicText(
    this.text, {
    super.key,
    this.fontSize,
    this.color,
    this.fontWeight,
    this.height,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final double? fontSize;
  final Color? color;
  final FontWeight? fontWeight;
  final double? height;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign ?? TextAlign.right,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontFamily: 'NotoNaskhArabic',
        fontSize: (fontSize ?? 16).sp,
        color: color ?? AppColors.textPrimary,
        fontWeight: fontWeight ?? FontWeight.w400,
        height: height ?? 2.0,
      ),
    );
  }
}

/// نص Tajawal للعناصر العامة
class TajawalText extends StatelessWidget {
  const TajawalText(
    this.text, {
    super.key,
    this.fontSize,
    this.color,
    this.fontWeight,
    this.height,
    this.textAlign,
    this.maxLines,
    this.letterSpacing,
  });

  final String text;
  final double? fontSize;
  final Color? color;
  final FontWeight? fontWeight;
  final double? height;
  final TextAlign? textAlign;
  final int? maxLines;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign ?? TextAlign.center,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontFamily: 'Tajawal',
        fontSize: (fontSize ?? 14).sp,
        color: color ?? AppColors.textPrimary,
        fontWeight: fontWeight ?? FontWeight.w400,
        height: height,
        letterSpacing: letterSpacing,
      ),
    );
  }
}

/// نص Amiri للأرقام والعناوين الكريمة
class AmiriText extends StatelessWidget {
  const AmiriText(
    this.text, {
    super.key,
    this.fontSize,
    this.color,
    this.fontWeight,
    this.height,
    this.textAlign,
    this.letterSpacing,
  });

  final String text;
  final double? fontSize;
  final Color? color;
  final FontWeight? fontWeight;
  final double? height;
  final TextAlign? textAlign;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign ?? TextAlign.center,
      style: TextStyle(
        fontFamily: 'Amiri',
        fontSize: (fontSize ?? 24).sp,
        color: color ?? AppColors.goldLight,
        fontWeight: fontWeight ?? FontWeight.w400,
        height: height ?? 1.0,
        letterSpacing: letterSpacing,
      ),
    );
  }
}
