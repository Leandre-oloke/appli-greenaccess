import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../repositories/notification_repository.dart';
import '../../routes.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réglages'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // ── Profil admin ───────────────────────────────────────────────────
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.admin_panel_settings, color: Colors.white),
            ),
            title: Text(user?.nom ?? 'Administrateur', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),

          // ── Navigation ─────────────────────────────────────────────────────
          _tile(Icons.switch_account_outlined, 'Vue utilisateur', 'Basculer vers l\'interface apprenant',
              () => context.go(AppRoutes.dashboard)),
          _tile(Icons.person_outline, 'Mon profil', 'Modifier mes informations',
              () => context.go(AppRoutes.profil)),

          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('PLATEFORME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),

          _tile(Icons.school_outlined, 'Gérer les formations',
              'Ajouter, modifier, supprimer des cours', () => context.go(AppRoutes.adminFormations)),
          _tile(Icons.people_outlined, 'Gérer les utilisateurs',
              'Rôles, comptes, accès', () => context.go(AppRoutes.adminUsers)),
          _tile(Icons.assignment_outlined, 'Demandes de financement',
              'Examiner et approuver les dossiers', () => context.go(AppRoutes.adminDemandes)),

          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('NOTIFICATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),

          _tile(
            Icons.campaign_outlined,
            'Envoyer une notification',
            'Diffuser un message à tous les utilisateurs',
            () => _showSendNotificationDialog(context),
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('COMPTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),

          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Se déconnecter', style: TextStyle(color: AppColors.error)),
            onTap: () => ref.read(authViewModelProvider.notifier).signOut(),
          ),

          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('GreenAccess Admin v1.0.0',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  ListTile _tile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  Future<void> _showSendNotificationDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final titreCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    NotificationType selectedType = NotificationType.info;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.campaign_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Envoyer une notification'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<NotificationType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: NotificationType.info,    child: Text('ℹ️  Information')),
                    DropdownMenuItem(value: NotificationType.success,  child: Text('✅  Succès')),
                    DropdownMenuItem(value: NotificationType.warning,  child: Text('⚠️  Avertissement')),
                    DropdownMenuItem(value: NotificationType.alert,    child: Text('🚨  Alerte')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (titreCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Envoyer'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await NotificationRepository().send(
        titre: titreCtrl.text.trim(),
        message: messageCtrl.text.trim(),
        type: selectedType.name,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Notification envoyée à tous les utilisateurs'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    } finally {
      titreCtrl.dispose();
      messageCtrl.dispose();
    }
  }
}
