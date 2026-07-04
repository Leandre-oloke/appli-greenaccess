import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/course_model.dart';
import '../../routes.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminCourseFormScreen extends ConsumerStatefulWidget {
  final String? courseId; // null = création
  const AdminCourseFormScreen({super.key, this.courseId});

  @override
  ConsumerState<AdminCourseFormScreen> createState() => _AdminCourseFormScreenState();
}

class _AdminCourseFormScreenState extends ConsumerState<AdminCourseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titreCtrl       = TextEditingController();
  final _themeCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _dureeCtrl       = TextEditingController(text: '20');
  final _xpCtrl          = TextEditingController(text: '50');
  final _urlVideoCtrl    = TextEditingController();
  final _urlPdfCtrl      = TextEditingController();
  final _objectifCtrl    = TextEditingController();

  CourseType _type = CourseType.video;
  int _niveau = 0;
  bool _actif = true;
  List<String> _objectifs = [];

  bool get _isNew => widget.courseId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  void _loadExisting() {
    final courses = ref.read(adminViewModelProvider).courses;
    final course = courses.where((c) => c.id == widget.courseId).firstOrNull;
    if (course == null) return;
    _titreCtrl.text    = course.titre;
    _themeCtrl.text    = course.theme;
    _descCtrl.text     = course.description;
    _dureeCtrl.text    = course.dureeMin.toString();
    _xpCtrl.text       = course.pointsXp.toString();
    _urlVideoCtrl.text = course.urlVideo ?? '';
    _urlPdfCtrl.text   = course.urlPdf ?? '';
    setState(() {
      _type      = course.type;
      _niveau    = course.niveauRequis;
      _actif     = course.actif;
      _objectifs = List.from(course.objectifs);
    });
  }

  void _addObjectif() {
    final txt = _objectifCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() => _objectifs.add(txt));
    _objectifCtrl.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final course = CourseModel(
      id: widget.courseId ?? '',
      titre:       _titreCtrl.text.trim(),
      theme:       _themeCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      objectifs:   _objectifs,
      type:        _type,
      urlVideo:    _urlVideoCtrl.text.trim().isEmpty ? null : _urlVideoCtrl.text.trim(),
      urlPdf:      _urlPdfCtrl.text.trim().isEmpty ? null : _urlPdfCtrl.text.trim(),
      dureeMin:    int.tryParse(_dureeCtrl.text) ?? 20,
      pointsXp:    int.tryParse(_xpCtrl.text) ?? 50,
      niveauRequis: _niveau,
      nbQuiz: 0,
      actif: _actif,
    );
    await ref.read(adminViewModelProvider.notifier).saveCourse(course, isNew: _isNew);
    if (mounted) context.go(AppRoutes.adminFormations);
  }

  @override
  void dispose() {
    for (final c in [_titreCtrl, _themeCtrl, _descCtrl, _dureeCtrl, _xpCtrl, _urlVideoCtrl, _urlPdfCtrl, _objectifCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(adminViewModelProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nouveau cours' : 'Modifier le cours'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go(AppRoutes.adminFormations)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Infos de base ────────────────────────────────────────────────
            _section('Informations générales'),
            _field(_titreCtrl, 'Titre du cours *', validator: _required),
            _field(_themeCtrl, 'Thème (ex: Finance climatique) *', validator: _required),
            _field(_descCtrl, 'Description', maxLines: 3),

            // ── Type et niveau ───────────────────────────────────────────────
            _section('Type de contenu'),
            DropdownButtonFormField<CourseType>(
              value: _type,
              decoration: _decor('Type *'),
              items: CourseType.values.map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
              )).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _niveau,
              decoration: _decor('Niveau *'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Débutant')),
                DropdownMenuItem(value: 1, child: Text('Intermédiaire')),
                DropdownMenuItem(value: 2, child: Text('Avancé')),
              ],
              onChanged: (v) => setState(() => _niveau = v!),
            ),
            const SizedBox(height: 12),

            // ── Durée et XP ──────────────────────────────────────────────────
            Row(children: [
              Expanded(child: _field(_dureeCtrl, 'Durée (min) *', keyboardType: TextInputType.number, validator: _required)),
              const SizedBox(width: 12),
              Expanded(child: _field(_xpCtrl, 'Points XP *', keyboardType: TextInputType.number, validator: _required)),
            ]),

            // ── URLs ─────────────────────────────────────────────────────────
            _section('Contenu'),
            _field(_urlVideoCtrl, 'URL vidéo (YouTube, Vimeo…)'),
            _field(_urlPdfCtrl, 'URL PDF'),

            // ── Objectifs ────────────────────────────────────────────────────
            _section('Objectifs pédagogiques'),
            Row(children: [
              Expanded(child: TextFormField(controller: _objectifCtrl, decoration: _decor('Ajouter un objectif'))),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary), onPressed: _addObjectif),
            ]),
            const SizedBox(height: 8),
            ..._objectifs.asMap().entries.map((e) => Chip(
              label: Text(e.value),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _objectifs.removeAt(e.key)),
            )),
            const SizedBox(height: 12),

            // ── Actif ────────────────────────────────────────────────────────
            SwitchListTile(
              title: const Text('Cours actif (visible aux apprenants)'),
              value: _actif,
              onChanged: (v) => setState(() => _actif = v),
              activeColor: AppColors.primary,
            ),
            const SizedBox(height: 24),

            // ── Bouton ───────────────────────────────────────────────────────
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isNew ? 'Créer le cours' : 'Enregistrer les modifications'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );

  Widget _field(TextEditingController ctrl, String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _decor(label),
    ),
  );

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null;
}
