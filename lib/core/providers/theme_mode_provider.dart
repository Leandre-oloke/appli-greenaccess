import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_provider.dart';

const String _kThemeModeKey = 'theme_mode';

/// Persiste le choix de thème (Système / Clair / Sombre) dans SharedPreferences.
///
/// Défensif : si les prefs ne sont pas disponibles (tests, previews), on
/// retombe silencieusement sur [ThemeMode.system].
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences? _prefs;

  static ThemeMode _read(SharedPreferences? p) {
    try {
      return switch (p?.getString(_kThemeModeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await _prefs?.setString(_kThemeModeKey, mode.name);
    } catch (_) {
      // best-effort
    }
  }

  void cycle() {
    set(switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPrefsProvider);
  } catch (_) {
    prefs = null;
  }
  return ThemeModeNotifier(prefs);
});
