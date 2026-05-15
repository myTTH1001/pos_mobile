// lib/features/auth/presentation/bloc/register_bloc.dart
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/api_constants.dart';
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
    emit(const RegisterLoading());
    try {
      await _dio.post(
        ApiConstants.register,
        data: FormData.fromMap({
          'username': event.username,
          'password': event.password,
          'store_name': event.storeName,
        }),
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      // Emit success — UI bắt rồi navigate về login
      emit(RegisterSuccess(storeName: event.storeName));
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data?['detail'] as String?;

      final message = switch (statusCode) {
        400 => detail ?? 'Tên đăng nhập đã tồn tại',
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
