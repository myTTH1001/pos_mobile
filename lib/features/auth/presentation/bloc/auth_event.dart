// lib/features/auth/presentation/bloc/auth_event.dart
import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

/// Gọi khi app khởi động — kiểm tra token có hợp lệ không
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Người dùng submit form login
class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.username, required this.password});
  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];
}

/// Người dùng bấm đăng xuất
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
