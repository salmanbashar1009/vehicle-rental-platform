import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_error.dart';

/// Generates RFC 4122 v4 UUIDs for Idempotency-Key and X-Correlation-ID headers.
String generateUuidV4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Typed REST API client communicating with FastAPI /api/v1.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _client = httpClient ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;
  String? accessToken;

  Map<String, String> _headers({String? idempotencyKey}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Correlation-ID': generateUuidV4(),
    };
    if (accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final res = await _client.get(uri, headers: _headers());
    return _decodeResponse(res);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final res = await _client.post(
      uri,
      headers: _headers(idempotencyKey: idempotencyKey),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(res);
  }

  dynamic _decodeResponse(http.Response res) {
    if (res.statusCode == 204 || res.body.isEmpty) {
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      throw ApiError(code: 'HTTP_${res.statusCode}', message: 'Request failed.', statusCode: res.statusCode);
    }
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      throw ApiError.fromJson(decoded, res.statusCode);
    }
    throw ApiError(code: 'HTTP_${res.statusCode}', message: 'Unexpected server error.', statusCode: res.statusCode);
  }
}
