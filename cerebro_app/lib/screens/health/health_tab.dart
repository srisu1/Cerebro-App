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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';
import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/widgets/mood_sticker.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';

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
    await _loadWaterFromCache();
    await _syncFromApi();
  }
  Future<void> refresh() async => _syncFromApi();

  Future<void> _loadWaterFromCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month}-${today.day}';
      final water = p.getInt('water_$dateKey') ?? 0;
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

      Map<String, dynamic>? todaysSleep;
      for (final s in sleep) {
        if ((s['date'] ?? '').toString().startsWith(today)) {
          todaysSleep = s;
          break;
        }
      }

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

      state = state.copyWith(
        sleepHistory: sleep,
        moodHistory: mood,
        medications: meds,
        todaysSleep: todaysSleep,
        todaysMood: todaysMood,
        waterGlasses: waterGlasses,
        avgSleepHours: sleep.isNotEmpty ? sleepSum / sleep.length : 0.0,
        avgMoodQuality: mood.isNotEmpty ? (moodSum / mood.length).toDouble() : 0.0,
        isLoading: false,
        wellnessScore: wellnessScore,
        insights: insights,
        weeklySummary: weeklySummary,
        moodDefinitions: moodDefs,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> incrementWater() async {
    final newVal = (state.waterGlasses + 1).clamp(0, 8);
    state = state.copyWith(waterGlasses: newVal);
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month}-${now.day}';
    await p.setInt('water_$dateKey', newVal);
    try { await _api.post('/health/water', data: {'glasses': newVal}); } catch (_) {}
  }

  Future<void> decrementWater() async {
    final newVal = (state.waterGlasses - 1).clamp(0, 8);
    state = state.copyWith(waterGlasses: newVal);
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month}-${now.day}';
    await p.setInt('water_$dateKey', newVal);
    try { await _api.post('/health/water', data: {'glasses': newVal}); } catch (_) {}
  }

  Future<void> logMedication(String medId) async {
    try {
      await _api.post('/health/medications/log', data: {
        'medication_id': medId,
        'scheduled_time': DateTime.now().toIso8601String(),
        'status': 'taken',
        'taken_at': DateTime.now().toIso8601String(),
      });
      await _syncFromApi();
    } catch (_) {}
  }

  Future<void> skipMedication(String medId) async {
    try {
      await _api.post('/health/medications/log', data: {
        'medication_id': medId,
        'scheduled_time': DateTime.now().toIso8601String(),
        'status': 'skipped',
      });
      await _syncFromApi();
    } catch (_) {}
  }

  Future<void> logMood(String moodId) async {
    try {
      await _api.post('/health/moods', data: {
        'mood_id': moodId,
      });
      await _syncFromApi();
    } catch (_) {}
  }

  Future<void> logMoodDetailed(String moodId, int energy, List<String> tags, String note) async {
    try {
      await _api.post('/health/moods', data: {
        'mood_id': moodId,
        'energy_level': energy,
        'context_tags': tags,
        'note': note,
      });
      await _syncFromApi();
    } catch (_) {}
  }

  Future<void> logSleep(String dateStr, String bedtime, String wakeTime, int quality, String notes) async {
    try {
      await _api.post('/health/sleep', data: {
        'date': dateStr,
        'bedtime': bedtime,
        'wake_time': wakeTime,
        'quality_rating': quality,
        'notes': notes,
      });
      await _syncFromApi();
    } catch (_) {}
  }

  Future<void> addMedication(String name, String dosage, String frequency) async {
    try {
      await _api.post('/health/medications', data: {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'reminder_enabled': true,
      });
      await _syncFromApi();
    } catch (_) {}
  }

  Future<void> logSymptom(String type, int intensity, List<String> triggers) async {
    try {
      await _api.post('/health/symptoms', data: {
        'symptom_type': type,
        'intensity': intensity,
        'triggers': triggers,
      });
      await _syncFromApi();
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

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  }

  int? _prevTab;

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // stagger helper
  Animation<double> _stagger(int i) =>
    CurvedAnimation(
      parent: _enterCtrl,
      curve: Interval(
        (i * 0.08).clamp(0.0, 0.7),
        ((i * 0.08) + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

  @override
  Widget build(BuildContext context) {
    // Auto-refresh when user switches TO the health tab
    final currentTab = ref.watch(selectedTabProvider);
    if (currentTab == 4 && _prevTab != 4) {
      // Just switched to Health tab — refresh data
      Future.microtask(() => ref.read(healthProvider.notifier).refresh());
    }
    _prevTab = currentTab;

    final h = ref.watch(healthProvider);
    final dash = ref.watch(dashboardProvider);
    final avatarConfig = dash.avatarConfig;

    return Stack(children: [
      // Pawprint ombré background
      Positioned.fill(child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_ombre1, _ombre2, _ombre3, _ombre4],
          stops: [0.0, 0.3, 0.6, 1.0],
        )),
      )),
      Positioned.fill(child: CustomPaint(painter: _PawPrintBg())),

      // Content
      SafeArea(child: RefreshIndicator(
        color: _coralHdr,
        onRefresh: () async {
          await ref.read(healthProvider.notifier).refresh();
          await ref.read(dashboardProvider.notifier).refresh();
        },
        child: h.isLoading
          ? const Center(child: CircularProgressIndicator(color: _coralHdr))
          : ListView(
              padding: const EdgeInsets.fromLTRB(34, 14, 34, 90),
              children: [
                // 1. Hero Header + Wellness Score
                _buildAnimated(0, _buildHeroHeader(h, avatarConfig)),
                const SizedBox(height: 20),

                // 2. Mood Check-In Strip
                _buildAnimated(1, _buildMoodStrip(h, avatarConfig)),
                const SizedBox(height: 20),

                // 3. Daily Vitals — Water + Sleep side by side
                _buildAnimated(2, _buildDailyVitals(h)),
                const SizedBox(height: 20),

                // 4. Medications Checklist
                _buildAnimated(3, _buildMedsCard(h)),
                const SizedBox(height: 20),

                // 5. AI Health Insights
                _buildAnimated(4, _buildInsightsCard(h)),
                const SizedBox(height: 20),

                // 6. Symptom Quick-Log + Weekly Trends row
                _buildAnimated(5, _buildBottomRow(h)),
                const SizedBox(height: 20),

                // 7. History Button
                _buildAnimated(6, _buildHistoryButton()),
                const SizedBox(height: 20),
              ],
            ),
      )),
    ]);
  }

  Widget _buildAnimated(int i, Widget child) {
    final anim = _stagger(i);
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }

  //  1. HERO HEADER WITH WELLNESS RING
  Widget _buildHeroHeader(HealthData h, AvatarConfig? avatar) {
    final ringColor = h.wellnessScore >= 80 ? _greenHdr
        : h.wellnessScore >= 60 ? _goldHdr
        : h.wellnessScore >= 40 ? _coralHdr
        : const Color(0xFFE88080);

    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Column(children: [
      Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(children: [
        // Wellness Score Ring
        SizedBox(
          width: 100, height: 100,
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
                Text('${h.wellnessScore}',
                  style: GoogleFonts.gaegu(
                    fontSize: 34, fontWeight: FontWeight.w700, color: ringColor)),
                Text('wellness', style: GoogleFonts.nunito(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: _brownLt, letterSpacing: 0.5)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right side: title + message + stats
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Health Today',
              style: GoogleFonts.gaegu(
                fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 3),
            Text(_wellnessMessage(h.wellnessScore),
              style: GoogleFonts.nunito(
                fontSize: 12, color: _brownLt, height: 1.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            // Mini stats
            Wrap(spacing: 8, runSpacing: 6, children: [
              _miniStat(Icons.bedtime_rounded,
                '${h.avgSleepHours.toStringAsFixed(1)}h', _purpleHdr),
              _miniStat(Icons.water_drop_rounded,
                '${h.waterGlasses}/8', _skyHdr),
              if (h.medications.isNotEmpty)
                _miniStat(Icons.medication_rounded,
                  '${(h.weeklySummary['med_adherence_pct'] ?? 0).toStringAsFixed(0)}%', _coralHdr),
            ]),
          ],
        )),
      ]),
      ),
      ]),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
      ]),
    );
  }

  String _wellnessMessage(int score) {
    if (score >= 80) return "You're doing amazing! Keep up the great habits.";
    if (score >= 60) return "Pretty good! A little more sleep or water could push you higher.";
    if (score >= 40) return "Room for improvement — log your activities to boost your score!";
    return "Let's get you feeling better. Start with one healthy action today.";
  }

  //  2. MOOD CHECK-IN STRIP
  Widget _buildMoodStrip(HealthData h, AvatarConfig? avatar) {
    final defs = h.moodDefinitions;
    final hasMood = h.todaysMood != null;

    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [_goldLt, _goldHdr],
              ),
            ),
            child: Row(children: [
              const Icon(Icons.emoji_emotions_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                hasMood ? 'Feeling ${h.todaysMood?['mood_name'] ?? '...'}' : 'How are you feeling?',
                style: GoogleFonts.gaegu(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
              const Spacer(),
              if (hasMood)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Logged!', style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _greenDk)),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          // Mood stickers — evenly distributed, big 3D pop stickers
          defs.isEmpty
            ? SizedBox(
                height: 100,
                child: Center(child: Text('Loading moods...',
                  style: GoogleFonts.nunito(fontSize: 12, color: _brownLt))))
            : LayoutBuilder(builder: (context, constraints) {
                final count = defs.length;
                final available = constraints.maxWidth;
                final chipW = (available / count).clamp(60.0, 120.0);
                final stickerSize = (chipW - 8).clamp(50.0, 100.0);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(count, (i) {
                    final def = defs[i];
                    final name = (def['name'] as String?) ?? '';
                    final id = (def['id'] as String?) ?? '';
                    final isSelected = h.todaysMood?['mood_id'] == id;
                    return _MoodChip(
                      name: name,
                      avatar: avatar,
                      isSelected: isSelected,
                      index: i,
                      stickerSize: stickerSize,
                      onTap: () => _onMoodTap(id, name),
                      onLongPress: () => _showMoodDetailSheet(id, name),
                    );
                  }),
                );
              }),
          const SizedBox(height: 10),
        ],
      ),
      ),
    );
  }

  void _onMoodTap(String moodId, String name) {
    ref.read(healthProvider.notifier).logMood(moodId);
    // Sync mood to dashboard so it shows on the home screen too (local only, no double-post)
    ref.read(dashboardProvider.notifier).setMoodLocally(name);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _goldLt,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _goldDk.withOpacity(0.3), width: 2)),
      content: Text('Feeling $name — logged!', style: GoogleFonts.gaegu(
        fontWeight: FontWeight.w700, color: _brown, fontSize: 15)),
      duration: const Duration(seconds: 2),
    ));
  }

  //  3. WATER GLASSES
  //  3. DAILY VITALS — Water + Sleep side by side
  Widget _buildDailyVitals(HealthData h) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildWaterHalf(h)),
        const SizedBox(width: 12),
        Expanded(child: _buildSleepHalf(h)),
      ],
    );
  }

  Widget _buildWaterHalf(HealthData h) {
    final filled = h.waterGlasses;
    final goalMet = filled >= 8;
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Column(
        children: [
          // Sky blue header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [_skyLt, _skyHdr],
              ),
            ),
            child: Row(children: [
              const Icon(Icons.water_drop_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text('Water', style: GoogleFonts.gaegu(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
              const Spacer(),
              Text('$filled / 8', style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _brown)),
            ]),
          ),
          if (goalMet) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _greenHdr.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Goal met!', style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w700, color: _greenDk)),
            ),
          ],
          const SizedBox(height: 12),
          // 4x2 grid of cup-style glasses
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(8, (i) => _WaterGlass(
              filled: i < filled,
              index: i,
              onTap: () {
                if (i < filled) {
                  final target = i;
                  for (int j = filled; j > target; j--) {
                    ref.read(healthProvider.notifier).decrementWater();
                  }
                } else {
                  for (int j = filled; j <= i; j++) {
                    ref.read(healthProvider.notifier).incrementWater();
                  }
                }
              },
            )),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSleepHalf(HealthData h) {
    final logged = h.todaysSleep != null;
    final hours = double.tryParse(h.todaysSleep?['total_hours']?.toString() ?? '0') ?? 0;
    final quality = (h.todaysSleep?['quality_rating'] as int?) ?? 0;

    return GestureDetector(
      onTap: () => _showSleepSheet(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline, width: 3),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
              offset: const Offset(0, 4), blurRadius: 0)],
        ),
        child: Column(
          children: [
            // Moon icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_purpleHdr.withOpacity(0.3), _purpleLt.withOpacity(0.2)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                logged ? Icons.nightlight_round : Icons.bedtime_outlined,
                color: _purpleHdr, size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(logged ? 'Last Night' : 'Log Sleep',
              style: GoogleFonts.gaegu(
                fontSize: 17, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 6),
            if (logged) ...[
              _sleepBadge(hours),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => Icon(
                  i < quality ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: i < quality ? _goldHdr : _brownLt.withOpacity(0.3),
                )),
              ),
            ] else
              Text('Tap to log', style: GoogleFonts.nunito(
                fontSize: 12, color: _brownLt)),
          ],
        ),
      ),
    );
  }

  Widget _sleepBadge(double hours) {
    final color = hours >= 7 && hours <= 9 ? _greenHdr
        : hours >= 6 ? _goldHdr : _coralHdr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text('${hours.toStringAsFixed(1)}h',
        style: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w800, color: _brown)),
    );
  }

  //  5. MEDICATIONS CHECKLIST
  Widget _buildMedsCard(HealthData h) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.medication_rounded, color: _coralHdr, size: 20),
            const SizedBox(width: 8),
            Text("Today's Meds", style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
            const Spacer(),
            GestureDetector(
              onTap: () => _showAddMedSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _coralHdr.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 14, color: _coralHdr),
                  const SizedBox(width: 2),
                  Text('Add', style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _brown)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (h.medications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(Icons.add_circle_outline_rounded, color: _brownLt.withOpacity(0.4), size: 20),
                const SizedBox(width: 8),
                Text('No medications yet — tap Add to track one',
                  style: GoogleFonts.nunito(fontSize: 12, color: _brownLt)),
              ]),
            )
          else
            ...h.medications.map((med) => _MedItem(
              name: med['name'] ?? '',
              dosage: med['dosage'] ?? '',
              onTake: () => ref.read(healthProvider.notifier).logMedication(med['id']),
              onSkip: () => ref.read(healthProvider.notifier).skipMedication(med['id']),
            )),
        ],
      ),
    );
  }

  //  6. AI HEALTH INSIGHTS
  Widget _buildInsightsCard(HealthData h) {
    if (h.insights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline, width: 3),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
              offset: const Offset(0, 4), blurRadius: 0)],
        ),
        child: Row(children: [
          Icon(Icons.auto_awesome_rounded, color: _sageHdr, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(
            'Log your activities to unlock personalized health insights!',
            style: GoogleFonts.nunito(fontSize: 13, color: _brownLt, height: 1.3),
          )),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, color: _sageHdr, size: 20),
            const SizedBox(width: 8),
            Text('Health Insights', style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
          ]),
          const SizedBox(height: 12),
          ...h.insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_insightIconData(insight['icon'] ?? ''),
                  size: 18, color: _greenDk),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  insight['text'] ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: 13, color: _brown, height: 1.4),
                )),
              ],
            ),
          )),
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

  //  7. BOTTOM ROW — Symptom Quick-Log + Weekly Trends
  Widget _buildBottomRow(HealthData h) {
    return Row(children: [
      // Symptom quick-log
      Expanded(child: GestureDetector(
        onTap: () => _showSymptomSheet(),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outline, width: 3),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
                offset: const Offset(0, 4), blurRadius: 0)],
          ),
          child: Column(children: [
            Icon(Icons.healing_rounded, color: _coralHdr, size: 28),
            const SizedBox(height: 8),
            Text('Feeling off?', style: GoogleFonts.gaegu(
              fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
            Text('Log symptom', style: GoogleFonts.nunito(
              fontSize: 11, color: _brownLt)),
          ]),
        ),
      )),
      const SizedBox(width: 12),
      // Weekly trends mini
      Expanded(child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline, width: 3),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
              offset: const Offset(0, 4), blurRadius: 0)],
        ),
        child: Column(children: [
          Text('This Week', style: GoogleFonts.gaegu(
            fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(height: 8),
          // Mini bar chart from sleep history
          SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final sleepVal = i < h.sleepHistory.length
                    ? (double.tryParse(h.sleepHistory[h.sleepHistory.length - 1 - i]['total_hours']?.toString() ?? '0') ?? 0)
                    : 0.0;
                final barH = (sleepVal / 10.0 * 36).clamp(2.0, 36.0);
                final color = sleepVal >= 7 ? _greenHdr
                    : sleepVal >= 5 ? _goldHdr : _coralHdr.withOpacity(0.5);
                return Container(
                  width: 8,
                  height: barH,
                  decoration: BoxDecoration(
                    color: sleepVal > 0 ? color : _outline.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Text('${h.weeklySummary['days_tracked'] ?? 0} days tracked',
            style: GoogleFonts.nunito(fontSize: 11, color: _brownLt)),
        ]),
      )),
    ]);
  }

  //  8. HISTORY BUTTON
  Widget _buildHistoryButton() {
    return GestureDetector(
      onTap: () => _showHistorySheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline, width: 3),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
              offset: const Offset(0, 4), blurRadius: 0)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_rounded, color: _brownLt, size: 20),
          const SizedBox(width: 8),
          Text('View Health History', style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: _brownLt.withOpacity(0.5), size: 20),
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
                ref.read(healthProvider.notifier).logMoodDetailed(
                  moodId, energy, selectedTags, noteCtrl.text);
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F2FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _sheetHandle(),
              Icon(Icons.nightlight_round, color: _purpleHdr, size: 32),
              const SizedBox(height: 8),
              Text('Log Sleep', style: GoogleFonts.gaegu(
                fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
              const SizedBox(height: 20),

              // Date
              _sheetLabel('Date'),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
                child: _sheetField(Icons.calendar_today_rounded,
                  '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}'),
              ),
              const SizedBox(height: 12),

              // Bedtime + Wake time row
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: bedtime);
                    if (t != null) setSheetState(() => bedtime = t);
                  },
                  child: _sheetField(Icons.bedtime_rounded,
                    'Bed: ${bedtime.format(ctx)}'),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: wakeTime);
                    if (t != null) setSheetState(() => wakeTime = t);
                  },
                  child: _sheetField(Icons.wb_sunny_rounded,
                    'Wake: ${wakeTime.format(ctx)}'),
                )),
              ]),
              const SizedBox(height: 16),

              // Quality stars
              _sheetLabel('Sleep Quality'),
              Row(mainAxisAlignment: MainAxisAlignment.center, children:
                List.generate(5, (i) => GestureDetector(
                  onTap: () => setSheetState(() => quality = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        i < quality ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 36, color: i < quality ? _goldHdr : _brownLt.withOpacity(0.2)),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 16),

              _sheetInput(noteCtrl, 'Notes (optional)'),
              const SizedBox(height: 20),

              _sheetButton('Log Sleep', _purpleHdr, () {
              final m = selectedDate.month.toString().padLeft(2, '0');
              final d = selectedDate.day.toString().padLeft(2, '0');
              final dateStr = '${selectedDate.year}-$m-$d';
              // Build bedtime/waketime as full ISO datetime
              final bedDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
                bedtime.hour, bedtime.minute);
              // Wake time is next day (safe across month boundaries)
              final nextDay = selectedDate.add(const Duration(days: 1));
              final wakeDt = DateTime(nextDay.year, nextDay.month, nextDay.day,
                wakeTime.hour, wakeTime.minute);
              ref.read(healthProvider.notifier).logSleep(
                dateStr, bedDt.toIso8601String(), wakeDt.toIso8601String(),
                quality, noteCtrl.text);
              // Refresh dashboard so sleep shows on home screen
              ref.read(dashboardProvider.notifier).refresh();
              // Check if sleep streak achievement unlocked
              ref.read(dashboardProvider.notifier).checkAchievements();
              Navigator.pop(ctx);
            }),
          ]),
        ),
      ),
      ),
    );
  }

  void _showAddMedSheet() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    String frequency = 'daily';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF6F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _sheetHandle(),
              Icon(Icons.medication_rounded, color: _coralHdr, size: 32),
              const SizedBox(height: 8),
              Text('Add Medication', style: GoogleFonts.gaegu(
                fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
              const SizedBox(height: 20),

              _sheetLabel('Medication'),
              _sheetInput(nameCtrl, 'Medication name'),
              const SizedBox(height: 12),
              _sheetInput(dosageCtrl, 'Dosage (e.g. 500mg)'),
              const SizedBox(height: 16),

              // Frequency chips
              _sheetLabel('Frequency'),
              Row(mainAxisAlignment: MainAxisAlignment.center, children:
                ['daily', 'weekly', 'as_needed'].map((f) {
                  final on = frequency == f;
                  final label = f == 'as_needed' ? 'As needed' : f[0].toUpperCase() + f.substring(1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _sheetChip(label, on, _coralHdr,
                      () => setSheetState(() => frequency = f)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              _sheetButton('Add Medication', _coralHdr, () {
                if (nameCtrl.text.isNotEmpty && dosageCtrl.text.isNotEmpty) {
                  ref.read(healthProvider.notifier).addMedication(
                    nameCtrl.text, dosageCtrl.text, frequency);
                  Navigator.pop(ctx);
                }
              }),
            ]),
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
    final types = ['Headache', 'Fatigue', 'Back Pain', 'Eye Strain', 'Nausea', 'Dizziness', 'Stomach Pain', 'Other'];
    final triggers = ['Studying', 'Lack of sleep', 'Stress', 'Caffeine', 'Dehydration', 'Screen time', 'Poor posture', 'Skipped meals'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF4F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _sheetHandle(),
              Icon(Icons.healing_rounded, color: _coralHdr, size: 32),
              const SizedBox(height: 8),
              Text('Log Symptom', style: GoogleFonts.gaegu(
                fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
              const SizedBox(height: 20),

              // Type chips
              _sheetLabel("What's bothering you?"),
              Wrap(spacing: 8, runSpacing: 10, children: types.map((t) {
                final on = (t == 'Other') ? isCustom : (type == t && !isCustom);
                return _sheetChip(t, on, _coralHdr, () => setSheetState(() {
                  if (t == 'Other') { isCustom = true; type = ''; }
                  else { isCustom = false; type = t; }
                }));
              }).toList()),

              if (isCustom) ...[
                const SizedBox(height: 12),
                _sheetInput(customCtrl, 'Describe your symptom'),
              ],
              const SizedBox(height: 16),

              // Intensity
              _sheetLabel('Intensity: $intensity/10'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _outline.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    activeTrackColor: _intensityColor(intensity),
                    inactiveTrackColor: _outline.withOpacity(0.08),
                    thumbColor: _intensityColor(intensity),
                    overlayColor: _intensityColor(intensity).withOpacity(0.15),
                  ),
                  child: Slider(
                    value: intensity.toDouble(),
                    min: 1, max: 10, divisions: 9,
                    onChanged: (v) => setSheetState(() => intensity = v.round()),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Triggers
              _sheetLabel('Possible triggers'),
              Wrap(spacing: 8, runSpacing: 10, children: triggers.map((t) {
                final on = selectedTriggers.contains(t);
                return _sheetChip(t, on, _coralHdr, () => setSheetState(() {
                  on ? selectedTriggers.remove(t) : selectedTriggers.add(t);
                }));
              }).toList()),
              const SizedBox(height: 20),

              _sheetButton('Log Symptom', _coralHdr, () {
                final symptomType = isCustom ? customCtrl.text : type;
                if (symptomType.isNotEmpty) {
                  ref.read(healthProvider.notifier).logSymptom(symptomType, intensity, selectedTriggers);
                  Navigator.pop(ctx);
                }
              }),
            ]),
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

class _MoodChip extends StatefulWidget {
  final String name;
  final AvatarConfig? avatar;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int index;
  final double stickerSize;

  const _MoodChip({
    required this.name,
    required this.avatar,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.index = 0,
    this.stickerSize = 70,
  });

  @override
  State<_MoodChip> createState() => _MoodChipState();
}

class _MoodChipState extends State<_MoodChip>
    with TickerProviderStateMixin {
  // Tap squish animation
  late AnimationController _tapCtrl;
  late Animation<double> _tapAnim;

  // Entrance bounce
  late AnimationController _enterCtrl;
  late Animation<double> _enterScale;
  late Animation<double> _enterSlide;

  // Idle wobble for selected
  late AnimationController _wobbleCtrl;

  @override
  void initState() {
    super.initState();

    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 350),
    );
    _tapAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut,
        reverseCurve: Curves.elasticOut),
    );

    // Staggered entrance — pop + slide up
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _enterScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.elasticOut),
    );
    _enterSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
    );

    // Idle wobble for selected sticker
    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Stagger entrance
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _enterCtrl.forward();
    });

    if (widget.isSelected) _wobbleCtrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _MoodChip old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !_wobbleCtrl.isAnimating) {
      _wobbleCtrl.repeat();
    } else if (!widget.isSelected && _wobbleCtrl.isAnimating) {
      _wobbleCtrl.stop();
    }
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    _enterCtrl.dispose();
    _wobbleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;
    final sz = widget.stickerSize;

    return AnimatedBuilder(
      animation: Listenable.merge([_tapAnim, _enterCtrl, _wobbleCtrl]),
      builder: (context, child) {
        // Wobble: gentle rotation + float for selected
        final wobbleAngle = sel
            ? math.sin(_wobbleCtrl.value * math.pi * 2) * 0.04
            : 0.0;
        final wobbleY = sel
            ? math.sin(_wobbleCtrl.value * math.pi * 2) * 2.5
            : 0.0;

        return Transform.translate(
          offset: Offset(0, _enterSlide.value - wobbleY),
          child: Transform.scale(
            scale: _enterScale.value * _tapAnim.value,
            child: Transform.rotate(
              angle: wobbleAngle,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _tapCtrl.forward(),
        onTapUp: (_) { _tapCtrl.reverse(); widget.onTap(); },
        onTapCancel: () => _tapCtrl.reverse(),
        onLongPress: widget.onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.avatar != null
                ? MoodSticker(
                    config: widget.avatar!,
                    mood: widget.name.toLowerCase(),
                    size: sz,
                    zoom: 1.4,
                  )
                : SizedBox(
                    width: sz, height: sz,
                    child: Center(child: Icon(
                      _moodIcon(widget.name),
                      size: sz * 0.55, color: _brownLt))),
            const SizedBox(height: 3),
            Text(
              widget.name,
              style: GoogleFonts.nunito(
                fontSize: sel ? 12 : 11,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                color: sel ? _brown : _brownLt,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: sel ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                width: 5, height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _goldDk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _moodIcon(String name) {
    switch (name.toLowerCase()) {
      case 'happy': return Icons.sentiment_very_satisfied_rounded;
      case 'sad': return Icons.sentiment_dissatisfied_rounded;
      case 'anxious': return Icons.sentiment_neutral_rounded;
      case 'calm': return Icons.spa_rounded;
      case 'energetic': return Icons.bolt_rounded;
      case 'tired': return Icons.bedtime_rounded;
      case 'stressed': return Icons.psychology_rounded;
      case 'focused': return Icons.center_focus_strong_rounded;
      default: return Icons.sentiment_satisfied_rounded;
    }
  }
}

class _WaterGlass extends StatefulWidget {
  final bool filled;
  final int index;
  final VoidCallback onTap;

  const _WaterGlass({required this.filled, required this.index, required this.onTap});

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
    // Cup shape: rectangle with slightly wider top, rounded bottom, thick border
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          width: 40, height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cup body
              Container(
                width: 34, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  border: Border.all(color: _outline, width: 2.5),
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
                      height: widget.filled ? 33 : 0,
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
                right: -2, top: 10,
                child: Container(
                  width: 10, height: 18,
                  decoration: BoxDecoration(
                    border: Border.all(color: _outline, width: 2.5),
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

class _MedItem extends StatefulWidget {
  final String name;
  final String dosage;
  final VoidCallback onTake;
  final VoidCallback onSkip;

  const _MedItem({
    required this.name, required this.dosage,
    required this.onTake, required this.onSkip,
  });

  @override State<_MedItem> createState() => _MedItemState();
}

class _MedItemState extends State<_MedItem> {
  bool _taken = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        // Checkbox
        GestureDetector(
          onTap: () {
            if (!_taken) {
              setState(() => _taken = true);
              widget.onTake();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _taken ? _greenHdr : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _taken ? _greenDk : _outline.withOpacity(0.3), width: 2),
            ),
            child: _taken
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name, style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w700, color: _brown,
              decoration: _taken ? TextDecoration.lineThrough : null)),
            Text(widget.dosage, style: GoogleFonts.nunito(
              fontSize: 11, color: _brownLt)),
          ],
        )),
        // Skip button
        if (!_taken) GestureDetector(
          onTap: () {
            setState(() => _taken = true);
            widget.onSkip();
          },
          child: Text('Skip', style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt.withOpacity(0.6))),
        ),
      ]),
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

//  PAWPRINT BACKGROUND PAINTER
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const gridSpacing = 90.0;
    final opacities = [0.06, 0.08, 0.10, 0.12, 0.14, 0.16];
    int opacityIndex = 0;

    // Draw pawprints in a 90px staggered grid pattern
    for (double y = -50; y < size.height + 50; y += gridSpacing) {
      final isStaggeredRow = ((y + 50) / gridSpacing).toInt() % 2 == 1;
      final double xOffset = isStaggeredRow ? gridSpacing / 2 : 0.0;

      for (double x = -50 + xOffset; x < size.width + 50; x += gridSpacing) {
        final paint = Paint()..color = _pawClr.withOpacity(opacities[opacityIndex % opacities.length]);
        opacityIndex++;

        canvas.save();
        canvas.translate(x, y);
        _drawPaw(canvas, 18.0, paint);
        canvas.restore();
      }
    }
  }

  void _drawPaw(Canvas canvas, double s, Paint paint) {
    canvas.drawOval(Rect.fromCenter(
      center: Offset(0, s * 0.2), width: s * 0.7, height: s * 0.55), paint);
    for (final off in [
      Offset(-s * 0.28, -s * 0.2),
      Offset(s * 0.28, -s * 0.2),
      Offset(-s * 0.12, -s * 0.38),
      Offset(s * 0.12, -s * 0.38),
    ]) {
      canvas.drawCircle(off, s * 0.14, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
