// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:dio/dio.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthRemoteDatasource? remote})
    : _remote = remote ?? AuthRemoteDatasourceImpl();

  final AuthRemoteDatasource _remote;
  final _storage = SecureStorage.instance;

  @override
  Future<void> login({
    required String username,
    required String password,
  }) async {
    try {
      final result = await _remote.login(
        username: username,
        password: password,
      );
      await _storage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final message = e.response?.data?['detail'] as String?;

      if (statusCode == 401) {
        throw AuthException(message ?? 'Sai tài khoản hoặc mật khẩu');
      } else if (statusCode == 403) {
        throw AuthException(message ?? 'Tài khoản đã bị khoá');
      } else {
        throw AuthException('Lỗi kết nối. Vui lòng thử lại.');
      }
    }
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
        await _remote.logout(refreshToken: refreshToken);
      }
    } catch (_) {
      // Vẫn clear local dù server lỗi
    } finally {
      await _storage.clearTokens();
    }
  }

  @override
  Future<bool> isLoggedIn() => _storage.hasTokens();
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
