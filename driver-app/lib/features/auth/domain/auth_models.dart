import 'package:equatable/equatable.dart';

/// Authenticated chauffeur profile + token summary.
class DriverSession extends Equatable {
  const DriverSession({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.roles,
    this.phone,
    this.licenceNumber,
    this.licenceExpiryIso,
  });

  final String userId;
  final String fullName;
  final String email;
  final List<String> roles;
  final String? phone;
  final String? licenceNumber;
  final String? licenceExpiryIso;

  @override
  List<Object?> get props => [userId, fullName, email, roles, licenceNumber, licenceExpiryIso];
}

/// Auth boundary for driver login, session restoration, and logout.
abstract class DriverAuthRepository {
  Future<DriverSession> login({required String identifier, required String password});
  Future<DriverSession?> restoreSession();
  Future<void> logout();
}
