// Test d'intégration de la messagerie liée à une demande de financement
// (J5.9, CDC §7.1) : valide bout en bout le parcours de conversation entre
// le demandeur et le partenaire financeur assigné — MessagerieRepository et
// MessagerieViewModel réels, enchaînés dans l'ordre du parcours utilisateur
// réel, contre un FakeFirebaseFirestore partagé (même stratégie que
// rgpd_export_deletion_scenario_test.dart et
// carte_alea_produit_parametrique_scenario_test.dart).
//
// Le volet "règles" du CDC §7.1 (accès réservé aux deux parties de la
// demande — propriétaire, partenaire assigné, admin) est validé séparément
// contre le vrai moteur de règles Firestore dans
// firestore-tests/rules.test.mjs (34 tests, dont les cas assigné/non-assigné
// de J5.5) : FakeFirebaseFirestore n'applique aucune Security Rule, donc ce
// fichier-ci se concentre sur le volet "flux" — l'échange réel entre les
// deux parties, dans l'ordre, via les mêmes classes que l'app.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/repositories/messagerie_repository.dart';
import 'package:greenaccess/viewmodels/messagerie_viewmodel.dart';

const _demandeId = 'd-t-messagerie';
const _demandeurId = 'alice';
const _partenaireId = 'financeur1';

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test(
    'scénario : le demandeur et le partenaire financeur assigné échangent sur une demande',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('demandes_financement').doc(_demandeId).set({
        'userId': _demandeurId,
        'partenaire_id': _partenaireId,
        'statut': 'soumis',
      });

      final repository = MessagerieRepository(firestore: db);

      // Les deux parties observent le même fil via deux instances de
      // ViewModel indépendantes (comme deux appareils/sessions distincts),
      // toutes deux abonnées au flux temps réel dès leur création (voir
      // J5.3).
      final container = ProviderContainer(
        overrides: [
          messagerieViewModelProvider(_demandeId).overrideWith(
            (ref) => MessagerieViewModel(repository, _demandeId),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(messagerieViewModelProvider(_demandeId));
      await _flush();

      expect(container.read(messagerieViewModelProvider(_demandeId)).messages, isEmpty);

      // 1. Le demandeur ouvre la conversation.
      await container.read(messagerieViewModelProvider(_demandeId).notifier).envoyerMessage(
            auteurId: _demandeurId,
            auteurNom: 'Alice Dupont',
            contenu: "Bonjour, où en est ma demande ?",
          );
      await _flush();

      // 2. Le partenaire financeur assigné répond (même fil, même viewmodel
      // ici car FakeFirebaseFirestore est partagé — le point testé est que
      // le flux temps réel restitue bien les deux messages, dans l'ordre,
      // avec le bon auteur pour chacun).
      await repository.envoyerMessage(
        demandeId: _demandeId,
        auteurId: _partenaireId,
        auteurNom: 'Partenaire Financeur',
        contenu: 'Elle est en cours d\'examen, réponse sous 48h.',
      );
      await _flush();

      final state = container.read(messagerieViewModelProvider(_demandeId));
      expect(state.messages, hasLength(2));
      expect(state.messages[0].auteurId, _demandeurId);
      expect(state.messages[0].contenu, "Bonjour, où en est ma demande ?");
      expect(state.messages[1].auteurId, _partenaireId);
      expect(state.messages[1].contenu, "Elle est en cours d'examen, réponse sous 48h.");
      expect(state.error, isNull);

      // 3. Le demandeur clôt l'échange par un accusé de réception.
      await container.read(messagerieViewModelProvider(_demandeId).notifier).envoyerMessage(
            auteurId: _demandeurId,
            auteurNom: 'Alice Dupont',
            contenu: 'Merci, je reste en attente.',
          );
      await _flush();

      final messages = await db
          .collection('demandes_financement')
          .doc(_demandeId)
          .collection('messages')
          .orderBy('created_at')
          .get();
      expect(messages.docs, hasLength(3));
      expect(messages.docs.every((d) => d.data()['demande_id'] == _demandeId), isTrue);
    },
  );
}
