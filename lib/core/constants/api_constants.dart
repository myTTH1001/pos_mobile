// lib/core/constants/api_constants.dart

class ApiConstants {
  ApiConstants._();

  // Backend routes are mounted under /api.
  // Real phone: pass --dart-define=API_BASE_URL=http://PC_LAN_IP:8000/api
  // USB with adb reverse tcp:8000 tcp:8000: use http://127.0.0.1:8000/api
  // Default below is only for the standard Android emulator.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  // ── Auth ──────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String register = '/auth/register';

  // ── Products ──────────────────────────────────────────
  static const String products = '/products';

  // ── Orders ────────────────────────────────────────────
  static const String orders = '/orders';
  static String orderConfirm(int id) => '/orders/$id/confirm';
  static String orderCancel(int id) => '/orders/$id/cancel';

  // ── Invoices ──────────────────────────────────────────
  static const String invoices = '/invoices';
  static String invoiceCancel(int id) => '/invoices/$id/cancel';

  // ── Stock ─────────────────────────────────────────────
  static const String stock = '/stock';
  static const String stockImport = '/stock/import';
  static const String stockAdjust = '/stock/adjust';
  static const String stockTransfer = '/stock/transfer';
  static const String stockMovements = '/stock/movements';

  // ── Reports ───────────────────────────────────────────
  static const String reportDaily = '/reports/daily';
  static const String reportCashier = '/reports/cashier';
  static const String reportProduct = '/reports/product';

  // ── Users / Roles ─────────────────────────────────────
  static const String users = '/users';
  static const String roles = '/roles';
}

class AppConstants {
  AppConstants._();

  // Token keys (secure storage)
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  // Pagination
  static const int defaultLimit = 20;
  static const int defaultOffset = 0;

  // Image upload
  static const int maxImageSizeMb = 2;

  // Responsive breakpoints
  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 900;
}
