// lib/features/auth/data/models/auth_response_model.dart

class AuthResponseModel {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}
