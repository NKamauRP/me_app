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
import '../services/ai_service.dart';
import '../shared/widgets/glass_panel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AiModelVariant _selectedVariant = AiModelVariant.gemma4;
  late Future<bool> _modelDownloaded;
  late Future<Map<String, dynamic>> _modelMetadata;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _modelDownloaded = AiService.instance.isModelDownloaded(_selectedVariant);
    _modelMetadata = AiService.instance.getModelMetadata(_selectedVariant);
    _loadActiveVariant();
  }

  Future<void> _loadActiveVariant() async {
    final variant = await AiService.instance.getActiveVariant();
    setState(() {
      _selectedVariant = variant;
      _modelDownloaded = AiService.instance.isModelDownloaded(variant);
      _modelMetadata = AiService.instance.getModelMetadata(variant);
    });
  }

  Future<void> _onVariantChanged(AiModelVariant? variant) async {
    if (variant == null) return;
    await AiService.instance.setActiveVariant(variant);
    setState(() {
      _selectedVariant = variant;
      _modelDownloaded = AiService.instance.isModelDownloaded(variant);
      _modelMetadata = AiService.instance.getModelMetadata(variant);
    });
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    await AiService.instance.downloadModel(
      variant: _selectedVariant,
      onProgress: (value) {
        if (!mounted) return;
        setState(() => _downloadProgress = value);
      },
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _modelDownloaded = AiService.instance.isModelDownloaded(_selectedVariant);
          _modelMetadata = AiService.instance.getModelMetadata(_selectedVariant);
          _downloadProgress = 1;
        });
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
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
    await AiService.instance.reset();
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
      _loadActiveVariant();
      _downloadProgress = 0;
      _isDownloading = false;
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
                FutureBuilder<bool>(
                  future: _modelDownloaded,
                  builder: (context, snapshot) {
                    final isDownloaded = snapshot.data ?? false;
                    if (isDownloaded || _isDownloading) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.accent.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: palette.accent, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Complete Your Setup',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: palette.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'To enable AI Companion and Insights, you\'ll need to install the on-device intelligence model.',
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _startDownload,
                            child: const Text('Start Download'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('AI Intelligence', style: theme.textTheme.titleLarge),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.green),
                                const SizedBox(width: 6),
                                Text(
                                  'ACTIVE',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                          child: Column(
                            children: [
                              RadioListTile<InsightMode>(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Instant - after each log'),
                                value: InsightMode.instant,
                                groupValue: settings.insightMode,
                                onChanged: (value) async {
                                  if (value != null) await settings.setInsightMode(value);
                                },
                              ),
                              RadioListTile<InsightMode>(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Daily summary - at 21:00'),
                                value: InsightMode.daily,
                                groupValue: settings.insightMode,
                                onChanged: (value) async {
                                  if (value != null) await settings.setInsightMode(value);
                                },
                              ),
                            ],
                          ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text('System & Connectivity', style: theme.textTheme.titleLarge),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.link_rounded, size: 14, color: Colors.blue),
                                const SizedBox(width: 6),
                                Text(
                                  'LOCAL',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Privacy Guaranteed Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_rounded, color: Colors.green, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Privacy Verified',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ME utilizes edge-intelligence. Your data never leaves your device.',
                                    style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<AiModelVariant>(
                        initialValue: _selectedVariant,
                        decoration: InputDecoration(
                          labelText: 'On-Device Model (SLM)',
                          labelStyle: TextStyle(color: palette.seed),
                          filled: true,
                          fillColor: palette.seed.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: AiModelVariant.values.map((variant) {
                          final isRecommended = variant == AiModelVariant.gemma4;
                          return DropdownMenuItem(
                            value: variant,
                            child: Text(
                              '${variant.label}${isRecommended ? " (Recommended)" : ""}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          );
                        }).toList(),
                        onChanged: _isDownloading ? null : _onVariantChanged,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: palette.seed.withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'At least 4GB RAM is recommended to prevent app crashes.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.seed.withValues(alpha: 0.6),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<List<dynamic>>(
                        future: Future.wait([_modelDownloaded, _modelMetadata]),
                        builder: (context, snapshot) {
                          final downloaded = snapshot.data?[0] as bool? ?? false;
                          final metadata = snapshot.data?[1] as Map<String, dynamic>? ?? {};

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: palette.seed.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: palette.seed.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          downloaded ? Icons.check_circle_rounded : Icons.cloud_download_rounded,
                                          color: downloaded ? Colors.green : palette.seed,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(_selectedVariant.label, style: theme.textTheme.titleMedium),
                                              Text(
                                                downloaded ? 'Offline model active' : 'Download required (~${_selectedVariant.estimate})',
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!downloaded && !_isDownloading)
                                          FilledButton.tonal(
                                            onPressed: _startDownload,
                                            child: const Text('Install'),
                                          ),
                                      ],
                                    ),
                                    if (downloaded) ...[
                                      const Divider(height: 24),
                                      _ModelDetailRow(label: 'Storage Path', value: metadata['path'] ?? '--'),
                                      const SizedBox(height: 12),
                                      _ModelDetailRow(label: 'Model Size', value: metadata['size'] ?? '--'),
                                    ],
                                    if (_isDownloading) ...[
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'INSTALLING ${_selectedVariant.name.toUpperCase()}',
                                            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
                                          ),
                                          Text(
                                            '${(_downloadProgress * 100).round()}%',
                                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: palette.seed),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Stack(
                                        children: [
                                          Container(
                                            height: 10,
                                            width: double.infinity,
                                            decoration: BoxDecoration(color: palette.seed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            height: 10,
                                            width: (MediaQuery.of(context).size.width - 100) * _downloadProgress,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: [palette.seed, palette.accent]),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Downloading to local storage...',
                                              style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted, fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
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



class _ModelDetailRow extends StatelessWidget {
  const _ModelDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
