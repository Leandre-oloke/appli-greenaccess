import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/models/assurance_model.dart';
import 'package:greenaccess/repositories/assurance_repository.dart';
import 'package:greenaccess/viewmodels/assurance_viewmodel.dart';

// ── Fake AssuranceRepository ─────────────────────────────────────────────────

class _FakeAssuranceRepository extends AssuranceRepository {
  List<ContratAssuranceModel> contratsToReturn = [];
  ContratAssuranceModel? contratCreated;
  String? lastUploadedContratId;
  String? lastUploadedNom;
  String? lastAddedUrl;

  _FakeAssuranceRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<ProduitAssuranceModel>> getProduitsParZone(String zone) async => [];

  @override
  Future<List<ProduitAssuranceModel>> getAllProduits() async => [];

  @override
  Future<List<ZoneAleaModel>> getZonesAlea() async => [];

  @override
  Future<ContratAssuranceModel> soumettreDossier(Map<String, dynamic> dossier) async {
    contratCreated = ContratAssuranceModel(
      id: 'contrat_new',
      userId: dossier['userId'] ?? 'user_test',
      produitId: dossier['produit_id'] ?? 'prod1',
      statut: StatutContrat.soumis,
      assureurId: dossier['assureur_id'] ?? 'ASS_01',
      dateDebut: DateTime(2025, 1, 1),
      primeMensuelle: (dossier['prime_mensuelle'] ?? 5000).toDouble(),
      zoneRisque: dossier['zone_risque'] ?? 'Sénégal',
    );
    return contratCreated!;
  }

  @override
  Future<List<ContratAssuranceModel>> getContrats(String userId) async => contratsToReturn;

  @override
  Future<String> uploadDocument({
    required String userId,
    required String contratId,
    required File file,
    required String nomDocument,
  }) async {
    lastUploadedContratId = contratId;
    lastUploadedNom = nomDocument;
    return 'https://storage.example.com/$userId/$contratId/$nomDocument.jpg';
  }

  @override
  Future<void> ajouterDocumentUrl(String contratId, String url) async {
    lastAddedUrl = url;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

ContratAssuranceModel _contrat({
  String id = 'c1',
  StatutContrat statut = StatutContrat.actif,
  DateTime? dateDebut,
}) =>
    ContratAssuranceModel(
      id: id,
      userId: 'user_test',
      produitId: 'prod_1',
      statut: statut,
      assureurId: 'ASS_01',
      dateDebut: dateDebut ?? DateTime(2024, 1, 15),
      primeMensuelle: 8000,
      zoneRisque: 'Sénégal',
    );

ProviderContainer _makeContainer(_FakeAssuranceRepository repo) {
  return ProviderContainer(
    overrides: [
      assuranceViewModelProvider('user_test').overrideWith(
        (ref) => AssuranceViewModel(repo, 'user_test'),
      ),
    ],
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── Calcul échéance 12 mois ──────────────────────────────────────────────
  group('Calcul échéance contrat (12 mois)', () {
    // La logique est dans les widgets ; on la valide ici indépendamment.
    DateTime expiryFor(DateTime debut) =>
        DateTime(debut.year, debut.month + 12, debut.day);

    int daysUntilExpiry(DateTime debut) =>
        expiryFor(debut).difference(DateTime.now()).inDays;

    test('expiration = dateDebut + 12 mois (même jour)', () {
      final debut = DateTime(2024, 3, 15);
      expect(expiryFor(debut), DateTime(2025, 3, 15));
    });

    test('contrat débuté il y a 11 mois expire dans ~30 jours', () {
      final debut = DateTime(
        DateTime.now().year,
        DateTime.now().month - 11,
        DateTime.now().day,
      );
      final jours = daysUntilExpiry(debut);
      // Entre 28 et 33 jours selon le mois
      expect(jours, inInclusiveRange(25, 35));
    });

    test('contrat débuté il y a plus de 12 mois → jours négatifs (expiré)', () {
      final debut = DateTime(2020, 1, 1);
      expect(daysUntilExpiry(debut), isNegative);
    });

    test('alerte activée si actif ET 0 < jours ≤ 30', () {
      bool alerteActive(StatutContrat statut, int jours) =>
          statut == StatutContrat.actif && jours > 0 && jours <= 30;

      expect(alerteActive(StatutContrat.actif, 15), isTrue);
      expect(alerteActive(StatutContrat.actif, 30), isTrue);
      expect(alerteActive(StatutContrat.actif, 31), isFalse);
      expect(alerteActive(StatutContrat.actif, 0), isFalse);
      expect(alerteActive(StatutContrat.soumis, 10), isFalse);
      expect(alerteActive(StatutContrat.expire, 5), isFalse);
    });
  });

  // ── loadContrats ─────────────────────────────────────────────────────────
  group('AssuranceViewModel — loadContrats', () {
    test('contrats chargés et contratActif défini si un contrat est actif', () async {
      final actif = _contrat(statut: StatutContrat.actif);
      final soumis = _contrat(id: 'c2', statut: StatutContrat.soumis);

      final repo = _FakeAssuranceRepository()
        ..contratsToReturn = [soumis, actif];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(assuranceViewModelProvider('user_test').notifier).loadContrats();
      final state = container.read(assuranceViewModelProvider('user_test'));

      expect(state.contrats, hasLength(2));
      expect(state.contratActif?.id, 'c1');
    });

    test('contratActif null si aucun contrat actif', () async {
      final repo = _FakeAssuranceRepository()
        ..contratsToReturn = [_contrat(statut: StatutContrat.soumis)];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(assuranceViewModelProvider('user_test').notifier).loadContrats();
      final state = container.read(assuranceViewModelProvider('user_test'));

      expect(state.contratActif, isNull);
    });
  });

  // ── soumettreSouscription ────────────────────────────────────────────────
  group('AssuranceViewModel — soumettreSouscription', () {
    test('crée le contrat et met contratActif à jour', () async {
      final repo = _FakeAssuranceRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(assuranceViewModelProvider('user_test').notifier)
          .soumettreSouscription({
        'zone_risque': 'Bénin',
        'produit_id': 'prod_2',
        'prime_mensuelle': 6000,
        'type_culture': 'Maïs',
        'superficie': 3.5,
        'assureur_id': 'ASS_01',
        'date_debut': DateTime(2025),
      });

      final state = container.read(assuranceViewModelProvider('user_test'));
      expect(state.contratActif?.id, 'contrat_new');
      expect(state.contratActif?.zoneRisque, 'Bénin');
      expect(state.isLoading, isFalse);
    });
  });

  // ── uploadDocument ───────────────────────────────────────────────────────
  group('AssuranceViewModel — uploadDocument', () {
    test('upload vers Storage et appelle ajouterDocumentUrl', () async {
      final repo = _FakeAssuranceRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      // Fichier temporaire pour le test
      final tmpFile = File(
        '${Directory.systemTemp.path}/test_doc_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tmpFile.writeAsBytes([0xFF, 0xD8]); // en-tête JPEG factice

      final url = await container
          .read(assuranceViewModelProvider('user_test').notifier)
          .uploadDocument(
            contratId: 'contrat_abc',
            file: tmpFile,
            nomDocument: 'piece_identite',
          );

      await tmpFile.delete();

      expect(url, isNotNull);
      expect(url, contains('piece_identite'));
      expect(repo.lastUploadedContratId, 'contrat_abc');
      expect(repo.lastUploadedNom, 'piece_identite');
      expect(repo.lastAddedUrl, url);
    });

    test('retourne null si le repo lève une exception', () async {
      final repo = _ErrorAssuranceRepository();
      final container = ProviderContainer(
        overrides: [
          assuranceViewModelProvider('user_test').overrideWith(
            (ref) => AssuranceViewModel(repo, 'user_test'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final tmpFile = File(
        '${Directory.systemTemp.path}/test_err_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tmpFile.writeAsBytes([0x00]);

      final url = await container
          .read(assuranceViewModelProvider('user_test').notifier)
          .uploadDocument(
            contratId: 'c1',
            file: tmpFile,
            nomDocument: 'doc',
          );

      await tmpFile.delete();

      expect(url, isNull);
      final state = container.read(assuranceViewModelProvider('user_test'));
      expect(state.error, isNotNull);
    });
  });

  // ── simulerPrime ─────────────────────────────────────────────────────────
  group('AssuranceViewModel — simulerPrime', () {
    test('simulation stockée dans l\'état sans appel réseau', () {
      final repo = _FakeAssuranceRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(assuranceViewModelProvider('user_test').notifier).simulerPrime(
            zone: 'Sénégal',
            typeAlea: 'secheresse',
            superficieCultivee: 4.0,
            valeurAssurable: 2000000,
          );

      final state = container.read(assuranceViewModelProvider('user_test'));
      expect(state.simulation, isNotNull);
      // prime ≥ primeMin (5000) × facteur
      expect(state.simulation!.primeEstimee, greaterThan(0));
      // indemnisation = valeur × 0.8
      expect(state.simulation!.indemnisationEstimee, closeTo(1600000, 1));
    });
  });
}

// ── Fake qui lève une exception sur uploadDocument ───────────────────────────

class _ErrorAssuranceRepository extends _FakeAssuranceRepository {
  @override
  Future<String> uploadDocument({
    required String userId,
    required String contratId,
    required File file,
    required String nomDocument,
  }) async {
    throw Exception('Réseau indisponible');
  }
}
