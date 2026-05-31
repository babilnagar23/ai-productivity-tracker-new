import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    _init();
  }

  /// On app start: check for a stored token and restore session.
  Future<void> _init() async {
    debugPrint('[AUTH] Initialising — checking stored tokens');
    final hasToken = await SecureStorageService.hasTokens();
    if (hasToken) {
      debugPrint('[AUTH] Token found — fetching user profile');
      try {
        final user = await _repository.getMe();
        state = state.copyWith(user: user, isAuthenticated: true);
        debugPrint('[AUTH] Session restored — ${user.email}');
      } catch (e) {
        debugPrint('[AUTH] Session restore failed: $e — clearing tokens');
        await SecureStorageService.clearAll();
      }
    } else {
      debugPrint('[AUTH] No stored token — user must log in');
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    debugPrint('[AUTH] Login started');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.login(email, password);
      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );
      debugPrint('[AUTH] State updated — isAuthenticated = true');
      debugPrint('[AUTH] Authenticated = ${state.isAuthenticated}');
      return true;
    } catch (e) {
      debugPrint('[AUTH] Login failed: $e');
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  // ── OTP Registration ───────────────────────────────────────────────────────

  Future<void> sendOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendOtp(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      rethrow;
    }
  }

  Future<void> verifyOtp(String email, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.verifyOtp(email, otp);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      rethrow;
    }
  }

  /// Complete registration — backend creates account + returns JWT.
  /// After this succeeds the user is logged in automatically.
  Future<bool> completeRegistration({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repository.completeRegistration(
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );
      // If the backend returned a user object, parse it and mark authenticated
      final userJson = data['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        final user = UserModel.fromJson(userJson);
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
        debugPrint('[AUTH] Registration complete — auto-logged in as ${user.email}');
      } else {
        state = state.copyWith(isLoading: false);
      }
      return true;
    } catch (e) {
      debugPrint('[AUTH] completeRegistration failed: $e');
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  // ── Forgot Password ────────────────────────────────────────────────────────

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.forgotPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      rethrow;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    debugPrint('[AUTH] Logout');
    await _repository.logout();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // ── Error Parsing ──────────────────────────────────────────────────────────

  String _parseError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('Invalid credentials')) return 'Invalid email or password.';
      if (msg.contains('not found')) return 'Account not found.';
      if (msg.contains('already exists')) return 'Email already registered.';
      if (msg.contains('not verified')) return 'Email not verified. Please complete OTP verification.';
      return msg.replaceFirst('Exception: ', '');
    }
    return 'Something went wrong. Try again.';
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
