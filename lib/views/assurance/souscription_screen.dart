import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../viewmodels/assurance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SouscriptionScreen extends ConsumerStatefulWidget {
  const SouscriptionScreen({super.key});

  @override
  ConsumerState<SouscriptionScreen> createState() => _SouscriptionScreenState();
}

class _SouscriptionScreenState extends ConsumerState<SouscriptionScreen> {
  int _step = 0;
  String _zone = 'Sénégal';
  String _typeRisque = 'secheresse';
  String _typeCulture = '';
  double _superficie = 1.0;
  double _valeur = 500000;
  bool _confirmed = false;

  static const _zones = ['Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso', 'Niger'];
  static const _risques = ['secheresse', 'inondation', 'chaleur', 'multirisque'];
  static const _risqueLabels = {
    'secheresse': 'Sécheresse',
    'inondation': 'Inondation',
    'chaleur': 'Stress thermique',
    'multirisque': 'Multirisques',
  };

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(assuranceViewModelProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: Text('Souscription — Étape ${_step + 1}/3'),
        leading: BackButton(onPressed: () {
          if (_step > 0) { setState(() => _step--); } else { context.pop(); }
        }),
      ),
      body: Column(
        children: [
          _ProgressBar(step: _step),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStep(state),
            ),
          ),
          _NavBar(
            step: _step,
            canNext: _stepValid(),
            canSubmit: _confirmed && !state.isLoading,
            isLoading: state.isLoading,
            onNext: () => setState(() => _step++),
            onSubmit: () => _submit(uid),
          ),
        ],
      ),
    );
  }

  bool _stepValid() {
    if (_step == 0) return _zone.isNotEmpty && _typeRisque.isNotEmpty;
    if (_step == 1) return _typeCulture.trim().isNotEmpty;
    return _confirmed;
  }

  Future<void> _submit(String uid) async {
    final simulation = ref.read(assuranceViewModelProvider(uid)).simulation;
    await ref.read(assuranceViewModelProvider(uid).notifier).soumettreSouscription({
      'zone_risque': _zone,
      'produit_id': simulation?.produitRecommande.id ?? 'default',
      'prime_mensuelle': simulation?.primeEstimee ?? 5000,
      'type_culture': _typeCulture,
      'superficie': _superficie,
      'assureur_id': 'ASSUREUR_01',
      'date_debut': DateTime.now(),
    });
    if (mounted) context.go(AppRoutes.mesContrats);
  }

  Widget _buildStep(AssuranceState state) {
    return switch (_step) {
      0 => _StepZone(
          zone: _zone, typeRisque: _typeRisque,
          zones: _zones, risques: _risques, risqueLabels: _risqueLabels,
          onZone: (v) => setState(() => _zone = v!),
          onRisque: (v) => setState(() => _typeRisque = v!),
        ),
      1 => _StepExploitation(
          typeCulture: _typeCulture, superficie: _superficie, valeur: _valeur,
          onCulture: (v) => setState(() => _typeCulture = v),
          onSuperficie: (v) => setState(() => _superficie = v),
          onValeur: (v) => setState(() => _valeur = v),
        ),
      _ => _StepConfirmation(
          zone: _zone, typeRisque: _risqueLabels[_typeRisque] ?? _typeRisque,
          typeCulture: _typeCulture, superficie: _superficie, valeur: _valeur,
          simulation: state.simulation,
          confirmed: _confirmed,
          onConfirm: (v) => setState(() => _confirmed = v ?? false),
        ),
    };
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;
  const _ProgressBar({required this.step});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (step + 1) / 3,
      backgroundColor: AppColors.divider,
      valueColor: const AlwaysStoppedAnimation(Color(0xFF6A1B9A)),
      minHeight: 6,
    );
  }
}

class _NavBar extends StatelessWidget {
  final int step;
  final bool canNext, canSubmit, isLoading;
  final VoidCallback onNext, onSubmit;
  const _NavBar({
    required this.step, required this.canNext, required this.canSubmit,
    required this.isLoading, required this.onNext, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: AppColors.surface,
      child: ElevatedButton(
        onPressed: step < 2 ? (canNext ? onNext : null) : (canSubmit ? onSubmit : null),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(step < 2 ? 'Suivant' : 'Confirmer la souscription'),
      ),
    );
  }
}

class _StepZone extends StatelessWidget {
  final String zone, typeRisque;
  final List<String> zones, risques;
  final Map<String, String> risqueLabels;
  final void Function(String?) onZone, onRisque;
  const _StepZone({
    required this.zone, required this.typeRisque, required this.zones,
    required this.risques, required this.risqueLabels,
    required this.onZone, required this.onRisque,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zone et risque à couvrir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: zone,
          decoration: const InputDecoration(labelText: 'Zone géographique', prefixIcon: Icon(Icons.location_on_outlined)),
          items: zones.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
          onChanged: onZone,
        ),
        const SizedBox(height: 16),
        const Text('Type de risque à couvrir', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...risques.map((r) => RadioListTile<String>(
          value: r,
          groupValue: typeRisque,
          title: Text(risqueLabels[r] ?? r),
          onChanged: onRisque,
          activeColor: const Color(0xFF6A1B9A),
          contentPadding: EdgeInsets.zero,
        )),
      ],
    );
  }
}

class _StepExploitation extends StatelessWidget {
  final String typeCulture;
  final double superficie, valeur;
  final void Function(String) onCulture;
  final void Function(double) onSuperficie, onValeur;
  const _StepExploitation({
    required this.typeCulture, required this.superficie, required this.valeur,
    required this.onCulture, required this.onSuperficie, required this.onValeur,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Votre exploitation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextFormField(
          initialValue: typeCulture,
          decoration: const InputDecoration(
            labelText: 'Type de culture / activité',
            prefixIcon: Icon(Icons.grass_outlined),
            hintText: 'ex: Riz pluvial, Maïs, Maraîchage...',
          ),
          onChanged: onCulture,
          validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 20),
        Text('Superficie cultivée : ${superficie.toStringAsFixed(1)} ha',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        Slider(
          value: superficie, min: 0.5, max: 20, divisions: 39,
          label: '${superficie.toStringAsFixed(1)} ha', onChanged: onSuperficie,
        ),
        const SizedBox(height: 8),
        Text('Valeur assurable : ${valeur.toStringAsFixed(0)} FCFA',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        Slider(
          value: valeur, min: 100000, max: 5000000, divisions: 49,
          label: '${(valeur / 1000).toStringAsFixed(0)}k', onChanged: onValeur,
        ),
      ],
    );
  }
}

class _StepConfirmation extends StatelessWidget {
  final String zone, typeRisque, typeCulture;
  final double superficie, valeur;
  final dynamic simulation;
  final bool confirmed;
  final void Function(bool?) onConfirm;
  const _StepConfirmation({
    required this.zone, required this.typeRisque, required this.typeCulture,
    required this.superficie, required this.valeur, required this.simulation,
    required this.confirmed, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Récapitulatif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Row('Zone', zone),
                _Row('Risque couvert', typeRisque),
                _Row('Culture', typeCulture),
                _Row('Superficie', '${superficie.toStringAsFixed(1)} ha'),
                _Row('Valeur assurée', '${valeur.toStringAsFixed(0)} FCFA'),
                if (simulation != null) ...[
                  const Divider(),
                  _Row('Prime estimée', '${simulation.primeEstimee.toStringAsFixed(0)} FCFA/mois'),
                  _Row('Indemnisation max', '${simulation.indemnisationEstimee.toStringAsFixed(0)} FCFA'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: confirmed,
          onChanged: onConfirm,
          activeColor: const Color(0xFF6A1B9A),
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'J\'atteste que les informations fournies sont exactes et j\'accepte les conditions générales de souscription.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String k, v;
  const _Row(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(flex: 3, child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
