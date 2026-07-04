import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/course_model.dart';
import '../../routes.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminFormationsScreen extends ConsumerStatefulWidget {
  const AdminFormationsScreen({super.key});
  @override
  ConsumerState<AdminFormationsScreen> createState() => _AdminFormationsScreenState();
}

class _AdminFormationsScreenState extends ConsumerState<AdminFormationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminViewModelProvider.notifier).loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);

    ref.listen(adminViewModelProvider, (_, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: AppColors.success),
        );
        ref.read(adminViewModelProvider.notifier).clearMessages();
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
        ref.read(adminViewModelProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des formations'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminViewModelProvider.notifier).loadCourses(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.adminCourseNew),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau cours'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.courses.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_outlined, size: 64, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Text('Aucun cours. Créez-en un !',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: state.courses.length,
                  itemBuilder: (context, i) {
                    final course = state.courses[i];
                    return _CourseAdminCard(
                      course: course,
                      onEdit: () => context.go(AppRoutes.adminCourseEdit(course.id)),
                      onLecons: () => context.go(
                        AppRoutes.adminCourseLecons(course.id),
                        extra: {'courseTitre': course.titre},
                      ),
                      onToggle: (val) => ref
                          .read(adminViewModelProvider.notifier)
                          .toggleCourse(course.id, val),
                      onDelete: () => _confirmDelete(context, course),
                    );
                  },
                ),
    );
  }

  void _confirmDelete(BuildContext context, CourseModel course) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce cours ?'),
        content: Text('« ${course.titre} » sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminViewModelProvider.notifier).deleteCourse(course.id);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _CourseAdminCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onEdit;
  final VoidCallback onLecons;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  const _CourseAdminCard({required this.course, required this.onEdit, required this.onLecons, required this.onToggle, required this.onDelete});

  static const _typeIcons = {
    CourseType.video: Icons.play_circle_outline,
    CourseType.pdf: Icons.picture_as_pdf_outlined,
    CourseType.quiz: Icons.quiz_outlined,
    CourseType.infographie: Icons.image_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: course.actif
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.15),
          child: Icon(_typeIcons[course.type], color: course.actif ? AppColors.primary : Colors.grey),
        ),
        title: Text(course.titre,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: course.actif ? null : AppColors.textSecondary,
            )),
        subtitle: Text('${course.theme} · ${course.dureeMin} min · +${course.pointsXp} XP',
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: course.actif,
              onChanged: onToggle,
              activeColor: AppColors.primary,
            ),
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: onLecons,
              color: AppColors.info,
              tooltip: 'Gérer les leçons',
            ),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit, color: AppColors.secondary),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete, color: AppColors.error),
          ],
        ),
      ),
    );
  }
}
