import 'package:jaspr/jaspr.dart';

import '../http/api_client.dart';
import '../models/auth_models.dart';

/// Shared client-side authentication state for customer portal pages.
class CustomerAuthStore extends ChangeNotifier {
  CustomerAuthStore._();
  static final CustomerAuthStore instance = CustomerAuthStore._();

  ApiClient api = ApiClient();
  TokenPairDto? _session;

  TokenPairDto? get session => _session;
  bool get isAuthenticated => _session != null;
  AuthUserDto? get user => _session?.user;

  Future<void> login({required String identifier, required String password}) async {
    final json = await api.post(
      '/auth/login',
      body: {'identifier': identifier.trim(), 'password': password},
    ) as Map<String, dynamic>;
    _session = TokenPairDto.fromJson(json);
    api.accessToken = _session!.accessToken;
    notifyListeners();
  }

  Future<void> register({
    required String fullName,
    String? email,
    String? phone,
    required String password,
  }) async {
    final json = await api.post(
      '/auth/register',
      body: {
        'full_name': fullName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'password': password,
      },
    ) as Map<String, dynamic>;
    _session = TokenPairDto.fromJson(json);
    api.accessToken = _session!.accessToken;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (isAuthenticated) {
        await api.post('/auth/logout');
      }
    } finally {
      _session = null;
      api.accessToken = null;
      notifyListeners();
    }
  }
}
