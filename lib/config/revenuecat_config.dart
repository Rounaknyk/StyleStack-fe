import 'package:flutter/foundation.dart';

class RevenueCatConfig {
  const RevenueCatConfig._();

  static const entitlement = 'premium';

  /// Keep this false until products and the default RevenueCat offering are
  /// configured in both stores. Premium purchases and ad removal still work
  /// while the mandatory paywall is disabled.
  static const subscriptionRequired = bool.fromEnvironment(
    'SUBSCRIPTION_REQUIRED',
    defaultValue: false,
  );

  static String apiKey() => switch (defaultTargetPlatform) {
    TargetPlatform.android => const String.fromEnvironment(
      'REVENUECAT_ANDROID_API_KEY',
    ),
    TargetPlatform.iOS => const String.fromEnvironment(
      'REVENUECAT_IOS_API_KEY',
    ),
    _ => '',
  };
}
