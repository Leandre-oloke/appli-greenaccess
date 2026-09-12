// Test d'intégration RGPD (J3.9, CDC §7.1 · T11) : valide bout en bout le
// parcours de portabilité (export) puis d'effacement (suppression de compte)
// d'un même utilisateur.
//
// Ceci n'est PAS un `integration_test/` Flutter classique contre de vrais
// émulateurs Firebase : ce mécanisme est bloqué dans ce Codespace
// (Firebase.initializeApp() reste indéfiniment en attente — diagnostic
// complet en tête de integration_test/auth_repository_test.dart et
// README.md §7). Le scénario T11 est donc validé au niveau où il est
// réellement exécutable ici : les vrais ExportRepository/AuthRepository/
// AuditRepository, enchaînés dans l'ordre du parcours utilisateur réel,
// contre un FakeFirebaseFirestore partagé — sans mock de la logique métier
// (contrairement aux tests de ViewModels de ce dépôt, qui substituent
// souvent des fakes de repository entiers).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/repositories/audit_repository.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/export_repository.dart';

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

const _userId = 'alice';

void main() {
  test(
    'parcours complet : un utilisateur exporte ses données puis supprime son compte',
    () async {
      final db = FakeFirebaseFirestore();

      // ── État initial : profil + données dans plusieurs modules ────────────
      await db.collection('users').doc(_userId).set({
        'nom': 'Alice Dupont',
        'email': 'alice@greenaccess.test',
        'telephone': '+221700000000',
        'pays': 'Sénégal',
        'region': 'Dakar',
        'secteur': 'Agriculture',
        'date_inscription': DateTime(2024, 1, 10),
        'profil_complet': true,
        'role': 'user',
      });
      await db.collection('scores_climat').add({
        'userId': _userId,
        'score_total': 72.0,
        'criteres': {
          'activite': 80,
          'uemoa': 70,
          'co2': 60,
          'certif': 50,
          'resilience': 90,
          'bonus_formation': 5,
        },
        'suggestions': <String>[],
        'date_calcul': DateTime(2025, 3, 1),
        'version_algo': 'v1-cloud',
      });
      await db.collection('users').doc(_userId).collection('progress').doc('c1').set({
        'statut': 'TERMINE',
        'score_quiz': 90,
        'points_xp_gagnés': 40,
        'badge_declenche': true,
      });

      final exportRepo = ExportRepository(firestore: db);
      final auditRepo = AuditRepository(firestore: db);
      final auth = _FakeFirebaseAuth(_FakeUser(uid: _userId, email: 'alice@greenaccess.test'));
      final authRepo = AuthRepository(auth: auth, firestore: db, audit: auditRepo);

      // ── 1. Portabilité : l'export réunit bien les données existantes ──────
      final avantSuppression = await exportRepo.exportUserData(_userId);
      expect(avantSuppression.profil.nom, 'Alice Dupont');
      expect(avantSuppression.scores, hasLength(1));
      expect(avantSuppression.progressions, hasLength(1));

      // ── 2. Effacement : suppression du compte ──────────────────────────────
      await authRepo.deleteAccount('motdepasse123');

      // Le profil Firestore n'existe plus.
      final profilApres = await db.collection('users').doc(_userId).get();
      expect(profilApres.exists, isFalse);

      // Un nouvel export échoue désormais explicitement (profil supprimé) —
      // plutôt qu'un export vide silencieux qui masquerait la suppression.
      expect(() => exportRepo.exportUserData(_userId), throwsA(isA<Exception>()));

      // ── 3. Traçabilité : le journal d'audit garde la trace de la suppression ─
      final logs = await auditRepo.fetchLogs();
      expect(logs.map((l) => l.action), contains('compte_supprime'));
      expect(logs.firstWhere((l) => l.action == 'compte_supprime').userId, _userId);
    },
  );
}
