// Test widget de MessageriePartenaireScreen (J5.4) : état vide, affichage des
// messages (bulles alignées selon l'auteur), envoi d'un message — sans
// Firebase réel (voir README.md §7). Même stratégie de fake que les autres
// tests widgets de ce dossier (fake_cloud_firestore + AuthViewModel fake).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/messagerie_repository.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/messagerie_viewmodel.dart';
import 'package:greenaccess/views/financement/messagerie_partenaire_screen.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: _MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class _FakeAuthViewModel extends AuthViewModel {
  _FakeAuthViewModel(String userId) : super(_FakeAuthRepository()) {
    state = AuthState(
      isAuthenticated: true,
      user: UserModel(
        id: userId,
        nom: 'Alice Dupont',
        email: 'alice@greenaccess.test',
        telephone: '',
        pays: 'Sénégal',
        region: 'Dakar',
        secteur: 'Agriculture',
        dateInscription: DateTime.now(),
        profilComplet: true,
        role: UserRole.user,
      ),
    );
  }
}

const _userId = 'alice';
const _demandeId = 'd1';

Widget _buildMessagerie(FakeFirebaseFirestore db) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel(_userId)),
      messagerieViewModelProvider(_demandeId).overrideWith(
        (ref) => MessagerieViewModel(MessagerieRepository(firestore: db), _demandeId),
      ),
    ],
    child: const MaterialApp(
      home: MessageriePartenaireScreen(demandeId: _demandeId),
    ),
  );
}

void main() {
  testWidgets("affiche l'état vide quand aucun message n'existe encore", (tester) async {
    await tester.pumpWidget(_buildMessagerie(FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    expect(find.text("Aucun message pour l'instant. Démarrez la conversation."), findsOneWidget);
  });

  testWidgets('affiche les messages existants, alignés selon leur auteur', (tester) async {
    final db = FakeFirebaseFirestore();
    await db
        .collection('demandes_financement')
        .doc(_demandeId)
        .collection('messages')
        .add({
      'demande_id': _demandeId,
      'auteur_id': 'alice',
      'auteur_nom': 'Alice Dupont',
      'contenu': 'Bonjour, où en est ma demande ?',
      'created_at': DateTime(2025, 1, 1, 10, 30),
    });
    await db
        .collection('demandes_financement')
        .doc(_demandeId)
        .collection('messages')
        .add({
      'demande_id': _demandeId,
      'auteur_id': 'financeur1',
      'auteur_nom': 'Partenaire Financeur',
      'contenu': 'Elle est en cours d\'examen.',
      'created_at': DateTime(2025, 1, 1, 10, 35),
    });

    await tester.pumpWidget(_buildMessagerie(db));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, où en est ma demande ?'), findsOneWidget);
    expect(find.text('Elle est en cours d\'examen.'), findsOneWidget);
    // Le nom de l'auteur n'est affiché que pour les messages qui ne sont pas
    // les miens (alice est l'utilisatrice connectée dans ce test).
    expect(find.text('Partenaire Financeur'), findsOneWidget);
    expect(find.text('Alice Dupont'), findsNothing);
  });

  testWidgets('taper un message puis appuyer sur envoyer l\'ajoute au fil', (tester) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(_buildMessagerie(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Merci pour votre réponse');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Merci pour votre réponse'), findsOneWidget);

    final messages = await db
        .collection('demandes_financement')
        .doc(_demandeId)
        .collection('messages')
        .get();
    expect(messages.docs, hasLength(1));
    expect(messages.docs.first.data()['contenu'], 'Merci pour votre réponse');
    expect(messages.docs.first.data()['auteur_id'], _userId);
  });

  testWidgets('le champ de saisie est vidé après l\'envoi', (tester) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(_buildMessagerie(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Un message');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
  });
}
