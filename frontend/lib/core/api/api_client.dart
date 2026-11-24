import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'api_exception.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio _dio;

  /// Determine appropriate default base URL based on platform
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return AppConstants.defaultLocalhostBaseUrl; // http://localhost:5050/api for Chrome/Edge web
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AppConstants.defaultEmulatorBaseUrl; // http://10.0.2.2:5050/api for Android Emulator
    }
    return AppConstants.defaultLocalhostBaseUrl; // Windows desktop, macOS, Linux, iOS Simulator
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        connectTimeout: const Duration(seconds: AppConstants.connectTimeoutSeconds),
        receiveTimeout: const Duration(seconds: AppConstants.receiveTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add logging and auth token interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();

          // Dynamically read custom server URL if configured by user
          final customUrl = prefs.getString(AppConstants.baseUrlKey);
          if (customUrl != null && customUrl.trim().isNotEmpty) {
            options.baseUrl = customUrl.trim();
          } else {
            options.baseUrl = defaultBaseUrl;
          }

          // Add JWT Token if available
          final token = prefs.getString(AppConstants.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) {
          final customException = ApiException.fromDioError(e);
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: e.type,
              error: customException,
              message: customException.message,
            ),
          );
        },
      ),
    );
  }

  Dio get dio => _dio;

  // Convenience HTTP methods
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete(path, data: data, queryParameters: queryParameters, options: options);
  }

  /// Update the base URL dynamically
  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }
}
