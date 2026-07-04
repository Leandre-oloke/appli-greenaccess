import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/badge_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/formation_viewmodel.dart';

class BadgesScreen extends ConsumerStatefulWidget {
  const BadgesScreen({super.key});

  @override
  ConsumerState<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends ConsumerState<BadgesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      ref.read(formationViewModelProvider(uid).notifier).loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(formationViewModelProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Mes Badges')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.badges.isEmpty
              ? _EmptyBadges()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _StatsHeader(badges: state.badges, xp: state.totalXp)),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _BadgeCard(badge: state.badges[i]),
                          childCount: state.badges.length,
                        ),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final List<BadgeModel> badges;
  final int xp;
  const _StatsHeader({required this.badges, required this.xp});

  @override
  Widget build(BuildContext context) {
    final obtained = badges.where((b) => b.isObtenu).length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(label: 'Badges obtenus', value: '$obtained', icon: Icons.verified),
          Container(width: 1, height: 40, color: Colors.white30),
          _Stat(label: 'Total badges', value: '${badges.length}', icon: Icons.emoji_events_outlined),
          Container(width: 1, height: 40, color: Colors.white30),
          _Stat(label: 'Points XP', value: '$xp', icon: Icons.star_outline),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  const _BadgeCard({required this.badge});

  Color _typeColor() => switch (badge.type) {
        'formation' => AppColors.primary,
        'financement' => AppColors.secondary,
        'assurance' => const Color(0xFF6A1B9A),
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final obtained = badge.isObtenu;
    final color = _typeColor();

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: obtained ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                      border: Border.all(
                        color: obtained ? color : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: obtained && badge.imageUrl.isNotEmpty
                        ? ClipOval(child: Image.network(badge.imageUrl, fit: BoxFit.cover))
                        : Icon(
                            Icons.emoji_events,
                            size: 36,
                            color: obtained ? color : Colors.grey.shade400,
                          ),
                  ),
                  if (obtained)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                badge.nom,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: obtained ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge.type,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              if (obtained && badge.dateObtention != null) ...[
                const SizedBox(height: 6),
                Text(
                  _formatDate(badge.dateObtention!),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(badge.nom, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(badge.description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            if (badge.isObtenu && badge.openbadgeUrl != null)
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.open_in_new),
                label: const Text('Voir sur OpenBadge Factory'),
              ),
            if (!badge.isObtenu)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Terminez les cours associés pour débloquer ce badge.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 80, color: AppColors.divider),
          const SizedBox(height: 16),
          const Text('Aucun badge encore', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('Complétez des cours pour gagner vos premiers badges !',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
