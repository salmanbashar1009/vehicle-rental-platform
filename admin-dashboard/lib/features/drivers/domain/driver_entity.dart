import 'package:equatable/equatable.dart';

import '../../../core/error/failures.dart';

/// Driver profile domain entity.
class DriverEntity extends Equatable {
  const DriverEntity({
    required this.id,
    required this.fullName,
    required this.licenceNumber,
    required this.licenceExpiry,
    required this.availabilityStatus,
    this.phone,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String licenceNumber;
  final DateTime licenceExpiry;
  final String availabilityStatus;

  bool get isLicenceExpiringSoon =>
      licenceExpiry.difference(DateTime.now().toUtc()).inDays <= 30;

  @override
  List<Object?> get props => [id, fullName, licenceNumber, licenceExpiry, availabilityStatus];
}

/// Abstract repository for driver management.
abstract interface class DriverRepository {
  Future<Result<List<DriverEntity>>> listDrivers();
}
