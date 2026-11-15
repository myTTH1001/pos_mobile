// lib/features/auth/presentation/bloc/register_bloc.dart
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/network/dio_client.dart';
import 'register_event.dart';
import 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc() : super(const RegisterInitial()) {
    on<RegisterSubmitted>(_onSubmitted);
    on<RegisterReset>(_onReset);
  }

  final _dio = DioClient.instance.dio;

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    if (state is RegisterLoading) return;
    emit(const RegisterLoading());
    try {
      await _dio.post(
        '/auth/register-tenant',
        data: {
          'tenant_name': event.tenantName.trim(),
          'slug': event.slug.trim(),
          'email': event.username.trim().toLowerCase(),
          'password': event.password,
          'store_name': event.storeName.trim(),
          'vertical': 'retail',
        },
      );

      // Emit success — UI bắt rồi navigate về login
      emit(RegisterSuccess(storeName: event.storeName));
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = apiError(e);

      final message = switch (statusCode) {
        400 || 409 => detail,
        422 => 'Thông tin không hợp lệ. Vui lòng kiểm tra lại.',
        _ => 'Lỗi kết nối. Vui lòng thử lại.',
      };

      emit(RegisterError(message));
      emit(const RegisterInitial()); // reset ngay để không kẹt state
    } catch (_) {
      emit(const RegisterError('Đã xảy ra lỗi. Vui lòng thử lại.'));
      emit(const RegisterInitial());
    }
  }

  void _onReset(RegisterReset event, Emitter<RegisterState> emit) {
    emit(const RegisterInitial());
  }
}
