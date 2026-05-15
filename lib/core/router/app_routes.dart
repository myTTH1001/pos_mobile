abstract class AppRoutes {
  AppRoutes._();

  // ── Auth ──────────────────────────────────────────────────
  static const login = '/login';
  static const register = '/register';

  // ── Shell tabs (StatefulShellRoute) ───────────────────────
  static const pos = '/pos'; // Bán hàng
  static const dashboard = '/dashboard'; // Dashboard chính với 4 tab bên dưới
  static const products = '/products'; // Sản phẩm
  static const stock = '/stock'; // Kho
  static const reports = '/reports'; // Báo cáo
  static const users = '/users'; // Nhân viên

  // ── Routes nằm ngoài shell (push full-screen) ─────────────
  static const orders = '/orders';
  static const invoices = '/invoices';
}
