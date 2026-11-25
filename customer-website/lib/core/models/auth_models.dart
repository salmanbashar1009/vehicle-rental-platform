/// Authenticated customer summary DTO.
class AuthUserDto {
  const AuthUserDto({
    required this.id,
    required this.fullName,
    required this.roles,
    this.email,
    this.phone,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final List<String> roles;

  factory AuthUserDto.fromJson(Map<String, dynamic> json) => AuthUserDto(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    roles: ((json['roles'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toList(),
  );
}

/// Auth token pair DTO returned by /auth/login and /auth/register.
class TokenPairDto {
  const TokenPairDto({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AuthUserDto user;

  factory TokenPairDto.fromJson(Map<String, dynamic> json) => TokenPairDto(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    expiresIn: json['expires_in'] as int,
    user: AuthUserDto.fromJson(json['user'] as Map<String, dynamic>),
  );
}
