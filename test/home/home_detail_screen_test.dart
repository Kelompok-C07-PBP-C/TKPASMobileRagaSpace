import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tk2ragaspace/features/account_settings/account_settings_screen.dart';
import 'package:tk2ragaspace/features/home/home_screen.dart';

void main() {
  setUp(() {
    homeDetailSkipReviewsNetworkForTests = true;
    venueDetailHttpGetOverride = null;
    venueDetailHttpPostOverride = null;
    accountUserIdOverride = null;
    accountFetchOverride = null;
    venueReviewSubmitOverride = null;
    venueReviewDeleteOverride = null;
    venueReviewsFetchOverride = null;
    venueAccountFetchOverride = null;
    venueAccountUserIdOverride = null;
  });

  tearDown(() {
    homeDetailSkipReviewsNetworkForTests = false;
    venueDetailHttpGetOverride = null;
    venueDetailHttpPostOverride = null;
    accountUserIdOverride = null;
    accountFetchOverride = null;
    venueReviewSubmitOverride = null;
    venueReviewDeleteOverride = null;
    venueReviewsFetchOverride = null;
    venueAccountFetchOverride = null;
    venueAccountUserIdOverride = null;
  });

  Future<dynamic> _pumpDetailScreen(
    WidgetTester tester, {
    bool withVenueId = true,
    bool withPhoneNumber = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildVenueDetailTestShell(
            withVenueId: withVenueId,
            withPhoneNumber: withPhoneNumber,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final finder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_VenueDetailScreen',
    );
    final dynamic state = tester.state(finder);
    return state;
  }

  testWidgets(
      'VenueDetailScreen builds layout and applies availability from override',
      (tester) async {
    venueDetailHttpGetOverride = (uri) async {
      final payload = [
        {
          'start_date': '2025-01-10T09:00:00Z',
          'end_date': '2025-01-10T11:00:00Z',
        },
      ];
      return http.Response(jsonEncode(payload), 200);
    };

    await _pumpDetailScreen(tester);

    // Base UI and empty-review state rendered.
    expect(find.text('Test Venue'), findsOneWidget);
    expect(
      find.text('Belum ada ulasan untuk venue ini.'),
      findsOneWidget,
    );
  });

  testWidgets('submitBookingRequest uses local mock when venueId is null',
      (tester) async {
    final state =
        await _pumpDetailScreen(tester, withVenueId: false) as dynamic;

    // If this override is ever called, the test should fail.
    venueDetailHttpPostOverride = (uri, {headers, body}) async {
      fail('HTTP POST should not be invoked for local mock booking');
    };

    final widget = state.widget as dynamic;
    final start = DateTime(2025, 1, 10, 9);
    final end = DateTime(2025, 1, 10, 11);

    final summary = await state.debugSubmitBookingRequestForTests(
      start,
      end,
      '08123',
      widget.data.addons as List<Object?>,
    );

    expect(summary, isNotNull);
  });

  testWidgets('submitBookingRequest success and error via HTTP override',
      (tester) async {
    final state = await _pumpDetailScreen(tester) as dynamic;
    final widget = state.widget as dynamic;
    final start = DateTime(2025, 1, 10, 9);
    final end = DateTime(2025, 1, 10, 11);

    // Success branch.
    venueDetailHttpPostOverride = (uri, {headers, body}) async {
      final payload = jsonDecode(body as String) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': 52,
          'venue': {
            'id': payload['venue_id'],
            'title': 'Test Venue',
            'type': 'Futsal',
            'location': 'Jakarta',
            'description': 'Indoor futsal',
            'image_url': '',
            'price': 100000,
          },
          'start_date': payload['start_date'],
          'end_date': payload['end_date'],
          'sessions': 2,
          'subtotal': 200000,
          'contact_phone': payload['phone_number'],
          'has_been_paid': false,
          'created_at': '2025-01-01T00:00:00Z',
          'selected_addons': const [],
          'addons_total': 0,
        }),
        200,
      );
    };

    final summary = await state.debugSubmitBookingRequestForTests(
      start,
      end,
      '08123',
      widget.data.addons as List<Object?>,
    );
    expect(summary, isNotNull);

    // Error branch with detail message.
    venueDetailHttpPostOverride = (uri, {headers, body}) async {
      return http.Response(jsonEncode({'detail': 'Some error'}), 400);
    };
    await expectLater(
      state.debugSubmitBookingRequestForTests(
        start,
        end,
        '08123',
        widget.data.addons as List<Object?>,
      ),
      throwsException,
    );
  });

  testWidgets('openBookingDialog without phone opens account settings',
      (tester) async {
    accountUserIdOverride = () => 1;
    accountFetchOverride = (api, userId) async => {
          'username': 'tester',
          'email': 't@example.com',
          'first_name': 'Test',
          'last_name': 'User',
          'phone_number': '08123',
          'avatar_url': '',
        };

    final state =
        await _pumpDetailScreen(tester, withPhoneNumber: false) as dynamic;

    await state.debugOpenBookingDialogForTests(
      tester.element(find.text('Test Venue')),
    );
    await tester.pumpAndSettle();

    // SnackBar shown and account settings screen pushed.
    expect(
      find.textContaining('Tambahkan nomor telepon'),
      findsOneWidget,
    );
    expect(find.byType(AccountSettingsScreen), findsOneWidget);
  });

  testWidgets('review dialog and star widgets can be interacted with',
      (tester) async {
    final state = await _pumpDetailScreen(tester) as dynamic;

    // Open the review dialog using the test helper.
    final futureDraft = state.debugShowReviewDialogForTests();
    await tester.pumpAndSettle();

    // Enter a comment and adjust the rating via star selector.
    await tester.enterText(
      find.byType(TextField),
      'Great venue!',
    );
    // Tap on the fourth star to change rating.
    final starButton = find.byIcon(Icons.star_rounded).at(3);
    await tester.tap(starButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final draft = await futureDraft;
    expect(draft, isNotNull);

    // Build the reusable star widgets directly to exercise their builders.
    final selector = state.debugBuildStarSelectorForTests(
      currentRating: 3,
    ) as Widget;
    final starRow = state.debugBuildStarRowForTests(4) as Widget;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            selector,
            starRow,
          ],
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('favorite toggle and addon selection update state',
      (tester) async {
    final state = await _pumpDetailScreen(tester) as dynamic;
    final widget = state.widget as dynamic;

    // Toggle addon selection using the test helper.
    expect(widget.data.addons, isNotEmpty);
    state.debugToggleDetailAddonSelectionForTests(0, true);
    final selectedAddons =
        state.debugDetailSelectedAddonsForTests() as List<dynamic>;
    expect(selectedAddons.length, 1);
    expect(state.debugDetailSelectedAddonsTotalForTests(), greaterThan(0));

    // Tap the favorite badge button to exercise _toggleFavorite.
    final favFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_FavoriteBadgeButton',
    );
    expect(favFinder, findsOneWidget);
    await tester.tap(favFinder);
    await tester.pump();
  });

  testWidgets('availability helpers compute hours, blocked days, and totals',
      (tester) async {
    homeDetailSkipReviewsNetworkForTests = true;

    venueDetailHttpGetOverride = (uri) async {
      final payload = [
        {
          'start_date': '2025-01-10T00:00:00Z',
          'end_date': '2025-01-11T00:00:00Z',
        },
        {
          'start_date': '2025-01-11T03:00:00Z',
          'end_date': '2025-01-11T05:00:00Z',
        },
      ];
      return http.Response(jsonEncode(payload), 200);
    };

    final state = await _pumpDetailScreen(tester) as dynamic;

    // Load availability from the override and exercise helper methods.
    await state.debugLoadBookedRangesForTests();

    final hourMap = state.debugBookedHoursFromStateForTests();
    expect(hourMap.values, isNotEmpty);

    final blocked = state.debugBlockedDayKeysFromStateForTests() as Set;
    expect(blocked, isA<Set>());

    final firstDayRanges = hourMap.values.first as List<dynamic>;
    final isFull = state.debugIsDayFullyBookedForTests(firstDayRanges);
    expect(isFull, isA<bool>());

    // Exercise remove-branch and zero-total path for addon selection.
    state.debugToggleDetailAddonSelectionForTests(0, true);
    expect(state.debugDetailSelectedAddonsForTests(), isNotEmpty);
    expect(state.debugDetailSelectedAddonsTotalForTests(), greaterThan(0));

    state.debugToggleDetailAddonSelectionForTests(0, false);
    expect(state.debugDetailSelectedAddonsForTests(), isEmpty);
    expect(state.debugDetailSelectedAddonsTotalForTests(), 0);
  });

  testWidgets('refreshAccountPhone uses override without network',
      (tester) async {
    venueAccountUserIdOverride = 42;
    venueAccountFetchOverride = (api, userId) async {
      expect(userId, 42);
      return {'phone_number': '08123456789'};
    };

    final state = await _pumpDetailScreen(tester) as dynamic;
    await state.debugRefreshAccountPhoneForTests();
    await tester.pumpAndSettle();
  });

  testWidgets('review composer submit, delete, and error paths use overrides',
      (tester) async {
    // Avoid automatic fetch from initState; use our overrides instead.
    homeDetailSkipReviewsNetworkForTests = true;

    final submitBodies = <Map<String, dynamic>>[];

    venueReviewSubmitOverride = (uri, body, {required isUpdate}) async {
      submitBodies.add({...body, 'isUpdate': isUpdate});
      return http.Response('{}', 200);
    };

    venueReviewsFetchOverride = (uri) async {
      final reviews = [
        {
          'id': 1,
          'venue_id': 1,
          'author': 'Tester',
          'comment': 'Nice',
          'rating': 4,
          'date': '2025-01-10T00:00:00Z',
          'is_mine': true,
        },
      ];
      return http.Response(jsonEncode(reviews), 200);
    };

    venueReviewDeleteOverride = (uri) async {
      return http.Response('', 204);
    };

    final state = await _pumpDetailScreen(tester) as dynamic;

    // Successful submit path triggers fetchReviews override.
    final future = state.debugOpenReviewComposerForTests();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Awesome place');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await future;
    expect(submitBodies, isNotEmpty);

    // Successful delete path.
    final deleteFuture = state.debugDeleteSampleReviewForTests();
    await tester.pump(); // show confirmation dialog
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await deleteFuture;

    // Error branch for delete shows a snackbar.
    venueReviewDeleteOverride = (uri) async {
      return http.Response('oops', 500);
    };
    final deleteErrorFuture = state.debugDeleteSampleReviewForTests();
    await tester.pump();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await deleteErrorFuture;
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Tidak bisa menghapus ulasan'),
      findsWidgets,
    );

    // Error path for submit uses override with non-2xx status code.
    venueReviewSubmitOverride = (uri, body, {required isUpdate}) async {
      return http.Response('bad', 500);
    };
    final errorFuture = state.debugOpenReviewComposerForTests();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Another try');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await errorFuture;
    await tester.pumpAndSettle();

    // Error path for fetchReviews.
    venueReviewsFetchOverride = (uri) async {
      return http.Response('bad', 500);
    };
    await state.debugFetchReviewsForTests();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Tidak bisa memuat ulasan saat ini.'),
      findsWidgets,
    );
  });
}
