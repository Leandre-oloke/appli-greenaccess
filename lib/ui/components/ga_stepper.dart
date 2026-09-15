import 'package:flutter/material.dart';

import '../tokens/ga_motion.dart';
import '../tokens/ga_spacing.dart';
import 'ga_buttons.dart';

/// Une étape de [GaStepper].
class GaStep {
  const GaStep({
    required this.title,
    required this.content,
    this.subtitle,
    this.isValid = true,
  });

  final String title;
  final String? subtitle;
  final Widget content;
  final bool isValid;
}

/// Stepper du design system — remplace le `Stepper` Material.
///
/// Rail segmenté animé + corps swappé avec transition, footer collant
/// (« Suivant » / libellé final, `busy` sur la dernière étape + « Retour »).
class GaStepper extends StatelessWidget {
  const GaStepper({
    super.key,
    required this.currentStep,
    required this.steps,
    required this.onStepContinue,
    required this.onStepCancel,
    this.busy = false,
    this.finishLabel = 'Terminer',
    this.continueLabel = 'Suivant',
    this.cancelLabel = 'Retour',
  });

  final int currentStep;
  final List<GaStep> steps;
  final VoidCallback onStepContinue;
  final VoidCallback onStepCancel;
  final bool busy;
  final String finishLabel;
  final String continueLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = steps[currentStep];
    final isLast = currentStep == steps.length - 1;

    return Column(
      children: [
        // ── Rail segmenté ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GaSpacing.lg, GaSpacing.md, GaSpacing.lg, GaSpacing.sm),
          child: Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: GaMotion.base,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= currentStep
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: GaSpacing.lg),
          child: Row(
            children: [
              Text(
                'Étape ${currentStep + 1} / ${steps.length}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (step.subtitle != null)
                Flexible(
                  child: Text(step.subtitle!,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),

        // ── Corps ────────────────────────────────────────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: GaMotion.base,
            switchInCurve: GaMotion.standard,
            transitionBuilder: (child, anim) {
              final offset = Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(anim);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: SingleChildScrollView(
              key: ValueKey(currentStep),
              padding: const EdgeInsets.fromLTRB(
                  GaSpacing.lg, GaSpacing.lg, GaSpacing.lg, GaSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: GaSpacing.lg),
                  step.content,
                ],
              ),
            ),
          ),
        ),

        // ── Footer collant ──────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
            GaSpacing.lg,
            GaSpacing.md,
            GaSpacing.lg,
            GaSpacing.md + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
                top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: Row(
            children: [
              if (currentStep > 0)
                GaSecondaryButton.ghost(
                  label: cancelLabel,
                  icon: Icons.arrow_back_rounded,
                  onPressed: busy ? null : onStepCancel,
                ),
              const Spacer(),
              GaPrimaryButton(
                label: isLast ? finishLabel : continueLabel,
                loading: busy,
                icon: isLast ? Icons.auto_awesome_rounded : null,
                expand: false,
                onPressed: step.isValid ? onStepContinue : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
