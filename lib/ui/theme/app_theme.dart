import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/ga_colors.dart';
import '../tokens/ga_radii.dart';
import '../tokens/ga_typography.dart';
import 'ga_theme_extensions.dart';

/// Thème Material 3 du design system « Organic Fintech ».
///
/// `AppTheme.light` / `AppTheme.dark` sont construits entièrement à partir des
/// jetons ([GaColors], [GaTypography], [GaRadii]).
abstract final class AppTheme {
  static ThemeData get light => _build(GaColors.light, Brightness.light);
  static ThemeData get dark => _build(GaColors.dark, Brightness.dark);

  static ThemeData _build(GaColors t, Brightness b) {
    final isDark = b == Brightness.dark;
    final text = GaTypography.textTheme(t);

    final scheme = ColorScheme(
      brightness: b,
      primary: t.forest,
      onPrimary: isDark ? const Color(0xFF06210F) : Colors.white,
      primaryContainer: t.forestContainer,
      onPrimaryContainer: isDark ? t.ink : t.forest,
      secondary: t.clay,
      onSecondary: Colors.white,
      secondaryContainer: t.claySoft,
      onSecondaryContainer: isDark ? t.ink : const Color(0xFF5A3115),
      tertiary: t.forestDim,
      onTertiary: Colors.white,
      error: t.error,
      onError: Colors.white,
      errorContainer: t.error.withValues(alpha: isDark ? 0.24 : 0.12),
      onErrorContainer: isDark ? t.ink : t.error,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.inkSoft,
      surfaceContainerLowest: t.background,
      surfaceContainerLow: t.surfaceAlt,
      surfaceContainer: t.surfaceAlt,
      surfaceContainerHigh: t.surface,
      surfaceContainerHighest: t.surface,
      outline: t.outline,
      outlineVariant: t.outline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: t.ink,
      onInverseSurface: t.surface,
      inversePrimary: t.forestBright,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      fontFamily: GaTypography.body,
      fontFamilyFallback: GaTypography.fallback,
      textTheme: text,
      primaryTextTheme: text,
      splashFactory: InkSparkle.splashFactory,
      extensions: [
        GaShadows.of(b),
        GaGradients.of(b),
        GaSemanticColors.of(b),
      ],

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontFamily: GaTypography.display,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: t.ink),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent),
      ),

      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: GaRadii.brLg),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.forest,
          foregroundColor: isDark ? const Color(0xFF06210F) : Colors.white,
          disabledBackgroundColor: t.forest.withValues(alpha: 0.4),
          minimumSize: const Size(64, 56),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: GaRadii.brPill),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.forest,
          foregroundColor: isDark ? const Color(0xFF06210F) : Colors.white,
          minimumSize: const Size(64, 56),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: GaRadii.brPill),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.forest,
          side: BorderSide(color: t.forest.withValues(alpha: 0.5)),
          minimumSize: const Size(64, 52),
          shape: const RoundedRectangleBorder(borderRadius: GaRadii.brPill),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.forest,
          textStyle: text.labelLarge,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.forest,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: GaRadii.brLg),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: GaRadii.brMd,
          borderSide: BorderSide(color: t.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: GaRadii.brMd,
          borderSide: BorderSide(color: t.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: GaRadii.brMd,
          borderSide: BorderSide(color: t.forest, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: GaRadii.brMd,
          borderSide: BorderSide(color: t.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: GaRadii.brMd,
          borderSide: BorderSide(color: t.error, width: 2),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: t.inkSoft),
        floatingLabelStyle: text.bodySmall?.copyWith(color: t.forest),
        hintStyle: text.bodyMedium?.copyWith(color: t.inkSoft),
        prefixIconColor: t.inkSoft,
        suffixIconColor: t.inkSoft,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.surface,
        selectedItemColor: t.forest,
        unselectedItemColor: t.inkSoft,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: text.labelSmall,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.forestContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: t.forest,
        inactiveTrackColor: t.forestContainer,
        thumbColor: t.forest,
        overlayColor: t.forest.withValues(alpha: 0.12),
        valueIndicatorColor: t.forest,
        trackHeight: 6,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: t.forestContainer,
        selectedColor: t.forest,
        labelStyle: text.labelMedium?.copyWith(color: t.forest),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: Colors.white),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: GaRadii.brSm),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.forest : t.inkSoft,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? t.forestBright.withValues(alpha: 0.5)
              : t.outline,
        ),
      ),

      dividerTheme: DividerThemeData(color: t.outline, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        iconColor: t.forest,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.forest,
        linearTrackColor: t.forestContainer,
        circularTrackColor: t.forestContainer,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.surface),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: GaRadii.brMd),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: GaRadii.brXl),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: GaRadii.brSheetTop),
        showDragHandle: true,
        dragHandleColor: t.outline,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: t.forest,
        unselectedLabelColor: t.inkSoft,
        indicatorColor: t.forest,
        labelStyle: text.labelLarge,
        dividerColor: Colors.transparent,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.ink,
          borderRadius: GaRadii.brSm,
        ),
        textStyle: text.bodySmall?.copyWith(color: t.surface),
      ),

      iconTheme: IconThemeData(color: t.inkSoft),
    );
  }
}
