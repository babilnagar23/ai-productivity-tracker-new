import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../storage/secure_storage.dart';

/// Returns the correct base URL depending on the platform.
///
/// Web (Chrome)         → http://localhost:8000/api
/// Android Emulator     → http://10.0.2.2:8000/api
/// Physical Device      → change _emulatorUrl below to your machine's LAN IP
///                        e.g. http://192.168.1.5:8000/api
const String _emulatorUrl = 'http://10.0.2.2:8000/api';
const String _webUrl = 'http://localhost:8000/api';

String get kBaseUrl {
  if (kIsWeb) {
    debugPrint('[API] Base URL: $_webUrl (web)');
    return _webUrl;
  }
  // On Android emulator the loopback alias is 10.0.2.2.
  // On a physical device you need your machine's LAN IP.
  debugPrint('[API] Base URL: $_emulatorUrl (native)');
  return _emulatorUrl;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(_AuthInterceptor(_dio));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[API] $obj'),
    ));
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this.dio);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await SecureStorageService.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    debugPrint('[API] Request: ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[API] Response: ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    debugPrint('[API] Error: ${err.response?.statusCode} ${err.requestOptions.path}');
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await SecureStorageService.getRefreshToken();
        if (refreshToken == null) {
          await SecureStorageService.clearAll();
          handler.next(err);
          return;
        }

        final response = await dio.post(
          '/auth/token/refresh',
          data: {'refresh': refreshToken},
          options: Options(headers: {'Authorization': null}),
        );

        final newToken = response.data['access'] as String;
        await SecureStorageService.saveTokens(
          accessToken: newToken,
          refreshToken: refreshToken,
        );

        // Retry original request
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        final retryResponse = await dio.fetch(err.requestOptions);
        handler.resolve(retryResponse);
      } catch (_) {
        await SecureStorageService.clearAll();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}

// Singleton accessor
final apiClient = ApiClient();
