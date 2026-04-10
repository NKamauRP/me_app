import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/theme_service.dart';
import '../../db/app_database.dart';
import '../mind/mood_catalog.dart';
import '../mind/providers/mind_me_provider.dart';
import '../../services/ai_service.dart';
import '../../shared/widgets/glass_panel.dart';
import '../../shared/widgets/halftone_overlay.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AiModelVariant _selectedVariant = AiModelVariant.gemma4;
  bool _isModelDownloaded = false;
  String _modelPath = '--';
  String _modelSize = '--';
  bool _isLoadingModel = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadModelState();

    // Listen to download state from AiService ValueNotifiers
    AiService.instance.isDownloading.addListener(_onDownloadStateChanged);
    AiService.instance.downloadProgress.addListener(_onDownloadProgressChanged);
    AiService.instance.downloadError.addListener(_onDownloadErrorChanged);

    // Sync initial state
    _isDownloading = AiService.instance.isDownloading.value;
    _downloadProgress = AiService.instance.downloadProgress.value;
  }

  @override
  void dispose() {
    AiService.instance.isDownloading.removeListener(_onDownloadStateChanged);
    AiService.instance.downloadProgress.removeListener(_onDownloadProgressChanged);
    AiService.instance.downloadError.removeListener(_onDownloadErrorChanged);
    super.dispose();
  }

  void _onDownloadStateChanged() {
    if (mounted) {
      setState(() => _isDownloading = AiService.instance.isDownloading.value);
      if (!_isDownloading && AiService.instance.downloadProgress.value >= 1.0) {
        _loadModelState(); // Refresh model info on completion
      }
    }
  }

  void _onDownloadProgressChanged() {
    if (mounted) {
      setState(() => _downloadProgress = AiService.instance.downloadProgress.value);
    }
  }

  void _onDownloadErrorChanged() {
    final error = AiService.instance.downloadError.value;
    if (mounted && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model download failed: $error')),
      );
    }
  }

  Future<void> _loadModelState() async {
    final variant = await AiService.instance.getActiveVariant();
    final downloaded = await AiService.instance.isModelDownloaded(variant);
    final metadata = await AiService.instance.getModelMetadata(variant);

    if (!mounted) return;
    setState(() {
      _selectedVariant = variant;
      _isModelDownloaded = downloaded;
      _modelPath = (metadata['path'] as String?) ?? '--';
      _modelSize = (metadata['size'] as String?) ?? '--';
      _isLoadingModel = false;
    });
  }

  Future<void> _onVariantChanged(AiModelVariant? variant) async {
    if (variant == null) return;
    await AiService.instance.setActiveVariant(variant);
    setState(() {
      _selectedVariant = variant;
      _isModelDownloaded = false;
      _modelPath = '--';
      _modelSize = '--';
      _isLoadingModel = true;
    });
    await _loadModelState();
  }

  Future<void> _startDownload() async {
    await AiService.instance.downloadModel(variant: _selectedVariant);
  }

  Future<void> _promptModelSelectionAndDownload() async {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(context.read<ThemeService>().currentTheme);

    final selected = await showModalBottomSheet<AiModelVariant>(
      context: context,
      backgroundColor: palette.scaffold,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Choose an AI Model',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Select the intelligence engine to download to your device.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
                ...AiModelVariant.values.map((variant) {
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text(
                      variant.label, 
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('Download size: ${variant.estimate}'),
                    trailing: Icon(Icons.cloud_download_rounded, color: palette.seed),
                    onTap: () => Navigator.of(context).pop(variant),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      // Ensure the selected model becomes the active one on the UI
      await _onVariantChanged(selected);
      // Start the download using the new selection
      await _startDownload();
    }
  }

  Future<void> _exportMoodHistory() async {
    final entries = await AppDatabase.instance.fetchAllMoodLogs();
    final buffer = StringBuffer('date,time,mood,intensity,note\n');

    for (final entry in entries) {
      final moodId = entry.mood;
      final mood = moodOptionById(moodId);
      final label = mood.label;
      final date = entry.date;
      final time = '';
      final note = entry.note.replaceAll('"', '""');
      buffer.writeln('$date,$time,"$label",${entry.intensity},"$note"');
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/me_mood_history.csv');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)], text: 'ME mood history export');
  }

  Future<void> _deleteAllData() async {
    // Capture context-dependent refs before any async gap
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<MindMeProvider>();

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

    if (!confirmed) return;

    await AppDatabase.instance.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await AiService.instance.reset();
    await ThemeService.instance.reloadPreferences();
    await AudioService.instance.updatePlaybackPreference();
    await NotificationService.instance.cancelAllScheduled();
    await provider.refresh();

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('All local data has been cleared.')),
    );
    setState(() {
      _isModelDownloaded = false;
      _downloadProgress = 0;
      _isDownloading = false;
    });
    await _loadModelState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, settings, _) {
        final theme = Theme.of(context);
        final palette = AppTheme.paletteOf(settings.currentTheme);

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: HalftoneOverlay(
            opacity: settings.currentTheme == AppThemePreset.night || settings.currentTheme == AppThemePreset.focus 
                ? 0.08 
                : 0.04,
            child: Container(
              decoration: BoxDecoration(
                color: palette.scaffold,
              ),
              child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                // ── Setup Banner ──────────────────────────────────────────
                if (!_isModelDownloaded && !_isDownloading && !_isLoadingModel)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
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
                          'Install the on-device AI model to enable the Companion and Insights features.',
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _promptModelSelectionAndDownload,
                          child: const Text('Start Download'),
                        ),
                      ],
                    ),
                  ),

                // ── AI Intelligence ───────────────────────────────────────
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('AI Intelligence', style: theme.textTheme.titleLarge),
                          ),
                          _StatusBadge(label: 'ACTIVE', color: Colors.green),
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
                                title: const Text('Instant — after each log'),
                                value: InsightMode.instant,
                                // ignore: deprecated_member_use
                                groupValue: settings.insightMode,
                                // ignore: deprecated_member_use
                                onChanged: (v) async {
                                  if (v != null) await settings.setInsightMode(v);
                                },
                              ),
                              RadioListTile<InsightMode>(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Daily summary — at 21:00'),
                                value: InsightMode.daily,
                                // ignore: deprecated_member_use
                                groupValue: settings.insightMode,
                                // ignore: deprecated_member_use
                                onChanged: (v) async {
                                  if (v != null) await settings.setInsightMode(v);
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

                // ── Model Selection ───────────────────────────────────────
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('On-Device AI Model', style: theme.textTheme.titleLarge),
                          ),
                          _StatusBadge(label: 'LOCAL', color: Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Privacy banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_rounded, color: Colors.green, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Privacy Verified',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'Your data never leaves this device.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Removed legacy dropdown logic here since we now use the persistent bottom sheet selector.
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 13, color: palette.seed.withValues(alpha: 0.55)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '4 GB RAM recommended to prevent crashes.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.seed.withValues(alpha: 0.55),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Model status card
                      _isLoadingModel
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Container(
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
                                        _isModelDownloaded
                                            ? Icons.check_circle_rounded
                                            : Icons.cloud_download_rounded,
                                        color: _isModelDownloaded ? Colors.green : palette.seed,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedVariant.label,
                                              style: theme.textTheme.titleMedium,
                                            ),
                                            Text(
                                              _isModelDownloaded
                                                  ? 'Offline model active'
                                                  : 'Download required (~${_selectedVariant.estimate})',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!_isModelDownloaded && !_isDownloading)
                                        FilledButton.tonal(
                                          onPressed: _startDownload,
                                          child: const Text('Install'),
                                        ),
                                    ],
                                  ),
                                  if (_isModelDownloaded) ...[
                                    const Divider(height: 24),
                                    _ModelDetailRow(label: 'Storage Path', value: _modelPath),
                                    const SizedBox(height: 10),
                                    _ModelDetailRow(label: 'Model Size', value: _modelSize),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () async {
                                              await AiService.instance.deleteActiveModel();
                                              await _loadModelState();
                                            },
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            label: const Text('Delete Framework', style: TextStyle(color: Colors.redAccent)),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FilledButton.tonalIcon(
                                            onPressed: _promptModelSelectionAndDownload,
                                            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                                            label: const Text('Switch Engine'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_isDownloading) ...[
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'INSTALLING ${_selectedVariant.name.toUpperCase()}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        Text(
                                          '${(_downloadProgress * 100).round()}%',
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: palette.seed,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(5),
                                            child: LinearProgressIndicator(
                                              value: _downloadProgress,
                                              minHeight: 10,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        TextButton(
                                          onPressed: () => AiService.instance.cancelDownload(),
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Downloading to local storage...',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: palette.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Notifications ─────────────────────────────────────────
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
                                  content: Text('Notification permission is needed to enable reminders.'),
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

                // ── Sensory Feedback ──────────────────────────────────────
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sensory Feedback', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sound effects'),
                        value: settings.soundEnabled,
                        onChanged: (value) async {
                          await settings.setSoundEnabled(value);
                          if (value) await SoundService.instance.playTap();
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Haptics'),
                        value: settings.hapticsEnabled,
                        onChanged: (value) async {
                          await settings.setHapticsEnabled(value);
                          if (value) await HapticsService.instance.lightImpact();
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

                // ── Data ──────────────────────────────────────────────────
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
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.redAccent),
                        ),
                        trailing: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                        onTap: _deleteAllData,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Theme ─────────────────────────────────────────────────
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
        ),
      );
    },
  );
}
}

// ── Supporting widgets ─────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _ModelDetailRow extends StatelessWidget {
  const _ModelDetailRow({required this.label, required this.value});
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
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
