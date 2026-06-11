import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform-aware token storage.
/// Web  → SharedPreferences (flutter_secure_storage uses WebCrypto which
///         throws OperationError in some browser contexts).
/// Mobile/Desktop → FlutterSecureStorage (encrypted keychain/keystore).
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userEmailKey = 'user_email';

  // ── Write ──────────────────────────────────────────────────────────────────

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    debugPrint('[STORAGE] Save tokens (web=$kIsWeb)');
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);
    } else {
      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      ]);
    }
    debugPrint('[STORAGE] Tokens saved successfully');
  }

  static Future<void> saveUserEmail(String email) async {
    debugPrint('[STORAGE] Save user email');
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userEmailKey, email);
    } else {
      await _storage.write(key: _userEmailKey, value: email);
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  static Future<String?> getAccessToken() async {
    String? token;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_accessTokenKey);
    } else {
      token = await _storage.read(key: _accessTokenKey);
    }
    debugPrint('[STORAGE] Read access token: ${token != null ? "found" : "null"}');
    return token;
  }

  static Future<String?> getRefreshToken() async {
    String? token;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_refreshTokenKey);
    } else {
      token = await _storage.read(key: _refreshTokenKey);
    }
    debugPrint('[STORAGE] Read refresh token: ${token != null ? "found" : "null"}');
    return token;
  }

  static Future<String?> getUserEmail() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    }
    return _storage.read(key: _userEmailKey);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    debugPrint('[STORAGE] Clear all tokens');
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userEmailKey);
    } else {
      await _storage.deleteAll();
    }
    debugPrint('[STORAGE] Tokens cleared');
  }

  static Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static const _userProfileKey = 'cached_user_profile';

  static Future<void> saveUserProfile(String profileJson) async {
    await saveFlag(_userProfileKey, profileJson);
  }

  static Future<String?> getCachedUserProfile() async {
    return await getFlag(_userProfileKey);
  }

  // ── Generic flags ──────────────────────────────────────────────────────────

  static Future<void> saveFlag(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  static Future<String?> getFlag(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return _storage.read(key: key);
  }
}
