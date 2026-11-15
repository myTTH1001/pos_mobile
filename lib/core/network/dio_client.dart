import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../events/auth_event_bus.dart';
import '../storage/secure_storage.dart';

class DioClient {
  DioClient._();
  static final instance = DioClient._();
  late final Dio dio = _build();
  Future<String>? _refresh;
  int _epoch = 0;
  void invalidateSession() {
    _epoch++;
  }

  Dio _build() {
    final client = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    bool publicPath(String path) => [
      ApiConstants.login,
      ApiConstants.register,
      '/auth/register-tenant',
      ApiConstants.refresh,
    ].contains(path);
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.extra['sessionEpoch'] = _epoch;
          if (!publicPath(options.path)) {
            final token = await SecureStorage.instance.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.requestOptions.extra['sessionEpoch'] != _epoch) {
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                type: DioExceptionType.cancel,
                message: 'Phiên đã thay đổi.',
              ),
            );
          } else {
            handler.next(response);
          }
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode != 401 ||
              publicPath(request.path) ||
              request.extra['retried'] == true ||
              request.extra['sessionEpoch'] != _epoch) {
            handler.next(error);
            return;
          }
          final epoch = _epoch;
          try {
            final current = await SecureStorage.instance.getAccessToken();
            String token;
            if (current != null &&
                request.headers['Authorization'] != 'Bearer $current') {
              token = current;
            } else {
              final future = _refresh ??= _refreshToken(client, epoch);
              try {
                token = await future;
              } finally {
                if (identical(_refresh, future)) _refresh = null;
              }
            }
            if (epoch != _epoch) {
              handler.next(error);
              return;
            }
            // Never replay a write automatically, even after a 401.
            if (!['GET', 'HEAD'].contains(request.method)) {
              handler.next(error);
              return;
            }
            request.extra['retried'] = true;
            request.headers['Authorization'] = 'Bearer $token';
            handler.resolve(await client.fetch<dynamic>(request));
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
    return client;
  }

  Future<String> _refreshToken(Dio client, int epoch) async {
    try {
      final refresh = await SecureStorage.instance.getRefreshToken();
      if (refresh == null) throw StateError('Missing refresh token');
      final response = await client.post(
        ApiConstants.refresh,
        data: {'refresh_token': refresh},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (epoch != _epoch) throw StateError('Session changed');
      final data = response.data as Map<String, dynamic>;
      await SecureStorage.instance.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return data['access_token'] as String;
    } catch (error) {
      // A temporary outage must not erase the user's session.
      if (epoch == _epoch &&
          (error is StateError ||
              error is DioException &&
                  [401, 403].contains(error.response?.statusCode))) {
        _epoch++;
        await SecureStorage.instance.clearTokens();
        AuthEventBus.instance.emitLogout();
      }
      rethrow;
    }
  }
}
