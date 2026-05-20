// lib/core/router/app_router.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';

import '../../features/dashboard/presentation/pages/dashboard_shell.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/orders/presentation/pages/orders_page.dart';
import '../../features/invoices/presentation/pages/invoices_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/stock/presentation/pages/stock_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import 'app_routes.dart';

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: AppRoutes.pos,
    debugLogDiagnostics: true,
    refreshListenable: _RouterRefreshStream(authBloc.stream),

    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;

      // Chưa biết trạng thái auth → không redirect, giữ nguyên
      if (authState is AuthInitial || authState is AuthLoading) return null;

      final isLoggedIn = authState is AuthAuthenticated;
      final isOnLoginPage = location == AppRoutes.login;
      final isOnRegisterPage = location == AppRoutes.register;

      // Chưa đăng nhập — chỉ cho phép vào /login và /register
      if (!isLoggedIn && !isOnLoginPage && !isOnRegisterPage) {
        return AppRoutes.login;
      }

      // Đã đăng nhập mà vào /login hoặc /register → redirect về app
      if (isLoggedIn && (isOnLoginPage || isOnRegisterPage)) {
        return AppRoutes.pos;
      }

      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // Route đăng ký — không cần auth, không nằm trong shell
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pos,
                name: 'pos',
                builder: (context, state) => const PosPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.products,
                name: 'products',
                builder: (context, state) => const ProductsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                name: 'orders',
                builder: (context, state) => const OrdersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stock,
                name: 'stock',
                builder: (context, state) => const StockPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.invoices,
                name: 'invoices',
                builder: (context, state) => const InvoicesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                name: 'reports',
                builder: (context, state) => const ReportsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.users,
                name: 'users',
                builder: (context, state) => const UsersPage(),
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => _RouterErrorPage(error: state.error),
  );
}

class _RouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  _RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _RouterErrorPage extends StatelessWidget {
  const _RouterErrorPage({this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                'Trang không tồn tại',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                error?.toString() ?? 'Unknown route error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.pos),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
