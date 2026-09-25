import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppText {
  AppText._();

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Headings
  static TextStyle h1(Color color) =>
      _base(size: 26, weight: FontWeight.w800, color: color, height: 1.2);
  static TextStyle h2(Color color) =>
      _base(size: 22, weight: FontWeight.w800, color: color, height: 1.25);
  static TextStyle h3(Color color) =>
      _base(size: 17, weight: FontWeight.w700, color: color, height: 1.3);

  static TextStyle body(Color color) =>
      _base(size: 14, weight: FontWeight.w400, color: color, height: 1.4);
  static TextStyle bodyMedium(Color color) =>
      _base(size: 14, weight: FontWeight.w600, color: color, height: 1.4);
  static TextStyle bodySmall(Color color) =>
      _base(size: 12.5, weight: FontWeight.w400, color: color, height: 1.4);

  static TextStyle label(Color color) => _base(
        size: 11,
        weight: FontWeight.w700,
        color: color,
        letterSpacing: 0.6,
      );

  static TextStyle input(Color color) =>
      _base(size: 15, weight: FontWeight.w600, color: color);

  static TextStyle button(Color color) =>
      _base(size: 15.5, weight: FontWeight.w700, color: color);

  static TextStyle caption(Color color) =>
      _base(size: 11.5, weight: FontWeight.w400, color: color, height: 1.4);
}
