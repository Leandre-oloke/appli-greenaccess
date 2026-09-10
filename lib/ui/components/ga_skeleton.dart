import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../tokens/ga_radii.dart';
import '../tokens/ga_spacing.dart';

/// Placeholder « shimmer » pour les états de chargement.
/// Remplace les `Center(child: CircularProgressIndicator())` de premier rendu.
class GaSkeleton extends StatelessWidget {
  const GaSkeleton._({
    required this.width,
    required this.height,
    required this.radius,
  });

  factory GaSkeleton.box({double? width, double height = 120, double radius = GaRadii.lg}) =>
      GaSkeleton._(width: width, height: height, radius: radius);
  factory GaSkeleton.line({double? width, double height = 14}) =>
      GaSkeleton._(width: width, height: height, radius: 6);
  factory GaSkeleton.circle({double size = 44}) =>
      GaSkeleton._(width: size, height: size, radius: size / 2);
  factory GaSkeleton.card({double height = 160}) =>
      GaSkeleton._(width: double.infinity, height: height, radius: GaRadii.lg);

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final hi = Theme.of(context).colorScheme.surface;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1400.ms,
          color: hi.withValues(alpha: 0.55),
        );
  }
}

/// Liste de skeletons pour un `ListView` en chargement.
class GaSkeletonList extends StatelessWidget {
  const GaSkeletonList({super.key, this.itemCount = 5, this.itemHeight = 76});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: GaSpacing.md),
          child: GaSkeleton.box(height: itemHeight),
        ),
      ),
    );
  }
}
