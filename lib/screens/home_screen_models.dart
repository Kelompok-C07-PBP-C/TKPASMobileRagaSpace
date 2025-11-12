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
        id: map['id'] is int
            ? map['id'] as int
            : int.tryParse(map['id']?.toString() ?? ''),
      );

  String get storageKey =>
      '${name.toLowerCase()}|${location.toLowerCase()}|$category';
}

class _CatalogProduct {
  const _CatalogProduct({
    required this.title,
    required this.category,
    required this.city,
    required this.description,
    required this.price,
    required this.rating,
    required this.imageUrl,
    this.id,
  });

  final int? id;
  final String title;
  final String category;
  final String city;
  final String description;
  final int price;
  final double rating;
  final String imageUrl;
}
