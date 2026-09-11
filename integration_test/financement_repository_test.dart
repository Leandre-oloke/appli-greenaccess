// Test d'intégration FinancementRepository contre les émulateurs Firebase
// (Auth + Firestore), via le package `integration_test` officiel.
// Actuellement bloqué en exécution — voir auth_repository_test.dart (même
// dossier) pour le diagnostic complet, et README.md §7.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greenaccess/firebase_options.dart';
import 'package:greenaccess/models/demande_financement_model.dart';
import 'package:greenaccess/repositories/financement_repository.dart';

const _emulatorHost = 'localhost';

String _uniqueEmail(String tag) =>
    '$tag-${DateTime.now().microsecondsSinceEpoch}@greenaccess.test';

const _password = 'MotDePasse123!';

Future<String> _signUp(String tag) async {
  final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: _uniqueEmail(tag),
    password: _password,
  );
  return credential.user!.uid;
}

/// Comme [_signUp] mais retourne aussi l'email, pour pouvoir se reconnecter
/// plus tard après être passé par un autre compte.
Future<(String uid, String email)> _signUpWithEmail(String tag) async {
  final email = _uniqueEmail(tag);
  final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: _password,
  );
  return (credential.user!.uid, email);
}

DemandeFinancementModel _demande(String userId, {StatutDemande statut = StatutDemande.brouillon}) {
  return DemandeFinancementModel(
    id: '',
    userId: userId,
    dateSoumission: DateTime.now(),
    montant: 5000000,
    typeProjet: 'Agriculture biologique',
    secteur: 'Agriculture',
    pays: 'Sénégal',
    descriptionProjet: 'Extension d\'une exploitation maraîchère bio.',
    statut: statut,
    scoreEligibilite: 72,
    docsUrl: const [],
    alignementTaxonomie: 'Conforme',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FinancementRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8085);
    repo = FinancementRepository(firestore: FirebaseFirestore.instance);
  });

  setUp(() async {
    await FirebaseAuth.instance.signOut();
  });

  test('submit() puis fetchStatut() (aller-retour Firestore)', () async {
    final userId = await _signUp('submit');
    final created = await repo.submit(_demande(userId));

    expect(created.id, isNotEmpty);
    final fetched = await repo.fetchStatut(created.id);
    expect(fetched, isNotNull);
    expect(fetched!.userId, userId);
    expect(fetched.montant, 5000000);
    expect(fetched.statut, StatutDemande.brouillon);
    expect(fetched.alignementTaxonomie, 'Conforme');
  });

  test('fetchUserDemandes() renvoie uniquement les demandes de l\'utilisateur', () async {
    final (userId, email) = await _signUpWithEmail('userdemandes');
    for (var i = 0; i < 3; i++) {
      await repo.submit(_demande(userId));
    }

    // Un autre utilisateur soumet aussi une demande, pendant que la session
    // active passe sur son propre compte.
    await _signUp('autreuser');
    await repo.submit(_demande(await _signUp('autreuser2')));

    // De retour sur le compte d'origine : la requête filtrée par userId ne
    // doit renvoyer que ses 3 demandes (Security Rules + filtre `.where`).
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: _password);

    final demandes = await repo.fetchUserDemandes(userId);
    expect(demandes.length, 3);
    expect(demandes.every((d) => d.userId == userId), isTrue);
  });

  test('updateStatut() : le propriétaire peut modifier tant que la demande est "brouillon"', () async {
    final userId = await _signUp('ownerupdate');
    final created = await repo.submit(_demande(userId));

    await repo.updateStatut(created.id, StatutDemande.soumis);
    final afterFirstUpdate = await repo.fetchStatut(created.id);
    expect(afterFirstUpdate!.statut, StatutDemande.soumis);

    // La demande n'est plus "brouillon" : le propriétaire ne peut plus la modifier
    // lui-même (firestore.rules — seul admin/partenaireFinanceur le peuvent).
    await expectLater(
      repo.updateStatut(created.id, StatutDemande.enExamen),
      throwsA(isA<FirebaseException>()),
    );
  });

  test('genererEcheancier() puis fetchRemboursements() (échéancier mensuel ordonné)', () async {
    final userId = await _signUp('echeancier');
    final created = await repo.submit(_demande(userId));

    await repo.genererEcheancier(
      demandeId: created.id,
      montantTotal: 1200000,
      dureesMois: 12,
      dateDebut: DateTime(2026, 1, 1),
    );

    final echeances = await repo.fetchRemboursements(created.id);
    expect(echeances.length, 12);
    expect(echeances.first.numeroEcheance, 1);
    expect(echeances.last.numeroEcheance, 12);
    expect(echeances.first.montant, closeTo(100000, 0.01));
    expect(echeances.every((e) => e.paye == false), isTrue);
  });

  test('un utilisateur ne peut pas lire la demande de financement d\'un autre', () async {
    final ownerId = await _signUp('demandeowner');
    final created = await repo.submit(_demande(ownerId));

    await FirebaseAuth.instance.signOut();
    await _signUp('demandereader');

    await expectLater(repo.fetchStatut(created.id), throwsA(isA<FirebaseException>()));
  });
}
