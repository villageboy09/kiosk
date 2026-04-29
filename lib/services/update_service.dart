import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  /// Checks for an update and starts a flexible update flow if available.
  static Future<void> checkForUpdates() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // Start a flexible update (downloads in the background)
        final result = await InAppUpdate.startFlexibleUpdate();

        if (result == AppUpdateResult.success) {
          // Once the update is downloaded, complete it (installs and restarts)
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      // In-app updates might fail in debug mode or if not downloaded from the Play Store.
      // We catch the error silently or log it so it doesn't crash the app.
      debugPrint("In-app update check failed: $e");
    }
  }
}
