class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    this.brand,
    this.color,
    this.description,
    this.formality,
    this.imageUrl,
    this.thumbnailUrl,
    this.isFavorite = false,
    this.seasons = const [],
    this.tags = const [],
    this.aiCategory,
    this.aiColor,
    this.aiSeason,
    this.aiFormality,
    this.aiDescription,
    this.aiTagStatus = 'pending',
    this.wearCount = 0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final String? brand;
  final String? color;
  final String? description;
  final String? formality;
  final String? imageUrl;
  final String? thumbnailUrl;
  final bool isFavorite;
  final List<String> seasons;
  final List<String> tags;
  final String? aiCategory;
  final String? aiColor;
  final String? aiSeason;
  final String? aiFormality;
  final String? aiDescription;
  final String aiTagStatus;
  final int wearCount;
  final DateTime createdAt;

  String get displayCategory =>
      (category.isEmpty || category.toLowerCase() == 'other') &&
          aiCategory != null
      ? aiCategory!
      : category;
  String? get displayColor => color ?? aiColor;
  String? get displayDescription => description ?? aiDescription;
  String? get displayFormality => formality ?? aiFormality;
  String? get displaySeason => seasons.isNotEmpty ? seasons.first : aiSeason;
  String? get gridImageUrl => thumbnailUrl ?? imageUrl;

  factory WardrobeItem.fromJson(Map<String, dynamic> json) => WardrobeItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    brand: json['brand'] as String?,
    color: json['color'] as String?,
    description: json['description'] as String?,
    formality: json['formality'] as String?,
    imageUrl: json['image_url'] as String?,
    thumbnailUrl: json['thumbnail_url'] as String?,
    isFavorite: json['is_favorite'] as bool? ?? false,
    seasons: (json['season'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    tags: (json['tags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    aiCategory: json['ai_category'] as String?,
    aiColor: json['ai_color'] as String?,
    aiSeason: json['ai_season'] as String?,
    aiFormality: json['ai_formality'] as String?,
    aiDescription: json['ai_description'] as String?,
    aiTagStatus: json['ai_tag_status'] as String? ?? 'pending',
    wearCount: json['wear_count'] as int? ?? 0,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
