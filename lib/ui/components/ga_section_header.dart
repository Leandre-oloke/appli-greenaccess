import 'package:flutter/material.dart';

import '../tokens/ga_spacing.dart';

/// En-tête de section : titre Sora + sous-titre + action optionnelle.
/// Remplace les `Text(..., FontWeight.bold)` de section dupliqués.
class GaSectionHeader extends StatelessWidget {
  const GaSectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.only(bottom: GaSpacing.md, top: GaSpacing.sm),
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
