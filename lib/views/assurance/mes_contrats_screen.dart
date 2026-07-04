import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../models/assurance_model.dart';
import '../../viewmodels/assurance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class MesContratsScreen extends ConsumerStatefulWidget {
  const MesContratsScreen({super.key});

  @override
  ConsumerState<MesContratsScreen> createState() => _MesContratsScreenState();
}

class _MesContratsScreenState extends ConsumerState<MesContratsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      if (uid.isEmpty) return;
      ref.read(assuranceViewModelProvider(uid).notifier).loadContrats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(assuranceViewModelProvider(uid));

    ref.listen(assuranceViewModelProvider(uid), (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes contrats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (uid.isNotEmpty) {
                ref.read(assuranceViewModelProvider(uid).notifier).loadContrats();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.souscription),
        backgroundColor: const Color(0xFF6A1B9A),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau contrat'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (uid.isNotEmpty) {
                  await ref.read(assuranceViewModelProvider(uid).notifier).loadContrats();
                }
              },
              child: state.contrats.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 400,
                        child: _EmptyContrats(),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.contrats.length,
                      itemBuilder: (_, i) => _ContratCard(contrat: state.contrats[i]),
                    ),
            ),
    );
  }
}

class _ContratCard extends StatelessWidget {
  final ContratAssuranceModel contrat;
  const _ContratCard({required this.contrat});

  Color _statutColor() => switch (contrat.statut) {
        StatutContrat.actif => AppColors.success,
        StatutContrat.soumis => AppColors.info,
        StatutContrat.expire => AppColors.textSecondary,
        StatutContrat.sinistre => AppColors.error,
      };

  String _statutLabel() => switch (contrat.statut) {
        StatutContrat.actif => 'Actif',
        StatutContrat.soumis => 'En attente',
        StatutContrat.expire => 'Expiré',
        StatutContrat.sinistre => 'Sinistre déclaré',
      };

  @override
  Widget build(BuildContext context) {
    final color = _statutColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(Icons.shield_outlined, color: color),
            ),
            title: Text('Zone : ${contrat.zoneRisque}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Depuis le ${_fmtDate(contrat.dateDebut)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_statutLabel(),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _InfoBadge(Icons.payments_outlined,
                    '${contrat.primeMensuelle.toStringAsFixed(0)} FCFA/mois'),
                const SizedBox(width: 8),
                if (contrat.statut == StatutContrat.actif)
                  OutlinedButton.icon(
                    onPressed: () => _declarerSinistre(context),
                    icon: const Icon(Icons.warning_amber_outlined, size: 16),
                    label: const Text('Déclarer sinistre', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _declarerSinistre(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déclarer un sinistre'),
        content: const Text(
          'Votre déclaration sera transmise à votre assureur. '
          'Un agent prendra contact avec vous sous 48h.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoBadge(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EmptyContrats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_outlined, size: 80, color: AppColors.divider),
          const SizedBox(height: 16),
          const Text('Aucun contrat', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Souscrivez à un produit d\'assurance climatique pour protéger votre activité.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.fichesProduit),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Voir les produits'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
          ),
        ],
      ),
    );
  }
}
