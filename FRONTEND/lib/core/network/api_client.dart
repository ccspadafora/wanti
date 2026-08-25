import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';

typedef TokenRefresher = Future<bool> Function();

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _access;
  String? _refresh;
  TokenRefresher? onRefreshNeeded;

  Future<void> loadTokens() async {
    _access = await _storage.read(key: 'access');
    _refresh = await _storage.read(key: 'refresh');
  }

  Future<void> saveTokens({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    await _storage.write(key: 'access', value: access);
    await _storage.write(key: 'refresh', value: refresh);
  }

  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
    await _storage.delete(key: 'access');
    await _storage.delete(key: 'refresh');
  }

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _access != null && _access!.isNotEmpty;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request('GET', path, query: query, auth: auth);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool auth = true,
  }) {
    return _request('POST', path, body: body, headers: headers, auth: auth);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool auth = true,
  }) {
    return _request('PATCH', path, body: body, headers: headers, auth: auth);
  }

  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) {
    return _request('DELETE', path, auth: auth);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
    bool auth = true,
    bool retried = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.apiV1}$path').replace(queryParameters: query);
    final reqHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };
    if (auth && _access != null) {
      reqHeaders['Authorization'] = 'Bearer $_access';
    }

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: reqHeaders).timeout(_timeout);
        case 'POST':
          response = await _client
              .post(
                uri,
                headers: reqHeaders,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_timeout);
        case 'PATCH':
          response = await _client
              .patch(
                uri,
                headers: reqHeaders,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_timeout);
        case 'DELETE':
          response = await _client.delete(uri, headers: reqHeaders).timeout(_timeout);
        default:
          throw ApiException(message: 'Método no soportado: $method');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'No se pudo conectar con el servidor (${ApiConfig.baseUrl}). '
            'Verifica tu conexión a internet.',
      );
    }

    if (response.statusCode == 401 && auth && !retried && onRefreshNeeded != null) {
      final ok = await onRefreshNeeded!();
      if (ok) {
        return _request(
          method,
          path,
          body: body,
          query: query,
          headers: headers,
          auth: auth,
          retried: true,
        );
      }
    }

    if (response.statusCode == 204 || response.body.isEmpty) {
      return {};
    }

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is List) {
        return {'results': raw};
      }
      decoded = Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      final body = response.body.trimLeft();
      if (body.startsWith('<') || response.statusCode == 400) {
        throw ApiException(
          message:
              'El servidor rechazó la petición (¿ALLOWED_HOSTS / URL incorrecta?). '
              'Base: ${ApiConfig.baseUrl}',
          statusCode: response.statusCode,
        );
      }
      throw ApiException(
        message: 'Respuesta inválida del servidor',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      final error = decoded['error'];
      if (error is Map) {
        throw ApiException(
          message: (error['message'] ?? 'Error').toString(),
          code: error['code']?.toString(),
          statusCode: response.statusCode,
          details: error['details'] is Map
              ? Map<String, dynamic>.from(error['details'] as Map)
              : null,
        );
      }
      throw ApiException(
        message: decoded['detail']?.toString() ?? 'Error ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  Future<bool> refreshAccessToken() async {
    if (_refresh == null || _refresh!.isEmpty) return false;
    try {
      final data = await _request(
        'POST',
        '/auth/token/refresh/',
        body: {'refresh': _refresh},
        auth: false,
      );
      final access = data['access']?.toString();
      if (access == null || access.isEmpty) return false;
      _access = access;
      await _storage.write(key: 'access', value: access);
      if (data['refresh'] != null) {
        _refresh = data['refresh'].toString();
        await _storage.write(key: 'refresh', value: _refresh);
      }
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }
}
