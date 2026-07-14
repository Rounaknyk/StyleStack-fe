class StyleCalendarEvent {
  const StyleCalendarEvent({
    required this.id,
    required this.source,
    required this.title,
    required this.startAt,
    required this.allDay,
    required this.occasion,
    this.description,
    this.location,
    this.endAt,
    this.outfitId,
  });

  final String id;
  final String source;
  final String title;
  final String? description;
  final String? location;
  final DateTime startAt;
  final DateTime? endAt;
  final bool allDay;
  final String occasion;
  final String? outfitId;

  factory StyleCalendarEvent.fromJson(Map<String, dynamic> json) =>
      StyleCalendarEvent(
        id: json['id'] as String,
        source: json['source'] as String? ?? 'manual',
        title: json['title'] as String,
        description: json['description'] as String?,
        location: json['location'] as String?,
        startAt: DateTime.parse(json['start_at'] as String).toLocal(),
        endAt: json['end_at'] == null
            ? null
            : DateTime.parse(json['end_at'] as String).toLocal(),
        allDay: json['all_day'] as bool? ?? false,
        occasion: json['occasion'] as String? ?? 'event',
        outfitId: json['outfit_id'] as String?,
      );
}

class StyleNotification {
  const StyleNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory StyleNotification.fromJson(Map<String, dynamic> json) =>
      StyleNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String).toLocal(),
      );
}
