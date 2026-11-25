/// Typed UI error mapped from backend ErrorEnvelope responses.
class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    required this.statusCode,
    this.correlationId,
  });

  final String code;
  final String message;
  final int statusCode;
  final String? correlationId;

  factory ApiError.fromJson(Map<String, dynamic> json, int statusCode) {
    final err = json['error'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return ApiError(
      code: (err['code'] as String?) ?? 'REQUEST_FAILED',
      message: (err['message'] as String?) ?? 'Unable to process request.',
      statusCode: statusCode,
      correlationId: err['correlation_id'] as String?,
    );
  }

  @override
  String toString() => 'ApiError($statusCode, $code): $message';
}
