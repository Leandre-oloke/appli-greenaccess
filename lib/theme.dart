import 'package:flutter/material.dart';

// Le thème vit désormais dans le design system (`lib/ui/`).
// Ce fichier reste un point d'entrée de compatibilité : `AppTheme` est
// ré-exporté, et `AppColors` conserve tous ses noms — seules les valeurs sont
// repointées sur les jetons « Organic Fintech » pour que les écrans non
// refondus héritent de la nouvelle palette sans édition.
export 'ui/theme/app_theme.dart' show AppTheme;

/// Palette de compatibilité — valeurs alignées sur `GaColors.light`.
/// Pour du code neuf, préférer les jetons du design system
/// (`context.gaTokens`, `Theme.of(context).colorScheme`, extensions `Ga*`).
class AppColors {
  // Primaire — vert forêt
  static const Color primary = Color(0xFF1F5C3D);
  static const Color primaryLight = Color(0xFF3E9B6B);
  static const Color primaryDark = Color(0xFF15402B);
  static const Color primarySoft = Color(0xFFE4EFE7);

  // Secondaire / accents
  static const Color secondary = Color(0xFF3E7C8C);
  static const Color secondaryLight = Color(0xFF6FA9B8);
  static const Color accent = Color(0xFFC06B3E);

  // Fonds
  static const Color background = Color(0xFFF7F5F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Texte
  static const Color textPrimary = Color(0xFF1A2420);
  static const Color textSecondary = Color(0xFF5B6B62);
  static const Color logoTextColor = Color(0xFF1F4A3A);

  // Séparateurs
  static const Color divider = Color(0xFFDCE5DD);

  // Niveaux de score
  static const Color scoreInsuffisant = Color(0xFFC4463A);
  static const Color scoreIntermediaire = Color(0xFFD98A2B);
  static const Color scoreBon = Color(0xFF5E9C4E);
  static const Color scoreExcellent = Color(0xFF1F5C3D);

  // États fonctionnels
  static const Color success = Color(0xFF2E7D52);
  static const Color warning = Color(0xFFD98A2B);
  static const Color error = Color(0xFFC4463A);
  static const Color info = Color(0xFF3E7C8C);
}
