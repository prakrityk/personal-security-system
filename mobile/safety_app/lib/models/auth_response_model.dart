// lib/models/auth_response_model.dart

import 'user_model.dart';

/// Token Model - matches backend Token schema
class TokenModel {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;

  TokenModel({
    required this.accessToken,
    this.refreshToken,
    required this.tokenType,
    this.expiresIn,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      'token_type': tokenType,
      if (expiresIn != null) 'expires_in': expiresIn,
    };
  }
}

/// Auth Response Model - matches backend UserWithToken schema
class AuthResponseModel {
  final UserModel user;
  final TokenModel token;

  AuthResponseModel({required this.user, required this.token});
  // lib/models/auth_response_model.dart

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    print('🔍 Parsing AuthResponseModel...');
    print('📦 Raw JSON: $json');
    print('📋 JSON Keys: ${json.keys.toList()}');

    // Check if user exists
    if (!json.containsKey('user')) {
      print('❌ ERROR: Missing "user" key in response');
      throw Exception('Server response missing "user" field');
    }

    final userData = json['user'];
    print('👤 User data type: ${userData.runtimeType}');

    if (userData == null) {
      print('❌ ERROR: User data is NULL');
      throw Exception('Server returned null user data');
    }

    if (userData is! Map<String, dynamic>) {
      print('❌ ERROR: User data is not a Map');
      throw Exception(
        'Invalid user data format: expected Map, got ${userData.runtimeType}',
      );
    }

    // ⚠️ FIX: Handle both 'token' (singular) AND 'tokens' (plural)
    final tokenData = json['tokens'] ?? json['token'];
    print('🔑 Token data type: ${tokenData.runtimeType}');

    if (tokenData == null) {
      print('❌ ERROR: No token data found');
      throw Exception('No token/tokens data found in response');
    }

    if (tokenData is! Map<String, dynamic>) {
      print('❌ ERROR: Token data is not a Map');
      throw Exception(
        'Invalid token data format: expected Map, got ${tokenData.runtimeType}',
      );
    }

    print('✅ Valid user and token data - proceeding to parse models');

    return AuthResponseModel(
      user: UserModel.fromJson(userData),
      token: TokenModel.fromJson(tokenData),
    );
  }
  Map<String, dynamic> toJson() {
    return {'user': user.toJson(), 'token': token.toJson()};
  }

  @override
  String toString() =>
      'AuthResponseModel(user: $user, token: ${token.accessToken})';
}

/// Email/Phone Check Response Models
class EmailCheckResponse {
  final bool available;
  final String message;

  EmailCheckResponse({required this.available, required this.message});

  factory EmailCheckResponse.fromJson(Map<String, dynamic> json) {
    return EmailCheckResponse(
      available: json['available'] as bool,
      message: json['message'] as String,
    );
  }
}

class PhoneCheckResponse {
  final bool available;
  final bool prefill;
  final String phoneNumber;

  PhoneCheckResponse({
    required this.available,
    required this.prefill,
    required this.phoneNumber,
  });

  factory PhoneCheckResponse.fromJson(Map<String, dynamic> json) {
    return PhoneCheckResponse(
      available: json['available'] as bool? ?? false,
      prefill: json['prefill'] as bool? ?? false,
      phoneNumber: json['phone_number'] as String? ?? '',
    );
  }
}

/// OTP Response Model
class OtpResponse {
  final bool success;
  final String message;

  OtpResponse({required this.success, required this.message});

  factory OtpResponse.fromJson(Map<String, dynamic> json) {
    return OtpResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}
