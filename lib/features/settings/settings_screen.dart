import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/theme_service.dart';
import '../../shared/widgets/glass_panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, settings, _) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensory feedback',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sound effects'),
                        subtitle: const Text('Tap, submit, and reward audio cues'),
                        value: settings.soundEnabled,
                        onChanged: (value) async {
                          await settings.setSoundEnabled(value);
                          if (value) {
                            await SoundService.instance.playTap();
                          }
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Haptics'),
                        subtitle: const Text('Subtle physical feedback while you interact'),
                        value: settings.hapticsEnabled,
                        onChanged: (value) async {
                          await settings.setHapticsEnabled(value);
                          if (value) {
                            await HapticsService.instance.lightImpact();
                          }
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Background music'),
                        subtitle: const Text('Play a calm loop while you use the app'),
                        value: settings.backgroundMusicEnabled,
                        onChanged: (value) async {
                          await settings.setBackgroundMusicEnabled(value);
                          await AudioService.instance.updatePlaybackPreference();
                          if (value) {
                            await HapticsService.instance.lightImpact();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mood reminders',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set a reminder rhythm that feels supportive, not noisy.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mood reminders'),
                        subtitle: const Text(
                          'Send a gentle reminder to log your mood',
                        ),
                        value: settings.notificationsEnabled,
                        onChanged: (value) async {
                          if (value) {
                            final granted = await NotificationService
                                .instance
                                .requestPermissionIfNeeded();
                            if (!granted) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notification permission is needed to enable reminders.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                          }

                          await settings.setNotificationsEnabled(value);
                          await NotificationService.instance.syncWithPreferences();

                          if (value) {
                            await HapticsService.instance.lightImpact();
                          }
                        },
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: !settings.notificationsEnabled
                            ? const SizedBox.shrink()
                            : Column(
                                key: const ValueKey('notification-options'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    'Reminder frequency',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: NotificationReminderFrequency.values
                                        .map((frequency) {
                                      final selected =
                                          settings.notificationFrequency ==
                                              frequency;
                                      return ChoiceChip(
                                        selected: selected,
                                        label: Text(
                                          _notificationFrequencyLabel(frequency),
                                        ),
                                        onSelected: (_) async {
                                          await settings.setNotificationFrequency(
                                            frequency,
                                          );
                                          await NotificationService
                                              .instance
                                              .syncWithPreferences();
                                          await HapticsService.instance
                                              .selectionClick();
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _notificationFrequencyDescription(
                                      settings.notificationFrequency,
                                    ),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick the atmosphere that feels best for daily check-ins.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: AppThemePreset.values.map((preset) {
                          final palette = AppTheme.paletteOf(preset);
                          final selected = settings.currentTheme == preset;

                          return ChoiceChip(
                            selected: selected,
                            label: Text(AppTheme.labelFor(preset)),
                            avatar: CircleAvatar(
                              backgroundColor: palette.seed,
                              child: Icon(
                                Icons.palette_rounded,
                                size: 16,
                                color: palette.accent,
                              ),
                            ),
                            onSelected: (_) async {
                              await settings.setTheme(preset);
                              await HapticsService.instance.lightImpact();
                              await SoundService.instance.playTap();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _notificationFrequencyLabel(NotificationReminderFrequency frequency) {
  switch (frequency) {
    case NotificationReminderFrequency.hourly:
      return 'Every hour';
    case NotificationReminderFrequency.threeTimesDaily:
      return '3 times a day';
    case NotificationReminderFrequency.fiveTimesDaily:
      return '5 times a day';
  }
}

String _notificationFrequencyDescription(
  NotificationReminderFrequency frequency,
) {
  switch (frequency) {
    case NotificationReminderFrequency.hourly:
      return 'A steady hourly nudge for people who like frequent prompts.';
    case NotificationReminderFrequency.threeTimesDaily:
      return 'A balanced reminder pace, roughly every 8 hours.';
    case NotificationReminderFrequency.fiveTimesDaily:
      return 'A more active cadence, roughly every 4 hours 48 minutes.';
  }
}
