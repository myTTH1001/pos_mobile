// lib/features/users/data/datasources/users_remote_datasource.dart
import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class UsersRemoteDatasource {
  final Dio _dio = DioClient.instance.dio;

  // ── Lấy store_id từ JWT access token (decode payload, không verify) ───────
  Future<int> _getStoreId() async {
    final token = await SecureStorage.instance.getAccessToken();
    if (token == null) throw Exception('Chưa đăng nhập');
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Token không hợp lệ');
      // Base64url decode phần payload
      String payload = parts[1];
      // Padding
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json['store_id'] as int;
    } catch (_) {
      throw Exception('Không thể đọc thông tin store từ token');
    }
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<List<UserModel>> getUsers() async {
    final res = await _dio.get(ApiConstants.users);
    final list = res.data as List<dynamic>;
    return list
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> createUser({
    required String username,
    required String password,
    required String roleName,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.users}/',
      data: {'username': username, 'password': password, 'role_name': roleName},
    );
    return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  Future<void> toggleUserStatus(int userId, {required bool isActive}) async {
    await _dio.put(
      '${ApiConstants.users}/$userId/status',
      data: {'is_active': isActive},
    );
  }

  Future<void> deleteUser(int userId) async {
    await _dio.delete('${ApiConstants.users}/$userId');
  }

  // ── Roles ─────────────────────────────────────────────────────────────────

  Future<List<RoleModel>> getRoles() async {
    final res = await _dio.get('${ApiConstants.roles}/');
    final list = res.data as List<dynamic>;
    return list
        .map((e) => RoleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gán role cho user — tự động lấy store_id từ JWT token
  Future<void> assignRole({
    required int userId,
    required int roleId,
    int? storeId, // optional override
  }) async {
    final sid = storeId != null && storeId > 0 ? storeId : await _getStoreId();
    await _dio.post(
      '${ApiConstants.roles}/assignments',
      data: {'user_id': userId, 'role_id': roleId, 'store_id': sid},
    );
  }

  Future<void> removeRole({required int userId, required int roleId}) async {
    await _dio.delete('${ApiConstants.roles}/assignments/$userId/$roleId');
  }
}
