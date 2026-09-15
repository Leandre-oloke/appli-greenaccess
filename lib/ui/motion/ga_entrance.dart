import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tokens/ga_motion.dart';

/// Presets d'entrée pour `flutter_animate`.
extension GaEntrance on Widget {
  /// Fondu + léger slide-up. `order` décale l'entrée pour un effet de cascade.
  Widget gaFadeSlideUp({int order = 0}) {
    return animate()
        .fadeIn(
          duration: GaMotion.base,
          delay: GaMotion.stagger * order,
          curve: GaMotion.standard,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          duration: GaMotion.base,
          delay: GaMotion.stagger * order,
          curve: GaMotion.standard,
        );
  }

  Widget gaScaleIn({int order = 0}) {
    return animate()
        .fadeIn(duration: GaMotion.base, delay: GaMotion.stagger * order)
        .scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1, 1),
          duration: GaMotion.slow,
          delay: GaMotion.stagger * order,
          curve: GaMotion.emphasized,
        );
  }
}

/// Applique une cascade `gaFadeSlideUp` à une liste d'enfants (colonnes).
List<Widget> gaStagger(List<Widget> children) {
  return [
    for (var i = 0; i < children.length; i++)
      children[i].gaFadeSlideUp(order: i),
  ];
}
