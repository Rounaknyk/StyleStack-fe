import 'wardrobe_item.dart';

class Outfit {
  const Outfit({
    required this.id,
    required this.occasion,
    required this.reasoning,
    required this.weather,
    required this.items,
    this.inspirationImages = const [],
  });
  final String id;
  final String occasion;
  final String reasoning;
  final Map<String, dynamic> weather;
  final List<WardrobeItem> items;
  final List<Map<String, dynamic>> inspirationImages;

  factory Outfit.fromJson(Map<String, dynamic> json) => Outfit(
    id: json['id'] as String,
    occasion: json['occasion'] as String,
    reasoning: json['reasoning'] as String,
    weather: Map<String, dynamic>.from(json['weather'] as Map),
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((item) => WardrobeItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    inspirationImages:
        (json['inspiration_images'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
  );
}

class UserPreferences {
  const UserPreferences({
    this.city,
    this.timezone = 'Asia/Kolkata',
    this.notificationEnabled = false,
    this.notificationTime = '08:00:00',
  });
  final String? city;
  final String timezone;
  final bool notificationEnabled;
  final String notificationTime;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        city: json['city'] as String?,
        timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
        notificationEnabled: json['notification_enabled'] as bool? ?? false,
        notificationTime: json['notification_time'] as String? ?? '08:00:00',
      );
}
