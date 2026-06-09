import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/create_password_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/template_select_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../shell/main_shell.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/daily_log/presentation/screens/daily_log_screen.dart';
import '../../features/daily_log/presentation/screens/customization_screen.dart';
import '../../features/daily_log/presentation/screens/advanced_analytics_screen.dart';
import '../../features/daily_log/presentation/screens/chart_edit_screen.dart';
import '../../features/routines/presentation/screens/add_routine_screen.dart';
import '../../features/ai_coach/presentation/screens/ai_coach_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/achievements_screen.dart';
import '../../features/settings/presentation/screens/notification_prefs_screen.dart';
import '../../features/focus/presentation/screens/focus_screen.dart';
import '../../features/notifications/presentation/screens/notification_center_screen.dart';

class _AuthChangeNotifier extends ChangeNotifier {
  final Ref _ref;
  _AuthChangeNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, __) {
      debugPrint('[ROUTER] Auth state changed — notifying router');
      notifyListeners();
    });
  }
}

final firstLoginDoneProvider = StateProvider<bool>((ref) => false);

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.isAuthenticated;
      final location = state.matchedLocation;

      debugPrint('[ROUTER] Current route: $location');
      debugPrint('[ROUTER] Authenticated: $isLoggedIn');

      final isAuthRoute = location.startsWith('/login') ||
          location.startsWith('/register') ||
          location.startsWith('/otp') ||
          location.startsWith('/create-password') ||
          location.startsWith('/forgot-password') ||
          location.startsWith('/template-select');

      if (!isLoggedIn && !isAuthRoute) {
        debugPrint('[ROUTER] Redirect triggered → /login');
        return '/login';
      }

      if (isLoggedIn &&
          (location.startsWith('/login') ||
              location.startsWith('/register') ||
              location.startsWith('/otp') ||
              location.startsWith('/create-password'))) {
        // Check first login flag synchronously via the provider
        final done = ref.read(firstLoginDoneProvider);
        if (!done) {
          return '/template-select';
        }
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // ── Auth routes ──────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
        path: '/otp',
        builder: (c, s) {
          final email = s.uri.queryParameters['email'] ?? '';
          return OtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/create-password',
        builder: (c, s) {
          final email = s.uri.queryParameters['email'] ?? '';
          return CreatePasswordScreen(email: email);
        },
      ),
      GoRoute(
          path: '/forgot-password',
          builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/template-select',
          builder: (c, s) => const TemplateSelectScreen()),

      // ── Main shell with bottom nav ────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
              path: '/dashboard', builder: (c, s) => const DashboardScreen()),

          // Daily Log tab
          GoRoute(
              path: '/daily-log', builder: (c, s) => const DailyLogScreen()),
          GoRoute(
            path: '/daily-log/add',
            builder: (c, s) => const AddRoutineScreen(),
          ),
          GoRoute(
            path: '/daily-log/edit/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);

              return AddRoutineScreen(
                routineId: id,
              );
            },
          ),
          
          GoRoute(
              path: '/daily-log/customize',
              builder: (c, s) => const CustomizationScreen()),
          GoRoute(
              path: '/daily-log/analytics',
              builder: (c, s) => const AdvancedAnalyticsScreen()),
          GoRoute(
              path: '/daily-log/analytics/charts/edit',
              builder: (c, s) => const ChartEditScreen()),

          // AI Coach tab
          GoRoute(path: '/ai-coach', builder: (c, s) => const AiCoachScreen()),

          // Calendar tab
          GoRoute(path: '/calendar', builder: (c, s) => const CalendarScreen()),

          // Settings tab
          GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
          GoRoute(
              path: '/settings/profile',
              builder: (c, s) => const EditProfileScreen()),
          GoRoute(
              path: '/settings/achievements',
              builder: (c, s) => const AchievementsScreen()),
          GoRoute(
              path: '/settings/notifications',
              builder: (c, s) => const NotificationPrefsScreen()),

          // Focus + Notifications (pushed from dashboard, still within shell)
          GoRoute(
            path: '/focus',
            builder: (c, s) {
              final duration =
                  int.tryParse(s.uri.queryParameters['duration'] ?? '');
              return FocusScreen(presetDuration: duration);
            },
          ),
          GoRoute(
              path: '/notifications',
              builder: (c, s) => const NotificationCenterScreen()),
        ],
      ),

      // Legacy routes for backward compat
      GoRoute(path: '/routines', redirect: (_, __) => '/daily-log'),
      GoRoute(path: '/routines/add', redirect: (_, __) => '/daily-log/add'),
      GoRoute(path: '/ai', redirect: (_, __) => '/ai-coach'),
      GoRoute(path: '/analytics', redirect: (_, __) => '/daily-log/analytics'),
      GoRoute(path: '/profile', redirect: (_, __) => '/settings'),
    ],
  );
});
