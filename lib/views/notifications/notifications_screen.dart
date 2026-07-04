import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      ref.read(notificationViewModelProvider(uid).notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider.select((s) => s.user?.id ?? ''));
    final state = ref.watch(notificationViewModelProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: Builder(builder: (context) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.notifications.isEmpty) {
          return const _EmptyState();
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.notifications.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            final notif = state.notifications[index];
            final isNew = notif.createdAt.isAfter(state.lastReadAt);
            return _NotifTile(
              notif: notif,
              isNew: isNew,
              onTap: () => _showDetail(context, notif),
            );
          },
        );
      }),
    );
  }

  void _showDetail(BuildContext context, NotificationModel notif) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            _TypeIcon(notif.type, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(notif.titre, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Text(notif.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final bool isNew;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.isNew, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: isNew ? AppColors.primarySoft : null,
      leading: _TypeIcon(notif.type),
      title: Text(
        notif.titre,
        style: TextStyle(
          fontWeight: isNew ? FontWeight.w700 : FontWeight.w400,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            notif.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(notif.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
      trailing: isNew
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      isThreeLine: true,
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return DateFormat('dd/MM/yyyy', 'fr').format(dt);
  }
}

class _TypeIcon extends StatelessWidget {
  final NotificationType type;
  final double size;
  const _TypeIcon(this.type, {this.size = 22});

  IconData get _icon => switch (type) {
        NotificationType.success => Icons.check_circle_outline,
        NotificationType.warning => Icons.warning_amber_outlined,
        NotificationType.alert   => Icons.notification_important_outlined,
        NotificationType.info    => Icons.info_outline,
      };

  Color get _color => switch (type) {
        NotificationType.success => AppColors.success,
        NotificationType.warning => AppColors.warning,
        NotificationType.alert   => AppColors.error,
        NotificationType.info    => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size,
      backgroundColor: _color.withValues(alpha: 0.12),
      child: Icon(_icon, color: _color, size: size),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none, size: 72, color: AppColors.divider),
          const SizedBox(height: 16),
          const Text(
            'Aucune notification',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les annonces de l\'administrateur\napparaîtront ici en temps réel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
