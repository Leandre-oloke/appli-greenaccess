import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message_model.dart';
import '../repositories/messagerie_repository.dart';

class MessagerieState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool envoiEnCours;
  final String? error;

  const MessagerieState({
    this.messages = const [],
    this.isLoading = false,
    this.envoiEnCours = false,
    this.error,
  });

  MessagerieState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? envoiEnCours,
    String? error,
  }) {
    return MessagerieState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      envoiEnCours: envoiEnCours ?? this.envoiEnCours,
      error: error,
    );
  }
}

/// Porte la logique de conversation d'une demande de financement (J5.3,
/// CDC §2.4) — s'abonne au flux temps réel des messages dès sa création,
/// comme `NotificationViewModel` pour les notifications.
class MessagerieViewModel extends StateNotifier<MessagerieState> {
  final MessagerieRepository _repository;
  final String demandeId;

  StreamSubscription<List<MessageModel>>? _sub;

  MessagerieViewModel(this._repository, this.demandeId) : super(const MessagerieState()) {
    _init();
  }

  void _init() {
    state = state.copyWith(isLoading: true);
    _sub = _repository.streamMessages(demandeId).listen(
      (messages) => state = state.copyWith(messages: messages, isLoading: false),
      onError: (e) => state = state.copyWith(isLoading: false, error: e.toString()),
    );
  }

  Future<void> envoyerMessage({
    required String auteurId,
    required String auteurNom,
    required String contenu,
  }) async {
    final texte = contenu.trim();
    if (texte.isEmpty) return;

    state = state.copyWith(envoiEnCours: true);
    try {
      await _repository.envoyerMessage(
        demandeId: demandeId,
        auteurId: auteurId,
        auteurNom: auteurNom,
        contenu: texte,
      );
      state = state.copyWith(envoiEnCours: false);
    } catch (e) {
      state = state.copyWith(envoiEnCours: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final messagerieViewModelProvider =
    StateNotifierProvider.family<MessagerieViewModel, MessagerieState, String>(
  (ref, demandeId) => MessagerieViewModel(MessagerieRepository(), demandeId),
);
