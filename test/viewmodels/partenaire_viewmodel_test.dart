// Tests unitaires de PartenaireViewModel (J2.25) — même style que
// assurance_viewmodel_test.dart : un fake PartenaireRepository injecté via
// ProviderContainer.overrides, sans Firebase réel.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/models/partenaire_model.dart';
import 'package:greenaccess/repositories/partenaire_repository.dart';
import 'package:greenaccess/viewmodels/partenaire_viewmodel.dart';

// ── Fake PartenaireRepository ────────────────────────────────────────────────

class _FakePartenaireRepository extends PartenaireRepository {
  _FakePartenaireRepository() : super(firestore: FakeFirebaseFirestore());

  List<PartenaireModel> fetchAllToReturn = [];
  Object? fetchAllError;

  PartenaireModel? createReturn;
  Object? createError;
  Object? updateError;
  Object? deleteError;
  Object? toggleActifError;

  PartenaireModel? lastCreated;
  PartenaireModel? lastUpdated;
  String? lastDeletedId;
  ({String id, bool actif})? lastToggle;

  @override
  Future<List<PartenaireModel>> fetchAll() async {
    if (fetchAllError != null) throw fetchAllError!;
    return fetchAllToReturn;
  }

  @override
  Future<PartenaireModel> create(PartenaireModel p) async {
    lastCreated = p;
    if (createError != null) throw createError!;
    return createReturn ?? p;
  }

  @override
  Future<void> update(PartenaireModel p) async {
    lastUpdated = p;
    if (updateError != null) throw updateError!;
  }

  @override
  Future<void> delete(String id) async {
    lastDeletedId = id;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<void> toggleActif(String id, bool actif) async {
    lastToggle = (id: id, actif: actif);
    if (toggleActifError != null) throw toggleActifError!;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

PartenaireModel _partenaire({
  String id = 'p1',
  String nom = 'AFD',
  bool actif = true,
}) =>
    PartenaireModel(
      id: id,
      nom: nom,
      type: 'bailleur',
      description: 'Agence Française de Développement',
      contact: 'contact@afd.example',
      pays: const ['Sénégal', 'Côte d\'Ivoire'],
      montantMin: 500000,
      montantMax: 50000000,
      actif: actif,
    );

ProviderContainer _makeContainer(_FakePartenaireRepository repo) {
  return ProviderContainer(
    overrides: [
      partenaireViewModelProvider.overrideWith((ref) => PartenaireViewModel(repo)),
    ],
  );
}

void main() {
  group('PartenaireViewModel — load', () {
    test('succès : partenaires chargés, isLoading repasse à false', () async {
      final repo = _FakePartenaireRepository()
        ..fetchAllToReturn = [_partenaire(id: 'p1'), _partenaire(id: 'p2', nom: 'BOAD')];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).load();
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires, hasLength(2));
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('échec : error renseigné, isLoading repasse à false, liste vide conservée', () async {
      final repo = _FakePartenaireRepository()..fetchAllError = Exception('Firestore indisponible');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).load();
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, contains('Firestore indisponible'));
    });
  });

  group('PartenaireViewModel — create', () {
    test('succès : le partenaire créé est ajouté à la liste existante', () async {
      final repo = _FakePartenaireRepository()
        ..createReturn = _partenaire(id: 'p_created', nom: 'GCF');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).load();
      await container.read(partenaireViewModelProvider.notifier).create(_partenaire(id: 'ignored'));
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires.map((p) => p.id), contains('p_created'));
      expect(repo.lastCreated?.id, 'ignored'); // ce qui a été transmis au repo
    });

    test('échec : error renseigné, liste inchangée', () async {
      final repo = _FakePartenaireRepository()..createError = Exception('Nom déjà utilisé');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).create(_partenaire());
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires, isEmpty);
      expect(state.error, contains('Nom déjà utilisé'));
    });
  });

  group('PartenaireViewModel — update', () {
    test('succès : le partenaire modifié remplace l\'ancien dans la liste', () async {
      final repo = _FakePartenaireRepository()..fetchAllToReturn = [_partenaire(id: 'p1', nom: 'AFD')];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).load();
      await container
          .read(partenaireViewModelProvider.notifier)
          .update(_partenaire(id: 'p1', nom: 'AFD (renommé)'));
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires, hasLength(1));
      expect(state.partenaires.first.nom, 'AFD (renommé)');
    });

    test('échec : error renseigné, liste inchangée', () async {
      final repo = _FakePartenaireRepository()
        ..fetchAllToReturn = [_partenaire(id: 'p1')]
        ..updateError = Exception('Conflit de version');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).load();
      await container.read(partenaireViewModelProvider.notifier).update(_partenaire(id: 'p1', nom: 'X'));
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires.first.nom, 'AFD'); // pas remplacé
      expect(state.error, contains('Conflit de version'));
    });
  });

  group('PartenaireViewModel — delete', () {
    test('succès : le partenaire est retiré de la liste', () async {
      final repo = _FakePartenaireRepository()
        ..fetchAllToReturn = [_partenaire(id: 'p1'), _partenaire(id: 'p2')];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).load();
      await container.read(partenaireViewModelProvider.notifier).delete('p1');
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires.map((p) => p.id), ['p2']);
    });

    test('échec : error renseigné, liste inchangée', () async {
      final repo = _FakePartenaireRepository()
        ..fetchAllToReturn = [_partenaire(id: 'p1')]
        ..deleteError = Exception('Partenaire référencé par une demande active');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).load();
      await container.read(partenaireViewModelProvider.notifier).delete('p1');
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires, hasLength(1)); // pas retiré
      expect(state.error, contains('référencé'));
    });
  });

  group('PartenaireViewModel — toggleActif', () {
    test('succès : le champ actif est mis à jour localement sans recharger', () async {
      final repo = _FakePartenaireRepository()
        ..fetchAllToReturn = [_partenaire(id: 'p1', actif: true)];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).load();
      await container.read(partenaireViewModelProvider.notifier).toggleActif('p1', false);
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires.first.actif, isFalse);
      expect(repo.lastToggle, (id: 'p1', actif: false));
    });

    test('échec : error renseigné, valeur locale inchangée', () async {
      final repo = _FakePartenaireRepository()
        ..fetchAllToReturn = [_partenaire(id: 'p1', actif: true)]
        ..toggleActifError = Exception('Réseau indisponible');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(partenaireViewModelProvider.notifier).load();
      await container.read(partenaireViewModelProvider.notifier).toggleActif('p1', false);
      final state = container.read(partenaireViewModelProvider);

      expect(state.partenaires.first.actif, isTrue); // pas basculé
      expect(state.error, contains('Réseau indisponible'));
    });
  });
}
