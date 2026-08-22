import 'package:flutter/foundation.dart';

/// AdMob identifiers for StyleStack's two rewarded placements.
///
/// Google's sample IDs are intentionally the defaults so development builds
/// can be exercised safely. Production builds must provide StyleStack-owned
/// IDs with the corresponding `--dart-define` values.
class AdMobConfig {
  const AdMobConfig._();

  static const _androidTestRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosTestRewarded = 'ca-app-pub-3940256099942544/1712485313';

  static String rewardedDailyOutfitId() => _forPlatform(
    android: const String.fromEnvironment(
      'ADMOB_REWARDED_DAILY_ANDROID',
      defaultValue: kDebugMode ? _androidTestRewarded : 'ca-app-pub-1786816052212177/8552169163',
    ),
    ios: const String.fromEnvironment(
      'ADMOB_REWARDED_DAILY_IOS',
      defaultValue: _iosTestRewarded, // TODO: Replace with iOS Prod ID
    ),
  );

  static String rewardedCalendarId() => _forPlatform(
    android: const String.fromEnvironment(
      'ADMOB_REWARDED_CALENDAR_ANDROID',
      defaultValue: kDebugMode ? _androidTestRewarded : 'ca-app-pub-1786816052212177/8552169163',
    ),
    ios: const String.fromEnvironment(
      'ADMOB_REWARDED_CALENDAR_IOS',
      defaultValue: _iosTestRewarded, // TODO: Replace with iOS Prod ID
    ),
  );

  static String _forPlatform({required String android, required String ios}) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => '',
    };
  }
}
