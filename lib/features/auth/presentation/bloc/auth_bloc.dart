import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// AuthBloc xử lý toàn bộ vòng đời xác thực.
///
/// Navigation KHÔNG nằm ở đây — GoRouter lắng nghe stream và tự redirect
/// khi state thay đổi. Bloc chỉ cần emit đúng state.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({AuthRepository? repository})
    : _repo = repository ?? AuthRepositoryImpl(),
      super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final AuthRepository _repo;

  // ── Check token lúc khởi động app ───────────────────────
  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Giữ AuthLoading trong lúc kiểm tra để GoRouter không redirect sớm
    emit(const AuthLoading());
    try {
      final loggedIn = await _repo.isLoggedIn();
      emit(loggedIn ? const AuthAuthenticated() : const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  // ── Login ───────────────────────────────────────────────
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.login(username: event.username, password: event.password);
      // Emit AuthAuthenticated → GoRouter tự redirect sang /dashboard
      emit(const AuthAuthenticated());
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (_) {
      emit(const AuthError('Đã xảy ra lỗi. Vui lòng thử lại.'));
    }
  }

  // ── Logout ──────────────────────────────────────────────
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _repo.logout();
    // Emit AuthUnauthenticated → GoRouter tự redirect về /login
    emit(const AuthUnauthenticated());
  }
}
