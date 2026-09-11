import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/score_climat_model.dart';

/// CDC §4.4 — règle absolue : « le calcul n'est jamais effectué côté client ».
/// Désactivé par défaut : n'active ce repli que pour du développement local
/// (ex. contre les émulateurs, sans avoir déployé `calculerScoreClimat`), en
/// sachant que le score obtenu n'est alors PAS celui du serveur.
///   flutter run --dart-define=ALLOW_LOCAL_SCORE_FALLBACK=true
const bool kAllowLocalScoreFallback =
    bool.fromEnvironment('ALLOW_LOCAL_SCORE_FALLBACK');

/// Levée quand `calculerScoreClimat` est injoignable et qu'aucun repli n'est
/// autorisé ([kAllowLocalScoreFallback] à `false`, le cas normal en prod).
class ScoreCalculationException implements Exception {
  final String message;
  const ScoreCalculationException(this.message);

  @override
  String toString() => message;
}

class ScoreRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ScoreRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        // calculerScoreClimat est déployée sur europe-west1 (functions/src/index.ts,
        // main.dart) — FirebaseFunctions.instance viserait us-central1 par défaut
        // et l'appel échouerait systématiquement en "not-found" une fois déployé.
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Calcule le score en appelant la Cloud Function `calculerScoreClimat`.
  ///
  /// Si elle est injoignable : repli local uniquement si
  /// [kAllowLocalScoreFallback] est activé (dev only) ; sinon lève
  /// [ScoreCalculationException] avec un message affichable tel quel.
  Future<ScoreClimatModel> calculate(String userId, Map<String, dynamic> inputs) async {
    try {
      final callable = _functions.httpsCallable(
        'calculerScoreClimat',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      // La Cloud Function attend des clés camelCase (interface ScoreInput côté
      // functions/src/index.ts) alors que le formulaire construit un Map en
      // snake_case pour le repli local — on convertit ici plutôt que de faire
      // porter ce détail d'intégration à l'écran appelant.
      final result = await callable.call({
        'userId': userId,
        'typeActivite': inputs['type_activite'],
        'alignementUemoa': inputs['alignement_uemoa'],
        'reductionCo2': inputs['co2_evite'],
        'certifications': inputs['certifications'],
        'resilience': inputs['resilience'],
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final score = ScoreClimatModel(
        id: data['scoreId'] ?? '',
        userId: userId,
        scoreTotal: (data['scoreTotal'] ?? 0).toDouble(),
        criteres: ScoreCriteres.fromMap(data['criteres'] ?? {}),
        niveau: ScoreClimatModel.niveauFromScore((data['scoreTotal'] ?? 0).toDouble()),
        suggestions: List<String>.from(data['suggestions'] ?? []),
        dateCalcul: DateTime.now(),
        versionAlgo: 'v1-cloud',
      );
      return score;
    } catch (_) {
      if (kAllowLocalScoreFallback) {
        return _calculLocalFallback(userId, inputs);
      }
      throw const ScoreCalculationException(
        'Le calcul du score est momentanément indisponible. Réessayez dans '
        'quelques instants, ou complétez des formations en attendant.',
      );
    }
  }

  /// Même formule que functions/src/index.ts → calculerScoreClimat.
  /// Score = (Activité×0.25) + (UEMOA×0.20) + (CO2×0.20) + (Certif×0.20) + (Résilience×0.15) + BonusFormation
  Future<ScoreClimatModel> _calculLocalFallback(
    String userId,
    Map<String, dynamic> inputs,
  ) async {
    final scoreActivite = _activiteToScore(inputs['type_activite']?.toString() ?? '');
    final scoreUemoa = _uemoaToScore(inputs['alignement_uemoa']?.toString() ?? 'Non');
    final scoreCo2 = _co2ToScore((inputs['co2_evite'] ?? 0).toDouble());
    final scoreCertif = _certifToScore(List<String>.from(inputs['certifications'] ?? []));
    final scoreResilience = ((inputs['resilience'] ?? 1) as num).toDouble() * 20.0;
    final bonusFormation = await _getBonusFormation(userId);

    final criteres = ScoreCriteres(
      scoreActivite: scoreActivite,
      scoreUemoa: scoreUemoa,
      scoreCo2: scoreCo2,
      scoreCertif: scoreCertif,
      scoreResilience: scoreResilience.clamp(0.0, 100.0),
      bonusFormation: bonusFormation,
    );

    final raw = criteres.scoreActivite * 0.25 +
        criteres.scoreUemoa * 0.20 +
        criteres.scoreCo2 * 0.20 +
        criteres.scoreCertif * 0.20 +
        criteres.scoreResilience * 0.15 +
        criteres.bonusFormation;

    final scoreTotal = double.parse(raw.clamp(0.0, 100.0).toStringAsFixed(1));
    final suggestions = _genererSuggestions(criteres, scoreTotal);

    final score = ScoreClimatModel(
      id: '',
      userId: userId,
      scoreTotal: scoreTotal,
      criteres: criteres,
      niveau: ScoreClimatModel.niveauFromScore(scoreTotal),
      suggestions: suggestions,
      dateCalcul: DateTime.now(),
      versionAlgo: 'v1-local',
    );

    await saveScore(userId, score);
    return score;
  }

  // ── Tables de conversion (identiques à la CF) ──────────────────────────────

  static const _activiteMap = {
    'Agriculture': 75.0,
    'Énergie renouvelable': 90.0,
    'Recyclage': 85.0,
    'Transport propre': 80.0,
    'Forêt': 88.0,
    'Forêt / Agroforesterie': 88.0,
    'Pêche durable': 70.0,
  };

  static const _uemoaMap = {
    'Oui': 100.0,
    'Partiel': 60.0,
    'Non': 20.0,
  };

  static const _certifMap = {
    'Bio': 25.0,
    'Agriculture biologique': 25.0,
    'Équitable': 20.0,
    'Commerce équitable': 20.0,
    'ISO 14001': 30.0,
    'Carbone Neutre': 25.0,
  };

  double _activiteToScore(String type) => _activiteMap[type] ?? 50.0;

  double _uemoaToScore(String alignement) => _uemoaMap[alignement] ?? 20.0;

  double _co2ToScore(double tonnes) {
    if (tonnes >= 500) return 100.0;
    if (tonnes >= 200) return 80.0;
    if (tonnes >= 100) return 60.0;
    if (tonnes >= 50) return 40.0;
    if (tonnes > 0) return 20.0;
    return 0.0;
  }

  double _certifToScore(List<String> certifs) {
    final total = certifs.fold(0.0, (acc, c) => acc + (_certifMap[c] ?? 0.0));
    return total.clamp(0.0, 100.0);
  }

  /// Bonus formation : +2 pts par cours terminé, +3 pts par badge, max 15 pts.
  Future<double> _getBonusFormation(String userId) async {
    try {
      final progress = await _firestore
          .collection('users')
          .doc(userId)
          .collection('progress')
          .where('statut', isEqualTo: 'TERMINE')
          .get();
      final badges = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();
      final bonus = progress.size * 2.0 + badges.size * 3.0;
      return bonus.clamp(0.0, 15.0);
    } catch (_) {
      return 0.0;
    }
  }

  List<String> _genererSuggestions(ScoreCriteres c, double total) {
    final s = <String>[];
    if (c.scoreCo2 < 60) {
      s.add('Documentez votre réduction d\'émissions CO₂ pour améliorer votre score.');
    }
    if (c.scoreUemoa < 60) {
      s.add('Alignez votre activité avec la taxonomie UEMOA verte (critères verts).');
    }
    if (c.scoreCertif < 40) {
      s.add('Obtenez une certification (Agriculture Bio, ISO 14001…) pour +25 pts.');
    }
    if (c.bonusFormation < 8) {
      s.add('Complétez davantage de formations pour gagner des points bonus (max +15).');
    }
    if (total < 60) {
      s.add('Score < 60 : continuez à améliorer vos critères pour accéder au financement vert.');
    }
    return s;
  }

  // ── Persistance Firestore ──────────────────────────────────────────────────

  Future<void> saveScore(String userId, ScoreClimatModel score) async {
    await _firestore.collection('scores_climat').add({
      'userId': userId,
      'date_calcul': FieldValue.serverTimestamp(),
      'score_total': score.scoreTotal,
      'criteres': score.criteres.toMap(),
      'niveau': score.niveau.name,
      'suggestions': score.suggestions,
      'version_algo': score.versionAlgo,
    });
  }

  Future<ScoreClimatModel?> getLatestScore(String userId) async {
    final snapshot = await _firestore
        .collection('scores_climat')
        .where('userId', isEqualTo: userId)
        .orderBy('date_calcul', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return ScoreClimatModel.fromFirestore(doc.data(), doc.id);
  }

  Future<List<ScoreClimatModel>> getHistory(String userId) async {
    final snapshot = await _firestore
        .collection('scores_climat')
        .where('userId', isEqualTo: userId)
        .orderBy('date_calcul', descending: true)
        .limit(10)
        .get();
    return snapshot.docs
        .map((doc) => ScoreClimatModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }
}
