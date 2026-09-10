import 'package:flutter/material.dart';

import '../theme/ga_theme_extensions.dart';
import '../tokens/ga_radii.dart';
import '../tokens/ga_spacing.dart';
import '../tokens/ga_typography.dart';

/// Tuile de métrique compacte : icône + valeur (Sora tabular) + libellé.
/// Remplace `_Stat`, `_ActionChip`, les blocs KPI ad-hoc.
class GaStatTile extends StatelessWidget {
  const GaStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: GaRadii.brLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: GaRadii.brLg,
        child: Container(
          padding: const EdgeInsets.all(GaSpacing.md),
          decoration: BoxDecoration(
            borderRadius: GaRadii.brLg,
            boxShadow: context.gaShadows.e1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: GaRadii.brSm,
                  ),
                  child: Icon(icon, size: 18, color: c),
                ),
              const SizedBox(height: GaSpacing.sm),
              if (value.isNotEmpty) ...[
                Text(value,
                    style: GaTypography.numeric(context.gaTokens, size: 22)),
                const SizedBox(height: 2),
              ],
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre horizontale animée : libellé + valeur/max.
class GaMeterRow extends StatelessWidget {
  const GaMeterRow({
    super.key,
    required this.label,
    required this.value,
    this.max = 100,
    this.color,
    this.trailing,
  });

  final String label;
  final double value;
  final double max;
  final Color? color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    final pct = (max <= 0 ? 0.0 : (value / max)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              trailing ?? '${value.round()}/${max.round()}',
              style: theme.textTheme.labelMedium?.copyWith(color: c),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: theme.colorScheme.primaryContainer,
              valueColor: AlwaysStoppedAnimation(c),
            ),
          ),
        ),
      ],
    );
  }
}
