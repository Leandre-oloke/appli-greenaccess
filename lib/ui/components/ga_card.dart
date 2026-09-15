import 'package:flutter/material.dart';

import '../theme/ga_theme_extensions.dart';
import '../tokens/ga_radii.dart';
import '../tokens/ga_spacing.dart';

/// Carte du design system : surface arrondie, ombre en couches, ripple optionnel.
///
/// Remplace `Card(...)` et les blocs `Container(decoration: BoxDecoration(...))`
/// dupliqués dans les écrans.
class GaCard extends StatelessWidget {
  const GaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GaSpacing.xl),
    this.onTap,
    this.tint,
    this.gradient,
    this.shadow,
    this.borderRadius,
    this.border,
    this.clip = Clip.antiAlias,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Teinte de fond (ex. `context.gaColors.forestContainer`).
  final Color? tint;
  final Gradient? gradient;
  final List<BoxShadow>? shadow;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final Clip clip;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? GaRadii.brLg;
    final bg = gradient == null
        ? (tint ?? Theme.of(context).colorScheme.surface)
        : null;

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        borderRadius: radius,
        border: border,
        boxShadow: shadow ?? context.gaShadows.e2,
      ),
      clipBehavior: clip,
      child: content,
    );
  }
}
