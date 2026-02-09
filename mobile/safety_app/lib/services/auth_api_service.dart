// lib/services/auth_api_service.dart
// Complete authentication service with email verification support
import 'package:dio/dio.dart';
import 'package:safety_app/models/role_info.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Authentication Service - handles all auth-related API calls
class AuthApiService {
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

  // ============================================================================
  // ✅ NEW: GET EMAIL BY PHONE NUMBER (for Firebase fallback login)
  // ============================================================================

  /// Fetch user's email by phone number
  /// Used for automatic Firebase fallback login after password reset
  /// Returns null if phone not found or on error
  Future<String?> getEmailByPhone(String phoneNumber) async {
    try {
      print('📧 Fetching email for phone: $phoneNumber');
      
      final response = await _dioClient.get(
        ApiEndpoints.checkPhone,
        queryParameters: {'phone_number': phoneNumber},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        
        // Check if user exists and has email
        if (data['exists'] == true && data['email'] != null) {
          print('✅ Found email: ${data['email']}');
          return data['email'] as String;
        }
      }
      
      print('⚠️ No email found for phone: $phoneNumber');
      return null;
      
    } catch (e) {
      print('❌ Error fetching email by phone: $e');
      return null;
    }
  }

  // ============================================================================
  // END OF NEW METHOD
  // ============================================================================

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

  // ============================================================================
  // 🔥 NEW: FIREBASE REGISTRATION METHOD
  // ============================================================================

  /// Complete registration with Firebase token
  /// This is called AFTER phone + email are verified in Firebase
  /// Sends Firebase token to backend which verifies it and creates the user
  Future<AuthResponseModel> completeFirebaseRegistration({
    required String firebaseToken,
    required String fullName,
    required String password,
  }) async {
    try {
      print('🔥 Completing Firebase registration...');
      print('📝 Full Name: $fullName');

      final response = await _dioClient.post(
        ApiEndpoints.completeFirebaseRegistration, 
        data: {
          'firebase_token': firebaseToken,
          'full_name': fullName,
          'password': password,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 180),
          receiveTimeout: const Duration(seconds: 180),
        ),
      );

      print('✅ Firebase registration completed');
      print('📦 Response: ${response.data}');

      final authResponse = AuthResponseModel.fromJson(response.data);

      // Save tokens to secure storage
      if (authResponse.token != null) {
        await _storage.saveAccessToken(authResponse.token!.accessToken);
        if (authResponse.token!.refreshToken != null) {
          await _storage.saveRefreshToken(authResponse.token!.refreshToken!);
        }
      }

      // Save user data to secure storage
      if (authResponse.user != null) {
        await _storage.saveUserData(authResponse.user!.toJson());
        print('✅ User registered and tokens saved');
        print('👤 User: ${authResponse.user!.fullName}');
        print('📧 Email: ${authResponse.user!.email}');
        print('📱 Phone: ${authResponse.user!.phoneNumber}');
      }

      return authResponse;
    } catch (e) {
      print('❌ Error completing Firebase registration: $e');

      if (e is DioException) {
        if (e.response?.statusCode == 400) {
          final detail = e.response?.data['detail'];
          throw Exception(detail ?? 'Invalid Firebase token');
        } else if (e.response?.statusCode == 409) {
          throw Exception('User already exists with this email or phone number');
        } else if (e.response?.statusCode == 401) {
          throw Exception('Firebase token verification failed');
        }
      }

      rethrow;
    }
  }

  // ============================================================================
  // END OF FIREBASE REGISTRATION METHOD
  // ============================================================================

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
          throw Exception('Too many requests. Please wait before trying again.');
        }
      }

      rethrow;
    }
  }

  /// Login user
  Future<AuthResponseModel> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      print('🔐 Logging in with phone: $phoneNumber');

      final response = await _dioClient.post(
        ApiEndpoints.login,
        data: {
          'phone_number': phoneNumber,
          'password': password,
        },
      );

      print('✅ Login successful');

      final authResponse = AuthResponseModel.fromJson(response.data);

      // Save tokens and user data
      if (authResponse.token != null) {
        await _storage.saveAccessToken(authResponse.token!.accessToken);
        if (authResponse.token!.refreshToken != null) {
          await _storage.saveRefreshToken(authResponse.token!.refreshToken!);
        }
      }

      if (authResponse.user != null) {
        await _storage.saveUserData(authResponse.user!.toJson());
        print('✅ User data saved');
      }

      return authResponse;
    } catch (e) {
      print('❌ Error logging in: $e');

      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw Exception('Invalid phone number or password');
        } else if (e.response?.statusCode == 403) {
          throw Exception('Account is disabled');
        }
      }

      rethrow;
    }
  }

  // ============================================================================
  // 🔥 FIREBASE LOGIN (after password reset)
  // ============================================================================

  /// Firebase login - used when normal login fails after password reset
  /// Verifies Firebase token, syncs password, and issues JWTs
  Future<AuthResponseModel> firebaseLogin({
    required String firebaseToken,
    required String password,
  }) async {
    try {
      print('🔥 Logging in via Firebase (post password reset)...');

      final response = await _dioClient.post(
        ApiEndpoints.firebaseLogin,
        data: {
          'firebase_token': firebaseToken,
          'password': password,
        },
      );

      print('✅ Firebase login successful');

      final authResponse = AuthResponseModel.fromJson(response.data);

      // Save tokens and user data
      if (authResponse.token != null) {
        await _storage.saveAccessToken(authResponse.token!.accessToken);
        if (authResponse.token!.refreshToken != null) {
          await _storage.saveRefreshToken(authResponse.token!.refreshToken!);
        }
      }

      if (authResponse.user != null) {
        await _storage.saveUserData(authResponse.user!.toJson());
        print('✅ User data saved after Firebase login');
      }

      return authResponse;
    } catch (e) {
      print('❌ Error during Firebase login: $e');

      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw Exception('Firebase authentication failed');
        } else if (e.response?.statusCode == 404) {
          throw Exception('User not found');
        }
      }

      rethrow;
    }
  }

  // ============================================================================
  // END FIREBASE LOGIN
  // ============================================================================

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

      final newAccessToken = response.data['access_token'] as String;
      await _storage.saveAccessToken(newAccessToken);

      print('✅ Access token refreshed');
      return newAccessToken;
    } catch (e) {
      print('❌ Error refreshing token: $e');
      rethrow;
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
      await _storage.logout();
      print('✅ Local storage cleared successfully');
      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Critical error during logout: $e');

      // Force clear as last resort
      try {
        print('🔄 Attempting force clear of storage...');
        await _storage.logout();
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

      await _storage.logout();
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

  // ============================================================================
  // 🔐 MODIFIED: ROLE SELECTION WITH BIOMETRIC CHECK
  // ============================================================================

  /// Select role for current user
  /// Returns a map with:
  /// - 'biometric_required': true if Guardian role (biometric setup needed)
  /// - 'biometric_required': false if other roles (assigned immediately)
  Future<Map<String, dynamic>> selectRole(int roleId) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.selectRole,
        data: {"role_id": roleId},
      );

      print('✅ Role selection response: ${response.data}');

      // Backend returns: { success, message, biometric_required, role_assigned }
      final data = response.data as Map<String, dynamic>;
      
      // If biometric is NOT required, role was assigned immediately
      // Update user data in storage
      if (data['biometric_required'] == false || data['role_assigned'] == true) {
        if (data['user'] != null) {
          final updatedUser = UserModel.fromJson(data['user']);
          await _storage.saveUserData(updatedUser.toJson());
          print('✅ User data updated after role assignment');
        }
      }

      return data;
    } catch (e) {
      print('❌ Error selecting role: $e');
      rethrow;
    }
  }

  // ============================================================================
  // 🔐 BIOMETRIC AUTHENTICATION METHODS
  // ============================================================================

  /// Enable biometric authentication for current user
  /// For Guardian users: This also assigns the Guardian role
  Future<UserModel> enableBiometric() async {
    try {
      print('🔐 Enabling biometric authentication...');
      
      final response = await _dioClient.post(ApiEndpoints.enableBiometric);
      print('✅ Biometric enabled on backend');
      print('📦 Response: ${response.data}');

      // Backend returns updated UserResponse with roles assigned
      final updatedUser = UserModel.fromJson(response.data);
      
      // Save updated user data to storage
      await _storage.saveUserData(updatedUser.toJson());
      print('✅ User data updated after biometric enable');
      
      // ✅ NEW: Mark biometric as enabled locally for future logins
      await _storage.setBiometricEnabled(true);
      print('✅ Biometric preference saved locally');
      
      return updatedUser;
    } catch (e) {
      print('❌ Error enabling biometric: $e');
      rethrow;
    }
  }

  /// Login via biometric (reuses existing refresh token logic)
  /// Called when user authenticates via fingerprint/face
  Future<AuthResponseModel> biometricLogin() async {
    try {
      print('🔐 Logging in via biometric...');
      
      // Refresh the access token using existing refresh token
      final newAccessToken = await refreshAccessToken();
      print('✅ Biometric login successful - token refreshed');

      // Get updated user data
      final user = await fetchCurrentUser();
      
      // Create response model with refreshed token
      return AuthResponseModel(
        success: true,
        message: 'Biometric login successful',
        user: user,
        token: null, // Token is already saved by refreshAccessToken()
      );
    } catch (e) {
      print('❌ Error during biometric login: $e');
      rethrow;
    }
  }
}