import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/models/score_climat_model.dart';

// ── Formule de scoring extraite — identique à ScoreRepository._calculLocalFallback ──
// Testée indépendamment sans Firebase ni Cloud Functions.

class ScoringFormula {
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
    'Bio': 25.0, 'Agriculture biologique': 25.0,
    'Équitable': 20.0, 'Commerce équitable': 20.0,
    'ISO 14001': 30.0, 'Carbone Neutre': 25.0,
  };

  static double activite(String type) => _activiteMap[type] ?? 50.0;
  static double uemoa(String alignement) => _uemoaMap[alignement] ?? 20.0;
  static double certif(List<String> certifs) =>
      certifs.fold(0.0, (acc, c) => acc + (_certifMap[c] ?? 0.0)).clamp(0.0, 100.0);

  static double co2(double tonnes) {
    if (tonnes >= 500) return 100.0;
    if (tonnes >= 200) return 80.0;
    if (tonnes >= 100) return 60.0;
    if (tonnes >= 50) return 40.0;
    if (tonnes > 0) return 20.0;
    return 0.0;
  }

  /// Score = (Activité×0.25) + (UEMOA×0.20) + (CO2×0.20) + (Certif×0.20) + (Résilience×0.15) + BonusFormation
  static double compute({
    required String typeActivite,
    required String alignementUemoa,
    required double co2Evite,
    required List<String> certifications,
    required double resilience,
    required double bonusFormation,
  }) {
    final scoreActivite = activite(typeActivite);
    final scoreUemoa = uemoa(alignementUemoa);
    final scoreCo2 = co2(co2Evite);
    final scoreCertif = certif(certifications);
    final scoreResilience = (resilience * 20.0).clamp(0.0, 100.0);

    final raw = scoreActivite * 0.25 +
        scoreUemoa * 0.20 +
        scoreCo2 * 0.20 +
        scoreCertif * 0.20 +
        scoreResilience * 0.15 +
        bonusFormation;

    return double.parse(raw.clamp(0.0, 100.0).toStringAsFixed(1));
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

ScoreClimatModel makeScore(double total) => ScoreClimatModel(
      id: '',
      userId: 'u',
      scoreTotal: total,
      criteres: const ScoreCriteres(
        scoreActivite: 0, scoreUemoa: 0, scoreCo2: 0,
        scoreCertif: 0, scoreResilience: 0, bonusFormation: 0,
      ),
      niveau: ScoreClimatModel.niveauFromScore(total),
      suggestions: [],
      dateCalcul: DateTime(2025),
      versionAlgo: 'v1',
    );

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── niveauFromScore ──────────────────────────────────────────────────────
  group('ScoreClimatModel — niveauFromScore', () {
    test('< 30 → insuffisant', () {
      expect(ScoreClimatModel.niveauFromScore(0), NiveauScore.insuffisant);
      expect(ScoreClimatModel.niveauFromScore(29.9), NiveauScore.insuffisant);
    });

    test('30–59 → intermediaire', () {
      expect(ScoreClimatModel.niveauFromScore(30), NiveauScore.intermediaire);
      expect(ScoreClimatModel.niveauFromScore(59.9), NiveauScore.intermediaire);
    });

    test('60–79 → bon', () {
      expect(ScoreClimatModel.niveauFromScore(60), NiveauScore.bon);
      expect(ScoreClimatModel.niveauFromScore(79.9), NiveauScore.bon);
    });

    test('≥ 80 → excellent', () {
      expect(ScoreClimatModel.niveauFromScore(80), NiveauScore.excellent);
      expect(ScoreClimatModel.niveauFromScore(100), NiveauScore.excellent);
    });
  });

  // ── peutDemanderFinancement ──────────────────────────────────────────────
  group('ScoreClimatModel — peutDemanderFinancement', () {
    test('score ≥ 60 → peut demander financement', () {
      expect(makeScore(60).peutDemanderFinancement, isTrue);
      expect(makeScore(85).peutDemanderFinancement, isTrue);
    });

    test('score < 60 → ne peut pas demander financement', () {
      expect(makeScore(59.9).peutDemanderFinancement, isFalse);
      expect(makeScore(0).peutDemanderFinancement, isFalse);
    });
  });

  // ── Formule de scoring (pure Dart, sans Firebase) ────────────────────────
  group('ScoringFormula — tables de conversion', () {
    test('Agriculture → 75', () => expect(ScoringFormula.activite('Agriculture'), 75.0));
    test('Activité inconnue → 50 (défaut)', () => expect(ScoringFormula.activite('Autre'), 50.0));
    test('UEMOA Oui → 100', () => expect(ScoringFormula.uemoa('Oui'), 100.0));
    test('UEMOA Partiel → 60', () => expect(ScoringFormula.uemoa('Partiel'), 60.0));
    test('UEMOA Non → 20', () => expect(ScoringFormula.uemoa('Non'), 20.0));
    test('CO2 ≥ 500t → 100', () => expect(ScoringFormula.co2(600), 100.0));
    test('CO2 200–499t → 80', () => expect(ScoringFormula.co2(300), 80.0));
    test('CO2 = 0 → 0', () => expect(ScoringFormula.co2(0), 0.0));
    test('certif Bio+Équitable → 45', () {
      expect(ScoringFormula.certif(['Bio', 'Équitable']), 45.0);
    });
    test('certif dépasse 100 → clamped à 100', () {
      expect(
        ScoringFormula.certif(['Bio', 'Équitable', 'ISO 14001', 'Carbone Neutre']),
        100.0,
      );
    });
  });

  group('ScoringFormula — compute()', () {
    test('profil optimal → score ≥ 90', () {
      final score = ScoringFormula.compute(
        typeActivite: 'Agriculture',
        alignementUemoa: 'Oui',
        co2Evite: 600,
        certifications: ['Bio', 'Équitable'],
        resilience: 5, // 5×20 = 100, clamped
        bonusFormation: 15,
      );
      // 75×0.25 + 100×0.20 + 100×0.20 + 45×0.20 + 100×0.15 + 15 = 97.75
      expect(score, greaterThanOrEqualTo(90));
    });

    test('profil minimal → score < 25', () {
      final score = ScoringFormula.compute(
        typeActivite: '',
        alignementUemoa: 'Non',
        co2Evite: 0,
        certifications: [],
        resilience: 0,
        bonusFormation: 0,
      );
      // 50×0.25 + 20×0.20 = 12.5 + 4 = 16.5
      expect(score, lessThan(25));
    });

    test('score toujours dans [0, 100]', () {
      final score = ScoringFormula.compute(
        typeActivite: '',
        alignementUemoa: 'Non',
        co2Evite: 0,
        certifications: [],
        resilience: -10, // négatif, doit être clamped à 0
        bonusFormation: 0,
      );
      expect(score, inInclusiveRange(0, 100));
    });

    test('bonus formation max 15 pts', () {
      final avecBonus = ScoringFormula.compute(
        typeActivite: 'Agriculture',
        alignementUemoa: 'Non',
        co2Evite: 0,
        certifications: [],
        resilience: 0,
        bonusFormation: 15,
      );
      final sansBonus = ScoringFormula.compute(
        typeActivite: 'Agriculture',
        alignementUemoa: 'Non',
        co2Evite: 0,
        certifications: [],
        resilience: 0,
        bonusFormation: 0,
      );
      expect(avecBonus - sansBonus, closeTo(15, 0.1));
    });
  });
}
