import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assurance_model.dart';
import '../models/course_model.dart';
import '../models/lecon_model.dart';
import '../models/user_model.dart';
import '../models/demande_financement_model.dart';
import '../repositories/admin_repository.dart';

class AdminState {
  final Map<String, int> stats;
  final Map<String, dynamic> analytics;
  final List<CourseModel> courses;
  final List<UserModel> users;
  final List<DemandeFinancementModel> demandes;
  final List<LeconModel> lecons;
  final List<ContratAssuranceModel> contrats;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const AdminState({
    this.stats = const {},
    this.analytics = const {},
    this.courses = const [],
    this.users = const [],
    this.demandes = const [],
    this.lecons = const [],
    this.contrats = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  AdminState copyWith({
    Map<String, int>? stats,
    Map<String, dynamic>? analytics,
    List<CourseModel>? courses,
    List<UserModel>? users,
    List<DemandeFinancementModel>? demandes,
    List<LeconModel>? lecons,
    List<ContratAssuranceModel>? contrats,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) => AdminState(
    stats: stats ?? this.stats,
    analytics: analytics ?? this.analytics,
    courses: courses ?? this.courses,
    users: users ?? this.users,
    demandes: demandes ?? this.demandes,
    lecons: lecons ?? this.lecons,
    contrats: contrats ?? this.contrats,
    isLoading: isLoading ?? this.isLoading,
    error: error,
    successMessage: successMessage,
  );
}

class AdminViewModel extends StateNotifier<AdminState> {
  final AdminRepository _repo;
  AdminViewModel(this._repo) : super(const AdminState());

  // ── Chargements ────────────────────────────────────────────────────────────

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true);
    try {
      final stats = await _repo.getStats();
      state = state.copyWith(stats: stats, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAnalytics() async {
    state = state.copyWith(isLoading: true);
    try {
      final analytics = await _repo.getAnalytics();
      state = state.copyWith(analytics: analytics, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadCourses() async {
    state = state.copyWith(isLoading: true);
    try {
      final courses = await _repo.getAllCourses();
      state = state.copyWith(courses: courses, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true);
    try {
      final users = await _repo.getAllUsers();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadDemandes() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _repo.getAllDemandes(),
        _repo.getAllUsers(),
      ]);
      state = state.copyWith(
        demandes: results[0] as List<DemandeFinancementModel>,
        users: results[1] as List<UserModel>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Formations ─────────────────────────────────────────────────────────────

  Future<void> saveCourse(CourseModel course, {bool isNew = false}) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.saveCourse(course, isNew: isNew);
      await loadCourses();
      state = state.copyWith(
        isLoading: false,
        successMessage: isNew ? 'Cours créé avec succès' : 'Cours mis à jour',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleCourse(String id, bool actif) async {
    try {
      await _repo.toggleCourseActif(id, actif);
      await loadCourses();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Impossible de modifier le cours : ${_msg(e)}');
    }
  }

  Future<void> deleteCourse(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.deleteCourse(id);
      // Mise à jour optimiste : retire le cours localement même si le rechargement échoue.
      List<CourseModel> updated;
      try {
        updated = await _repo.getAllCourses();
      } catch (_) {
        updated = state.courses.where((c) => c.id != id).toList();
      }
      state = state.copyWith(courses: updated, isLoading: false, successMessage: 'Cours supprimé');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Impossible de supprimer : ${_msg(e)}');
    }
  }

  // ── Utilisateurs ───────────────────────────────────────────────────────────

  Future<void> changeUserRole(String userId, UserRole role) async {
    try {
      await _repo.updateUserRole(userId, role);
      await loadUsers();
      state = state.copyWith(successMessage: 'Rôle mis à jour');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Impossible de modifier le rôle : ${_msg(e)}');
    }
  }

  Future<void> deleteUser(String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.deleteUser(userId);
      await loadUsers();
      state = state.copyWith(isLoading: false, successMessage: 'Utilisateur supprimé');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Impossible de supprimer : ${_msg(e)}');
    }
  }

  // ── Leçons ─────────────────────────────────────────────────────────────────

  Future<void> loadLecons(String courseId) async {
    state = state.copyWith(isLoading: true);
    try {
      final lecons = await _repo.getLecons(courseId);
      state = state.copyWith(lecons: lecons, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> saveLecon(
    String courseId,
    LeconModel lecon, {
    bool isNew = false,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.saveLecon(courseId, lecon, isNew: isNew);
      await loadLecons(courseId);
      state = state.copyWith(
        isLoading: false,
        successMessage: isNew ? 'Leçon créée' : 'Leçon mise à jour',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> deleteLecon(String courseId, String leconId) async {
    try {
      await _repo.deleteLecon(courseId, leconId);
      await loadLecons(courseId);
      state = state.copyWith(successMessage: 'Leçon supprimée');
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  // ── Contrats ───────────────────────────────────────────────────────────────

  Future<void> loadContrats() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _repo.getAllContrats(),
        _repo.getAllUsers(),
      ]);
      state = state.copyWith(
        contrats: results[0] as List<ContratAssuranceModel>,
        users: results[1] as List<UserModel>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> updateContratStatut(String contratId, StatutContrat statut) async {
    try {
      final contrat = state.contrats.where((c) => c.id == contratId).firstOrNull;
      await _repo.updateContratStatut(contratId, statut);
      if (contrat != null) {
        await _repo.sendNotifToUser(
          userId: contrat.userId,
          titre: _contratNotifTitre(statut),
          message: _contratNotifMessage(statut, contrat.zoneRisque),
          type: _contratNotifType(statut),
        );
      }
      await loadContrats();
      state = state.copyWith(successMessage: 'Statut mis à jour');
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  String _contratNotifTitre(StatutContrat s) => switch (s) {
    StatutContrat.actif    => 'Contrat activé ✅',
    StatutContrat.expire   => 'Contrat expiré',
    StatutContrat.sinistre => 'Sinistre en traitement',
    StatutContrat.soumis   => 'Contrat soumis',
  };

  String _contratNotifMessage(StatutContrat s, String zone) => switch (s) {
    StatutContrat.actif    =>
      'Votre contrat d\'assurance (zone : $zone) est maintenant actif. '
      'Vous êtes protégé contre les aléas climatiques.',
    StatutContrat.expire   =>
      'Votre contrat d\'assurance (zone : $zone) a expiré.',
    StatutContrat.sinistre =>
      'Votre déclaration de sinistre (zone : $zone) est en cours de traitement par votre assureur.',
    StatutContrat.soumis   =>
      'Votre dossier de souscription (zone : $zone) a été soumis et est en attente de validation.',
  };

  String _contratNotifType(StatutContrat s) => switch (s) {
    StatutContrat.actif    => 'success',
    StatutContrat.expire   => 'warning',
    StatutContrat.sinistre => 'alert',
    StatutContrat.soumis   => 'info',
  };

  // ── Demandes ───────────────────────────────────────────────────────────────

  Future<void> approuverDemande(String id) async {
    try {
      final demande = state.demandes.where((d) => d.id == id).firstOrNull;
      await _repo.updateDemandeStatut(id, StatutDemande.approuve);
      if (demande != null) {
        await _repo.sendNotifToUser(
          userId: demande.userId,
          titre: 'Demande approuvée ✅',
          message:
              'Votre demande de financement (${demande.montant.toStringAsFixed(0)} FCFA) '
              'a été approuvée. Un partenaire prendra contact avec vous.',
          type: 'success',
        );
      }
      await loadDemandes();
      state = state.copyWith(successMessage: 'Demande approuvée');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur : ${_msg(e)}');
    }
  }

  Future<void> rejeterDemande(String id, String commentaire) async {
    try {
      final demande = state.demandes.where((d) => d.id == id).firstOrNull;
      await _repo.updateDemandeStatut(id, StatutDemande.rejete, commentaire: commentaire);
      if (demande != null) {
        await _repo.sendNotifToUser(
          userId: demande.userId,
          titre: 'Demande non retenue',
          message:
              'Votre demande de financement (${demande.montant.toStringAsFixed(0)} FCFA) '
              'n\'a pas été retenue. Motif : $commentaire',
          type: 'warning',
        );
      }
      await loadDemandes();
      state = state.copyWith(successMessage: 'Demande rejetée');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur : ${_msg(e)}');
    }
  }

  void clearMessages() => state = state.copyWith();

  String _msg(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied')) return 'Permission refusée (vérifiez les règles Firestore)';
    if (s.contains('network') || s.contains('unavailable')) return 'Erreur réseau';
    if (s.contains('not-found')) return 'Document introuvable';
    return 'Erreur : $s';
  }
}

final adminViewModelProvider =
    StateNotifierProvider<AdminViewModel, AdminState>(
  (ref) => AdminViewModel(AdminRepository()),
);
