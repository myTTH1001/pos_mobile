import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';

class PosApp extends StatefulWidget {
  const PosApp({super.key});

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  // AuthBloc sống ở root — GoRouter lắng nghe stream của nó.
  // Khởi tạo ở đây để router có thể nhận instance ngay khi build.
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(repository: AuthRepositoryImpl())
      // Kiểm tra token còn hạn ngay khi app khởi động.
      // AuthBloc sẽ emit AuthAuthenticated hoặc AuthUnauthenticated,
      // GoRouter sẽ tự redirect dựa vào state đó.
      ..add(const AuthCheckRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tạo router SAU khi _authBloc đã sẵn sàng.
    // Router giữ reference đến _authBloc để lắng nghe stream.
    final router = createRouter(_authBloc);

    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'Đặc Sản Quê Hương POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}
