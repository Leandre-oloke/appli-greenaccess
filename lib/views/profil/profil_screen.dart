import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/export_viewmodel.dart';

class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  bool _editing = false;
  bool _gpsLoading = false;
  String _pays = 'Sénégal';
  String _secteur = 'Agriculture';

  static const _paysList = [
    'Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso',
    'Guinée', 'Niger', 'Togo',
  ];
  static const _secteursList = [
    'Agriculture', 'Énergie renouvelable', 'Recyclage',
    'Transport propre', 'Forêt / Agroforesterie', 'Pêche durable', 'Autre',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromState();
  }

  void _syncFromState() {
    final user = ref.read(authViewModelProvider).user;
    if (user == null) return;
    _nomCtrl.text = user.nom;
    _telCtrl.text = user.telephone;
    _regionCtrl.text = user.region;
    _pays = _paysList.contains(user.pays) ? user.pays : _paysList.first;
    _secteur = _secteursList.contains(user.secteur) ? user.secteur : _secteursList.first;
  }

  Future<void> _detectLocation() async {
    setState(() => _gpsLoading = true);
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission granted = permission;
      if (permission == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }
      if (granted == LocationPermission.denied ||
          granted == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée.')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      // Conversion coordonnées → zone UEMOA approximative
      final zone = _coordsToZone(pos.latitude, pos.longitude);
      setState(() => _regionCtrl.text = zone);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur GPS : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  /// Mappe des coordonnées GPS vers une zone géographique UEMOA approximative.
  String _coordsToZone(double lat, double lng) {
    if (lat >= 12.0 && lat <= 14.8 && lng >= -17.5 && lng <= -11.3) return 'Sénégal';
    if (lat >= 6.0  && lat <= 12.5 && lng >= 1.0   && lng <= 3.8)   return 'Bénin';
    if (lat >= 4.0  && lat <= 10.7 && lng >= -8.6  && lng <= -2.5)  return 'Côte d\'Ivoire';
    if (lat >= 11.0 && lat <= 15.0 && lng >= -4.2  && lng <= 4.3)   return 'Burkina Faso';
    if (lat >= 11.0 && lat <= 25.0 && lng >= -4.3  && lng <= 4.3)   return 'Mali';
    if (lat >= 13.0 && lat <= 23.5 && lng >= 0.2   && lng <= 16.0)  return 'Niger';
    if (lat >= 6.0  && lat <= 11.2 && lng >= 0.0   && lng <= 1.8)   return 'Togo';
    if (lat >= 4.0  && lat <= 12.7 && lng >= -15.1 && lng <= -7.6)  return 'Guinée';
    return 'Lat ${lat.toStringAsFixed(2)}, Lng ${lng.toStringAsFixed(2)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authViewModelProvider).user!;
    final updated = user.copyWith(
      nom: _nomCtrl.text.trim(),
      telephone: _telCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      pays: _pays,
      secteur: _secteur,
      profilComplet: _nomCtrl.text.trim().isNotEmpty &&
          _telCtrl.text.trim().isNotEmpty &&
          _regionCtrl.text.trim().isNotEmpty,
    );
    await ref.read(authViewModelProvider.notifier).updateProfile(updated);
    if (mounted) setState(() => _editing = false);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);
    final user = state.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final completionPct = _completionPercent(user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AvatarCard(nom: user.nom, email: user.email, role: user.role),
              const SizedBox(height: 16),
              _CompletionCard(percent: completionPct),
              const SizedBox(height: 16),
              _SectionTitle('Informations personnelles'),
              const SizedBox(height: 8),
              _field(
                label: 'Nom complet',
                ctrl: _nomCtrl,
                icon: Icons.person_outline,
                enabled: _editing,
                validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Téléphone',
                ctrl: _telCtrl,
                icon: Icons.phone_outlined,
                enabled: _editing,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Email',
                ctrl: TextEditingController(text: user.email),
                icon: Icons.email_outlined,
                enabled: false,
              ),
              const SizedBox(height: 16),
              _SectionTitle('Localisation & Activité'),
              const SizedBox(height: 8),
              _dropdown(
                label: 'Pays',
                value: _pays,
                items: _paysList,
                enabled: _editing,
                onChanged: (v) => setState(() => _pays = v!),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      label: 'Région / Ville',
                      ctrl: _regionCtrl,
                      icon: Icons.location_on_outlined,
                      enabled: _editing,
                    ),
                  ),
                  if (_editing) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Détecter ma position GPS',
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _gpsLoading ? null : _detectLocation,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: _gpsLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location_outlined),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _dropdown(
                label: 'Secteur d\'activité',
                value: _secteur,
                items: _secteursList,
                enabled: _editing,
                onChanged: (v) => setState(() => _secteur = v!),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _showChangePasswordDialog(context),
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Changer le mot de passe'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await _confirmLogoutDialog(context);
                  if (confirm != true || !mounted) return;
                  // Attendre la fin de l'animation de fermeture du dialog (150ms Flutter)
                  // avant de déclencher le redirect GoRouter, sinon _debugLocked.
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (!mounted) return;
                  await ref.read(authViewModelProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Se déconnecter', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showExportDialog(context, user.id),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Télécharger mes données'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),
              const _SectionTitle('Zone dangereuse'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showDeleteAccountDialog(context),
                icon: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
                label: const Text('Supprimer mon compte', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  backgroundColor: AppColors.error.withValues(alpha: 0.04),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cette action est irréversible. Toutes vos données seront définitivement supprimées.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _completionPercent(UserModel user) {
    int filled = 0;
    if (user.nom.isNotEmpty) filled++;
    if (user.email.isNotEmpty) filled++;
    if (user.telephone.isNotEmpty) filled++;
    if (user.region.isNotEmpty) filled++;
    if (user.pays.isNotEmpty) filled++;
    if (user.secteur.isNotEmpty) filled++;
    return filled / 6;
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.background,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required bool enabled,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.background,
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: enabled ? onChanged : null,
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    String? errorMsg;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Changer le mot de passe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe actuel',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureNew,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                if (currentCtrl.text.trim().isEmpty || newCtrl.text.trim().isEmpty) {
                  setDialogState(() => errorMsg = 'Remplissez tous les champs');
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setDialogState(() => errorMsg = 'Les mots de passe ne correspondent pas');
                  return;
                }
                if (newCtrl.text.length < 6) {
                  setDialogState(() => errorMsg = 'Minimum 6 caractères requis');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await ref.read(authViewModelProvider.notifier).changePassword(
          currentCtrl.text.trim(),
          newCtrl.text.trim(),
        );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    if (!mounted) return;

    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Mot de passe modifié avec succès'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  /// Export RGPD (J3.4-J3.5) : laisse le choix du format, PDF (lisible) ou
  /// CSV (réutilisable), plutôt que de déclencher les deux téléchargements
  /// d'un coup — meilleure expérience qu'une double boîte de dialogue de
  /// partage/impression s'ouvrant simultanément.
  Future<void> _showExportDialog(BuildContext context, String userId) async {
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Exporter mes données'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Réunit toutes vos données personnelles (profil, scores, formations, '
                'demandes de financement, paiements, contrats d\'assurance…) dans un '
                'seul fichier.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      await ref.read(exportViewModelProvider.notifier).exportAsCsv(userId);
                      final error = ref.read(exportViewModelProvider).error;
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (error != null) _showExportError(context, error);
                    },
              child: const Text('CSV'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      await ref.read(exportViewModelProvider.notifier).exportAsPdf(userId);
                      final error = ref.read(exportViewModelProvider).error;
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (error != null) _showExportError(context, error);
                    },
              child: const Text('PDF'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<bool?> _confirmLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnecter', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    String? errorMsg;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Supprimer le compte'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette action est irréversible.\nToutes vos données (profil, score, demandes, formations) seront définitivement supprimées.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirmez avec votre mot de passe :',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: isLoading
                        ? null
                        : () => setDialogState(() => obscure = !obscure),
                  ),
                  errorText: errorMsg,
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final pwd = passwordCtrl.text.trim();
                      if (pwd.isEmpty) {
                        setDialogState(
                            () => errorMsg = 'Entrez votre mot de passe');
                        return;
                      }
                      setDialogState(() {
                        errorMsg = null;
                        isLoading = true;
                      });

                      final error = await ref
                          .read(authViewModelProvider.notifier)
                          .deleteAccount(pwd);

                      if (error != null) {
                        // Erreur : on l'affiche dans le dialog, pas besoin de mounted.
                        if (ctx.mounted) {
                          setDialogState(() {
                            errorMsg = error;
                            isLoading = false;
                          });
                        }
                      }
                      // Succès : _RouterNotifier redirige vers /login automatiquement.
                      // Le dialog disparaît avec la navigation — pas de mounted à vérifier.
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.error),
                    )
                  : const Text('Supprimer',
                      style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );

    passwordCtrl.dispose();
  }
}

class _AvatarCard extends StatelessWidget {
  final String nom;
  final String email;
  final UserRole role;
  const _AvatarCard({required this.nom, required this.email, required this.role});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                nom.isNotEmpty ? nom[0].toUpperCase() : 'G',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  _RoleBadge(role),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge(this.role);

  String get _label => switch (role) {
        UserRole.admin => 'Administrateur',
        UserRole.partenaireAssureur => 'Partenaire Assureur',
        UserRole.partenaireFinanceur => 'Partenaire Financeur',
        UserRole.user => 'Utilisateur',
      };

  Color get _color => switch (role) {
        UserRole.admin => AppColors.error,
        UserRole.partenaireAssureur => AppColors.info,
        UserRole.partenaireFinanceur => AppColors.secondary,
        UserRole.user => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(_label, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  final double percent;
  const _CompletionCard({required this.percent});

  @override
  Widget build(BuildContext context) {
    final pct = (percent * 100).round();
    final isComplete = pct == 100;
    return Card(
      color: isComplete ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.info_outline,
                  color: isComplete ? AppColors.success : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Profil complété à $pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isComplete ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation(
                  isComplete ? AppColors.success : AppColors.warning,
                ),
              ),
            ),
            if (!isComplete) ...[
              const SizedBox(height: 6),
              const Text(
                'Un profil complet est requis pour soumettre une demande de financement.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
