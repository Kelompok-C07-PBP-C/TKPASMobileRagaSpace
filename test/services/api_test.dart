import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marco/services/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _jsonResponse(
  HttpRequest req,
  Map<String, dynamic> payload, {
  int status = 200,
}) async {
  final body = jsonEncode(payload);
  req.response.statusCode = status;
  req.response.headers.contentType = ContentType.json;
  req.response.write(body);
  await req.response.close();
}

void main() {
  late HttpServer server;
  late String baseUrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://${server.address.host}:${server.port}/api/';

    server.listen((HttpRequest req) async {
      final path = req.uri.path;
      if (path.endsWith('/api/register/') || path.endsWith('/api/login/')) {
        await _jsonResponse(req, {'id': 1, 'username': 'tester'});
        return;
      }
      if (path.endsWith('/api/me/')) {
        await _jsonResponse(req, {'authenticated': true, 'id': 2, 'username': 'me'});
        return;
      }
      if (path.contains('/api/account/') && req.uri.queryParameters.containsKey('user_id')) {
        final id = req.uri.queryParameters['user_id'];
        await _jsonResponse(req, {
          'data': {'id': id, 'username': 'account-$id'}
        });
        return;
      }
      if (path.contains('/api/wishlist/') && req.method == 'GET') {
        await _jsonResponse(req, {
          'data': [
            {'id': 9}
          ]
        });
        return;
      }
      if (path.contains('/api/wishlist/') && (req.method == 'POST' || req.method == 'DELETE')) {
        await _jsonResponse(req, {
          'data': {'id': 11}
        }, status: req.method == 'DELETE' ? 204 : 200);
        return;
      }
      if (path.contains('/api/fail/')) {
        await _jsonResponse(req, {'detail': 'boom'}, status: 500);
        return;
      }
      await _jsonResponse(req, {'detail': 'not found'}, status: 404);
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('login updates session state', () async {
    final api = Api(baseUrl: baseUrl);
    final res = await api.login('user', 'pass');
    expect(res['id'], 1);
    expect(Api.currentUserId, 1);
    expect(Api.currentUsername, 'tester');
  });

  test('fetchAccount unwraps data field', () async {
    final api = Api(baseUrl: baseUrl);
    final res = await api.fetchAccount(7);
    expect(res['id'], '7');
    expect(res['username'], 'account-7');
  });

  test('fetchWishlist returns list and add/remove succeed', () async {
    final api = Api(baseUrl: baseUrl);
    final list = await api.fetchWishlist(userId: 3);
    expect(list, isNotEmpty);
    final added = await api.addWishlistItem(userId: 3, venueId: 12);
    expect(added['id'], 11);
    await api.removeWishlistItem(userId: 3, venueId: 12); // should not throw
  });

  test('decode throws ApiError on non-200 responses', () async {
    final api = Api(baseUrl: '${baseUrl}fail/');
    expect(
      () => api.me(),
      throwsA(isA<ApiError>()),
    );
  });
}
