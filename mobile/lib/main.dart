import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/routes/app_router.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/services/notification_service.dart';

ThemeMode _effectiveMode(ThemeMode mode) {
  if (mode != ThemeMode.system) return mode;
  final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
}

SystemUiOverlayStyle _overlayStyleFor(ThemeMode mode) {
  final isLight = _effectiveMode(mode) == ThemeMode.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
    statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  apiClient.init();
  await NotificationService.initialize();

  final firstLoginDone =
      await SecureStorageService.getFlag('first_login_done') == 'true';
  final initialThemeMode = await loadPersistedThemeMode();

  AppColors.setThemeMode(_effectiveMode(initialThemeMode));

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        firstLoginDoneProvider.overrideWith((ref) => firstLoginDone),
        initialThemeModeProvider.overrideWithValue(initialThemeMode),
      ],
      child: const ProductivityAIApp(),
    ),
  );
}

class ProductivityAIApp extends ConsumerWidget {
  const ProductivityAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return AnnotatedRegion(
      value: _overlayStyleFor(themeMode),
      child: MaterialApp.router(
        title: 'com.productivitytracker.productive_ai',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
