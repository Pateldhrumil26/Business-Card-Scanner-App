import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  factory ApiException.fromDioError(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timed out. Please check your network and backend server.',
          statusCode: dioException.response?.statusCode,
        );

      case DioExceptionType.badResponse:
        final response = dioException.response;
        if (response != null && response.data != null) {
          if (response.data is Map<String, dynamic>) {
            final msg = response.data['message'] ??
                response.data['error'] ??
                'Server responded with error (${response.statusCode})';
            return ApiException(
              message: msg.toString(),
              statusCode: response.statusCode,
              details: response.data['errors'],
            );
          }
        }
        return ApiException(
          message: 'Server error with status code ${response?.statusCode}',
          statusCode: response?.statusCode,
        );

      case DioExceptionType.cancel:
        return ApiException(message: 'Request was cancelled.');

      case DioExceptionType.connectionError:
        return ApiException(
          message:
              'Cannot reach the backend server. Please verify the backend is running and the Server URL in Settings is correct.',
        );

      default:
        return ApiException(
          message: dioException.message ?? 'An unexpected network error occurred.',
        );
    }
  }

  @override
  String toString() => message;
}
