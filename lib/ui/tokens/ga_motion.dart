import 'package:flutter/widgets.dart';

/// Durées et courbes de mouvement du design system.
abstract final class GaMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration expressive = Duration(milliseconds: 600);

  /// Balayage de la jauge de score signature.
  static const Duration gauge = Duration(milliseconds: 1200);

  /// Décalage entre éléments d'une entrée en cascade.
  static const Duration stagger = Duration(milliseconds: 60);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
  static const Curve decelerate = Curves.easeOutQuart;
  static const Curve spring = Curves.elasticOut;

  /// Décalage vertical de l'entrée « fade + slide-up ».
  static const double entranceOffset = 12;
}
