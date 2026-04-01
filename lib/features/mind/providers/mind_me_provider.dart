import 'package:flutter/foundation.dart';

import '../../../core/date_utils.dart';
import '../../../db/app_database.dart';
import '../../../models/checkin_result.dart';
import '../../../models/mood_log.dart';
import '../../../models/user_stats.dart';
import '../../../services/xp_engine.dart';
import '../daily_insight.dart';
import '../mood_catalog.dart';

class MindMeProvider extends ChangeNotifier {
  MindMeProvider({
    required AppDatabase database,
    XpEngine? xpEngine,
  })  : _database = database,
        _xpEngine = xpEngine ?? XpEngine();

  final AppDatabase _database;
  final XpEngine _xpEngine;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  UserStats _stats = UserStats.initial();
  MoodLog? _todayLog;
  List<MoodLog> _recentLogs = const [];
  List<MoodLog> _weeklyLogs = const [];

  bool get isLoading => _isLoading;

  bool get hasLoadedOnce => _hasLoadedOnce;

  String? get errorMessage => _errorMessage;

  UserStats get stats => _stats;

  MoodLog? get todayLog => _todayLog;

  List<MoodLog> get recentLogs => _recentLogs;

  List<MoodLog> get weeklyLogs => _weeklyLogs;

  bool get hasLoggedToday => _todayLog != null;

  Future<void> initialize() async {
    if (_hasLoadedOnce) {
      return;
    }

    await refresh();
  }

  Future<void> refresh() async {
    _setLoading(true);

    try {
      _stats = await _database.ensureUserStats();
      _todayLog = await _database.getMoodLogByDate(
        AppDateUtils.toStorageDate(DateTime.now()),
      );
      _recentLogs = await _database.fetchRecentMoodLogs(limit: 5);
      _weeklyLogs = await _loadWeeklyLogs(DateTime.now());
      _errorMessage = null;
      _hasLoadedOnce = true;
    } catch (_) {
      _errorMessage = 'Unable to load your journal right now.';
    } finally {
      _setLoading(false);
    }
  }

  Future<CheckInResult> submitMood({
    required MoodOption mood,
    required int intensity,
    required String note,
  }) async {
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) {
      throw ArgumentError('Please answer the question before submitting.');
    }

    _setLoading(true);

    try {
      final now = DateTime.now();
      final todayKey = AppDateUtils.toStorageDate(now);
      final currentStats = await _database.ensureUserStats();
      final existingLog = await _database.getMoodLogByDate(todayKey);

      if (existingLog != null) {
        final updatedLog = existingLog.copyWith(
          mood: mood.id,
          intensity: intensity,
          note: trimmedNote,
        );
        await _database.updateMoodLog(updatedLog);
        final weeklyLogs = await _loadWeeklyLogs(now);
        _todayLog = updatedLog;
        _stats = currentStats;
        _recentLogs = await _database.fetchRecentMoodLogs(limit: 5);
        _weeklyLogs = weeklyLogs;
        _errorMessage = null;
        notifyListeners();

        return CheckInResult.alreadyCheckedIn(
          log: updatedLog,
          stats: currentStats,
          dailyInsight: buildDailyInsight(
            previousStats: currentStats,
            updatedStats: currentStats,
            weeklyLogs: weeklyLogs,
            alreadyCheckedIn: true,
            leveledUp: false,
          ),
        );
      }

      final savedLog = await _database.insertMoodLog(
        MoodLog(
          date: todayKey,
          mood: mood.id,
          intensity: intensity,
          note: trimmedNote,
        ),
      );

      // Rewards are calculated after confirming this is the first log for today.
      final reward = _xpEngine.calculate(
        currentStats: currentStats,
        today: now,
      );
      final updatedStats = currentStats.copyWith(
        xp: reward.newXp,
        level: reward.newLevel,
        streak: reward.newStreak,
        lastCheckinDate: todayKey,
      );

      await _database.upsertUserStats(updatedStats);
      final weeklyLogs = await _loadWeeklyLogs(now);

      _todayLog = savedLog;
      _stats = updatedStats;
      _recentLogs = await _database.fetchRecentMoodLogs(limit: 5);
      _weeklyLogs = weeklyLogs;
      _errorMessage = null;
      notifyListeners();

      return CheckInResult(
        log: savedLog,
        stats: updatedStats,
        baseXp: reward.baseXp,
        streakBonusXp: reward.streakBonusXp,
        continuedStreak: reward.continuedStreak,
        leveledUp: reward.leveledUp,
        alreadyCheckedIn: false,
        dailyInsight: buildDailyInsight(
          previousStats: currentStats,
          updatedStats: updatedStats,
          weeklyLogs: weeklyLogs,
          alreadyCheckedIn: false,
          leveledUp: reward.leveledUp,
        ),
      );
    } catch (_) {
      _errorMessage = 'Your check-in could not be saved.';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  Future<List<MoodLog>> _loadWeeklyLogs(DateTime anchorDate) {
    final end = AppDateUtils.toStorageDate(anchorDate);
    final start = AppDateUtils.toStorageDate(
      DateTime(anchorDate.year, anchorDate.month, anchorDate.day)
          .subtract(const Duration(days: 6)),
    );

    return _database.fetchMoodLogsBetween(
      startDate: start,
      endDate: end,
    );
  }
}
