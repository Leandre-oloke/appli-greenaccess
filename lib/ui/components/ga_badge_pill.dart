import 'package:flutter/material.dart';

import '../tokens/ga_radii.dart';

/// Pastille arrondie : libellé + icône, teintée d'une couleur sémantique.
class GaBadgePill extends StatelessWidget {
  const GaBadgePill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// `true` : fond plein coloré, texte blanc. `false` : fond teinté, texte coloré.
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    final bg = filled ? color : color.withValues(alpha: 0.14);
    final textStyle = (dense
            ? Theme.of(context).textTheme.labelSmall
            : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(color: fg, fontWeight: FontWeight.w600, letterSpacing: 0.2);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: GaRadii.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}
