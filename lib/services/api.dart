import 'dart:convert';
import 'package:http/http.dart' as http;

import 'base_url_resolver.dart';

class Api {
  Api({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  final String baseUrl;

  static final String defaultBaseUrl = _ensureTrailingSlash('${resolveBaseApiHost()}/api/');

  static int? _currentUserId;
  static String? _currentUsername;

  static int? get currentUserId => _currentUserId;
  static String? get currentUsername => _currentUsername;

  static void _updateSession(Map<String, dynamic> payload) {
    final idValue = payload['id'];
    if (idValue is int) {
      _currentUserId = idValue;
    } else if (idValue is String) {
      _currentUserId = int.tryParse(idValue);
    }
    final usernameValue = payload['username'];
    if (usernameValue is String && usernameValue.isNotEmpty) {
      _currentUsername = usernameValue;
    }
  }

  static void _clearSession() {
    _currentUserId = null;
    _currentUsername = null;
  }

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
    final decoded = _decode(res);
    _updateSession(decoded);
    return decoded;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      _u('login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final decoded = _decode(res);
    _updateSession(decoded);
    return decoded;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await http.get(_u('me/'));
    final decoded = _decode(res);
    if (decoded['authenticated'] == true) {
      _updateSession(decoded);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> logout() async {
    final res = await http.post(_u('logout/'));
    final decoded = _decode(res);
    _clearSession();
    return decoded;
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
