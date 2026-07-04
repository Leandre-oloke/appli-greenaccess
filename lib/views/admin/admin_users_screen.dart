import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminViewModelProvider.notifier).loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);
    final currentAdminId = ref.watch(authViewModelProvider.select((s) => s.user?.id));

    ref.listen(adminViewModelProvider, (_, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: AppColors.success),
        );
        ref.read(adminViewModelProvider.notifier).clearMessages();
      }
    });

    final filtered = state.users.where((u) {
      final q = _search.toLowerCase();
      return u.nom.toLowerCase().contains(q) ||
             u.email.toLowerCase().contains(q) ||
             u.pays.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Utilisateurs (${state.users.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur…',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? const Center(child: Text('Aucun utilisateur trouvé'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final user = filtered[i];
                    final isSelf = user.id == currentAdminId;
                    return _UserCard(
                      user: user,
                      isSelf: isSelf,
                      onRoleChange: (role) => ref.read(adminViewModelProvider.notifier).changeUserRole(user.id, role),
                      onDelete: isSelf ? null : () => _confirmDelete(context, user),
                    );
                  },
                ),
    );
  }

  void _confirmDelete(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text('${user.nom} sera retiré de la plateforme.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminViewModelProvider.notifier).deleteUser(user.id);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool isSelf;
  final ValueChanged<UserRole> onRoleChange;
  final VoidCallback? onDelete;
  const _UserCard({required this.user, required this.isSelf, required this.onRoleChange, required this.onDelete});

  static const _roleColors = {
    UserRole.admin:              Colors.red,
    UserRole.partenaireFinanceur: Color(0xFF7B1FA2),
    UserRole.partenaireAssureur:  Color(0xFF0277BD),
    UserRole.user:               AppColors.primary,
  };

  static const _roleLabels = {
    UserRole.admin:              'Admin',
    UserRole.partenaireFinanceur: 'P. Financeur',
    UserRole.partenaireAssureur:  'P. Assureur',
    UserRole.user:               'Utilisateur',
  };

  @override
  Widget build(BuildContext context) {
    final color = _roleColors[user.role] ?? AppColors.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Text('${user.pays} · ${user.secteur}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<UserRole>(
                  tooltip: 'Changer le rôle',
                  onSelected: onRoleChange,
                  child: Chip(
                    label: Text(_roleLabels[user.role] ?? 'user',
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                    backgroundColor: color.withValues(alpha: 0.1),
                    side: BorderSide(color: color.withValues(alpha: 0.3)),
                    padding: EdgeInsets.zero,
                  ),
                  itemBuilder: (_) => UserRole.values.map((r) => PopupMenuItem(
                    value: r,
                    child: Text(_roleLabels[r] ?? r.name),
                  )).toList(),
                ),
                if (isSelf)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Vous', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.error,
                    padding: EdgeInsets.zero,
                    onPressed: onDelete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
