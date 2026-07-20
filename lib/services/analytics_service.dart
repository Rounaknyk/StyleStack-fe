import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Privacy-safe product analytics for StyleStack.
///
/// Never pass wardrobe names, photos, chat text, email content, phone numbers,
/// event titles, or other user-provided values to this service.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;

  FirebaseAnalytics? get _availableAnalytics {
    if (Firebase.apps.isEmpty) return null;
    return _analytics ??= FirebaseAnalytics.instance;
  }

  FirebaseAnalyticsObserver createObserver() =>
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  Future<void> identifyUser(String? uid) {
    final analytics = _availableAnalytics;
    if (analytics == null) return Future.value();
    return _safely(() => analytics.setUserId(id: uid));
  }

  Future<void> screen(String name) {
    final analytics = _availableAnalytics;
    if (analytics == null) return Future.value();
    return _safely(
      () => analytics.logScreenView(screenName: name, screenClass: name),
    );
  }

  Future<void> event(String name, {Map<String, Object>? parameters}) {
    final analytics = _availableAnalytics;
    if (analytics == null) return Future.value();
    return _safely(
      () => analytics.logEvent(name: name, parameters: parameters),
    );
  }

  Future<void> authSucceeded({required String method, required bool signUp}) {
    final analytics = _availableAnalytics;
    if (analytics == null) return Future.value();
    if (signUp) {
      return _safely(() => analytics.logSignUp(signUpMethod: method));
    }
    return _safely(() => analytics.logLogin(loginMethod: method));
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Analytics is observability only and must never break a user journey.
    }
  }
}
