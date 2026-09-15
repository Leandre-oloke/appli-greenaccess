import 'package:flutter/widgets.dart';

/// Points de rupture responsive et largeurs de contenu.
abstract final class GaBreakpoints {
  static const double compact = 600;
  static const double medium = 1024;

  /// Largeur max d'un formulaire / d'un écran d'authentification (centré sur web).
  static const double maxForm = 480;

  /// Largeur max d'un contenu de lecture.
  static const double maxContent = 640;

  static bool isCompact(BuildContext c) =>
      MediaQuery.sizeOf(c).width < compact;
  static bool isExpanded(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= medium;
}
