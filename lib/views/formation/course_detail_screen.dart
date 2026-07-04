import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/lecon_model.dart';
import '../../routes.dart';
import '../../models/course_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/formation_viewmodel.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      final vm = ref.read(formationViewModelProvider(uid).notifier);
      vm.loadCourses();
      vm.loadLecons(widget.courseId);
    });
  }

  CourseModel? _findCourse(FormationState state) {
    try {
      return state.courses.firstWhere((c) => c.id == widget.courseId);
    } catch (_) {
      return null;
    }
  }

  CourseProgress? _findProgress(FormationState state) {
    try {
      return state.progress.firstWhere((p) => p.courseId == widget.courseId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showUrlError();
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) _showUrlError();
  }

  void _showUrlError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible d\'ouvrir le lien. Vérifiez votre connexion.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(formationViewModelProvider(uid));
    final course = _findCourse(state);
    final progress = _findProgress(state);
    final isComplete = progress?.statut == 'TERMINE';
    final lecons = state.leconsByCourse[widget.courseId] ?? [];

    if (state.isLoading || course == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _CourseAppBar(course: course, isComplete: isComplete),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (course.type == CourseType.video && course.urlVideo != null)
                    _VideoLinkCard(url: course.urlVideo!, onTap: () => _openUrl(course.urlVideo!)),
                  if (course.type == CourseType.pdf && course.urlPdf != null)
                    _VideoLinkCard(
                      url: course.urlPdf!,
                      onTap: () => _openUrl(course.urlPdf!),
                      isPdf: true,
                    ),
                  const SizedBox(height: 16),
                  _MetaRow(course: course),
                  const SizedBox(height: 20),
                  Text(
                    'À propos de ce cours',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.description,
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  _ObjectifsSection(objectifs: course.objectifs),
                  if (lecons.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _LeconsSection(lecons: lecons, onOpenUrl: _openUrl),
                  ],
                  const SizedBox(height: 24),
                  if (isComplete)
                    _CompletedBanner(progress: progress!)
                  else
                    ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.quizPath(widget.courseId)),
                      icon: const Icon(Icons.quiz_outlined),
                      label: const Text('Passer le quiz (+XP)'),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseAppBar extends StatelessWidget {
  final CourseModel course;
  final bool isComplete;
  const _CourseAppBar({required this.course, required this.isComplete});

  Color _typeColor() => switch (course.type) {
        CourseType.video => AppColors.info,
        CourseType.pdf => AppColors.error,
        CourseType.quiz => AppColors.secondary,
        CourseType.infographie => AppColors.scoreBon,
      };

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          course.titre,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_typeColor(), AppColors.primary],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconFor(course.type), size: 64, color: Colors.white70),
                if (isComplete)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Terminé', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(CourseType t) => switch (t) {
        CourseType.video => Icons.play_circle_outline,
        CourseType.pdf => Icons.picture_as_pdf_outlined,
        CourseType.quiz => Icons.quiz_outlined,
        CourseType.infographie => Icons.image_outlined,
      };
}

class _VideoLinkCard extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  final bool isPdf;
  const _VideoLinkCard({required this.url, required this.onTap, this.isPdf = false});

  @override
  Widget build(BuildContext context) {
    final color = isPdf ? AppColors.error : AppColors.info;
    final icon = isPdf ? Icons.picture_as_pdf_outlined : Icons.play_circle_outline;
    final label = isPdf ? 'Ouvrir le PDF' : 'Regarder la vidéo';
    final sublabel = isPdf ? 'S\'ouvre dans votre lecteur PDF' : 'S\'ouvre dans votre navigateur';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, color: Colors.white.withValues(alpha: 0.8), size: 20),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final CourseModel course;
  const _MetaRow({required this.course});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(icon: Icons.timer_outlined, label: '${course.dureeMin} min'),
        _Chip(icon: Icons.star_outline, label: '${course.pointsXp} XP'),
        _Chip(icon: Icons.category_outlined, label: course.theme),
        _Chip(icon: Icons.bar_chart, label: course.niveauDifficulte),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ObjectifsSection extends StatelessWidget {
  final List<String> objectifs;
  const _ObjectifsSection({required this.objectifs});

  @override
  Widget build(BuildContext context) {
    if (objectifs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Objectifs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...objectifs.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(o, style: const TextStyle(color: AppColors.textSecondary, height: 1.4))),
                ],
              ),
            )),
      ],
    );
  }
}

class _LeconsSection extends StatelessWidget {
  final List<LeconModel> lecons;
  final Future<void> Function(String url) onOpenUrl;
  const _LeconsSection({required this.lecons, required this.onOpenUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Programme du cours',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${lecons.length} leçon${lecons.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...lecons.map((l) => _LeconTile(lecon: l, onOpenUrl: onOpenUrl)),
      ],
    );
  }
}

class _LeconTile extends StatelessWidget {
  final LeconModel lecon;
  final Future<void> Function(String url) onOpenUrl;
  const _LeconTile({required this.lecon, required this.onOpenUrl});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    '${lecon.ordre}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lecon.titre,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(lecon.contenu,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.6)),
            if (lecon.urlVideo != null) ...[
              const SizedBox(height: 20),
              _UrlButton(
                label: 'Regarder la vidéo',
                icon: Icons.play_circle_outline,
                color: AppColors.info,
                onTap: () => onOpenUrl(lecon.urlVideo!),
              ),
            ],
            if (lecon.urlPdf != null) ...[
              const SizedBox(height: 10),
              _UrlButton(
                label: 'Ouvrir le PDF',
                icon: Icons.picture_as_pdf_outlined,
                color: AppColors.error,
                onTap: () => onOpenUrl(lecon.urlPdf!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            '${lecon.ordre}',
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
        title: Text(lecon.titre,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          lecon.contenu,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lecon.urlVideo != null)
              const Icon(Icons.play_circle_outline,
                  size: 16, color: AppColors.info),
            if (lecon.urlPdf != null)
              const Icon(Icons.picture_as_pdf_outlined,
                  size: 16, color: AppColors.error),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
        onTap: () => _showDetail(context),
      ),
    );
  }
}

class _UrlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _UrlButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  final CourseProgress progress;
  const _CompletedBanner({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: AppColors.success, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cours terminé !', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                Text('Score quiz: ${progress.scoreQuiz}%  ·  +${progress.pointsXpGagnes} XP',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
