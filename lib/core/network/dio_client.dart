// lib/core/network/dio_client.dart
import 'dart:async';
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

class _TokenInterceptor extends Interceptor {
  _TokenInterceptor(this._dio);
  final Dio _dio;

  // Dùng Completer thay vì bool để queue tất cả request đang chờ refresh
  Completer<String>? _refreshCompleter;

  static const _skipPaths = [
    ApiConstants.login,
    ApiConstants.register,
    ApiConstants.refresh,
  ];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final shouldSkip = _skipPaths.any((p) => options.path.contains(p));
    if (!shouldSkip) {
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
    // Không retry nếu chính request refresh bị lỗi
    final isRetry = err.requestOptions.extra['skipRetry'] == true;
    if (err.response?.statusCode != 401 || isRetry) {
      handler.next(err);
      return;
    }

    // Nếu đang có refresh chạy, đợi kết quả thay vì trigger thêm một cái nữa
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      try {
        final newToken = await _refreshCompleter!.future;
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        final retryResponse = await _dio.fetch(opts);
        handler.resolve(retryResponse);
      } catch (_) {
        handler.next(err);
      }
      return;
    }

    // Bắt đầu refresh
    _refreshCompleter = Completer<String>();
    try {
      final refreshToken = await SecureStorage.instance.getRefreshToken();
      if (refreshToken == null) throw Exception('No refresh token');

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

      _refreshCompleter!.complete(newAccess);

      // Retry request gốc với token mới
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(opts);
      handler.resolve(retryResponse);
    } catch (_) {
      await SecureStorage.instance.clearTokens();
      _refreshCompleter!.completeError('refresh_failed');
      handler.next(err);
    } finally {
      _refreshCompleter = null;
    }
  }
}
