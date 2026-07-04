import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/demande_financement_model.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminDemandesScreen extends ConsumerStatefulWidget {
  const AdminDemandesScreen({super.key});
  @override
  ConsumerState<AdminDemandesScreen> createState() => _AdminDemandesScreenState();
}

class _AdminDemandesScreenState extends ConsumerState<AdminDemandesScreen> {
  StatutDemande? _filtre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminViewModelProvider.notifier).loadDemandes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);

    ref.listen(adminViewModelProvider, (_, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: AppColors.success),
        );
        ref.read(adminViewModelProvider.notifier).clearMessages();
      }
    });

    final demandes = _filtre == null
        ? state.demandes
        : state.demandes.where((d) => d.statut == _filtre).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Demandes de financement (${state.demandes.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _FilterChip(label: 'Tous', selected: _filtre == null, onTap: () => setState(() => _filtre = null)),
                ...StatutDemande.values.map((s) => _FilterChip(
                  label: _statutLabel(s),
                  selected: _filtre == s,
                  onTap: () => setState(() => _filtre = s),
                  color: _statutColor(s),
                )),
              ],
            ),
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : demandes.isEmpty
              ? const Center(child: Text('Aucune demande'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: demandes.length,
                  itemBuilder: (context, i) => _DemandeCard(
                    demande: demandes[i],
                    onApprouver: () => ref.read(adminViewModelProvider.notifier).approuverDemande(demandes[i].id),
                    onRejeter: () => _showRejetDialog(context, demandes[i].id),
                  ),
                ),
    );
  }

  void _showRejetDialog(BuildContext context, String id) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motif de rejet'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Expliquez pourquoi cette demande est rejetée…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminViewModelProvider.notifier).rejeterDemande(id, ctrl.text.trim());
            },
            child: const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static String _statutLabel(StatutDemande s) => switch (s) {
    StatutDemande.brouillon  => 'Brouillon',
    StatutDemande.soumis     => 'Soumis',
    StatutDemande.enExamen   => 'En examen',
    StatutDemande.approuve   => 'Approuvé',
    StatutDemande.rejete     => 'Rejeté',
    StatutDemande.finance    => 'Financé',
  };

  static Color _statutColor(StatutDemande s) => switch (s) {
    StatutDemande.brouillon  => Colors.grey,
    StatutDemande.soumis     => AppColors.warning,
    StatutDemande.enExamen   => AppColors.info,
    StatutDemande.approuve   => AppColors.success,
    StatutDemande.rejete     => AppColors.error,
    StatutDemande.finance    => AppColors.primary,
  };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : Colors.white54),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.primary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            )),
      ),
    );
  }
}

class _DemandeCard extends StatelessWidget {
  final DemandeFinancementModel demande;
  final VoidCallback onApprouver;
  final VoidCallback onRejeter;
  const _DemandeCard({required this.demande, required this.onApprouver, required this.onRejeter});

  static const _colors = {
    StatutDemande.brouillon: Colors.grey,
    StatutDemande.soumis:    AppColors.warning,
    StatutDemande.enExamen:  AppColors.info,
    StatutDemande.approuve:  AppColors.success,
    StatutDemande.rejete:    AppColors.error,
    StatutDemande.finance:   AppColors.primary,
  };

  static const _labels = {
    StatutDemande.brouillon: 'Brouillon',
    StatutDemande.soumis:    'Soumis',
    StatutDemande.enExamen:  'En examen',
    StatutDemande.approuve:  'Approuvé',
    StatutDemande.rejete:    'Rejeté',
    StatutDemande.finance:   'Financé',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[demande.statut] ?? Colors.grey;
    final fmt = NumberFormat('#,##0', 'fr_FR');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(demande.typeProjet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(_labels[demande.statut] ?? '', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${demande.secteur} · ${demande.pays}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Text('Montant : ${fmt.format(demande.montant)} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Score ESG : ${demande.scoreEligibilite.toStringAsFixed(0)}/100 · ${demande.alignementTaxonomie}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('Soumis le ${DateFormat('dd/MM/yyyy').format(demande.dateSoumission)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (demande.commentaireRejet != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Rejet : ${demande.commentaireRejet}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error)),
              ),
            if (demande.statut == StatutDemande.soumis || demande.statut == StatutDemande.enExamen) ...[
              const Divider(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRejeter,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprouver,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approuver'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
