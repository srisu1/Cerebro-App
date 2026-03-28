// Per-user SharedPreferences scoping — wipes stale data on account switch.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/services/api_service.dart';

// Pref key for the user_id whose data currently lives in prefs.
const String kActiveUserIdKey = 'cerebro_active_user_id';

// All per-user pref keys. Add new ones here so account-switch wipes them.
const List<String> kPerUserPrefKeys = [
  // Gamification
  'total_xp',
  'level',
  'cash',
  'streak_days',
  'display_name',

  // Dashboard / daily
  'daily_habits',
  'quest_definitions',
  'habits_date',
  'today_mood',
  'today_study_minutes',
  'today_sleep',

  // Wizard snapshots
  'cerebro_initial_habits',
  'cerebro_initial_mood',
  'cerebro_medical_conditions',
  'cerebro_bedtime_hour',
  'cerebro_bedtime_min',
  'cerebro_wake_hour',
  'cerebro_wake_min',

  // Avatar + onboarding gates (kept per-account so new accounts re-do setup)
  AppConstants.onboardingCompleteKey,
  AppConstants.setupCompleteKey,
  AppConstants.avatarCreatedKey,
  AppConstants.avatarConfigKey,

  // Legacy unscoped store ownership (scoped version lives under
  // `store_owned__$userId` and survives the wipe)
  'store_owned',
];

/// Resolve current user_id from prefs cache or /auth/me fallback.
Future<String?> resolveUserId(ApiService api) async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(AppConstants.userIdKey);
  if (cached != null && cached.isNotEmpty) return cached;

  try {
    final res = await api.get('/auth/me');
    if (res.statusCode == 200) {
      final raw = res.data;
      final id = raw is Map ? (raw['id'] ?? '').toString() : '';
      if (id.isNotEmpty) {
        await prefs.setString(AppConstants.userIdKey, id);
        return id;
      }
    }
  } catch (_) {
    // Offline or token invalid — cache stays whatever it was.
  }
  return null;
}

/// Wipe per-user prefs if the active account changed. Returns true on wipe.
Future<bool> refreshUserScope(ApiService api) async {
  final currentId = await resolveUserId(api);
  if (currentId == null || currentId.isEmpty) return false;

  final prefs = await SharedPreferences.getInstance();
  final lastActive = prefs.getString(kActiveUserIdKey);

  if (lastActive == currentId) return false;

  // Different account is active now (or this is the first sign-in on
  // this device) — clear everything the previous session stashed.
  for (final k in kPerUserPrefKeys) {
    await prefs.remove(k);
  }
  await prefs.setString(kActiveUserIdKey, currentId);
  return true;
}

/// Clear active-user stamp + per-user keys (called on logout).
Future<void> clearUserScope() async {
  final prefs = await SharedPreferences.getInstance();
  for (final k in kPerUserPrefKeys) {
    await prefs.remove(k);
  }
  await prefs.remove(kActiveUserIdKey);
}
