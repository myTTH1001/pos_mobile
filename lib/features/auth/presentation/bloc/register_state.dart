// lib/features/auth/presentation/bloc/register_state.dart
import 'package:equatable/equatable.dart';

abstract class RegisterState extends Equatable {
  const RegisterState();
  @override
  List<Object?> get props => [];
}

class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

class RegisterLoading extends RegisterState {
  const RegisterLoading();
}

/// Đăng ký thành công — UI navigate về login và hiện thông báo
class RegisterSuccess extends RegisterState {
  const RegisterSuccess({required this.storeName});
  final String storeName;

  @override
  List<Object?> get props => [storeName];
}

/// Lỗi — emit xong sẽ ngay lập tức reset về Initial
/// để state không kẹt (giống pattern của AuthBloc)
class RegisterError extends RegisterState {
  const RegisterError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
