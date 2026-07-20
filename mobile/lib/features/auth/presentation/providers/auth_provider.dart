import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/database/database_helper.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/sync/sync_engine.dart';

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
      final activeUserId = await SecureStorageService.getActiveUserId();
      if (activeUserId != null) {
        debugPrint('[AUTH] Token found — switching to DB for user: $activeUserId');
        await DatabaseHelper.switchUser(activeUserId);

        final cachedJson = await SecureStorageService.getCachedUserProfile(activeUserId);
        if (cachedJson != null) {
          try {
            final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
            final user = UserModel.fromJson(decoded);
            state = state.copyWith(user: user, isAuthenticated: true);
            debugPrint('[AUTH] Restored cached session offline for: ${user.email}');
            SyncEngine().syncNow();
          } catch (e) {
            debugPrint('[AUTH] Failed to decode cached profile: $e');
          }
        }
      }

      try {
        final user = await _repository.getMe();
        await DatabaseHelper.switchUser(user.id);
        await SecureStorageService.saveActiveUserId(user.id);
        state = state.copyWith(user: user, isAuthenticated: true);
        await SecureStorageService.saveUserProfile(user.id, jsonEncode(user.toJson()));
        debugPrint('[AUTH] Session refreshed from server: ${user.email}');
        SyncEngine().syncNow();
      } catch (e) {
        debugPrint('[AUTH] Background revalidation failed: $e');
        final isAuthError = e.toString().contains('401') || e.toString().contains('403');
        if (isAuthError) {
          debugPrint('[AUTH] Auth error — clearing session');
          await DatabaseHelper.closeDatabase();
          await SecureStorageService.clearAll();
          state = const AuthState();
        }
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
      await DatabaseHelper.switchUser(user.id);
      await SecureStorageService.saveActiveUserId(user.id);
      await SecureStorageService.saveUserProfile(user.id, jsonEncode(user.toJson()));
      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );
      debugPrint('[AUTH] State updated — isAuthenticated = true');
      debugPrint('[AUTH] Authenticated = ${state.isAuthenticated}');
      SyncEngine().syncNow();
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
      final payloadData = data['data'] as Map<String, dynamic>? ?? {};
      final userJson = payloadData['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        final user = UserModel.fromJson(userJson);
        await DatabaseHelper.switchUser(user.id);
        await SecureStorageService.saveActiveUserId(user.id);
        await SecureStorageService.saveUserProfile(user.id, jsonEncode(user.toJson()));
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
        debugPrint(
            '[AUTH] Registration complete — auto-logged in as ${user.email}');
        SyncEngine().syncNow();
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

  // ── Update Profile ─────────────────────────────────────────────────────────

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? avatar,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = <String, dynamic>{};

      if (firstName != null || lastName != null) {
        final fullName = [firstName ?? '', lastName ?? '']
            .where((s) => s.isNotEmpty)
            .join(' ');
        if (fullName.isNotEmpty) data['name'] = fullName;
      }

      if (email != null) data['email'] = email;
      if (avatar != null) data['avatar'] = avatar;

      await _repository.updateProfile(data);
      final user = await _repository.getMe();
      await SecureStorageService.saveUserProfile(user.id, jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    debugPrint('[AUTH] Logout');
    await _repository.logout();
    await DatabaseHelper.closeDatabase();
    await SecureStorageService.clearAll();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // ── XP / Level helpers ─────────────────────────────────────────────────────

  int get level => (state.user?.xp ?? 0) ~/ 1000 + 1;
  int get nextLevelXp => level * 1000;
  double get xpProgress => ((state.user?.xp ?? 0) % 1000) / 1000.0;

  // ── Error Parsing ──────────────────────────────────────────────────────────

  String _parseError(dynamic e) {
    // Handle DioException (network/HTTP errors)
    if (e.runtimeType.toString().contains('DioException') ||
        e.runtimeType.toString().contains('DioError')) {
      try {
        final dioErr = e as dynamic;
        final statusCode = dioErr.response?.statusCode as int?;
        final responseData = dioErr.response?.data;

        // Extract backend error message if present
        String? backendMsg;
        if (responseData is Map) {
          backendMsg = responseData['error'] as String? ??
              responseData['detail'] as String? ??
              responseData['message'] as String?;
        }

        switch (statusCode) {
          case 400:
            return backendMsg ?? 'Please check your input and try again.';
          case 401:
            return 'Incorrect email or password. Please try again.';
          case 403:
            return 'Account access denied. Contact support if this is unexpected.';
          case 404:
            return 'Account not found. Please register first.';
          case 409:
            return backendMsg ?? 'A conflict occurred. Please try again.';
          case 429:
            return 'Too many attempts. Please wait a moment and try again.';
          case 500:
          case 502:
          case 503:
            return 'Server is temporarily unavailable. Please try again later.';
          case null:
            // No response — network error
            final errType = dioErr.type?.toString() ?? '';
            if (errType.contains('connectTimeout') ||
                errType.contains('receiveTimeout') ||
                errType.contains('sendTimeout')) {
              return 'Connection timed out. Check your internet connection.';
            }
            if (errType.contains('connectionError') ||
                errType.contains('other')) {
              return 'Cannot reach the server. Check your internet connection.';
            }
            return 'Network error. Check your internet connection.';
          default:
            return backendMsg ??
                'Something went wrong (error $statusCode). Please try again.';
        }
      } catch (_) {
        return 'Network error. Check your internet connection.';
      }
    }

    // Handle plain Exception
    if (e is Exception) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('Invalid credentials') ||
          msg.contains('Incorrect') ||
          msg.contains('invalid credentials')) {
        return 'Incorrect email or password. Please try again.';
      }
      if (msg.contains('not found') || msg.contains('does not exist')) {
        return 'Account not found. Please register first.';
      }
      if (msg.contains('already exists') ||
          msg.contains('already registered')) {
        return 'This email is already registered. Try logging in instead.';
      }
      if (msg.contains('not verified')) {
        return 'Email not verified. Please complete OTP verification.';
      }
      if (msg.contains('tokens') || msg.contains('token')) {
        return 'Authentication failed. Please try again.';
      }
      if (msg.contains('internet') ||
          msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('socket')) {
        return 'Check your internet connection and try again.';
      }
      // Return the message but strip technical prefixes
      if (msg.length < 120) return msg;
      return 'Something went wrong. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
