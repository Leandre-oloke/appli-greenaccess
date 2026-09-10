import 'package:flutter/material.dart';

/// Indicateur de pagination : le point actif s'allonge.
class GaDotsIndicator extends StatelessWidget {
  const GaDotsIndicator({
    super.key,
    required this.count,
    required this.index,
    this.activeColor,
    this.inactiveColor,
  });

  final int count;
  final int index;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? Theme.of(context).colorScheme.primary;
    final inactive = inactiveColor ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.25);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: selected ? 22 : 6,
          decoration: BoxDecoration(
            color: selected ? active : inactive,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
