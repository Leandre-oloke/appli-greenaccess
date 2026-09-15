import 'package:flutter/material.dart';

import '../tokens/ga_radii.dart';
import '../tokens/ga_spacing.dart';

/// Tuile de liste du design system : icône teintée + titre + sous-titre +
/// trailing (chevron par défaut si [onTap] est fourni).
///
/// Remplace les `ListTile` décorés à la main (icône `AppColors.primary`,
/// chevron manuel) dupliqués sur les écrans admin/notifications/contrats.
class GaListTile extends StatelessWidget {
  const GaListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leading,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;

  /// Widget de tête personnalisé (ex. `CircleAvatar`) — prioritaire sur [leadingIcon].
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;

    final effectiveLeading = leading ??
        (leadingIcon == null
            ? null
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: GaRadii.brSm,
                ),
                child: Icon(leadingIcon, size: 20, color: color),
              ));

    final effectiveTrailing = trailing ??
        (onTap == null
            ? null
            : Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant));

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: GaSpacing.md,
        vertical: dense ? 0 : GaSpacing.xs,
      ),
      leading: effectiveLeading,
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: theme.textTheme.bodySmall),
      trailing: effectiveTrailing,
      onTap: onTap,
    );
  }
}
