/// Tất cả tên route tập trung ở đây — không hardcode string ở chỗ khác.
/// Dùng [AppRoutes.login] thay vì '/login' trong code.
abstract class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const dashboard = '/dashboard';
  static const products = '/products';
  static const orders = '/orders';
  static const invoices = '/invoices';
  static const stock = '/stock';
  static const reports = '/reports';
  static const users = '/users';
}
