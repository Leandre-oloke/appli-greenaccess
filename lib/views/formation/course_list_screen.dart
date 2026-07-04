import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/course_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/formation_viewmodel.dart';

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authViewModelProvider).user?.id ?? '';
      ref.read(formationViewModelProvider(userId).notifier).loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(formationViewModelProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/formation/badges'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _ProgressHeader(
                  percent: state.progressPercent,
                  xp: state.totalXp,
                  badges: state.badges.length,
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.courses.length,
                    itemBuilder: (context, index) {
                      final course = state.courses[index];
                      final progress = state.progress
                          .where((p) => p.courseId == course.id)
                          .firstOrNull;
                      return _CourseCard(
                        course: course,
                        progress: progress,
                        onTap: () => context.push('/formation/${course.id}'),
                      );
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
