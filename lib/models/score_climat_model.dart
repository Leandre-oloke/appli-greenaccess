enum NiveauScore { insuffisant, intermediaire, bon, excellent }

class ScoreCriteres {
  final double scoreActivite;
  final double scoreUemoa;
  final double scoreCo2;
  final double scoreCertif;
  final double scoreResilience;
  final double bonusFormation;

  const ScoreCriteres({
    required this.scoreActivite,
    required this.scoreUemoa,
    required this.scoreCo2,
    required this.scoreCertif,
    required this.scoreResilience,
    required this.bonusFormation,
  });

  Map<String, dynamic> toMap() => {
        'activite': scoreActivite,
        'uemoa': scoreUemoa,
        'co2': scoreCo2,
        'certif': scoreCertif,
        'resilience': scoreResilience,
        'bonus_formation': bonusFormation,
      };

  factory ScoreCriteres.fromMap(Map<String, dynamic> data) {
    return ScoreCriteres(
      scoreActivite: (data['activite'] ?? 0).toDouble(),
      scoreUemoa: (data['uemoa'] ?? 0).toDouble(),
      scoreCo2: (data['co2'] ?? 0).toDouble(),
      scoreCertif: (data['certif'] ?? 0).toDouble(),
      scoreResilience: (data['resilience'] ?? 0).toDouble(),
      bonusFormation: (data['bonus_formation'] ?? 0).toDouble(),
    );
  }
}

class ScoreClimatModel {
  final String id;
  final String userId;
  final double scoreTotal;
  final ScoreCriteres criteres;
  final NiveauScore niveau;
  final List<String> suggestions;
  final DateTime dateCalcul;
  final String versionAlgo;

  const ScoreClimatModel({
    required this.id,
    required this.userId,
    required this.scoreTotal,
    required this.criteres,
    required this.niveau,
    required this.suggestions,
    required this.dateCalcul,
    required this.versionAlgo,
  });

  static NiveauScore niveauFromScore(double score) {
    if (score < 30) return NiveauScore.insuffisant;
    if (score < 60) return NiveauScore.intermediaire;
    if (score < 80) return NiveauScore.bon;
    return NiveauScore.excellent;
  }

  bool get peutDemanderFinancement => scoreTotal >= 60;

  factory ScoreClimatModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ScoreClimatModel(
      id: id,
      userId: data['userId'] ?? '',
      scoreTotal: (data['score_total'] ?? 0).toDouble(),
      criteres: ScoreCriteres.fromMap(data['criteres'] ?? {}),
      niveau: niveauFromScore((data['score_total'] ?? 0).toDouble()),
      suggestions: List<String>.from(data['suggestions'] ?? []),
      dateCalcul: (data['date_calcul'] as dynamic).toDate(),
      versionAlgo: data['version_algo'] ?? 'v1',
    );
  }
}
