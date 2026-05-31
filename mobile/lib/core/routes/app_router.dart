import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/create_password_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../shell/main_shell.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/routines/presentation/screens/routine_tracker_screen.dart';
import '../../features/routines/presentation/screens/add_routine_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_chat_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

/// A [ChangeNotifier] that bridges Riverpod auth state into GoRouter's
/// [refreshListenable]. When auth state changes, GoRouter re-evaluates
/// the redirect function automatically.
class _AuthChangeNotifier extends ChangeNotifier {
  final Ref _ref;
  _AuthChangeNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, __) {
      debugPrint('[ROUTER] Auth state changed — notifying router');
      notifyListeners();
    });
  }
}

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
          location.startsWith('/forgot-password');

      if (!isLoggedIn && !isAuthRoute) {
        debugPrint('[ROUTER] Redirect triggered → /login');
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        debugPrint('[ROUTER] Redirect triggered → /dashboard');
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

      // ── Main shell with bottom nav ────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
              path: '/dashboard',
              builder: (c, s) => const DashboardScreen()),
          GoRoute(
              path: '/routines',
              builder: (c, s) => const RoutineTrackerScreen()),
          GoRoute(
              path: '/routines/add',
              builder: (c, s) => const AddRoutineScreen()),
          GoRoute(
            path: '/routines/edit/:id',
            builder: (c, s) => AddRoutineScreen(
                routineId:
                    int.tryParse(s.pathParameters['id'] ?? '')),
          ),
          GoRoute(path: '/ai', builder: (c, s) => const AiChatScreen()),
          GoRoute(
              path: '/analytics',
              builder: (c, s) => const AnalyticsScreen()),
          GoRoute(
              path: '/calendar',
              builder: (c, s) => const CalendarScreen()),
          GoRoute(
              path: '/profile',
              builder: (c, s) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
