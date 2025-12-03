import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:marco/features/home/home_screen.dart';
import 'package:marco/services/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  Future<dynamic> _pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    return tester.state(find.byType(HomeScreen));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    homeSkipNetworkForTests = true;
    homeDisableNetworkImagesForTests = true;
    debugSetFadeSlideInDisabledForTests(true);
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    wishlistFetchOverride = null;
    wishlistAddOverride = null;
    wishlistRemoveOverride = null;
    wishlistHttpGetOverride = null;
    wishlistUserIdOverride = null;
  });

  tearDown(() {
    homeSkipNetworkForTests = false;
    homeDisableNetworkImagesForTests = false;
    debugSetFadeSlideInDisabledForTests(false);
    wishlistFetchOverride = null;
    wishlistAddOverride = null;
    wishlistRemoveOverride = null;
    wishlistHttpGetOverride = null;
    wishlistUserIdOverride = null;
  });

  testWidgets('restoreWishlistFromStorage cleans invalid and orphaned entries',
      (tester) async {
    final stored = [
      jsonEncode({'id': 1, 'title': 'Saved venue'}),
      'not-json',
      jsonEncode({'id': null, 'title': 'Missing id'}),
    ];
    SharedPreferences.setMockInitialValues({
      'wishlist_venues:guest': stored,
    });

    wishlistHttpGetOverride = (uri) async {
      final body = jsonEncode([
        {'id': 1},
        {'id': 999},
      ]);
      return http.Response(body, 200);
    };

    final dynamic state = await _pumpHome(tester);
    final items =
        await state.debugRestoreWishlistFromStorageForTests() as List<dynamic>;
    await tester.pump();

    expect(items.length, 1);
    final keys = state.debugWishlistKeysForTests() as Set;
    expect(keys.length, 1);
  });

  testWidgets('_fetchAllVenueIds handles non-200 responses', (tester) async {
    wishlistHttpGetOverride =
        (uri) async => http.Response('nope', 500); // non-200 path

    final dynamic state = await _pumpHome(tester);
    final ids = await state.debugFetchAllVenueIdsForTests();
    expect(ids, isNull);
  });

  testWidgets('_syncWishlistFromServer merges remote items and handles errors',
      (tester) async {
    wishlistUserIdOverride = 42;

    wishlistFetchOverride = ({required int userId}) async {
      return [
        {
          'id': 10,
          'title': 'Synced Venue',
          'image_url': '',
          'city': 'Jakarta',
          'price': 100000,
        },
        {
          'id': 'oops',
          'title': 'Bad entry',
        },
      ];
    };

    final dynamic state = await _pumpHome(tester);

    await state.debugSyncWishlistFromServerForTests(silent: true);
    await tester.pump();

    var items = state.debugWishlistItemsForTests() as List;
    expect(items, isNotEmpty);

    // Error branch: fetch throws and silent=false shows a snackbar.
    wishlistFetchOverride = ({required int userId}) async {
      throw ApiError('Server down');
    };

    await state.debugSyncWishlistFromServerForTests(silent: false);
    await tester.pump();

    expect(find.byType(SnackBar), findsWidgets);
  });

  testWidgets('_toggleWishlist optimistic update and rollback on error',
      (tester) async {
    wishlistUserIdOverride = 99;

    // Seed one remote item so that wishlist has content.
    wishlistFetchOverride = ({required int userId}) async => [
          {
            'id': 77,
            'title': 'Favourite',
            'image_url': '',
            'city': 'Bandung',
            'price': 200000,
          },
        ];

    final dynamic state = await _pumpHome(tester);
    await state.debugSyncWishlistFromServerForTests(silent: true);
    await tester.pump();

    var items = state.debugWishlistItemsForTests() as List;
    final item = items.first;

    // Remove item via server override.
    final removed =
        await state.debugToggleWishlistAndReturnForTests(item as dynamic);
    await tester.pump();

    // Re-add with a failing server call to trigger rollback and error snackbar.
    wishlistAddOverride = ({
      required int userId,
      required int venueId,
    }) async {
      throw ApiError('Add failed');
    };

    final added =
        await state.debugToggleWishlistAndReturnForTests(item as dynamic);
    await tester.pump();

    items = state.debugWishlistItemsForTests() as List;
    expect(items.length, 1); // rolled back to previous list
    expect(find.byType(SnackBar), findsWidgets);
  });
}
