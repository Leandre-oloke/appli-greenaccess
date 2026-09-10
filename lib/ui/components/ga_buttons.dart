import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/ga_spacing.dart';

/// Bouton d'action principal : pilule pleine, état `loading` sans saut de layout.
class GaPrimaryButton extends StatelessWidget {
  const GaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(cs.onPrimary),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: GaSpacing.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final btn = FilledButton(
      onPressed: loading
          ? null
          : (onPressed == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

enum GaButtonVariant { outlined, tonal, ghost }

/// Bouton secondaire : contour, tonal ou fantôme.
class GaSecondaryButton extends StatelessWidget {
  const GaSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GaButtonVariant.outlined,
    this.icon,
    this.expand = false,
    this.loading = false,
  });

  const GaSecondaryButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
  }) : variant = GaButtonVariant.outlined;

  const GaSecondaryButton.tonal({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
  }) : variant = GaButtonVariant.tonal;

  const GaSecondaryButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
  }) : variant = GaButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final GaButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveOnPressed = loading ? null : onPressed;
    final child = loading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 6),
              ],
              Text(label),
            ],
          );

    final Widget btn = switch (variant) {
      GaButtonVariant.outlined =>
        OutlinedButton(onPressed: effectiveOnPressed, child: child),
      GaButtonVariant.tonal => FilledButton.tonal(
          onPressed: effectiveOnPressed,
          child: child,
        ),
      GaButtonVariant.ghost => TextButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
    };
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
