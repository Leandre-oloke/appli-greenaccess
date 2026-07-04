import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/demande_financement_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/financement_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class DemandeFormScreen extends ConsumerStatefulWidget {
  const DemandeFormScreen({super.key});

  @override
  ConsumerState<DemandeFormScreen> createState() => _DemandeFormScreenState();
}

class _DemandeFormScreenState extends ConsumerState<DemandeFormScreen> {
  int _step = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1: Identité
  String _nom = '';
  String _pays = 'Sénégal';
  String _region = '';
  String _secteur = 'Agriculture';

  // Step 2: Projet
  String _nomProjet = '';
  String _typeActivite = 'Agriculture biologique';
  String _description = '';
  int _dureesMois = 12;

  // Step 3: Financier
  double _montant = 500000;
  String _typeFinancement = 'Micro-crédit';
  String _utilisationFonds = 'Équipement';
  String _apportPersonnel = '';

  // Step 4: Impact
  double _reductionCo2 = 0;
  int _emploisVerts = 0;
  final Set<String> _techsVertes = {};
  String _certifVisee = 'Aucune';

  // Step 5: Documents (simulated)
  final Map<String, bool> _docs = {
    'Pièce d\'identité': false,
    'Plan d\'affaires': false,
    'Preuves d\'activité': false,
    'Justificatif de domicile': false,
  };

  // Step 6: Alignement UEMOA
  final Set<String> _uemoaCriteres = {};

  // Step 7: Revue
  bool _confirmed = false;

  static const _paysList = ['Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso', 'Guinée', 'Niger', 'Togo'];
  static const _secteursList = ['Agriculture', 'Énergie renouvelable', 'Recyclage', 'Transport propre', 'Forêt / Agroforesterie', 'Pêche durable'];
  static const _typeActiviteList = ['Agriculture biologique', 'Énergie solaire', 'Recyclage / Déchets', 'Transport propre', 'Agroforesterie', 'Irrigation durable', 'Autre'];
  static const _typeFinancementList = ['Micro-crédit', 'Prêt vert', 'Subvention', 'Investissement participatif'];
  static const _utilisationList = ['Équipement', 'Fonds de roulement', 'Expansion', 'Formation / R&D'];
  static const _techsVertesList = ['Énergie solaire', 'Compostage', 'Goutte-à-goutte', 'Biodigesteur', 'Semences résistantes'];
  static const _certifList = ['Aucune', 'Agriculture biologique', 'Commerce équitable', 'ISO 14001', 'Carbone Neutre'];
  static const _uemoaList = ['Efficacité énergétique', 'Énergie renouvelable', 'Agriculture durable', 'Gestion des déchets', 'Biodiversité', 'Économie circulaire'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authViewModelProvider).user;
      if (user != null) {
        setState(() {
          _nom = user.nom;
          _pays = user.pays.isNotEmpty ? user.pays : 'Sénégal';
          _region = user.region;
          _secteur = user.secteur.isNotEmpty ? user.secteur : 'Agriculture';
        });
      }
      final uid = user?.id ?? '';
      if (uid.isNotEmpty) {
        ref.read(scoringViewModelProvider(uid).notifier).loadLatestScore();
      }
    });
  }

  Future<void> _submit() async {
    final uid = ref.read(authViewModelProvider).user?.id ?? '';
    final demande = DemandeFinancementModel(
      id: '',
      userId: uid,
      dateSoumission: DateTime.now(),
      montant: _montant,
      typeProjet: _typeActivite,
      secteur: _secteur,
      pays: _pays,
      descriptionProjet: _description,
      statut: StatutDemande.soumis,
      scoreEligibilite: ref.read(scoringViewModelProvider(uid)).currentScore?.scoreTotal ?? 0,
      docsUrl: [],
      alignementTaxonomie: _uemoaCriteres.length >= 3 ? 'Conforme' : _uemoaCriteres.isNotEmpty ? 'Partiel' : 'NonConforme',
    );
    await ref.read(financementViewModelProvider(uid).notifier).soumettreDemande(demande);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final scoreState = ref.watch(scoringViewModelProvider(uid));
    final score = scoreState.currentScore?.scoreTotal ?? 0;

    if (score < 60) {
      return Scaffold(
        appBar: AppBar(title: const Text('Demande de financement')),
        body: _ScoreBlocked(score: score),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Étape ${_step + 1} / 7'),
        leading: BackButton(onPressed: () {
          if (_step > 0) {
            setState(() => _step--);
          } else {
            context.pop();
          }
        }),
      ),
      body: Column(
        children: [
          _StepProgress(step: _step),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildStep(),
              ),
            ),
          ),
          _NavButtons(
            step: _step,
            onNext: _onNext,
            canFinish: _confirmed,
            isLoading: ref.watch(financementViewModelProvider(uid)).isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _Step1Identite(
          nom: _nom, pays: _pays, region: _region, secteur: _secteur,
          paysList: _paysList, secteursList: _secteursList,
          onNom: (v) => _nom = v,
          onPays: (v) => setState(() => _pays = v!),
          onRegion: (v) => _region = v,
          onSecteur: (v) => setState(() => _secteur = v!),
        ),
      1 => _Step2Projet(
          nomProjet: _nomProjet, typeActivite: _typeActivite,
          description: _description, dureesMois: _dureesMois,
          typeList: _typeActiviteList,
          onNom: (v) => _nomProjet = v,
          onType: (v) => setState(() => _typeActivite = v!),
          onDesc: (v) => _description = v,
          onDuree: (v) => setState(() => _dureesMois = v),
        ),
      2 => _Step3Financier(
          montant: _montant, typeFinancement: _typeFinancement,
          utilisation: _utilisationFonds, apport: _apportPersonnel,
          typeList: _typeFinancementList, utilisationList: _utilisationList,
          onMontant: (v) => setState(() => _montant = v),
          onType: (v) => setState(() => _typeFinancement = v!),
          onUtil: (v) => setState(() => _utilisationFonds = v!),
          onApport: (v) => _apportPersonnel = v,
        ),
      3 => _Step4Impact(
          reductionCo2: _reductionCo2, emplois: _emploisVerts,
          techsVertes: _techsVertes, certif: _certifVisee,
          techsList: _techsVertesList, certifList: _certifList,
          onCo2: (v) => setState(() => _reductionCo2 = v),
          onEmplois: (v) => setState(() => _emploisVerts = v),
          onTechToggle: (t) => setState(() {
            if (_techsVertes.contains(t)) { _techsVertes.remove(t); } else { _techsVertes.add(t); }
          }),
          onCertif: (v) => setState(() => _certifVisee = v!),
        ),
      4 => _Step5Docs(docs: _docs, onToggle: (k) => setState(() => _docs[k] = !(_docs[k]!))),
      5 => _Step6UEMOA(
          selected: _uemoaCriteres,
          onToggle: (c) => setState(() {
            if (_uemoaCriteres.contains(c)) { _uemoaCriteres.remove(c); } else { _uemoaCriteres.add(c); }
          }),
          criteres: _uemoaList,
        ),
      _ => _Step7Revue(
          nom: _nom, pays: _pays, secteur: _secteur,
          typeActivite: _typeActivite, montant: _montant,
          typeFinancement: _typeFinancement, reductionCo2: _reductionCo2,
          uemoaCriteres: _uemoaCriteres.length,
          confirmed: _confirmed,
          onConfirm: (v) => setState(() => _confirmed = v ?? false),
        ),
    };
  }

  void _onNext() {
    if (_step < 6) {
      setState(() => _step++);
    } else if (_confirmed) {
      _submit();
    }
  }
}

class _StepProgress extends StatelessWidget {
  final int step;
  const _StepProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(7, (i) {
          final done = i < step;
          final active = i == step;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: done ? AppColors.success : active ? AppColors.secondary : AppColors.divider,
                  child: done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('${i + 1}', style: TextStyle(fontSize: 11, color: active ? Colors.white : AppColors.textSecondary)),
                ),
                if (i < 6)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done ? AppColors.success : AppColors.divider,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _NavButtons extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  final bool canFinish;
  final bool isLoading;
  const _NavButtons({required this.step, required this.onNext, required this.canFinish, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: AppColors.surface,
      child: ElevatedButton(
        onPressed: (step == 6 && !canFinish) || isLoading ? null : onNext,
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(step < 6 ? 'Suivant' : 'Soumettre la demande'),
      ),
    );
  }
}

// ─── Step widgets ────────────────────────────────────────────────────────────

class _Step1Identite extends StatelessWidget {
  final String nom, pays, region, secteur;
  final List<String> paysList, secteursList;
  final void Function(String) onNom, onRegion;
  final void Function(String?) onPays, onSecteur;
  const _Step1Identite({
    required this.nom, required this.pays, required this.region, required this.secteur,
    required this.paysList, required this.secteursList,
    required this.onNom, required this.onRegion, required this.onPays, required this.onSecteur,
  });

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Identité & Profil',
      icon: Icons.person_outline,
      children: [
        _field('Nom complet', initialValue: nom, onChanged: onNom, required: true),
        const SizedBox(height: 12),
        _dropdown('Pays', value: pays, items: paysList, onChanged: onPays),
        const SizedBox(height: 12),
        _field('Région / Ville', initialValue: region, onChanged: onRegion),
        const SizedBox(height: 12),
        _dropdown('Secteur d\'activité', value: secteur, items: secteursList, onChanged: onSecteur),
      ],
    );
  }
}

class _Step2Projet extends StatelessWidget {
  final String nomProjet, typeActivite, description;
  final int dureesMois;
  final List<String> typeList;
  final void Function(String) onNom, onDesc;
  final void Function(String?) onType;
  final void Function(int) onDuree;
  const _Step2Projet({
    required this.nomProjet, required this.typeActivite, required this.description,
    required this.dureesMois, required this.typeList,
    required this.onNom, required this.onDesc, required this.onType, required this.onDuree,
  });

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Description du projet',
      icon: Icons.description_outlined,
      children: [
        _field('Nom du projet', initialValue: nomProjet, onChanged: onNom, required: true),
        const SizedBox(height: 12),
        _dropdown('Type d\'activité verte', value: typeActivite, items: typeList, onChanged: onType),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: description,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Description du projet', alignLabelWithHint: true),
          onChanged: onDesc,
          validator: (v) => v == null || v.trim().length < 20 ? 'Minimum 20 caractères' : null,
        ),
        const SizedBox(height: 12),
        Text('Durée : $dureesMois mois', style: const TextStyle(fontWeight: FontWeight.w500)),
        Slider(
          value: dureesMois.toDouble(),
          min: 6, max: 60, divisions: 9,
          label: '$dureesMois mois',
          onChanged: (v) => onDuree(v.round()),
        ),
      ],
    );
  }
}

class _Step3Financier extends StatelessWidget {
  final double montant;
  final String typeFinancement, utilisation, apport;
  final List<String> typeList, utilisationList;
  final void Function(double) onMontant;
  final void Function(String?) onType, onUtil;
  final void Function(String) onApport;
  const _Step3Financier({
    required this.montant, required this.typeFinancement, required this.utilisation,
    required this.apport, required this.typeList, required this.utilisationList,
    required this.onMontant, required this.onType, required this.onUtil, required this.onApport,
  });

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Aspect financier',
      icon: Icons.payments_outlined,
      children: [
        Text(
          'Montant demandé: ${montant.toStringAsFixed(0)} FCFA',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Slider(
          value: montant,
          min: 100000, max: 50000000,
          divisions: 499,
          label: '${(montant / 1000).toStringAsFixed(0)}k FCFA',
          onChanged: onMontant,
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('100k FCFA', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text('50M FCFA', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 16),
        _dropdown('Type de financement', value: typeFinancement, items: typeList, onChanged: onType),
        const SizedBox(height: 12),
        _dropdown('Utilisation des fonds', value: utilisation, items: utilisationList, onChanged: onUtil),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: apport,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Apport personnel (FCFA)', prefixIcon: Icon(Icons.savings_outlined)),
          onChanged: onApport,
        ),
      ],
    );
  }
}

class _Step4Impact extends StatelessWidget {
  final double reductionCo2;
  final int emplois;
  final Set<String> techsVertes;
  final String certif;
  final List<String> techsList, certifList;
  final void Function(double) onCo2;
  final void Function(int) onEmplois;
  final void Function(String) onTechToggle;
  final void Function(String?) onCertif;
  const _Step4Impact({
    required this.reductionCo2, required this.emplois, required this.techsVertes,
    required this.certif, required this.techsList, required this.certifList,
    required this.onCo2, required this.onEmplois, required this.onTechToggle, required this.onCertif,
  });

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Impact environnemental',
      icon: Icons.eco_outlined,
      children: [
        Text('Réduction CO₂ estimée: ${reductionCo2.round()} t/an',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        Slider(value: reductionCo2, min: 0, max: 500, onChanged: onCo2,
            label: '${reductionCo2.round()} t'),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Emplois verts créés:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: emplois > 0 ? () => onEmplois(emplois - 1) : null),
            Text('$emplois', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => onEmplois(emplois + 1)),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Technologies vertes utilisées:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: techsList.map((t) => FilterChip(
            label: Text(t, style: const TextStyle(fontSize: 12)),
            selected: techsVertes.contains(t),
            onSelected: (_) => onTechToggle(t),
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
          )).toList(),
        ),
        const SizedBox(height: 12),
        _dropdown('Certification visée', value: certif, items: certifList, onChanged: onCertif),
      ],
    );
  }
}

class _Step5Docs extends StatelessWidget {
  final Map<String, bool> docs;
  final void Function(String) onToggle;
  const _Step5Docs({required this.docs, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Documents requis',
      icon: Icons.folder_outlined,
      children: [
        const Text(
          'Cochez les documents que vous pouvez fournir. '
          'Vous pourrez télécharger les fichiers après la soumission.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...docs.entries.map((e) => CheckboxListTile(
              title: Text(e.key),
              value: e.value,
              onChanged: (_) => onToggle(e.key),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            )),
      ],
    );
  }
}

class _Step6UEMOA extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;
  final List<String> criteres;
  const _Step6UEMOA({required this.selected, required this.onToggle, required this.criteres});

  @override
  Widget build(BuildContext context) {
    final score = selected.length;
    final alignement = score >= 4 ? 'Conforme' : score >= 1 ? 'Partiel' : 'Non conforme';
    final color = score >= 4 ? AppColors.success : score >= 1 ? AppColors.warning : AppColors.error;

    return _StepCard(
      title: 'Alignement Taxonomie UEMOA',
      icon: Icons.verified_outlined,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.flag, color: color, size: 20),
              const SizedBox(width: 8),
              Text('Alignement: $alignement ($score/6 critères)',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...criteres.map((c) => CheckboxListTile(
              title: Text(c),
              value: selected.contains(c),
              onChanged: (_) => onToggle(c),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            )),
      ],
    );
  }
}

class _Step7Revue extends StatelessWidget {
  final String nom, pays, secteur, typeActivite, typeFinancement;
  final double montant, reductionCo2;
  final int uemoaCriteres;
  final bool confirmed;
  final void Function(bool?) onConfirm;
  const _Step7Revue({
    required this.nom, required this.pays, required this.secteur,
    required this.typeActivite, required this.montant, required this.typeFinancement,
    required this.reductionCo2, required this.uemoaCriteres,
    required this.confirmed, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'Revue et soumission',
      icon: Icons.check_circle_outline,
      children: [
        _SummaryRow('Porteur de projet', nom),
        _SummaryRow('Pays', pays),
        _SummaryRow('Secteur', secteur),
        _SummaryRow('Type d\'activité', typeActivite),
        _SummaryRow('Montant demandé', '${montant.toStringAsFixed(0)} FCFA'),
        _SummaryRow('Type de financement', typeFinancement),
        _SummaryRow('Réduction CO₂', '${reductionCo2.round()} t/an'),
        _SummaryRow('Alignement UEMOA', '$uemoaCriteres/6 critères'),
        const Divider(height: 24),
        CheckboxListTile(
          value: confirmed,
          onChanged: onConfirm,
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'J\'atteste sur l\'honneur que toutes les informations fournies sont exactes et complètes.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _StepCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.secondary, size: 24),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.secondary)),
          ],
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

Widget _field(String label, {required String initialValue, required void Function(String) onChanged, bool required = false}) {
  return TextFormField(
    initialValue: initialValue,
    decoration: InputDecoration(labelText: label),
    onChanged: onChanged,
    validator: required ? (v) => v == null || v.trim().isEmpty ? 'Requis' : null : null,
  );
}

Widget _dropdown(String label, {required String value, required List<String> items, required void Function(String?) onChanged}) {
  return DropdownButtonFormField<String>(
    value: value,
    decoration: InputDecoration(labelText: label),
    items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
    onChanged: onChanged,
  );
}

class _ScoreBlocked extends StatelessWidget {
  final double score;
  const _ScoreBlocked({required this.score});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 80, color: AppColors.error),
          const SizedBox(height: 24),
          const Text('Score insuffisant', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Votre score Climat actuel est ${score.round()}/100. '
            'Un score minimum de 60/100 est requis pour soumettre une demande de financement.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/scoring'),
            icon: const Icon(Icons.eco_outlined),
            label: const Text('Améliorer mon score via Formation'),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: () => context.pop(), child: const Text('Retour')),
        ],
      ),
    );
  }
}
