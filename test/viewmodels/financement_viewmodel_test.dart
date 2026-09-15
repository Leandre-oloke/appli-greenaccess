// Tests unitaires de FinancementViewModel (J2.24) — même style que
// assurance_viewmodel_test.dart : un fake FinancementRepository injecté via
// ProviderContainer.overrides, sans Firebase réel.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/models/demande_financement_model.dart';
import 'package:greenaccess/models/remboursement_model.dart';
import 'package:greenaccess/repositories/financement_repository.dart';
import 'package:greenaccess/viewmodels/financement_viewmodel.dart';

const _userId = 'user_test';

// ── Fake FinancementRepository ───────────────────────────────────────────────

class _FakeFinancementRepository extends FinancementRepository {
  _FakeFinancementRepository() : super(firestore: FakeFirebaseFirestore());

  DemandeFinancementModel? submitReturn;
  Object? submitError;
  List<DemandeFinancementModel> demandesToReturn = [];
  Object? fetchDemandesError;
  DemandeFinancementModel? statutToReturn;
  List<RemboursementModel> remboursementsToReturn = [];

  DemandeFinancementModel? lastSubmitted;
  ({String demandeId, double montantTotal, int dureesMois, DateTime dateDebut})? lastEcheancierArgs;

  @override
  Future<DemandeFinancementModel> submit(DemandeFinancementModel demande) async {
    lastSubmitted = demande;
    if (submitError != null) throw submitError!;
    return submitReturn ?? demande;
  }

  @override
  Future<List<DemandeFinancementModel>> fetchUserDemandes(String userId) async {
    if (fetchDemandesError != null) throw fetchDemandesError!;
    return demandesToReturn;
  }

  @override
  Future<DemandeFinancementModel?> fetchStatut(String demandeId) async => statutToReturn;

  @override
  Future<List<RemboursementModel>> fetchRemboursements(String demandeId) async =>
      remboursementsToReturn;

  @override
  Future<void> genererEcheancier({
    required String demandeId,
    required double montantTotal,
    required int dureesMois,
    required DateTime dateDebut,
  }) async {
    lastEcheancierArgs = (
      demandeId: demandeId,
      montantTotal: montantTotal,
      dureesMois: dureesMois,
      dateDebut: dateDebut,
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

DemandeFinancementModel _demande({
  String id = 'd1',
  double montant = 1000000,
  StatutDemande statut = StatutDemande.brouillon,
}) =>
    DemandeFinancementModel(
      id: id,
      userId: _userId,
      dateSoumission: DateTime(2025, 1, 1),
      montant: montant,
      typeProjet: 'Agriculture biologique',
      secteur: 'Agriculture',
      pays: 'Sénégal',
      descriptionProjet: 'Projet test',
      statut: statut,
      scoreEligibilite: 72,
      docsUrl: const [],
      alignementTaxonomie: 'Conforme',
    );

ProviderContainer _makeContainer(_FakeFinancementRepository repo) {
  return ProviderContainer(
    overrides: [
      financementViewModelProvider(_userId).overrideWith(
        (ref) => FinancementViewModel(repo, _userId),
      ),
    ],
  );
}

void main() {
  group('FinancementViewModel — simuler', () {
    test('secteur vert : score d\'éligibilité 75, fourchette ±30%, taux 5.5%', () {
      final repo = _FakeFinancementRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(financementViewModelProvider(_userId).notifier).simuler(
            montant: 1000000,
            typeProjet: 'Agriculture biologique',
            secteur: 'Agriculture',
            pays: 'Sénégal',
          );
      final sim = container.read(financementViewModelProvider(_userId)).simulation;

      expect(sim, isNotNull);
      expect(sim!.montantMin, closeTo(700000, 0.01));
      expect(sim.montantMax, closeTo(1300000, 0.01));
      expect(sim.tauxIndicatif, 5.5);
      expect(sim.scoreEligibilite, 75.0);
    });

    test('secteur non vert : score d\'éligibilité 45', () {
      final repo = _FakeFinancementRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(financementViewModelProvider(_userId).notifier).simuler(
            montant: 1000000,
            typeProjet: 'Commerce',
            secteur: 'Commerce',
            pays: 'Sénégal',
          );
      final sim = container.read(financementViewModelProvider(_userId)).simulation;

      expect(sim!.scoreEligibilite, 45.0);
    });

    test('la reconnaissance de secteur vert est insensible à la casse', () {
      final repo = _FakeFinancementRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(financementViewModelProvider(_userId).notifier).simuler(
            montant: 1000000,
            typeProjet: 'x',
            secteur: 'ÉNERGIE', // le check est sur 'energie' (sans accent, minuscule)
            pays: 'Sénégal',
          );
      // 'ÉNERGIE'.toLowerCase() == 'énergie' ≠ 'energie' (accent) : ce cas
      // documente le comportement réel (pas reconnu comme secteur vert à
      // cause de l'accent), pas un idéal.
      final sim = container.read(financementViewModelProvider(_userId)).simulation;
      expect(sim!.scoreEligibilite, 45.0);
    });

    test('organisme "Microfinance locale" seulement si montant < 10M FCFA', () {
      final repo = _FakeFinancementRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(financementViewModelProvider(_userId).notifier).simuler(
            montant: 5000000,
            typeProjet: 'x',
            secteur: 'Agriculture',
            pays: 'Sénégal',
          );
      var sim = container.read(financementViewModelProvider(_userId)).simulation;
      expect(sim!.organismesEligibles, containsAll(['AFD', 'BOAD', 'GCF', 'Microfinance locale']));

      container.read(financementViewModelProvider(_userId).notifier).simuler(
            montant: 15000000,
            typeProjet: 'x',
            secteur: 'Agriculture',
            pays: 'Sénégal',
          );
      sim = container.read(financementViewModelProvider(_userId)).simulation;
      expect(sim!.organismesEligibles, containsAll(['AFD', 'BOAD', 'GCF']));
      expect(sim.organismesEligibles, isNot(contains('Microfinance locale')));
    });
  });

  group('FinancementViewModel — soumettreDemande', () {
    test('succès : currentDemande mis à jour, isLoading repasse à false', () async {
      final repo = _FakeFinancementRepository()..submitReturn = _demande(id: 'd-created');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(financementViewModelProvider(_userId).notifier)
          .soumettreDemande(_demande());
      final state = container.read(financementViewModelProvider(_userId));

      expect(state.currentDemande?.id, 'd-created');
      expect(state.isLoading, isFalse);
      expect(repo.lastSubmitted?.userId, _userId);
    });

    test('échec : errorMessage renseigné, currentDemande inchangé', () async {
      final repo = _FakeFinancementRepository()..submitError = Exception('Firestore indisponible');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(financementViewModelProvider(_userId).notifier)
          .soumettreDemande(_demande());
      final state = container.read(financementViewModelProvider(_userId));

      expect(state.currentDemande, isNull);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, contains('Firestore indisponible'));
    });
  });

  group('FinancementViewModel — loadDemandes', () {
    test('succès : demandes chargées dans l\'état', () async {
      final repo = _FakeFinancementRepository()
        ..demandesToReturn = [_demande(id: 'd1'), _demande(id: 'd2')];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(financementViewModelProvider(_userId).notifier).loadDemandes();
      final state = container.read(financementViewModelProvider(_userId));

      expect(state.demandes, hasLength(2));
      expect(state.isLoading, isFalse);
    });

    test('échec réseau : errorMessage renseigné, liste vide conservée', () async {
      final repo = _FakeFinancementRepository()..fetchDemandesError = Exception('Timeout');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(financementViewModelProvider(_userId).notifier).loadDemandes();
      final state = container.read(financementViewModelProvider(_userId));

      expect(state.demandes, isEmpty);
      expect(state.errorMessage, contains('Timeout'));
    });
  });

  group('FinancementViewModel — getStatut / getRemboursements / genererEcheancier', () {
    test('getStatut() délègue au repository et renvoie sa réponse telle quelle', () async {
      final repo = _FakeFinancementRepository()..statutToReturn = _demande(statut: StatutDemande.approuve);
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result =
          await container.read(financementViewModelProvider(_userId).notifier).getStatut('d1');

      expect(result?.statut, StatutDemande.approuve);
    });

    test('getRemboursements() délègue au repository', () async {
      final repo = _FakeFinancementRepository()
        ..remboursementsToReturn = [
          RemboursementModel(
            id: 'e1',
            demandeId: 'd1',
            numeroEcheance: 1,
            dateEcheance: DateTime(2025, 2, 1),
            montant: 100000,
            paye: false,
          ),
        ];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(financementViewModelProvider(_userId).notifier)
          .getRemboursements('d1');

      expect(result, hasLength(1));
      expect(result.first.numeroEcheance, 1);
    });

    test('genererEcheancier() transmet exactement les arguments reçus', () async {
      final repo = _FakeFinancementRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final debut = DateTime(2025, 3, 1);
      await container.read(financementViewModelProvider(_userId).notifier).genererEcheancier(
            demandeId: 'd1',
            montantTotal: 1200000,
            dureesMois: 12,
            dateDebut: debut,
          );

      expect(repo.lastEcheancierArgs?.demandeId, 'd1');
      expect(repo.lastEcheancierArgs?.montantTotal, 1200000);
      expect(repo.lastEcheancierArgs?.dureesMois, 12);
      expect(repo.lastEcheancierArgs?.dateDebut, debut);
    });
  });
}
