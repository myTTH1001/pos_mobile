import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';

import '../../features/dashboard/presentation/pages/dashboard_shell.dart';
import '../../features/dashboard/presentation/pages/pos_page.dart';

import '../../features/products/presentation/pages/products_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/stock/presentation/pages/stock_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import 'app_routes.dart';

/// Tạo GoRouter. Nhận [authBloc] để lắng nghe thay đổi auth state.
///
/// Logic redirect:
/// - [AuthLoading] / [AuthInitial] → hiển thị splash (không redirect, chờ)
/// - [AuthUnauthenticated]         → redirect về /login (trừ khi đang ở /login)
/// - [AuthAuthenticated]           → redirect về /dashboard (nếu đang ở /login)
GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: true, // tắt khi release
    // ── Refresh stream ──────────────────────────────────────
    // GoRouter re-evaluate redirect mỗi khi AuthBloc emit state mới.
    refreshListenable: _RouterRefreshStream(authBloc.stream),

    // ── Redirect ────────────────────────────────────────────
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;

      // Đang chờ kết quả check token → chưa redirect, giữ nguyên
      if (authState is AuthInitial || authState is AuthLoading) {
        return null;
      }

      final isLoggedIn = authState is AuthAuthenticated;
      final isOnLoginPage = location == AppRoutes.login;

      // Chưa đăng nhập → về login
      if (!isLoggedIn && !isOnLoginPage) return AppRoutes.login;

      // Đã đăng nhập + đang ở login → về dashboard
      if (isLoggedIn && isOnLoginPage) return AppRoutes.pos;
      ;

      return null; // không redirect
    },

    // ── Routes ──────────────────────────────────────────────
    routes: [
      // LOGIN
      GoRoute(
        path: AppRoutes.login,
        name: "login",
        builder: (context, state) {
          return const LoginPage();
        },
      ),

      // DASHBOARD SHELL
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardShell(navigationShell: navigationShell);
        },

        branches: [
          // POS
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pos,
                name: "pos",
                builder: (context, state) {
                  return const PosPage();
                },
              ),
            ],
          ),

          // PRODUCTS
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.products,
                name: "products",
                builder: (context, state) {
                  return const ProductsPage();
                },
              ),
            ],
          ),

          // STOCK
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stock,
                name: "stock",
                builder: (context, state) {
                  return const StockPage();
                },
              ),
            ],
          ),

          // REPORTS
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                name: "reports",
                builder: (context, state) {
                  return const ReportsPage();
                },
              ),
            ],
          ),

          // USERS
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.users,
                name: "users",
                builder: (context, state) {
                  return const UsersPage();
                },
              ),
            ],
          ),
        ],
      ),
    ],

    // ─────────
    // ── Error page ──────────────────────────────────────────
    errorBuilder: (context, state) => _RouterErrorPage(error: state.error),
  );
}

// ─────────────────────────────────────────────────────────────
// ROUTER REFRESH STREAM
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// ERROR PAGE
// ─────────────────────────────────────────────────────────────

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
                onPressed: () {
                  context.go(AppRoutes.pos);
                },
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
