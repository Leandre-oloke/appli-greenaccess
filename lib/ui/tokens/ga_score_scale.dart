import 'package:flutter/material.dart';

import '../../models/score_climat_model.dart';
import 'ga_colors.dart';

/// Source unique — côté présentation — des paliers du Score Climat.
///
/// Le modèle ([ScoreClimatModel.niveauFromScore]) reste la vérité métier ;
/// cette classe ne fait que fournir couleur + libellé + bornes d'affichage.
/// Réaligner les bornes sur le CDC (0-29 / 30-59 / 60-79 / 80-100) se fera
/// ici et dans le modèle sans toucher aux composants.
abstract final class GaScoreScale {
  static const int seuilFinancement = 60;

  static String labelFor(NiveauScore n) => switch (n) {
        NiveauScore.insuffisant => 'Insuffisant',
        NiveauScore.intermediaire => 'Intermédiaire',
        NiveauScore.bon => 'Bon',
        NiveauScore.excellent => 'Excellent',
      };

  static Color colorFor(NiveauScore n, Brightness b) {
    final c = GaColors.of(b);
    return switch (n) {
      NiveauScore.insuffisant => c.error,
      NiveauScore.intermediaire => c.warning,
      NiveauScore.bon => b == Brightness.dark
          ? const Color(0xFF7FC96A)
          : const Color(0xFF5E9C4E),
      NiveauScore.excellent => c.forest,
    };
  }

  /// Message court d'éligibilité au financement.
  static String eligibiliteMessage(double score) => score >= seuilFinancement
      ? 'Score ≥ $seuilFinancement : vous pouvez soumettre une demande de financement vert.'
      : 'Score < $seuilFinancement : complétez des formations pour améliorer votre score.';
}
