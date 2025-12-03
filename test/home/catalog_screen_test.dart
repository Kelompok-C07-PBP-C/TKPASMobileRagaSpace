import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:marco/features/home/home_screen.dart';

void main() {
  Map<String, dynamic> _productJson({
    required int id,
    required String title,
    String city = 'Jakarta',
    String type = 'Futsal',
    int price = 200000,
    double rating = 4.5,
    String description = 'Indoor futsal pitch',
  }) {
    return {
      'id': id,
      'title': title,
      'type': type,
      'city': city,
      'location': '$city, Indonesia',
      'description': description,
      'price': price,
      'average_rating': rating,
      'image_url': '',
      'addons': const [],
    };
  }

  tearDown(() {
    catalogHttpGetOverride = null;
  });

  testWidgets('CatalogScreen loads products, filters, and favorites (wide)',
      (tester) async {
    final completer = Completer<http.Response>();
    final toggled = <Map<String, dynamic>>[];
    var toggleCallCount = 0;

    catalogHttpGetOverride = (_) => completer.future;

    await tester.pumpWidget(
      buildCatalogTestApp(
        initialWishlistKeys: {'id:1'},
        onToggleFavorite: (venue) async {
          toggled.add(venue);
          toggleCallCount++;
          // First call marks as favorite, second call unmarks.
          return toggleCallCount == 1;
        },
      ),
    );

    // Initial loading indicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete network call with two products.
    completer.complete(http.Response(
      jsonEncode([
        _productJson(id: 1, title: 'Aurora Sports Dome'),
        _productJson(id: 2, title: 'Harborview Badminton Center'),
      ]),
      200,
    ));
    await tester.pumpAndSettle();

    // Header and filter panel.
    expect(find.text('Product Catalog'), findsOneWidget);
    expect(find.text('Filter venues'), findsOneWidget);

    // Change each dropdown to exercise onChanged handlers.
    await tester.tap(find.text('All cities'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jakarta').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('All categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futsal').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Any price'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('< Rp 400k').last);
    await tester.pumpAndSettle();

    // Search button tapped to exercise callback.
    await tester.tap(find.text('Search venues'));
    await tester.pump();

    // Catalog product cards rendered.
    final cardFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_CatalogProductCard',
    );
    expect(cardFinder, findsWidgets);

    // Toggle favorite via the badge button -> _toggleProductFavorite success
    // and false branches, plus badge onTap wrapper.
    final favFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_FavoriteBadgeButton',
    );
    expect(favFinder, findsWidgets);
    final favButton = tester.widget(favFinder.first) as dynamic;
    favButton.onTap();
    await tester.pumpAndSettle();
    favButton.onTap();
    await tester.pumpAndSettle();
    expect(toggled, isNotEmpty);

    // Trigger card onTap (Navigator.pop(product)).
    final firstCard = tester.widget(cardFinder.first) as dynamic;
    firstCard.onTap();
    await tester.pumpAndSettle();
  });

  testWidgets('CatalogScreen shows error then reloads products', (tester) async {
    var attempts = 0;
    catalogHttpGetOverride = (_) async {
      attempts++;
      if (attempts == 1) {
        return http.Response('error', 500);
      }
      return http.Response(
        jsonEncode([_productJson(id: 3, title: 'Downtown Arena')]),
        200,
      );
    };

    await tester.pumpWidget(
      buildCatalogTestApp(
        onToggleFavorite: (_) async => false,
      ),
    );
    await tester.pumpAndSettle();

    // Error card shown.
    expect(find.text('Tidak bisa memuat katalog'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    // Retry button triggers successful reload.
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_CatalogProductCard',
      ),
      findsOneWidget,
    );
  });

  testWidgets('CatalogScreen back button pops route', (tester) async {
    catalogHttpGetOverride = (_) async {
      final product = _productJson(id: 6, title: 'Back Test');
      product['id'] = '6'; // exercise id string parsing branch
      return http.Response(jsonEncode([product]), 200);
    };

    await tester.pumpWidget(
      buildCatalogTestApp(
        onToggleFavorite: (_) async => false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('CatalogScreen empty-state reset filters', (tester) async {
    catalogHttpGetOverride = (_) async => http.Response(
          jsonEncode(
              [_productJson(id: 4, title: 'City Stadium', city: 'Jakarta')]),
          200,
        );

    // Start with filters that will exclude the product (Bandung).
    await tester.pumpWidget(
      buildCatalogTestApp(
        initialCity: 'Bandung',
        onToggleFavorite: (_) async => false,
      ),
    );
    await tester.pumpAndSettle();

    // Empty state shown.
    expect(
      find.text('Tidak ada venue dengan filter ini.'),
      findsOneWidget,
    );

    // Reset filters -> product should appear.
    await tester.tap(find.text('Reset filter'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_CatalogProductCard',
      ),
      findsOneWidget,
    );
  });

  testWidgets('CatalogScreen narrow layout and favorite toggle error ignored',
      (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized()
        as TestWidgetsFlutterBinding;
    binding.window.physicalSizeTestValue = const Size(400, 800);
    binding.window.devicePixelRatioTestValue = 1.0;

    addTearDown(() {
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    // onToggleFavorite throws to exercise catch branch and description fallback.
    catalogHttpGetOverride = (_) async => http.Response(
          jsonEncode([
            _productJson(
              id: 5,
              title: 'Narrow Court',
              description: '',
            )
          ]),
          200,
        );

    await tester.pumpWidget(
      buildCatalogTestApp(
        onToggleFavorite: (_) async => throw Exception('fail'),
      ),
    );
    await tester.pumpAndSettle();

    final favFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_FavoriteBadgeButton',
    );
    expect(favFinder, findsOneWidget);

    final favButton = tester.widget(favFinder.first) as dynamic;
    // This will hit _toggleProductFavorite and go through the catch branch.
    favButton.onTap();
    await tester.pumpAndSettle();
  });
}
