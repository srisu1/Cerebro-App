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
// Historical testing gifts — intentionally zero in production so the
// dashboard reflects actions the user has actually taken. Any display
// of non-zero XP / cash on a brand-new account would be misleading.
const int startingXp = 0;
const int startingCash = 0;

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

  // XP semantics — totalXp is CUMULATIVE (matches backend's User.total_xp).
  // Each level is a constant AppConstants.xpPerLevel (500) wide, so:
  //   level           = totalXp ~/ 500 + 1
  //   xpInCurrentLevel = totalXp % 500           (progress inside the bar)
  //   xpForNext       = 500                      (bar capacity)
  //   xpToNextLevel   = 500 - (totalXp % 500)    (XP still needed this level)
  //
  // We deliberately don't compute `level` from totalXp here — backend sends
  // it explicitly on /gamification/stats so we trust it and fall back to the
  // computed value only inside _addXp for optimistic updates.
  int get xpInCurrentLevel => totalXp % AppConstants.xpPerLevel;
  int get xpForNext => AppConstants.xpPerLevel;
  int get xpToNextLevel => AppConstants.xpPerLevel - xpInCurrentLevel;
  double get xpProgress =>
      (xpInCurrentLevel / AppConstants.xpPerLevel).clamp(0.0, 1.0);

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

  //
  // Why the ordering matters:
  //   On logout we wipe per-user SharedPreferences keys (total_xp, cash,
  //   streak_days, level, …). The very next login therefore has a cache
  //   that says "0". If we paint cache first and then hit the server,
  //   every widget that watches DashboardState.totalXp paints 0, then
  //   the real value arrives a few hundred ms later and we "snap" — that
  //   is the exact "XP shows zero until I tick a quest" bug the user
  //   keeps reporting.
  //
  // Fix:
  //   When a token exists, run the server sync FIRST (and await it) so
  //   totalXp / level / cash / streak_days are authoritative before the
  //   widget tree ever reads them. We still load cache afterwards so
  //   screens that depend on non-gamification cached bits (avatar JSON,
  //   today_mood, today_study_minutes) keep their fast path. If the
  //   server call fails, we fall back to whatever the cache had.
  //
  //   When there's no token (pre-login), the server call would 401, so
  //   we skip it entirely and just paint the (empty) cache.
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);

    final prefs = await SharedPreferences.getInstance();
    final hasToken =
        (prefs.getString(AppConstants.accessTokenKey) ?? '').isNotEmpty;

    if (hasToken) {
      // Server-first: populate the critical gamification fields from the
      // backend BEFORE any widget sees a cached zero.
      await _syncFromApi();
      // Cache load is still needed for fields the server doesn't own
      // (avatar config, locally-tracked water intake, etc.) — but it
      // must not stomp on the server values we just wrote.
      await _loadFromCache(preserveGamification: true);
    } else {
      // Not logged in — cache is all we have. If it's wiped, state stays
      // at the defaults (0 / level 1), which is the correct rendering
      // for a signed-out user.
      await _loadFromCache(preserveGamification: false);
    }

    state = state.copyWith(isLoading: false);
  }

  //
  // Called by the `ref.listen` on `authProvider` in two situations:
  //   1. A new account just authenticated — we need to wipe account A's
  //      XP/cash/streak/habits from memory so the UI doesn't flash them
  //      before /gamification/stats returns account B's values.
  //   2. The user just logged out — same reason, the next login screen
  //      (or re-entry into the app as a different user) should never
  //      see the previous session's numbers.
  //
  // This is intentionally synchronous and only touches in-memory state.
  // SharedPreferences are wiped separately by [clearUserScope] /
  // [refreshUserScope] in `utils/user_session.dart`.
  void resetForNewUser() {
    state = DashboardState(lastRefreshed: DateTime.now());
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

  //
  // When [preserveGamification] is true, we do NOT overwrite totalXp /
  // level / cash / streak on the state — they were already set by a
  // fresh /gamification/stats sync and the on-disk cache may be stale
  // (e.g. wiped by logout before the new account logged in). Everything
  // else (avatar, habits list, today's mood / study minutes / sleep) is
  // still loaded from cache because the server may not own those fields
  // or the sync may not have pulled them yet.
  Future<void> _loadFromCache({bool preserveGamification = false}) async {
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

    // If STILL empty, leave empty instead of forcing a generic set.
    // The wizard writes the user's real picks to both cerebro_initial_habits
    // and /daily/habits, and the subsequent _syncFromApi() call will hydrate
    // them. Showing four random "Drink Water / Read / Exercise / Stretch"
    // placeholders here would be precisely the "nothing can be static"
    // failure mode — better to render the empty state until real picks land.

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

    if (preserveGamification) {
      // Gamification fields were just set by the server — leave them
      // alone. Only hydrate caches that the server didn't touch.
      state = state.copyWith(
        displayName: prefs.getString('display_name') ?? state.displayName,
        todayMood: prefs.getString('today_mood'),
        studyMinutes:
            prefs.getInt('today_study_minutes') ?? state.studyMinutes,
        sleepHours: prefs.getString('today_sleep'),
        habits: habits,
        avatarConfig: avatarConfig,
      );
    } else {
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
    }

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

    // BACKEND is the source of truth — local cache is just for fast first
    // paint. Without this, logging out wipes local prefs and login shows
    // zeros until a habit completion triggers a fresh server response.
    // Habit completions, study sessions etc. already increment server-side
    // values directly, so we always trust the server here.
    try {
      final gamRes = await _api.get('/gamification/stats');
      if (gamRes.statusCode == 200) {
        final g = gamRes.data;
        final prefs = await SharedPreferences.getInstance();
        final totalXp = (g['total_xp'] as num?)?.toInt() ?? state.totalXp;
        final level = (g['level'] as num?)?.toInt() ?? state.level;
        final coins = (g['coins'] as num?)?.toInt() ?? state.cash;
        final streak = (g['streak_days'] as num?)?.toInt() ?? state.streak;
        await prefs.setInt('total_xp', totalXp);
        await prefs.setInt('level', level);
        await prefs.setInt('cash', coins);
        await prefs.setInt('streak_days', streak);
        state = state.copyWith(
          totalXp: totalXp,
          level: level,
          cash: coins,
          streak: streak,
        );
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
  ///
  /// Server is authoritative — we POST /gamification/exchange and reconcile
  /// our local state from the response so totals never drift between the
  /// in-memory state, SharedPreferences, and the DB.
  Future<bool> exchangeXpToCash(int amount) async {
    final xpCost = amount * xpPerCash;
    if (amount <= 0 || state.totalXp < xpCost) return false;

    try {
      final res = await _api.post(
        '/gamification/exchange',
        data: {'coins': amount},
      );

      if (res.statusCode != 200 || res.data == null) {
        return false;
      }

      final data = res.data as Map;
      final totalXp =
          (data['total_xp'] as num?)?.toInt() ?? (state.totalXp - xpCost);
      final level = (data['level'] as num?)?.toInt() ?? state.level;
      final coins =
          (data['coins'] as num?)?.toInt() ?? (state.cash + amount);

      state = state.copyWith(totalXp: totalXp, level: level, cash: coins);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_xp', totalXp);
      await prefs.setInt('level', level);
      await prefs.setInt('cash', coins);

      return true;
    } catch (_) {
      // Backend unreachable or rejected — don't fake success locally,
      // it would desync from the server on next fetch.
      return false;
    }
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
    // Cumulative XP model — mirrors backend's User.total_xp + level formula
    // (level = total_xp // 500 + 1). totalXp never resets on level-up; we
    // render progress via modulo in the getters above. This keeps the
    // optimistic local update consistent with what /gamification/stats will
    // return next time we sync, so no numbers "jump" after a background sync.
    final newXp = (state.totalXp + amount).clamp(0, 1 << 31).toInt();
    final newLevel = (newXp ~/ AppConstants.xpPerLevel) + 1;
    final didLevelUp = newLevel > state.level;

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

  // Intentionally no static "default quests" — the wizard is the sole
  // source of truth for which quests a user tracks. If something goes
  // wrong and no quests are found, we render an empty state rather
  // than seeding fake ones the user never opted into.
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final notifier = DashboardNotifier(api);

  // Auth transitions (logout → login, or new account on same device) wipe
  // the per-user SharedPreferences cache via utils/user_session.dart. The
  // notifier's in-memory state is still the *previous* account's data at
  // that moment, so we explicitly reset the gamification fields to their
  // defaults AND force a reload from the freshly-scoped prefs / server
  // whenever we land in the authenticated state. Without this reset the
  // next user can briefly see the previous user's XP / cash / streak
  // before the server response lands — exactly the "it shows 0 sometimes,
  // sometimes the other user's number" bug.
  ref.listen<AuthState>(authProvider, (prev, next) {
    final becameAuthed = (prev?.status != AuthStatus.authenticated) &&
        (next.status == AuthStatus.authenticated);
    final becameUnauthed = (prev?.status == AuthStatus.authenticated) &&
        (next.status != AuthStatus.authenticated);
    if (becameAuthed) {
      // Zero out per-user fields so we never paint account A's XP/cash/
      // streak while account B's /gamification/stats is still in flight.
      notifier.resetForNewUser();
      // ignore: discarded_futures
      notifier.loadAll();
    } else if (becameUnauthed) {
      // On logout, immediately clear the visible surface so the login
      // screen (or whatever re-uses the provider) doesn't flash stale
      // numbers before the next account logs in.
      notifier.resetForNewUser();
    }
  });

  return notifier;
});
