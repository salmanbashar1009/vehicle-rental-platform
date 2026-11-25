import 'dart:convert';

import 'package:jaspr/jaspr.dart';

import '../http/api_client.dart';
import '../models/auth_models.dart';
import '../web/browser_nav.dart';

const String _sessionStorageKey = 'velofleet_customer_session';

/// Shared client-side authentication state for customer portal pages.
class CustomerAuthStore extends ChangeNotifier {
  CustomerAuthStore._() {
    _restoreFromStorage();
  }
  static final CustomerAuthStore instance = CustomerAuthStore._();

  ApiClient api = ApiClient();
  TokenPairDto? _session;

  TokenPairDto? get session => _session;
  bool get isAuthenticated => _session != null;
  AuthUserDto? get user => _session?.user;

  void _restoreFromStorage() {
    final raw = readSessionValue(_sessionStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _session = TokenPairDto.fromJson(decoded);
      api.accessToken = _session!.accessToken;
    } catch (_) {
      writeSessionValue(_sessionStorageKey, null);
    }
  }

  void _saveSession(Map<String, dynamic> json) {
    _session = TokenPairDto.fromJson(json);
    api.accessToken = _session!.accessToken;
    writeSessionValue(_sessionStorageKey, jsonEncode(json));
    notifyListeners();
  }

  Future<void> login({required String identifier, required String password}) async {
    final json = await api.post(
      '/auth/login',
      body: {'identifier': identifier.trim(), 'password': password},
    ) as Map<String, dynamic>;
    _saveSession(json);
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
    _saveSession(json);
  }

  Future<void> logout() async {
    try {
      if (isAuthenticated) {
        await api.post('/auth/logout');
      }
    } finally {
      _session = null;
      api.accessToken = null;
      writeSessionValue(_sessionStorageKey, null);
      notifyListeners();
    }
  }
}
