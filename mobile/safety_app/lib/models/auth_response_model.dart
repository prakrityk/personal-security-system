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
  final UserModel? user; // ✅ nullable now
  final TokenModel? token; // optional too, for OTP-only responses
  final bool? success; // for success messages without user
  final String? message;

  AuthResponseModel({this.user, this.token, this.success, this.message});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    print('🔍 Parsing AuthResponseModel...');
    print('📦 Raw JSON: $json');
    print('📋 JSON Keys: ${json.keys.toList()}');

    UserModel? parsedUser;
    TokenModel? parsedToken;

    // Parse user if it exists
    if (json.containsKey('user') && json['user'] != null) {
      if (json['user'] is Map<String, dynamic>) {
        parsedUser = UserModel.fromJson(json['user']);
      } else {
        print('⚠️ Warning: user key exists but is not a Map');
      }
    }

    // Parse token if it exists
    final tokenData = json['tokens'] ?? json['token'];
    if (tokenData != null && tokenData is Map<String, dynamic>) {
      parsedToken = TokenModel.fromJson(tokenData);
    }

    return AuthResponseModel(
      user: parsedUser,
      token: parsedToken,
      success: json['success'] as bool?,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (user != null) 'user': user!.toJson(),
      if (token != null) 'token': token!.toJson(),
      if (success != null) 'success': success,
      if (message != null) 'message': message,
    };
  }

  @override
  String toString() =>
      'AuthResponseModel(user: $user, token: ${token?.accessToken}, message: $message)';
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
