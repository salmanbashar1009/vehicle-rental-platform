import '../../../core/error/failures.dart';
import '../../../core/network/dio_client.dart';
import '../domain/auth_entities.dart';

/// Concrete Dio + SecureStorage AuthRepository implementation.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required ApiClient api, required TokenVault vault})
    : _api = api,
      _vault = vault;

  final ApiClient _api;
  final TokenVault _vault;

  StaffUser _mapUser(Map<String, dynamic> u) => StaffUser(
    id: u['id'] as String,
    fullName: u['full_name'] as String,
    email: u['email'] as String?,
    phone: u['phone'] as String?,
    roles: ((u['roles'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toSet(),
    permissions: ((u['permissions'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toSet(),
  );

  @override
  Future<Result<StaffUser>> login({
    required String identifier,
    required String password,
    String? totpCode,
  }) async {
    try {
      final res = await _api.raw.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'identifier': identifier.trim(),
          'password': password,
          if (totpCode != null && totpCode.trim().isNotEmpty) 'totp_code': totpCode.trim(),
        },
      );
      final body = res.data!;
      await _vault.saveTokens(
        accessToken: body['access_token'] as String,
        refreshToken: body['refresh_token'] as String,
      );
      final user = _mapUser(body['user'] as Map<String, dynamic>);
      if (user.roles.length == 1 &&
          (user.roles.contains('customer') || user.roles.contains('driver'))) {
        await _vault.clear();
        return const Err(ForbiddenFailure(message: 'Staff role required for Admin Dashboard.'));
      }
      return Success(user);
    } catch (e) {
      return Err(ApiClient.mapDioError(e));
    }
  }

  @override
  Future<Result<StaffUser?>> restoreSession() async {
    try {
      final token = await _vault.readAccessToken();
      if (token == null || token.isEmpty) return const Success(null);
      final res = await _api.raw.get<Map<String, dynamic>>('/auth/me');
      return Success(_mapUser(res.data!));
    } catch (_) {
      return const Success(null);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.raw.post<void>('/auth/logout');
    } catch (_) {
      // Clear local session regardless of network reachability.
    } finally {
      await _vault.clear();
    }
  }
}
