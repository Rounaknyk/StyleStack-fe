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
      defaultValue: kDebugMode ? _iosTestRewarded : 'ca-app-pub-1786816052212177/7355044082',
    ),
  );

  static String rewardedCalendarId() => _forPlatform(
    android: const String.fromEnvironment(
      'ADMOB_REWARDED_CALENDAR_ANDROID',
      defaultValue: kDebugMode ? _androidTestRewarded : 'ca-app-pub-1786816052212177/8552169163',
    ),
    ios: const String.fromEnvironment(
      'ADMOB_REWARDED_CALENDAR_IOS',
      defaultValue: kDebugMode ? _iosTestRewarded : 'ca-app-pub-1786816052212177/7355044082',
    ),
  );

  static const _androidTestInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _iosTestInterstitial = 'ca-app-pub-3940256099942544/4411468910';

  static String interstitialId() => _forPlatform(
    android: const String.fromEnvironment(
      'ADMOB_INTERSTITIAL_ANDROID',
      defaultValue: kDebugMode ? _androidTestInterstitial : 'ca-app-pub-1786816052212177/1412626302',
    ),
    ios: const String.fromEnvironment(
      'ADMOB_INTERSTITIAL_IOS',
      defaultValue: kDebugMode ? _iosTestInterstitial : 'ca-app-pub-1786816052212177/7978139855',
    ),
  );

  static String interstitialExportStyleId() => _forPlatform(
    android: const String.fromEnvironment(
      'ADMOB_INTERSTITIAL_EXPORT_ANDROID',
      defaultValue: kDebugMode ? _androidTestInterstitial : 'ca-app-pub-1786816052212177/3038827883',
    ),
    ios: const String.fromEnvironment(
      'ADMOB_INTERSTITIAL_EXPORT_IOS',
      defaultValue: kDebugMode ? _iosTestInterstitial : 'ca-app-pub-1786816052212177/5210619090',
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
