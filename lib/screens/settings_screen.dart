import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../core/services/audio_service.dart';
import '../core/services/haptics_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/sound_service.dart';
import '../core/services/theme_service.dart';
import '../data/database_helper.dart';
import '../db/app_database.dart';
import '../features/mind/mood_catalog.dart';
import '../features/mind/providers/mind_me_provider.dart';
import '../services/gemma_service.dart';
import '../shared/widgets/glass_panel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _modelDownloaded = false;
  bool _isDownloadingModel = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadModelState();
  }

  Future<void> _loadModelState() async {
    final downloaded = await GemmaService.instance.isModelDownloaded();
    if (!mounted) {
      return;
    }
    setState(() => _modelDownloaded = downloaded);
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloadingModel = true;
      _downloadProgress = 0;
    });

    await GemmaService.instance.downloadModel(
      onProgress: (value) {
        if (!mounted) {
          return;
        }
        setState(() => _downloadProgress = value);
      },
      onComplete: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _isDownloadingModel = false;
          _modelDownloaded = true;
          _downloadProgress = 1;
        });
      },
      onError: (message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isDownloadingModel = false;
          _downloadProgress = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Model download failed: $message')),
        );
      },
    );
  }

  Future<void> _exportMoodHistory() async {
    final entries = await DatabaseHelper.instance.getAllEntries();
    final buffer = StringBuffer('date,time,mood,intensity,note\n');

    for (final entry in entries) {
      final timestamp = DateTime.tryParse(entry['timestamp'] as String? ?? '');
      final moodId = entry['mood_id'] as String? ?? 'calm';
      final mood = moodOptionById(moodId);
      final label = (entry['custom_label'] as String?)?.trim().isNotEmpty == true
          ? entry['custom_label'] as String
          : mood.label;
      final date = entry['date'] as String? ?? '';
      final time = timestamp == null
          ? ''
          : '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      final note = ((entry['note'] as String?) ?? '').replaceAll('"', '""');

      buffer.writeln('$date,$time,"$label",${entry['intensity'] ?? 0},"$note"');
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/me_mood_history.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'ME mood history export',
    );
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete all data?'),
            content: const Text(
              'This removes saved journals, AI insights, XP progress, reminders, and preferences.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await DatabaseHelper.instance.resetDatabase();
    await AppDatabase.instance.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await GemmaService.instance.reset();
    await ThemeService.instance.reloadPreferences();
    await AudioService.instance.updatePlaybackPreference();
    await NotificationService.instance.cancelAllScheduled();
    if (mounted) {
      await context.read<MindMeProvider>().refresh();
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All local data has been cleared.')),
    );
    setState(() {
      _modelDownloaded = false;
      _downloadProgress = 0;
      _isDownloadingModel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, settings, _) {
        final theme = Theme.of(context);
        final palette = AppTheme.paletteOf(settings.currentTheme);

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.backgroundTop,
                  palette.backgroundBottom,
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
                      Text('AI insights', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable AI insights'),
                        value: settings.aiInsightsEnabled,
                        onChanged: (value) async {
                          await settings.setAiInsightsEnabled(value);
                        },
                      ),
                      Opacity(
                        opacity: settings.aiInsightsEnabled ? 1 : 0.45,
                        child: IgnorePointer(
                          ignoring: !settings.aiInsightsEnabled,
                          child: RadioGroup<InsightMode>(
                            groupValue: settings.insightMode,
                            onChanged: (value) async {
                              if (value != null) {
                                await settings.setInsightMode(value);
                              }
                            },
                            child: Column(
                              children: const [
                                RadioListTile<InsightMode>(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Instant - after each log'),
                                  value: InsightMode.instant,
                                ),
                                RadioListTile<InsightMode>(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Daily summary - at 21:00'),
                                  value: InsightMode.daily,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('AI model'),
                        subtitle: _ModelSubtitle(
                          downloaded: _modelDownloaded,
                          downloading: _isDownloadingModel,
                          progress: _downloadProgress,
                        ),
                        trailing: _isDownloadingModel
                            ? SizedBox(
                                width: 36,
                                height: 36,
                                child: Center(
                                  child: Text('${(_downloadProgress * 100).round()}%'),
                                ),
                              )
                            : _modelDownloaded
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : ElevatedButton(
                                    onPressed: _downloadModel,
                                    child: const Text('Download'),
                                  ),
                      ),
                      if (!_modelDownloaded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'This model works best on devices with 3GB+ RAM.',
                            style: theme.textTheme.bodySmall,
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
                      Text('Notifications', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Daily reminder at 21:00'),
                        value: settings.dailyReminderEnabled,
                        onChanged: (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (value) {
                            final granted = await NotificationService
                                .instance
                                .requestPermissionIfNeeded();
                            if (!granted && mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Notification permission is needed to enable reminders.',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          await settings.setDailyReminderEnabled(value);
                          await NotificationService.instance.syncWithPreferences();
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
                        'Sensory feedback',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sound effects'),
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
                        value: settings.backgroundMusicEnabled,
                        onChanged: (value) async {
                          await settings.setBackgroundMusicEnabled(value);
                          await AudioService.instance.updatePlaybackPreference();
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
                      Text('Data', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Export mood history'),
                        trailing: const Icon(Icons.ios_share_rounded),
                        onTap: _exportMoodHistory,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Delete all data',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.redAccent,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.redAccent,
                        ),
                        onTap: _deleteAllData,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: AppThemePreset.values.map((preset) {
                          final presetPalette = AppTheme.paletteOf(preset);
                          return ChoiceChip(
                            selected: settings.currentTheme == preset,
                            label: Text(AppTheme.labelFor(preset)),
                            avatar: CircleAvatar(
                              backgroundColor: presetPalette.seed,
                              child: Icon(
                                Icons.palette_rounded,
                                size: 16,
                                color: presetPalette.accent,
                              ),
                            ),
                            onSelected: (_) async {
                              await settings.setTheme(preset);
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

class _ModelSubtitle extends StatelessWidget {
  const _ModelSubtitle({
    required this.downloaded,
    required this.downloading,
    required this.progress,
  });

  final bool downloaded;
  final bool downloading;
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (downloaded) {
      return const Text('Gemma 4 E2B - ready');
    }

    if (downloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text('${(progress * 100).round()}%'),
        ],
      );
    }

    return const Text('Not downloaded - ~1.3 GB');
  }
}
