import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/dio_client.dart';
import '../theme/brand_theme.dart';

/// Secure token vault backed by Windows Credential Manager via flutter_secure_storage.
class SecureTokenVault implements TokenVault {
  SecureTokenVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _accessKey = 'vf_admin_access';
  static const _refreshKey = 'vf_admin_refresh';

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Formats minor currency units deterministically without float math.
String formatMinorCurrency(int amountMinor, String currency) {
  final sign = amountMinor < 0 ? '-' : '';
  final absVal = amountMinor.abs();
  final whole = absVal ~/ 100;
  final cents = (absVal % 100).toString().padLeft(2, '0');
  return '$sign$currency $whole.$cents';
}

/// Consistent semantic status pill aligned with shared-contracts/design-tokens.md.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BrandTokens>() ?? BrandTokens.light;
    final (fg, bg) = switch (status) {
      'confirmed' || 'completed' || 'closed' || 'available' || 'live' || 'accepted' => (
        tokens.successFg,
        tokens.successBg,
      ),
      'requested' || 'under_review' || 'quoted' || 'pending_ack' || 'stale' => (
        tokens.warningFg,
        tokens.warningBg,
      ),
      'rejected' || 'cancelled' || 'expired' || 'offline' || 'maintenance' || 'out_of_service' => (
        tokens.errorFg,
        tokens.errorBg,
      ),
      _ => (tokens.infoFg, tokens.infoBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
