import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

const _themeModeKey = 'app_theme_mode';

final initialThemeModeProvider =
    Provider((_) => ThemeMode.dark);

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(initialThemeModeProvider));
});

ThemeMode _effectiveMode(ThemeMode mode) {
  if (mode != ThemeMode.system) return mode;

  final brightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(ThemeMode initialMode) : super(initialMode) {
    AppColors.setThemeMode(_effectiveMode(initialMode));
  }

  Future setMode(ThemeMode mode) async {
    state = mode;
    AppColors.setThemeMode(_effectiveMode(mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future toggleLightMode(bool lightMode) {
    return setMode(lightMode ? ThemeMode.light : ThemeMode.dark);
  }
}

Future<ThemeMode> loadPersistedThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_themeModeKey);
  return switch (value) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}
