import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/demande_financement_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/financement_viewmodel.dart';

class StatutDemandeScreen extends ConsumerStatefulWidget {
  final String demandeId;
  const StatutDemandeScreen({super.key, required this.demandeId});

  @override
  ConsumerState<StatutDemandeScreen> createState() => _StatutDemandeScreenState();
}

class _StatutDemandeScreenState extends ConsumerState<StatutDemandeScreen> {
  DemandeFinancementModel? _demande;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(authViewModelProvider).user?.id ?? '';
    final d = await ref.read(financementViewModelProvider(uid).notifier).getStatut(widget.demandeId);
    if (mounted) setState(() { _demande = d; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statut de la demande')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _demande == null
              ? const Center(child: Text('Demande introuvable'))
              : _DemandeDetail(demande: _demande!),
    );
  }
}

class _DemandeDetail extends StatelessWidget {
  final DemandeFinancementModel demande;
  const _DemandeDetail({required this.demande});

  static const _steps = [
    StatutDemande.soumis,
    StatutDemande.enExamen,
    StatutDemande.approuve,
    StatutDemande.finance,
  ];

  int get _currentStepIndex {
    if (demande.statut == StatutDemande.rejete) return 1;
    return _steps.indexOf(demande.statut).clamp(0, _steps.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final isRejete = demande.statut == StatutDemande.rejete;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(demande: demande),
          const SizedBox(height: 16),
          if (isRejete) _RejectionCard(motif: demande.commentaireRejet)
          else _TimelineCard(currentIndex: _currentStepIndex),
          const SizedBox(height: 16),
          _DetailsCard(demande: demande),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final DemandeFinancementModel demande;
  const _HeaderCard({required this.demande});

  Color _color() => switch (demande.statut) {
        StatutDemande.soumis => AppColors.info,
        StatutDemande.enExamen => AppColors.warning,
        StatutDemande.approuve => AppColors.success,
        StatutDemande.finance => AppColors.scoreExcellent,
        StatutDemande.rejete => AppColors.error,
        StatutDemande.brouillon => AppColors.textSecondary,
      };

  String _label() => switch (demande.statut) {
        StatutDemande.soumis => 'Soumis',
        StatutDemande.enExamen => 'En examen',
        StatutDemande.approuve => 'Approuvé',
        StatutDemande.finance => 'Financé',
        StatutDemande.rejete => 'Rejeté',
        StatutDemande.brouillon => 'Brouillon',
      };

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(Icons.description_outlined, color: color, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              '${demande.montant.toStringAsFixed(0)} FCFA',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(demande.typeProjet, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_label(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final int currentIndex;
  const _TimelineCard({required this.currentIndex});

  static const _labels = ['Soumis', 'En examen', 'Approuvé', 'Financé'];
  static const _icons = [
    Icons.send_outlined,
    Icons.search_outlined,
    Icons.check_circle_outline,
    Icons.payments_outlined,
  ];
  static const _descriptions = [
    'Votre demande a été reçue',
    'Un analyste étudie votre dossier',
    'Votre demande est approuvée',
    'Les fonds ont été débloqués',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Avancement du dossier',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            ...List.generate(_labels.length, (i) {
              final done = i <= currentIndex;
              final active = i == currentIndex;
              return _TimelineStep(
                icon: _icons[i],
                label: _labels[i],
                description: _descriptions[i],
                done: done,
                active: active,
                isLast: i == _labels.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String label, description;
  final bool done, active, isLast;
  const _TimelineStep({
    required this.icon, required this.label, required this.description,
    required this.done, required this.active, required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.primary : AppColors.divider;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 18, color: color),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: done ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        color: done ? AppColors.textPrimary : AppColors.textSecondary,
                      )),
                  Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectionCard extends StatelessWidget {
  final String? motif;
  const _RejectionCard({required this.motif});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.error.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cancel_outlined, color: AppColors.error),
                SizedBox(width: 8),
                Text('Demande rejetée', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              ],
            ),
            if (motif != null) ...[
              const SizedBox(height: 8),
              Text('Motif : $motif', style: const TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            const Text(
              'Améliorez votre dossier en complétant davantage de formations et en augmentant votre score Climat avant de soumettre une nouvelle demande.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final DemandeFinancementModel demande;
  const _DetailsCard({required this.demande});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Détails', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            _Row('Secteur', demande.secteur),
            _Row('Pays', demande.pays),
            _Row('Score d\'éligibilité', '${demande.scoreEligibilite.round()}/100'),
            _Row('Alignement UEMOA', demande.alignementTaxonomie),
            _Row('Soumis le', _fmtDate(demande.dateSoumission)),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
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
