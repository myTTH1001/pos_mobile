// lib/features/users/data/datasources/users_remote_datasource.dart
import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_model.dart';

class UsersRemoteDatasource {
  final Dio _dio = DioClient.instance.dio;

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
    // Backend trả CreateUserOut { message, user }
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

  Future<void> assignRole({
    required int userId,
    required int roleId,
    required int storeId,
  }) async {
    await _dio.post(
      '${ApiConstants.roles}/assignments',
      data: {'user_id': userId, 'role_id': roleId, 'store_id': storeId},
    );
  }

  Future<void> removeRole({required int userId, required int roleId}) async {
    await _dio.delete('${ApiConstants.roles}/assignments/$userId/$roleId');
  }
}
