// lib/features/auth/data/datasources/auth_remote_datasource.dart
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/auth_response_model.dart';

abstract class AuthRemoteDatasource {
  Future<AuthResponseModel> login({
    required String username,
    required String password,
  });

  Future<void> logout({required String refreshToken});
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final Dio _dio = DioClient.instance.dio;

  @override
  Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    // Backend dùng OAuth2PasswordRequestForm → gửi form-encoded
    final response = await _dio.post(
      ApiConstants.login,
      data: FormData.fromMap({'username': username, 'password': password}),
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );

    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    await _dio.post(
      ApiConstants.logout,
      data: FormData.fromMap({'refresh_token': refreshToken}),
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
  }
}
