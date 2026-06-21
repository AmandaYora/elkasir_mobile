import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'token_store.dart';

/// Thin HTTP client for the Elkasir Go API (`/api/v1`).
///
/// Responsibilities:
/// - attaches `Authorization: Bearer <access>` when authenticated;
/// - unwraps the standard success envelope `{ success, message, data, meta }`
///   and returns `data`;
/// - on `success: false` (or a non-2xx status) throws [ApiException] carrying
///   the server `message`;
/// - on a 401 it transparently refreshes the token once via `/auth/refresh`
///   and retries the request.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokens, http.Client? client})
    : _http = client ?? http.Client();

  final String baseUrl;
  final TokenStore tokens;
  final http.Client _http;

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) => _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool auth = true,
  }) => _send('POST', path, body: body, headers: headers, auth: auth);

  Future<dynamic> put(String path, {Object? body, bool auth = true}) =>
      _send('PUT', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {bool auth = true}) =>
      _send('DELETE', path, auth: auth);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
    bool auth = true,
    bool allowRetry = true,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query?.isEmpty ?? true ? null : query);

    final reqHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (headers != null) ...headers,
    };
    if (auth && tokens.access != null) {
      reqHeaders['Authorization'] = 'Bearer ${tokens.access}';
    }

    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(reqHeaders);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await _http.send(req).timeout(const Duration(seconds: 20));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('Server tidak merespons. Coba lagi.', code: 'network');
    } catch (_) {
      throw ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi.',
        code: 'network',
      );
    }

    // Expired access token: refresh once, then retry the original request.
    if (res.statusCode == 401 &&
        auth &&
        allowRetry &&
        tokens.refresh != null) {
      if (await _refresh()) {
        return _send(
          method,
          path,
          body: body,
          query: query,
          headers: headers,
          auth: auth,
          allowRetry: false,
        );
      }
    }

    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
      return decoded;
    }

    final message = decoded is Map && decoded['message'] is String
        ? decoded['message'] as String
        : 'Permintaan gagal (${res.statusCode}).';
    final code = decoded is Map &&
            decoded['errors'] is List &&
            (decoded['errors'] as List).isNotEmpty &&
            (decoded['errors'] as List).first is Map
        ? ((decoded['errors'] as List).first as Map)['code'] as String?
        : null;
    throw ApiException(message, statusCode: res.statusCode, code: code);
  }

  Future<bool> _refresh() async {
    final refresh = tokens.refresh;
    if (refresh == null) return false;
    try {
      final res = await _http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
        await tokens.save(
          data['accessToken'] as String,
          data['refreshToken'] as String,
        );
        return true;
      }
    } catch (_) {
      // fall through to clear
    }
    await tokens.clear();
    return false;
  }

  void close() => _http.close();
}
