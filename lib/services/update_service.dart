import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  Future<void> checkForUpdates(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (!context.mounted) {
        return;
      }

      final shouldUpdate = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Update available'),
                content: const Text(
                  'A newer version of ME is ready. Update now for the best experience.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Update now'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!shouldUpdate) {
        return;
      }

      if (updateInfo.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (updateInfo.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (_) {
      // In-app updates only work on supported Android/Play Store installs.
    }
  }
}
