import 'package:flutter/material.dart';

import '../theme/ga_theme_extensions.dart';
import '../tokens/ga_radii.dart';
import '../tokens/ga_spacing.dart';

enum GaBannerKind { success, warning, info, neutral, error }

/// Encart d'information en ligne, teinté selon [kind].
/// Remplace `_InfoBanner`, `_CompletedBanner`, les `Container` d'alerte inline…
class GaInfoBanner extends StatelessWidget {
  const GaInfoBanner({
    super.key,
    required this.message,
    this.kind = GaBannerKind.info,
    this.icon,
    this.action,
    this.title,
  });

  final String message;
  final GaBannerKind kind;
  final IconData? icon;
  final Widget? action;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = context.gaColors;
    final color = switch (kind) {
      GaBannerKind.success => sem.success,
      GaBannerKind.warning => sem.warning,
      GaBannerKind.info => sem.info,
      GaBannerKind.error => theme.colorScheme.error,
      GaBannerKind.neutral => sem.inkSoft,
    };
    final ic = icon ??
        switch (kind) {
          GaBannerKind.success => Icons.check_circle_rounded,
          GaBannerKind.warning => Icons.warning_amber_rounded,
          GaBannerKind.info => Icons.info_rounded,
          GaBannerKind.error => Icons.error_rounded,
          GaBannerKind.neutral => Icons.lightbulb_outline_rounded,
        };

    return Container(
      padding: const EdgeInsets.all(GaSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: GaRadii.brMd,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ic, color: color, size: 20),
          const SizedBox(width: GaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: GaSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}
