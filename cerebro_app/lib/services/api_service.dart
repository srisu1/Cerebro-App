/// Central HTTP client using Dio with JWT token management.
/// Uses SharedPreferences for token storage (macOS Keychain has issues).

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: Duration(milliseconds: AppConstants.apiTimeout),
        receiveTimeout: Duration(milliseconds: AppConstants.apiTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(AppConstants.accessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Let Dio set the correct Content-Type for FormData (multipart)
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Auto-refresh token on 401 (but NOT for auth endpoints)
          final path = error.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/refresh');

          if (error.response?.statusCode == 401 && !isAuthEndpoint) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry the failed request
              final retryResponse = await _dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Refresh the access token using the refresh token
  Future<bool> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final refreshToken = prefs.getString(AppConstants.refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await Dio().post(
        '${AppConstants.apiBaseUrl}/auth/refresh',
        queryParameters: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        await prefs.setString(
          AppConstants.accessTokenKey,
          response.data['access_token'],
        );
        await prefs.setString(
          AppConstants.refreshTokenKey,
          response.data['refresh_token'],
        );
        return true;
      }
    } catch (e) {
      // Refresh failed - clear tokens so user gets redirected to login
      await prefs.remove(AppConstants.accessTokenKey);
      await prefs.remove(AppConstants.refreshTokenKey);
    }
    return false;
  }


  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    return _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}
