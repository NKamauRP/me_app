import 'package:flutter/material.dart';

import '../../../core/app_routes.dart';
import '../../../core/date_utils.dart';
import '../../../db/app_database.dart';
import '../../../models/mood_log.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../mood_catalog.dart';
import 'mood_detail_screen.dart';

class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  static const int _pageSize = 24;

  final ScrollController _scrollController = ScrollController();
  final List<MoodLog> _logs = <MoodLog>[];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadInitialHistory();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitialHistory() async {
    try {
      final logs = await AppDatabase.instance.fetchMoodLogsPage(limit: _pageSize);
      if (!mounted) {
        return;
      }

      setState(() {
        _logs
          ..clear()
          ..addAll(logs);
        _hasMore = logs.length == _pageSize;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() => _isLoadingMore = true);
    try {
      final nextPage = await AppDatabase.instance.fetchMoodLogsPage(
        limit: _pageSize,
        offset: _logs.length,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _logs.addAll(nextPage);
        _hasMore = nextPage.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoadingMore = false);
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 240;
    if (_scrollController.position.pixels >= threshold) {
      _loadMoreHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood history'),
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Your check-ins will appear here once you log a mood.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: _logs.length + (_isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= _logs.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                );
              }

              final log = _logs[index];
              final staggerIndex = index > 5 ? 5 : index;
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 280 + (staggerIndex * 45)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _MoodHistoryItem(log: log),
              );
            },
          );
        },
      ),
    );
  }
}

class _MoodHistoryItem extends StatelessWidget {
  const _MoodHistoryItem({
    required this.log,
  });

  final MoodLog log;

  @override
  Widget build(BuildContext context) {
    final mood = moodOptionById(log.mood);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          Navigator.of(context).push(
            buildAppRoute(MoodDetailScreen(log: log)),
          );
        },
        child: GlassPanel(
          tint: mood.color.withValues(alpha: 0.1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: mood.color.withValues(alpha: 0.14),
                child: Text(
                  mood.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mood.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      log.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppDateUtils.readableDate(log.date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
