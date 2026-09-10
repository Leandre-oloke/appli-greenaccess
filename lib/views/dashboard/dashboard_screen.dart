import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/theme_mode_provider.dart';
import '../../models/score_climat_model.dart';
import '../../routes.dart';
import '../../ui/ui.dart';
import '../../viewmodels/assurance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/formation_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

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
      ref.read(scoringViewModelProvider(uid).notifier).loadLatestScore();
      ref.read(formationViewModelProvider(uid).notifier).loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider.select((s) => s.user));
    if (user == null) return const SizedBox.shrink();

    final scoring = ref.watch(scoringViewModelProvider(user.id));
    final formation = ref.watch(formationViewModelProvider(user.id));
    final unread = ref.watch(
      notificationViewModelProvider(user.id).select((s) => s.unreadCount),
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(scoringViewModelProvider(user.id));
          ref.invalidate(formationViewModelProvider(user.id));
          await Future.wait([
            ref
                .read(scoringViewModelProvider(user.id).notifier)
                .loadLatestScore(),
            ref
                .read(formationViewModelProvider(user.id).notifier)
                .loadCourses(),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(name: user.nom, unread: unread),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(GaSpacing.screenH, GaSpacing.xl,
                  GaSpacing.screenH, GaSpacing.xxl),
              sliver: SliverList.list(
                children: gaStagger([
                  _ScoreHero(score: scoring.currentScore),
                  const SizedBox(height: GaSpacing.xl),
                  const GaSectionHeader('Accès rapide'),
                  const _QuickActions(),
                  const SizedBox(height: GaSpacing.xl),
                  _FormationCard(
                      progressPercent: formation.progressPercent,
                      xp: formation.totalXp),
                  const SizedBox(height: GaSpacing.md),
                  const _FinancementCard(),
                  const SizedBox(height: GaSpacing.md),
                  const _AssuranceCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.name, required this.unread});
  final String name;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat("EEEE d MMMM", 'fr').format(DateTime.now());
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GaGradientHeader(
      title: 'Bonjour, ${name.split(' ').first}',
      subtitle: '${date[0].toUpperCase()}${date.substring(1)}',
      actions: [
        IconButton(
          tooltip: 'Thème',
          onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
          icon: Icon(
            dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: Colors.white,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.go(AppRoutes.notifications),
              icon:
                  const Icon(Icons.notifications_none_rounded, color: Colors.white),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          onPressed: () => context.go(AppRoutes.profil),
          icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
        ),
      ],
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({this.score});
  final ScoreClimatModel? score;

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return GaCard(
        child: Column(
          children: [
            const GaEmptyState(
              compact: true,
              icon: Icons.speed_rounded,
              title: 'Votre Score Climat',
              message: 'Répondez à 5 questions pour connaître votre score ESG.',
            ),
            const SizedBox(height: GaSpacing.md),
            GaPrimaryButton(
              label: 'Calculer mon score',
              icon: Icons.auto_awesome_rounded,
              onPressed: () => context.go(AppRoutes.scoringForm),
            ),
          ],
        ),
      );
    }
    final s = score!;
    return GaCard(
      onTap: () => context.push(AppRoutes.scoreResult),
      child: Row(
        children: [
          Hero(
            tag: 'score-gauge',
            child: Material(
              color: Colors.transparent,
              child: GaMiniGauge(score: s.scoreTotal, level: s.niveau, size: 96),
            ),
          ),
          const SizedBox(width: GaSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score Climat ESG',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                GaBadgePill(
                  label: GaScoreScale.labelFor(s.niveau),
                  color: GaScoreScale.colorFor(
                      s.niveau, Theme.of(context).brightness),
                ),
                const SizedBox(height: GaSpacing.sm),
                GaSecondaryButton.tonal(
                  label: 'Améliorer',
                  icon: Icons.trending_up_rounded,
                  onPressed: () => context.go(AppRoutes.scoringForm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actions = <(IconData, String, String, Color)>[
      (Icons.school_rounded, 'Formation', AppRoutes.courseList, cs.primary),
      (Icons.savings_rounded, 'Financement', AppRoutes.financement, cs.tertiary),
      (Icons.speed_rounded, 'Mon Score', AppRoutes.scoringForm,
          context.gaColors.success),
      (Icons.shield_moon_rounded, 'Assurance', AppRoutes.assurance,
          context.gaColors.info),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: GaSpacing.sm),
          Expanded(
            child: GaStatTile(
              icon: actions[i].$1,
              value: '',
              label: actions[i].$2,
              color: actions[i].$4,
              onTap: () => context.go(actions[i].$3),
            ),
          ),
        ],
      ],
    );
  }
}

class _FormationCard extends StatelessWidget {
  const _FormationCard({required this.progressPercent, required this.xp});
  final int progressPercent;
  final int xp;

  @override
  Widget build(BuildContext context) {
    return GaCard(
      onTap: () => context.go(AppRoutes.courseList),
      child: Row(
        children: [
          _Leading(icon: Icons.school_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: GaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Formation',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: GaSpacing.sm),
                GaMeterRow(
                  label: '$xp XP cumulés',
                  value: progressPercent.toDouble(),
                  trailing: '$progressPercent %',
                ),
              ],
            ),
          ),
          const SizedBox(width: GaSpacing.sm),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _FinancementCard extends StatelessWidget {
  const _FinancementCard();

  @override
  Widget build(BuildContext context) {
    return GaCard(
      onTap: () => context.go(AppRoutes.financement),
      child: Row(
        children: [
          _Leading(
              icon: Icons.account_balance_rounded,
              color: Theme.of(context).colorScheme.tertiary),
          const SizedBox(width: GaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Financement',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('Micro-crédit vert et suivi de vos demandes',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _AssuranceCard extends ConsumerWidget {
  const _AssuranceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid =
        ref.watch(authViewModelProvider.select((s) => s.user?.id ?? ''));
    final contrats =
        ref.watch(assuranceViewModelProvider(uid).select((s) => s.contrats));

    final expiringSoon = contrats.where((c) {
      if (c.statut.name != 'actif') return false;
      final expiry =
          DateTime(c.dateDebut.year, c.dateDebut.month + 12, c.dateDebut.day);
      final days = expiry.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 30;
    }).toList();

    return GaCard(
      onTap: () => context.go(AppRoutes.assurance),
      child: Column(
        children: [
          Row(
            children: [
              _Leading(
                  icon: Icons.shield_moon_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: GaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assurance climatique',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      contrats.isEmpty
                          ? 'Gérer vos contrats et zones à risque'
                          : '${contrats.length} contrat${contrats.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          if (expiringSoon.isNotEmpty) ...[
            const SizedBox(height: GaSpacing.md),
            GaInfoBanner(
              kind: GaBannerKind.warning,
              icon: Icons.timer_outlined,
              message:
                  '${expiringSoon.length} contrat${expiringSoon.length > 1 ? 's expirent' : ' expire'} bientôt — pensez à renouveler.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GaSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: GaRadii.brSm,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
