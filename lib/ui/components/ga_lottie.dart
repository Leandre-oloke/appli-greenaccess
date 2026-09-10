import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Enrobage de `Lottie.asset` : sûr sur Web, respecte reduced-motion,
/// retombe sur une icône si l'asset est absent ou illisible.
class GaLottie extends StatelessWidget {
  const GaLottie(
    this.asset, {
    super.key,
    this.size,
    this.repeat = false,
    this.controller,
    this.fallbackIcon = Icons.eco_rounded,
    this.animate = true,
  });

  final String asset;
  final double? size;
  final bool repeat;
  final Animation<double>? controller;
  final IconData fallbackIcon;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Lottie.asset(
      asset,
      width: size,
      height: size,
      controller: controller,
      repeat: repeat && !reduceMotion,
      animate: animate && !reduceMotion,
      frameRate: FrameRate.max,
      errorBuilder: (context, error, stack) => Icon(
        fallbackIcon,
        size: (size ?? 64) * 0.6,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
