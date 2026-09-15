import 'package:flutter/material.dart';

import '../tokens/ga_colors.dart';

/// Ombres en couches, teintées selon le thème.
@immutable
class GaShadows extends ThemeExtension<GaShadows> {
  final List<BoxShadow> e1;
  final List<BoxShadow> e2; // carte au repos
  final List<BoxShadow> e3; // surélevé / hover / feuille
  final List<BoxShadow> e4; // modale

  const GaShadows({
    required this.e1,
    required this.e2,
    required this.e3,
    required this.e4,
  });

  static const List<BoxShadow> e0 = [];

  factory GaShadows.of(Brightness b) {
    final tint = b == Brightness.dark
        ? Colors.black
        : const Color(0xFF1F5C3D);
    double a(double light, double dark) => b == Brightness.dark ? dark : light;
    return GaShadows(
      e1: [
        BoxShadow(
          color: tint.withValues(alpha: a(0.06, 0.28)),
          blurRadius: 8,
          spreadRadius: -1,
          offset: const Offset(0, 2),
        ),
      ],
      e2: [
        BoxShadow(
          color: tint.withValues(alpha: a(0.05, 0.24)),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: tint.withValues(alpha: a(0.08, 0.34)),
          blurRadius: 20,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ],
      e3: [
        BoxShadow(
          color: tint.withValues(alpha: a(0.06, 0.28)),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: tint.withValues(alpha: a(0.12, 0.42)),
          blurRadius: 32,
          spreadRadius: -6,
          offset: const Offset(0, 16),
        ),
      ],
      e4: [
        BoxShadow(
          color: tint.withValues(alpha: a(0.16, 0.5)),
          blurRadius: 48,
          spreadRadius: -8,
          offset: const Offset(0, 24),
        ),
      ],
    );
  }

  @override
  GaShadows copyWith({
    List<BoxShadow>? e1,
    List<BoxShadow>? e2,
    List<BoxShadow>? e3,
    List<BoxShadow>? e4,
  }) =>
      GaShadows(
        e1: e1 ?? this.e1,
        e2: e2 ?? this.e2,
        e3: e3 ?? this.e3,
        e4: e4 ?? this.e4,
      );

  @override
  GaShadows lerp(ThemeExtension<GaShadows>? other, double t) {
    if (other is! GaShadows) return this;
    return GaShadows(
      e1: BoxShadow.lerpList(e1, other.e1, t) ?? e1,
      e2: BoxShadow.lerpList(e2, other.e2, t) ?? e2,
      e3: BoxShadow.lerpList(e3, other.e3, t) ?? e3,
      e4: BoxShadow.lerpList(e4, other.e4, t) ?? e4,
    );
  }
}

/// Dégradés de marque.
@immutable
class GaGradients extends ThemeExtension<GaGradients> {
  final LinearGradient header; // bandeaux héros
  final SweepGradient gaugeSweep; // jauge de score
  final LinearGradient heroWash; // fond doux

  const GaGradients({
    required this.header,
    required this.gaugeSweep,
    required this.heroWash,
  });

  factory GaGradients.of(Brightness b) {
    final c = GaColors.of(b);
    return GaGradients(
      header: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.forest, c.forestDim, c.forestDim],
        stops: const [0.0, 0.7, 1.0],
      ),
      gaugeSweep: SweepGradient(
        startAngle: 0,
        endAngle: 3.14159 * 2,
        colors: [c.forest, c.forestBright, c.clay, c.forest],
        stops: const [0.0, 0.45, 0.8, 1.0],
      ),
      heroWash: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c.forestContainer, c.surface],
      ),
    );
  }

  @override
  GaGradients copyWith({
    LinearGradient? header,
    SweepGradient? gaugeSweep,
    LinearGradient? heroWash,
  }) =>
      GaGradients(
        header: header ?? this.header,
        gaugeSweep: gaugeSweep ?? this.gaugeSweep,
        heroWash: heroWash ?? this.heroWash,
      );

  @override
  GaGradients lerp(ThemeExtension<GaGradients>? other, double t) {
    if (other is! GaGradients) return this;
    return GaGradients(
      header: LinearGradient.lerp(header, other.header, t) ?? header,
      gaugeSweep: gaugeSweep,
      heroWash: LinearGradient.lerp(heroWash, other.heroWash, t) ?? heroWash,
    );
  }
}

/// Couleurs sémantiques (success / warning / info) exposées via le thème.
@immutable
class GaSemanticColors extends ThemeExtension<GaSemanticColors> {
  final Color success;
  final Color warning;
  final Color info;
  final Color sand;
  final Color clay;
  final Color forestContainer;
  final Color surfaceAlt;
  final Color inkSoft;

  const GaSemanticColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.sand,
    required this.clay,
    required this.forestContainer,
    required this.surfaceAlt,
    required this.inkSoft,
  });

  factory GaSemanticColors.of(Brightness b) {
    final c = GaColors.of(b);
    return GaSemanticColors(
      success: c.success,
      warning: c.warning,
      info: c.info,
      sand: c.sand,
      clay: c.clay,
      forestContainer: c.forestContainer,
      surfaceAlt: c.surfaceAlt,
      inkSoft: c.inkSoft,
    );
  }

  @override
  GaSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? sand,
    Color? clay,
    Color? forestContainer,
    Color? surfaceAlt,
    Color? inkSoft,
  }) =>
      GaSemanticColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        info: info ?? this.info,
        sand: sand ?? this.sand,
        clay: clay ?? this.clay,
        forestContainer: forestContainer ?? this.forestContainer,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        inkSoft: inkSoft ?? this.inkSoft,
      );

  @override
  GaSemanticColors lerp(ThemeExtension<GaSemanticColors>? other, double t) {
    if (other is! GaSemanticColors) return this;
    return GaSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      sand: Color.lerp(sand, other.sand, t)!,
      clay: Color.lerp(clay, other.clay, t)!,
      forestContainer: Color.lerp(forestContainer, other.forestContainer, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
    );
  }
}

/// Raccourcis d'accès aux extensions depuis un [BuildContext].
extension GaThemeX on BuildContext {
  GaShadows get gaShadows =>
      Theme.of(this).extension<GaShadows>() ?? GaShadows.of(Brightness.light);
  GaGradients get gaGradients =>
      Theme.of(this).extension<GaGradients>() ?? GaGradients.of(Brightness.light);
  GaSemanticColors get gaColors =>
      Theme.of(this).extension<GaSemanticColors>() ??
      GaSemanticColors.of(Brightness.light);
  GaColors get gaTokens => GaColors.of(Theme.of(this).brightness);
}
