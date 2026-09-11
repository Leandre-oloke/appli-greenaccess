// Test d'intégration AuthRepository contre les émulateurs Firebase (Auth +
// Firestore). Tag "integration" : exclu de `flutter test` (VM, sans platform
// channels — voir README.md §7) et exécuté séparément via
// `flutter test --tags=integration --platform chrome`, à l'intérieur de
// `firebase emulators:exec`. Voir .github/workflows/ci.yml, job
// "flutter integration tests (emulator)".
@Tags(['integration'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenaccess/firebase_options.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';

const _emulatorHost = 'localhost';

/// Emails uniques par exécution pour éviter les collisions "email-already-in-use"
/// entre les tests de ce fichier (l'émulateur Auth garde son état le temps du run).
String _uniqueEmail(String tag) =>
    '$tag-${DateTime.now().microsecondsSinceEpoch}@greenaccess.test';

void main() {
  late AuthRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8085);
    repo = AuthRepository(auth: FirebaseAuth.instance, firestore: FirebaseFirestore.instance);
  });

  setUp(() async {
    await FirebaseAuth.instance.signOut();
  });

  test('registerWithEmail + saveUserProfile + getCurrentUser (aller-retour complet)', () async {
    final email = _uniqueEmail('register');
    final credential = await repo.registerWithEmail(email, 'MotDePasse123!');
    final uid = credential.user!.uid;

    final profile = UserModel(
      id: uid,
      nom: 'Aïcha Diallo',
      email: email,
      telephone: '+221700000000',
      pays: 'Sénégal',
      region: 'Dakar',
      secteur: 'Agriculture',
      dateInscription: DateTime.now(),
      profilComplet: true,
      role: UserRole.user,
    );
    await repo.saveUserProfile(profile);

    final fetched = await repo.getCurrentUser();
    expect(fetched, isNotNull);
    expect(fetched!.id, uid);
    expect(fetched.nom, 'Aïcha Diallo');
    expect(fetched.email, email);
    expect(fetched.role, UserRole.user);
  });

  test('getCurrentUser retourne null quand personne n\'est connecté', () async {
    final current = await repo.getCurrentUser();
    expect(current, isNull);
  });

  test('signInWithEmail réauthentifie un utilisateur existant', () async {
    final email = _uniqueEmail('signin');
    await repo.registerWithEmail(email, 'MotDePasse123!');
    await repo.signOut();

    final credential = await repo.signInWithEmail(email, 'MotDePasse123!');
    expect(credential.user, isNotNull);
    expect(credential.user!.email, email);
  });

  test('signInWithEmail échoue avec un mauvais mot de passe', () async {
    final email = _uniqueEmail('badpass');
    await repo.registerWithEmail(email, 'MotDePasse123!');
    await repo.signOut();

    await expectLater(
      repo.signInWithEmail(email, 'MauvaisMotDePasse'),
      throwsA(isA<FirebaseAuthException>()),
    );
  });

  test('changePassword permet ensuite de se reconnecter avec le nouveau mot de passe', () async {
    final email = _uniqueEmail('changepwd');
    await repo.registerWithEmail(email, 'AncienMdp123!');

    await repo.changePassword('AncienMdp123!', 'NouveauMdp456!');
    await repo.signOut();

    final credential = await repo.signInWithEmail(email, 'NouveauMdp456!');
    expect(credential.user, isNotNull);
  });

  test('deleteAccount supprime le compte Auth et le profil Firestore', () async {
    final email = _uniqueEmail('delete');
    final credential = await repo.registerWithEmail(email, 'MotDePasse123!');
    final uid = credential.user!.uid;
    await repo.saveUserProfile(UserModel(
      id: uid,
      nom: 'À supprimer',
      email: email,
      telephone: '',
      pays: 'Togo',
      region: 'Maritime',
      secteur: 'Recyclage',
      dateInscription: DateTime.now(),
      profilComplet: true,
      role: UserRole.user,
    ));

    await repo.deleteAccount('MotDePasse123!');

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    expect(doc.exists, isFalse);
    await expectLater(
      repo.signInWithEmail(email, 'MotDePasse123!'),
      throwsA(isA<FirebaseAuthException>()),
    );
  });
}
