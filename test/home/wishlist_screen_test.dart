import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk2ragaspace/features/home/home_screen.dart';

void main() {
  Map<String, dynamic> _venue({
    String key = '1',
    String name = 'Aurora Sports Dome',
    double rating = 4.5,
  }) {
    return {
      'id': int.parse(key),
      'category': 'Futsal',
      'name': name,
      'location': 'Jakarta',
      'description': 'Indoor futsal pitch',
      'price': 200000,
      'rating': rating,
      'imageUrl': '',
      'addons': const [],
    };
  }

  testWidgets('WishlistScreen shows empty state and back works',
      (tester) async {
    var removed = <Map<String, dynamic>>[];
    var selected = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      buildWishlistTestApp(
        items: const [],
        onRemove: (v) async => removed.add(v),
        onSelect: selected.add,
      ),
    );

    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Belum ada venue yang disimpan.'), findsOneWidget);

    // Tap back button and ensure Navigator.pop is triggered without crash.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(removed, isEmpty);
    expect(selected, isEmpty);
  });

  testWidgets('WishlistScreen dismiss & tap flows update state',
      (tester) async {
    final venues = [
      _venue(key: '2', name: 'Harborview Badminton Center', rating: 4.9),
      _venue(key: '3', name: 'Downtown Arena', rating: 4.2),
    ];
    final removed = <Map<String, dynamic>>[];
    final selected = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      buildWishlistTestApp(
        items: venues,
        onRemove: (v) async => removed.add(v),
        onSelect: selected.add,
      ),
    );
    await tester.pumpAndSettle();

    // At least one venue card should be rendered.
    final cardFinder =
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_VenueCard');
    expect(cardFinder, findsWidgets);

    // Swipe to dismiss the first venue -> triggers onRemove and removes it.
    final firstVenueTitle = find.text('Harborview Badminton Center');
    expect(firstVenueTitle, findsOneWidget);
    final dismissible = find.ancestor(
      of: firstVenueTitle,
      matching: find.byType(Dismissible),
    );
    final dragStart = tester.getTopLeft(dismissible) + const Offset(20, 20);
    await tester.dragFrom(dragStart, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(removed.length, 1);
    expect(removed.first['id'], 2);

    // Invoke the card's onTap directly -> onSelect.
    final remainingCard =
        tester.widget(cardFinder.first) as dynamic; // _VenueCard
    selected.clear();
    remainingCard.onTap();
    await tester.pumpAndSettle();

    expect(selected.length, 1);
    expect(selected.first['id'], 3);

    // Trigger onToggleFavorite directly on the remaining card -> _removeItem.
    removed.clear();
    final toggledCard =
        tester.widget(cardFinder.first) as dynamic; // _VenueCard
    toggledCard.onToggleFavorite();
    await tester.pumpAndSettle();

    // Item removed via favorite toggle and callback called.
    expect(removed.length, 1);
  });
}
