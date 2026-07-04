import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/lecon_model.dart';
import '../../routes.dart';
import '../../viewmodels/admin_viewmodel.dart';

// ── Écran liste des leçons (admin) ────────────────────────────────────────────

class AdminLeconsScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String courseTitre;
  const AdminLeconsScreen({
    super.key,
    required this.courseId,
    required this.courseTitre,
  });

  @override
  ConsumerState<AdminLeconsScreen> createState() => _AdminLeconsScreenState();
}

class _AdminLeconsScreenState extends ConsumerState<AdminLeconsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminViewModelProvider.notifier).loadLecons(widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);

    ref.listen(adminViewModelProvider, (_, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(next.successMessage!),
              backgroundColor: AppColors.success),
        );
        ref.read(adminViewModelProvider.notifier).clearMessages();
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(next.error!),
              backgroundColor: AppColors.error),
        );
        ref.read(adminViewModelProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leçons du cours', style: TextStyle(fontSize: 16)),
            Text(widget.courseTitre,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.adminFormations),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          AppRoutes.adminLeconNew(widget.courseId),
          extra: {'courseTitre': widget.courseTitre, 'nextOrdre': state.lecons.length + 1},
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle leçon'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.lecons.isEmpty
              ? _EmptyLecons(
                  onAdd: () => context.push(
                    AppRoutes.adminLeconNew(widget.courseId),
                    extra: {'courseTitre': widget.courseTitre, 'nextOrdre': 1},
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: state.lecons.length,
                  itemBuilder: (context, i) {
                    final lecon = state.lecons[i];
                    return _LeconAdminCard(
                      lecon: lecon,
                      onEdit: () => context.push(
                        AppRoutes.adminLeconEdit(widget.courseId, lecon.id),
                        extra: {'courseTitre': widget.courseTitre},
                      ),
                      onDelete: () => _confirmDelete(context, lecon),
                    );
                  },
                ),
    );
  }

  void _confirmDelete(BuildContext context, LeconModel lecon) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette leçon ?'),
        content: Text('« ${lecon.titre} » sera définitivement supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(adminViewModelProvider.notifier)
                  .deleteLecon(widget.courseId, lecon.id);
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _LeconAdminCard extends StatelessWidget {
  final LeconModel lecon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _LeconAdminCard(
      {required this.lecon, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                '${lecon.ordre}',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lecon.titre,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    lecon.contenu,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (lecon.urlVideo != null || lecon.urlPdf != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (lecon.urlVideo != null)
                            const Icon(Icons.play_circle_outline,
                                size: 14, color: AppColors.info),
                          if (lecon.urlPdf != null) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.picture_as_pdf_outlined,
                                size: 14, color: AppColors.error),
                          ],
                          const SizedBox(width: 4),
                          const Text('Lien joint',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              color: AppColors.secondary,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: AppColors.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLecons extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyLecons({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined,
              size: 72, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Aucune leçon pour ce cours',
              style:
                  TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez des leçons que les apprenants\ndevront suivre avant le quiz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une leçon'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ── Formulaire leçon (admin) ──────────────────────────────────────────────────

class AdminLeconFormScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String? leconId;
  final String courseTitre;
  final int nextOrdre;
  const AdminLeconFormScreen({
    super.key,
    required this.courseId,
    this.leconId,
    required this.courseTitre,
    this.nextOrdre = 1,
  });

  @override
  ConsumerState<AdminLeconFormScreen> createState() =>
      _AdminLeconFormScreenState();
}

class _AdminLeconFormScreenState extends ConsumerState<AdminLeconFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _contenuCtrl = TextEditingController();
  final _urlVideoCtrl = TextEditingController();
  final _urlPdfCtrl = TextEditingController();
  late int _ordre;

  bool get _isNew => widget.leconId == null;

  @override
  void initState() {
    super.initState();
    _ordre = widget.nextOrdre;
    if (!_isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  void _loadExisting() {
    final lecons = ref.read(adminViewModelProvider).lecons;
    final lecon = lecons.where((l) => l.id == widget.leconId).firstOrNull;
    if (lecon == null) return;
    _titreCtrl.text = lecon.titre;
    _contenuCtrl.text = lecon.contenu;
    _urlVideoCtrl.text = lecon.urlVideo ?? '';
    _urlPdfCtrl.text = lecon.urlPdf ?? '';
    setState(() => _ordre = lecon.ordre);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final lecon = LeconModel(
      id: widget.leconId ?? '',
      titre: _titreCtrl.text.trim(),
      contenu: _contenuCtrl.text.trim(),
      urlVideo: _urlVideoCtrl.text.trim().isEmpty
          ? null
          : _urlVideoCtrl.text.trim(),
      urlPdf:
          _urlPdfCtrl.text.trim().isEmpty ? null : _urlPdfCtrl.text.trim(),
      ordre: _ordre,
    );
    await ref
        .read(adminViewModelProvider.notifier)
        .saveLecon(widget.courseId, lecon, isNew: _isNew);
    if (mounted) {
      context.go(AppRoutes.adminCourseLecons(widget.courseId),
          extra: {'courseTitre': widget.courseTitre});
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titreCtrl,
      _contenuCtrl,
      _urlVideoCtrl,
      _urlPdfCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(adminViewModelProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nouvelle leçon' : 'Modifier la leçon'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            AppRoutes.adminCourseLecons(widget.courseId),
            extra: {'courseTitre': widget.courseTitre},
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Contenu de la leçon'),
            _field(_titreCtrl, 'Titre de la leçon *', validator: _required),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: _contenuCtrl,
                maxLines: 6,
                validator: _required,
                decoration: _decor('Contenu / Résumé *'),
              ),
            ),
            _section('Ressources (optionnel)'),
            _field(_urlVideoCtrl, 'URL vidéo (YouTube, Vimeo…)'),
            _field(_urlPdfCtrl, 'URL PDF'),
            _section('Ordre d\'affichage'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                initialValue: _ordre.toString(),
                keyboardType: TextInputType.number,
                decoration: _decor('Ordre *'),
                validator: _required,
                onChanged: (v) =>
                    setState(() => _ordre = int.tryParse(v) ?? _ordre),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isNew ? 'Créer la leçon' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          validator: validator,
          decoration: _decor(label),
        ),
      );

  InputDecoration _decor(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ requis' : null;
}
