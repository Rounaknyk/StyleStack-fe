class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    this.brand,
    this.color,
    this.imageUrl,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String category;
  final String? brand;
  final String? color;
  final String? imageUrl;
  final bool isFavorite;

  factory WardrobeItem.fromJson(Map<String, dynamic> json) => WardrobeItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        brand: json['brand'] as String?,
        color: json['color'] as String?,
        imageUrl: json['image_url'] as String?,
        isFavorite: json['is_favorite'] as bool? ?? false,
      );
}
