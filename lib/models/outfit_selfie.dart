import 'wardrobe_item.dart';

class OutfitSelfieDetection {
  OutfitSelfieDetection({
    required this.id,
    required this.detectedName,
    required this.category,
    required this.color,
    required this.description,
    required this.visualTags,
    required this.confidence,
    required this.selected,
    this.wardrobeItemId,
    this.wardrobeItem,
  });

  final String id;
  final String detectedName;
  final String? category;
  final String? color;
  final String? description;
  final List<String> visualTags;
  final double confidence;
  bool selected;
  String? wardrobeItemId;
  WardrobeItem? wardrobeItem;

  bool get matched => wardrobeItemId != null;

  factory OutfitSelfieDetection.fromJson(Map<String, dynamic> json) {
    final wardrobeJson = json['wardrobe_item'];
    return OutfitSelfieDetection(
      id: json['id'] as String,
      detectedName: json['detected_name'] as String,
      category: json['detected_category'] as String?,
      color: json['detected_color'] as String?,
      description: json['detected_description'] as String?,
      visualTags: (json['visual_tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      selected: json['selected'] as bool? ?? true,
      wardrobeItemId: json['wardrobe_item_id'] as String?,
      wardrobeItem: wardrobeJson is Map<String, dynamic>
          ? WardrobeItem.fromJson(wardrobeJson)
          : null,
    );
  }
}

class OutfitSelfieAnalysis {
  const OutfitSelfieAnalysis({
    required this.qualityAcceptable,
    required this.qualityScore,
    required this.qualityFeedback,
    required this.detections,
    this.selfieId,
    this.imageUrl,
  });

  final bool qualityAcceptable;
  final double qualityScore;
  final String qualityFeedback;
  final String? selfieId;
  final String? imageUrl;
  final List<OutfitSelfieDetection> detections;

  factory OutfitSelfieAnalysis.fromJson(Map<String, dynamic> json) =>
      OutfitSelfieAnalysis(
        qualityAcceptable: json['quality_acceptable'] as bool? ?? false,
        qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 0,
        qualityFeedback:
            json['quality_feedback'] as String? ?? 'Please retake the photo.',
        selfieId: json['selfie_id'] as String?,
        imageUrl: json['image_url'] as String?,
        detections: (json['detections'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  OutfitSelfieDetection.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class OutfitSelfieConfirmationResult {
  const OutfitSelfieConfirmationResult({
    required this.loggedItems,
    required this.unmatchedItems,
  });

  final int loggedItems;
  final List<String> unmatchedItems;

  factory OutfitSelfieConfirmationResult.fromJson(Map<String, dynamic> json) =>
      OutfitSelfieConfirmationResult(
        loggedItems: json['logged_items'] as int? ?? 0,
        unmatchedItems: (json['unmatched_items'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
      );
}

class OutfitSelfieHistoryEntry {
  const OutfitSelfieHistoryEntry({
    required this.id,
    required this.capturedAt,
    required this.items,
    this.imageUrl,
  });

  final String id;
  final String? imageUrl;
  final DateTime capturedAt;
  final List<WardrobeItem> items;

  factory OutfitSelfieHistoryEntry.fromJson(Map<String, dynamic> json) =>
      OutfitSelfieHistoryEntry(
        id: json['id'] as String,
        imageUrl: json['image_url'] as String?,
        capturedAt:
            DateTime.tryParse(json['captured_at'] as String? ?? '') ??
            DateTime.now(),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => WardrobeItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
