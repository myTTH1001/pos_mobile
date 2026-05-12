// lib/core/network/dio_client.dart
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  late final Dio _dio = _buildDio();

  Dio get dio => _dio;

  Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      _TokenInterceptor(dio),
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ),
    ]);

    return dio;
  }
}

// ── Token Interceptor ───────────────────────────────────────────────────────
class _TokenInterceptor extends Interceptor {
  _TokenInterceptor(this._dio);
  final Dio _dio;

  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Không attach token cho login/register/refresh
    final skipPaths = [
      ApiConstants.login,
      ApiConstants.register,
      ApiConstants.refresh,
    ];

    if (!skipPaths.any((p) => options.path.contains(p))) {
      final token = await SecureStorage.instance.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await SecureStorage.instance.getRefreshToken();
        if (refreshToken == null) throw Exception('No refresh token');

        // Gọi refresh với FormData
        final response = await _dio.post(
          ApiConstants.refresh,
          data: FormData.fromMap({'refresh_token': refreshToken}),
          options: Options(
            contentType: 'application/x-www-form-urlencoded',
            extra: {'skipRetry': true},
          ),
        );

        final newAccess = response.data['access_token'] as String;
        final newRefresh = response.data['refresh_token'] as String;

        await SecureStorage.instance.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );

        // Retry request gốc với token mới
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccess';
        final retryResponse = await _dio.fetch(opts);
        handler.resolve(retryResponse);
      } catch (_) {
        // Refresh thất bại → xoá token, ném lỗi để UI bắt
        await SecureStorage.instance.clearTokens();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}
