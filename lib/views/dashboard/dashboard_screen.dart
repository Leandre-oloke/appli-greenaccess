import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../models/score_climat_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';
import '../../viewmodels/formation_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../viewmodels/assurance_viewmodel.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      if (uid.isEmpty) return;
      // Chargement initial unique — gardé en vie par StatefulShellRoute.
      ref.read(scoringViewModelProvider(uid).notifier).loadLatestScore();
      ref.read(formationViewModelProvider(uid).notifier).loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    // select évite les rebuilds sur isLoading/error de l'auth
    final user = ref.watch(authViewModelProvider.select((s) => s.user));
    if (user == null) return const SizedBox.shrink();

    final scoring  = ref.watch(scoringViewModelProvider(user.id));
    final formation = ref.watch(formationViewModelProvider(user.id));
    final unread = ref.watch(
      notificationViewModelProvider(user.id).select((s) => s.unreadCount),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, ${user.nom.split(' ').first}'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.go(AppRoutes.notifications),
              ),
              if (unread > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go(AppRoutes.profil),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(scoringViewModelProvider(user.id));
          ref.invalidate(formationViewModelProvider(user.id));
          await Future.wait([
            ref.read(scoringViewModelProvider(user.id).notifier).loadLatestScore(),
            ref.read(formationViewModelProvider(user.id).notifier).loadCourses(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ScoreCard(score: scoring.currentScore),
            const SizedBox(height: 16),
            const _QuickActions(),
            const SizedBox(height: 16),
            _FormationCard(progressPercent: formation.progressPercent, xp: formation.totalXp),
            const SizedBox(height: 16),
            const _FinancementCard(),
            const SizedBox(height: 16),
            const _AssuranceCard(),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final ScoreClimatModel? score;
  const _ScoreCard({this.score});

  Color get _scoreColor {
    if (score == null) return AppColors.textSecondary;
    return switch (score!.niveau) {
      NiveauScore.insuffisant   => AppColors.scoreInsuffisant,
      NiveauScore.intermediaire => AppColors.scoreIntermediaire,
      NiveauScore.bon           => AppColors.scoreBon,
      NiveauScore.excellent     => AppColors.scoreExcellent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scoreVal = score?.scoreTotal ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 50,
              lineWidth: 8,
              percent: scoreVal / 100,
              center: Text(
                scoreVal.toStringAsFixed(0),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _scoreColor),
              ),
              progressColor: _scoreColor,
              backgroundColor: AppColors.divider,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Score Climat ESG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    score == null ? 'Non calculé' : score!.niveau.name.toUpperCase(),
                    style: TextStyle(color: _scoreColor, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.scoringForm),
                    icon: const Icon(Icons.trending_up, size: 16),
                    label: const Text('Améliorer mon score'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.school_outlined,    'Formation',   AppRoutes.courseList,  AppColors.primary),
      (Icons.attach_money,       'Financement', AppRoutes.financement, AppColors.secondary),
      (Icons.assessment_outlined,'Mon Score',   AppRoutes.scoringForm, AppColors.scoreBon),
      (Icons.umbrella_outlined,  'Assurance',   AppRoutes.assurance,   AppColors.info),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions
          .map((a) => _ActionChip(icon: a.$1, label: a.$2, route: a.$3, color: a.$4))
          .toList(),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _ActionChip({required this.icon, required this.label, required this.route, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            radius: 28,
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _FormationCard extends StatelessWidget {
  final int progressPercent;
  final int xp;
  const _FormationCard({required this.progressPercent, required this.xp});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.school, color: AppColors.primary, size: 32),
        title: const Text('Formation', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progressPercent / 100, color: AppColors.primary),
            const SizedBox(height: 4),
            Text('$progressPercent% · $xp XP cumulés'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.courseList),
      ),
    );
  }
}

class _FinancementCard extends StatelessWidget {
  const _FinancementCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_balance_outlined, color: AppColors.secondary, size: 32),
        title: const Text('Financement', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Accéder aux demandes de micro-financement vert'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.financement),
      ),
    );
  }
}

class _AssuranceCard extends ConsumerWidget {
  const _AssuranceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authViewModelProvider.select((s) => s.user?.id ?? ''));
    final contrats = ref.watch(assuranceViewModelProvider(uid).select((s) => s.contrats));

    final expiringSoon = contrats.where((c) {
      if (c.statut.name != 'actif') return false;
      final expiry = DateTime(c.dateDebut.year, c.dateDebut.month + 12, c.dateDebut.day);
      final days = expiry.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 30;
    }).toList();

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.umbrella_outlined, color: AppColors.primary, size: 32),
            title: const Text('Assurance Climatique', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              contrats.isEmpty
                  ? 'Gérer vos contrats et zones à risque'
                  : '${contrats.length} contrat${contrats.length > 1 ? 's' : ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.assurance),
          ),
          if (expiringSoon.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${expiringSoon.length} contrat${expiringSoon.length > 1 ? 's expirent' : ' expire'} bientôt — pensez à renouveler',
                      style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
