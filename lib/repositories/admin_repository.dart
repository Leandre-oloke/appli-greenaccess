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

  /// Données agrégées pour l'écran Analytics admin.
  Future<Map<String, dynamic>> getAnalytics() async {
    final results = await Future.wait([
      // Scores climat — moyenne et répartition par niveau
      _db.collection('scores_climat').get(),
      // Demandes par statut
      _db.collection('demandes_financement').get(),
      // Contrats actifs
      _db.collection('contrats_assurance').where('statut', isEqualTo: 'actif').count().get(),
      // Formations complétées (progress docs)
      _db.collectionGroup('progress').where('statut', isEqualTo: 'TERMINE').count().get(),
      // Utilisateurs par rôle
      _db.collection('users').get(),
    ]);

    final scoresDocs = (results[0] as QuerySnapshot).docs;
    double scoreMoyen = 0;
    final Map<String, int> scoresParNiveau = {'excellent': 0, 'bon': 0, 'intermediaire': 0, 'insuffisant': 0};
    if (scoresDocs.isNotEmpty) {
      double total = 0;
      for (final doc in scoresDocs) {
        final d = doc.data() as Map<String, dynamic>;
        total += (d['scoreTotal'] as num? ?? 0).toDouble();
        final niveau = d['niveau'] as String? ?? 'insuffisant';
        scoresParNiveau[niveau] = (scoresParNiveau[niveau] ?? 0) + 1;
      }
      scoreMoyen = total / scoresDocs.length;
    }

    final demandesDocs = (results[1] as QuerySnapshot).docs;
    final Map<String, int> demandesParStatut = {};
    for (final doc in demandesDocs) {
      final statut = (doc.data() as Map<String, dynamic>)['statut'] as String? ?? 'brouillon';
      demandesParStatut[statut] = (demandesParStatut[statut] ?? 0) + 1;
    }

    final usersDocs = (results[4] as QuerySnapshot).docs;
    final Map<String, int> usersParRole = {};
    for (final doc in usersDocs) {
      final role = (doc.data() as Map<String, dynamic>)['role'] as String? ?? 'user';
      usersParRole[role] = (usersParRole[role] ?? 0) + 1;
    }

    return {
      'scoreMoyen': scoreMoyen,
      'totalScores': scoresDocs.length,
      'scoresParNiveau': scoresParNiveau,
      'demandesParStatut': demandesParStatut,
      'contratsActifs': (results[2] as AggregateQuerySnapshot).count ?? 0,
      'formationsCompletees': (results[3] as AggregateQuerySnapshot).count ?? 0,
      'usersParRole': usersParRole,
    };
  }

  Future<Map<String, int>> getStats() async {
    // Chaque comptage échoue indépendamment — on ne bloque pas le dashboard entier.
    Future<int> count(Query q) async {
      try {
        final snap = await q.count().get();
        return snap.count ?? 0;
      } catch (_) {
        return 0;
      }
    }

    final results = await Future.wait([
      count(_db.collection('users')),
      count(_db.collection('courses')),
      count(_db.collection('demandes_financement')),
      count(_db.collection('contrats_assurance')),
      count(_db.collection('sinistres')),
      count(_db.collection('contrats_assurance').where('statut', isEqualTo: 'soumis')),
    ]);
    return {
      'users':              results[0],
      'courses':            results[1],
      'demandes':           results[2],
      'contrats':           results[3],
      'sinistres':          results[4],
      'contratsAVerifier':  results[5],
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
