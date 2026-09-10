import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'ga_colors.dart';

/// Typographie du design system.
///
/// Display : **Sora** (expressif). Corps : **Inter** (lisible).
/// Polices variables — la graisse est résolue via l'axe `wght`.
abstract final class GaTypography {
  static const String display = 'Sora';
  static const String body = 'Inter';
  static const List<String> fallback = ['Roboto'];

  static const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

  /// Style pour les valeurs chiffrées alignées (scores, montants).
  static TextStyle numeric(GaColors c, {double size = 44, Color? color}) =>
      TextStyle(
        fontFamily: display,
        fontFamilyFallback: fallback,
        fontSize: size,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: color ?? c.ink,
        fontFeatures: _tnum,
      );

  static TextTheme textTheme(GaColors c) {
    TextStyle d(double s, double h, FontWeight w) => TextStyle(
          fontFamily: display,
          fontFamilyFallback: fallback,
          fontSize: s,
          height: h / s,
          fontWeight: w,
          color: c.ink,
        );
    TextStyle b(double s, double h, FontWeight w, {Color? col, double? track}) =>
        TextStyle(
          fontFamily: body,
          fontFamilyFallback: fallback,
          fontSize: s,
          height: h / s,
          fontWeight: w,
          letterSpacing: track,
          color: col ?? c.ink,
        );

    return TextTheme(
      displayLarge: d(40, 46, FontWeight.w700),
      displayMedium: d(32, 38, FontWeight.w700),
      displaySmall: d(26, 32, FontWeight.w600),
      headlineMedium: d(22, 28, FontWeight.w600),
      headlineSmall: d(19, 26, FontWeight.w600),
      titleLarge: b(17, 24, FontWeight.w600),
      titleMedium: b(15, 22, FontWeight.w600),
      titleSmall: b(13, 18, FontWeight.w600, col: c.inkSoft),
      bodyLarge: b(15, 23, FontWeight.w400),
      bodyMedium: b(14, 21, FontWeight.w400),
      bodySmall: b(12.5, 18, FontWeight.w400, col: c.inkSoft),
      labelLarge: b(14, 20, FontWeight.w600),
      labelMedium: b(12, 16, FontWeight.w600),
      labelSmall: b(11, 16, FontWeight.w500, col: c.inkSoft, track: 0.4),
    );
  }
}
