import 'package:flutter/material.dart';

import '../theme/ga_theme_extensions.dart';
import '../tokens/ga_spacing.dart';

enum GaTimelineStepState { done, current, pending, error }

/// Une étape de [GaStatusTimeline].
class GaTimelineStep {
  const GaTimelineStep({
    required this.label,
    this.subtitle,
    this.state = GaTimelineStepState.pending,
  });

  final String label;
  final String? subtitle;
  final GaTimelineStepState state;
}

/// Frise verticale de statut : remplace les indicateurs d'étape ad-hoc du
/// suivi de demande de financement / dossier de sinistre.
class GaStatusTimeline extends StatelessWidget {
  const GaStatusTimeline({super.key, required this.steps});

  final List<GaTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = context.gaColors;

    Color colorFor(GaTimelineStepState s) => switch (s) {
          GaTimelineStepState.done => theme.colorScheme.primary,
          GaTimelineStepState.current => theme.colorScheme.primary,
          GaTimelineStepState.error => theme.colorScheme.error,
          GaTimelineStepState.pending => sem.inkSoft.withValues(alpha: 0.35),
        };

    IconData iconFor(GaTimelineStepState s) => switch (s) {
          GaTimelineStepState.done => Icons.check_rounded,
          GaTimelineStepState.current => Icons.radio_button_checked_rounded,
          GaTimelineStepState.error => Icons.close_rounded,
          GaTimelineStepState.pending => Icons.circle,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: steps[i].state == GaTimelineStepState.pending
                            ? Colors.transparent
                            : colorFor(steps[i].state),
                        shape: BoxShape.circle,
                        border: Border.all(color: colorFor(steps[i].state), width: 2),
                      ),
                      child: Icon(
                        iconFor(steps[i].state),
                        size: steps[i].state == GaTimelineStepState.pending ? 8 : 14,
                        color: steps[i].state == GaTimelineStepState.pending
                            ? colorFor(steps[i].state)
                            : Colors.white,
                      ),
                    ),
                    if (i != steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: steps[i].state == GaTimelineStepState.done
                              ? theme.colorScheme.primary
                              : sem.inkSoft.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: GaSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: GaSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: steps[i].state == GaTimelineStepState.pending
                                ? sem.inkSoft
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (steps[i].subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(steps[i].subtitle!, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
