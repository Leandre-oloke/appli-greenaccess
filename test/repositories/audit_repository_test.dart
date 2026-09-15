// Tests unitaires du journal d'audit (J3.7-J3.8) : AuditRepository.logAction()
// lui-même, puis vérification que les 4 actions critiques listées par le CDC
// §6 (soumission, souscription, paiement, suppression) l'alimentent bien.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/models/demande_financement_model.dart';
import 'package:greenaccess/models/paiement_model.dart';
import 'package:greenaccess/repositories/assurance_repository.dart';
import 'package:greenaccess/repositories/audit_repository.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/financement_repository.dart';
import 'package:greenaccess/repositories/paiement_repository.dart';

class _FakeUser extends Fake implements User {
  _FakeUser({required this.uid, required this.email});
  @override
  final String uid;
  @override
  final String? email;

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async =>
      _FakeUserCredential();

  @override
  Future<void> delete() async {}
}

class _FakeUserCredential extends Fake implements UserCredential {}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  _FakeFirebaseAuth(this._user);
  final User _user;
  @override
  User? get currentUser => _user;
}

Future<List<Map<String, dynamic>>> _auditDocs(FakeFirebaseFirestore db) async {
  final snap = await db.collection('audit_logs').get();
  return snap.docs.map((d) => d.data()).toList();
}

void main() {
  group('AuditRepository — logAction / fetchLogs', () {
    test('logAction() écrit userId, action, details et un horodatage', () async {
      final db = FakeFirebaseFirestore();
      final repo = AuditRepository(firestore: db);

      await repo.logAction(
        userId: 'alice',
        action: 'financement_soumis',
        details: {'demandeId': 'd1'},
      );

      final docs = await _auditDocs(db);
      expect(docs, hasLength(1));
      expect(docs.first['userId'], 'alice');
      expect(docs.first['action'], 'financement_soumis');
      expect(docs.first['details'], {'demandeId': 'd1'});
      expect(docs.first['createdAt'], isA<Timestamp>());
    });

    test('fetchLogs() renvoie les logs triés du plus récent au plus ancien', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('audit_logs').add({
        'userId': 'alice',
        'action': 'paiement_initie',
        'details': {},
        'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
      });
      await db.collection('audit_logs').add({
        'userId': 'alice',
        'action': 'compte_supprime',
        'details': {},
        'createdAt': Timestamp.fromDate(DateTime(2025, 2, 1)),
      });
      final repo = AuditRepository(firestore: db);

      final logs = await repo.fetchLogs();

      expect(logs, hasLength(2));
      expect(logs.first.action, 'compte_supprime'); // le plus récent en premier
    });
  });

  group('Branchement de logAction() sur les actions critiques (J3.8)', () {
    test('FinancementRepository.submit() alimente le journal d\'audit', () async {
      final db = FakeFirebaseFirestore();
      final repo = FinancementRepository(firestore: db);

      await repo.submit(DemandeFinancementModel(
        id: '',
        userId: 'alice',
        dateSoumission: DateTime(2025, 1, 1),
        montant: 500000,
        typeProjet: 'x',
        secteur: 'Agriculture',
        pays: 'Sénégal',
        descriptionProjet: 'x',
        statut: StatutDemande.brouillon,
        scoreEligibilite: 0,
        docsUrl: const [],
        alignementTaxonomie: 'Conforme',
      ));

      final docs = await _auditDocs(db);
      expect(docs, hasLength(1));
      expect(docs.first['action'], 'financement_soumis');
      expect(docs.first['userId'], 'alice');
    });

    test('AssuranceRepository.soumettreDossier() alimente le journal d\'audit', () async {
      final db = FakeFirebaseFirestore();
      final repo = AssuranceRepository(firestore: db);

      await repo.soumettreDossier({
        'userId': 'alice',
        'produit_id': 'prod1',
        'assureur_id': 'ASS_01',
        'prime_mensuelle': 5000,
        'zone_risque': 'Sénégal',
      });

      final docs = await _auditDocs(db);
      expect(docs, hasLength(1));
      expect(docs.first['action'], 'assurance_souscrite');
      expect(docs.first['userId'], 'alice');
    });

    test('PaiementRepository.initierPaiement() alimente le journal d\'audit', () async {
      final db = FakeFirebaseFirestore();
      final repo = PaiementRepository(firestore: db);

      await repo.initierPaiement(
        demandeId: 'd1',
        echeanceId: 'e1',
        userId: 'alice',
        montant: 100000,
        operateur: OperateurMobileMoney.wave,
      );

      final docs = await _auditDocs(db);
      expect(docs, hasLength(1));
      expect(docs.first['action'], 'paiement_initie');
      expect(docs.first['userId'], 'alice');
    });

    test('AuthRepository.deleteAccount() alimente le journal d\'audit avant la suppression',
        () async {
      final db = FakeFirebaseFirestore();
      final auth = _FakeFirebaseAuth(_FakeUser(uid: 'alice', email: 'alice@greenaccess.test'));
      final repo = AuthRepository(auth: auth, firestore: db);
      await db.collection('users').doc('alice').set({'nom': 'Alice'});

      await repo.deleteAccount('motdepasse123');

      final docs = await _auditDocs(db);
      expect(docs, hasLength(1));
      expect(docs.first['action'], 'compte_supprime');
      expect(docs.first['userId'], 'alice');
      // Le document utilisateur a bien été supprimé après l'écriture du log.
      final userDoc = await db.collection('users').doc('alice').get();
      expect(userDoc.exists, isFalse);
    });
  });
}
