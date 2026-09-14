// Tests unitaires de MessagerieViewModel (J5.3) — s'abonne au flux temps réel
// des messages dès sa création (comme NotificationViewModel), envoi de
// message, gestion des erreurs.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/repositories/messagerie_repository.dart';
import 'package:greenaccess/viewmodels/messagerie_viewmodel.dart';

const _demandeId = 'd1';

ProviderContainer _makeContainer(MessagerieRepository repo) {
  final container = ProviderContainer(
    overrides: [
      messagerieViewModelProvider(_demandeId).overrideWith(
        (ref) => MessagerieViewModel(repo, _demandeId),
      ),
    ],
  );
  // StateNotifierProvider est paresseux : sans ce read immédiat, l'abonnement
  // au flux fait par le constructeur de MessagerieViewModel ne démarre qu'au
  // premier accès — trop tard pour les tests qui attendent un court délai
  // (même piège que NotificationViewModel, voir J2.26).
  container.read(messagerieViewModelProvider(_demandeId));
  return container;
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  group('MessagerieViewModel — chargement initial', () {
    test('charge les messages déjà présents dans Firestore', () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('demandes_financement')
          .doc(_demandeId)
          .collection('messages')
          .add({
        'demande_id': _demandeId,
        'auteur_id': 'alice',
        'auteur_nom': 'Alice',
        'contenu': 'Bonjour',
        'created_at': DateTime(2025, 1, 1),
      });
      final container = _makeContainer(MessagerieRepository(firestore: db));
      addTearDown(container.dispose);
      await _flush();

      final state = container.read(messagerieViewModelProvider(_demandeId));
      expect(state.messages, hasLength(1));
      expect(state.messages.first.contenu, 'Bonjour');
      expect(state.isLoading, isFalse);
    });

    test('démarre vide sans erreur quand aucun message n\'existe encore', () async {
      final container = _makeContainer(MessagerieRepository(firestore: FakeFirebaseFirestore()));
      addTearDown(container.dispose);
      await _flush();

      final state = container.read(messagerieViewModelProvider(_demandeId));
      expect(state.messages, isEmpty);
      expect(state.error, isNull);
    });
  });

  group('MessagerieViewModel — envoyerMessage', () {
    test('écrit le message et le fil se met à jour via le flux temps réel', () async {
      final db = FakeFirebaseFirestore();
      final container = _makeContainer(MessagerieRepository(firestore: db));
      addTearDown(container.dispose);
      await _flush();

      await container.read(messagerieViewModelProvider(_demandeId).notifier).envoyerMessage(
            auteurId: 'alice',
            auteurNom: 'Alice',
            contenu: 'Nouveau message',
          );
      await _flush();

      final state = container.read(messagerieViewModelProvider(_demandeId));
      expect(state.messages, hasLength(1));
      expect(state.messages.first.contenu, 'Nouveau message');
      expect(state.messages.first.auteurNom, 'Alice');
      expect(state.envoiEnCours, isFalse);
    });

    test('un contenu vide (ou uniquement des espaces) n\'envoie rien', () async {
      final db = FakeFirebaseFirestore();
      final container = _makeContainer(MessagerieRepository(firestore: db));
      addTearDown(container.dispose);
      await _flush();

      await container
          .read(messagerieViewModelProvider(_demandeId).notifier)
          .envoyerMessage(auteurId: 'alice', auteurNom: 'Alice', contenu: '   ');
      await _flush();

      final state = container.read(messagerieViewModelProvider(_demandeId));
      expect(state.messages, isEmpty);
    });

    test('le contenu est nettoyé (trim) avant l\'envoi', () async {
      final db = FakeFirebaseFirestore();
      final container = _makeContainer(MessagerieRepository(firestore: db));
      addTearDown(container.dispose);
      await _flush();

      await container.read(messagerieViewModelProvider(_demandeId).notifier).envoyerMessage(
            auteurId: 'alice',
            auteurNom: 'Alice',
            contenu: '  Avec espaces autour  ',
          );
      await _flush();

      final state = container.read(messagerieViewModelProvider(_demandeId));
      expect(state.messages.first.contenu, 'Avec espaces autour');
    });
  });
}
