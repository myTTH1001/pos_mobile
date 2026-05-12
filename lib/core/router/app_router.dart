import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
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
    refreshListenable: _BlocListenable(authBloc.stream),

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
      if (isLoggedIn && isOnLoginPage) return AppRoutes.dashboard;

      return null; // không redirect
    },

    // ── Routes ──────────────────────────────────────────────
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),

      // TODO: thêm routes cho products, orders, invoices, stock, reports, users
      // GoRoute(path: AppRoutes.products, builder: ...),
    ],

    // ── Error page ──────────────────────────────────────────
    errorBuilder: (context, state) => _NotFoundPage(error: state.error),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Helper: bridge từ Stream → Listenable (GoRouter cần Listenable)
// ────────────────────────────────────────────────────────────────────────────
class _BlocListenable extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;

  _BlocListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 404 page
// ────────────────────────────────────────────────────────────────────────────
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Trang không tồn tại',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    );
  }
}
