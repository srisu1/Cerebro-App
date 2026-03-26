///
/// A single source of truth for:
///  1. Resolving the currently-authenticated user_id (cached in prefs,
///     with a fallback /auth/me fetch that primes the cache).
///  2. Detecting when the currently cached "active" user_id diverges
///     from the real authenticated user, and wiping all per-user
///     SharedPreferences keys so the next account doesn't inherit
///     the old account's XP / cash / quests / avatar / etc.
///
/// Why this exists:
///  SharedPreferences is a single key-value store shared across all
///  accounts on the device. Historically we wrote keys like 'total_xp',
///  'quest_definitions', 'cash' unscoped. When a user signed out and
///  someone else signed in on the same device (or a brand-new account
///  was created on a dev machine), the new session picked up the old
///  account's gamification / wizard state.
///
///  This helper gives us a narrow, auditable chokepoint: every time
///  auth changes, call [refreshUserScope]. It compares the newly-logged
///  in user_id against the previously-cached active_user_id; on a
///  mismatch it nukes the per-user keys below and records the new
///  active user_id.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/services/api_service.dart';

/// Pref key holding the user_id whose data currently lives in prefs.
/// Distinct from [AppConstants.userIdKey] which is just a cache of the
/// last-known user_id (used for scoped key construction elsewhere).
const String kActiveUserIdKey = 'cerebro_active_user_id';

/// Every per-user SharedPreferences key written anywhere in the app.
///
/// Adding a new per-user key? Put it here too so the next sign-in wipes it.
/// Keys that are genuinely device-global (theme mode, onboarding-skip
/// tutorials, etc.) stay out of this list.
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

/// Resolve the currently-authenticated user_id, caching in prefs.
///
/// Order of resolution:
///   1. [AppConstants.userIdKey] in SharedPreferences (fastest).
///   2. GET /auth/me and cache the id.
///
/// Returns null if neither source has an id (e.g. user isn't signed in).
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

/// Ensure per-user prefs belong to the currently-authenticated user.
///
/// If the newly-resolved user_id differs from [kActiveUserIdKey], wipes
/// every key in [kPerUserPrefKeys]. Then stamps [kActiveUserIdKey] with
/// the current id so subsequent calls are no-ops.
///
/// Returns `true` when a wipe happened (caller can use this to force a
/// reload of dependent state).
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
