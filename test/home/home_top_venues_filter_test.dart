import 'package:flutter_test/flutter_test.dart';
import 'package:marco/features/home/home_screen.dart';

void main() {
  group('_filterVenues applies city, category, and price filters', () {
    final venues = [
      {
        'category': 'Futsal',
        'name': 'Aurora Sports Dome',
        'location': 'Jakarta',
        'description': 'Indoor futsal pitch',
        'price': 150000,
        'rating': 4.5,
        'imageUrl': '',
        'id': 1,
      },
      {
        'category': 'Badminton',
        'name': 'Harborview Badminton Center',
        'location': 'Bandung',
        'description': 'Badminton courts',
        'price': 350000,
        'rating': 4.8,
        'imageUrl': '',
        'id': 2,
      },
      {
        'category': 'Basket',
        'name': 'City Court',
        'location': 'Surabaya',
        'description': 'Basket court',
        'price': 650000,
        'rating': 4.2,
        'imageUrl': '',
        'id': 3,
      },
    ];

    test('no filters returns all venues', () {
      final result = debugFilterVenuesForTests(
        venues,
        city: 'All cities',
        category: 'All categories',
        price: 'Any price',
      );
      expect(result.length, venues.length);
    });

    test('city filter matches substring in location', () {
      final result = debugFilterVenuesForTests(
        venues,
        city: 'Jakarta',
        category: 'All categories',
        price: 'Any price',
      );
      expect(result.length, 1);
      expect(result.first['name'], 'Aurora Sports Dome');
    });

    test('category filter matches category name', () {
      final result = debugFilterVenuesForTests(
        venues,
        city: 'All cities',
        category: 'Badminton',
        price: 'Any price',
      );
      expect(result.length, 1);
      expect(result.first['name'], 'Harborview Badminton Center');
    });

    test('price filters cover all branches', () {
      // < Rp 200k -> only the cheap futsal venue.
      final under200 = debugFilterVenuesForTests(
        venues,
        city: 'All cities',
        category: 'All categories',
        price: '< Rp 200k',
      );
      expect(
        under200.map((v) => v['name']),
        contains('Aurora Sports Dome'),
      );

      // < Rp 400k -> futsal + badminton.
      final under400 = debugFilterVenuesForTests(
        venues,
        city: 'All cities',
        category: 'All categories',
        price: '< Rp 400k',
      );
      expect(under400.length, 2);

      // < Rp 600k -> all but premium.
      final under600 = debugFilterVenuesForTests(
        venues,
        city: 'All cities',
        category: 'All categories',
        price: '< Rp 600k',
      );
      expect(under600.length, 2);

      // Premium -> only the most expensive.
      final premium = debugFilterVenuesForTests(
        venues,
        city: 'All cities',
        category: 'All categories',
        price: 'Premium',
      );
      expect(premium.length, 1);
      expect(premium.first['name'], 'City Court');
    });
  });
}
