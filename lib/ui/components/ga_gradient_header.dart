import 'package:flutter/material.dart';

import '../theme/ga_theme_extensions.dart';
import '../tokens/ga_radii.dart';
import '../tokens/ga_spacing.dart';

/// Bandeau héros : dégradé de marque, coins bas arrondis, gros titre Sora.
class GaGradientHeader extends StatelessWidget {
  const GaGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.actions,
    this.leading,
    this.minHeight = 150,
    this.padding = const EdgeInsets.fromLTRB(
        GaSpacing.xl, GaSpacing.md, GaSpacing.lg, GaSpacing.xl),
    this.rounded = true,
    this.child,
  });

  final String title;
  final String? subtitle;

  /// Widget aligné à droite du titre (avatar, jauge, illustration).
  final Widget? trailing;
  final List<Widget>? actions;
  final Widget? leading;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final bool rounded;

  /// Contenu additionnel sous le titre (ex. une carte tirée par-dessus).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onGrad = Colors.white;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        gradient: context.gaGradients.header,
        borderRadius: rounded ? GaRadii.brHeaderBottom : null,
      ),
      padding: padding,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (actions != null && actions!.isNotEmpty)
              Row(
                children: [
                  if (leading != null) leading!,
                  const Spacer(),
                  ...actions!,
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(color: onGrad),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: GaSpacing.xs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onGrad.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: GaSpacing.md),
                  trailing!,
                ],
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: GaSpacing.lg),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}
