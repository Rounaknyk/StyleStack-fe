import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import 'analytics_service.dart';

/// Uses Google Play's flexible update flow for release builds installed from
/// Play. It intentionally does nothing for debug builds, sideloaded APKs, and
/// iOS, where this Android API is unavailable.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  bool _checked = false;

  Future<void> checkForFlexibleUpdate({
    required Future<bool> Function() confirmRestart,
  }) async {
    if (_checked || !kReleaseMode || !Platform.isAndroid) return;
    _checked = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      final updateDownloaded = info.installStatus == InstallStatus.downloaded;
      if (!updateDownloaded &&
          info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      await AnalyticsService.instance.event(
        'app_update_available',
        parameters: {
          if (info.availableVersionCode != null)
            'version_code': info.availableVersionCode!,
        },
      );

      if (!updateDownloaded) {
        if (!info.flexibleUpdateAllowed) return;
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result != AppUpdateResult.success) {
          await AnalyticsService.instance.event(
            'app_update_download_incomplete',
            parameters: {'result': result.name},
          );
          return;
        }
      }

      await AnalyticsService.instance.event('app_update_downloaded');
      final shouldRestart = await confirmRestart();
      if (!shouldRestart) {
        await AnalyticsService.instance.event('app_update_restart_deferred');
        return;
      }

      // Google Play closes and restarts the process while installing. Only do
      // this after explicit confirmation so the expected restart never looks
      // like an application crash.
      await InAppUpdate.completeFlexibleUpdate();
      await AnalyticsService.instance.event('app_update_installed');
    } catch (error) {
      // Play's API is unavailable for locally installed/sideloaded builds.
      // Update checks must never interrupt normal app startup.
      debugPrint('Play in-app update check skipped: $error');
    }
  }
}
