import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/models/assurance_model.dart';
import 'package:greenaccess/models/course_model.dart';
import 'package:greenaccess/models/demande_financement_model.dart';
import 'package:greenaccess/models/lecon_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/admin_repository.dart';
import 'package:greenaccess/viewmodels/admin_viewmodel.dart';

// ── Fake AdminRepository ─────────────────────────────────────────────────────

class _FakeAdminRepository extends AdminRepository {
  List<DemandeFinancementModel> demandes = [];
  List<UserModel> users = [];
  List<ContratAssuranceModel> contrats = [];

  // Journaux pour assertions
  final List<String> updatedDemandeStatuts = [];
  final List<Map<String, String>> sentNotifs = [];
  String? lastDemandeStatut;
  String? lastCommentaireRejet;

  _FakeAdminRepository() : super(db: FakeFirebaseFirestore());

  @override
  Future<Map<String, int>> getStats() async =>
      {'users': 0, 'courses': 0, 'demandes': 0, 'contrats': 0, 'enAttente': 0};

  @override
  Future<List<DemandeFinancementModel>> getAllDemandes() async => demandes;

  @override
  Future<List<UserModel>> getAllUsers() async => users;

  @override
  Future<List<ContratAssuranceModel>> getAllContrats() async => contrats;

  @override
  Future<List<CourseModel>> getAllCourses() async => [];

  @override
  Future<void> updateDemandeStatut(
    String demandeId,
    StatutDemande statut, {
    String? commentaire,
  }) async {
    lastDemandeStatut = statut.name;
    lastCommentaireRejet = commentaire;
  }

  @override
  Future<void> sendNotifToUser({
    required String userId,
    required String titre,
    required String message,
    String type = 'info',
  }) async {
    sentNotifs.add({'userId': userId, 'titre': titre, 'type': type, 'message': message});
  }

  @override
  Future<void> updateContratStatut(String contratId, StatutContrat statut) async {}

  @override
  Future<List<LeconModel>> getLecons(String courseId) async => [];
}

// ── Helpers ──────────────────────────────────────────────────────────────────

DemandeFinancementModel _demande({
  String id = 'd1',
  String userId = 'user_42',
  double montant = 250000,
  StatutDemande statut = StatutDemande.soumis,
}) =>
    DemandeFinancementModel(
      id: id,
      userId: userId,
      dateSoumission: DateTime(2025, 1, 15),
      montant: montant,
      typeProjet: 'Maraîchage',
      secteur: 'Agriculture',
      pays: 'Sénégal',
      descriptionProjet: 'Projet irrigué',
      statut: statut,
      scoreEligibilite: 72,
      docsUrl: [],
      alignementTaxonomie: 'Conforme',
    );

ProviderContainer _makeContainer(_FakeAdminRepository repo) {
  return ProviderContainer(
    overrides: [
      adminViewModelProvider.overrideWith((ref) => AdminViewModel(repo)),
    ],
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('AdminViewModel — approuverDemande', () {
    test('envoie une notification de type "success" à l\'utilisateur', () async {
      final repo = _FakeAdminRepository()
        ..demandes = [_demande()]
        ..users = [];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      // Charger les demandes pour peupler l'état
      await container.read(adminViewModelProvider.notifier).loadDemandes();

      await container.read(adminViewModelProvider.notifier).approuverDemande('d1');

      expect(repo.sentNotifs, hasLength(1));
      final notif = repo.sentNotifs.first;
      expect(notif['userId'], 'user_42');
      expect(notif['type'], 'success');
      expect(repo.lastDemandeStatut, 'approuve');
    });

    test('le message contient le montant de la demande', () async {
      final repo = _FakeAdminRepository()
        ..demandes = [_demande(montant: 500000)]
        ..users = [];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(adminViewModelProvider.notifier).loadDemandes();
      await container.read(adminViewModelProvider.notifier).approuverDemande('d1');

      expect(repo.sentNotifs.first['message'], contains('500000'));
    });

    test('successMessage mis à jour dans l\'état', () async {
      final repo = _FakeAdminRepository()
        ..demandes = [_demande()]
        ..users = [];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(adminViewModelProvider.notifier).loadDemandes();
      await container.read(adminViewModelProvider.notifier).approuverDemande('d1');

      expect(container.read(adminViewModelProvider).successMessage, 'Demande approuvée');
    });
  });

  group('AdminViewModel — rejeterDemande', () {
    test('envoie une notification de type "warning" avec le motif', () async {
      final repo = _FakeAdminRepository()
        ..demandes = [_demande()]
        ..users = [];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(adminViewModelProvider.notifier).loadDemandes();
      await container
          .read(adminViewModelProvider.notifier)
          .rejeterDemande('d1', 'Dossier incomplet');

      expect(repo.sentNotifs, hasLength(1));
      final notif = repo.sentNotifs.first;
      expect(notif['type'], 'warning');
      expect(notif['message'], contains('Dossier incomplet'));
      expect(repo.lastDemandeStatut, 'rejete');
      expect(repo.lastCommentaireRejet, 'Dossier incomplet');
    });

    test('le message contient le montant de la demande rejetée', () async {
      final repo = _FakeAdminRepository()
        ..demandes = [_demande(montant: 150000)]
        ..users = [];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(adminViewModelProvider.notifier).loadDemandes();
      await container
          .read(adminViewModelProvider.notifier)
          .rejeterDemande('d1', 'Risque élevé');

      expect(repo.sentNotifs.first['message'], contains('150000'));
    });

    test('pas de notification si la demande n\'existe pas dans l\'état', () async {
      final repo = _FakeAdminRepository()..demandes = []..users = [];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(adminViewModelProvider.notifier).loadDemandes();
      await container
          .read(adminViewModelProvider.notifier)
          .rejeterDemande('inexistant', 'Motif');

      // Aucune notif envoyée car demande introuvable dans l'état
      expect(repo.sentNotifs, isEmpty);
    });
  });

  group('AdminViewModel — loadDemandes', () {
    test('charge demandes ET users en parallèle', () async {
      final user = UserModel(
        id: 'user_42',
        nom: 'Kofi Mensah',
        email: 'kofi@example.com',
        telephone: '+221777777777',
        pays: 'Sénégal',
        region: 'Dakar',
        secteur: 'Agriculture',
        dateInscription: DateTime(2024),
        profilComplet: true,
        role: UserRole.user,
      );

      final repo = _FakeAdminRepository()
        ..demandes = [_demande()]
        ..users = [user];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(adminViewModelProvider.notifier).loadDemandes();
      final state = container.read(adminViewModelProvider);

      expect(state.demandes, hasLength(1));
      expect(state.users, hasLength(1));
      expect(state.users.first.nom, 'Kofi Mensah');
    });
  });
}
