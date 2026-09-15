// Tests unitaires de MessagerieRepository (J5.2) — envoi de message et flux
// temps réel des messages d'une demande de financement.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/repositories/messagerie_repository.dart';

const _demandeId = 'd1';

void main() {
  group('MessagerieRepository — envoyerMessage', () {
    test('écrit un message avec les champs attendus dans la sous-collection', () async {
      final db = FakeFirebaseFirestore();
      final repo = MessagerieRepository(firestore: db);

      await repo.envoyerMessage(
        demandeId: _demandeId,
        auteurId: 'alice',
        auteurNom: 'Alice Dupont',
        contenu: 'Bonjour, où en est ma demande ?',
      );

      final snapshot = await db
          .collection('demandes_financement')
          .doc(_demandeId)
          .collection('messages')
          .get();
      expect(snapshot.docs, hasLength(1));
      final data = snapshot.docs.first.data();
      expect(data['demande_id'], _demandeId);
      expect(data['auteur_id'], 'alice');
      expect(data['auteur_nom'], 'Alice Dupont');
      expect(data['contenu'], 'Bonjour, où en est ma demande ?');
      expect(data['created_at'], isNotNull);
    });
  });

  group('MessagerieRepository — streamMessages', () {
    test('émet les messages triés du plus ancien au plus récent', () async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('demandes_financement').doc(_demandeId).collection('messages');
      await ref.add({
        'demande_id': _demandeId,
        'auteur_id': 'admin1',
        'auteur_nom': 'Admin',
        'contenu': 'Message récent',
        'created_at': Timestamp.fromDate(DateTime(2025, 2, 1)),
      });
      await ref.add({
        'demande_id': _demandeId,
        'auteur_id': 'alice',
        'auteur_nom': 'Alice',
        'contenu': 'Message ancien',
        'created_at': Timestamp.fromDate(DateTime(2025, 1, 1)),
      });
      final repo = MessagerieRepository(firestore: db);

      final messages = await repo.streamMessages(_demandeId).first;

      expect(messages, hasLength(2));
      expect(messages.first.contenu, 'Message ancien');
      expect(messages.last.contenu, 'Message récent');
    });

    test('le flux émet une nouvelle valeur quand un message est ajouté', () async {
      final db = FakeFirebaseFirestore();
      final repo = MessagerieRepository(firestore: db);

      final emissions = <int>[];
      final sub = repo.streamMessages(_demandeId).listen((m) => emissions.add(m.length));
      addTearDown(sub.cancel);

      await repo.envoyerMessage(
        demandeId: _demandeId,
        auteurId: 'alice',
        auteurNom: 'Alice',
        contenu: 'Premier message',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await repo.envoyerMessage(
        demandeId: _demandeId,
        auteurId: 'admin1',
        auteurNom: 'Admin',
        contenu: 'Réponse',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions, contains(1));
      expect(emissions.last, 2);
    });
  });
}
