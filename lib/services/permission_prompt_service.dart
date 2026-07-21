import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';
import 'notification_service.dart';

class PermissionPromptService {
  static const _cameraDisclosureKey = 'camera_permission_disclosure_seen';
  static const _photosDisclosureKey = 'photos_permission_disclosure_seen';

  static Future<String?> requestNotificationToken(BuildContext context) async {
    if (await NotificationService.isAuthorized()) {
      return NotificationService.token();
    }
    if (!context.mounted) return null;

    final accepted = await _showDisclosure(
      context,
      icon: Icons.notifications_active_outlined,
      title: 'Stay ready for your day',
      body:
          'StyleStack uses notifications to send your morning outfit, '
          'event reminders, wardrobe processing updates, and occasional '
          'StyleStack announcements. Notifications are optional, can be turned '
          'off anytime, and are never sold or used for third-party ads.',
      actionLabel: 'Continue',
    );
    if (!accepted || !context.mounted) return null;

    final token = await NotificationService.requestToken();
    if (token == null && context.mounted) {
      await _showSettingsRecovery(
        context,
        title: 'Notifications are off',
        body:
            'Android or iOS may stop showing the permission prompt after it '
            'has been declined. Open StyleStack settings to enable '
            'notifications, or continue without them.',
      );
    }
    return token;
  }

  static Future<bool> requestLocation(BuildContext context) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!context.mounted) return false;
      final open = await _showChoice(
        context,
        icon: Icons.location_off_outlined,
        title: 'Location Services are off',
        body:
            'StyleStack only needs your current city to keep outfit comfort '
            'appropriate for local weather. You can still use all core '
            'wardrobe and styling features without location.',
        actionLabel: 'Open location settings',
      );
      if (open) await Geolocator.openLocationSettings();
      return false;
    }

    final current = await LocationService.permission();
    if (LocationService.isGranted(current)) return true;
    if (!context.mounted) return false;

    final accepted = await _showDisclosure(
      context,
      icon: Icons.location_on_outlined,
      title: 'Use your city for outfit comfort',
      body:
          'StyleStack uses your location once to detect and save your city. '
          'Your coordinates are not stored, location is not tracked in the '
          'background, and styling still works if you choose Not now.',
      actionLabel: 'Continue',
    );
    if (!accepted || !context.mounted) return false;

    if (current == LocationPermission.deniedForever) {
      return _showSettingsRecovery(
        context,
        title: 'Location permission is off',
        body:
            'The system will not show the location prompt again. Open '
            'StyleStack settings to allow location, or continue without it.',
      );
    }

    final permission = await LocationService.requestPermission();
    if (LocationService.isGranted(permission)) return true;
    if (context.mounted) {
      await _showSettingsRecovery(
        context,
        title: 'Location was not enabled',
        body:
            'You can keep using StyleStack without location. If you change '
            'your mind, open Settings or tap Detect again later.',
      );
    }
    return false;
  }

  static Future<bool> explainCamera(BuildContext context) => _confirmOnce(
    context,
    preferenceKey: _cameraDisclosureKey,
    icon: Icons.camera_alt_outlined,
    title: 'Photograph a wardrobe item',
    body:
        'StyleStack uses the camera only when you choose Take a photo. The '
        'photo is uploaded to your private wardrobe so it can be prepared and '
        'tagged. StyleStack does not record video or use the camera in the '
        'background.',
  );

  static Future<bool> explainPhotos(BuildContext context) => _confirmOnce(
    context,
    preferenceKey: _photosDisclosureKey,
    icon: Icons.photo_library_outlined,
    title: 'Choose wardrobe photos',
    body:
        'StyleStack only receives the photos you select. They are uploaded to '
        'your private wardrobe for background preparation and AI tagging; the '
        'rest of your photo library is not scanned.',
  );

  static Future<void> showMediaSettingsRecovery(
    BuildContext context, {
    required String mediaName,
  }) => _showSettingsRecovery(
    context,
    title: '$mediaName access is off',
    body:
        'The system may no longer display its permission prompt. Open '
        'StyleStack settings to enable access, or choose another way to add '
        'your items.',
  );

  static Future<bool> _confirmOnce(
    BuildContext context, {
    required String preferenceKey,
    required IconData icon,
    required String title,
    required String body,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(preferenceKey) == true) return true;
    if (!context.mounted) return false;
    final accepted = await _showDisclosure(
      context,
      icon: icon,
      title: title,
      body: body,
      actionLabel: 'Continue',
    );
    if (accepted) await preferences.setBool(preferenceKey, true);
    return accepted;
  }

  static Future<bool> _showDisclosure(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required String actionLabel,
  }) => _showChoice(
    context,
    icon: icon,
    title: title,
    body: body,
    actionLabel: actionLabel,
  );

  static Future<bool> _showSettingsRecovery(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final open = await _showChoice(
      context,
      icon: Icons.settings_outlined,
      title: title,
      body: body,
      actionLabel: 'Open settings',
    );
    if (open) await Geolocator.openAppSettings();
    return false;
  }

  static Future<bool> _showChoice(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required String actionLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(icon),
            title: Text(title),
            content: Text(body, style: const TextStyle(height: 1.45)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }
}
