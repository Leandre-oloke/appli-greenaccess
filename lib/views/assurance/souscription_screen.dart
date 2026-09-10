import 'dart:io';
import 'package:file_picker/file_picker.dart';
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

  // Step 4 — documents
  File? _pieceIdentite;
  File? _preuveActivite;
  bool _uploading = false;

  static const _totalSteps = 4;
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
    final isLastStep = _step == _totalSteps - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Souscription — Étape ${_step + 1}/$_totalSteps'),
        leading: BackButton(onPressed: () {
          if (_step > 0) { setState(() => _step--); } else { context.pop(); }
        }),
      ),
      body: Column(
        children: [
          _ProgressBar(step: _step, total: _totalSteps),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStep(state),
            ),
          ),
          _NavBar(
            step: _step,
            total: _totalSteps,
            canNext: _stepValid(),
            isLoading: state.isLoading || _uploading,
            onNext: () => setState(() => _step++),
            onSubmit: isLastStep ? () => _submit(uid, state) : null,
          ),
        ],
      ),
    );
  }

  bool _stepValid() {
    if (_step == 0) return _zone.isNotEmpty && _typeRisque.isNotEmpty;
    if (_step == 1) return _typeCulture.trim().isNotEmpty;
    if (_step == 2) return _confirmed;
    return true; // step 3 (documents) : facultatif
  }

  Future<void> _submit(String uid, AssuranceState state) async {
    // Étape 1 : créer le contrat si pas encore fait
    if (state.contratActif == null) {
      final simulation = state.simulation;
      await ref.read(assuranceViewModelProvider(uid).notifier).soumettreSouscription({
        'zone_risque': _zone,
        'produit_id': simulation?.produitRecommande.id ?? 'default',
        'prime_mensuelle': simulation?.primeEstimee ?? 5000,
        'type_culture': _typeCulture,
        'superficie': _superficie,
        'assureur_id': 'ASSUREUR_01',
        'date_debut': DateTime.now(),
      });
    }

    // Étape 2 : upload documents si sélectionnés
    final contratId = ref.read(assuranceViewModelProvider(uid)).contratActif?.id;
    if (contratId != null && (_pieceIdentite != null || _preuveActivite != null)) {
      setState(() => _uploading = true);
      final vm = ref.read(assuranceViewModelProvider(uid).notifier);
      await Future.wait([
        if (_pieceIdentite != null)
          vm.uploadDocument(
            contratId: contratId,
            file: _pieceIdentite!,
            nomDocument: 'piece_identite',
          ),
        if (_preuveActivite != null)
          vm.uploadDocument(
            contratId: contratId,
            file: _preuveActivite!,
            nomDocument: 'preuve_activite',
          ),
      ]);
      setState(() => _uploading = false);
    }

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
      2 => _StepConfirmation(
          zone: _zone, typeRisque: _risqueLabels[_typeRisque] ?? _typeRisque,
          typeCulture: _typeCulture, superficie: _superficie, valeur: _valeur,
          simulation: state.simulation,
          confirmed: _confirmed,
          onConfirm: (v) => setState(() => _confirmed = v ?? false),
        ),
      _ => _StepDocuments(
          pieceIdentite: _pieceIdentite,
          preuveActivite: _preuveActivite,
          onPieceIdentite: (f) => setState(() => _pieceIdentite = f),
          onPreuveActivite: (f) => setState(() => _preuveActivite = f),
        ),
    };
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (step + 1) / total,
      backgroundColor: AppColors.divider,
      valueColor: const AlwaysStoppedAnimation(Color(0xFF6A1B9A)),
      minHeight: 6,
    );
  }
}

class _NavBar extends StatelessWidget {
  final int step;
  final int total;
  final bool canNext;
  final bool isLoading;
  final VoidCallback onNext;
  final VoidCallback? onSubmit;
  const _NavBar({
    required this.step,
    required this.total,
    required this.canNext,
    required this.isLoading,
    required this.onNext,
    required this.onSubmit,
  });

  bool get _isLastStep => step == total - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLastStep)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Documents facultatifs — vous pouvez les ajouter plus tard',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : (_isLastStep ? onSubmit : (canNext ? onNext : null)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(_isLastStep ? 'Terminer la souscription' : 'Suivant'),
          ),
        ],
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

class _StepDocuments extends StatelessWidget {
  final File? pieceIdentite;
  final File? preuveActivite;
  final void Function(File) onPieceIdentite;
  final void Function(File) onPreuveActivite;

  const _StepDocuments({
    required this.pieceIdentite,
    required this.preuveActivite,
    required this.onPieceIdentite,
    required this.onPreuveActivite,
  });

  Future<void> _pickFile(BuildContext context, void Function(File) onPicked) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      onPicked(File(result.files.single.path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Documents justificatifs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Ces documents sont facultatifs et peuvent être ajoutés plus tard depuis votre espace contrats.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _DocTile(
          label: 'Pièce d\'identité',
          subtitle: 'CNI, passeport ou tout document officiel',
          icon: Icons.badge_outlined,
          file: pieceIdentite,
          onPick: () => _pickFile(context, onPieceIdentite),
        ),
        const SizedBox(height: 12),
        _DocTile(
          label: 'Preuves d\'activité',
          subtitle: 'Photos, registre ou attestation d\'exploitation',
          icon: Icons.agriculture_outlined,
          file: preuveActivite,
          onPick: () => _pickFile(context, onPreuveActivite),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, color: AppColors.info, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Formats acceptés : PDF, JPG, PNG. Taille max : 5 Mo par document. Vos documents sont stockés de façon sécurisée.',
                  style: TextStyle(fontSize: 12, color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocTile extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final File? file;
  final VoidCallback onPick;

  const _DocTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.file,
    required this.onPick,
  });

  String get _fileName => file?.path.split(Platform.pathSeparator).last ?? '';

  @override
  Widget build(BuildContext context) {
    final selected = file != null;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.success : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.success.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: (selected ? AppColors.success : const Color(0xFF6A1B9A))
                  .withValues(alpha: 0.12),
              child: Icon(
                selected ? Icons.check_circle_outline : icon,
                color: selected ? AppColors.success : const Color(0xFF6A1B9A),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    selected ? _fileName : subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? AppColors.success : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.edit_outlined : Icons.upload_file_outlined,
              color: selected ? AppColors.success : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
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
