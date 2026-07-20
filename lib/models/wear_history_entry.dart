import 'wardrobe_item.dart';

class WearHistoryEntry {
  const WearHistoryEntry({
    required this.id,
    required this.wornAt,
    required this.items,
    this.notes,
  });

  final String id;
  final DateTime wornAt;
  final String? notes;
  final List<WardrobeItem> items;

  factory WearHistoryEntry.fromJson(Map<String, dynamic> json) =>
      WearHistoryEntry(
        id: json['id'] as String,
        wornAt: DateTime.parse(json['worn_at'] as String),
        notes: json['notes'] as String?,
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => WardrobeItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
