import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

/// Trạng thái khởi đầu trước khi check token
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Đang xử lý (login / logout / check)
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Đã đăng nhập — GoRouter redirect sang /dashboard
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated();
}

/// Chưa đăng nhập — GoRouter redirect về /login
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Lỗi login (sai pass, bị khoá, v.v.)
class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
