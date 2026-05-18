// lib/features/users/data/models/user_model.dart

class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.isActive,
    required this.roles,
  });

  final int id;
  final String username;
  final bool isActive;
  final List<String> roles;

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: j['id'] as int,
    username: j['username'] as String,
    isActive: j['is_active'] as bool? ?? true,
    roles: (j['roles'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
  );

  /// Tên role hiển thị — ưu tiên role cao nhất
  String get primaryRole {
    if (roles.contains('owner')) return 'owner';
    if (roles.contains('manager')) return 'manager';
    if (roles.contains('staff')) return 'staff';
    if (roles.contains('cashier')) return 'cashier';
    return roles.isNotEmpty ? roles.first : '—';
  }
}

class RoleModel {
  const RoleModel({
    required this.id,
    required this.name,
    required this.permissions,
  });

  final int id;
  final String name;
  final List<String> permissions;

  factory RoleModel.fromJson(Map<String, dynamic> j) => RoleModel(
    id: j['id'] as int,
    name: j['name'] as String,
    permissions: (j['permissions'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
  );
}
