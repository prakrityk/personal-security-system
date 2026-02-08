import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import 'api_endpoints.dart';

class DioClient {
  late final Dio _dio;
  final SecureStorageService _storage = SecureStorageService();

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          // 'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await _storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          print('Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('Response: ${response.statusCode} ${response.data}');
          return handler.next(response);
        },
        onError: (error, handler) {
          print('Error: ${error.message}');
          print('Response: ${error.response?.data}');
          return handler.next(error);
        },
      ),
    );
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST multipart/form-data (for file uploads)
 // POST multipart/form-data (for file uploads)
Future<Response> postFormData(
  String path, {
  required dynamic data, // file and any other fields
  Map<String, dynamic>? queryParameters, // query params like user_id, sample_number
}) async {
  try {
    final requestData = data is FormData ? data : FormData.fromMap(data);

    // Make POST request
    final response = await _dio.post(
      path,
      data: requestData,
      queryParameters: queryParameters, // query params
      options: Options(
        contentType: 'multipart/form-data', // Important!
      ),
    );

    return response;
  } on DioException catch (e) {
    throw _handleError(e); // your existing error handler
  }
}


  // Error handler
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please try again.');

      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);

      case DioExceptionType.cancel:
        return Exception('Request cancelled');

      default:
        return Exception('Network error. Please check your connection.');
    }
  }

  Exception _handleResponseError(Response? response) {
    if (response == null) {
      return Exception('Unknown error occurred');
    }

    // Try to extract error message from response
    String? errorMessage;
    if (response.data is Map) {
      errorMessage = response.data['detail'] ?? response.data['message'];
    } else if (response.data is String) {
      errorMessage = response.data;
    }

    switch (response.statusCode) {
      case 400:
        return Exception(errorMessage ?? 'Bad request');
      case 401:
        return Exception(errorMessage ?? 'Unauthorized. Please login again.');
      case 403:
        return Exception(errorMessage ?? 'Access forbidden');
      case 404:
        return Exception(errorMessage ?? 'Resource not found');
      case 429:
        return Exception(
          errorMessage ?? 'Too many requests. Please try again later.',
        );
      case 500:
        return Exception(
          errorMessage ?? 'Server error. Please try again later.',
        );
      default:
        return Exception(errorMessage ?? 'Something went wrong');
    }
  }
}
