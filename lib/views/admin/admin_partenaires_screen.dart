import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/partenaire_model.dart';
import '../../viewmodels/partenaire_viewmodel.dart';

class AdminPartenairesScreen extends ConsumerStatefulWidget {
  const AdminPartenairesScreen({super.key});
  @override
  ConsumerState<AdminPartenairesScreen> createState() => _AdminPartenairesScreenState();
}

class _AdminPartenairesScreenState extends ConsumerState<AdminPartenairesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(partenaireViewModelProvider.notifier).load();
    });
  }

  void _showForm({PartenaireModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _PartenaireForm(existing: existing),
    );
  }

  void _confirmDelete(PartenaireModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce partenaire ?'),
        content: Text('« ${p.nom} » sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(partenaireViewModelProvider.notifier).delete(p.id);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partenaireViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Partenaires (${state.partenaires.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.partenaires.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.handshake_outlined, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text('Aucun partenaire enregistré',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter le premier partenaire'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: state.partenaires.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = state.partenaires[i];
                    return _PartenaireCard(
                      partenaire: p,
                      onEdit: () => _showForm(existing: p),
                      onDelete: () => _confirmDelete(p),
                      onToggle: (v) => ref
                          .read(partenaireViewModelProvider.notifier)
                          .toggleActif(p.id, v),
                    );
                  },
                ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _PartenaireCard extends StatelessWidget {
  final PartenaireModel partenaire;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool) onToggle;

  const _PartenaireCard({
    required this.partenaire,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(partenaire.nom,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(partenaire.type,
                          style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Switch(
                  value: partenaire.actif,
                  onChanged: onToggle,
                  activeColor: AppColors.success,
                ),
              ],
            ),
            if (!partenaire.actif)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Inactif', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 8),
            Text(partenaire.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${fmt.format(partenaire.montantMin)} – ${fmt.format(partenaire.montantMax)} FCFA',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    partenaire.pays.join(', '),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formulaire ajout / modification ──────────────────────────────────────────

class _PartenaireForm extends ConsumerStatefulWidget {
  final PartenaireModel? existing;
  const _PartenaireForm({this.existing});

  @override
  ConsumerState<_PartenaireForm> createState() => _PartenaireFormState();
}

class _PartenaireFormState extends ConsumerState<_PartenaireForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _type;
  late final TextEditingController _description;
  late final TextEditingController _contact;
  late final TextEditingController _paysCtrl;
  late final TextEditingController _montantMin;
  late final TextEditingController _montantMax;
  bool _actif = true;
  bool _saving = false;

  static const _types = [
    'Banque développement',
    'Microfinance',
    'Fonds climatique',
    'ONG',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nom         = TextEditingController(text: e?.nom ?? '');
    _type        = TextEditingController(text: e?.type ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _contact     = TextEditingController(text: e?.contact ?? '');
    _paysCtrl    = TextEditingController(text: e?.pays.join(', ') ?? '');
    _montantMin  = TextEditingController(text: e != null ? e.montantMin.toStringAsFixed(0) : '');
    _montantMax  = TextEditingController(text: e != null ? e.montantMax.toStringAsFixed(0) : '');
    _actif       = e?.actif ?? true;
  }

  @override
  void dispose() {
    for (final c in [_nom, _type, _description, _contact, _paysCtrl, _montantMin, _montantMax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final pays = _paysCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (widget.existing == null) {
      await ref.read(partenaireViewModelProvider.notifier).create(
            PartenaireModel(
              id: '',
              nom: _nom.text.trim(),
              type: _type.text.trim(),
              description: _description.text.trim(),
              contact: _contact.text.trim(),
              pays: pays,
              montantMin: double.tryParse(_montantMin.text) ?? 0,
              montantMax: double.tryParse(_montantMax.text) ?? 0,
              actif: _actif,
            ),
          );
    } else {
      await ref.read(partenaireViewModelProvider.notifier).update(
            widget.existing!.copyWith(
              nom: _nom.text.trim(),
              type: _type.text.trim(),
              description: _description.text.trim(),
              contact: _contact.text.trim(),
              pays: pays,
              montantMin: double.tryParse(_montantMin.text) ?? 0,
              montantMax: double.tryParse(_montantMax.text) ?? 0,
              actif: _actif,
            ),
          );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Modifier le partenaire' : 'Nouveau partenaire',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _field(controller: _nom, label: 'Nom du partenaire', required: true),
              const SizedBox(height: 12),

              // Type — dropdown
              DropdownButtonFormField<String>(
                value: _types.contains(_type.text) ? _type.text : null,
                decoration: _inputDeco('Type'),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => _type.text = v ?? '',
                validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),

              _field(controller: _description, label: 'Description', minLines: 2, maxLines: 4, required: true),
              const SizedBox(height: 12),
              _field(controller: _contact, label: 'Contact (email)', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field(
                controller: _paysCtrl,
                label: 'Pays éligibles (séparés par des virgules)',
                hint: 'ex: Sénégal, Bénin, Côte d\'Ivoire',
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _field(controller: _montantMin, label: 'Montant min (FCFA)', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(controller: _montantMax, label: 'Montant max (FCFA)', keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Text('Actif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Switch(value: _actif, onChanged: (v) => setState(() => _actif = v), activeColor: AppColors.success),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Enregistrer les modifications' : 'Créer le partenaire'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int? minLines,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines ?? 1,
      decoration: _inputDeco(label, hint: hint),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
          : null,
    );
  }

  InputDecoration _inputDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
