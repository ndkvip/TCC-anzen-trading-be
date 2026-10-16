import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, Duration? requestTimeout})
    : _client = client ?? http.Client(),
      _requestTimeout = requestTimeout ?? const Duration(seconds: 8);

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  // 10.0.2.2 is Android Emulator's host alias; iOS Simulator reaches the
  // host machine through 127.0.0.1. Keeping this platform-aware prevents auth
  // requests from waiting indefinitely on iOS during local development.
  static String get baseUrl => _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : Platform.isAndroid
      ? 'http://10.0.2.2:3001/api'
      : 'http://127.0.0.1:3001/api';

  final http.Client _client;
  final Duration _requestTimeout;

  Future<List<int>> download(String path, {String? token}) async {
    final uri = Uri.parse(path);
    final response = await _client
        .get(
          uri.hasScheme ? uri : Uri.parse('$baseUrl$path'),
          headers: _headers(token),
        )
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Không tải được ảnh', statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required File file,
    required String token,
    Map<String, String> fields = const {},
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll(fields)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await _client.send(request).timeout(_requestTimeout);
    final streamed = await http.Response.fromStream(response);
    return _decode(streamed);
  }

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final response = await _client
        .get(Uri.parse('$baseUrl$path'), headers: _headers(token))
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    String? token,
  }) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: _headers(token),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    String? token,
  }) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl$path'),
          headers: _headers(token),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    final response = await _client
        .delete(Uri.parse('$baseUrl$path'), headers: _headers(token))
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    String? token,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers(token),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    final Object? decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final rawMessage = data['message'];
    final message = rawMessage is List
        ? rawMessage.join('\n')
        : rawMessage?.toString() ?? 'Không thể kết nối máy chủ';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
