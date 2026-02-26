import 'dart:math';

import 'package:dio/dio.dart';
import 'package:safety_app/core/network/api_endpoints.dart';
import 'package:safety_app/core/storage/secure_storage_service.dart';
import 'package:safety_app/services/native_back_tap_service.dart';

class DioClient {
  late final Dio _dio;
  final SecureStorageService _storage = SecureStorageService();
  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})>
  _requestQueue = [];

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
        // In onRequest interceptor, add more detailed logging:
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await _storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            print('🔐 Token attached to ${options.method} ${options.path}');
            print('   Token length: ${token.length}');
            print(
              '   Token preview: ${token.substring(0, min(20, token.length))}...',
            );
          } else {
            print('⚠️ NO TOKEN FOUND for ${options.method} ${options.path}');
          }
          print('📤 Request: ${options.method} ${options.path}');
          print('   Headers: ${options.headers}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print(
            '✅ Response: ${response.statusCode} ${response.requestOptions.path}',
          );
          return handler.next(response);
        },
        onError: (error, handler) async {
          print('❌ Error: ${error.message}');
          print('📥 Response data: ${error.response?.data}');
          print('📥 Response status: ${error.response?.statusCode}');

          // Handle 401 Unauthorized errors (token expired)
          if (error.response?.statusCode == 401) {
            print('🔐 Token expired or invalid. Attempting refresh...');

            // Check if we're already refreshing
            if (_isRefreshing) {
              // Queue this request to be retried after refresh
              print('⏳ Already refreshing token, queuing request...');
              _requestQueue.add((
                options: error.requestOptions,
                handler: handler,
              ));
              return;
            }

            _isRefreshing = true;

            try {
              // Try to refresh the token
              print('🔄 Refreshing access token...');

              final refreshToken = await _storage.getRefreshToken();
              if (refreshToken == null || refreshToken.isEmpty) {
                print('❌ No refresh token available');
                await _storage.logout();
                throw Exception('Session expired. Please login again.');
              }

              print('🔑 Refresh token found, length: ${refreshToken.length}');

              // Make refresh request using a new Dio instance to avoid circular reference
              final refreshDio = Dio(
                BaseOptions(
                  baseUrl: ApiEndpoints.baseUrl,
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                ),
              );

              final refreshResponse = await refreshDio.post(
                ApiEndpoints.refresh,
                data: {'refresh_token': refreshToken},
              );

              if (refreshResponse.statusCode == 200) {
                final tokenData = refreshResponse.data;
                final newAccessToken = tokenData['access_token'] as String;
                final newRefreshToken = tokenData['refresh_token'] as String?;

                // Save new tokens
                await _storage.saveAccessToken(newAccessToken);
                if (newRefreshToken != null) {
                  await _storage.saveRefreshToken(newRefreshToken);
                }

                // ✅ Keep SharedPreferences in sync so BackTapService can
                // fire SOS via HTTP even when the Flutter app is killed.
                // This must happen every time the token rotates.
                await NativeBackTapService.instance.saveToken(newAccessToken);

                print('✅ Token refreshed successfully');
                print('🔑 New access token length: ${newAccessToken.length}');

                _dio.options.headers['Authorization'] =
                    'Bearer $newAccessToken';
                // Update the original request with new token
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';

                // Retry the original request
                print(
                  '🔄 Retrying original request: ${error.requestOptions.method} ${error.requestOptions.path}',
                );
                final response = await _dio.request(
                  error.requestOptions.path,
                  data: error.requestOptions.data,
                  queryParameters: error.requestOptions.queryParameters,
                  options: Options(
                    method: error.requestOptions.method,
                    headers: error.requestOptions.headers,
                  ),
                );

                // Complete the original handler with successful response
                print('✅ Retry successful: ${response.statusCode}');
                handler.resolve(response);

                // Process queued requests
                _processQueuedRequests(newAccessToken);
              } else {
                print(
                  '❌ Token refresh failed with status: ${refreshResponse.statusCode}',
                );
                await _storage.logout();
                throw Exception('Session expired. Please login again.');
              }
            } catch (refreshError) {
              print('❌ Error during token refresh: $refreshError');
              // Do NOT clear storage here for non-auth errors — a network blip
              // would log the user out permanently. Storage is only cleared
              // inside refreshAccessToken() when the server returns 401/403.
              // Pass the original error through
              handler.next(error);
            } finally {
              _isRefreshing = false;
            }
          } else {
            // For other errors, just pass them through
            handler.next(error);
          }
        },
      ),
    );
  }

  /// Process queued requests after token refresh
  void _processQueuedRequests(String newAccessToken) {
    if (_requestQueue.isEmpty) return;

    print('🔄 Processing ${_requestQueue.length} queued requests...');

    final queueCopy = List.of(_requestQueue);
    _requestQueue.clear();

    for (final item in queueCopy) {
      try {
        item.options.headers['Authorization'] = 'Bearer $newAccessToken';
        print(
          '🔄 Retrying queued request: ${item.options.method} ${item.options.path}',
        );

        _dio
            .request(
              item.options.path,
              data: item.options.data,
              queryParameters: item.options.queryParameters,
              options: Options(
                method: item.options.method,
                headers: item.options.headers,
              ),
            )
            .then((response) {
              print('✅ Queued request succeeded: ${response.statusCode}');
              item.handler.resolve(response);
            })
            .catchError((error) {
              print('❌ Queued request failed: $error');
              item.handler.reject(error as DioException);
            });
      } catch (e) {
        print('❌ Error processing queued request: $e');
        item.handler.next(DioException(requestOptions: item.options, error: e));
      }
    }
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

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

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

      case DioExceptionType.unknown:
        return Exception('Network error. Please check your connection.');

      default:
        return Exception('Something went wrong. Please try again.');
    }
  }

  // Add this method to your DioClient class in dio_client.dart
  /// Update the default headers with new authorization token
  void updateAuthorizationHeader(String newToken) {
    _dio.options.headers['Authorization'] = 'Bearer $newToken';
    print('✅ DioClient headers updated with new token');
    print(
      '   Token preview: ${newToken.substring(0, min(20, newToken.length))}...',
    );
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
        // This should be handled by the interceptor now
        return Exception(
          errorMessage ?? 'Session expired. Please login again.',
        );
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