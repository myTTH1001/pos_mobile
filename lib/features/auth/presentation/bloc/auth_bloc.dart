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
      emit(const AuthAuthenticated());
    } on AuthException catch (e) {
      // Emit error để listener bắt và hiển thị SnackBar,
      // sau đó ngay lập tức reset về Unauthenticated để:
      //   1. State không "kẹt" ở AuthError
      //   2. Listener không re-trigger ở lần submit tiếp theo
      //   3. Form vẫn enabled, user có thể thử lại
      emit(AuthError(e.message));
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthError('Đã xảy ra lỗi. Vui lòng thử lại.'));
      emit(const AuthUnauthenticated());
    }
  }

  // ── Logout ──────────────────────────────────────────────
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _repo.logout();
    emit(const AuthUnauthenticated());
  }
}
