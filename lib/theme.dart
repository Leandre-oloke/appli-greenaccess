import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Palette verte GreenAccess ─────────────────────────────────────────────────

class AppColors {
  // Primaire — vert forêt (identité de marque)
  static const Color primary      = Color(0xFF2D7D46);
  static const Color primaryLight = Color(0xFF48A66A);
  static const Color primaryDark  = Color(0xFF1B5E20);
  static const Color primarySoft  = Color(0xFFE8F5E9); // fond cartes vertes

  // Secondaire — teal (accent complémentaire vert)
  static const Color secondary      = Color(0xFF00897B);
  static const Color secondaryLight = Color(0xFF4DB6AC);

  // Accent — or/ambre (CTA forts, badges, warnings)
  static const Color accent = Color(0xFFF9A825);

  // Fonds
  static const Color background = Color(0xFFF4FAF5); // blanc verdâtre très léger
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color onPrimary  = Color(0xFFFFFFFF);

  // Texte
  static const Color textPrimary   = Color(0xFF1A2E1F); // quasi-noir verdâtre
  static const Color textSecondary = Color(0xFF607D6A); // gris verdâtre
  static const Color logoTextColor = Color(0xFF2D4A3E);

  // Séparateurs
  static const Color divider = Color(0xFFCCDFD1);

  // Niveaux de score
  static const Color scoreInsuffisant   = Color(0xFFE53935);
  static const Color scoreIntermediaire = Color(0xFFFF9800);
  static const Color scoreBon           = Color(0xFF8BC34A);
  static const Color scoreExcellent     = Color(0xFF2E7D32);

  // États fonctionnels
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57F17);
  static const Color error   = Color(0xFFD32F2F);
  static const Color info    = Color(0xFF00897B); // teal cohérent avec secondary
}

// ── Thème Material 3 unifié ────────────────────────────────────────────────────

class AppTheme {
  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary:          AppColors.primary,
      onPrimary:        AppColors.onPrimary,
      primaryContainer: AppColors.primarySoft,
      secondary:        AppColors.secondary,
      onSecondary:      Colors.white,
      tertiary:         AppColors.accent,
      surface:          AppColors.surface,
      onSurface:        AppColors.textPrimary,
      surfaceContainerHighest: AppColors.background,
      error:            AppColors.error,
      outline:          AppColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      // ── Bottom Navigation Bar ────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),

      // ── Boutons ──────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // ── Champs texte ─────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        prefixIconColor: AppColors.textSecondary,
      ),

      // ── Cartes ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // ── Chips ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySoft,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.primary, fontSize: 13),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ── Switch ───────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primaryLight.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ─────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        titleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),

      // ── Progress Indicator ───────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
        circularTrackColor: AppColors.primarySoft,
      ),

      // ── Typographie ──────────────────────────────────────────────────────
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,  color: AppColors.textPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,  color: AppColors.textPrimary),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium:  TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodyLarge:    TextStyle(fontSize: 15, color: AppColors.textPrimary),
        bodyMedium:   TextStyle(fontSize: 14, color: AppColors.textPrimary),
        bodySmall:    TextStyle(fontSize: 12, color: AppColors.textSecondary),
        labelLarge:   TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
        labelSmall:   TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}
