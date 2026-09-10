import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/lecon_model.dart';
import '../models/badge_model.dart';

class CoursRepository {
  final FirebaseFirestore _firestore;

  CoursRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<CourseModel>> fetchAll() async {
    try {
      final snapshot = await _firestore
          .collection('courses')
          .where('actif', isEqualTo: true)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => CourseModel.fromFirestore(doc.data(), doc.id))
            .toList();
      }
    } catch (_) {}
    // Données de démo quand Firestore est vide (avant alimentation)
    return _demoCourses;
  }

  static final _demoCourses = <CourseModel>[
    const CourseModel(
      id: 'demo-1',
      titre: 'Introduction au financement vert',
      theme: 'Finance climatique',
      description: 'Découvrez les mécanismes de financement vert disponibles en Afrique de l\'Ouest et comment y accéder.',
      objectifs: ['Comprendre la taxonomie UEMOA verte', 'Identifier les bailleurs de fonds', 'Préparer un dossier de financement'],
      type: CourseType.video,
      dureeMin: 20,
      pointsXp: 50,
      niveauRequis: 0,
      nbQuiz: 5,
      actif: true,
    ),
    const CourseModel(
      id: 'demo-2',
      titre: 'Score Climat ESG : comment l\'améliorer ?',
      theme: 'Scoring',
      description: 'Maîtrisez les critères ESG et apprenez à maximiser votre score pour accéder au financement.',
      objectifs: ['Connaître les 5 critères du score', 'Réduire son empreinte CO₂', 'Obtenir des certifications'],
      type: CourseType.quiz,
      dureeMin: 15,
      pointsXp: 40,
      niveauRequis: 0,
      nbQuiz: 8,
      actif: true,
    ),
    const CourseModel(
      id: 'demo-3',
      titre: 'Agriculture résiliente au changement climatique',
      theme: 'Agronomie climatique',
      description: 'Techniques et pratiques pour adapter votre exploitation agricole aux aléas climatiques.',
      objectifs: ['Techniques d\'irrigation adaptées', 'Cultures résistantes à la sécheresse', 'Gestion des sols'],
      type: CourseType.pdf,
      dureeMin: 30,
      pointsXp: 60,
      niveauRequis: 1,
      nbQuiz: 6,
      actif: true,
    ),
    const CourseModel(
      id: 'demo-4',
      titre: 'Assurance indicielle : protéger son exploitation',
      theme: 'Assurance climatique',
      description: 'Comprenez le fonctionnement de l\'assurance indicielle et comment elle protège contre les aléas climatiques.',
      objectifs: ['Principe de l\'indice de déclenchement', 'Choisir un produit adapté', 'Déclarer un sinistre'],
      type: CourseType.infographie,
      dureeMin: 25,
      pointsXp: 45,
      niveauRequis: 0,
      nbQuiz: 4,
      actif: true,
    ),
    const CourseModel(
      id: 'demo-5',
      titre: 'Énergies renouvelables pour les PME rurales',
      theme: 'Énergie verte',
      description: 'Solutions solaires et bioénergies accessibles aux petites entreprises rurales d\'Afrique de l\'Ouest.',
      objectifs: ['Dimensionner une installation solaire', 'Calculer le retour sur investissement', 'Accéder aux subventions'],
      type: CourseType.video,
      dureeMin: 35,
      pointsXp: 70,
      niveauRequis: 1,
      nbQuiz: 7,
      actif: true,
    ),
  ];

  Future<CourseModel?> fetchById(String courseId) async {
    final doc = await _firestore.collection('courses').doc(courseId).get();
    if (!doc.exists) return null;
    return CourseModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<List<QuizQuestion>> fetchQuiz(String courseId) async {
    final doc = await _firestore.collection('courses').doc(courseId).get();
    final quizData = doc.data()?['quiz'] as List<dynamic>? ?? [];
    return quizData.map((q) => QuizQuestion.fromMap(q as Map<String, dynamic>)).toList();
  }

  Future<void> markComplete(String userId, String courseId, int scoreQuiz, int pointsXp) async {
    final badgeDeclenche = scoreQuiz >= 70;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('progress')
        .doc(courseId)
        .set({
      'statut': 'TERMINE',
      'score_quiz': scoreQuiz,
      'date_completion': FieldValue.serverTimestamp(),
      'points_xp_gagnés': pointsXp,
      'badge_declenche': badgeDeclenche,
    }, SetOptions(merge: true));

    if (badgeDeclenche) {
      await _triggerBadge(userId, courseId, scoreQuiz);
    }
  }

  Future<void> _triggerBadge(String userId, String courseId, int scoreQuiz) async {
    final badgeId = 'cours_$courseId';
    final badgeRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('badges')
        .doc(badgeId);

    final existing = await badgeRef.get();
    if (existing.exists) return; // badge déjà délivré

    final nom = scoreQuiz == 100 ? 'Expert Vert — $courseId' : 'Cours complété';
    await badgeRef.set({
      'nom': nom,
      'description': scoreQuiz == 100
          ? 'Quiz réussi à 100% — maîtrise parfaite du cours.'
          : 'Cours terminé avec $scoreQuiz% au quiz.',
      'image_url': '',
      'type': 'formation',
      'date_obtention': FieldValue.serverTimestamp(),
      'course_id': courseId,
      'score_quiz': scoreQuiz,
    });
  }

  Future<void> triggerAssureClimatBadge(String userId) async {
    const badgeId = 'assure_climat';
    final badgeRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('badges')
        .doc(badgeId);

    final existing = await badgeRef.get();
    if (existing.exists) return;

    await badgeRef.set({
      'nom': 'Assuré Climat 🌿',
      'description': 'Vous avez souscrit à votre première assurance climatique. Votre activité est maintenant protégée.',
      'image_url': '',
      'type': 'assurance',
      'date_obtention': FieldValue.serverTimestamp(),
    });
  }

  Future<List<CourseProgress>> fetchProgress(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('progress')
        .get();
    return snapshot.docs
        .map((doc) => CourseProgress.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<List<BadgeModel>> fetchBadges(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('badges')
        .get();
    return snapshot.docs
        .map((doc) => BadgeModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<List<LeconModel>> fetchLecons(String courseId) async {
    try {
      final snapshot = await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('lecons')
          .orderBy('ordre')
          .get();
      return snapshot.docs
          .map((d) => LeconModel.fromFirestore(d.data(), d.id))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
