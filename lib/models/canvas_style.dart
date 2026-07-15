class CanvasStyleItem {
  const CanvasStyleItem({
    required this.itemId,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
  });

  final String itemId;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
  };

  factory CanvasStyleItem.fromJson(Map<String, dynamic> json) =>
      CanvasStyleItem(
        itemId: json['item_id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num).toDouble(),
        rotation: (json['rotation'] as num).toDouble(),
      );
}

class CanvasStyle {
  const CanvasStyle({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    this.previewUrl,
  });

  final String id;
  final String name;
  final List<CanvasStyleItem> items;
  final DateTime createdAt;
  final String? previewUrl;

  factory CanvasStyle.fromJson(Map<String, dynamic> json) => CanvasStyle(
    id: json['id'] as String,
    name: json['name'] as String,
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CanvasStyleItem.fromJson)
        .toList(),
    previewUrl: json['preview_url'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
