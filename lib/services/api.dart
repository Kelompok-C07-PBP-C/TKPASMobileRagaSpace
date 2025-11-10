import 'dart:convert';
import 'package:http/http.dart' as http;

import 'base_url_resolver.dart';

class Api {
  Api({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  final String baseUrl;

  static final String defaultBaseUrl = _ensureTrailingSlash('${resolveBaseApiHost()}/api/');

  static String _ensureTrailingSlash(String value) => value.endsWith('/') ? value : '$value/';

  Uri _u(String path) => Uri.parse(baseUrl + path);

  Future<Map<String, dynamic>> register(String username, String password,
      {String? email}) async {
    final res = await http.post(
      _u('register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        if (email != null) 'email': email,
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      _u('login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> me() async {
    final res = await http.get(_u('me/'));
    return _decode(res);
  }

  Future<Map<String, dynamic>> logout() async {
    final res = await http.post(_u('logout/'));
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = (res.body.isEmpty) ? '{}' : res.body;
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiError(decoded['detail']?.toString() ?? 'Request failed');
    }
    return decoded;
  }
}

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}
