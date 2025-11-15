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

  factory _VenueCardData.fromWishlistPayload(Map<String, dynamic> payload) {
    final venue = (payload['venue'] as Map<String, dynamic>?) ?? payload;
    final rawImage = (venue['image_absolute_url'] ?? venue['image_url'] ?? '').toString();
    double parseRating(dynamic value) {
      if (value is num) return value.toDouble();
      if (value == null) return 0;
      return double.tryParse(value.toString()) ?? 0;
    }
    return _VenueCardData(
      category: (venue['type'] ?? venue['category'] ?? '').toString(),
      name: (venue['title'] ?? venue['name'] ?? '').toString(),
      location: (venue['location'] ?? '').toString(),
      description: (venue['description'] ?? '').toString(),
      price: (venue['price'] as num?)?.toInt() ?? 0,
      rating: parseRating(
        venue['average_rating'] ?? venue['avg_rating'] ?? venue['rating'],
      ),
      imageUrl: _resolveMediaUrlGlobal(rawImage),
      id: venue['id'] is int ? venue['id'] as int : int.tryParse('${venue['id']}'),
    );
  }

  String get storageKey {
    if (id != null) return 'id:$id';
    final normalizedName = name.toLowerCase();
    final normalizedLocation = location.toLowerCase();
    return '$normalizedName|$normalizedLocation|$category';
  }
}

class _VenueReview {
  const _VenueReview({
    required this.id,
    required this.venueId,
    required this.author,
    required this.comment,
    required this.rating,
    required this.date,
    required this.isMine,
  });

  final int id;
  final int? venueId;
  final String author;
  final String comment;
  final int rating;
  final DateTime date;
  final bool isMine;

  factory _VenueReview.fromMap(
    Map<String, dynamic> map, {
    String? currentUsername,
    int? currentUserId,
  }) {
    final author = (map['author'] ?? '').toString();
    final username = currentUsername?.toLowerCase();
    final normalizedAuthor = author.toLowerCase();
    final isMineByName = username != null && username.isNotEmpty && normalizedAuthor == username;
    final authorId =
        map['author_id'] is int ? map['author_id'] as int : int.tryParse('${map['author_id']}');
    final isMine = (authorId != null && currentUserId != null && authorId == currentUserId) || isMineByName;
    return _VenueReview(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}') ?? 0,
      venueId: map['venue_id'] is int
          ? map['venue_id'] as int
          : int.tryParse('${map['venue_id']}'),
      author: author.isNotEmpty ? author : 'Anonim',
      comment: (map['comment'] ?? '').toString(),
      rating: int.tryParse(map['rating']?.toString() ?? '') ?? 0,
      date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
      isMine: isMine || (map['is_mine'] == true),
    );
  }

  _VenueReview copyWith({
    String? comment,
    int? rating,
  }) =>
      _VenueReview(
        id: id,
        venueId: venueId,
        author: author,
        comment: comment ?? this.comment,
        rating: rating ?? this.rating,
        date: date,
        isMine: isMine,
      );
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
