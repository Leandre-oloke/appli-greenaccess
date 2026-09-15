import 'package:flutter/material.dart';

import '../tokens/ga_spacing.dart';
import 'ga_card.dart';

/// Carte regroupant une section de formulaire : titre Sora + champs espacés
/// régulièrement. Remplace les groupes de champs délimités par un simple
/// `Text` de section (register, demande de financement, formulaires admin).
class GaFormCard extends StatelessWidget {
  const GaFormCard({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.gap = GaSpacing.md,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: GaSpacing.sm),
              ],
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: GaSpacing.md),
          for (var i = 0; i < children.length; i++) ...[
            if (i != 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
    );
  }
}
