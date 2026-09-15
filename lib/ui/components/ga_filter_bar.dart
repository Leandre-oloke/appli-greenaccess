import 'package:flutter/material.dart';

import '../theme/ga_theme_extensions.dart';
import '../tokens/ga_radii.dart';
import '../tokens/ga_spacing.dart';

/// Barre de recherche + chips de filtre du design system.
///
/// Remplace les champs de recherche et rangées de filtre ad-hoc (Formation,
/// Notifications). [filters] est optionnel : sans filtres, la barre ne montre
/// que le champ de recherche.
class GaFilterBar extends StatelessWidget {
  const GaFilterBar({
    super.key,
    this.controller,
    this.hint = 'Rechercher…',
    this.onChanged,
    this.filters = const [],
    this.selectedFilter,
    this.onFilterSelected,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  /// Libellés des chips de filtre (ex. catégories).
  final List<String> filters;
  final String? selectedFilter;
  final ValueChanged<String>? onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final sem = context.gaColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: sem.surfaceAlt,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: GaSpacing.md, vertical: 0),
            border: OutlineInputBorder(
              borderRadius: GaRadii.brMd,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (filters.isNotEmpty) ...[
          const SizedBox(height: GaSpacing.sm),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: GaSpacing.xs),
              itemBuilder: (context, i) {
                final label = filters[i];
                final selected = label == selectedFilter;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => onFilterSelected?.call(label),
                  showCheckmark: false,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
