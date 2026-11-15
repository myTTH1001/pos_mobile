// lib/features/auth/presentation/bloc/register_event.dart
import 'package:equatable/equatable.dart';

abstract class RegisterEvent extends Equatable {
  const RegisterEvent();
  @override
  List<Object?> get props => [];
}

class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted({
    required this.username,
    required this.password,
    required this.storeName,
    required this.tenantName,
    required this.slug,
  });

  final String tenantName;
  final String slug;
  final String username;
  final String password;
  final String storeName;

  @override
  List<Object?> get props => [username, password, storeName];
}

class RegisterReset extends RegisterEvent {
  const RegisterReset();
}
