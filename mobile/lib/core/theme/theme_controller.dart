import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_theme_mode';

final initialThemeModeProvider =
    Provider<ThemeMode>((_) => ThemeMode.dark);

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(initialThemeModeProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initialMode);

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<void> toggleLightMode(bool lightMode) {
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
