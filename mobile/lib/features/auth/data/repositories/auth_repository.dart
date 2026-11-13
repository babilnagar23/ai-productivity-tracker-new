import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

// ignore: unused_import
export 'package:dio/dio.dart' show DioException;

class AuthRepository {
  final Dio _dio = apiClient.dio;

  Future<bool> checkEmail(String email) async {
    debugPrint('[AUTH] checkEmail → $email');
    final response = await _dio.post(
      ApiEndpoints.checkEmail,
      data: {'email': email},
    );
    final data = response.data as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>? ?? {};
    return payload['available'] == true;
  }

  /// Direct OTP-free registration.
  /// Backend expects: { email, password, confirm_password, [name] }
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String confirmPassword,
    String? name,
  }) async {
    debugPrint('[AUTH] register → $email');
    final response = await _dio.post(
      ApiEndpoints.register,
      data: {
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        if (name != null) 'name': name,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final payloadData = data['data'] as Map<String, dynamic>? ?? {};
    final access = payloadData['token'] as String?;
    final refresh = payloadData['refresh'] as String?;
    if (access != null && refresh != null) {
      await SecureStorageService.saveTokens(
        accessToken: access,
        refreshToken: refresh,
      );
      await SecureStorageService.saveUserEmail(email);
      debugPrint('[JWT] Tokens saved after registration');
    }
    return data;
  }

  Future<void> sendOtp(String email) async {
    debugPrint('[AUTH] sendOtp → $email');
    await _dio.post(ApiEndpoints.sendOtp, data: {'email': email});
  }

  Future<void> verifyOtp(String email, String otp) async {
    debugPrint('[AUTH] verifyOtp → $email');
    await _dio.post(ApiEndpoints.verifyOtp, data: {'email': email, 'otp': otp});
  }

  /// Step 3 of OTP registration.
  /// Backend expects: { email, password, confirm_password }  (snake_case)
  Future<Map<String, dynamic>> completeRegistration({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    debugPrint('[AUTH] completeRegistration → $email');
    final response = await _dio.post(
      ApiEndpoints.completeRegistration,
      data: {
        'email': email,
        'password': password,
        'confirm_password': confirmPassword, // ← backend expects snake_case
      },
    );
    final data = response.data as Map<String, dynamic>;
    final payloadData = data['data'] as Map<String, dynamic>? ?? {};
    // Registration also returns tokens — save them so the user is logged in
    final access = payloadData['token'] as String?;
    final refresh = payloadData['refresh'] as String?;
    if (access != null && refresh != null) {
      await SecureStorageService.saveTokens(
        accessToken: access,
        refreshToken: refresh,
      );
      await SecureStorageService.saveUserEmail(email);
      debugPrint('[JWT] Tokens saved after registration');
    }
    return data;
  }

  /// Login returns: { success, access, refresh, token, user: {...} }
  Future<UserModel> login(String email, String password) async {
    debugPrint('[AUTH] Login started → $email');
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      final payloadData = data['data'] as Map<String, dynamic>? ?? {};

      final access = payloadData['token'] as String?;
      final refresh = payloadData['refresh'] as String?;

      if (access == null || refresh == null) {
        throw Exception('Server did not return tokens');
      }

      await SecureStorageService.saveTokens(
        accessToken: access,
        refreshToken: refresh,
      );
      await SecureStorageService.saveUserEmail(email);
      debugPrint('[JWT] Access token saved');
      debugPrint('[JWT] Refresh token saved');

      final userJson = payloadData['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        throw Exception('Server did not return user data');
      }

      final user = UserModel.fromJson(userJson);
      debugPrint('[AUTH] Login success — user: ${user.email}');
      return user;
    } on DioException {
      // Re-throw DioException so _parseError in auth_provider can handle it
      rethrow;
    }
  }

  /// GET /auth/me — returns { success, data: { id, name, email, ... } }
  Future<UserModel> getMe() async {
    debugPrint('[AUTH] getMe');
    final response = await _dio.get(ApiEndpoints.me);
    final body = response.data as Map<String, dynamic>;
    // Backend wraps in { success, data: {...} }
    final userJson = body['data'] as Map<String, dynamic>? ?? body;
    return UserModel.fromJson(userJson);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    debugPrint('[AUTH] updateProfile');
    await _dio.patch(ApiEndpoints.updateProfile, data: data);
  }

  Future<void> forgotPassword(String email) async {
    debugPrint('[AUTH] forgotPassword → $email');
    await _dio.post(ApiEndpoints.forgotPassword, data: {'email': email});
  }

  Future<void> logout() async {
    debugPrint('[AUTH] logout — clearing tokens');
    await SecureStorageService.clearAll();
  }
}
