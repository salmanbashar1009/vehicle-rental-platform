import 'package:equatable/equatable.dart';

import '../../../core/error/failures.dart';

/// Authenticated staff user identity & RBAC claims.
class StaffUser extends Equatable {
  const StaffUser({
    required this.id,
    required this.fullName,
    required this.roles,
    required this.permissions,
    this.email,
    this.phone,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final Set<String> roles;
  final Set<String> permissions;

  bool hasPermission(String permission) =>
      roles.contains('owner') || permissions.contains(permission);

  @override
  List<Object?> get props => [id, fullName, email, phone, roles, permissions];
}

/// Abstract repository contract for staff authentication.
abstract interface class AuthRepository {
  Future<Result<StaffUser>> login({
    required String identifier,
    required String password,
    String? totpCode,
  });

  Future<Result<StaffUser?>> restoreSession();
  Future<void> logout();
}
