import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:velofleet_driver/core/config/app_config.dart';

/// Abstraction over encrypted token persistence for testability.
abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> writeTokens({required String accessToken, required String refreshToken});
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _accessKey = 'vf_driver_access';
  static const _refreshKey = 'vf_driver_refresh';

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Configured Dio HTTP client with Correlation ID, Bearer JWT, and single-flight refresh.
class DriverDioClient {
  DriverDioClient({required this.tokenStore, Dio? dio})
    : dio = dio ?? Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl, connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 15))) {
    this.dio.interceptors.add(_DriverAuthInterceptor(this.dio, tokenStore));
  }

  final Dio dio;
  final TokenStore tokenStore;
}

class _DriverAuthInterceptor extends Interceptor {
  _DriverAuthInterceptor(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;
  final _uuid = const Uuid();
  Completer<String?>? _refreshLock;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers['X-Correlation-ID'] ??= _uuid.v4();
    final access = await _tokens.readAccessToken();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final retried = err.requestOptions.extra['_retried'] == true;
    final isRefreshCall = err.requestOptions.path.contains('/auth/refresh');
    if (status != 401 || retried || isRefreshCall) {
      handler.next(err);
      return;
    }

    final newAccess = await _refreshSingleFlight();
    if (newAccess == null) {
      handler.next(err);
      return;
    }
    err.requestOptions.extra['_retried'] = true;
    err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
    try {
      final response = await _dio.fetch<dynamic>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<String?> _refreshSingleFlight() async {
    if (_refreshLock != null) return _refreshLock!.future;
    final lock = Completer<String?>();
    _refreshLock = lock;
    try {
      final refresh = await _tokens.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        lock.complete(null);
        return null;
      }
      final resp = await Dio(
        BaseOptions(baseUrl: _dio.options.baseUrl),
      ).post<Map<String, dynamic>>('/auth/refresh', data: {'refresh_token': refresh});
      final data = resp.data;
      final access = data?['access_token'] as String?;
      final nextRefresh = data?['refresh_token'] as String?;
      if (access != null && nextRefresh != null) {
        await _tokens.writeTokens(accessToken: access, refreshToken: nextRefresh);
        lock.complete(access);
        return access;
      }
      await _tokens.clear();
      lock.complete(null);
      return null;
    } catch (_) {
      await _tokens.clear();
      lock.complete(null);
      return null;
    } finally {
      _refreshLock = null;
    }
  }
}
