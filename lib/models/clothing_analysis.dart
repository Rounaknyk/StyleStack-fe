class ClothingAnalysis {
  const ClothingAnalysis({
    required this.category,
    required this.color,
    required this.season,
    required this.formality,
    required this.description,
    this.tags = const [],
  });

  final String category;
  final String color;
  final String season;
  final String formality;
  final String description;
  final List<String> tags;

  factory ClothingAnalysis.fromJson(Map<String, dynamic> json) =>
      ClothingAnalysis(
        category: json['category'] as String,
        color: json['color'] as String,
        season: json['season'] as String,
        formality: json['formality'] as String,
        description: json['description'] as String,
        tags: (json['tags'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .take(5)
            .toList(),
      );
}

class ClothingDetection {
  const ClothingDetection({required this.items});
  final List<ClothingAnalysis> items;

  factory ClothingDetection.fromJson(Map<String, dynamic> json) =>
      ClothingDetection(
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ClothingAnalysis.fromJson)
            .toList(),
      );
}
