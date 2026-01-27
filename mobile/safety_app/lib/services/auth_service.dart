// lib/services/auth_service.dart
// Complete authentication service with email verification support
import 'package:dio/dio.dart';
import 'package:safety_app/models/role_info.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Authentication Service - handles all auth-related API calls
class AuthService {
  final DioClient _dioClient = DioClient();
  final SecureStorageService _storage = SecureStorageService();

  /// Send OTP to phone number
  Future<OtpResponse> sendVerificationCode(String phoneNumber) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.sendVerificationCode,
        data: {'phone_number': phoneNumber},
      );

      return OtpResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error sending verification code: $e');
      rethrow;
    }
  }

  /// Verify phone number with OTP
  Future<OtpResponse> verifyPhone({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.verifyPhone,
        data: {
          'phone_number': phoneNumber,
          'verification_code': verificationCode,
        },
      );

      return OtpResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error verifying phone: $e');
      rethrow;
    }
  }

  /// Check if email is available
  Future<EmailCheckResponse> checkEmail(String email) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.checkEmail,
        queryParameters: {'email': email},
      );

      return EmailCheckResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error checking email: $e');
      rethrow;
    }
  }

  /// Check phone
  Future<PhoneCheckResponse> checkPhone(String phoneNumber) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.checkPhone,
        queryParameters: {'phone_number': phoneNumber},
      );
      return PhoneCheckResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error checking phone: $e');
      rethrow;
    }
  }

  /// Register new user - creates pending user and sends email OTP
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.register,
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'phone_number': phoneNumber,
        },
      );

      print('📦 Registration Response:');
      print(response.data);

      // Registration creates pending user and returns success message
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error registering user: $e');
      rethrow;
    }
  }

  /// Verify email OTP - converts pending user to actual user
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String otp,
  }) async {
    try {
      print('📧 Verifying email OTP for: $email');
      print('🔑 OTP: $otp');

      // Use query parameters instead of body
      final response = await _dioClient.post(
        ApiEndpoints.verifyEmail,
        queryParameters: {'email': email, 'otp': otp},
      );

      print('✅ Email verified successfully');
      print('📦 Response: ${response.data}');

      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error verifying email: $e');

      if (e is DioException) {
        if (e.response?.statusCode == 400) {
          final detail = e.response?.data['detail'];
          final message = detail is String ? detail : 'Invalid OTP';
          throw Exception(message);
        } else if (e.response?.statusCode == 404) {
          throw Exception('No pending registration found');
        } else if (e.response?.statusCode == 429) {
          throw Exception('Too many attempts. Please try again later.');
        }
      }

      rethrow;
    }
  }

  /// Resend email OTP
  Future<Map<String, dynamic>> resendEmailOTP({required String email}) async {
    try {
      print('📧 Resending email OTP for: $email');

      // Use query parameters instead of body
      final response = await _dioClient.post(
        ApiEndpoints.resendEmailOTP,
        queryParameters: {'email': email},
      );

      print('✅ Email OTP resent successfully');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error resending email OTP: $e');

      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          throw Exception('No pending registration found for this email');
        } else if (e.response?.statusCode == 429) {
          throw Exception('Please wait before requesting another OTP');
        }
      }

      rethrow;
    }
  }

  /// Login user
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );

      print('📦 Login Response:');
      print(response.data);

      final authResponse = AuthResponseModel.fromJson(response.data);

      // ⚠️ Only save tokens and user if they exist
      if (authResponse.token != null) {
        await _storage.saveAccessToken(authResponse.token!.accessToken);
        if (authResponse.token!.refreshToken != null) {
          await _storage.saveRefreshToken(authResponse.token!.refreshToken!);
        }
      }

      if (authResponse.user != null) {
        await _storage.saveUserData(authResponse.user!.toJson());
        print('✅ Login successful');
        print('👤 User: ${authResponse.user!.fullName}');
        print(
          '🎭 Roles: ${authResponse.user!.roles.map((r) => r.roleName).join(", ")}',
        );
      } else {
        print('ℹ️ Login response received, user object missing.');
      }

      return authResponse;
    } catch (e) {
      print('❌ Error logging in: $e');

      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw Exception('Invalid email or password');
        } else if (e.response?.statusCode == 404) {
          throw Exception('User not found');
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          throw Exception('Connection timeout. Please try again.');
        } else if (e.type == DioExceptionType.connectionError) {
          throw Exception('Network error. Please check your connection.');
        }
      }

      rethrow;
    }
  }

  /// Refresh access token using refresh token
  Future<String> refreshAccessToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('No refresh token available');
      }

      final response = await _dioClient.post(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );

      print('🔄 Token Refreshed');

      // Backend returns TokenResponse
      final tokenData = response.data;
      final newAccessToken = tokenData['access_token'] as String;
      final newRefreshToken = tokenData['refresh_token'] as String?;

      // Save new tokens
      await _storage.saveAccessToken(newAccessToken);
      if (newRefreshToken != null) {
        await _storage.saveRefreshToken(newRefreshToken);
      }

      return newAccessToken;
    } catch (e) {
      print('❌ Error refreshing token: $e');

      // If refresh fails, clear all data and force re-login
      await logout();
      throw Exception('Session expired. Please login again.');
    }
  }

  /// Get current user from storage
  Future<UserModel?> getCurrentUser() async {
    try {
      final userData = await _storage.getUserData();
      if (userData != null) {
        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final token = await _storage.getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    print('🔄 Starting logout process...');

    try {
      // Step 1: Get refresh token
      final refreshToken = await _storage.getRefreshToken();
      print('🔑 Refresh token found: ${refreshToken != null}');

      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          print('📤 Attempting to revoke token on backend...');
          print('🔗 Endpoint: ${ApiEndpoints.logout}');

          final response = await _dioClient.post(
            ApiEndpoints.logout,
            data: {'refresh_token': refreshToken},
          );

          print('✅ Backend response: ${response.statusCode}');
          print('📥 Response data: ${response.data}');
          print('✅ Token revoked on backend successfully');
        } on DioException catch (e) {
          if (e.response?.statusCode == 404 || e.response?.statusCode == 400) {
            print('ℹ️ Token already invalid or revoked');
          } else {
            print(
              '⚠️ Backend token revocation failed: ${e.response?.statusCode}',
            );
            print('   Response data: ${e.response?.data}');
            print('   Error message: ${e.message}');
          }
          print('   Continuing with local logout...');
        } catch (e) {
          print('⚠️ Unexpected error during backend revocation: $e');
          print('   Continuing with local logout...');
        }
      } else {
        print('ℹ️ No refresh token found, skipping backend revocation');
      }

      // Step 2: Always clear local data
      print('🗑️ Clearing local storage...');
      await _storage.clearAll();
      print('✅ Local storage cleared successfully');
      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Critical error during logout: $e');

      // Force clear as last resort
      try {
        print('🔄 Attempting force clear of storage...');
        await _storage.clearAll();
        print('✅ Force clear successful');
      } catch (clearError) {
        print('❌ Fatal: Could not clear storage: $clearError');
      }
    }
  }

  /// Logout from all devices
  Future<void> logoutAllDevices() async {
    print('🔄 Logging out from all devices...');

    try {
      try {
        await _dioClient.post(ApiEndpoints.logoutAll);
        print('✅ All tokens revoked on backend');
      } on DioException catch (e) {
        print('⚠️ Failed to revoke all tokens: ${e.response?.statusCode}');
        print('   Continuing with local logout...');
      }

      await _storage.clearAll();
      print('✅ Logged out from all devices - local data cleared');
    } catch (e) {
      print('❌ Error during logout-all: $e');

      try {
        await _storage.clearAll();
      } catch (clearError) {
        print('❌ Failed to clear storage: $clearError');
      }
    }
  }

  /// Get current user from API (when token exists)
  Future<UserModel> fetchCurrentUser() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.me);
      final user = UserModel.fromJson(response.data);

      // Update stored user data
      await _storage.saveUserData(user.toJson());

      print('✅ Current user fetched and updated');
      return user;
    } catch (e) {
      print('❌ Error fetching current user: $e');
      rethrow;
    }
  }

  /// Fetch all roles from backend
  Future<List<RoleInfo>> fetchRoles() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.getRoles);

      final roles = (response.data as List)
          .map((json) => RoleInfo.fromJson(json))
          .toList();

      print('✅ Fetched ${roles.length} roles');
      return roles;
    } catch (e) {
      print('❌ Error fetching roles: $e');
      rethrow;
    }
  }

  /// Assign role to current user
  Future<void> selectRole(int roleId) async {
    try {
      await _dioClient.post(ApiEndpoints.selectRole, data: {"role_id": roleId});

      print('✅ Role assigned successfully');

      // Refresh user after role assignment
      final updatedUser = await fetchCurrentUser();
      await _storage.saveUserData(updatedUser.toJson());
    } catch (e) {
      print('❌ Error selecting role: $e');
      rethrow;
    }
  }
}
