/// Everything in one beautiful scrollable page.
/// Bottom sheets for logging. AI insights tie it all together.
///
/// Layout:
///  1. Hero Header with animated Wellness Score ring
///  2. Mood Check-In Strip (MoodSticker avatars — tap to log)
///  3. Water Glasses Row (tap-to-fill cups — user loves these)
///  4. Sleep Card (last night + "How'd you sleep?" prompt)
///  5. Medications Checklist (inline take/skip)
///  6. AI Health Insights Card (smart personalized tips)
///  7. Symptom Quick-Log (simple "Feeling off?" button)
///  8. Weekly Trends mini-chart

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';
import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/widgets/mood_sticker.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';
import 'package:go_router/go_router.dart';

const _ombre1   = Color(0xFFFFFBF7);
const _ombre2   = Color(0xFFFFF8F3);
const _ombre3   = Color(0xFFFFF3EF);
const _ombre4   = Color(0xFFFEEDE9);
const _pawClr   = Color(0xFFF8BCD0);

const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);

const _cardFill = Color(0xFFFFF8F4);
const _coralHdr = Color(0xFFF0A898);
const _coralLt  = Color(0xFFF0A090);
const _greenHdr = Color(0xFF7EC878);
const _greenLt  = Color(0xFFC2E8BC);
const _greenDk  = Color(0xFF88B883);
const _goldHdr  = Color(0xFFE8C840);
const _goldLt   = Color(0xFFFDE890);
const _goldDk   = Color(0xFFD0B048);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFCCA8D8);
const _skyHdr   = Color(0xFF9DD4F0);
const _skyLt    = Color(0xFF98D4F0);
const _sageHdr  = Color(0xFF70B880);
const _sageLt   = Color(0xFF98D0A8);
const _redLt    = Color(0xFFF09888);

const _olive    = Color(0xFF98A869);   // --olive
const _oliveDk  = Color(0xFF58772F);   // --olive-dk
const _inkSoft  = Color(0xFF9A8070);   // --ink-soft
const _pinkDk   = Color(0xFFE890B8);   // --pink-dk
const _orange   = Color(0xFFFFBC5C);   // --orange
const _goldWarm = Color(0xFFE4BC83);   // --gold (warm, matches HTML)
const _blueLt   = Color(0xFFDDF6FF);   // --blue-lt (Log Sleep popup fill)
const _blueLtDk = Color(0xFF4A8FAD);   // deeper blue — text + accents on _blueLt
const _pinkLt   = Color(0xFFFFD5F5);   // --pink-lt
const _rosePink = Color(0xFFF7AEAE);   // Log Symptom popup fill
const _rosePinkDk = Color(0xFFA85058); // deeper rose — text + accents on _rosePink

// Mirrors symptom_screen.dart so the modal "Log a Symptom" dialog
// shows the same tailored chip row. Keys are lowercased substrings
// matched against the user's `medical_conditions` from /auth/me.
const _conditionSuggestionsModal = <String, List<String>>{
  'migraine': ['Aura', 'Photophobia', 'Phonophobia', 'Throbbing Pain', 'Nausea'],
  'adhd': ['Restlessness', 'Brain Fog', 'Focus Crash', 'Irritability'],
  'anxiety': ['Racing Heart', 'Chest Tightness', 'Restlessness', 'Shortness of Breath', 'Panic'],
  'depression': ['Fatigue', 'Low Motivation', 'Brain Fog', 'Insomnia'],
  'pcos': ['Cramps', 'Bloating', 'Acne Flare', 'Fatigue', 'Mood Swings'],
  'asthma': ['Shortness of Breath', 'Wheezing', 'Chest Tightness', 'Cough'],
  'diabetes': ['Low Blood Sugar', 'High Blood Sugar', 'Thirst', 'Blurred Vision', 'Fatigue'],
  'ibs': ['Bloating', 'Cramps', 'Diarrhea', 'Constipation', 'Stomach Pain'],
  'insomnia': ['Exhaustion', 'Brain Fog', 'Irritability', 'Headache'],
  'hypertension': ['Headache', 'Dizziness', 'Chest Tightness'],
  'dyslexia': ['Eye Strain', 'Focus Crash', 'Brain Fog'],
  'eczema': ['Skin Itch', 'Skin Flare', 'Dry Skin'],
};

const _medicationSideEffectsModal = <String, List<String>>{
  'adderall': ['Appetite Loss', 'Insomnia', 'Jitters', 'Dry Mouth'],
  'ritalin': ['Appetite Loss', 'Insomnia', 'Jitters'],
  'vyvanse': ['Appetite Loss', 'Insomnia', 'Jitters'],
  'methylphenidate': ['Appetite Loss', 'Insomnia', 'Jitters'],
  'concerta': ['Appetite Loss', 'Insomnia', 'Jitters'],
  'sertraline': ['Nausea', 'Dry Mouth', 'Drowsiness'],
  'zoloft': ['Nausea', 'Dry Mouth', 'Drowsiness'],
  'fluoxetine': ['Nausea', 'Insomnia', 'Drowsiness'],
  'prozac': ['Nausea', 'Insomnia', 'Drowsiness'],
  'escitalopram': ['Nausea', 'Drowsiness', 'Dry Mouth'],
  'lexapro': ['Nausea', 'Drowsiness', 'Dry Mouth'],
  'ibuprofen': ['Stomach Pain', 'Heartburn', 'Nausea'],
  'aspirin': ['Stomach Pain', 'Heartburn'],
  'metformin': ['Nausea', 'Diarrhea', 'Stomach Pain'],
  'birth control': ['Nausea', 'Headache', 'Mood Swings'],
  'contraceptive': ['Nausea', 'Headache', 'Mood Swings'],
  'cetirizine': ['Drowsiness', 'Dry Mouth'],
  'loratadine': ['Drowsiness', 'Dry Mouth'],
  'antihistamine': ['Drowsiness', 'Dry Mouth'],
  'xanax': ['Drowsiness', 'Brain Fog'],
  'lorazepam': ['Drowsiness', 'Brain Fog'],
  'atorvastatin': ['Muscle Pain', 'Fatigue'],
  'statin': ['Muscle Pain', 'Fatigue'],
};

const _conditionTriggersModal = <String, List<String>>{
  'migraine': ['Bright light', 'Loud noise', 'Menstruation'],
  'asthma': ['Pollen', 'Exercise', 'Cold air'],
  'ibs': ['Specific foods', 'Anxiety'],
  'anxiety': ['Deadlines', 'Exams', 'Social pressure'],
  'adhd': ['Overstimulation', 'Boredom'],
};

//  HEALTH DATA MODEL + PROVIDER
class HealthData {
  final List<Map<String, dynamic>> sleepHistory;
  final List<Map<String, dynamic>> moodHistory;
  final List<Map<String, dynamic>> medications;
  final Map<String, dynamic>? todaysSleep;
  final Map<String, dynamic>? todaysMood;
  final int waterGlasses;
  final int medicationsTakenToday;
  final double avgSleepHours;
  final double avgMoodQuality;
  final bool isLoading;
  // Insights data
  final int wellnessScore;
  final List<Map<String, dynamic>> insights;
  final Map<String, dynamic> weeklySummary;
  // Mood definitions
  final List<Map<String, dynamic>> moodDefinitions;

  const HealthData({
    this.sleepHistory = const [],
    this.moodHistory = const [],
    this.medications = const [],
    this.todaysSleep,
    this.todaysMood,
    this.waterGlasses = 0,
    this.medicationsTakenToday = 0,
    this.avgSleepHours = 0.0,
    this.avgMoodQuality = 0.0,
    this.isLoading = true,
    this.wellnessScore = 0,
    this.insights = const [],
    this.weeklySummary = const {},
    this.moodDefinitions = const [],
  });

  HealthData copyWith({
    List<Map<String, dynamic>>? sleepHistory,
    List<Map<String, dynamic>>? moodHistory,
    List<Map<String, dynamic>>? medications,
    Map<String, dynamic>? todaysSleep,
    Map<String, dynamic>? todaysMood,
    int? waterGlasses,
    int? medicationsTakenToday,
    double? avgSleepHours,
    double? avgMoodQuality,
    bool? isLoading,
    int? wellnessScore,
    List<Map<String, dynamic>>? insights,
    Map<String, dynamic>? weeklySummary,
    List<Map<String, dynamic>>? moodDefinitions,
  }) => HealthData(
    sleepHistory: sleepHistory ?? this.sleepHistory,
    moodHistory: moodHistory ?? this.moodHistory,
    medications: medications ?? this.medications,
    todaysSleep: todaysSleep ?? this.todaysSleep,
    todaysMood: todaysMood ?? this.todaysMood,
    waterGlasses: waterGlasses ?? this.waterGlasses,
    medicationsTakenToday: medicationsTakenToday ?? this.medicationsTakenToday,
    avgSleepHours: avgSleepHours ?? this.avgSleepHours,
    avgMoodQuality: avgMoodQuality ?? this.avgMoodQuality,
    isLoading: isLoading ?? this.isLoading,
    wellnessScore: wellnessScore ?? this.wellnessScore,
    insights: insights ?? this.insights,
    weeklySummary: weeklySummary ?? this.weeklySummary,
    moodDefinitions: moodDefinitions ?? this.moodDefinitions,
  );
}

class HealthNotifier extends StateNotifier<HealthData> {
  final ApiService _api;
  HealthNotifier(this._api) : super(const HealthData()) { loadAll(); }

  Future<void> loadAll() async {
    // Hydrate from local snapshot FIRST so the UI shows last-known state
    // instantly — meds, sleep, mood, wellness score, insights all restore
    // across hot restarts even when the backend is offline. Then the API
    // sync overwrites with fresh server data.
    await _loadHealthCache();
    await _syncFromApi();
  }
  Future<void> refresh() async => _syncFromApi();

  // Snapshot of every field we care about survives between sessions.
  // Stored as a single JSON blob under a fixed key; day-scoped fields
  // (water, today's mood, today's sleep, wellness) are keyed by date so
  // a new day starts fresh automatically.

  String get _dateKey {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  Future<void> _saveHealthCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final snap = <String, dynamic>{
        'date': _dateKey,
        'sleepHistory': state.sleepHistory,
        'moodHistory': state.moodHistory,
        'medications': state.medications,
        'todaysSleep': state.todaysSleep,
        'todaysMood': state.todaysMood,
        'waterGlasses': state.waterGlasses,
        'medicationsTakenToday': state.medicationsTakenToday,
        'avgSleepHours': state.avgSleepHours,
        'avgMoodQuality': state.avgMoodQuality,
        'wellnessScore': state.wellnessScore,
        'insights': state.insights,
        'weeklySummary': state.weeklySummary,
        'moodDefinitions': state.moodDefinitions,
      };
      await p.setString('health_cache', jsonEncode(snap));
      // Keep the legacy per-day water key in sync for older readers.
      await p.setInt('water_${_dateKey}', state.waterGlasses);
    } catch (_) {}
  }

  Future<void> _loadHealthCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      // Fast path: hydrate from unified JSON blob.
      final raw = p.getString('health_cache');
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final savedDate = (m['date'] ?? '') as String;
        final sameDay = savedDate == _dateKey;

        List<Map<String, dynamic>> asListOfMaps(dynamic v) {
          if (v is List) {
            return v
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
          return const [];
        }

        Map<String, dynamic>? asMap(dynamic v) =>
            v is Map ? Map<String, dynamic>.from(v) : null;

        state = HealthData(
          sleepHistory: asListOfMaps(m['sleepHistory']),
          moodHistory: asListOfMaps(m['moodHistory']),
          medications: asListOfMaps(m['medications']),
          // Day-scoped fields only restore if it's still the same day.
          todaysSleep: sameDay ? asMap(m['todaysSleep']) : null,
          todaysMood: sameDay ? asMap(m['todaysMood']) : null,
          waterGlasses: sameDay ? ((m['waterGlasses'] as int?) ?? 0) : 0,
          medicationsTakenToday:
              sameDay ? ((m['medicationsTakenToday'] as int?) ?? 0) : 0,
          avgSleepHours: (m['avgSleepHours'] as num?)?.toDouble() ?? 0.0,
          avgMoodQuality: (m['avgMoodQuality'] as num?)?.toDouble() ?? 0.0,
          isLoading: true, // API sync is about to run
          wellnessScore: sameDay ? ((m['wellnessScore'] as int?) ?? 0) : 0,
          insights: asListOfMaps(m['insights']),
          weeklySummary: asMap(m['weeklySummary']) ?? const {},
          moodDefinitions: asListOfMaps(m['moodDefinitions']),
        );
        return;
      }

      // Legacy fallback: water-only cache from earlier builds.
      final water = p.getInt('water_$_dateKey') ?? 0;
      state = state.copyWith(waterGlasses: water);
    } catch (_) {}
  }

  Future<void> _syncFromApi() async {
    try {
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Fetch sleep data (7 days)
      List<Map<String, dynamic>> sleep = [];
      double sleepSum = 0;
      try {
        final res = await _api.get('/health/sleep', queryParams: {'limit': '7'});
        if (res.data is List) {
          sleep = (res.data as List).cast<Map<String, dynamic>>();
          for (final s in sleep) {
            final hrs = (double.tryParse(s['total_hours']?.toString() ?? '0') ?? 0).clamp(0.0, 24.0);
            sleepSum += hrs;
          }
        }
      } catch (_) {}

      // "Last night's sleep" = entry dated today OR yesterday (since most
      // users log the bedtime-date which is yesterday relative to wake time).
      // Fallback: most recent entry if within the last 36 hours.
      final yesterday = now.subtract(const Duration(days: 1));
      final yday =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      Map<String, dynamic>? todaysSleep;
      for (final s in sleep) {
        final d = (s['date'] ?? '').toString();
        if (d.startsWith(today) || d.startsWith(yday)) {
          todaysSleep = s;
          break;
        }
      }
      // Fallback: use most recent if nothing matched today/yesterday
      todaysSleep ??= sleep.isNotEmpty ? sleep.first : null;

      // Fetch mood data (10 entries)
      List<Map<String, dynamic>> mood = [];
      double moodSum = 0;
      try {
        final res = await _api.get('/health/moods', queryParams: {'limit': '10'});
        if (res.data is List) {
          mood = (res.data as List).cast<Map<String, dynamic>>();
          for (final m in mood) {
            moodSum += (m['energy_level'] ?? 0) as int;
          }
        }
      } catch (_) {}

      Map<String, dynamic>? todaysMood;
      for (final m in mood) {
        if ((m['timestamp'] ?? '').toString().startsWith(today)) {
          todaysMood = m;
          break;
        }
      }

      // Fetch medications
      List<Map<String, dynamic>> meds = [];
      try {
        final res = await _api.get('/health/medications', queryParams: {'active_only': 'true'});
        if (res.data is List) {
          meds = (res.data as List).cast<Map<String, dynamic>>();
        }
      } catch (_) {}

      // Fetch today's water from API
      int waterGlasses = state.waterGlasses;
      try {
        final res = await _api.get('/health/water/today');
        if (res.data != null && res.data is Map) {
          waterGlasses = (res.data['glasses'] as int?) ?? waterGlasses;
        }
      } catch (_) {}

      // Fetch mood definitions
      List<Map<String, dynamic>> moodDefs = [];
      try {
        final res = await _api.get('/health/moods/definitions');
        if (res.data is List) {
          moodDefs = (res.data as List).cast<Map<String, dynamic>>();
        }
      } catch (_) {}

      // Fetch insights
      int wellnessScore = 0;
      List<Map<String, dynamic>> insights = [];
      Map<String, dynamic> weeklySummary = {};
      try {
        final res = await _api.get('/health/insights');
        if (res.data is Map) {
          wellnessScore = (res.data['wellness_score'] as int?) ?? 0;
          if (res.data['insights'] is List) {
            insights = (res.data['insights'] as List).cast<Map<String, dynamic>>();
          }
          if (res.data['weekly_summary'] is Map) {
            weeklySummary = Map<String, dynamic>.from(res.data['weekly_summary']);
          }
        }
      } catch (_) {}

      // Merge API results over cached state WITHOUT clobbering local data
      // when the server responds empty. Rationale: the user may have logged
      // items optimistically while offline — the POST got swallowed, the
      // server never saw it, so the authoritative sync returns an empty
      // list. We don't want that empty list to erase what the user just
      // logged locally. Non-empty responses win (server is authoritative);
      // empty responses fall back to whatever's already in state (which
      // was just hydrated from the local snapshot cache a moment ago).
      state = state.copyWith(
        sleepHistory: sleep.isNotEmpty ? sleep : state.sleepHistory,
        moodHistory: mood.isNotEmpty ? mood : state.moodHistory,
        medications: meds.isNotEmpty ? meds : state.medications,
        // Nullable fields: copyWith treats null as "no change", so passing
        // our locally-computed todaysSleep / todaysMood (which may be null
        // when the API lists were empty) already preserves cached values.
        todaysSleep: todaysSleep,
        todaysMood: todaysMood,
        waterGlasses: waterGlasses,
        avgSleepHours: sleep.isNotEmpty
            ? sleepSum / sleep.length
            : state.avgSleepHours,
        avgMoodQuality: mood.isNotEmpty
            ? (moodSum / mood.length).toDouble()
            : state.avgMoodQuality,
        isLoading: false,
        // Wellness score: prefer server value when present, otherwise keep
        // the locally-computed one (recalc from water/mood/meds/sleep).
        wellnessScore: wellnessScore > 0 ? wellnessScore : state.wellnessScore,
        insights: insights.isNotEmpty ? insights : state.insights,
        weeklySummary:
            weeklySummary.isNotEmpty ? weeklySummary : state.weeklySummary,
        moodDefinitions:
            moodDefs.isNotEmpty ? moodDefs : state.moodDefinitions,
      );
      // Refresh the locally-computed wellness score so the ring reflects
      // whatever we just merged (water + cached meds/sleep/mood, etc.).
      if (wellnessScore == 0) _recalcWellnessLocally();
      await _saveHealthCache();
    } catch (_) {
      // Network/auth blew up entirely — keep the cache-hydrated state and
      // just mark loading done. The snapshot we loaded before this call
      // still holds everything the user logged earlier.
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> incrementWater() async {
    final newVal = (state.waterGlasses + 1).clamp(0, 8);
    state = state.copyWith(waterGlasses: newVal);
    _recalcWellnessLocally();
    await _saveHealthCache();
    try { await _api.post('/health/water', data: {'glasses': newVal}); } catch (_) {}
  }

  Future<void> decrementWater() async {
    final newVal = (state.waterGlasses - 1).clamp(0, 8);
    state = state.copyWith(waterGlasses: newVal);
    _recalcWellnessLocally();
    await _saveHealthCache();
    try { await _api.post('/health/water', data: {'glasses': newVal}); } catch (_) {}
  }

  /// Local wellness recompute — gives instant ring feedback before backend
  /// returns its own canonical score. 4 categories × 25 points each.
  ///   • water:  glasses / 8 × 25
  ///   • mood:   any mood logged today  → 25
  ///   • meds:   taken / total × 25  (or 25 if no meds tracked)
  ///   • sleep:  last night hours, ramps 0h→0pts, 8h→25pts
  void _recalcWellnessLocally() {
    final waterPts = ((state.waterGlasses / 8.0) * 25).clamp(0.0, 25.0);
    final moodPts  = state.todaysMood != null ? 25.0 : 0.0;
    final medsPts  = state.medications.isEmpty
        ? 25.0
        : ((state.medicationsTakenToday / state.medications.length) * 25)
            .clamp(0.0, 25.0);
    final sleepHrs = state.todaysSleep != null
        ? (double.tryParse(state.todaysSleep!['total_hours']?.toString() ?? '0') ?? 0)
        : state.avgSleepHours;
    final sleepPts = ((sleepHrs / 8.0) * 25).clamp(0.0, 25.0);
    final score = (waterPts + moodPts + medsPts + sleepPts).round().clamp(0, 100);
    state = state.copyWith(wellnessScore: score);
  }

  Future<void> logMedication(String medId) async {
    // Optimistic: mark med taken locally + bump wellness ring
    final updated = state.medications.map((m) {
      if ((m['id'] ?? '').toString() == medId) {
        return {...m, 'taken_today': true};
      }
      return m;
    }).toList();
    final takenCount = updated.where((m) => m['taken_today'] == true).length;
    state = state.copyWith(
      medications: updated, medicationsTakenToday: takenCount);
    _recalcWellnessLocally();
    await _saveHealthCache();
    // Fire-and-forget POST — do NOT re-sync after, so the optimistic state
    // survives even if the backend endpoint is flaky. Pull-to-refresh will
    // reconcile on demand.
    try {
      await _api.post('/health/medications/log', data: {
        'medication_id': medId,
        'scheduled_time': DateTime.now().toIso8601String(),
        'status': 'taken',
        'taken_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> skipMedication(String medId) async {
    try {
      await _api.post('/health/medications/log', data: {
        'medication_id': medId,
        'scheduled_time': DateTime.now().toIso8601String(),
        'status': 'skipped',
      });
    } catch (_) {}
  }

  Future<void> logMood(String moodId, {String? displayName}) async {
    // Optimistic: set todaysMood locally so the ring + pill update instantly
    final name = displayName ??
        (state.moodDefinitions.firstWhere(
              (d) => (d['id'] ?? '').toString() == moodId,
              orElse: () => <String, dynamic>{'name': moodId},
            )['name'] ??
            moodId);
    state = state.copyWith(
      todaysMood: {'mood_id': moodId, 'mood_name': name},
    );
    _recalcWellnessLocally();
    await _saveHealthCache();
    // Fire-and-forget POST — trust optimistic mood
    try {
      await _api.post('/health/moods', data: {
        'mood_id': moodId,
      });
    } catch (_) {}
  }

  Future<void> logMoodDetailed(String moodId, int energy, List<String> tags, String note) async {
    // Optimistic todaysMood + wellness bump
    final name = state.moodDefinitions.firstWhere(
      (d) => (d['id'] ?? '').toString() == moodId,
      orElse: () => <String, dynamic>{'name': moodId},
    )['name'] ?? moodId;
    state = state.copyWith(
      todaysMood: {'mood_id': moodId, 'mood_name': name, 'energy_level': energy},
    );
    _recalcWellnessLocally();
    await _saveHealthCache();
    // Fire-and-forget POST — trust optimistic mood
    try {
      await _api.post('/health/moods', data: {
        'mood_id': moodId,
        'energy_level': energy,
        'context_tags': tags,
        'note': note,
      });
    } catch (_) {}
  }

  Future<void> logSleep(String dateStr, String bedtime, String wakeTime, int quality, String notes) async {
    // Optimistic: compute total hours + set todaysSleep immediately so the
    // "Last night" card + weekly-sleep chart update without waiting on API.
    try {
      final bed = DateTime.parse(bedtime);
      final wake = DateTime.parse(wakeTime);
      final hours = wake.difference(bed).inMinutes / 60.0;
      final newEntry = <String, dynamic>{
        'date': dateStr,
        'bedtime': bedtime,
        'wake_time': wakeTime,
        'total_hours': hours.toStringAsFixed(2),
        'quality_rating': quality,
        'notes': notes,
      };
      final history = [newEntry, ...state.sleepHistory];
      if (history.length > 7) history.removeRange(7, history.length);
      final total = history.fold<double>(0, (sum, s) =>
          sum + (double.tryParse(s['total_hours']?.toString() ?? '0') ?? 0));
      state = state.copyWith(
        sleepHistory: history,
        todaysSleep: newEntry,
        avgSleepHours: history.isEmpty ? 0.0 : total / history.length,
      );
      _recalcWellnessLocally();
      await _saveHealthCache();
    } catch (_) {}
    // Fire-and-forget POST — trust optimistic sleep entry
    try {
      await _api.post('/health/sleep', data: {
        'date': dateStr,
        'bedtime': bedtime,
        'wake_time': wakeTime,
        'quality_rating': quality,
        'notes': notes,
      });
    } catch (_) {}
  }

  Future<void> addMedication(String name, String dosage, String frequency) async {
    // Optimistic: push new med to local list so it appears instantly.
    final tempId = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    final newMed = <String, dynamic>{
      'id': tempId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'reminder_enabled': true,
      'taken_today': false,
      'is_active': true,
    };
    state = state.copyWith(
      medications: [...state.medications, newMed],
    );
    _recalcWellnessLocally();
    await _saveHealthCache();
    // Fire-and-forget POST — the optimistic med with its tmp_ id is reliable
    // enough to display. If the backend returns a canonical id on next manual
    // refresh, the tmp_ entry will be replaced then.
    try {
      await _api.post('/health/medications', data: {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'reminder_enabled': true,
      });
    } catch (_) {}
  }

  Future<void> logSymptom(String type, int intensity, List<String> triggers) async {
    try {
      await _api.post('/health/symptoms', data: {
        'symptom_type': type,
        'intensity': intensity,
        'triggers': triggers,
      });
    } catch (_) {}
  }
}

final healthProvider = StateNotifierProvider<HealthNotifier, HealthData>((ref) {
  return HealthNotifier(ref.watch(apiServiceProvider));
});

//  HEALTH TAB WIDGET
class HealthTab extends ConsumerStatefulWidget {
  const HealthTab({super.key});
  @override ConsumerState<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends ConsumerState<HealthTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  bool _insightsOpen = false;

  // Loaded once in initState from /auth/me + /health/medications.
  // The Log-a-Symptom modal reads these to surface tailored chips.
  List<String> _userConditions = [];
  List<String> _userMedications = [];
  List<String> _suggestedSymptoms = [];
  List<String> _extraTriggers = [];

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPersonalization());
  }

  /// Pull the user's medical conditions + medications and derive
  /// the symptom / trigger suggestion lists. Best-effort — failures
  /// just leave the lists empty so the modal falls back to defaults.
  Future<void> _loadPersonalization() async {
    try {
      final api = ref.read(apiServiceProvider);
      List<String> conds = [];
      List<String> meds = [];
      try {
        final meRes = await api.get('/auth/me');
        final me = Map<String, dynamic>.from(meRes.data ?? {});
        conds = List<String>.from(me['medical_conditions'] ?? const []);
      } catch (_) {}
      try {
        final medsRes = await api.get('/health/medications');
        final list = List<dynamic>.from(medsRes.data ?? const []);
        meds = list
            .map((m) => (m['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
      } catch (_) {}

      final suggested = <String>[];
      void addAll(Iterable<String> xs) {
        for (final s in xs) { if (!suggested.contains(s)) suggested.add(s); }
      }
      for (final raw in conds) {
        final key = raw.toLowerCase().trim();
        _conditionSuggestionsModal.forEach((k, v) {
          if (key.contains(k)) addAll(v);
        });
      }
      for (final raw in meds) {
        final key = raw.toLowerCase().trim();
        _medicationSideEffectsModal.forEach((k, v) {
          if (key.contains(k)) addAll(v);
        });
      }

      final extraTrig = <String>[];
      for (final raw in conds) {
        final key = raw.toLowerCase().trim();
        _conditionTriggersModal.forEach((k, v) {
          if (key.contains(k)) {
            for (final t in v) { if (!extraTrig.contains(t)) extraTrig.add(t); }
          }
        });
      }

      if (mounted) {
        setState(() {
          _userConditions = conds;
          _userMedications = meds;
          _suggestedSymptoms = suggested.length > 8 ? suggested.sublist(0, 8) : suggested;
          _extraTriggers = extraTrig;
        });
      }
    } catch (_) {/* silent — personalisation is optional */}
  }

  int? _prevTab;

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // Stagger helper — fades + slides a child in as _enterCtrl advances.
  Widget _stag(double delay, Widget child) {
    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(
          ((_enterCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
        return Opacity(opacity: t, child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)), child: child));
      },
    );
  }

  //  BUILD — dispatches to desktop (>900px) or narrow layout
  @override
  Widget build(BuildContext context) {
    // NOTE: No auto-refresh on tab switch — it was overwriting the optimistic
    // state (sleep/meds) that users just added, making it look like nothing
    // was logged when they came back to this tab. Users can pull-to-refresh
    // on the narrow layout if they want to re-sync with the backend.
    final currentTab = ref.watch(selectedTabProvider);
    _prevTab = currentTab;

    final h = ref.watch(healthProvider);
    final dash = ref.watch(dashboardProvider);
    final avatarConfig = dash.avatarConfig;

    return Stack(fit: StackFit.expand, children: [
      // Pawprint ombré background (fills full screen incl. under nav)
      Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_ombre1, _ombre2, _ombre3, _ombre4],
          stops: [0.0, 0.3, 0.6, 1.0],
        )),
      ),
      CustomPaint(painter: _PawPrintBg()),

      SafeArea(
        bottom: false,
        child: h.isLoading
          ? const Center(child: CircularProgressIndicator(color: _coralHdr))
          : LayoutBuilder(
              builder: (ctx, c) {
                final isDesktop = c.maxWidth > 900;
                if (isDesktop) {
                  return _buildDesktopLayout(h, dash, avatarConfig, c);
                }
                return _buildNarrowLayout(h, dash, avatarConfig, c);
              },
            ),
      ),
    ]);
  }

  //  DESKTOP LAYOUT
  //  Column { Hero, Mood strip (full width), Two columns }
  //  Mood gets the full-width slot now (was water) — water moves into the
  //  left column above the meds card so the meds card has more vertical
  //  room to fit 4+ entries without scrolling.
  Widget _buildDesktopLayout(
      HealthData h, DashboardState dash, AvatarConfig? avatar,
      BoxConstraints c) {
    final hPad = c.maxWidth > 1280 ? 80.0
              : c.maxWidth > 1024 ? 60.0
              : 40.0;
    // Tighter hero so the mood strip + 2-col area get breathing room
    final heroH = math.max(c.maxHeight * 0.26, 210.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HERO — Stack: back+title (top-left), pills (top-right), wellness card (centered)
        SizedBox(
          height: heroH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(top: 20, left: hPad,
                child: _stag(0.00, _buildHeroTop())),
              Positioned(top: 20, right: hPad,
                child: _stag(0.00, _buildHeroPills(h, dash))),
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0.0, 0.30),
                  child: _stag(0.06, _buildWellnessCard(h)),
                ),
              ),
            ],
          ),
        ),
        // CONTENT — fills remaining viewport (100px bottom clears olive nav)
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // MOOD STRIP — full width horizontal, all 8 moods in one row
                _stag(0.08, _buildMoodStrip(h, avatar)),
                const SizedBox(height: 14),
                // 2-COLUMN ROW — Water+Meds (left) | Sleep+Insights+Footer (right)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 45,
                        child: _stag(0.12,
                          _buildLeftColumnDesktop(h, avatar))),
                      const SizedBox(width: 24),
                      Expanded(flex: 55,
                        child: _stag(0.16, _buildRightColumnDesktop(h))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  //  NARROW LAYOUT — stacked scrollable fallback for phone/tablet
  Widget _buildNarrowLayout(
      HealthData h, DashboardState dash, AvatarConfig? avatar,
      BoxConstraints c) {
    return RefreshIndicator(
      color: _outline, backgroundColor: _cardFill,
      onRefresh: () async {
        await ref.read(healthProvider.notifier).refresh();
        await ref.read(dashboardProvider.notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stag(0.00, _buildNarrowHeader(h, dash)),
              const SizedBox(height: 16),
              _stag(0.04, _buildWellnessCardWide(h)),
              const SizedBox(height: 18),
              _stag(0.08, _buildMoodSection(h, avatar)),
              const SizedBox(height: 18),
              _stag(0.10, SizedBox(
                height: 220,
                child: _buildVitalsRow(h),
              )),
              const SizedBox(height: 14),
              _stag(0.12, _buildMedsCard(h, expanded: false)),
              const SizedBox(height: 14),
              _stag(0.14, SizedBox(
                height: 220,
                child: _buildInsightsCard(h),
              )),
              const SizedBox(height: 10),
              _stag(0.16, _buildSymptomTeaser()),
              const SizedBox(height: 10),
              _stag(0.18, _buildSleepTeaser(h)),
              const SizedBox(height: 10),
              _stag(0.20, _buildTipCard(h)),
              const SizedBox(height: 10),
              _stag(0.22, _buildHistoryButton()),
            ],
          ),
        ),
      ),
    );
  }

  //  HERO TOP (left) — back btn + page title.  Mirrors .hero-top
  Widget _buildHeroTop() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _backButton(),
      const SizedBox(width: 10),
      const Text('Health Hub', style: TextStyle(
        fontFamily: 'Bitroad', fontSize: 26, color: _brown)),
    ]);
  }

  // Back button (matches study_tab back button)
  Widget _backButton() {
    return GestureDetector(
      onTap: () => ref.read(selectedTabProvider.notifier).state = 0,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(0.28),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: const Icon(Icons.chevron_left_rounded, size: 20, color: _outline),
      ),
    );
  }

  //  HERO PILLS (right) — Wellness / Mood / Streak
  //  Mirrors .hero-pills in HTML
  Widget _buildHeroPills(HealthData h, DashboardState dash) {
    final moodName = h.todaysMood?['mood_name']?.toString() ?? 'Log mood';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _HealthPill(
        icon: Icons.favorite_rounded,
        label: '${h.wellnessScore} Wellness',
        bg: _olive.withOpacity(0.5),
      ),
      const SizedBox(width: 7),
      _HealthPill(
        icon: Icons.sentiment_satisfied_rounded,
        label: moodName,
        bg: const Color(0xFFF7AEAE),
      ),
      const SizedBox(width: 7),
      _HealthPill(
        icon: Icons.bolt_rounded,
        label: '${dash.streak}',
        bg: _orange,
      ),
    ]);
  }

  //  NARROW HEADER — single row with back + title + pills
  Widget _buildNarrowHeader(HealthData h, DashboardState dash) {
    return Row(children: [
      _backButton(),
      const SizedBox(width: 10),
      const Expanded(child: Text('Health Hub', style: TextStyle(
        fontFamily: 'Bitroad', fontSize: 24, color: _brown))),
      _HealthPill(
        icon: Icons.favorite_rounded,
        label: '${h.wellnessScore}',
        bg: _olive.withOpacity(0.5),
      ),
      const SizedBox(width: 6),
      _HealthPill(
        icon: Icons.bolt_rounded,
        label: '${dash.streak}',
        bg: _orange,
      ),
    ]);
  }

  //  WELLNESS CARD — ring + title + msg + 3 stats (horizontal)
  //  Hero-centered on desktop
  Widget _buildWellnessCard(HealthData h) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 22, 16),
        decoration: BoxDecoration(
          // Cream, not stark white — hero still reads as a paper card against
          // the ombré background but stops shouting "WHITE BOX".
          color: _cardFill,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _outline.withOpacity(0.18),
              offset: const Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildWellnessRing(h),
            const SizedBox(width: 18),
            Flexible(child: _buildWellnessText(h)),
          ],
        ),
      ),
    );
  }

  // Wider variant used in the narrow scrolling layout
  Widget _buildWellnessCardWide(HealthData h) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.18), width: 1),
      ),
      child: Row(children: [
        _buildWellnessRing(h),
        const SizedBox(width: 18),
        Expanded(child: _buildWellnessText(h)),
      ]),
    );
  }

  // Ring — uses existing _WellnessRingPainter (KEPT)
  Widget _buildWellnessRing(HealthData h) {
    return SizedBox(
      width: 108, height: 108,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: h.wellnessScore / 100.0),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (_, value, child) => CustomPaint(
          painter: _WellnessRingPainter(value, h.wellnessScore),
          child: child,
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${h.wellnessScore}', style: GoogleFonts.gaegu(
              fontSize: 34, fontWeight: FontWeight.w700,
              color: _brown, height: 1.0)),
            Text('WELLNESS', style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 0.8, color: _inkSoft)),
          ]),
        ),
      ),
    );
  }

  // Wellness title + message + 3 stat chips
  Widget _buildWellnessText(HealthData h) {
    final sleepH = h.avgSleepHours > 0
      ? '${h.avgSleepHours.toStringAsFixed(1)}h avg'
      : '— sleep';
    final medPct = (h.weeklySummary['med_adherence_pct'] is num)
      ? (h.weeklySummary['med_adherence_pct'] as num).round()
      : 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Health Today', style: GoogleFonts.gaegu(
          fontSize: 26, fontWeight: FontWeight.w700,
          color: _brown, height: 1.1)),
        const SizedBox(height: 4),
        Text(_wellnessMessage(h.wellnessScore),
          style: GoogleFonts.nunito(fontSize: 13, color: _inkSoft, height: 1.4),
          maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _wellnessStat(
            Icons.nightlight_round, sleepH,
            bg: _pinkLt.withOpacity(0.40), iconColor: _pinkDk),
          _wellnessStat(
            Icons.water_drop_rounded, '${h.waterGlasses} / 8',
            bg: _blueLt.withOpacity(0.50), iconColor: _outline),
          if (h.medications.isNotEmpty)
            _wellnessStat(
              Icons.medication_rounded, '$medPct% meds',
              bg: const Color(0xFFF7AEAE).withOpacity(0.25),
              iconColor: _outline),
        ]),
      ],
    );
  }

  // One stat chip (ws-sleep / ws-water / ws-meds)
  Widget _wellnessStat(IconData icon, String label,
      {required Color bg, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _outline.withOpacity(0.08), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: iconColor),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.nunito(
          fontSize: 11, fontWeight: FontWeight.w700, color: _brown)),
      ]),
    );
  }

  String _wellnessMessage(int score) {
    if (score >= 80) return "You're doing amazing! Keep up the great habits.";
    if (score >= 60) return "Pretty good! A little more sleep or water could push you higher.";
    if (score >= 40) return "Room for improvement — log your activities to boost your score!";
    return "Let's get you feeling better. Start with one healthy action today.";
  }

  //  SECTION TITLE helper — matches .sec-t
  Widget _sectionTitle(String label, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(children: [
        Icon(icon, size: 16, color: _oliveDk),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(
          fontFamily: 'Bitroad', fontSize: 16, color: _brown)),
        if (trailing != null) ...[const Spacer(), trailing],
      ]),
    );
  }

  //  LEFT COLUMN (desktop) — Water (compact) + Meds (expanded)
  //  Water moved here from top strip so meds gets the majority of
  //  the vertical real estate — it can now show 4 meds without
  //  scrolling. Water is capped at ~110px so it doesn't dominate.
  Widget _buildLeftColumnDesktop(HealthData h, AvatarConfig? avatar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Compact horizontal water card — only ~100px tall
        SizedBox(height: 100, child: _buildWaterStripCompact(h)),
        const SizedBox(height: 12),
        Expanded(child: _buildMedsCard(h, expanded: true)),
      ],
    );
  }

  //  RIGHT COLUMN (desktop) — Weekly Sleep + Insights + 3-up footer
  //  Water was moved to its own full-width strip above the columns
  //  so the two illustration-heavy elements (mood + water) don't clash.
  Widget _buildRightColumnDesktop(HealthData h) {
    // Use Column with Expanded children instead of SingleChildScrollView so
    // all elements auto-fit the available viewport height — no scrolling
    // needed, insights are always fully visible.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Weekly sleep chart — fixed compact height
        SizedBox(height: 152, child: _buildWeeklySleepCard(h)),
        const SizedBox(height: 10),
        // Insights — absorbs remaining space so all rows render
        Expanded(child: _buildInsightsCard(h)),
        const SizedBox(height: 10),
        // Compact 3-up footer — Symptom · Sleep · Tip (smaller)
        SizedBox(
          height: 68,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildCompactAction(
                title: 'Feeling off?',
                subtitle: 'Log symptom',
                icon: Icons.favorite_rounded,
                bg: const Color(0xFFF7AEAE).withOpacity(0.40),
                iconBg: const Color(0xFFF7AEAE).withOpacity(0.65),
                iconColor: _brownLt,
                onTap: _showSymptomSheet,
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildCompactAction(
                title: 'Log Sleep',
                subtitle: h.todaysSleep == null
                    ? 'Tap last night'
                    : '${(double.tryParse(h.todaysSleep!['total_hours']?.toString() ?? '0') ?? 0).toStringAsFixed(1)}h logged',
                icon: Icons.nightlight_round,
                bg: _blueLt.withOpacity(0.45),
                iconBg: _blueLt.withOpacity(0.7),
                iconColor: _brownLt,
                onTap: _showSleepSheet,
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildCompactTip(h)),
            ],
          ),
        ),
      ],
    );
  }

  // Compact 3-up footer card (Symptom / Sleep)
  Widget _buildCompactAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bg,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.18), width: 1.5),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(0.14),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outline.withOpacity(0.2), width: 1.5),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w800, color: _brown),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(subtitle, style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w600, color: _inkSoft),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
    );
  }

  // Compact tip card (3-up footer slot)
  Widget _buildCompactTip(HealthData h) {
    String msg; IconData ic;
    if (h.waterGlasses < 4) {
      msg = 'Hydrate · ${8 - h.waterGlasses} more glasses';
      ic = Icons.water_drop_rounded;
    } else if (h.avgSleepHours > 0 && h.avgSleepHours < 7) {
      msg = 'Try a 10-min evening stretch';
      ic = Icons.self_improvement_rounded;
    } else if (h.wellnessScore >= 80) {
      msg = "You're crushing it — keep going!";
      ic = Icons.celebration_rounded;
    } else {
      msg = 'Small steps add up — log mood today';
      ic = Icons.lightbulb_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _pinkLt.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline.withOpacity(0.18), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.14),
          offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.3), width: 1.5),
          ),
          child: Icon(ic, size: 13, color: _pinkDk),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.gaegu(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: _brown, height: 1.25),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  //  MOOD STRIP (desktop) — full-width horizontal row of 8 moods
  //  Lives at the top of the content area (swapped with water). Left
  //  side shows an aproachable title + "logged!" chip; right side is
  //  a single row of 8 _MoodButton stickers.
  Widget _buildMoodStrip(HealthData h, AvatarConfig? avatar) {
    final defs = h.moodDefinitions;
    final hasMood = h.todaysMood != null;
    final moodName = h.todaysMood?['mood_name']?.toString() ?? '';
    const order = ['Happy','Calm','Excited','Focused','Tired','Sad','Anxious','Angry'];
    final moods = <Map<String, dynamic>>[];
    for (final n in order) {
      final found = defs.firstWhere(
        (d) => ((d['name'] as String?) ?? '').toLowerCase() == n.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) moods.add(found);
      else moods.add({'id': n.toLowerCase(), 'name': n});
    }
    final eight = moods.take(8).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        // Soft blush pink — ties into the pink ombré page bg + the pink
        // hero/insights cards instead of the previous brown champagne which
        // felt out of place. Slightly more saturated than the page bg so
        // the strip still reads as its own "mood mat".
        color: const Color(0xFFFCDDE2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title column
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Icon(Icons.sentiment_satisfied_rounded,
                    size: 18, color: _oliveDk),
                  const SizedBox(width: 7),
                  const Text('Mood', style: TextStyle(
                    fontFamily: 'Bitroad', fontSize: 18, color: _brown)),
                ]),
                const SizedBox(height: 3),
                if (hasMood)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      // Soft white chip pops nicely against the pink mat.
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _outline.withOpacity(0.28), width: 1),
                    ),
                    child: Text('$moodName · logged',
                      style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w800, color: _brown)),
                  )
                else
                  Text('How are you?',
                    style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _brownLt)),
              ],
            ),
          ),
          // 8 horizontal mood buttons
          Expanded(
            child: Row(
              children: [
                for (int i = 0; i < eight.length; i++) ...[
                  if (i != 0) const SizedBox(width: 7),
                  Expanded(child: _MoodButton(
                    name: (eight[i]['name'] as String?) ?? '',
                    avatar: avatar,
                    active: moodName.toLowerCase() ==
                      ((eight[i]['name'] as String?) ?? '').toLowerCase(),
                    onTap: () => _onMoodTap(
                      (eight[i]['id'] as String?) ?? '',
                      (eight[i]['name'] as String?) ?? ''),
                    onLongPress: () => _showMoodDetailSheet(
                      (eight[i]['id'] as String?) ?? '',
                      (eight[i]['name'] as String?) ?? ''),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  //  COMPACT WATER STRIP (desktop left column)
  //  Sits above the meds card — small 8-cup horizontal row so meds has
  //  the majority of the column height.
  Widget _buildWaterStripCompact(HealthData h) {
    final filled = h.waterGlasses;
    final goalMet = filled >= 8;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.water_drop_rounded, size: 15, color: _oliveDk),
            const SizedBox(width: 6),
            const Text('Water', style: TextStyle(
              fontFamily: 'Bitroad', fontSize: 14, color: _brown)),
            const Spacer(),
            Text('$filled / 8', style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w800, color: _inkSoft)),
            if (goalMet) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _olive.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _olive.withOpacity(0.4), width: 1),
                ),
                child: Text('✓ goal',
                  style: GoogleFonts.nunito(
                    fontSize: 9, fontWeight: FontWeight.w800, color: _oliveDk)),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          // 8 horizontal smaller cups
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(8, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _waterCupTap(i, filled, compact: true),
              )),
            ),
          ),
        ],
      ),
    );
  }

  //  MOOD SECTION — 4x2 grid of coloured mood buttons
  //  Uses existing MoodSticker widget for faces (HTML styling outside)
  //  Used by the NARROW layout only; desktop now uses _buildMoodStrip.
  Widget _buildMoodSection(HealthData h, AvatarConfig? avatar) {
    final defs = h.moodDefinitions;
    final hasMood = h.todaysMood != null;
    final moodName = h.todaysMood?['mood_name']?.toString() ?? '';

    // 8-preset fallback order (matches HTML)
    const order = ['Happy','Calm','Excited','Focused','Tired','Sad','Anxious','Angry'];

    // Build list of up to 8 moods — prefer backend defs, fall back to order
    final moods = <Map<String, dynamic>>[];
    for (final n in order) {
      final found = defs.firstWhere(
        (d) => ((d['name'] as String?) ?? '').toLowerCase() == n.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) moods.add(found);
      else moods.add({'id': n.toLowerCase(), 'name': n});
    }
    final eight = moods.take(8).toList();

    Widget row(int start) {
      return Row(children: [
        for (int i = start; i < start + 4 && i < eight.length; i++) ...[
          if (i != start) const SizedBox(width: 8),
          Expanded(child: _MoodButton(
            name: (eight[i]['name'] as String?) ?? '',
            avatar: avatar,
            active: moodName.toLowerCase() ==
              ((eight[i]['name'] as String?) ?? '').toLowerCase(),
            onTap: () => _onMoodTap(
              (eight[i]['id'] as String?) ?? '',
              (eight[i]['name'] as String?) ?? ''),
            onLongPress: () => _showMoodDetailSheet(
              (eight[i]['id'] as String?) ?? '',
              (eight[i]['name'] as String?) ?? ''),
          )),
        ],
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Mood Check-In', Icons.sentiment_satisfied_rounded,
          trailing: hasMood
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _goldWarm.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _outline.withOpacity(0.3), width: 1.5),
                  boxShadow: [BoxShadow(
                    color: _outline.withOpacity(0.2),
                    offset: const Offset(1, 1), blurRadius: 0)],
                ),
                child: Text('Logged!', style: GoogleFonts.nunito(
                  fontSize: 10, fontWeight: FontWeight.w700, color: _brown)))
            : null,
        ),
        row(0),
        const SizedBox(height: 8),
        row(4),
      ],
    );
  }

  void _handleMedTake(Map<String, dynamic> med) {
    final wasTaken = med['taken_today'] == true;
    final id = (med['id'] ?? '').toString();
    ref.read(healthProvider.notifier).logMedication(id);
    if (!wasTaken) {
      ref.read(dashboardProvider.notifier).awardXp(AppConstants.xpPerMedication);
    }
  }

  void _onMoodTap(String moodId, String name) {
    // Only skip XP if user taps the EXACT same mood they already have.
    // Different mood = legit update = award XP.
    final prevMood = ref.read(healthProvider).todaysMood;
    final prevMoodId = (prevMood?['mood_id'] ?? '').toString();
    final sameMood = prevMoodId == moodId;
    ref.read(healthProvider.notifier).logMood(moodId, displayName: name);
    // Sync mood to dashboard so it shows on the home screen too
    ref.read(dashboardProvider.notifier).setMoodLocally(name);
    if (!sameMood) {
      ref.read(dashboardProvider.notifier).awardXp(AppConstants.xpPerMoodLog);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _goldLt,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _goldDk.withOpacity(0.3), width: 2)),
      content: Text(
        sameMood
            ? 'Feeling $name — logged!'
            : 'Feeling $name — +${AppConstants.xpPerMoodLog} XP!',
        style: GoogleFonts.gaegu(
          fontWeight: FontWeight.w700, color: _brown, fontSize: 15)),
      duration: const Duration(seconds: 2),
    ));
  }

  //  VITALS ROW (narrow layout only) — Water + Weekly Sleep
  //  Desktop layout now splits these into separate strips.
  Widget _buildVitalsRow(HealthData h) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildWaterCard(h)),
        const SizedBox(width: 10),
        Expanded(child: _buildWeeklySleepCard(h)),
      ],
    );
  }

  // (Old full-width _buildWaterStrip removed — water now lives in the
  //  left column via _buildWaterStripCompact, and mood took its slot.)

  // Water card — 4×2 grid of _WaterGlass (existing widget)
  Widget _buildWaterCard(HealthData h) {
    final filled = h.waterGlasses;
    final goalMet = filled >= 8;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        // Warm cream instead of pure white — cuts the "too many white boxes" feel
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.water_drop_rounded, size: 16, color: _oliveDk),
            const SizedBox(width: 7),
            const Text('Water', style: TextStyle(
              fontFamily: 'Bitroad', fontSize: 15, color: _brown)),
            const Spacer(),
            Text('$filled / 8', style: GoogleFonts.nunito(
              fontSize: 11, fontWeight: FontWeight.w700, color: _inkSoft)),
          ]),
          const SizedBox(height: 8),
          Expanded(child: _buildWaterCupsGrid(filled)),
          if (goalMet) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _olive.withOpacity(0.2),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _olive.withOpacity(0.38), width: 1),
              ),
              child: Text('✓ Daily goal reached!', style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w700, color: _oliveDk)),
            ),
          ],
        ],
      ),
    );
  }

  // 4x2 grid of existing _WaterGlass widgets
  Widget _buildWaterCupsGrid(int filled) {
    return LayoutBuilder(builder: (ctx, c) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => _waterCupTap(i, filled))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => _waterCupTap(i + 4, filled))),
        ],
      );
    });
  }

  Widget _waterCupTap(int i, int filled, {bool compact = false}) {
    return _WaterGlass(
      filled: i < filled,
      index: i,
      compact: compact,
      onTap: () {
        if (i < filled) {
          final target = i;
          for (int j = filled; j > target; j--) {
            ref.read(healthProvider.notifier).decrementWater();
          }
        } else {
          // Award 1 XP per fresh glass filled (capped at 8 glasses/day)
          final newGlasses = (i + 1) - filled;
          if (newGlasses > 0) {
            ref.read(dashboardProvider.notifier).awardXp(newGlasses);
          }
          for (int j = filled; j <= i; j++) {
            ref.read(healthProvider.notifier).incrementWater();
          }
        }
      },
    );
  }

  // Weekly Sleep card — avg + bars chart
  Widget _buildWeeklySleepCard(HealthData h) {
    final lastNight = h.todaysSleep;
    final lastH = double.tryParse(
      lastNight?['total_hours']?.toString() ?? '0') ?? 0;
    final daysTracked = (h.weeklySummary['days_tracked'] as int?) ??
        h.sleepHistory.where((s) {
          final hrs = double.tryParse(s['total_hours']?.toString() ?? '0') ?? 0;
          return hrs > 0;
        }).length;
    final hasAnySleep = daysTracked > 0;
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(children: [
              Text(
                hasAnySleep ? '${h.avgSleepHours.toStringAsFixed(1)}h' : '— h',
                style: const TextStyle(
                  fontFamily: 'Bitroad', fontSize: 20, color: _brown)),
              const SizedBox(width: 6),
              Text('avg', style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w700, color: _olive)),
              const Spacer(),
              if (lastH > 0) _sleepBadge(lastH),
            ]),
          ),
          Divider(height: 1, color: _outline.withOpacity(0.08)),
          Expanded(
            child: hasAnySleep
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    child: _buildSleepBars(h),
                  )
                : _buildEmptySleepState(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              '$daysTracked of 7 days tracked',
              style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w700, color: _inkSoft)),
          ),
        ],
      ),
    );
  }

  // Friendly empty state when no sleep has been logged yet this week
  Widget _buildEmptySleepState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bedtime_outlined,
              size: 26, color: _purpleHdr.withOpacity(0.7)),
          const SizedBox(height: 4),
          Text('No sleep logged yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.gaegu(
                fontSize: 13, fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: _showSleepSheet,
            child: Text('Tap to log last night ›',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _purpleHdr,
                  decoration: TextDecoration.underline,
                  decorationColor: _purpleHdr.withOpacity(0.5))),
          ),
        ],
      ),
    );
  }

  // Sleep bars — 7 bars, colour by hours range
  Widget _buildSleepBars(HealthData h) {
    // Build a 7-day array of hours (latest last / Sun)
    final hrs = List<double>.filled(7, 0);
    for (int i = 0; i < h.sleepHistory.length && i < 7; i++) {
      final v = double.tryParse(
        h.sleepHistory[i]['total_hours']?.toString() ?? '0') ?? 0;
      hrs[6 - i] = v;
    }
    final maxH = hrs.fold<double>(0, (a, b) => b > a ? b : a);
    const days = ['M','T','W','T','F','S','S'];
    final today = DateTime.now().weekday - 1;

    return LayoutBuilder(builder: (ctx, c) {
      const labelSpace = 18.0;
      final avail = (c.maxHeight - labelSpace).clamp(30.0, 500.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final v = hrs[i];
          final h01 = maxH > 0 ? (v / maxH).clamp(0.0, 1.0) : 0.0;
          final bh = (h01 * avail).clamp(v > 0 ? 5.0 : 3.0, avail);
          final isToday = i == today;
          List<Color> colors;
          if (v == 0) colors = [_outline.withOpacity(0.12), _outline.withOpacity(0.2)];
          else if (v >= 7 && v <= 9) colors = [_olive.withOpacity(0.4), _olive];
          else if (v >= 5) colors = [_goldWarm.withOpacity(0.5), _goldWarm];
          else colors = [const Color(0xFFF7AEAE).withOpacity(0.5), const Color(0xFFF7AEAE)];

          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: avail,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    height: bh,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: colors),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4), bottom: Radius.circular(2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(days[i], style: GoogleFonts.nunito(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: isToday ? _brown : _inkSoft)),
            ]),
          ));
        }),
      );
    });
  }

  Widget _sleepBadge(double hours) {
    Color bg, bd;
    if (hours >= 7 && hours <= 9) {
      bg = _olive.withOpacity(0.22); bd = _olive.withOpacity(0.4);
    } else if (hours >= 5) {
      bg = _goldWarm.withOpacity(0.3); bd = _goldWarm.withOpacity(0.5);
    } else {
      bg = const Color(0xFFF7AEAE).withOpacity(0.35);
      bd = const Color(0xFFF7AEAE).withOpacity(0.6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bd, width: 1.5),
      ),
      child: Text('${hours.toStringAsFixed(1)}h', style: GoogleFonts.nunito(
        fontSize: 11, fontWeight: FontWeight.w800, color: _brown)),
    );
  }

  //  MEDS CARD — .meds-wrap, scrollable list + add button
  Widget _buildMedsCard(HealthData h, {bool expanded = false}) {
    final done = h.medicationsTakenToday;
    final total = h.medications.length;
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _sectionTitle(
          "Today's Meds", Icons.medication_rounded,
          trailing: Text(
            total > 0 ? '$done / $total taken' : 'No meds yet',
            style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w700, color: _inkSoft)),
        ),
        if (h.medications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Icon(Icons.add_circle_outline_rounded,
                color: _inkSoft.withOpacity(0.5), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'No medications yet — tap Add to track one',
                style: GoogleFonts.nunito(fontSize: 12, color: _inkSoft))),
            ]),
          )
        else ...[
          if (expanded)
            Expanded(child: SingleChildScrollView(
              child: Column(children: [
                for (final med in h.medications)
                  _HealthMedRow(
                    name: (med['name'] as String?) ?? '',
                    dose: (med['dosage'] as String?) ?? '',
                    taken: (med['taken_today'] == true),
                    onTake: () => _handleMedTake(med),
                    onSkip: () => ref.read(healthProvider.notifier)
                      .skipMedication((med['id'] ?? '').toString()),
                  ),
              ]),
            ))
          else
            for (final med in h.medications)
              _HealthMedRow(
                name: (med['name'] as String?) ?? '',
                dose: (med['dosage'] as String?) ?? '',
                taken: (med['taken_today'] == true),
                onTake: () => _handleMedTake(med),
                onSkip: () => ref.read(healthProvider.notifier)
                  .skipMedication((med['id'] ?? '').toString()),
              ),
        ],
        const SizedBox(height: 10),
        // Olive-accented, cream surface, brown paw-stamp shadow.
        // Lives in the same palette family as the wellness ring
        // + bottom nav so the CTA reads native to the page
        // instead of being a loud coral button on cream.
        GestureDetector(
          onTap: _showAddMedSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: _ombre1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _oliveDk.withOpacity(0.35), width: 1.3),
              boxShadow: [
                BoxShadow(
                  color: _outline.withOpacity(0.18),
                  offset: const Offset(2, 2), blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Plus-in-circle chip in SAGE (#98A869 from the
                // palette) so it matches the popup it opens.
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _olive,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _outline.withOpacity(0.28), width: 1),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 14, color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Add a medication',
                  style: GoogleFonts.gaegu(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _brown, letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    // Wrap in a warm cream paper card so meds sit on their own surface
    // (matches water/sleep/insights cards and removes visual clutter).
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: card,
    );
  }

  //  LOCAL INSIGHTS FALLBACK
  //  Always returns 3–4 personalized tips derived from the current
  //  state, so the Insights card is never empty even before the
  //  backend generator has enough data to work with.
  List<Map<String, dynamic>> _localInsights(HealthData h) {
    final tips = <Map<String, dynamic>>[];

    final glasses = h.waterGlasses;
    if (glasses == 0) {
      tips.add({
        'icon': 'water',
        'text': 'Start with one glass of water — hydration boosts mood and focus within minutes.',
      });
    } else if (glasses >= 8) {
      tips.add({
        'icon': 'water',
        'text': 'Hydration goal smashed! Keep sipping through the day for peak focus.',
      });
    } else {
      tips.add({
        'icon': 'water',
        'text': 'You\'re at $glasses / 8 glasses — ${8 - glasses} to go for your daily goal!',
      });
    }

    final todayMood = h.todaysMood;
    if (todayMood == null) {
      tips.add({
        'icon': 'mood',
        'text': 'Haven\'t checked in yet? Logging your mood helps spot patterns over time.',
      });
    } else {
      final mName = (todayMood['mood_name'] ?? '').toString().toLowerCase();
      if (['sad', 'anxious', 'angry', 'tired'].contains(mName)) {
        tips.add({
          'icon': 'mood',
          'text': 'Feeling $mName? Try a 5-minute walk or breathing exercise — small resets help.',
        });
      } else {
        tips.add({
          'icon': 'mood',
          'text': 'Logged mood: great job. Daily check-ins build self-awareness over weeks.',
        });
      }
    }

    final sleepH = h.todaysSleep != null
        ? (double.tryParse(h.todaysSleep!['total_hours']?.toString() ?? '0') ?? 0)
        : 0.0;
    if (sleepH == 0) {
      tips.add({
        'icon': 'sleep',
        'text': 'No sleep logged yet — tap Log Sleep to track last night and spot trends.',
      });
    } else if (sleepH >= 7 && sleepH <= 9) {
      tips.add({
        'icon': 'sleep',
        'text': 'Got ${sleepH.toStringAsFixed(1)}h last night — right in the sweet spot. Keep it up!',
      });
    } else if (sleepH < 7) {
      tips.add({
        'icon': 'sleep',
        'text': 'Only ${sleepH.toStringAsFixed(1)}h last night — aim for 7–9h. Try winding down earlier.',
      });
    } else {
      tips.add({
        'icon': 'sleep',
        'text': '${sleepH.toStringAsFixed(1)}h is a lot — too much sleep can feel just as groggy as too little.',
      });
    }

    if (h.medications.isEmpty) {
      tips.add({
        'icon': 'pill',
        'text': 'Track any meds you take so you never miss a dose. Tap Add Medication to start.',
      });
    } else {
      final total = h.medications.length;
      final taken = h.medicationsTakenToday;
      if (taken < total) {
        tips.add({
          'icon': 'pill',
          'text': '$taken of $total meds taken today — tap the check to mark the rest.',
        });
      } else {
        tips.add({
          'icon': 'pill',
          'text': 'All meds taken today — consistency is key to staying on top of your health.',
        });
      }
    }

    return tips;
  }

  //  AI HEALTH INSIGHTS CARD — with See-more toggle
  //  Matches .insights-wrap
  Widget _buildInsightsCard(HealthData h) {
    // Blend server insights with local fallback tips so the card is NEVER
    // empty — the backend's insight generator only kicks in once you have
    // multi-day history, which is a rough first-run experience.
    final all = <Map<String, dynamic>>[
      ...h.insights,
      ..._localInsights(h),
    ];
    final shown = _insightsOpen ? all : all.take(2).toList();
    final hasMore = all.length > 2;

    Widget emptyState() => Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(Icons.auto_awesome_rounded, color: _oliveDk, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(
          'Log your activities to unlock personalized health insights!',
          style: GoogleFonts.nunito(fontSize: 13, color: _inkSoft, height: 1.4))),
      ]),
    );

    return Container(
      decoration: BoxDecoration(
        // Soft pink-tinted cream so insights stand out from the cream cards
        // around them without being another stark white box.
        color: const Color(0xFFFFF1F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _pinkDk.withOpacity(0.28), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: _pinkDk),
              const SizedBox(width: 7),
              const Text('Health Insights', style: TextStyle(
                fontFamily: 'Bitroad', fontSize: 18, color: _brown)),
              const Spacer(),
              // Arrow now navigates to the cross-domain Insights screen so
              // users can drill into correlations across study + health.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push(Routes.insights),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                  child: Text('See all →', style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _pinkDk)),
                ),
              ),
            ]),
          ),
          Divider(height: 1, color: _outline.withOpacity(0.08)),
          Expanded(child: all.isEmpty
            ? emptyState()
            : Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: SingleChildScrollView(
                      child: Column(children: [
                        for (int i = 0; i < shown.length; i++) ...[
                          _InsightRow(
                            text: (shown[i]['text'] as String?) ?? '',
                            iconKey: (shown[i]['icon'] as String?) ?? '',
                          ),
                          if (i < shown.length - 1) const SizedBox(height: 5),
                        ],
                      ]),
                    )),
                    if (hasMore) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => setState(() => _insightsOpen = !_insightsOpen),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _outline.withOpacity(0.15), width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _insightsOpen
                                  ? 'Show less'
                                  : 'See ${all.length - 2} more',
                                style: GoogleFonts.nunito(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: _brownLt)),
                              const SizedBox(width: 4),
                              Icon(
                                _insightsOpen
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                                size: 12, color: _brownLt),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ),
        ],
      ),
    );
  }

  IconData _insightIconData(String icon) {
    switch (icon) {
      case 'bulb': return Icons.lightbulb_rounded;
      case 'fire': return Icons.local_fire_department_rounded;
      case 'chart_up': return Icons.trending_up_rounded;
      case 'chart_down': return Icons.trending_down_rounded;
      case 'water': return Icons.water_drop_rounded;
      case 'moon': return Icons.nightlight_round;
      case 'pill': return Icons.medication_rounded;
      case 'heart': return Icons.favorite_rounded;
      default: return Icons.auto_awesome_rounded;
    }
  }

  //  SYMPTOM TEASER — .teaser.t-coral
  Widget _buildSymptomTeaser() {
    return GestureDetector(
      onTap: _showSymptomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7AEAE).withOpacity(0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline.withOpacity(0.12), width: 1),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF7AEAE).withOpacity(0.65),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outline.withOpacity(0.2), width: 1.5),
            ),
            child: Icon(Icons.favorite_rounded, size: 14, color: _brownLt),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Feeling off?', style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
              Text('Log a symptom quickly', style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w600, color: _inkSoft)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 14,
            color: _outline.withOpacity(0.25)),
        ]),
      ),
    );
  }

  //  SLEEP TEASER — .teaser.t-blue
  Widget _buildSleepTeaser(HealthData h) {
    final last = h.todaysSleep;
    final hrs = double.tryParse(last?['total_hours']?.toString() ?? '0') ?? 0;
    final q   = (last?['quality_rating'] as int?) ?? 0;
    final sub = last == null
      ? 'Tap to log last night'
      : 'Last night · ${hrs.toStringAsFixed(1)}h · ${'★' * q}${'☆' * (5 - q)}';
    return GestureDetector(
      onTap: _showSleepSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _blueLt.withOpacity(0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline.withOpacity(0.12), width: 1),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _blueLt.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outline.withOpacity(0.2), width: 1.5),
            ),
            child: Icon(Icons.nightlight_round, size: 14, color: _brownLt),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log Sleep', style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
              Text(sub, style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w600, color: _inkSoft),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 14,
            color: _outline.withOpacity(0.25)),
        ]),
      ),
    );
  }

  //  TIP CARD — .tip (lightbulb + Gaegu message)
  Widget _buildTipCard(HealthData h) {
    String msg; IconData ic;
    if (h.waterGlasses < 4) {
      msg = 'Drinking water before meals can boost your energy — you need ${8 - h.waterGlasses} more glasses today!';
      ic = Icons.water_drop_rounded;
    } else if (h.avgSleepHours > 0 && h.avgSleepHours < 7) {
      msg = 'A 10-min evening stretch could bump your sleep quality higher.';
      ic = Icons.self_improvement_rounded;
    } else if (h.wellnessScore >= 80) {
      msg = "You're crushing it! Keep your momentum going with a short walk.";
      ic = Icons.celebration_rounded;
    } else {
      msg = 'Small steps add up — hydrate, rest, and check in with your mood today.';
      ic = Icons.lightbulb_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _pinkLt.withOpacity(0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.18), width: 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.3), width: 1.5),
          ),
          child: Icon(ic, size: 12, color: _pinkDk),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(msg, style: GoogleFonts.gaegu(
          fontSize: 15, fontWeight: FontWeight.w700,
          color: _brown, height: 1.4))),
      ]),
    );
  }

  //  HISTORY BUTTON — .history-btn styling
  Widget _buildHistoryButton() {
    return GestureDetector(
      onTap: _showHistorySheet,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDEFDB).withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(0.2),
            offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_rounded, size: 15, color: _inkSoft),
          const SizedBox(width: 8),
          Text('View Health History', style: GoogleFonts.gaegu(
            fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
        ]),
      ),
    );
  }

  //  BOTTOM SHEETS

  void _showMoodDetailSheet(String moodId, String moodName) {
    int energy = 3;
    final selectedTags = <String>[];
    final noteCtrl = TextEditingController();
    final tags = ['Study', 'Exercise', 'Social', 'Work', 'Relax', 'Outdoors'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF9F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _sheetHandle(),
              Text('Feeling $moodName', style: GoogleFonts.gaegu(
                fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
              const SizedBox(height: 20),

              // Energy level
              _sheetLabel('Energy Level'),
              Row(mainAxisAlignment: MainAxisAlignment.center, children:
                List.generate(5, (i) => GestureDetector(
                  onTap: () => setSheetState(() => energy = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: i < energy ? LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [_goldHdr, _goldDk],
                        ) : null,
                        color: i < energy ? null : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (i < energy) BoxShadow(color: _goldHdr.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3)),
                          if (i >= energy) BoxShadow(color: _outline.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: Center(child: Icon(Icons.bolt_rounded,
                        size: i < energy ? 20 : 16,
                        color: i < energy ? Colors.white : _brownLt.withOpacity(0.3))),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 20),

              // Context tags
              _sheetLabel('What are you up to?'),
              Wrap(spacing: 8, runSpacing: 10, children: tags.map((t) {
                final on = selectedTags.contains(t);
                return _sheetChip(t, on, _goldHdr, () => setSheetState(() {
                  on ? selectedTags.remove(t) : selectedTags.add(t);
                }));
              }).toList()),
              const SizedBox(height: 16),

              _sheetInput(noteCtrl, 'Add a note (optional)'),
              const SizedBox(height: 20),

              _sheetButton('Save Mood', _goldHdr, () {
                // Only skip XP if same mood as current (can't farm by re-saving)
                final prevMood = ref.read(healthProvider).todaysMood;
                final sameMood = (prevMood?['mood_id'] ?? '').toString() == moodId;
                ref.read(healthProvider.notifier).logMoodDetailed(
                  moodId, energy, selectedTags, noteCtrl.text);
                if (!sameMood) {
                  ref.read(dashboardProvider.notifier)
                      .awardXp(AppConstants.xpPerMoodLog);
                }
                Navigator.pop(ctx);
              }),
            ]),
          ),
        ),
      ),
    );
  }

  void _showSleepSheet() {
    DateTime selectedDate = DateTime.now().subtract(const Duration(days: 1));
    TimeOfDay bedtime = const TimeOfDay(hour: 23, minute: 0);
    TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);
    int quality = 3;
    final noteCtrl = TextEditingController();

    // Same sticker-stamp gamified treatment as _showAddMedSheet
    // — sage green palette, thick brown outline, hard offset
    // shadow. The old purple bottom sheet didn't match the
    // health tab's warm cream/olive vibe; this one does.
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close log sleep',
      barrierColor: _brown.withOpacity(0.32),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(
          parent: anim, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * anim.value,
            sigmaY: 8 * anim.value,
          ),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.85 + curved.value * 0.15,
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20,
                      MediaQuery.of(ctx).viewInsets.bottom + 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: StatefulBuilder(
                        builder: (sCtx, setSheetState) => _buildSleepDialog(
                          ctx: ctx,
                          selectedDate: selectedDate,
                          bedtime: bedtime,
                          wakeTime: wakeTime,
                          quality: quality,
                          noteCtrl: noteCtrl,
                          setSheetState: setSheetState,
                          onDateChange: (d) => selectedDate = d,
                          onBedChange: (t) => bedtime = t,
                          onWakeChange: (t) => wakeTime = t,
                          onQualityChange: (q) => quality = q,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the Log Sleep popup content — sticker-stamp card
  /// using the theme blue palette (`_blueLt` #DDF6FF from the
  /// app theme, paired with `_blueLtDk` for text contrast).
  /// Mirrors the structure of `_buildAddMedDialog` so the two
  /// popups feel like siblings in the same gamified system,
  /// just in different color families so Sleep vs. Medications
  /// vs. Symptoms are visually distinguishable at a glance.
  Widget _buildSleepDialog({
    required BuildContext ctx,
    required DateTime selectedDate,
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required int quality,
    required TextEditingController noteCtrl,
    required void Function(VoidCallback) setSheetState,
    required void Function(DateTime) onDateChange,
    required void Function(TimeOfDay) onBedChange,
    required void Function(TimeOfDay) onWakeChange,
    required void Function(int) onQualityChange,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
        decoration: BoxDecoration(
          color: _ombre2,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _brown, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: _brown,
              offset: const Offset(6, 6), blurRadius: 0,
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Eyebrow + close
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'SLEEP',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _blueLtDk,                // deep blue eyebrow
                    letterSpacing: 2.4,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _brown, width: 2),
                  boxShadow: [
                    BoxShadow(color: _brown,
                      offset: const Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: Icon(Icons.close_rounded, size: 16, color: _brown),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Stamped icon + title
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _blueLt,                       // soft sky blue stamp
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _brown, width: 2),
                boxShadow: [
                  BoxShadow(color: _brown,
                    offset: const Offset(3, 3), blurRadius: 0),
                ],
              ),
              // Brown icon on pale blue — keeps strong contrast since
              // _blueLt is too pale to carry white glyphs.
              child: const Icon(Icons.nightlight_round,
                color: _brown, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Log Sleep', style: GoogleFonts.gaegu(
                    fontSize: 30, fontWeight: FontWeight.w700,
                    color: _brown, letterSpacing: 0.5, height: 1.0)),
                  const SizedBox(height: 4),
                  Text('how did last night treat you?',
                    style: GoogleFonts.gaegu(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: _brownLt, letterSpacing: 0.2)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 22),

          // Date — full width sticker tile
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setSheetState(() {
                  selectedDate = picked;
                  onDateChange(picked);
                });
              }
            },
            child: _stickerInfoTile(
              icon: Icons.calendar_today_rounded,
              text: '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
              iconColor: _blueLtDk,
            ),
          ),
          const SizedBox(height: 12),

          // Bedtime + Wake time row
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () async {
                final t = await showTimePicker(
                  context: ctx, initialTime: bedtime);
                if (t != null) {
                  setSheetState(() {
                    bedtime = t;
                    onBedChange(t);
                  });
                }
              },
              child: _stickerInfoTile(
                icon: Icons.bedtime_rounded,
                text: 'bed  ${bedtime.format(ctx)}',
                iconColor: _blueLtDk,
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () async {
                final t = await showTimePicker(
                  context: ctx, initialTime: wakeTime);
                if (t != null) {
                  setSheetState(() {
                    wakeTime = t;
                    onWakeChange(t);
                  });
                }
              },
              child: _stickerInfoTile(
                icon: Icons.wb_sunny_rounded,
                text: 'wake  ${wakeTime.format(ctx)}',
                iconColor: _blueLtDk,
              ),
            )),
          ]),
          const SizedBox(height: 22),

          // Sleep Quality
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Text('sleep quality', style: GoogleFonts.gaegu(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: _brown, letterSpacing: 0.3)),
            ),
          ),
          // Sticker tile holding the 5 stars — feels like a single
          // unit of the popup, not floating starts on the cream bg.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _brown, width: 2),
              boxShadow: [
                BoxShadow(color: _brown,
                  offset: const Offset(3, 3), blurRadius: 0),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setSheetState(() {
                  quality = i + 1;
                  onQualityChange(quality);
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: i < quality ? 1.0 : 0.94,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      i < quality
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                      size: 34,
                      // Deeper blue for filled stars so they pop on
                      // the white sticker tile. The pale _blueLt
                      // would disappear against white.
                      color: i < quality
                        ? _blueLtDk
                        : _brownLt.withOpacity(0.30),
                    ),
                  ),
                ),
              )),
            ),
          ),
          const SizedBox(height: 18),

          // Notes
          _medSheetField(
            icon: Icons.edit_note_rounded,
            controller: noteCtrl,
            hint: 'notes (optional)',
            iconColor: _blueLtDk,
          ),
          const SizedBox(height: 26),

          // Cancel + Log pill buttons
          Row(children: [
            Expanded(
              flex: 2,
              child: _medPillButton(
                label: 'cancel',
                bg: Colors.white,
                fg: _brown,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _medPillButton(
                label: 'log sleep',
                // Pale blue fill — text goes brown since white
                // would be invisible on #DDF6FF.
                bg: _blueLt,
                fg: _brown,
                onTap: () {
                  final m = selectedDate.month.toString().padLeft(2, '0');
                  final d = selectedDate.day.toString().padLeft(2, '0');
                  final dateStr = '${selectedDate.year}-$m-$d';
                  final bedDt = DateTime(
                    selectedDate.year, selectedDate.month, selectedDate.day,
                    bedtime.hour, bedtime.minute);
                  final nextDay = selectedDate.add(const Duration(days: 1));
                  final wakeDt = DateTime(
                    nextDay.year, nextDay.month, nextDay.day,
                    wakeTime.hour, wakeTime.minute);
                  ref.read(healthProvider.notifier).logSleep(
                    dateStr, bedDt.toIso8601String(),
                    wakeDt.toIso8601String(), quality, noteCtrl.text);
                  ref.read(dashboardProvider.notifier)
                      .awardXp(AppConstants.xpPerSleepLog);
                  ref.read(dashboardProvider.notifier).refresh();
                  ref.read(dashboardProvider.notifier).checkAchievements();
                  Navigator.pop(ctx);
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  /// Tappable sticker-stamp tile that displays an icon + a label
  /// (used for date / bedtime / wake time pickers in the sleep
  /// popup). Same look as `_medSheetField` but with text instead
  /// of an editable field. [iconColor] defaults to sage `_oliveDk`
  /// but each popup can pass its own accent.
  Widget _stickerInfoTile({
    required IconData icon,
    required String text,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brown, width: 2),
        boxShadow: [
          BoxShadow(color: _brown,
            offset: const Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
          child: Icon(icon, size: 22,
            color: iconColor ?? _oliveDk),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              text,
              style: GoogleFonts.gaegu(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: _brown),
            ),
          ),
        ),
        const SizedBox(width: 14),
      ]),
    );
  }

  void _showAddMedSheet() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    String frequency = 'daily';

    // Frequency chip metadata — each option has its own warm icon + hint
    // so the choice feels considered, not like a generic radio row.
    final freqOptions = <Map<String, dynamic>>[
      {
        'key': 'daily',
        'label': 'Daily',
        'hint': 'Every day',
        'icon': Icons.wb_sunny_rounded,
      },
      {
        'key': 'weekly',
        'label': 'Weekly',
        'hint': 'A few times a week',
        'icon': Icons.calendar_view_week_rounded,
      },
      {
        'key': 'as_needed',
        'label': 'As needed',
        'hint': 'Only when required',
        'icon': Icons.bolt_rounded,
      },
    ];

    // Earlier this was a bottom sheet that read too "form-y" and the
    // peach background didn't match the warm cream / olive vibe of
    // the health tab. Now it's a centered popup that floats above a
    // blurred + dimmed copy of the page — feels native to the app.
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close add medication',
      // Soft warm tint instead of black — keeps the dim from feeling
      // harsh against the cream palette.
      barrierColor: _brown.withOpacity(0.32),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        // Curve for a friendly "pop in" — slightly overshoots so the
        // dialog feels physical, not just faded.
        final curved = CurvedAnimation(
          parent: anim, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * anim.value,
            sigmaY: 8 * anim.value,
          ),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.85 + curved.value * 0.15,
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20,
                      MediaQuery.of(ctx).viewInsets.bottom + 24),
                    child: ConstrainedBox(
                      // Bumped from 440 → 560. The old width felt cramped
                      // once the gamified sticker treatment (thick outline
                      // + hard stamp shadow + pill buttons) was added —
                      // the content needs more canvas to breathe.
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: StatefulBuilder(
                        builder: (sCtx, setSheetState) => _buildAddMedDialog(
                          ctx: ctx,
                          nameCtrl: nameCtrl,
                          dosageCtrl: dosageCtrl,
                          frequency: frequency,
                          setSheetState: setSheetState,
                          freqOptions: freqOptions,
                          onFreqChange: (f) => frequency = f,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the popup dialog content — kept separate so the transition
  /// builder above stays focused on motion / blur.
  Widget _buildAddMedDialog({
    required BuildContext ctx,
    required TextEditingController nameCtrl,
    required TextEditingController dosageCtrl,
    required String frequency,
    required void Function(VoidCallback) setSheetState,
    required List<Map<String, dynamic>> freqOptions,
    required void Function(String) onFreqChange,
  }) {
    // Inspired by the Focus Mode reference: thick dark outline,
    // hard offset shadow (no blur), creamy interior, sage-green
    // accents. The whole popup should read like a sticker that's
    // been pressed onto the page.
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
        decoration: BoxDecoration(
          color: _ombre2,                                     // warm cream
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _brown, width: 2.5),       // thick dark outline
          boxShadow: [
            // The signature hard "stamp" shadow — no blur, big offset.
            BoxShadow(
              color: _brown,
              offset: const Offset(6, 6), blurRadius: 0,
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'MEDICATIONS',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _oliveDk,
                      letterSpacing: 2.4,
                    ),
                  ),
                ),
              ),
              // Close chip — same sticker treatment, just smaller.
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _brown, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _brown,
                        offset: const Offset(2, 2), blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16, color: _brown,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Stamped pill icon — SAGE green chip (#98A869 from
              // the palette, not the mint _greenLt we had before)
              // with the same thick outline + hard shadow as the
              // rest of the sticker elements.
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _olive,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _brown, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _brown,
                      offset: const Offset(3, 3), blurRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Colors.white, size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add a Medication',
                      style: GoogleFonts.gaegu(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: _brown,
                        letterSpacing: 0.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'track what you take. never miss a dose.',
                      style: GoogleFonts.gaegu(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _brownLt,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          _medSheetField(
            icon: Icons.local_pharmacy_rounded,
            controller: nameCtrl,
            hint: 'medication name',
          ),
          const SizedBox(height: 12),
          _medSheetField(
            icon: Icons.straighten_rounded,
            controller: dosageCtrl,
            hint: 'dosage  •  e.g. 500mg',
          ),
          const SizedBox(height: 22),

          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Text(
                'how often?',
                style: GoogleFonts.gaegu(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: _brown, letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          Row(children: freqOptions.map((o) {
            final on = frequency == o['key'];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _medFreqTile(
                  icon: o['icon'] as IconData,
                  label: o['label'] as String,
                  hint: o['hint'] as String,
                  selected: on,
                  onTap: () => setSheetState(() {
                    frequency = o['key'] as String;
                    onFreqChange(frequency);
                  }),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 26),

          // Mirrors the Focus Mode reference: two pill buttons
          // side-by-side, both with the thick outline + hard
          // stamp shadow. Cancel is white, save is sage green.
          Row(children: [
            Expanded(
              flex: 2,
              child: _medPillButton(
                label: 'cancel',
                bg: Colors.white,
                fg: _brown,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _medPillButton(
                label: 'save medication',
                bg: _olive,   // sage #98A869 from the palette
                fg: Colors.white,
                onTap: () {
                  if (nameCtrl.text.isNotEmpty &&
                      dosageCtrl.text.isNotEmpty) {
                    ref.read(healthProvider.notifier).addMedication(
                      nameCtrl.text, dosageCtrl.text, frequency);
                    ref.read(dashboardProvider.notifier).awardXp(3);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _olive,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _brown.withOpacity(0.25),
                            width: 2,
                          ),
                        ),
                        content: Text(
                          '${nameCtrl.text} added — +3 XP!',
                          style: GoogleFonts.gaegu(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  //  Add-med popup helpers — "sticker stamp" style. Every
  //  element shares three traits:
  //    • Thick dark brown outline (2–2.5 px)
  //    • Hard offset shadow (no blur) in brown
  //    • Creamy / sage fill
  //  Inspired by the Focus Mode reference mock. Sage green
  //  is the accent so the popup lives in the same palette
  //  family as the wellness ring + olive bottom nav.

  /// Icon-prefixed input field — ONE clean white sticker box
  /// with a thick dark outline + hard stamp shadow. The icon
  /// floats inside the field next to the text, with NO tinted
  /// background, NO divider, NO inner chip. Single uninterrupted
  /// white surface.
  ///
  /// [iconColor] lets each popup (Add Med = sage, Log Sleep =
  /// blue, Log Symptom = rose) tint the leading icon to match
  /// its own palette without re-implementing this whole widget.
  ///
  /// To kill the "double box" look — where Material's default
  /// InputDecoration was drawing its own subtle container/outline
  /// *inside* our sticker box — we:
  ///   • explicitly clear every border state (border, enabled,
  ///     focused, disabled, error, focusedError) to InputBorder.none
  ///   • force filled:false / fillColor:transparent so no tinted
  ///     rounded background is painted behind the text
  ///   • wrap the TextField in a Theme that overrides
  ///     inputDecorationTheme so ancestor defaults can't sneak a
  ///     border back in
  ///   • use isCollapsed:true + custom padding so Material's
  ///     built-in minimum vertical chrome doesn't leak through
  Widget _medSheetField({
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brown, width: 2),
        boxShadow: [
          BoxShadow(
            color: _brown,
            offset: const Offset(3, 3), blurRadius: 0,
          ),
        ],
      ),
      child: Row(children: [
        // Just the icon — no background, no border, no chip.
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
          child: Icon(icon, size: 22,
            color: iconColor ?? _oliveDk),
        ),
        Expanded(
          child: Theme(
            // Local theme override so any ancestor
            // InputDecorationTheme can't reintroduce the inner
            // rounded-rect border / background.
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                isCollapsed: true,
              ),
            ),
            child: TextField(
              controller: controller,
              cursorColor: _brown,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.gaegu(
                  fontSize: 16,
                  color: _brownLt.withOpacity(0.55),
                  fontWeight: FontWeight.w600,
                ),
                // Belt-and-suspenders: also set everything
                // inline in case the Theme override gets shadowed.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 18),
              ),
              style: GoogleFonts.gaegu(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _brown,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
      ]),
    );
  }

  /// Frequency tile — sticker card. Selected gets sage fill +
  /// hard stamp shadow; unselected gets white with subtle shadow.
  Widget _medFreqTile({
    required IconData icon,
    required String label,
    required String hint,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          // Sage fill when selected (_olive = #98A869 from palette),
          // white otherwise. Same thick brown outline on both for
          // consistent sticker treatment.
          color: selected ? _olive : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _brown, width: 2),
          boxShadow: [
            BoxShadow(
              color: _brown,
              offset: selected ? const Offset(3, 3) : const Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
            size: 22,
            color: selected ? Colors.white : _brownLt),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.gaegu(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _brown,
            letterSpacing: 0.3,
          )),
          const SizedBox(height: 2),
          Text(hint,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.gaegu(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              // White/90 when selected so it stays legible on the
              // sage fill; brown/80 otherwise on white.
              color: selected
                  ? Colors.white.withOpacity(0.90)
                  : _brownLt.withOpacity(0.80),
            )),
        ]),
      ),
    );
  }

  /// Sticker-stamp pill button — thick outline, hard shadow,
  /// big friendly Gaegu label. Reusable for both Cancel + Save.
  Widget _medPillButton({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _brown, width: 2.2),
          boxShadow: [
            BoxShadow(
              color: _brown,
              offset: const Offset(3, 3), blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.gaegu(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  void _showSymptomSheet() {
    String type = 'Headache';
    bool isCustom = false;
    int intensity = 5;
    final selectedTriggers = <String>[];
    final customCtrl = TextEditingController();
    // Prepend any condition-/medication-derived suggestions so they
    // appear first in the picker. 'Other' always stays last.
    final baseTypes = ['Headache', 'Fatigue', 'Back Pain', 'Eye Strain',
      'Nausea', 'Dizziness', 'Stomach Pain'];
    final types = <String>[
      ..._suggestedSymptoms,
      ...baseTypes.where((t) => !_suggestedSymptoms.contains(t)),
      'Other',
    ];
    // Merge condition-specific triggers ahead of the generic set.
    final baseTriggers = ['Studying', 'Lack of sleep', 'Stress', 'Caffeine',
      'Dehydration', 'Screen time', 'Poor posture', 'Skipped meals'];
    final triggers = <String>[
      ..._extraTriggers,
      ...baseTriggers.where((t) => !_extraTriggers.contains(t)),
    ];

    // Gamified sticker-stamp treatment, sage palette — same
    // family as Add Med + Log Sleep so all three core logging
    // flows feel cohesive instead of three different colors.
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close log symptom',
      barrierColor: _brown.withOpacity(0.32),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(
          parent: anim, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * anim.value,
            sigmaY: 8 * anim.value,
          ),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.85 + curved.value * 0.15,
              // Height-bounded ConstrainedBox so the ScrollView scrolls
              // internally instead of letting Center overflow the
              // viewport on short screens.
              //
              // Width: widen to 720 when we have condition-aware
              // suggested chips so they spread horizontally instead of
              // forcing the user to scroll a tall column. When there are
              // no suggestions, keep the default narrow 560 so the card
              // stays compact and doesn't feel empty.
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _suggestedSymptoms.isNotEmpty ? 720 : 560,
                    maxHeight: MediaQuery.of(ctx).size.height -
                        MediaQuery.of(ctx).viewInsets.bottom - 48,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 24, 20,
                      MediaQuery.of(ctx).viewInsets.bottom + 24),
                    child: StatefulBuilder(
                      builder: (sCtx, setSheetState) => _buildSymptomDialog(
                          ctx: ctx,
                          type: type,
                          isCustom: isCustom,
                          intensity: intensity,
                          selectedTriggers: selectedTriggers,
                          customCtrl: customCtrl,
                          types: types,
                          triggers: triggers,
                          setSheetState: setSheetState,
                          onTypeChange: (t, c) {
                            type = t; isCustom = c;
                          },
                          onIntensityChange: (i) => intensity = i,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
      },
    );
  }

  /// Builds the Log Symptom popup content — sticker-stamp card
  /// using the theme rose-pink palette (`_rosePink` #F7AEAE from
  /// the palette, paired with `_rosePinkDk` for text contrast).
  /// The rose ties back to the pink pawprint motif already used
  /// elsewhere in the app, and distinguishes Symptoms from
  /// Medications (sage) + Sleep (pale blue) at a glance.
  Widget _buildSymptomDialog({
    required BuildContext ctx,
    required String type,
    required bool isCustom,
    required int intensity,
    required List<String> selectedTriggers,
    required TextEditingController customCtrl,
    required List<String> types,
    required List<String> triggers,
    required void Function(VoidCallback) setSheetState,
    required void Function(String, bool) onTypeChange,
    required void Function(int) onIntensityChange,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
        decoration: BoxDecoration(
          color: _ombre2,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _brown, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: _brown,
              offset: const Offset(6, 6), blurRadius: 0,
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Eyebrow + close
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'SYMPTOMS',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _rosePinkDk,              // deep rose eyebrow
                    letterSpacing: 2.4,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _brown, width: 2),
                  boxShadow: [
                    BoxShadow(color: _brown,
                      offset: const Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: Icon(Icons.close_rounded, size: 16, color: _brown),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Stamped icon + title
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _rosePink,                    // #F7AEAE stamp
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _brown, width: 2),
                boxShadow: [
                  BoxShadow(color: _brown,
                    offset: const Offset(3, 3), blurRadius: 0),
                ],
              ),
              // Brown icon reads cleanly on the soft rose — white
              // would wash out against the pastel background.
              child: const Icon(Icons.healing_rounded,
                color: _brown, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Log a Symptom', style: GoogleFonts.gaegu(
                    fontSize: 30, fontWeight: FontWeight.w700,
                    color: _brown, letterSpacing: 0.5, height: 1.0)),
                  const SizedBox(height: 4),
                  Text("noticing patterns starts with a tap.",
                    style: GoogleFonts.gaegu(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: _brownLt, letterSpacing: 0.2)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 22),

          // Only rendered when the user has at least one matched
          // condition/medication. Purple tint so they're obviously
          // distinct from the generic choices below.
          if (_suggestedSymptoms.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: _purpleHdr),
                  const SizedBox(width: 6),
                  Text('suggested for you',
                    style: GoogleFonts.gaegu(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: _brown, letterSpacing: 0.3)),
                ]),
              ),
            ),
            Wrap(spacing: 8, runSpacing: 10,
              children: _suggestedSymptoms.map((t) {
                final on = type == t && !isCustom;
                return _stickerPickChip(
                  label: t,
                  selected: on,
                  // Purple fill on selection so these visually
                  // separate from the rose-pink "generic" chips.
                  selectedColor: _purpleLt,
                  selectedTextColor: _brown,
                  onTap: () => setSheetState(() {
                    isCustom = false; type = t;
                    onTypeChange(t, false);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Text("what's bothering you?",
                style: GoogleFonts.gaegu(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: _brown, letterSpacing: 0.3)),
            ),
          ),
          Wrap(spacing: 8, runSpacing: 10, children: types.map((t) {
            final on = (t == 'Other')
              ? isCustom
              : (type == t && !isCustom);
            return _stickerPickChip(
              label: t,
              selected: on,
              onTap: () => setSheetState(() {
                if (t == 'Other') {
                  isCustom = true; type = '';
                  onTypeChange('', true);
                } else {
                  isCustom = false; type = t;
                  onTypeChange(t, false);
                }
              }),
            );
          }).toList()),

          if (isCustom) ...[
            const SizedBox(height: 12),
            _medSheetField(
              icon: Icons.edit_rounded,
              controller: customCtrl,
              hint: 'describe your symptom',
              iconColor: _rosePinkDk,
            ),
          ],
          const SizedBox(height: 22),

          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Row(children: [
                Text('intensity',
                  style: GoogleFonts.gaegu(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: _brown, letterSpacing: 0.3)),
                const Spacer(),
                // Pill badge showing the current value — rose
                // accent so it ties back to the rest of the popup.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _rosePink,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _brown, width: 1.6),
                    boxShadow: [
                      BoxShadow(color: _brown,
                        offset: const Offset(2, 2), blurRadius: 0),
                    ],
                  ),
                  child: Text('$intensity / 10',
                    style: GoogleFonts.gaegu(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      // Brown text stays legible on the pastel rose.
                      color: _brown, letterSpacing: 0.4)),
                ),
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _brown, width: 2),
              boxShadow: [
                BoxShadow(color: _brown,
                  offset: const Offset(3, 3), blurRadius: 0),
              ],
            ),
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 8,
                // Deeper rose on the active track + thumb so the
                // slider reads strongly against the pale rose
                // inactive track.
                activeTrackColor: _rosePinkDk,
                inactiveTrackColor: _rosePink.withOpacity(0.35),
                thumbColor: _rosePinkDk,
                overlayColor: _rosePinkDk.withOpacity(0.18),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 12),
              ),
              child: Slider(
                value: intensity.toDouble(),
                min: 1, max: 10, divisions: 9,
                onChanged: (v) => setSheetState(() {
                  intensity = v.round();
                  onIntensityChange(intensity);
                }),
              ),
            ),
          ),
          const SizedBox(height: 22),

          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Text('possible triggers',
                style: GoogleFonts.gaegu(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: _brown, letterSpacing: 0.3)),
            ),
          ),
          Wrap(spacing: 8, runSpacing: 10, children: triggers.map((t) {
            final on = selectedTriggers.contains(t);
            return _stickerPickChip(
              label: t,
              selected: on,
              onTap: () => setSheetState(() {
                on ? selectedTriggers.remove(t) : selectedTriggers.add(t);
              }),
            );
          }).toList()),
          const SizedBox(height: 26),

          Row(children: [
            Expanded(
              flex: 2,
              child: _medPillButton(
                label: 'cancel',
                bg: Colors.white,
                fg: _brown,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _medPillButton(
                label: 'log symptom',
                // Rose fill with brown text — white would be
                // illegible on the pastel pink.
                bg: _rosePink,
                fg: _brown,
                onTap: () {
                  final symptomType = isCustom ? customCtrl.text : type;
                  if (symptomType.isNotEmpty) {
                    ref.read(healthProvider.notifier)
                        .logSymptom(symptomType, intensity,
                          selectedTriggers);
                    ref.read(dashboardProvider.notifier).awardXp(3);
                    Navigator.pop(ctx);
                  }
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  /// Sticker-stamp pick chip used by the Log Symptom popup for
  /// both type chips and trigger chips. Selected = colored fill
  /// + hard stamp shadow; unselected = white with the same
  /// outline. Pass [selectedColor] to theme the chip (Symptom
  /// uses rose, future popups could use other palette accents).
  /// Selected text color auto-picks brown for pastel fills or
  /// white for saturated fills — callers can force it via
  /// [selectedTextColor].
  Widget _stickerPickChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color selectedColor = _rosePink,
    Color selectedTextColor = _brown,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _brown, width: 2),
          boxShadow: [
            BoxShadow(
              color: _brown,
              offset: selected
                ? const Offset(3, 3)
                : const Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.gaegu(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? selectedTextColor : _brown,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  void _showHistorySheet() {
    final h = ref.read(healthProvider);
    int tabIndex = 0; // 0=sleep, 1=mood, 2=meds, 3=symptoms

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF8F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollCtrl) => Column(children: [
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: _sheetHandle(),
              ),
            Text('Health History', style: GoogleFonts.gaegu(
              fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 12),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _historyTab('Sleep', 0, _purpleHdr, tabIndex, (i) => setSheetState(() => tabIndex = i)),
                const SizedBox(width: 6),
                _historyTab('Mood', 1, _goldHdr, tabIndex, (i) => setSheetState(() => tabIndex = i)),
                const SizedBox(width: 6),
                _historyTab('Meds', 2, _coralHdr, tabIndex, (i) => setSheetState(() => tabIndex = i)),
                const SizedBox(width: 6),
                _historyTab('Symptoms', 3, _sageHdr, tabIndex, (i) => setSheetState(() => tabIndex = i)),
              ]),
            ),
            const SizedBox(height: 12),

            // Content
            Expanded(child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (tabIndex == 0) ..._buildSleepHistory(h),
                if (tabIndex == 1) ..._buildMoodHistory(h),
                if (tabIndex == 2) ..._buildMedHistory(h),
                if (tabIndex == 3) ..._buildSymptomHistory(),
              ],
            )),
          ]),
        ),
      )),
    );
  }

  Widget _historyTab(String label, int index, Color color, int current, void Function(int) onTap) {
    final on = current == index;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: on ? LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.35)],
          ) : null,
          color: on ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: on ? [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2)),
          ] : [
            BoxShadow(color: _outline.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Center(child: Text(label, style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: on ? _brown : _brownLt))),
      ),
    ));
  }

  List<Widget> _buildSleepHistory(HealthData h) {
    if (h.sleepHistory.isEmpty) {
      return [_emptyHistory('No sleep entries yet. Tap the sleep card to log your first night!')];
    }
    return h.sleepHistory.map((s) {
      final hours = double.tryParse(s['total_hours']?.toString() ?? '0') ?? 0;
      final quality = (s['quality_rating'] as int?) ?? 0;
      final date = (s['date'] ?? '').toString();
      final notes = (s['notes'] ?? '').toString();
      return _historyCard(
        icon: Icons.nightlight_round,
        color: _purpleHdr,
        title: '${hours.toStringAsFixed(1)} hours',
        subtitle: date,
        trailing: Row(mainAxisSize: MainAxisSize.min, children:
          List.generate(5, (i) => Icon(
            i < quality ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14, color: i < quality ? _goldHdr : _brownLt.withOpacity(0.2)))),
        note: notes.isNotEmpty ? notes : null,
      );
    }).toList();
  }

  List<Widget> _buildMoodHistory(HealthData h) {
    if (h.moodHistory.isEmpty) {
      return [_emptyHistory('No mood entries yet. Tap a mood sticker to check in!')];
    }
    return h.moodHistory.map((m) {
      final name = (m['mood_name'] ?? 'Unknown').toString();
      final energy = (m['energy_level'] as int?) ?? 0;
      final note = (m['note'] ?? '').toString();
      final tags = (m['context_tags'] as List?)?.cast<String>() ?? [];
      final ts = (m['timestamp'] ?? '').toString();
      return _historyCard(
        icon: Icons.emoji_emotions_rounded,
        color: _goldHdr,
        title: name,
        subtitle: _formatTimestamp(ts),
        trailing: Row(mainAxisSize: MainAxisSize.min, children:
          List.generate(5, (i) => Icon(Icons.bolt_rounded,
            size: 14, color: i < energy ? _goldHdr : _brownLt.withOpacity(0.2)))),
        note: note.isNotEmpty ? note : null,
        tags: tags,
      );
    }).toList();
  }

  List<Widget> _buildMedHistory(HealthData h) {
    if (h.medications.isEmpty) {
      return [_emptyHistory('No medications tracked yet. Tap the + Add button to start!')];
    }
    return h.medications.map((med) {
      return _historyCard(
        icon: Icons.medication_rounded,
        color: _coralHdr,
        title: med['name'] ?? '',
        subtitle: '${med['dosage'] ?? ''} • ${med['frequency'] ?? ''}',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (med['is_active'] == true) ? _greenHdr.withOpacity(0.2) : _brownLt.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text((med['is_active'] == true) ? 'Active' : 'Inactive',
            style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700,
              color: (med['is_active'] == true) ? _greenDk : _brownLt)),
        ),
      );
    }).toList();
  }

  List<Widget> _buildSymptomHistory() {
    // Need to fetch symptoms separately since they're not in main healthData
    // For now show a message — symptoms can be loaded async
    return [
      FutureBuilder(
        future: ref.read(apiServiceProvider).get('/health/symptoms', queryParams: {'limit': '20'}),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: _coralHdr),
            ));
          }
          if (!snap.hasData || snap.data?.data == null) {
            return _emptyHistory('No symptoms logged yet. Tap "Feeling off?" to log one.');
          }
          final items = (snap.data!.data as List?)?.cast<Map<String, dynamic>>() ?? [];
          if (items.isEmpty) {
            return _emptyHistory('No symptoms logged yet. Tap "Feeling off?" to log one.');
          }
          return Column(children: items.map((s) {
            final type = (s['symptom_type'] ?? '').toString();
            final intensity = (s['intensity'] as int?) ?? 0;
            final triggers = (s['triggers'] as List?)?.cast<String>() ?? [];
            final ts = (s['recorded_at'] ?? '').toString();
            return _historyCard(
              icon: Icons.healing_rounded,
              color: _intensityColor(intensity),
              title: type,
              subtitle: _formatTimestamp(ts),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _intensityColor(intensity).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$intensity/10', style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _brown)),
              ),
              tags: triggers,
            );
          }).toList());
        },
      ),
    ];
  }

  Widget _historyCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Widget? trailing,
    String? note,
    List<String> tags = const [],
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3)),
            BoxShadow(color: Colors.white.withOpacity(0.7), blurRadius: 0, spreadRadius: 0.5),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.15), color.withOpacity(0.25)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.nunito(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
                  Text(subtitle, style: GoogleFonts.nunito(
                    fontSize: 11, color: _brownLt)),
                ],
              )),
              if (trailing != null) trailing,
            ]),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(note, style: GoogleFonts.nunito(
                fontSize: 12, color: _brownLt, fontStyle: FontStyle.italic)),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: tags.map((t) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(t, style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w600, color: _brown)),
                ),
              ).toList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyHistory(String msg) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Icon(Icons.inbox_rounded, size: 32, color: _brownLt.withOpacity(0.3)),
        ),
        const SizedBox(height: 14),
        Text(msg, textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 13, color: _brownLt, height: 1.4)),
      ]),
    );
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return ts.split('T').first;
    }
  }

  Color _intensityColor(int i) {
    if (i <= 3) return _greenHdr;
    if (i <= 6) return _goldHdr;
    if (i <= 8) return _coralHdr;
    return const Color(0xFFE05050);
  }

  //  SHEET HELPERS — polished components

  /// Draggable handle bar at top of every sheet
  Widget _sheetHandle() {
    return Container(
      width: 44, height: 5,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _brownLt.withOpacity(0.18),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  /// Section label inside sheets
  Widget _sheetLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _brownLt, letterSpacing: 0.5)),
      ),
    );
  }

  /// Tappable field row (date, time pickers)
  Widget _sheetField(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _outline.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _purpleHdr.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: _purpleHdr),
        ),
        const SizedBox(width: 10),
        Text(text, style: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w600, color: _brown)),
      ]),
    );
  }

  /// Styled text input
  Widget _sheetInput(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _outline.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt.withOpacity(0.45)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.nunito(fontSize: 14, color: _brown),
      ),
    );
  }

  /// Selectable chip (tags, frequency, symptom types)
  Widget _sheetChip(String label, bool on, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? color.withOpacity(0.18) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on ? color.withOpacity(0.5) : _outline.withOpacity(0.08),
            width: on ? 2 : 1.5,
          ),
          boxShadow: on ? [
            BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2)),
          ] : [
            BoxShadow(color: _outline.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Text(label, style: GoogleFonts.nunito(
          fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w600,
          color: on ? color.withOpacity(0.9) : _brownLt)),
      ),
    );
  }

  /// Primary action button
  Widget _sheetButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.15)!],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Center(child: Text(label, style: GoogleFonts.gaegu(
          fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
          letterSpacing: 0.5))),
      ),
    );
  }
}

//  SMALL WIDGETS

//  HEALTH PILL — hero stat pill (matches .pill)
class _HealthPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  const _HealthPill({required this.icon, required this.label, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.28),
          offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: _outline),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.gaegu(
          fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
      ]),
    );
  }
}

//  MOOD BUTTON — coloured card wrapping a MoodSticker
//  Matches .mood-btn .mb-{state} in HTML (active + default)
class _MoodButton extends StatefulWidget {
  final String name;
  final AvatarConfig? avatar;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _MoodButton({
    required this.name, required this.avatar, required this.active,
    required this.onTap, required this.onLongPress,
  });

  @override
  State<_MoodButton> createState() => _MoodButtonState();
}

class _MoodButtonState extends State<_MoodButton>
    with TickerProviderStateMixin {
  bool _p = false;
  // Slow, always-on float loop for the selected emoji. Designed to look
  // like the sticker is gently breathing / hovering in place — smooth sine
  // curve, big enough to be visibly "alive", but slow enough (≈ 3.2s full
  // cycle) that it never feels jittery or demanding.
  late AnimationController _float;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    // easeInOutSine gives a natural breathing rhythm — no hard stops at the
    // top/bottom of the loop.
    _floatAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _float, curve: Curves.easeInOutSine),
    );
    if (widget.active) _float.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _MoodButton old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      // Start the gentle loop from 0 so the newly-selected emoji animates
      // in smoothly from rest.
      _float.value = 0;
      _float.repeat(reverse: true);
    } else if (!widget.active && old.active) {
      _float.stop();
      _float.value = 0;
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No box anywhere — selected or not. The entire strip shares one soft
    // pink mat, and selection is conveyed purely by the sticker behaviour:
    //   • elevated baseline (scale + lift) while selected
    //   • slow continuous float + breathe while selected
    //   • soft drop-shadow halo under the selected sticker
    //   • bolder label
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _p ? 2 : 0, 0),
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
        // No bg / no border — purely transparent so the strip mat shows
        // through seamlessly across all 8 slots.
        color: Colors.transparent,
        child: LayoutBuilder(builder: (ctx, lc) {
          // Balanced sizing: bigger than the original 72px cap (which read
          // tiny in the desktop strip) but nowhere near the 116px pass that
          // blew up the layout. ~88px desktop max with a ~0.55 crop gives
          // the head a noticeable ~20% bump over the prior 0.46 pass while
          // still leaving a little padding around the edges.
          final stickerSize = lc.maxWidth.clamp(48.0, 96.0).toDouble();
          final actual = stickerSize > 88 ? 88.0 : stickerSize - 4;
          final face = widget.avatar != null
              ? MoodSticker(
                  config: widget.avatar!,
                  mood: widget.name.toLowerCase(),
                  size: actual,
                  // Bumped from 0.46 → 0.55 (~20% bigger head) per the
                  // latest design pass: the previous sticker read too
                  // small next to the mood label.
                  zoom: 0.55,
                  // Bias the scale origin below center so the scaled-up
                  // head visually shifts DOWN inside the sticker frame,
                  // closing the gap between the face and the mood label
                  // beneath it. Alignment(0, 0.5) = origin halfway between
                  // center and bottom edge.
                  scaleAlignment: const Alignment(0, 0.5),
                )
              : Icon(_fallbackIcon(widget.name),
                  size: actual * 0.65, color: _outline);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animation: "jelly boing" — instead of the old slow
              // float/breathe/tilt, the selected sticker now squishes
              // horizontally / stretches vertically in a bouncy
              // figure-8 rhythm, with a tiny double-time wiggle
              // rotation and a soft bob. Reads way more alive +
              // playful than a uniform scale pulse.
              //
              // Aura: replaced the old dark drop-shadow (which read
              // as a black halo on the cream strip) with a soft
              // warm coral / pink radial gradient that BREATHES —
              // expands + brightens with the bounce. No black, no
              // hard ring; just a glow that feels lit from within.
              AnimatedBuilder(
                animation: _floatAnim,
                builder: (_, child) {
                  if (!widget.active) return child!;
                  final t = _floatAnim.value; // 0 → 1 (reverse loop)

                  // Phase shifts so squish + bob aren't perfectly in
                  // sync — gives an organic, "rubbery" feel.
                  final s1 = math.sin(t * math.pi * 2);    // -1..1
                  final s2 = math.sin(t * math.pi * 4);    // double-speed
                  final c1 = math.cos(t * math.pi * 2);    // -1..1

                  // Jelly squish: x and y scale move INVERSELY so the
                  // total volume looks roughly preserved (like a
                  // bouncy ball compressing).
                  final scaleX = 1.10 + s1 * 0.05; // 1.05 .. 1.15
                  final scaleY = 1.10 - s1 * 0.05; // 1.05 .. 1.15

                  // Subtle bob — a half-cycle out of phase with the
                  // squish so it peaks just as the sticker stretches
                  // tall (extra hop feel).
                  final bobY = -5.0 + c1 * 3.0; // -8 .. -2

                  // Wiggle: double-speed, small amplitude. Cute,
                  // not seasick.
                  final wiggle = s2 * 0.04; // ±0.04 rad ≈ ±2.3°

                  return Transform.translate(
                    offset: Offset(0, bobY),
                    child: Transform.rotate(
                      angle: wiggle,
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.identity()
                          ..scale(scaleX, scaleY, 1.0),
                        child: child,
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  width: actual, height: actual,
                  child: widget.active
                    ? AnimatedBuilder(
                        // Halo pulses on the SAME controller so the
                        // bounce + glow stay locked together.
                        animation: _floatAnim,
                        builder: (_, halo) {
                          final t = _floatAnim.value;
                          // Halo intensity rises + falls with bounce.
                          // Stays low (subtle) at rest, brighter at peak.
                          final glow = 0.18 + (math.sin(t * math.pi) * 0.18);
                          return Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Soft coral radial halo — fades from
                              // warm pink center to fully transparent.
                              // No box, no ring, no black.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          _coralHdr.withOpacity(glow),
                                          _pawClr.withOpacity(glow * 0.55),
                                          _coralHdr.withOpacity(0.0),
                                        ],
                                        stops: const [0.0, 0.45, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              halo!,
                            ],
                          );
                        },
                        child: face,
                      )
                    : face,
                ),
              ),
              const SizedBox(height: 2),
              Text(widget.name, style: GoogleFonts.gaegu(
                fontSize: 12,
                fontWeight: widget.active ? FontWeight.w800 : FontWeight.w700,
                color: _brown),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          );
        }),
      ),
    );
  }

  static IconData _fallbackIcon(String name) {
    switch (name.toLowerCase()) {
      case 'happy':    return Icons.sentiment_very_satisfied_rounded;
      case 'calm':     return Icons.spa_rounded;
      case 'excited':  return Icons.celebration_rounded;
      case 'focused':  return Icons.center_focus_strong_rounded;
      case 'tired':    return Icons.bedtime_rounded;
      case 'sad':      return Icons.sentiment_dissatisfied_rounded;
      case 'anxious':  return Icons.sentiment_neutral_rounded;
      case 'angry':    return Icons.local_fire_department_rounded;
      default:         return Icons.sentiment_satisfied_rounded;
    }
  }
}

class _WaterGlass extends StatefulWidget {
  final bool filled;
  final int index;
  final VoidCallback onTap;
  /// Compact variant — renders at ~70% scale so 8 cups fit comfortably in
  /// the left-column water strip without crowding the meds card below.
  final bool compact;

  const _WaterGlass({
    required this.filled,
    required this.index,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_WaterGlass> createState() => _WaterGlassState();
}

class _WaterGlassState extends State<_WaterGlass> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _wasFilled = false;

  @override
  void initState() {
    super.initState();
    _wasFilled = widget.filled;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_WaterGlass old) {
    super.didUpdateWidget(old);
    if (widget.filled != _wasFilled) {
      _wasFilled = widget.filled;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Compact cups (left-column strip) at ~70% scale of the standard size
    final c = widget.compact;
    final boxW = c ? 30.0 : 40.0;
    final boxH = c ? 36.0 : 48.0;
    final cupW = c ? 26.0 : 34.0;
    final cupH = c ? 36.0 : 48.0;
    final fillH = c ? 25.0 : 33.0;
    final hand = c ? 7.0 : 10.0;
    final handH = c ? 14.0 : 18.0;
    final handTop = c ? 8.0 : 10.0;
    final border = c ? 2.0 : 2.5;

    // Cup shape: rectangle with slightly wider top, rounded bottom, thick border
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          width: boxW, height: boxH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cup body
              Container(
                width: cupW, height: cupH,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  border: Border.all(color: _outline, width: border),
                  boxShadow: [
                    BoxShadow(color: _outline.withOpacity(0.3), blurRadius: 0, offset: const Offset(0, 3)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      width: double.infinity,
                      height: widget.filled ? fillH : 0,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Color(0xFFB8E8FC), Color(0xFF7DD3FC)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Handle (right side)
              Positioned(
                right: -2, top: handTop,
                child: Container(
                  width: hand, height: handH,
                  decoration: BoxDecoration(
                    border: Border.all(color: _outline, width: border),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  HEALTH MED ROW — matches HTML .med-row / .med-done-row
class _HealthMedRow extends StatefulWidget {
  final String name;
  final String dose;
  final bool taken;
  final VoidCallback onTake;
  final VoidCallback onSkip;

  const _HealthMedRow({
    required this.name,
    required this.dose,
    required this.taken,
    required this.onTake,
    required this.onSkip,
  });

  @override
  State<_HealthMedRow> createState() => _HealthMedRowState();
}

class _HealthMedRowState extends State<_HealthMedRow> {
  late bool _done;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _done = widget.taken;
  }

  @override
  void didUpdateWidget(covariant _HealthMedRow old) {
    super.didUpdateWidget(old);
    if (old.taken != widget.taken) _done = widget.taken;
  }

  @override
  Widget build(BuildContext context) {
    final done = _done || _skipped;
    final strikeName = TextStyle(
      fontFamily: GoogleFonts.nunito().fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _brown.withOpacity(done ? 0.55 : 1.0),
      decoration: done ? TextDecoration.lineThrough : null,
    );
    final doseStyle = GoogleFonts.nunito(
      fontSize: 10,
      color: _inkSoft.withOpacity(done ? 0.50 : 1.0),
      decoration: done ? TextDecoration.lineThrough : null,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.70),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _outline.withOpacity(0.20), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _outline.withOpacity(0.12),
              offset: const Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // med-dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _done ? _olive : const Color(0xFFF7AEAE),
                border: Border.all(
                  color: _done ? _oliveDk : _outline.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 9),
            // med-info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.name, style: strikeName),
                  const SizedBox(height: 1),
                  Text(widget.dose, style: doseStyle),
                ],
              ),
            ),
            // med-btns (hidden when done)
            if (!done) ...[
              const SizedBox(width: 8),
              _MedActionBtn(
                label: 'Take',
                bg: const Color(0xFF98A869).withOpacity(0.28),
                border: const Color(0xFF58772F).withOpacity(0.38),
                shadow: const Color(0xFF58772F).withOpacity(0.28),
                fg: _oliveDk,
                onTap: () {
                  setState(() => _done = true);
                  widget.onTake();
                },
              ),
              const SizedBox(width: 5),
              _MedActionBtn(
                label: 'Skip',
                bg: const Color(0xFFFDEFDB).withOpacity(0.70),
                border: _outline.withOpacity(0.22),
                shadow: _outline.withOpacity(0.18),
                fg: _inkSoft,
                onTap: () {
                  setState(() => _skipped = true);
                  widget.onSkip();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MedActionBtn extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color shadow;
  final Color fg;
  final VoidCallback onTap;

  const _MedActionBtn({
    required this.label,
    required this.bg,
    required this.border,
    required this.shadow,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: border, width: 1.5),
          boxShadow: [
            BoxShadow(color: shadow, offset: const Offset(0, 2), blurRadius: 0),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

//  INSIGHT ROW — matches HTML .insight-row.ii-{sleep|water|mood|tip}-row
class _InsightRow extends StatelessWidget {
  final String text;
  final String iconKey;

  const _InsightRow({required this.text, required this.iconKey});

  // Map iconKey → (rowBg, tileBg, tileBorder, iconColor, icon)
  ({Color rowBg, Color tileBg, Color tileBorder, Color iconColor, IconData icon})
      _variant() {
    // Canonical HTML palettes:
    //   ii-sleep → pink-lt + pink-dk svg
    //   ii-water → blue-lt + ink-mid svg
    //   ii-mood  → gold warm + bdr-dk svg
    //   ii-tip   → olive + olive-dk svg
    final k = iconKey.toLowerCase();
    if (k == 'moon' || k == 'sleep') {
      return (
        rowBg: const Color(0xFFFFD5F5).withOpacity(0.45),
        tileBg: const Color(0xFFFFD5F5).withOpacity(0.45),
        tileBorder: _outline.withOpacity(0.12),
        iconColor: _pinkDk,
        icon: Icons.nightlight_round,
      );
    } else if (k == 'water' || k == 'drop') {
      return (
        rowBg: const Color(0xFFDDF6FF).withOpacity(0.55),
        tileBg: const Color(0xFFDDF6FF).withOpacity(0.60),
        tileBorder: _outline.withOpacity(0.12),
        iconColor: _inkSoft,
        icon: Icons.water_drop_rounded,
      );
    } else if (k == 'heart' || k == 'mood') {
      return (
        rowBg: const Color(0xFFFDEFDB).withOpacity(0.60),
        tileBg: _goldWarm.withOpacity(0.30),
        tileBorder: _outline.withOpacity(0.12),
        iconColor: _outline,
        icon: Icons.favorite_rounded,
      );
    } else if (k == 'bulb' || k == 'tip') {
      return (
        rowBg: _olive.withOpacity(0.22),
        tileBg: _olive.withOpacity(0.22),
        tileBorder: _outline.withOpacity(0.12),
        iconColor: _oliveDk,
        icon: Icons.lightbulb_rounded,
      );
    } else if (k == 'fire') {
      return (
        rowBg: const Color(0xFFFDEFDB).withOpacity(0.60),
        tileBg: _goldWarm.withOpacity(0.30),
        tileBorder: _outline.withOpacity(0.12),
        iconColor: _outline,
        icon: Icons.local_fire_department_rounded,
      );
    } else if (k == 'chart_up') {
      return (
        rowBg: _olive.withOpacity(0.22),
        tileBg: _olive.withOpacity(0.22),
        tileBorder: _outline.withOpacity(0.12),
        iconColor: _oliveDk,
        icon: Icons.trending_up_rounded,
      );
    } else if (k == 'chart_down') {
      return (
        rowBg: const Color(0xFFFDEFDB).withOpacity(0.60),
        tileBg: _goldWarm.withOpacity(0.30),
        tileBorder: _outline.withOpacity(0.12),
        iconColor: _outline,
        icon: Icons.trending_down_rounded,
      );
    } else if (k == 'pill') {
      return (
        rowBg: _olive.withOpacity(0.22),
        tileBg: _olive.withOpacity(0.22),
        tileBorder: _outline.withOpacity(0.12),
        iconColor: _oliveDk,
        icon: Icons.medication_rounded,
      );
    }
    // default → tip
    return (
      rowBg: _olive.withOpacity(0.22),
      tileBg: _olive.withOpacity(0.22),
      tileBorder: _outline.withOpacity(0.12),
      iconColor: _oliveDk,
      icon: Icons.auto_awesome_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _variant();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: v.rowBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _outline.withOpacity(0.20), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.12),
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: v.tileBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: v.tileBorder, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(v.icon, size: 12, color: v.iconColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 12,
                height: 1.35,
                color: _brown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//  WELLNESS RING PAINTER
class _WellnessRingPainter extends CustomPainter {
  final double progress; // 0-1
  final int score;

  _WellnessRingPainter(this.progress, this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    // Background ring
    canvas.drawCircle(center, radius,
      Paint()
        ..color = _outline.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
    );

    // Progress arc
    if (progress > 0) {
      final color = score >= 80 ? _greenHdr
          : score >= 60 ? _goldHdr
          : score >= 40 ? _coralHdr
          : const Color(0xFFE05050);

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WellnessRingPainter old) =>
    old.progress != progress || old.score != score;
}

//  PAWPRINT BACKGROUND — matches study_tab.dart exactly
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const sp = 90.0, rs = 45.0, r = 10.0;
    int idx = 0;
    for (double y = 30; y < size.height; y += sp) {
      final odd = ((y / sp).floor() % 2) == 1;
      for (double x = (odd ? rs : 0) + 30; x < size.width; x += sp) {
        paint.color = _pawClr.withOpacity(0.07);
        final a = (idx % 4) * 0.3 - 0.3;
        canvas.save(); canvas.translate(x, y); canvas.rotate(a);
        canvas.drawOval(Rect.fromCenter(
          center: Offset.zero, width: r * 2.2, height: r * 1.8), paint);
        final t = r * 0.52;
        canvas.drawCircle(Offset(-r, -r * 1.35), t, paint);
        canvas.drawCircle(Offset(-r * 0.38, -r * 1.65), t, paint);
        canvas.drawCircle(Offset(r * 0.38, -r * 1.65), t, paint);
        canvas.drawCircle(Offset(r, -r * 1.35), t, paint);
        canvas.restore(); idx++;
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}
