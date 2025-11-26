import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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

  Future<Map<String, dynamic>> fetchAccount(int userId) async {
    final uri = _u('account/?user_id=$userId');
    final res = await http.get(uri);
    final decoded = _decode(res);
    final data = _unwrapData(decoded);
    return data;
  }

  Future<Map<String, dynamic>> updateAccount({
    required int userId,
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    File? avatarFile,
    Uint8List? avatarBytes,
    String? avatarFilename,
    Object? avatarWebSource,
  }) async {
    final request = http.MultipartRequest('POST', _u('account/update/'));
    request.fields.addAll({
      'user_id': userId.toString(),
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
    });

    // Resolve avatar payload for all platforms (web and io).
    final resolvedBytes = await () async {
      if (avatarBytes != null) return avatarBytes;
      if (avatarWebSource != null) {
        // Support XFile or html.File by duck-typing readAsBytes / bytes.
        try {
          final dyn = avatarWebSource as dynamic;
          if (dyn.bytes != null) {
            final b = dyn.bytes;
            if (b is Uint8List) return b;
            if (b is List<int>) return Uint8List.fromList(b);
          }
          if (dyn.readAsBytes != null) {
            final b = await dyn.readAsBytes();
            if (b is Uint8List) return b;
            if (b is List<int>) return Uint8List.fromList(b);
          }
        } catch (_) {
          // ignore and fall through
        }
      }
      if (!kIsWeb && avatarFile != null) {
        return await avatarFile.readAsBytes();
      }
      return null;
    }();

    if (resolvedBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          resolvedBytes,
          filename: avatarFilename ?? (avatarFile?.path.split('/').last ?? 'avatar.jpg'),
        ),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response);
    final data = _unwrapData(decoded);
    _updateSession(data);
    return data;
  }

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final res = await http.post(
      _u('account/password/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      }),
    );
    _decode(res);
  }

  Future<List<Map<String, dynamic>>> fetchWishlist({required int userId}) async {
    final uri = _u('wishlist/?user_id=$userId');
    final res = await http.get(uri);
    final decoded = _decode(res);
    final data = decoded['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addWishlistItem({
    required int userId,
    required int venueId,
  }) async {
    final res = await http.post(
      _u('wishlist/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'venue_id': venueId}),
    );
    final decoded = _decode(res);
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return decoded;
  }

  Future<void> removeWishlistItem({
    required int userId,
    required int venueId,
  }) async {
    final res = await http.delete(
      _u('wishlist/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'venue_id': venueId}),
    );
    _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = (res.body.isEmpty) ? '{}' : res.body;
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiError(decoded['detail']?.toString() ?? 'Request failed');
    }
    return decoded;
  }

  Map<String, dynamic> _unwrapData(Map<String, dynamic> decoded) {
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data;
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
