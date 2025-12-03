import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marco/features/home/home_screen.dart';

void main() {
  testWidgets('buildDetailChipForTests renders provided text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildDetailChipForTests('Indoor, AC, Parking'),
        ),
      ),
    );
    expect(find.text('Indoor, AC, Parking'), findsOneWidget);
  });

  testWidgets('buildReviewCardForTests shows author, rating, and comment',
      (tester) async {
    var editTapped = false;
    var deleteTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildReviewCardForTests(
            author: 'Tester',
            comment: 'Nice place',
            rating: 4,
            starBuilder: (rating, {double size = 18}) =>
                Text('stars:$rating'),
            onEdit: () => editTapped = true,
            onDelete: () => deleteTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Tester'), findsOneWidget);
    expect(find.textContaining('Nice place'), findsOneWidget);
    expect(find.text('stars:4'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.tap(find.byIcon(Icons.delete_forever));
    expect(editTapped, isTrue);
    expect(deleteTapped, isTrue);
  });

  testWidgets('buildAddonInfoCardForTests renders name, price, description',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildAddonInfoCardForTests(
            name: 'Massage',
            price: 50000,
            description: 'Relax after the game',
          ),
        ),
      ),
    );

    expect(find.text('Massage'), findsOneWidget);
    expect(find.textContaining('Relax after the game'), findsOneWidget);
    expect(find.textContaining('Rp'), findsWidgets);
  });

  test('resolveMediaUrlGlobalForTests normalizes relative paths', () {
    // Empty becomes empty.
    expect(resolveMediaUrlGlobalForTests(''), '');

    // Absolute URLs are untouched.
    expect(
      resolveMediaUrlGlobalForTests('https://example.com/image.png'),
      'https://example.com/image.png',
    );

    // Relative URL gets prefixed with _apiHostBase.
    final resolved = resolveMediaUrlGlobalForTests('media/image.png');
    expect(resolved.contains('media/image.png'), isTrue);
  });
}
