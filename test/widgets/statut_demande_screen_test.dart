// Test widget de StatutDemandeScreen (Refonte frontend, Phase 3 — étape 6 :
// Financement) : frise d'avancement (GaStatusTimeline). Aucun test
// n'existait auparavant sur cet écran.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/demande_financement_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/financement_repository.dart';
import 'package:greenaccess/ui/ui.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/financement_viewmodel.dart';
import 'package:greenaccess/views/financement/statut_demande_screen.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: _MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class _FakeAuthViewModel extends AuthViewModel {
  _FakeAuthViewModel() : super(_FakeAuthRepository()) {
    state = AuthState(
      isAuthenticated: true,
      user: UserModel(
        id: _userId,
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

class _FakeFinancementViewModel extends FinancementViewModel {
  _FakeFinancementViewModel(super.repository, super.userId, this._demande);
  final DemandeFinancementModel? _demande;

  @override
  Future<DemandeFinancementModel?> getStatut(String demandeId) async => _demande;
}

DemandeFinancementModel _demande(StatutDemande statut, {String? commentaireRejet}) =>
    DemandeFinancementModel(
      id: 'd1',
      userId: _userId,
      dateSoumission: DateTime(2026, 1, 10),
      montant: 500000,
      typeProjet: 'Agriculture résiliente',
      secteur: 'Agriculture',
      pays: 'Sénégal',
      descriptionProjet: 'Irrigation goutte-à-goutte',
      statut: statut,
      scoreEligibilite: 72,
      docsUrl: const [],
      commentaireRejet: commentaireRejet,
      alignementTaxonomie: 'Conforme',
    );

Widget _buildScreen(DemandeFinancementModel? demande) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel()),
      financementViewModelProvider.overrideWith(
        (ref, userId) => _FakeFinancementViewModel(
          FinancementRepository(firestore: FakeFirebaseFirestore()),
          userId,
          demande,
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const StatutDemandeScreen(demandeId: 'd1'),
    ),
  );
}

void main() {
  testWidgets('demande soumise : première étape "current", les suivantes "pending"',
      (tester) async {
    await tester.pumpWidget(_buildScreen(_demande(StatutDemande.soumis)));
    await tester.pumpAndSettle();

    final timeline = find.byType(GaStatusTimeline);
    expect(timeline, findsOneWidget);
    expect(find.descendant(of: timeline, matching: find.text('Soumis')), findsOneWidget);
    expect(find.descendant(of: timeline, matching: find.text('En examen')), findsOneWidget);
    expect(find.descendant(of: timeline, matching: find.text('Approuvé')), findsOneWidget);
    expect(find.descendant(of: timeline, matching: find.text('Financé')), findsOneWidget);
  });

  testWidgets('demande financée (étape finale) : pas de bandeau de rejet', (tester) async {
    await tester.pumpWidget(_buildScreen(_demande(StatutDemande.finance)));
    await tester.pumpAndSettle();

    expect(find.byType(GaStatusTimeline), findsOneWidget);
    expect(find.text('Demande rejetée'), findsNothing);
    expect(find.text('Voir les remboursements'), findsOneWidget);
  });

  testWidgets('demande rejetée : bandeau de rejet à la place de la frise', (tester) async {
    await tester.pumpWidget(_buildScreen(
      _demande(StatutDemande.rejete, commentaireRejet: 'Dossier incomplet'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Demande rejetée'), findsOneWidget);
    expect(find.textContaining('Dossier incomplet'), findsOneWidget);
    expect(find.byType(GaStatusTimeline), findsNothing);
  });

  testWidgets('demande introuvable affiche un message dédié', (tester) async {
    await tester.pumpWidget(_buildScreen(null));
    await tester.pumpAndSettle();

    expect(find.text('Demande introuvable'), findsOneWidget);
  });
}
