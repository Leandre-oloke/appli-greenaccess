import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/course_model.dart';
import '../../ui/ui.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/formation_viewmodel.dart';

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedTheme = 'Tous';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authViewModelProvider).user?.id ?? '';
      ref.read(formationViewModelProvider(userId).notifier).loadCourses();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(formationViewModelProvider(userId));

    final themes = <String>['Tous', ...{for (final c in state.courses) c.theme}]..sort();
    final filtered = state.courses.where((c) {
      final matchesTheme = _selectedTheme == 'Tous' || c.theme == _selectedTheme;
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          c.titre.toLowerCase().contains(q) ||
          c.theme.toLowerCase().contains(q);
      return matchesTheme && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formation'),
        actions: [
          IconButton(
            tooltip: 'Mes badges',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/formation/badges'),
          ),
        ],
      ),
      body: state.isLoading
          ? const SingleChildScrollView(
              padding: EdgeInsets.all(GaSpacing.lg),
              child: GaSkeletonList(itemCount: 6, itemHeight: 92),
            )
          : state.error != null
              ? Padding(
                  padding: const EdgeInsets.all(GaSpacing.lg),
                  child: GaErrorView(
                    error: state.error!,
                    onRetry: () => ref
                        .read(formationViewModelProvider(userId).notifier)
                        .loadCourses(),
                  ),
                )
              : Column(
                  children: [
                    _ProgressHeader(
                      percent: state.progressPercent,
                      xp: state.totalXp,
                      badges: state.badges.length,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          GaSpacing.lg, GaSpacing.md, GaSpacing.lg, 0),
                      child: GaFilterBar(
                        controller: _searchCtrl,
                        hint: 'Rechercher un cours…',
                        onChanged: (v) => setState(() => _query = v),
                        filters: themes,
                        selectedFilter: _selectedTheme,
                        onFilterSelected: (v) =>
                            setState(() => _selectedTheme = v),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const GaEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'Aucun cours trouvé',
                              message:
                                  'Essayez un autre thème ou une autre recherche.',
                              compact: true,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(GaSpacing.lg),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final course = filtered[index];
                                final progress = state.progress
                                    .where((p) => p.courseId == course.id)
                                    .firstOrNull;
                                return _CourseCard(
                                  course: course,
                                  progress: progress,
                                  onTap: () =>
                                      context.push('/formation/${course.id}'),
                                ).gaFadeSlideUp(order: index.clamp(0, 10));
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int percent;
  final int xp;
  final int badges;
  const _ProgressHeader({required this.percent, required this.xp, required this.badges});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'Complétion', value: '$percent%'),
          _Stat(label: 'XP cumulés', value: '$xp'),
          _Stat(label: 'Badges', value: '$badges'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final CourseProgress? progress;
  final VoidCallback onTap;
  const _CourseCard({required this.course, this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isComplete = progress?.isComplete ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: isComplete ? AppColors.success : AppColors.primary,
          child: Icon(
            isComplete ? Icons.check : _iconFor(course.type),
            color: Colors.white,
          ),
        ),
        title: Text(course.titre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course.theme, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${course.dureeMin} min', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.star_outline, size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text('+${course.pointsXp} XP', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: isComplete
            ? const Icon(Icons.verified, color: AppColors.success)
            : const Icon(Icons.play_circle_outline, color: AppColors.primary),
        onTap: onTap,
      ),
    );
  }

  IconData _iconFor(CourseType type) {
    return switch (type) {
      CourseType.video => Icons.play_circle_outline,
      CourseType.pdf => Icons.picture_as_pdf_outlined,
      CourseType.quiz => Icons.quiz_outlined,
      CourseType.infographie => Icons.image_outlined,
    };
  }
}
