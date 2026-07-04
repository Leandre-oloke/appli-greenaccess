import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assurance_model.dart';
import '../models/course_model.dart';
import '../models/lecon_model.dart';
import '../models/user_model.dart';
import '../models/demande_financement_model.dart';

class AdminRepository {
  final FirebaseFirestore _db;
  AdminRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  // ── Stats ──────────────────────────────────────────────────────────────────

  Future<Map<String, int>> getStats() async {
    final results = await Future.wait([
      _db.collection('users').count().get(),
      _db.collection('courses').count().get(),
      _db.collection('demandes_financement').count().get(),
      _db.collection('contrats_assurance').count().get(),
      _db.collection('demandes_financement')
          .where('statut', isEqualTo: 'soumis').count().get(),
    ]);
    return {
      'users':    results[0].count ?? 0,
      'courses':  results[1].count ?? 0,
      'demandes': results[2].count ?? 0,
      'contrats': results[3].count ?? 0,
      'enAttente': results[4].count ?? 0,
    };
  }

  // ── Formations ─────────────────────────────────────────────────────────────

  Future<List<CourseModel>> getAllCourses() async {
    // Pas de orderBy pour éviter l'exigence d'un index Firestore composite.
    final snap = await _db.collection('courses').get();
    final courses = snap.docs
        .map((d) => CourseModel.fromFirestore(d.data(), d.id))
        .toList();
    courses.sort((a, b) => a.titre.compareTo(b.titre));
    return courses;
  }

  Future<void> saveCourse(CourseModel course, {bool isNew = false}) async {
    final data = {
      'titre': course.titre,
      'theme': course.theme,
      'description': course.description,
      'objectifs': course.objectifs,
      'type': course.type.name,
      'url_video': course.urlVideo,
      'url_pdf': course.urlPdf,
      'duree_min': course.dureeMin,
      'points_xp': course.pointsXp,
      'niveau_requis': course.niveauRequis,
      'nb_quiz': course.nbQuiz,
      'actif': course.actif,
    };
    if (isNew) {
      await _db.collection('courses').add(data);
    } else {
      await _db.collection('courses').doc(course.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> toggleCourseActif(String id, bool actif) async {
    await _db.collection('courses').doc(id).update({'actif': actif});
  }

  Future<void> deleteCourse(String id) async {
    await _db.collection('courses').doc(id).delete();
  }

  // ── Utilisateurs ───────────────────────────────────────────────────────────

  Future<List<UserModel>> getAllUsers() async {
    final snap = await _db.collection('users').get();
    final users = snap.docs
        .map((d) => UserModel.fromFirestore(d.data(), d.id))
        .toList();
    users.sort((a, b) => b.dateInscription.compareTo(a.dateInscription));
    return users;
  }

  Future<void> updateUserRole(String userId, UserRole role) async {
    await _db.collection('users').doc(userId).update({'role': role.name});
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  // ── Demandes de financement ────────────────────────────────────────────────

  Future<List<DemandeFinancementModel>> getAllDemandes() async {
    final snap = await _db.collection('demandes_financement').get();
    final demandes = snap.docs
        .map((d) => DemandeFinancementModel.fromFirestore(d.data(), d.id))
        .toList();
    demandes.sort((a, b) => b.dateSoumission.compareTo(a.dateSoumission));
    return demandes;
  }

  Future<void> updateDemandeStatut(
    String demandeId,
    StatutDemande statut, {
    String? commentaire,
  }) async {
    await _db.collection('demandes_financement').doc(demandeId).update({
      'statut': statut.name,
      if (commentaire != null) 'commentaire_rejet': commentaire,
    });
  }

  // ── Leçons ─────────────────────────────────────────────────────────────────

  Future<List<LeconModel>> getLecons(String courseId) async {
    final snap = await _db
        .collection('courses')
        .doc(courseId)
        .collection('lecons')
        .orderBy('ordre')
        .get();
    return snap.docs
        .map((d) => LeconModel.fromFirestore(d.data(), d.id))
        .toList();
  }

  Future<void> saveLecon(
    String courseId,
    LeconModel lecon, {
    bool isNew = false,
  }) async {
    final col = _db.collection('courses').doc(courseId).collection('lecons');
    if (isNew) {
      await col.add(lecon.toFirestore());
    } else {
      await col.doc(lecon.id).set(lecon.toFirestore(), SetOptions(merge: true));
    }
  }

  Future<void> deleteLecon(String courseId, String leconId) async {
    await _db
        .collection('courses')
        .doc(courseId)
        .collection('lecons')
        .doc(leconId)
        .delete();
  }

  // ── Contrats assurance ─────────────────────────────────────────────────────

  Future<List<ContratAssuranceModel>> getAllContrats() async {
    final snap = await _db.collection('contrats_assurance').get();
    final contrats = <ContratAssuranceModel>[];
    for (final doc in snap.docs) {
      try {
        contrats.add(ContratAssuranceModel.fromFirestore(doc.data(), doc.id));
      } catch (_) {
        // Document malformé ignoré — on ne bloque pas toute la liste
      }
    }
    contrats.sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
    return contrats;
  }

  Future<void> updateContratStatut(String contratId, StatutContrat statut) async {
    await _db.collection('contrats_assurance').doc(contratId).update({
      'statut': statut.name,
    });
  }

  /// Envoie une notification personnelle dans users/{userId}/notifications/.
  Future<void> sendNotifToUser({
    required String userId,
    required String titre,
    required String message,
    String type = 'info',
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'titre': titre,
      'message': message,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
