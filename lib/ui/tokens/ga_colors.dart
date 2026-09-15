import 'package:flutter/material.dart';

/// Jeton de couleurs du design system « Organic Fintech ».
///
/// Deux instances : [GaColors.light] et [GaColors.dark]. Toutes les couleurs de
/// l'app passent par ces jetons (directement ou via le [ThemeData]).
@immutable
class GaColors {
  // ── Marque : vert forêt ────────────────────────────────────────────────
  final Color forest; // primary
  final Color forestDim; // partenaire de dégradé, success
  final Color forestBright; // accents sur fond sombre, reflet de jauge
  final Color forestContainer; // remplissages tonals, cartes sélectionnées

  // ── Accents : terre / sable du Sahel ───────────────────────────────────
  final Color sand;
  final Color sandSoft;
  final Color clay; // secondary / accent
  final Color claySoft;

  // ── Surfaces ──────────────────────────────────────────────────────────
  final Color background; // scaffold (papier chaud)
  final Color surface; // cartes
  final Color surfaceAlt; // inputs, cartes imbriquées

  // ── Texte / traits ────────────────────────────────────────────────────
  final Color ink; // texte principal
  final Color inkSoft; // texte secondaire
  final Color outline; // filets

  // ── Sémantique ────────────────────────────────────────────────────────
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  const GaColors({
    required this.forest,
    required this.forestDim,
    required this.forestBright,
    required this.forestContainer,
    required this.sand,
    required this.sandSoft,
    required this.clay,
    required this.claySoft,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.outline,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  bool get isDark => background.computeLuminance() < 0.5;

  static const GaColors light = GaColors(
    forest: Color(0xFF1F5C3D),
    forestDim: Color(0xFF2E7D52),
    forestBright: Color(0xFF3E9B6B),
    forestContainer: Color(0xFFE4EFE7),
    sand: Color(0xFFEADFCB),
    sandSoft: Color(0xFFF3E9DA),
    clay: Color(0xFFC06B3E),
    claySoft: Color(0xFFF3E2D6),
    background: Color(0xFFF7F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBF8F2),
    ink: Color(0xFF1A2420),
    inkSoft: Color(0xFF5B6B62),
    outline: Color(0xFFDCE5DD),
    success: Color(0xFF2E7D52),
    warning: Color(0xFFD98A2B),
    error: Color(0xFFC4463A),
    info: Color(0xFF3E7C8C),
  );

  static const GaColors dark = GaColors(
    forest: Color(0xFF4FB07A),
    forestDim: Color(0xFF3E9B6B),
    forestBright: Color(0xFF6BC793),
    forestContainer: Color(0xFF21402F),
    sand: Color(0xFF3A342A),
    sandSoft: Color(0xFF2E2A22),
    clay: Color(0xFFD8894F),
    claySoft: Color(0xFF3A2E24),
    background: Color(0xFF0F1A14),
    surface: Color(0xFF16241C),
    surfaceAlt: Color(0xFF1D2F24),
    ink: Color(0xFFECF1ED),
    inkSoft: Color(0xFF9DB0A4),
    outline: Color(0xFF2C3D33),
    success: Color(0xFF5FB98A),
    warning: Color(0xFFE4A24B),
    error: Color(0xFFE06A5E),
    info: Color(0xFF6FA9B8),
  );

  static GaColors of(Brightness b) =>
      b == Brightness.dark ? GaColors.dark : GaColors.light;
}
