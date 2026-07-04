import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../models/demande_financement_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/financement_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class FinancementScreen extends ConsumerStatefulWidget {
  const FinancementScreen({super.key});

  @override
  ConsumerState<FinancementScreen> createState() => _FinancementScreenState();
}

class _FinancementScreenState extends ConsumerState<FinancementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      if (uid.isEmpty) return;
      ref.read(financementViewModelProvider(uid).notifier).loadDemandes();
      ref.read(scoringViewModelProvider(uid).notifier).loadLatestScore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final finState = ref.watch(financementViewModelProvider(uid));
    final scoreState = ref.watch(scoringViewModelProvider(uid));

    final score = scoreState.currentScore?.scoreTotal ?? 0;
    final eligible = score >= 60;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financementViewModelProvider(uid));
          ref.invalidate(scoringViewModelProvider(uid));
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('Micro-Financement Vert'),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2D7D46), Color(0xFF1B5E34)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.account_balance, size: 60, color: Colors.white24),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EligibilityCard(score: score, eligible: eligible),
                    const SizedBox(height: 16),
                    _QuickActionsRow(eligible: eligible),
                    const SizedBox(height: 20),
                    if (finState.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      _SectionTitle('Mes demandes (${finState.demandes.length})'),
                      const SizedBox(height: 8),
                      if (finState.demandes.isEmpty)
                        _EmptyDemandes()
                      else
                        ...finState.demandes.map((d) => _DemandeCard(
                              demande: d,
                              onTap: () => context.push('/financement/statut/${d.id}'),
                            )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: eligible
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.demandeForm),
              backgroundColor: AppColors.secondary,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle demande'),
            )
          : null,
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  final double score;
  final bool eligible;
  const _EligibilityCard({required this.score, required this.eligible});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: eligible ? AppColors.success.withValues(alpha: 0.08) : AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: eligible ? AppColors.success : AppColors.warning,
              child: Icon(
                eligible ? Icons.check_circle : Icons.warning_amber,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eligible ? 'Éligible au financement' : 'Score insuffisant',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: eligible ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  Text(
                    eligible
                        ? 'Score Climat: ${score.round()}/100 ✓'
                        : 'Score: ${score.round()}/100 — Minimum requis: 60/100',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (!eligible)
              TextButton(
                onPressed: () => context.push(AppRoutes.scoringForm),
                child: const Text('Améliorer'),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final bool eligible;
  const _QuickActionsRow({required this.eligible});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.calculate_outlined,
            label: 'Simuler',
            color: AppColors.secondary,
            onTap: () => context.push(AppRoutes.demandeForm),
            enabled: eligible,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.people_outline,
            label: 'Partenaires',
            color: AppColors.info,
            onTap: () => context.push(AppRoutes.partenaires),
            enabled: true,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: enabled ? color.withValues(alpha: 0.3) : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: enabled ? color : Colors.grey, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: enabled ? color : Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      );
}

class _DemandeCard extends StatelessWidget {
  final DemandeFinancementModel demande;
  final VoidCallback onTap;
  const _DemandeCard({required this.demande, required this.onTap});

  Color _statutColor() => switch (demande.statut) {
        StatutDemande.brouillon => AppColors.textSecondary,
        StatutDemande.soumis => AppColors.info,
        StatutDemande.enExamen => AppColors.warning,
        StatutDemande.approuve => AppColors.success,
        StatutDemande.rejete => AppColors.error,
        StatutDemande.finance => AppColors.scoreExcellent,
      };

  String _statutLabel() => switch (demande.statut) {
        StatutDemande.brouillon => 'Brouillon',
        StatutDemande.soumis => 'Soumis',
        StatutDemande.enExamen => 'En examen',
        StatutDemande.approuve => 'Approuvé',
        StatutDemande.rejete => 'Rejeté',
        StatutDemande.finance => 'Financé',
      };

  @override
  Widget build(BuildContext context) {
    final color = _statutColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.description_outlined, color: color),
        ),
        title: Text(
          '${demande.montant.toStringAsFixed(0)} FCFA  ·  ${demande.typeProjet}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          _formatDate(demande.dateSoumission),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_statutLabel(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _EmptyDemandes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 52, color: AppColors.divider),
          const SizedBox(height: 12),
          const Text('Aucune demande', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text(
            'Soumettez votre première demande de financement vert.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
