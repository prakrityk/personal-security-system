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

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    // Handle both 'token' and 'tokens' keys from backend
    final tokenData = json['token'] ?? json['tokens'];

    if (tokenData == null) {
      throw Exception('No token data found in response');
    }

    return AuthResponseModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      token: TokenModel.fromJson(tokenData as Map<String, dynamic>),
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
