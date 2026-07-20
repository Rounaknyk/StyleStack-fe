import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
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
