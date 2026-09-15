import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/ga_radii.dart';
import '../tokens/ga_spacing.dart';

/// Une option pour [GaChoiceGroup].
class GaChoiceOption<T> {
  const GaChoiceOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.emoji,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final String? emoji;
}

/// Carte de sélection large : icône/emoji + titre + description + état choisi.
/// Remplace `RadioListTile` / `CheckboxListTile` / dropdowns du formulaire scoring.
class GaChoiceCard extends StatelessWidget {
  const GaChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
    this.icon,
    this.emoji,
    this.multi = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? description;
  final IconData? icon;
  final String? emoji;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = selected ? cs.primaryContainer : cs.surface;
    final border = selected ? cs.primary : cs.outline;

    return Material(
      color: bg,
      borderRadius: GaRadii.brMd,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: GaRadii.brMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(GaSpacing.md),
          decoration: BoxDecoration(
            borderRadius: GaRadii.brMd,
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 22))
              else if (icon != null)
                Icon(icon,
                    color: selected ? cs.primary : cs.onSurfaceVariant, size: 22),
              if (emoji != null || icon != null)
                const SizedBox(width: GaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(description!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: GaSpacing.sm),
              _Indicator(selected: selected, multi: multi),
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.selected, required this.multi});
  final bool selected;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 22,
      width: 22,
      decoration: BoxDecoration(
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(
            color: selected ? cs.primary : cs.outline, width: 2),
        borderRadius:
            multi ? BorderRadius.circular(6) : BorderRadius.circular(999),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}

/// Groupe de [GaChoiceCard] : sélection simple ou multiple.
class GaChoiceGroup<T> extends StatelessWidget {
  const GaChoiceGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multi = false,
    this.columns = 1,
  });

  final List<GaChoiceOption<T>> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multi;
  final int columns;

  void _toggle(T value) {
    final next = Set<T>.from(selected);
    if (multi) {
      next.contains(value) ? next.remove(value) : next.add(value);
    } else {
      next
        ..clear()
        ..add(value);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final cards = options
        .map((o) => GaChoiceCard(
              label: o.label,
              description: o.description,
              icon: o.icon,
              emoji: o.emoji,
              multi: multi,
              selected: selected.contains(o.value),
              onTap: () => _toggle(o.value),
            ))
        .toList();

    if (columns <= 1) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: GaSpacing.sm),
            cards[i],
          ],
        ],
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      crossAxisSpacing: GaSpacing.sm,
      mainAxisSpacing: GaSpacing.sm,
      childAspectRatio: 2.6,
      children: cards,
    );
  }
}
