enum CourseType { video, pdf, quiz, infographie }

class CourseModel {
  final String id;
  final String titre;
  final String theme;
  final String description;
  final List<String> objectifs;
  final CourseType type;
  final String? urlVideo;
  final String? urlPdf;
  final int dureeMin;
  final int pointsXp;
  final int niveauRequis;
  final int nbQuiz;
  final bool actif;

  const CourseModel({
    required this.id,
    required this.titre,
    required this.theme,
    this.description = '',
    this.objectifs = const [],
    required this.type,
    this.urlVideo,
    this.urlPdf,
    required this.dureeMin,
    required this.pointsXp,
    required this.niveauRequis,
    required this.nbQuiz,
    required this.actif,
  });

  // Url de contenu selon le type
  String? get contenuUrl => type == CourseType.video ? urlVideo : urlPdf;

  // Niveau en texte pour l'affichage
  String get niveauDifficulte => switch (niveauRequis) {
        0 => 'Débutant',
        1 => 'Intermédiaire',
        _ => 'Avancé',
      };

  factory CourseModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CourseModel(
      id: id,
      titre: data['titre'] ?? '',
      theme: data['theme'] ?? '',
      description: data['description'] ?? '',
      objectifs: List<String>.from(data['objectifs'] ?? []),
      type: CourseType.values.firstWhere(
        (t) => t.name == (data['type'] ?? 'video'),
        orElse: () => CourseType.video,
      ),
      urlVideo: data['url_video'],
      urlPdf: data['url_pdf'],
      dureeMin: data['duree_min'] ?? 0,
      pointsXp: data['points_xp'] ?? 0,
      niveauRequis: data['niveau_requis'] ?? 0,
      nbQuiz: data['nb_quiz'] ?? 0,
      actif: data['actif'] ?? true,
    );
  }
}

class CourseProgress {
  final String courseId;
  final String statut; // EN_COURS, TERMINE
  final int scoreQuiz;
  final DateTime? dateCompletion;
  final int pointsXpGagnes;
  final bool badgeDeclenche;

  const CourseProgress({
    required this.courseId,
    required this.statut,
    required this.scoreQuiz,
    this.dateCompletion,
    required this.pointsXpGagnes,
    required this.badgeDeclenche,
  });

  factory CourseProgress.fromFirestore(Map<String, dynamic> data, String courseId) {
    return CourseProgress(
      courseId: courseId,
      statut: data['statut'] ?? 'EN_COURS',
      scoreQuiz: data['score_quiz'] ?? 0,
      dateCompletion: data['date_completion'] != null
          ? (data['date_completion'] as dynamic).toDate()
          : null,
      pointsXpGagnes: data['points_xp_gagnés'] ?? 0,
      badgeDeclenche: data['badge_declenche'] ?? false,
    );
  }

  bool get isComplete => statut == 'TERMINE';
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  // Pour type 'ordre' : ordre correct des options (ex: [2,0,1] signifie options[2] en premier)
  final List<int> correctOrder;
  final String type; // qcm, vrai_faux, ordre

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.correctOrder = const [],
    required this.type,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> data) {
    return QuizQuestion(
      id: data['id'] ?? '',
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctIndex: data['correct_index'] ?? 0,
      correctOrder: data['correct_order'] != null
          ? List<int>.from(data['correct_order'])
          : [],
      type: data['type'] ?? 'qcm',
    );
  }

  bool isOrderCorrect(List<int> userOrder) {
    if (correctOrder.isEmpty || userOrder.length != correctOrder.length) return false;
    for (int i = 0; i < correctOrder.length; i++) {
      if (userOrder[i] != correctOrder[i]) return false;
    }
    return true;
  }
}
