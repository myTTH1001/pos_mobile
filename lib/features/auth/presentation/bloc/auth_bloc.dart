// lib/features/auth/presentation/bloc/auth_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/events/auth_event_bus.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({AuthRepository? repository})
    : _repo = repository ?? AuthRepositoryImpl(),
      super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);

    // [FIX] Lắng nghe AuthEventBus từ DioClient
    // Khi refresh token hết hạn → tự động logout
    _authBusSubscription = AuthEventBus.instance.stream.listen((event) {
      if (event == AuthBusEvent.sessionExpired) {
        if (state is AuthAuthenticated || state is AuthLoading) {
          add(const AuthLogoutRequested());
        }
      }
    });
  }

  final AuthRepository _repo;
  late final StreamSubscription<AuthBusEvent> _authBusSubscription;

  @override
  Future<void> close() {
    _authBusSubscription.cancel();
    return super.close();
  }

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

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.login(username: event.username, password: event.password);
      emit(const AuthAuthenticated());
    } on AuthException catch (e) {
      emit(AuthError(e.message));
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthError('Đã xảy ra lỗi. Vui lòng thử lại.'));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _repo.logout();
    emit(const AuthUnauthenticated());
  }
}
