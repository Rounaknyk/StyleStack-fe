import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationNavigationRequest {
  const NotificationNavigationRequest({
    required this.destination,
    this.outfitId,
    this.title,
  });

  final String destination;
  final String? outfitId;
  final String? title;
}

class NotificationService {
  static final ValueNotifier<NotificationNavigationRequest?> navigation =
      ValueNotifier(null);
  static bool _interactionHandlingInitialized = false;

  static Future<void> initializeInteractionHandling() async {
    if (_interactionHandlingInitialized) return;
    _interactionHandlingInitialized = true;

    FirebaseMessaging.onMessageOpenedApp.listen(_handleInteraction);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleInteraction(initialMessage);
  }

  static void _handleInteraction(RemoteMessage message) {
    final data = message.data;
    var destination = data['destination']?.trim();
    if (destination == null || destination.isEmpty) {
      final deepLink = data['deep_link']?.trim() ?? '';
      if (deepLink.startsWith('stylestack://')) {
        destination = deepLink
            .substring('stylestack://'.length)
            .split('/')
            .first;
      }
    }
    destination ??= data['type'] == 'event_outfit' ? 'outfit' : 'today';

    navigation.value = NotificationNavigationRequest(
      destination: destination,
      outfitId: data['outfit_id'],
      title: message.notification?.title,
    );
  }

  static NotificationNavigationRequest? takeNavigationRequest() {
    final request = navigation.value;
    navigation.value = null;
    return request;
  }

  static Future<bool> isAuthorized() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<String?> token() async {
    final messaging = FirebaseMessaging.instance;
    if (Platform.isIOS) {
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return messaging.getToken();
  }

  static Future<String?> requestToken() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
    return token();
  }
}
