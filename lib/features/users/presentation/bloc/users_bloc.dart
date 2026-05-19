// lib/features/users/presentation/bloc/users_bloc.dart
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/users_remote_datasource.dart';
import '../../data/models/user_model.dart';

// ─── Events ──────────────────────────────────────────────────────────────────

abstract class UsersEvent extends Equatable {
  const UsersEvent();
  @override
  List<Object?> get props => [];
}

class UsersLoadRequested extends UsersEvent {
  const UsersLoadRequested();
}

class UserCreateRequested extends UsersEvent {
  const UserCreateRequested({
    required this.username,
    required this.password,
    required this.roleName,
  });
  final String username;
  final String password;
  final String roleName;
  @override
  List<Object?> get props => [username, roleName];
}

class UserToggleStatusRequested extends UsersEvent {
  const UserToggleStatusRequested({
    required this.userId,
    required this.isActive,
  });
  final int userId;
  final bool isActive;
  @override
  List<Object?> get props => [userId, isActive];
}

class UserDeleteRequested extends UsersEvent {
  const UserDeleteRequested(this.userId);
  final int userId;
  @override
  List<Object?> get props => [userId];
}

/// Gán thêm role cho user
class UserAssignRoleRequested extends UsersEvent {
  const UserAssignRoleRequested({required this.userId, required this.roleId});
  final int userId;
  final int roleId;
  @override
  List<Object?> get props => [userId, roleId];
}

/// Xóa role khỏi user
class UserRemoveRoleRequested extends UsersEvent {
  const UserRemoveRoleRequested({required this.userId, required this.roleId});
  final int userId;
  final int roleId;
  @override
  List<Object?> get props => [userId, roleId];
}

// ─── State ───────────────────────────────────────────────────────────────────

enum UsersStatus { initial, loading, success, failure }

enum UsersActionStatus { idle, loading, success, failure }

class UsersState extends Equatable {
  const UsersState({
    this.status = UsersStatus.initial,
    this.users = const [],
    this.roles = const [],
    this.errorMessage,
    this.actionStatus = UsersActionStatus.idle,
    this.actionError,
  });

  final UsersStatus status;
  final List<UserModel> users;
  final List<RoleModel> roles;
  final String? errorMessage;
  final UsersActionStatus actionStatus;
  final String? actionError;

  UsersState copyWith({
    UsersStatus? status,
    List<UserModel>? users,
    List<RoleModel>? roles,
    String? errorMessage,
    UsersActionStatus? actionStatus,
    String? actionError,
    bool clearActionError = false,
  }) => UsersState(
    status: status ?? this.status,
    users: users ?? this.users,
    roles: roles ?? this.roles,
    errorMessage: errorMessage ?? this.errorMessage,
    actionStatus: actionStatus ?? this.actionStatus,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );

  @override
  List<Object?> get props => [
    status,
    users,
    roles,
    errorMessage,
    actionStatus,
    actionError,
  ];
}

// ─── Bloc ─────────────────────────────────────────────────────────────────────

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  UsersBloc() : super(const UsersState()) {
    on<UsersLoadRequested>(_onLoad);
    on<UserCreateRequested>(_onCreate);
    on<UserToggleStatusRequested>(_onToggleStatus);
    on<UserDeleteRequested>(_onDelete);
    on<UserAssignRoleRequested>(_onAssignRole);
    on<UserRemoveRoleRequested>(_onRemoveRole);
  }

  final _remote = UsersRemoteDatasource();

  // ── Load users + roles ────────────────────────────────────────────────────

  Future<void> _onLoad(
    UsersLoadRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(status: UsersStatus.loading));
    try {
      final results = await Future.wait([
        _remote.getUsers(),
        _remote.getRoles(),
      ]);
      emit(
        state.copyWith(
          status: UsersStatus.success,
          users: results[0] as List<UserModel>,
          roles: results[1] as List<RoleModel>,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.failure, errorMessage: _clean(e)),
      );
    }
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<void> _onCreate(
    UserCreateRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(actionStatus: UsersActionStatus.loading));
    try {
      final newUser = await _remote.createUser(
        username: event.username,
        password: event.password,
        roleName: event.roleName,
      );
      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.success,
          users: [newUser, ...state.users],
          clearActionError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  // ── Toggle status ─────────────────────────────────────────────────────────

  Future<void> _onToggleStatus(
    UserToggleStatusRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(actionStatus: UsersActionStatus.loading));
    try {
      await _remote.toggleUserStatus(event.userId, isActive: event.isActive);
      final updated = state.users
          .map(
            (u) => u.id == event.userId
                ? UserModel(
                    id: u.id,
                    username: u.username,
                    isActive: event.isActive,
                    roles: u.roles,
                  )
                : u,
          )
          .toList();
      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.success,
          users: updated,
          clearActionError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _onDelete(
    UserDeleteRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(actionStatus: UsersActionStatus.loading));
    try {
      await _remote.deleteUser(event.userId);
      final updated = state.users.where((u) => u.id != event.userId).toList();
      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.success,
          users: updated,
          clearActionError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  // ── Assign role ───────────────────────────────────────────────────────────

  Future<void> _onAssignRole(
    UserAssignRoleRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(actionStatus: UsersActionStatus.loading));
    try {
      final role = state.roles.firstWhere((r) => r.id == event.roleId);

      // store_id được datasource tự đọc từ JWT token
      await _remote.assignRole(userId: event.userId, roleId: event.roleId);

      // Cập nhật local: thêm role vào user
      final updated = state.users.map((u) {
        if (u.id == event.userId) {
          return UserModel(
            id: u.id,
            username: u.username,
            isActive: u.isActive,
            roles: [...u.roles, role.name],
          );
        }
        return u;
      }).toList();

      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.success,
          users: updated,
          clearActionError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  // ── Remove role ───────────────────────────────────────────────────────────

  Future<void> _onRemoveRole(
    UserRemoveRoleRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(actionStatus: UsersActionStatus.loading));
    try {
      await _remote.removeRole(userId: event.userId, roleId: event.roleId);

      final role = state.roles.firstWhere(
        (r) => r.id == event.roleId,
        orElse: () => RoleModel(id: event.roleId, name: '', permissions: []),
      );

      // Cập nhật local: xóa role khỏi user
      final updated = state.users.map((u) {
        if (u.id == event.userId) {
          return UserModel(
            id: u.id,
            username: u.username,
            isActive: u.isActive,
            roles: u.roles.where((r) => r != role.name).toList(),
          );
        }
        return u;
      }).toList();

      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.success,
          users: updated,
          clearActionError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: UsersActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  String _clean(Object e) {
    if (e is DioException) {
      final detail = e.response?.data?['detail'];
      if (detail is String) return detail;
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
