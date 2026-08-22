import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initializeInteractionHandling() async {
    if (_interactionHandlingInitialized) return;
    _interactionHandlingInitialized = true;

    // Initialize Timezone for local scheduling
    tz.initializeTimeZones();

    // Initialize Local Notifications
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && details.payload!.startsWith('outfit_')) {
          final outfitId = details.payload!.replaceFirst('outfit_', '');
          navigation.value = NotificationNavigationRequest(
            destination: 'outfit',
            outfitId: outfitId,
          );
        }
      },
    );

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'This channel is used for important notifications.',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data['outfit_id'] != null
              ? 'outfit_${message.data['outfit_id']}'
              : null,
        );
      }
    });

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

  static Future<void> scheduleOutfitReminder({
    required String outfitId,
    required String eventName,
    required DateTime eventDate,
  }) async {
    // Schedule exactly 1 day before at 9:00 AM (or 24 hours before)
    // Actually, let's just do 24 hours before the event date for simplicity
    final scheduleTime = eventDate.subtract(const Duration(days: 1));
    if (scheduleTime.isBefore(DateTime.now())) {
      // If the event is in less than 24 hours, don't schedule
      return;
    }

    final id = outfitId.hashCode; // Unique integer ID

    const androidDetails = AndroidNotificationDetails(
      'outfit_reminders',
      'Outfit Reminders',
      channelDescription: 'Reminders for your planned outfits',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.zonedSchedule(
      id: id,
      title: 'Your look is ready!',
      body: 'Tap to review your planned outfit for $eventName tomorrow.',
      scheduledDate: tz.TZDateTime.from(scheduleTime, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'outfit_$outfitId',
    );
  }
}
