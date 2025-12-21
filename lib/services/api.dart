import 'dart:convert';
import 'dart:io' show File, SocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'base_url_resolver.dart';
import 'cookie_reader.dart';

class Api {
  Api({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  final String baseUrl;

  static final String defaultBaseUrl = _ensureTrailingSlash('${resolveBaseApiHost()}/api/');

  static final http.Client _client = _createClient();

  static http.Client _createClient() {
    final client = http.Client();
    if (kIsWeb) {
      try {
        (client as dynamic).withCredentials = true;
      } catch (_) {
        // Ignore if the underlying client does not expose browser credentials.
      }
    }
    return client;
  }

  // Keys for persisting "remember me" behaviour.
  static const String _rememberKey = 'auth_remember_me';
  static const String _rememberUserKey = 'auth_remember_username';
  static const String _rememberPasswordKey = 'auth_remember_password';

  static int? _currentUserId;
  static String? _currentUsername;
  static bool? _currentIsAdmin;

  static final Map<String, String> _cookies = <String, String>{};

  static int? get currentUserId => _currentUserId;
  static String? get currentUsername => _currentUsername;
  static bool get isAdmin => _currentIsAdmin ?? false;
  static bool? get currentIsAdmin => _currentIsAdmin;

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
    _updateAdminFlag(payload);
  }

  static void _clearSession() {
    _currentUserId = null;
    _currentUsername = null;
    _currentIsAdmin = null;
  }

  static void _clearCookies() {
    _cookies.clear();
  }

  static bool? _coerceBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
      if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
    }
    return null;
  }

  static void _updateAdminFlag(Map<String, dynamic> payload) {
    final explicit = _coerceBool(payload['is_admin']);
    final staff = _coerceBool(payload['is_staff']);
    final superuser = _coerceBool(payload['is_superuser']);
    if (explicit != null) {
      _currentIsAdmin = explicit;
      return;
    }
    if (staff != null || superuser != null) {
      _currentIsAdmin = (staff ?? false) || (superuser ?? false);
    }
  }

  /// Persist or clear the "remember me" credentials.
  static Future<void> _persistRememberMe({
    required bool remember,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);
    if (remember) {
      await prefs.setString(_rememberUserKey, username);
      await prefs.setString(_rememberPasswordKey, password);
    } else {
      await prefs.remove(_rememberUserKey);
      await prefs.remove(_rememberPasswordKey);
    }
  }

  /// Clear any stored "remember me" state.
  static Future<void> clearRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, false);
    await prefs.remove(_rememberUserKey);
    await prefs.remove(_rememberPasswordKey);
  }

  /// Returns whether the user previously opted into "Remind me next time".
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? false;
  }

  /// Attempts to perform an automatic login using stored credentials.
  ///
  /// Returns true when login succeeded and the in-memory session was updated.
  static Future<bool> tryAutoLoginFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? false;
    if (!remember) return false;

    final username = prefs.getString(_rememberUserKey);
    final password = prefs.getString(_rememberPasswordKey);
    if (username == null || password == null) {
      return false;
    }
    try {
      await Api().login(username, password, rememberMe: true);
      return true;
    } on ApiError {
      await clearRememberedLogin();
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _ensureTrailingSlash(String value) => value.endsWith('/') ? value : '$value/';

  Uri _u(String path) => Uri.parse(baseUrl + path);

  static String get _cookieHeaderValue {
    if (_cookies.isEmpty) return '';
    return _cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  static String? get _csrfToken =>
      _cookies['csrftoken'] ?? readCookie('csrftoken');

  Map<String, String> _headersWithCookies([Map<String, String>? headers]) {
    final resolved = <String, String>{};
    if (headers != null) {
      resolved.addAll(headers);
    }
    if (!kIsWeb) {
      final cookieHeader = _cookieHeaderValue;
      if (cookieHeader.isNotEmpty) {
        resolved['Cookie'] = cookieHeader;
      }
    }
    return resolved;
  }

  static void _storeCookiesFromHeaders(Map<String, String> headers) {
    final raw = headers['set-cookie'];
    if (raw == null || raw.trim().isEmpty) return;

    for (final cookie in _splitSetCookieHeader(raw)) {
      final parts = cookie.split(';');
      if (parts.isEmpty) continue;
      final nameValue = parts.first.trim();
      final equalsIndex = nameValue.indexOf('=');
      if (equalsIndex <= 0) continue;
      final name = nameValue.substring(0, equalsIndex).trim();
      final value = nameValue.substring(equalsIndex + 1).trim();
      if (name.isEmpty) continue;
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  static List<String> _splitSetCookieHeader(String header) {
    final result = <String>[];
    var start = 0;
    var inExpires = false;
    for (var index = 0; index < header.length; index++) {
      final char = header[index];
      if (!inExpires && index + 8 <= header.length) {
        final maybeExpires = header.substring(index, index + 8).toLowerCase();
        if (maybeExpires == 'expires=') {
          inExpires = true;
        }
      }
      if (inExpires && char == ';') {
        inExpires = false;
      }
      if (char != ',' || inExpires) continue;

      var next = index + 1;
      while (next < header.length && header[next] == ' ') {
        next++;
      }
      if (next >= header.length) continue;

      final equalsIndex = header.indexOf('=', next);
      if (equalsIndex == -1) continue;

      final semicolonIndex = header.indexOf(';', next);
      final commaIndex = header.indexOf(',', next);
      var boundary = header.length;
      if (semicolonIndex != -1 && semicolonIndex < boundary) boundary = semicolonIndex;
      if (commaIndex != -1 && commaIndex < boundary) boundary = commaIndex;

      if (equalsIndex >= boundary) continue;

      final chunk = header.substring(start, index).trim();
      if (chunk.isNotEmpty) result.add(chunk);
      start = next;
    }

    final tail = header.substring(start).trim();
    if (tail.isNotEmpty) result.add(tail);
    return result;
  }

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() send,
  ) async {
    try {
      final response = await send();
      _storeCookiesFromHeaders(response.headers);
      return response;
    } on SocketException catch (e) {
      throw ApiError(
        'Could not reach the server at $baseUrl. '
        'Ensure the backend is running and API_BASE_URL is reachable. (${e.message})',
      );
    } on http.ClientException catch (e) {
      throw ApiError(
        'Could not reach the server at $baseUrl. '
        'Check your network connection or CORS configuration. (${e.message})',
      );
    }
  }

  Future<http.StreamedResponse> _sendStreamedRequest(
    Future<http.StreamedResponse> Function() send,
  ) async {
    try {
      final response = await send();
      _storeCookiesFromHeaders(response.headers);
      return response;
    } on SocketException catch (e) {
      throw ApiError(
        'Could not reach the server at $baseUrl. '
        'Ensure the backend is running and API_BASE_URL is reachable. (${e.message})',
      );
    } on http.ClientException catch (e) {
      throw ApiError(
        'Could not reach the server at $baseUrl. '
        'Check your network connection or CORS configuration. (${e.message})',
      );
    }
  }

  Future<Map<String, dynamic>> register(String username, String password,
      {String? email}) async {
    final res = await _sendRequest(
      () => _client.post(
        _u('register/'),
        headers: _headersWithCookies({'Content-Type': 'application/json'}),
        body: jsonEncode({
          'username': username,
          'password': password,
          if (email != null) 'email': email,
        }),
      ),
    );
    final decoded = _decode(res);
    _updateSession(decoded);
    return decoded;
  }

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    final res = await _sendRequest(
      () => _client.post(
        _u('login/'),
        headers: _headersWithCookies({'Content-Type': 'application/json'}),
        body: jsonEncode({'username': username, 'password': password}),
      ),
    );
    final decoded = _decode(res);
    _updateSession(decoded);
    // Fire-and-forget persistence; we don't block the caller on disk I/O.
    // If this fails it only affects auto-login, not the current session.
    // ignore: unawaited_futures
    _persistRememberMe(
      remember: rememberMe,
      username: username,
      password: password,
    );
    return decoded;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _sendRequest(() => _client.get(_u('me/'), headers: _headersWithCookies()));
    final decoded = _decode(res);
    if (decoded['authenticated'] == true) {
      _updateSession(decoded);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> logout() async {
    final res = await _sendRequest(() => _client.post(_u('logout/'), headers: _headersWithCookies()));
    final decoded = _decode(res);
    _clearSession();
    _clearCookies();
    await clearRememberedLogin();
    return decoded;
  }

  Future<Map<String, dynamic>> fetchAccount(int userId) async {
    final uri = _u('account/?user_id=$userId');
    final res = await _sendRequest(() => _client.get(uri, headers: _headersWithCookies()));
    final decoded = _decode(res);
    final rawData = _unwrapData(decoded);
    final data = _normalizeAvatarPayload(Map<String, dynamic>.from(rawData));
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
    request.headers.addAll(_headersWithCookies());
    final streamed = await _sendStreamedRequest(() => _client.send(request));
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response);
    final rawData = _unwrapData(decoded);
    final data = _normalizeAvatarPayload(Map<String, dynamic>.from(rawData));
    _updateSession(data);
    return data;
  }

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final res = await _sendRequest(
      () => _client.post(
        _u('account/password/'),
        headers: _headersWithCookies({'Content-Type': 'application/json'}),
        body: jsonEncode({
          'user_id': userId,
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      ),
    );
    _decode(res);
  }

  Future<List<Map<String, dynamic>>> fetchWishlist({required int userId}) async {
    final uri = _u('wishlist/?user_id=$userId');
    final res = await _sendRequest(() => _client.get(uri, headers: _headersWithCookies()));
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
    final res = await _sendRequest(
      () => _client.post(
        _u('wishlist/'),
        headers: _headersWithCookies({'Content-Type': 'application/json'}),
        body: jsonEncode({'user_id': userId, 'venue_id': venueId}),
      ),
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
    final res = await _sendRequest(
      () => _client.delete(
        _u('wishlist/'),
        headers: _headersWithCookies({'Content-Type': 'application/json'}),
        body: jsonEncode({'user_id': userId, 'venue_id': venueId}),
      ),
    );
    _decode(res);
  }

  Future<void> ensureCsrfToken() async {
    final token = _csrfToken;
    if (token != null && token.isNotEmpty) return;
    final uri = _u('csrf/');
    await _sendRequest(() => _client.get(uri, headers: _headersWithCookies()));
  }

  Future<bool> resolveAdminStatus() async {
    final cached = _currentIsAdmin;
    if (cached != null) return cached;

    try {
      await me();
    } catch (_) {
      // ignore me() failures; we'll fall back to a probe.
    }
    final refreshed = _currentIsAdmin;
    if (refreshed != null) return refreshed;

    try {
      final probe = await adminVenuesList(page: 1, pageSize: 1);
      final success = probe['success'] == true;
      _currentIsAdmin = success;
      return success;
    } catch (_) {
      _currentIsAdmin = false;
      return false;
    }
  }

  Future<Map<String, dynamic>> adminVenuesList({
    String query = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final uri = _u(
      'admin/venues/?q=${Uri.encodeQueryComponent(query)}&page=$page&page_size=$pageSize',
    );
    final res = await _sendRequest(() => _client.get(uri, headers: _headersWithCookies()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> adminBookingsList({
    String query = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final uri = _u(
      'admin/bookings/?q=${Uri.encodeQueryComponent(query)}&page=$page&page_size=$pageSize',
    );
    final res = await _sendRequest(() => _client.get(uri, headers: _headersWithCookies()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> adminUsersSearch({
    required String query,
  }) async {
    final uri = _u('admin/users/search/?q=${Uri.encodeQueryComponent(query)}');
    final res = await _sendRequest(() => _client.get(uri, headers: _headersWithCookies()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> adminCreateVenue({
    required String title,
    required String type,
    required String description,
    required String facilities,
    required String price,
    required String location,
    required List<Map<String, Object?>> addons,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    await ensureCsrfToken();

    final request = http.MultipartRequest('POST', _u('admin/venues/create/'));
    request.fields.addAll({
      'title': title,
      'type': type,
      'description': description,
      'facilities': facilities,
      'price': price,
      'location': location,
      'addons': jsonEncode(addons),
    });

    if (imageBytes != null && imageBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: (imageFilename == null || imageFilename.trim().isEmpty)
              ? 'venue.jpg'
              : imageFilename.trim(),
        ),
      );
    }

    request.headers.addAll(
      _headersWithCookies(
        {
          if (_csrfToken != null) 'X-CSRFToken': _csrfToken!,
          'Referer': '$_apiHostBase/admin/',
        },
      ),
    );

    final streamed = await _sendStreamedRequest(() => _client.send(request));
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<Map<String, dynamic>> adminUpdateVenue({
    required int venueId,
    required String title,
    required String type,
    required String description,
    required String facilities,
    required String price,
    required String location,
    required List<Map<String, Object?>> addons,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    await ensureCsrfToken();

    final request = http.MultipartRequest(
      'POST',
      _u('admin/venues/$venueId/update/'),
    );
    request.fields.addAll({
      'title': title,
      'type': type,
      'description': description,
      'facilities': facilities,
      'price': price,
      'location': location,
      'addons': jsonEncode(addons),
    });

    if (imageBytes != null && imageBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: (imageFilename == null || imageFilename.trim().isEmpty)
              ? 'venue.jpg'
              : imageFilename.trim(),
        ),
      );
    }

    request.headers.addAll(
      _headersWithCookies(
        {
          if (_csrfToken != null) 'X-CSRFToken': _csrfToken!,
          'Referer': '$_apiHostBase/admin/',
        },
      ),
    );

    final streamed = await _sendStreamedRequest(() => _client.send(request));
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<void> adminDeleteVenue({required int venueId}) async {
    await ensureCsrfToken();
    final res = await _sendRequest(
      () => _client.post(
        _u('admin/venues/$venueId/delete/'),
        headers: _headersWithCookies(
          {
            if (_csrfToken != null) 'X-CSRFToken': _csrfToken!,
            'Referer': '$_apiHostBase/admin/',
          },
        ),
      ),
    );
    _decode(res);
  }

  Future<Map<String, dynamic>> adminCreateBooking({
    required String username,
    required int venueId,
    required DateTime startDate,
    required DateTime endDate,
    required bool hasBeenPaid,
    required String notes,
    required List<Map<String, Object?>> selectedAddons,
  }) async {
    await ensureCsrfToken();

    final res = await _sendRequest(
      () => _client.post(
        _u('admin/bookings/create/'),
        headers: _headersWithCookies(
          {
            if (_csrfToken != null) 'X-CSRFToken': _csrfToken!,
            'Referer': '$_apiHostBase/admin/',
          },
        ),
        body: {
          'username': username,
          'venue': venueId.toString(),
          'start_date': _formatAdminDateTime(startDate),
          'end_date': _formatAdminDateTime(endDate),
          if (hasBeenPaid) 'has_been_paid': 'true',
          'notes': notes,
          'selected_addons': jsonEncode(selectedAddons),
        },
      ),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> adminUpdateBooking({
    required int bookingId,
    required String username,
    required int venueId,
    required DateTime startDate,
    required DateTime endDate,
    required bool hasBeenPaid,
    required String notes,
    required List<Map<String, Object?>> selectedAddons,
  }) async {
    await ensureCsrfToken();

    final res = await _sendRequest(
      () => _client.post(
        _u('admin/bookings/$bookingId/update/'),
        headers: _headersWithCookies(
          {
            if (_csrfToken != null) 'X-CSRFToken': _csrfToken!,
            'Referer': '$_apiHostBase/admin/',
          },
        ),
        body: {
          'username': username,
          'venue': venueId.toString(),
          'start_date': _formatAdminDateTime(startDate),
          'end_date': _formatAdminDateTime(endDate),
          if (hasBeenPaid) 'has_been_paid': 'true',
          'notes': notes,
          'selected_addons': jsonEncode(selectedAddons),
        },
      ),
    );
    return _decode(res);
  }

  Future<void> adminDeleteBooking({required int bookingId}) async {
    await ensureCsrfToken();
    final res = await _sendRequest(
      () => _client.post(
        _u('admin/bookings/$bookingId/delete/'),
        headers: _headersWithCookies(
          {
            if (_csrfToken != null) 'X-CSRFToken': _csrfToken!,
            'Referer': '$_apiHostBase/admin/',
          },
        ),
      ),
    );
    _decode(res);
  }

  String _formatAdminDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}T${two(local.hour)}:${two(local.minute)}';
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = (res.body.isEmpty) ? '{}' : res.body;
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      if (res.statusCode >= 400) {
        final condensed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
        final snippet = condensed.length > 140 ? '${condensed.substring(0, 140)}…' : condensed;
        throw ApiError('Request failed (${res.statusCode}). $snippet');
      }
      throw ApiError(
        'Received an unexpected response from the server (${res.statusCode}). '
        'Verify that $baseUrl is correct and the backend is running. (${e.message})',
      );
    }
    if (res.statusCode >= 400) {
      final detail = decoded['detail']?.toString();
      if (detail != null && detail.trim().isNotEmpty) {
        throw ApiError(detail);
      }
      final errors = decoded['errors'];
      if (errors is List) {
        final message = errors.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).join('\n');
        if (message.isNotEmpty) {
          throw ApiError(message);
        }
      }
      throw ApiError('Request failed (${res.statusCode})');
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

  Map<String, dynamic> _normalizeAvatarPayload(Map<String, dynamic> payload) {
    final resolved = _resolveAvatarUrl(_extractAvatarRaw(payload));
    if (resolved.isEmpty) return payload;
    final normalized = Map<String, dynamic>.from(payload);
    normalized['avatar_url'] = resolved;
    return normalized;
  }

  String? _extractAvatarRaw(Map<String, dynamic>? data) {
    if (data == null) return null;
    final nested = data['data'];
    final profile = data['profile'];
    final candidates = [
      data['avatar_url'],
      data['avatarUrl'],
      data['avatar'],
      data['avatar_path'],
      data['avatarPath'],
      if (nested is Map<String, dynamic>) ...[
        nested['avatar_url'],
        nested['avatar'],
        nested['avatar_path'],
        nested['avatarPath'],
      ],
      if (profile is Map<String, dynamic>) ...[
        profile['avatar_url'],
        profile['avatar'],
        profile['avatar_path'],
        profile['avatarPath'],
      ],
    ];
    for (final value in candidates) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  String _resolveAvatarUrl(String? rawUrl) {
    final value = (rawUrl ?? '').trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      final uri = Uri.tryParse(value);
      if (uri == null) return value;
      final base = _baseUri;
      final matchesBaseHost = uri.host.toLowerCase() == base.host.toLowerCase();
      final shouldUpgradeScheme = matchesBaseHost && base.scheme == 'https' && uri.scheme != 'https';
      if (shouldUpgradeScheme) {
        return uri.replace(scheme: 'https').toString();
      }
      final shouldRebase = _isLoopbackHost(uri.host);
      if (!shouldRebase) return value;
      return _mergeWithBase(uri.path, query: uri.hasQuery ? uri.query : null);
    }
    return _mergeWithBase(value);
  }

  String resolveMediaUrl(String? rawUrl) {
    return _resolveAvatarUrl(rawUrl);
  }

  String get _apiHostBase {
    final withoutApi = baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    if (withoutApi.endsWith('/')) {
      return withoutApi.substring(0, withoutApi.length - 1);
    }
    return withoutApi;
  }

  Uri get _baseUri => Uri.parse(_apiHostBase);

  bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '0.0.0.0';
  }

  String _mergeWithBase(String path, {String? query}) {
    final base = _baseUri;
    final normalizedPath =
        path.startsWith('/') ? path : '/${path.replaceFirst(RegExp(r'^/+'), '')}';
    final merged = base.replace(
      path: normalizedPath,
      query: query ?? '',
    );
    return merged.toString();
  }
}

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}
