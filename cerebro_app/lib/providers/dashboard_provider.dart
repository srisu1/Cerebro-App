/// CEREBRO – Dashboard State Provider
/// Manages all dashboard data: profile, stats, habits, mood.
/// Dual currency: XP (star) earned by actions, Cash (green) exchanged from XP.
/// 20 XP = 1 Cash. Cash is spent in the store.
/// Pulls from API when available, caches locally in SharedPreferences.
/// Reactive via Riverpod — all screens watch this.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

const int xpPerCash = 20; // 20 XP = 1 Cash
const int startingXp = 20; // new users start with 20 XP

/// Icon string mapping for habit presets (used by onboarding + quest mgmt)
const Map<String, String> habitIconMap = {
  'Drink Water': 'water',
  'Exercise': 'fitness',
  'Read': 'book',
  'Meditate': 'self_improve',
  'No Junk Food': 'no_food',
  'Walk 10k Steps': 'walk',
  'No Social Media': 'phone_off',
  'Study 2+ Hours': 'school',
  'Sleep Before 12': 'night',
  'Stretch': 'fitness',
  'Read 15 min': 'book',
};

class DashboardState {
  final bool isLoading;
  final String displayName;
  final int totalXp;
  final int level;
  final int streak;
  final int cash; // green currency — exchanged from XP, spent in store
  final String? todayMood;
  final int studyMinutes;
  final String? sleepHours;
  final List<Map<String, dynamic>> habits;
  final AvatarConfig? avatarConfig;
  final DateTime lastRefreshed;

  const DashboardState({
    this.isLoading = true,
    this.displayName = 'Scholar',
    this.totalXp = 0,
    this.level = 1,
    this.streak = 0,
    this.cash = 0,
    this.todayMood,
    this.studyMinutes = 0,
    this.sleepHours,
    this.habits = const [],
    this.avatarConfig,
    required this.lastRefreshed,
  });

  int get habitsDone => habits.where((h) => h['done'] == true).length;
  int get xpForNext => level * AppConstants.xpPerLevel;
  double get xpProgress => (totalXp / xpForNext).clamp(0.0, 1.0);

  /// How many cash the user can exchange right now
  int get exchangeableCash => totalXp ~/ xpPerCash;

  DashboardState copyWith({
    bool? isLoading,
    String? displayName,
    int? totalXp,
    int? level,
    int? streak,
    int? cash,
    String? todayMood,
    bool clearMood = false,
    int? studyMinutes,
    String? sleepHours,
    bool clearSleep = false,
    List<Map<String, dynamic>>? habits,
    AvatarConfig? avatarConfig,
    DateTime? lastRefreshed,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      displayName: displayName ?? this.displayName,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      cash: cash ?? this.cash,
      todayMood: clearMood ? null : (todayMood ?? this.todayMood),
      studyMinutes: studyMinutes ?? this.studyMinutes,
      sleepHours: clearSleep ? null : (sleepHours ?? this.sleepHours),
      habits: habits ?? this.habits,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final ApiService _api;

  DashboardNotifier(this._api)
      : super(DashboardState(lastRefreshed: DateTime.now())) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    await _loadFromCache();
    state = state.copyWith(isLoading: false);
    // Then try API in background (non-blocking)
    _syncFromApi();
  }

  Future<void> refresh() async {
    // Re-read avatar from cache (may have been changed on avatar screen)
    final prefs = await SharedPreferences.getInstance();
    final avatarJson = prefs.getString(AppConstants.avatarConfigKey);
    if (avatarJson != null) {
      try {
        final config = AvatarConfig.fromJson(jsonDecode(avatarJson));
        state = state.copyWith(avatarConfig: config);
      } catch (_) {}
    }
    await _syncFromApi();
    state = state.copyWith(lastRefreshed: DateTime.now());
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();

    AvatarConfig? avatarConfig;
    final avatarJson = prefs.getString(AppConstants.avatarConfigKey);
    if (avatarJson != null) {
      try {
        avatarConfig = AvatarConfig.fromJson(jsonDecode(avatarJson));
      } catch (_) {}
    }

    // We store the user's quest *definitions* in 'quest_definitions'
    // and the daily completion state in 'habits_date' key.
    // If the date has changed, we reset all 'done' flags.
    final today = _todayKey();
    final lastHabitDate = prefs.getString('habits_date');
    final needsReset = lastHabitDate != today;

    // Load quest definitions (the quests themselves, without done state)
    List<Map<String, dynamic>> questDefs = [];
    final questDefsJson = prefs.getString('quest_definitions');
    if (questDefsJson != null) {
      try {
        final list = jsonDecode(questDefsJson) as List;
        questDefs = list.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    // If no quest definitions exist, check if onboarding set habits
    if (questDefs.isEmpty) {
      final onboardingHabits = prefs.getStringList('cerebro_initial_habits');
      if (onboardingHabits != null && onboardingHabits.isNotEmpty) {
        questDefs = onboardingHabits.map((name) {
          final icon = habitIconMap[name] ?? 'check';
          return {'name': name, 'icon': icon};
        }).toList();
      }
    }

    // If still empty, fall back to old daily_habits format (migration)
    if (questDefs.isEmpty) {
      final oldJson = prefs.getString('daily_habits');
      if (oldJson != null) {
        try {
          final list = jsonDecode(oldJson) as List;
          questDefs = list.map((e) {
            final m = Map<String, dynamic>.from(e);
            return {'name': m['name'], 'icon': m['icon'] ?? 'check'};
          }).toList();
        } catch (_) {}
      }
    }

    // If STILL empty, use defaults
    if (questDefs.isEmpty) {
      questDefs = _defaultQuestDefs();
    }

    // Save quest definitions
    await prefs.setString('quest_definitions', jsonEncode(questDefs));

    // Now build the habits list with done state
    List<Map<String, dynamic>> habits;
    if (needsReset) {
      // New day — reset all done flags
      habits = questDefs.map((q) => {
        'name': q['name'],
        'icon': q['icon'],
        'done': false,
      }).toList();
      await prefs.setString('habits_date', today);
      await prefs.setString('daily_habits', jsonEncode(habits));
    } else {
      // Same day — load today's progress
      final habitsJson = prefs.getString('daily_habits');
      if (habitsJson != null) {
        try {
          final list = jsonDecode(habitsJson) as List;
          habits = list.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {
          habits = questDefs.map((q) => {
            'name': q['name'], 'icon': q['icon'], 'done': false,
          }).toList();
        }
      } else {
        habits = questDefs.map((q) => {
          'name': q['name'], 'icon': q['icon'], 'done': false,
        }).toList();
      }
    }

    // New user detection: if no XP was ever saved, give starting XP
    final hasPlayed = prefs.containsKey('total_xp');
    final defaultXp = hasPlayed ? 0 : startingXp;

    state = state.copyWith(
      displayName: prefs.getString('display_name') ?? 'Scholar',
      totalXp: prefs.getInt('total_xp') ?? defaultXp,
      level: prefs.getInt('level') ?? 1,
      streak: prefs.getInt('streak_days') ?? 0,
      cash: prefs.getInt('cash') ?? 0,
      todayMood: prefs.getString('today_mood'),
      studyMinutes: prefs.getInt('today_study_minutes') ?? 0,
      sleepHours: prefs.getString('today_sleep'),
      habits: habits,
      avatarConfig: avatarConfig,
    );

    // Persist starting XP for new users
    if (!hasPlayed) {
      await prefs.setInt('total_xp', defaultXp);
    }
  }

  Future<void> _syncFromApi() async {
    try {
      // Fetch user profile
      final profileRes = await _api.get('/auth/me');
      if (profileRes.statusCode == 200) {
        final data = profileRes.data;
        final prefs = await SharedPreferences.getInstance();

        final name = data['display_name'] as String? ?? state.displayName;
        await prefs.setString('display_name', name);

        state = state.copyWith(displayName: name);
      }
    } catch (_) {
      // API down — use cached data silently
    }

    try {
      // Fetch today's study sessions
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final studyRes = await _api.get('/study/sessions', queryParams: {
        'start_date': dateStr,
        'end_date': dateStr,
      });
      if (studyRes.statusCode == 200) {
        final sessions = studyRes.data as List? ?? [];
        int totalMin = 0;
        for (final s in sessions) {
          totalMin += (s['duration_minutes'] as num?)?.toInt() ?? 0;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('today_study_minutes', totalMin);
        state = state.copyWith(studyMinutes: totalMin);
      }
    } catch (_) {}

    try {
      // Fetch today's mood
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final moodRes = await _api.get('/health/moods', queryParams: {
        'start_date': dateStr,
        'end_date': dateStr,
      });
      if (moodRes.statusCode == 200) {
        final moods = moodRes.data as List? ?? [];
        if (moods.isNotEmpty) {
          final latestMood = moods.last['mood_type'] as String?;
          if (latestMood != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('today_mood', latestMood);
            state = state.copyWith(todayMood: latestMood);
          }
        }
      }
    } catch (_) {}

    try {
      // Fetch today's sleep
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final sleepRes = await _api.get('/health/sleep', queryParams: {
        'start_date': dateStr,
        'end_date': dateStr,
      });
      if (sleepRes.statusCode == 200) {
        final sleepLogs = sleepRes.data as List? ?? [];
        if (sleepLogs.isNotEmpty) {
          final hours = sleepLogs.last['hours'] as num?;
          if (hours != null) {
            final sleepStr = '${hours.toStringAsFixed(1)}h';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('today_sleep', sleepStr);
            state = state.copyWith(sleepHours: sleepStr);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> logMood(String mood) async {
    // Update local state immediately
    state = state.copyWith(todayMood: mood);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('today_mood', mood);

    // Award XP
    await _addXp(AppConstants.xpPerMoodLog);

    // Sync to API
    try {
      await _api.post('/health/moods', data: {'mood_type': mood});
    } catch (_) {}
  }

  Future<void> toggleHabit(int index) async {
    final updated = List<Map<String, dynamic>>.from(
      state.habits.map((h) => Map<String, dynamic>.from(h)),
    );
    if (index < 0 || index >= updated.length) return;

    final wasDone = updated[index]['done'] == true;
    updated[index]['done'] = !wasDone;

    state = state.copyWith(habits: updated);

    // Persist to cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_habits', jsonEncode(updated));

    // Award XP if completing (not uncompleting)
    if (!wasDone) {
      await _addXp(AppConstants.xpPerHabitComplete);
    }
  }

  /// Add a new quest. Returns true if added.
  Future<bool> addQuest(String name, {String icon = 'check'}) async {
    if (name.trim().isEmpty) return false;
    // Don't allow duplicates
    if (state.habits.any((h) =>
        (h['name'] as String).toLowerCase() == name.trim().toLowerCase())) {
      return false;
    }

    final newHabit = {'name': name.trim(), 'icon': icon, 'done': false};
    final updated = [...state.habits, newHabit];
    state = state.copyWith(habits: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_habits', jsonEncode(updated));
    // Also update definitions
    await _saveQuestDefs(updated);
    return true;
  }

  /// Update quest name/icon at [index].
  Future<void> updateQuest(int index, {String? name, String? icon}) async {
    if (index < 0 || index >= state.habits.length) return;
    final updated = List<Map<String, dynamic>>.from(
      state.habits.map((h) => Map<String, dynamic>.from(h)),
    );
    if (name != null) updated[index]['name'] = name.trim();
    if (icon != null) updated[index]['icon'] = icon;

    state = state.copyWith(habits: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_habits', jsonEncode(updated));
    await _saveQuestDefs(updated);
  }

  /// Delete quest at [index].
  Future<void> deleteQuest(int index) async {
    if (index < 0 || index >= state.habits.length) return;
    final updated = List<Map<String, dynamic>>.from(
      state.habits.map((h) => Map<String, dynamic>.from(h)),
    );
    updated.removeAt(index);

    state = state.copyWith(habits: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_habits', jsonEncode(updated));
    await _saveQuestDefs(updated);
  }

  /// Persist quest definitions (name + icon only, no done state).
  Future<void> _saveQuestDefs(List<Map<String, dynamic>> habits) async {
    final defs = habits.map((h) => {
      'name': h['name'],
      'icon': h['icon'] ?? 'check',
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quest_definitions', jsonEncode(defs));
  }

  /// Exchange XP for cash. [amount] = number of cash to buy.
  /// Each cash costs 20 XP. Returns true if successful.
  Future<bool> exchangeXpToCash(int amount) async {
    final xpCost = amount * xpPerCash;
    if (state.totalXp < xpCost || amount <= 0) return false;

    final newXp = state.totalXp - xpCost;
    final newCash = state.cash + amount;

    state = state.copyWith(totalXp: newXp, cash: newCash);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_xp', newXp);
    await prefs.setInt('cash', newCash);

    return true;
  }

  /// Spend cash in the store. Returns true if successful.
  Future<bool> spendCash(int amount) async {
    if (state.cash < amount || amount <= 0) return false;

    final newCash = state.cash - amount;
    state = state.copyWith(cash: newCash);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cash', newCash);

    return true;
  }

  Future<void> _addXp(int amount) async {
    int newXp = state.totalXp + amount;
    int newLevel = state.level;

    // Level up check — awards bonus XP (not cash directly)
    while (newXp >= newLevel * AppConstants.xpPerLevel) {
      newXp -= newLevel * AppConstants.xpPerLevel;
      newLevel++;
    }

    state = state.copyWith(
      totalXp: newXp,
      level: newLevel,
    );

    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_xp', newXp);
    await prefs.setInt('level', newLevel);
  }

  Future<void> updateAvatarConfig(AvatarConfig config) async {
    state = state.copyWith(avatarConfig: config);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.avatarConfigKey, jsonEncode(config.toJson()));
  }

  /// Default quests — NO Journal
  static List<Map<String, dynamic>> _defaultQuestDefs() => [
        {'name': 'Drink Water', 'icon': 'water'},
        {'name': 'Read 15 min', 'icon': 'book'},
        {'name': 'Exercise', 'icon': 'fitness'},
        {'name': 'Stretch', 'icon': 'fitness'},
      ];

  // Keep for backward compat but delegates to new system
  static List<Map<String, dynamic>> _defaultHabits() =>
      _defaultQuestDefs().map((q) => {...q, 'done': false}).toList();
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return DashboardNotifier(api);
});
