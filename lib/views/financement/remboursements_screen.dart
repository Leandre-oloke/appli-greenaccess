import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/remboursement_model.dart';
import '../../routes.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/financement_viewmodel.dart';

class RemboursementsScreen extends ConsumerStatefulWidget {
  final String demandeId;
  final double montantTotal;
  const RemboursementsScreen({
    super.key,
    required this.demandeId,
    required this.montantTotal,
  });

  @override
  ConsumerState<RemboursementsScreen> createState() => _RemboursementsScreenState();
}

class _RemboursementsScreenState extends ConsumerState<RemboursementsScreen> {
  List<RemboursementModel> _echeances = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(authViewModelProvider).user?.id ?? '';
    final list = await ref
        .read(financementViewModelProvider(uid).notifier)
        .getRemboursements(widget.demandeId);

    if (!mounted) return;
    if (list.isEmpty) {
      // Génère l'échéancier automatiquement si absent (12 mois par défaut)
      await ref.read(financementViewModelProvider(uid).notifier).genererEcheancier(
            demandeId: widget.demandeId,
            montantTotal: widget.montantTotal,
            dureesMois: 12,
            dateDebut: DateTime.now(),
          );
      final generated = await ref
          .read(financementViewModelProvider(uid).notifier)
          .getRemboursements(widget.demandeId);
      if (mounted) setState(() { _echeances = generated; _loading = false; });
    } else {
      setState(() { _echeances = list; _loading = false; });
    }
  }

  int get _nbPayees => _echeances.where((e) => e.paye).length;
  double get _montantRestant => _echeances
      .where((e) => !e.paye)
      .fold(0.0, (sum, e) => sum + e.montant);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final total = _echeances.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Échéancier de remboursement'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Résumé ────────────────────────────────────────────────
                Container(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: 'Payées',
                          value: '$_nbPayees/$total',
                          color: AppColors.success,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Restant dû',
                          value: '${fmt.format(_montantRestant)} FCFA',
                          color: AppColors.warning,
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Barre de progression ──────────────────────────────────
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Progression', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${((_nbPayees / total) * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _nbPayees / total,
                          backgroundColor: AppColors.divider,
                          color: AppColors.success,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // ── Liste des échéances ───────────────────────────────────
                Expanded(
                  child: _echeances.isEmpty
                      ? const Center(child: Text('Aucune échéance disponible'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _echeances.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _EcheanceTile(
                            echeance: _echeances[i],
                            demandeId: widget.demandeId,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SummaryTile({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EcheanceTile extends StatelessWidget {
  final RemboursementModel echeance;
  final String demandeId;
  const _EcheanceTile({required this.echeance, required this.demandeId});

  void _payer(BuildContext context) {
    context.push(
      AppRoutes.paiementPath(demandeId, echeance.id),
      extra: {'numeroEcheance': echeance.numeroEcheance, 'montant': echeance.montant},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPast = echeance.dateEcheance.isBefore(DateTime.now()) && !echeance.paye;
    final fmt = NumberFormat('#,##0', 'fr_FR');

    Color borderColor;
    Color iconColor;
    IconData icon;

    if (echeance.paye) {
      borderColor = AppColors.success;
      iconColor = AppColors.success;
      icon = Icons.check_circle;
    } else if (isPast) {
      borderColor = AppColors.error;
      iconColor = AppColors.error;
      icon = Icons.warning_amber_rounded;
    } else {
      borderColor = AppColors.divider;
      iconColor = AppColors.textSecondary;
      icon = Icons.radio_button_unchecked;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: echeance.paye ? AppColors.success.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Échéance ${echeance.numeroEcheance}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      DateFormat('dd MMMM yyyy', 'fr').format(echeance.dateEcheance),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPast ? AppColors.error : AppColors.textSecondary,
                        fontWeight: isPast ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (echeance.paye && echeance.datePaiement != null)
                      Text(
                        'Payé le ${DateFormat('dd/MM/yyyy').format(echeance.datePaiement!)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.success),
                      ),
                    if (isPast)
                      const Text('En retard',
                          style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text(
                '${fmt.format(echeance.montant)} FCFA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: echeance.paye ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (!echeance.paye) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _payer(context),
                icon: const Icon(Icons.payment_outlined, size: 16),
                label: const Text('Payer cette échéance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPast ? AppColors.error : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
