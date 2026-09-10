import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminViewModelProvider.notifier).loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);
    final user  = ref.watch(authViewModelProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Administration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Bonjour, ${user?.nom.split(' ').first ?? 'Admin'}',
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Vue utilisateur',
            icon: const Icon(Icons.switch_account_outlined),
            onPressed: () => context.go(AppRoutes.dashboard),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminViewModelProvider.notifier).loadDashboard(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(adminViewModelProvider.notifier).loadDashboard(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Cartes stats ────────────────────────────────────────────
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      _StatCard(
                        label: 'Utilisateurs',
                        value: '${state.stats['users'] ?? 0}',
                        icon: Icons.people,
                        color: AppColors.primary,
                        onTap: () => context.go(AppRoutes.adminUsers),
                      ),
                      _StatCard(
                        label: 'Formations',
                        value: '${state.stats['courses'] ?? 0}',
                        icon: Icons.school,
                        color: AppColors.secondary,
                        onTap: () => context.go(AppRoutes.adminFormations),
                      ),
                      _StatCard(
                        label: 'Demandes financement',
                        value: '${state.stats['demandes'] ?? 0}',
                        icon: Icons.account_balance,
                        color: AppColors.scoreBon,
                        onTap: () => context.go(AppRoutes.adminDemandes),
                      ),
                      _StatCard(
                        label: 'Sinistres déclarés',
                        value: '${state.stats['sinistres'] ?? 0}',
                        icon: Icons.report_problem_outlined,
                        color: AppColors.error,
                        onTap: () => context.go(AppRoutes.adminContrats),
                      ),
                      _StatCard(
                        label: 'Contrats assurance',
                        value: '${state.stats['contrats'] ?? 0}',
                        icon: Icons.shield_outlined,
                        color: const Color(0xFF6A1B9A),
                        onTap: () => context.go(AppRoutes.adminContrats),
                      ),
                      _StatCard(
                        label: 'Dossiers à vérifier',
                        value: '${state.stats['contratsAVerifier'] ?? 0}',
                        icon: Icons.fact_check_outlined,
                        color: AppColors.error,
                        onTap: () => context.go(AppRoutes.adminContrats),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Accès rapide ────────────────────────────────────────────
                  const Text('Gestion rapide',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.add_circle_outline,
                    color: AppColors.primary,
                    title: 'Ajouter un module de formation',
                    subtitle: 'Créer un nouveau cours, quiz ou infographie',
                    onTap: () => context.go(AppRoutes.adminCourseNew),
                  ),
                  _ActionTile(
                    icon: Icons.people_outline,
                    color: AppColors.secondary,
                    title: 'Gérer les utilisateurs',
                    subtitle: 'Changer les rôles, désactiver des comptes',
                    onTap: () => context.go(AppRoutes.adminUsers),
                  ),
                  _ActionTile(
                    icon: Icons.assignment_turned_in_outlined,
                    color: AppColors.scoreBon,
                    title: 'Examiner les demandes',
                    subtitle: 'Approuver ou rejeter les demandes en attente',
                    onTap: () => context.go(AppRoutes.adminDemandes),
                  ),
                  _ActionTile(
                    icon: Icons.fact_check_outlined,
                    color: const Color(0xFF6A1B9A),
                    title: 'Vérifier les dossiers assurance',
                    subtitle: 'Valider les contrats soumis et les documents joints',
                    onTap: () => context.go(AppRoutes.adminContrats),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 26),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                  Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
