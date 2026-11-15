import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';

class PosApp extends StatefulWidget {
  const PosApp({super.key});
  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  late final AuthBloc _auth;
  late final StreamSubscription<AuthState> _subscription;
  late GoRouter _router;
  bool _authenticated = false;
  int _session = 0;
  @override
  void initState() {
    super.initState();
    _auth = AuthBloc();
    _router = createRouter(_auth);
    _subscription = _auth.stream.listen((state) {
      final loggedIn = state is AuthAuthenticated;
      if ((state is AuthAuthenticated || state is AuthUnauthenticated) &&
          loggedIn != _authenticated) {
        _authenticated = loggedIn;
        final previous = _router;
        setState(() {
          _router = createRouter(_auth);
          _session++;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    });
    _auth.add(const AuthCheckRequested());
  }

  @override
  void dispose() {
    _subscription.cancel();
    _router.dispose();
    _auth.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _auth,
    child: MaterialApp.router(
      key: ValueKey(_session),
      title: 'SaaS POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    ),
  );
}
