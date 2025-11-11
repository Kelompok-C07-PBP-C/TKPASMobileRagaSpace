part of 'home_screen.dart';

class _CategoryChipData {
  const _CategoryChipData({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _HighlightCardData {
  const _HighlightCardData({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
}

class _PromoCardData {
  const _PromoCardData({
    required this.title,
    required this.description,
    required this.bullets,
    required this.gradient,
    required this.icon,
  });
  final String title;
  final String description;
  final List<String> bullets;
  final List<Color> gradient;
  final IconData icon;
}

class _TestimonialData {
  const _TestimonialData({
    required this.name,
    required this.role,
    required this.quote,
    required this.avatarUrl,
  });
  final String name;
  final String role;
  final String quote;
  final String avatarUrl;
}

class _VenueCardData {
  const _VenueCardData({
    required this.category,
    required this.name,
    required this.location,
    required this.description,
    required this.price,
    required this.rating,
    required this.imageUrl,
    this.id,
  });

  final String category;
  final String name;
  final String location;
  final String description;
  final int price;
  final double rating;
  final String imageUrl;
  final int? id;

  Map<String, dynamic> toMap() => {
        'category': category,
        'name': name,
        'location': location,
        'description': description,
        'price': price,
        'rating': rating,
        'imageUrl': imageUrl,
        'id': id,
      };

  factory _VenueCardData.fromMap(Map<String, dynamic> map) => _VenueCardData(
        category: (map['category'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        location: (map['location'] ?? '').toString(),
        description: (map['description'] ?? '').toString(),
        price: int.tryParse(map['price']?.toString() ?? '') ?? 0,
        rating: double.tryParse(map['rating']?.toString() ?? '') ?? 0,
        imageUrl: (map['imageUrl'] ?? '').toString(),
        id: map['id'] is int ? map['id'] as int : null,
      );

  String get storageKey =>
      '${name.toLowerCase()}|${location.toLowerCase()}|$category';
}

class _CatalogProduct {
  const _CatalogProduct({
    required this.title,
    required this.category,
    required this.city,
    required this.price,
    required this.rating,
    required this.imageUrl,
  });

  final String title;
  final String category;
  final String city;
  final int price;
  final double rating;
  final String imageUrl;
}

const List<_CatalogProduct> _catalogProducts = [
  _CatalogProduct(
    title: 'Harborview Badminton Center',
    category: 'Badminton',
    city: 'Surabaya',
    price: 320000,
    rating: 4.8,
    imageUrl:
        'https://images.unsplash.com/photo-1549060279-7e168fcee0c2?auto=format&fit=crop&w=600&q=80',
  ),
  _CatalogProduct(
    title: 'Aurora Sports Dome',
    category: 'Futsal',
    city: 'Jakarta',
    price: 550000,
    rating: 4.9,
    imageUrl:
        'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=600&q=80',
  ),
  _CatalogProduct(
    title: 'Summit Court Arena',
    category: 'Basket',
    city: 'Bandung',
    price: 680000,
    rating: 4.7,
    imageUrl:
        'https://images.unsplash.com/photo-1502740479091-635887520276?auto=format&fit=crop&w=600&q=80',
  ),
  _CatalogProduct(
    title: 'Padel Loft',
    category: 'Tennis',
    city: 'Jakarta',
    price: 420000,
    rating: 4.5,
    imageUrl:
        'https://images.unsplash.com/photo-1521412644187-c49fa049e84d?auto=format&fit=crop&w=600&q=80',
  ),
  _CatalogProduct(
    title: 'Bali Seaside Court',
    category: 'Basket',
    city: 'Bali',
    price: 360000,
    rating: 4.6,
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=600&q=80',
  ),
  _CatalogProduct(
    title: 'Neo Badminton Pods',
    category: 'Badminton',
    city: 'Jakarta',
    price: 250000,
    rating: 4.4,
    imageUrl:
        'https://images.unsplash.com/photo-1459865264687-595d652de67e?auto=format&fit=crop&w=600&q=80',
  ),
];
