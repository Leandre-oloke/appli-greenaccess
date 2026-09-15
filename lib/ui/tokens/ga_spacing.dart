import 'package:flutter/widgets.dart';

/// Échelle d'espacement 4-pt du design system.
abstract final class GaSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// Marge latérale d'écran par défaut.
  static const double screenH = 20;

  static SizedBox gap(double v) => SizedBox(width: v, height: v);
  static SizedBox get gapSm => gap(sm);
  static SizedBox get gapMd => gap(md);
  static SizedBox get gapLg => gap(lg);
  static SizedBox get gapXl => gap(xl);
}
