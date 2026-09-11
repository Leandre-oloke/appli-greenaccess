import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routes.dart';
import '../../ui/ui.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class ScoringFormScreen extends ConsumerStatefulWidget {
  const ScoringFormScreen({super.key});

  @override
  ConsumerState<ScoringFormScreen> createState() => _ScoringFormScreenState();
}

class _ScoringFormScreenState extends ConsumerState<ScoringFormScreen> {
  int _step = 0;

  String _typeActivite = 'Agriculture';
  String _alignementUemoa = 'Non';
  double _co2Evite = 0;
  final List<String> _certifications = [];
  int _resilience = 3;

  static const _activites = <(String, String)>[
    ('Agriculture', '🌾'),
    ('Énergie renouvelable', '☀️'),
    ('Recyclage', '♻️'),
    ('Transport propre', '🚲'),
    ('Forêt', '🌳'),
  ];
  static const _certifs = <(String, String)>[
    ('Bio', '🌱'),
    ('Équitable', '🤝'),
    ('ISO 14001', '📋'),
    ('Carbone Neutre', '🌍'),
  ];

  Future<void> _submit() async {
    final userId = ref.read(authViewModelProvider).user?.id ?? '';
    final data = {
      'type_activite': _typeActivite,
      'alignement_uemoa': _alignementUemoa,
      'co2_evite': _co2Evite,
      'certifications': _certifications,
      'resilience': _resilience,
    };
    final score = await ref
        .read(scoringViewModelProvider(userId).notifier)
        .soumettreCriteres(data);
    // En cas d'échec, l'erreur reste dans ScoringState.error et s'affiche
    // dans le bandeau au-dessus du stepper (voir build()) — pas de calcul de
    // repli côté client (CDC §4.4).
    if (mounted && score != null) {
      context.pushReplacement(AppRoutes.scoreResult);
    }
  }

  void _continue() {
    if (_step < 4) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(scoringViewModelProvider(userId));

    return Scaffold(
      appBar: const GaAppBar(title: 'Score Climat'),
      body: SafeArea(
        child: Column(
          children: [
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GaSpacing.lg, GaSpacing.sm, GaSpacing.lg, 0),
                child: GaInfoBanner(
                  kind: GaBannerKind.error,
                  title: 'Calcul du score indisponible',
                  message: state.error!,
                  action: GaSecondaryButton.ghost(
                    label: 'Voir les cours',
                    onPressed: () => context.push(AppRoutes.courseList),
                  ),
                ),
              ),
            Expanded(
              child: GaStepper(
                currentStep: _step,
                busy: state.isCalculating,
                finishLabel: 'Calculer mon score',
                onStepContinue: _continue,
                onStepCancel: () => setState(() => _step--),
                steps: [
                  GaStep(
                    title: "Quelle est votre activité ?",
                    content: GaChoiceGroup<String>(
                      options: [
                        for (final (name, emoji) in _activites)
                          GaChoiceOption(
                              value: name, label: name, emoji: emoji),
                      ],
                      selected: {_typeActivite},
                      onChanged: (s) =>
                          setState(() => _typeActivite = s.first),
                    ),
                  ),
                  GaStep(
                    title: 'Alignement à la taxonomie UEMOA',
                    subtitle: 'Critères verts AMF-UEMOA',
                    content: GaChoiceGroup<String>(
                      options: const [
                        GaChoiceOption(
                            value: 'Oui',
                            label: 'Oui, pleinement',
                            description: 'Activité conforme aux critères verts',
                            icon: Icons.verified_rounded),
                        GaChoiceOption(
                            value: 'Partiel',
                            label: 'Partiellement',
                            description: 'Conformité en cours',
                            icon: Icons.timelapse_rounded),
                        GaChoiceOption(
                            value: 'Non',
                            label: 'Non / je ne sais pas',
                            icon: Icons.help_outline_rounded),
                      ],
                      selected: {_alignementUemoa},
                      onChanged: (s) =>
                          setState(() => _alignementUemoa = s.first),
                    ),
                  ),
                  GaStep(
                    title: 'Impact CO₂ estimé',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _co2Evite.round().toString(),
                          style:
                              GaTypography.numeric(context.gaTokens, size: 52),
                        ),
                        Text('tonnes de CO₂ évitées par an',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: GaSpacing.lg),
                        Slider(
                          value: _co2Evite,
                          max: 500,
                          divisions: 50,
                          label: '${_co2Evite.round()} t',
                          onChanged: (v) => setState(() => _co2Evite = v),
                        ),
                      ],
                    ),
                  ),
                  GaStep(
                    title: 'Vos certifications',
                    subtitle: 'Plusieurs choix possibles',
                    content: GaChoiceGroup<String>(
                      multi: true,
                      options: [
                        for (final (name, emoji) in _certifs)
                          GaChoiceOption(
                              value: name, label: name, emoji: emoji),
                      ],
                      selected: _certifications.toSet(),
                      onChanged: (s) => setState(() {
                        _certifications
                          ..clear()
                          ..addAll(s);
                      }),
                    ),
                  ),
                  GaStep(
                    title: 'Votre résilience climatique',
                    subtitle: 'Plan d\'adaptation, diversification…',
                    content: GaChoiceGroup<int>(
                      options: const [
                        GaChoiceOption(value: 1, label: '1 — Faible'),
                        GaChoiceOption(value: 2, label: '2 — Limitée'),
                        GaChoiceOption(value: 3, label: '3 — Moyenne'),
                        GaChoiceOption(value: 4, label: '4 — Bonne'),
                        GaChoiceOption(value: 5, label: '5 — Très bonne'),
                      ],
                      selected: {_resilience},
                      onChanged: (s) => setState(() => _resilience = s.first),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
