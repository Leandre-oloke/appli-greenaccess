import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class ScoringFormScreen extends ConsumerStatefulWidget {
  const ScoringFormScreen({super.key});

  @override
  ConsumerState<ScoringFormScreen> createState() => _ScoringFormScreenState();
}

class _ScoringFormScreenState extends ConsumerState<ScoringFormScreen> {
  int _currentStep = 0;

  String _typeActivite = 'Agriculture';
  String _alignementUemoa = 'Non';
  double _co2Evite = 0;
  final List<String> _certifications = [];
  int _resilience = 3;

  final List<String> _activites = [
    'Agriculture', 'Énergie renouvelable', 'Recyclage', 'Transport propre', 'Forêt'
  ];
  final List<String> _certifsList = ['Bio', 'Équitable', 'ISO 14001', 'Carbone Neutre'];

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
    if (mounted && score != null) {
      context.pushReplacement(AppRoutes.scoreResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(scoringViewModelProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Calcul du Score Climat')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 4) {
            setState(() => _currentStep++);
          } else {
            _submit();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: state.isCalculating ? null : details.onStepContinue,
                child: state.isCalculating && _currentStep == 4
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_currentStep == 4 ? 'Calculer mon score' : 'Suivant'),
              ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 12),
                TextButton(onPressed: details.onStepCancel, child: const Text('Retour')),
              ],
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text("Type d'activité"),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: DropdownButtonFormField<String>(
              value: _typeActivite,
              decoration: const InputDecoration(labelText: "Secteur d'activité"),
              items: _activites.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (v) => setState(() => _typeActivite = v!),
            ),
          ),
          Step(
            title: const Text('Alignement taxonomie UEMOA'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              children: ['Oui', 'Partiel', 'Non'].map((v) => RadioListTile<String>(
                title: Text(v),
                value: v,
                groupValue: _alignementUemoa,
                onChanged: (val) => setState(() => _alignementUemoa = val!),
                activeColor: AppColors.primary,
              )).toList(),
            ),
          ),
          Step(
            title: const Text('Impact CO₂ estimé'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tonnes CO₂ évitées/an : ${_co2Evite.toStringAsFixed(0)}'),
                Slider(
                  value: _co2Evite,
                  min: 0,
                  max: 500,
                  divisions: 50,
                  activeColor: AppColors.primary,
                  label: '${_co2Evite.toStringAsFixed(0)} t',
                  onChanged: (v) => setState(() => _co2Evite = v),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Certifications existantes'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: Column(
              children: _certifsList.map((c) => CheckboxListTile(
                title: Text(c),
                value: _certifications.contains(c),
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() {
                  val! ? _certifications.add(c) : _certifications.remove(c);
                }),
              )).toList(),
            ),
          ),
          Step(
            title: const Text('Résilience climatique'),
            isActive: _currentStep >= 4,
            state: StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Niveau de résilience (1 = faible, 5 = très bon)'),
                Slider(
                  value: _resilience.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: AppColors.primary,
                  label: '$_resilience/5',
                  onChanged: (v) => setState(() => _resilience = v.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
