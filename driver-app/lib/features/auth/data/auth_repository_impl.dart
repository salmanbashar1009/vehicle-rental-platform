import 'package:dio/dio.dart';

import 'package:velofleet_driver/core/error/failures.dart';
import 'package:velofleet_driver/core/network/dio_client.dart';
import 'package:velofleet_driver/features/auth/domain/auth_models.dart';

/// Concrete REST authentication repository backed by FastAPI `/auth/*`.
class DriverAuthRepositoryImpl implements DriverAuthRepository {
  DriverAuthRepositoryImpl(this._client);

  final DriverDioClient _client;

  @override
  Future<DriverSession> login({required String identifier, required String password}) async {
    try {
      final resp = await _client.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'identifier': identifier.trim(), 'password': password},
      );
      final data = resp.data ?? const {};
      await _client.tokenStore.writeTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return await _fetchMe();
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
      throw AuthFailure(detail?.toString() ?? 'Unable to sign in. Check credentials.');
    }
  }

  @override
  Future<DriverSession?> restoreSession() async {
    final access = await _client.tokenStore.readAccessToken();
    if (access == null || access.isEmpty) return null;
    try {
      return await _fetchMe();
    } catch (_) {
      return null;
    }
  }

  Future<DriverSession> _fetchMe() async {
    final me = await _client.dio.get<Map<String, dynamic>>('/auth/me');
    final u = me.data ?? const {};
    final roles = ((u['roles'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toList();
    if (!roles.contains('driver')) {
      await _client.tokenStore.clear();
      throw const AuthFailure('Account does not hold a driver role.');
    }
    return DriverSession(
      userId: u['id'].toString(),
      fullName: (u['full_name'] as String?) ?? 'Driver',
      email: (u['email'] as String?) ?? '',
      phone: u['phone'] as String?,
      roles: roles,
    );
  }

  @override
  Future<void> logout() async {
    try {
      final refresh = await _client.tokenStore.readRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _client.dio.post<void>('/auth/logout', data: {'refresh_token': refresh});
      }
    } finally {
      await _client.tokenStore.clear();
    }
  }
}
