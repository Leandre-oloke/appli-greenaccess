import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/messagerie_viewmodel.dart';

/// Interface de chat entre le demandeur et le partenaire financeur/admin sur
/// une demande de financement (J5.4, CDC §3 M2).
class MessageriePartenaireScreen extends ConsumerStatefulWidget {
  final String demandeId;
  const MessageriePartenaireScreen({super.key, required this.demandeId});

  @override
  ConsumerState<MessageriePartenaireScreen> createState() =>
      _MessageriePartenaireScreenState();
}

class _MessageriePartenaireScreenState extends ConsumerState<MessageriePartenaireScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _dernierNombreMessages = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollVersLeBas() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _envoyer() async {
    final texte = _controller.text;
    if (texte.trim().isEmpty) return;
    final user = ref.read(authViewModelProvider).user;
    if (user == null) return;

    _controller.clear();
    await ref.read(messagerieViewModelProvider(widget.demandeId).notifier).envoyerMessage(
          auteurId: user.id,
          auteurNom: user.nom,
          contenu: texte,
        );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(messagerieViewModelProvider(widget.demandeId));

    if (state.messages.length != _dernierNombreMessages) {
      _dernierNombreMessages = state.messages.length;
      _scrollVersLeBas();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messagerie')),
      body: Column(
        children: [
          if (state.error != null)
            Container(
              width: double.infinity,
              color: AppColors.error.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(12),
              child: Text(
                'Impossible de charger la conversation. Réessayez.',
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aucun message pour l\'instant. Démarrez la conversation.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: state.messages.length,
                        itemBuilder: (context, i) {
                          final message = state.messages[i];
                          final estMoi = message.auteurId == uid;
                          return _MessageBulle(message: message, estMoi: estMoi);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _envoyer(),
                      decoration: InputDecoration(
                        hintText: 'Écrire un message…',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  state.envoiEnCours
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: AppColors.primary),
                          onPressed: _envoyer,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBulle extends StatelessWidget {
  final MessageModel message;
  final bool estMoi;
  const _MessageBulle({required this.message, required this.estMoi});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: estMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: estMoi ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(estMoi ? 14 : 2),
            bottomRight: Radius.circular(estMoi ? 2 : 14),
          ),
          border: estMoi ? null : Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!estMoi)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.auteurNom,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            Text(
              message.contenu,
              style: TextStyle(color: estMoi ? Colors.white : AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              message.createdAt != null ? DateFormat('HH:mm').format(message.createdAt!) : '',
              style: TextStyle(
                fontSize: 10,
                color: estMoi ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
