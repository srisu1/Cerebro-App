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
const int startingCash = 50; // new users start with 50 cash for testing

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
  final String? backendExpression; // expression from backend intelligence
  final int? pendingLevelUp; // non-null = show level-up celebration for this level
  final int waterIntake; // glasses of water today (out of 8)
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
    this.backendExpression,
    this.pendingLevelUp,
    this.waterIntake = 0,
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
    String? backendExpression,
    int? pendingLevelUp,
    bool clearLevelUp = false,
    int? waterIntake,
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
      backendExpression: backendExpression ?? this.backendExpression,
      pendingLevelUp: clearLevelUp ? null : (pendingLevelUp ?? this.pendingLevelUp),
      waterIntake: waterIntake ?? this.waterIntake,
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

    // New user detection: if no XP was ever saved, give starting XP + cash
    final hasPlayed = prefs.containsKey('total_xp');
    final defaultXp = hasPlayed ? 0 : startingXp;
    final defaultCash = hasPlayed ? 0 : startingCash;

    // Only give starting cash to genuinely new users (first launch)
    if (!hasPlayed) {
      await prefs.setInt('cash', startingCash);
    }

    state = state.copyWith(
      displayName: prefs.getString('display_name') ?? 'Scholar',
      totalXp: prefs.getInt('total_xp') ?? defaultXp,
      level: prefs.getInt('level') ?? 1,
      streak: prefs.getInt('streak_days') ?? 0,
      cash: prefs.getInt('cash') ?? defaultCash,
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

    // LOCAL is the authority for XP and cash — backend may be stale.
    // We only pull streak from the backend (which we can't track locally).
    // We push our local XP/cash TO the backend to keep it in sync.
    try {
      final gamRes = await _api.get('/gamification/stats');
      if (gamRes.statusCode == 200) {
        final g = gamRes.data;
        final prefs = await SharedPreferences.getInstance();
        // Streak comes from backend (server tracks daily login)
        final streak = (g['streak_days'] as num?)?.toInt() ?? state.streak;
        await prefs.setInt('streak_days', streak);
        state = state.copyWith(streak: streak);
        // Push local XP/cash/level to backend so it stays in sync
        try {
          await _api.post('/gamification/stats/sync', data: {
            'total_xp': state.totalXp,
            'level': state.level,
            'coins': state.cash,
          });
        } catch (_) {} // backend endpoint may not exist yet — that's fine
      }
    } catch (_) {}

    try {
      final habitsRes = await _api.get('/daily/habits');
      if (habitsRes.statusCode == 200) {
        final apiHabits = habitsRes.data as List? ?? [];
        if (apiHabits.isNotEmpty) {
          final habits = apiHabits.map<Map<String, dynamic>>((h) => {
            'id': h['id'],
            'name': h['name'] ?? '',
            'icon': h['icon'] ?? 'check',
            'done': h['done'] == true,
            'color': h['color'] ?? '#10B981',
            'streak_days': h['streak_days'] ?? 0,
          }).toList();

          state = state.copyWith(habits: habits);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('daily_habits', jsonEncode(habits));
          await _saveQuestDefs(habits);
        } else {
          // No habits on backend — seed defaults
          try {
            await _api.post('/daily/habits/seed-defaults');
            // Re-fetch after seeding
            final retryRes = await _api.get('/daily/habits');
            if (retryRes.statusCode == 200) {
              final seeded = retryRes.data as List? ?? [];
              final habits = seeded.map<Map<String, dynamic>>((h) => {
                'id': h['id'],
                'name': h['name'] ?? '',
                'icon': h['icon'] ?? 'check',
                'done': h['done'] == true,
              }).toList();
              state = state.copyWith(habits: habits);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('daily_habits', jsonEncode(habits));
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      // API down — local habits are already loaded
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
          final latestMood = (moods.last['mood_name'] ?? moods.last['mood_type']) as String?;
          if (latestMood != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('today_mood', latestMood);
            state = state.copyWith(todayMood: latestMood);
          }
        }
      }
    } catch (_) {}

    try {
      // Fetch most recent sleep log (last 3 days — covers last night)
      final today = DateTime.now();
      final threeDaysAgo = today.subtract(const Duration(days: 3));
      final startStr =
          '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';
      final endStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final sleepRes = await _api.get('/health/sleep', queryParams: {
        'start_date': startStr,
        'end_date': endStr,
        'limit': '1',
      });
      if (sleepRes.statusCode == 200) {
        final sleepLogs = sleepRes.data as List? ?? [];
        if (sleepLogs.isNotEmpty) {
          final raw = sleepLogs.first['total_hours'] ?? sleepLogs.first['hours'];
          final hours = double.tryParse(raw?.toString() ?? '');
          if (hours != null) {
            final h = hours.clamp(0.0, 24.0); // Sanity cap at 24h
            final sleepStr = '${h.toStringAsFixed(1)}h';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('today_sleep', sleepStr);
            state = state.copyWith(sleepHours: sleepStr);
          }
        }
      }
    } catch (_) {}

    try {
      final exprRes = await _api.get('/gamification/avatar/expression');
      if (exprRes.statusCode == 200) {
        final expr = exprRes.data['expression'] as String?;
        if (expr != null) {
          state = state.copyWith(backendExpression: expr);
        }
      }
    } catch (_) {}
  }

  /// Check for newly unlocked achievements — returns list of unlocked names.
  /// Call this after meaningful actions (study, mood, habit, sleep).
  Future<List<Map<String, dynamic>>> checkAchievements() async {
    try {
      final res = await _api.post('/gamification/achievements/check', data: {});
      if (res.statusCode == 200 && res.data != null) {
        final unlocked = res.data['newly_unlocked'] as List? ?? [];
        if (unlocked.isNotEmpty) {
          // Refresh XP/level since achievements award XP
          await refresh();
          return unlocked.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }


  /// Update mood display locally only (no API call).
  /// Use when another screen already posted to the API.
  void setMoodLocally(String mood) {
    state = state.copyWith(todayMood: mood);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('today_mood', mood);
    });
  }

  Future<void> logMood(String mood) async {
    // Update local state immediately
    state = state.copyWith(todayMood: mood);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('today_mood', mood);

    // Award XP
    await _addXp(AppConstants.xpPerMoodLog);

    // Sync to API — send mood_type (name) which backend now accepts
    try {
      await _api.post('/health/moods', data: {'mood_type': mood});
      // Check for mood-streak achievements
      checkAchievements();
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

    // Award XP locally if completing (not uncompleting)
    if (!wasDone) {
      await _addXp(AppConstants.xpPerHabitComplete);
    }

    // Sync to backend
    final habitId = updated[index]['id'];
    if (habitId != null) {
      try {
        final res = await _api.post('/daily/habits/$habitId/complete');
        if (res.statusCode == 200) {
          final data = res.data;
          // Update XP/level from server (source of truth)
          final xp = (data['total_xp'] as num?)?.toInt();
          final lvl = (data['level'] as num?)?.toInt();
          if (xp != null && lvl != null) {
            state = state.copyWith(totalXp: xp, level: lvl);
            await prefs.setInt('total_xp', xp);
            await prefs.setInt('level', lvl);
          }
        }
      } catch (_) {
        // API down — local state is already updated
      }
    }

    // Check if any achievements were unlocked by this habit completion
    if (!wasDone) {
      checkAchievements();
    }
  }

  void drinkWater() {
    if (state.waterIntake < 8) {
      state = state.copyWith(waterIntake: state.waterIntake + 1);
    }
  }

  void undoWater() {
    if (state.waterIntake > 0) {
      state = state.copyWith(waterIntake: state.waterIntake - 1);
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

    // Try API first to get the ID
    try {
      final res = await _api.post('/daily/habits', data: {
        'name': name.trim(),
        'icon': icon,
      });
      if (res.statusCode == 201) {
        newHabit['id'] = res.data['id'];
      }
    } catch (_) {}

    final updated = [...state.habits, newHabit];
    state = state.copyWith(habits: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_habits', jsonEncode(updated));
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

    // Sync to backend
    final habitId = updated[index]['id'];
    if (habitId != null) {
      try {
        await _api.put('/daily/habits/$habitId', data: {
          if (name != null) 'name': name.trim(),
          if (icon != null) 'icon': icon,
        });
      } catch (_) {}
    }
  }

  /// Delete quest at [index].
  Future<void> deleteQuest(int index) async {
    if (index < 0 || index >= state.habits.length) return;
    final habitId = state.habits[index]['id'];

    final updated = List<Map<String, dynamic>>.from(
      state.habits.map((h) => Map<String, dynamic>.from(h)),
    );
    updated.removeAt(index);

    state = state.copyWith(habits: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_habits', jsonEncode(updated));
    await _saveQuestDefs(updated);

    // Sync to backend
    if (habitId != null) {
      try {
        await _api.delete('/daily/habits/$habitId');
      } catch (_) {}
    }
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

    // Sync to backend
    try {
      await _api.post('/gamification/stats/sync', data: {
        'total_xp': newXp,
        'level': state.level,
        'coins': newCash,
      });
    } catch (_) {}

    return true;
  }

  /// Spend cash in the store. Returns true if successful.
  /// If [itemId] is provided, also calls the backend store purchase endpoint.
  Future<bool> spendCash(int amount, {String? itemId}) async {
    if (state.cash < amount || amount <= 0) return false;

    final newCash = state.cash - amount;
    state = state.copyWith(cash: newCash);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cash', newCash);

    // Sync purchase to backend
    if (itemId != null) {
      try {
        await _api.post('/gamification/store/purchase', data: {
          'item_id': itemId,
        });
      } catch (_) {}
    }

    return true;
  }

  /// Clear the pending level-up so the celebration doesn't re-trigger.
  void clearLevelUp() {
    state = state.copyWith(clearLevelUp: true);
  }

  /// Public wrapper so other tabs (health, daily, etc.) can award XP.
  Future<void> awardXp(int amount) => _addXp(amount);

  Future<void> _addXp(int amount) async {
    int newXp = state.totalXp + amount;
    int newLevel = state.level;
    bool didLevelUp = false;

    // Level up check — awards bonus XP (not cash directly)
    while (newXp >= newLevel * AppConstants.xpPerLevel) {
      newXp -= newLevel * AppConstants.xpPerLevel;
      newLevel++;
      didLevelUp = true;
    }

    state = state.copyWith(
      totalXp: newXp,
      level: newLevel,
      pendingLevelUp: didLevelUp ? newLevel : null,
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

    // Also sync to backend avatar endpoint
    try {
      await _api.post('/gamification/avatar', data: {
        'gender': config.gender,
        'skin_tone': config.baseSkin,
        'hair': config.hairStyle,
        'hair_color': config.hairColor,
        'eyes': config.eyes,
        'nose': config.nose,
        'mouth': config.mouth,
        'clothes': config.clothes,
        'facial_hair': config.facialHair,
        'glasses': config.glasses,
        'headwear': config.headwear,
        'neckwear': config.neckwear,
        'extras': config.extras,
      });
    } catch (_) {
      // Backend sync failed — local already saved
    }
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
