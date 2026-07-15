class OnboardingProfile {
  const OnboardingProfile({
    this.completed = false,
    this.displayName,
    this.gender,
    this.dateOfBirth,
    this.bodyType,
    this.heightCm,
    this.stylePreferences = const [],
    this.shoppingFrequency,
    this.styleGoals = const [],
  });

  final bool completed;
  final String? displayName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? bodyType;
  final int? heightCm;
  final List<String> stylePreferences;
  final String? shoppingFrequency;
  final List<String> styleGoals;

  factory OnboardingProfile.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date_of_birth'] as String?;
    return OnboardingProfile(
      completed: json['onboarding_completed'] as bool? ?? false,
      displayName: json['display_name'] as String?,
      gender: json['gender_identity'] as String?,
      dateOfBirth: rawDate == null ? null : DateTime.tryParse(rawDate),
      bodyType: json['body_type'] as String?,
      heightCm: (json['height_cm'] as num?)?.round(),
      stylePreferences: _strings(json['style_preferences']),
      shoppingFrequency: json['shopping_frequency'] as String?,
      styleGoals: _strings(json['onboarding_goals']),
    );
  }

  Map<String, dynamic> toJson() => {
    'display_name': displayName?.trim(),
    'gender_identity': gender,
    'date_of_birth': dateOfBirth == null ? null : _dateOnly(dateOfBirth!),
    'body_type': bodyType,
    'height_cm': heightCm,
    'style_preferences': stylePreferences,
    'shopping_frequency': shoppingFrequency,
    'onboarding_goals': styleGoals,
  };

  static List<String> _strings(dynamic value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const [];

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
