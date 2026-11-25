import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../error/failures.dart';

/// Token vault interface allowing secure storage or in-memory test doubles.
abstract interface class TokenVault {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({required String accessToken, required String refreshToken});
  Future<void> clear();
}

/// Configured Dio client with Correlation ID, single-flight refresh, and error mapper.
class ApiClient {
  ApiClient({required TokenVault vault, Dio? dio})
    : _vault = vault,
      _dio = dio ?? Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['X-Correlation-ID'] ??= const Uuid().v4();
          final token = await _vault.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          if (err.response?.statusCode == 401 &&
              err.requestOptions.extra['_retried'] != true &&
              !err.requestOptions.path.contains('/auth/')) {
            final refreshed = await _refreshSingleFlight();
            if (refreshed) {
              final token = await _vault.readAccessToken();
              err.requestOptions.headers['Authorization'] = 'Bearer $token';
              err.requestOptions.extra['_retried'] = true;
              final retry = await _dio.fetch<dynamic>(err.requestOptions);
              return handler.resolve(retry);
            }
          }
          handler.next(err);
        },
      ),
    );
  }

  final TokenVault _vault;
  final Dio _dio;
  Completer<bool>? _refreshLock;

  Dio get raw => _dio;
  TokenVault get vault => _vault;

  Future<bool> _refreshSingleFlight() async {
    if (_refreshLock != null) return _refreshLock!.future;
    final completer = Completer<bool>();
    _refreshLock = completer;
    try {
      final refresh = await _vault.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        completer.complete(false);
        return false;
      }
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final data = res.data;
      if (data != null) {
        await _vault.saveTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
        );
        completer.complete(true);
        return true;
      }
      completer.complete(false);
      return false;
    } catch (_) {
      await _vault.clear();
      completer.complete(false);
      return false;
    } finally {
      _refreshLock = null;
    }
  }

  static Failure mapDioError(Object error) {
    if (error is! DioException) {
      return ServerFailure(message: error.toString());
    }
    final res = error.response;
    if (res == null) return const NetworkFailure();
    final body = res.data;
    String msg = 'Request failed (${res.statusCode}).';
    String code = 'HTTP_${res.statusCode}';
    String? corrId;
    if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
      final err = body['error'] as Map<String, dynamic>;
      msg = (err['message'] as String?) ?? msg;
      code = (err['code'] as String?) ?? code;
      corrId = err['correlation_id'] as String?;
    }
    return switch (res.statusCode) {
      401 => AuthFailure(message: msg, code: code, correlationId: corrId),
      403 => ForbiddenFailure(message: msg, code: code, correlationId: corrId),
      409 => ConflictFailure(message: msg, code: code, correlationId: corrId),
      422 => ValidationFailure(message: msg, code: code, correlationId: corrId),
      _ => ServerFailure(message: msg, code: code, correlationId: corrId),
    };
  }
}
