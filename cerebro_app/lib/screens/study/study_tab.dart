/// Sneak-peek overview — each feature has its own page.
/// Centered timer hero with circular controls (user-approved style).
/// Warm Pocket Love aesthetic, visual variety, no endless scroll.
///
/// Layout:
///  1. Header row (title + XP pill)
///  2. Timer Hero (centered, warm cream/gold, circular buttons)
///  3. Quick Actions (5 cozy game buttons — 2 rows)
///  4. Feature Peek — 2×2 cards with distinct visual styles
///  5. Study Resources teaser banner
///  6. Study Insight

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';

const _ombre1  = Color(0xFFFFFBF7);
const _ombre2  = Color(0xFFFFF8F3);
const _ombre3  = Color(0xFFFFF3EF);
const _ombre4  = Color(0xFFFEEDE9);
const _pawClr  = Color(0xFFF8BCD0);

const _outline = Color(0xFF6E5848);
const _brown   = Color(0xFF4E3828);
const _brownLt = Color(0xFF7A5840);

const _cardFill = Color(0xFFFFF8F4);
const _goldGlow = Color(0xFFF8E080);

const _skyHdr   = Color(0xFF9DD4F0);
const _skyDk    = Color(0xFF6BB8E0);
const _pinkHdr  = Color(0xFFE8B0A8);
const _pinkLt   = Color(0xFFF0C0B8);
const _greenHdr = Color(0xFFA8D5A3);
const _greenLt  = Color(0xFFC2E8BC);
const _greenDk  = Color(0xFF88B883);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _purpleDk = Color(0xFFAA88C0);
const _coralHdr = Color(0xFFF0A898);
const _coralLt  = Color(0xFFF8C0B0);
const _goldHdr  = Color(0xFFF0D878);
const _goldDk   = Color(0xFFD4B850);
const _sageHdr  = Color(0xFF90C8A0);
const _sageLt   = Color(0xFFB0D8B8);
const _sageDk   = Color(0xFF70A880);

//  STUDY DATA MODEL + PROVIDER
class StudyData {
  final int todayMinutes, todaySessions, avgFocus;
  final int weeklyMinutes, weeklySessions, totalXpEarned;
  final int cardsDue, totalCards, masteredCards, cardStreak;
  final int quizCount;
  final double avgQuizScore;
  final List<String> weakTopics;
  final List<Map<String, dynamic>> recentQuizzes;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> recentSessions;
  final List<int> weeklyActivity;
  final bool isLoading;

  const StudyData({
    this.todayMinutes = 0, this.todaySessions = 0, this.avgFocus = 0,
    this.weeklyMinutes = 0, this.weeklySessions = 0, this.totalXpEarned = 0,
    this.cardsDue = 0, this.totalCards = 0, this.masteredCards = 0,
    this.cardStreak = 0, this.quizCount = 0, this.avgQuizScore = 0.0,
    this.weakTopics = const [], this.recentQuizzes = const [],
    this.subjects = const [], this.recentSessions = const [],
    this.weeklyActivity = const [0, 0, 0, 0, 0, 0, 0],
    this.isLoading = true,
  });

  StudyData copyWith({
    int? todayMinutes, int? todaySessions, int? avgFocus,
    int? weeklyMinutes, int? weeklySessions, int? totalXpEarned,
    int? cardsDue, int? totalCards, int? masteredCards, int? cardStreak,
    int? quizCount, double? avgQuizScore, List<String>? weakTopics,
    List<Map<String, dynamic>>? recentQuizzes,
    List<Map<String, dynamic>>? subjects,
    List<Map<String, dynamic>>? recentSessions,
    List<int>? weeklyActivity, bool? isLoading,
  }) => StudyData(
    todayMinutes: todayMinutes ?? this.todayMinutes,
    todaySessions: todaySessions ?? this.todaySessions,
    avgFocus: avgFocus ?? this.avgFocus,
    weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
    weeklySessions: weeklySessions ?? this.weeklySessions,
    totalXpEarned: totalXpEarned ?? this.totalXpEarned,
    cardsDue: cardsDue ?? this.cardsDue,
    totalCards: totalCards ?? this.totalCards,
    masteredCards: masteredCards ?? this.masteredCards,
    cardStreak: cardStreak ?? this.cardStreak,
    quizCount: quizCount ?? this.quizCount,
    avgQuizScore: avgQuizScore ?? this.avgQuizScore,
    weakTopics: weakTopics ?? this.weakTopics,
    recentQuizzes: recentQuizzes ?? this.recentQuizzes,
    subjects: subjects ?? this.subjects,
    recentSessions: recentSessions ?? this.recentSessions,
    weeklyActivity: weeklyActivity ?? this.weeklyActivity,
    isLoading: isLoading ?? this.isLoading,
  );
}

class StudyNotifier extends StateNotifier<StudyData> {
  final ApiService _api;
  StudyNotifier(this._api) : super(const StudyData()) { loadAll(); }

  Future<void> loadAll() async {
    await _loadFromCache();
    await _syncFromApi();
  }
  Future<void> refresh() async => _syncFromApi();

  Future<void> _loadFromCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = state.copyWith(
        todayMinutes: p.getInt('study_today_min') ?? 0,
        todaySessions: p.getInt('study_today_sess') ?? 0,
        avgFocus: p.getInt('study_avg_focus') ?? 0,
        isLoading: false,
      );
    } catch (_) {}
  }

  Future<void> _syncFromApi() async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final sessRes = await _api.get('/study/sessions');
      final sessions = sessRes.data is List ? sessRes.data as List : [];
      int todayMin = 0, todayN = 0, focusS = 0, focusN = 0;
      int weekMin = 0, weekN = 0, totalXp = 0;
      final List<int> wk = [0, 0, 0, 0, 0, 0, 0];
      final List<Map<String, dynamic>> recent = [];

      for (final s in sessions) {
        DateTime? t;
        try { t = DateTime.parse(s['start_time'] ?? s['created_at'] ?? ''); } catch (_) { continue; }
        final dur = (s['duration_minutes'] ?? 0) as int;
        final foc = (s['focus_score'] ?? 0) as int;
        final xp = (s['xp_earned'] ?? 0) as int;
        totalXp += xp;
        if (t.year == now.year && t.month == now.month && t.day == now.day) {
          todayMin += dur; todayN++;
          if (foc > 0) { focusS += foc; focusN++; }
        }
        if (t.isAfter(weekAgo)) {
          weekMin += dur; weekN++;
          final d = t.weekday - 1;
          if (d >= 0 && d < 7) wk[d] += dur;
        }
        if (recent.length < 5) recent.add({
          'title': s['title'] ?? 'Study Session', 'type': s['session_type'] ?? 'focused',
          'duration': dur, 'focus': foc, 'xp': xp, 'date': t,
        });
      }

      List<Map<String, dynamic>> subs = [];
      try {
        final r = await _api.get('/study/subjects');
        for (final s in (r.data is List ? r.data as List : [])) {
          subs.add({
            'id': s['id'], 'name': s['name'] ?? 'Untitled',
            'code': s['code'] ?? '', 'color': s['color'] ?? '#9DD4F0',
            'icon': s['icon'] ?? 'book',
            'proficiency': (s['current_proficiency'] ?? 0.0).toDouble(),
            'target': (s['target_proficiency'] ?? 100.0).toDouble(),
          });
        }
      } catch (_) {}

      int cardsDue = 0, totalCards = 0, mastered = 0, maxStreak = 0;
      try {
        final allCards = await _api.get('/study/flashcards');
        final cards = allCards.data is List ? allCards.data as List : [];
        totalCards = cards.length;
        for (final c in cards) {
          if ((c['correct_reviews'] ?? 0) as int >= 5) mastered++;
          final streak = (c['streak_days'] ?? 0) as int;
          if (streak > maxStreak) maxStreak = streak;
          try {
            final nr = DateTime.parse(c['next_review_date'] ?? '');
            if (!nr.isAfter(now)) cardsDue++;
          } catch (_) { cardsDue++; }
        }
      } catch (_) {}

      int quizCount = 0; double scoreSum = 0;
      final Set<String> weakSet = {};
      final List<Map<String, dynamic>> recentQuiz = [];
      try {
        final qRes = await _api.get('/study/quizzes');
        final quizzes = qRes.data is List ? qRes.data as List : [];
        quizCount = quizzes.length;
        for (final q in quizzes) {
          final sc = (q['score_achieved'] ?? 0).toDouble();
          final mx = (q['max_score'] ?? 100).toDouble();
          final pct = mx > 0 ? sc / mx * 100 : 0.0;
          scoreSum += pct;
          final weak = q['weak_topics'];
          if (weak is List) for (final t in weak) { if (t is String) weakSet.add(t); }
          if (recentQuiz.length < 3) recentQuiz.add({
            'title': q['title'] ?? 'Quiz', 'type': q['quiz_type'] ?? 'test',
            'score': pct.round(), 'date': q['date_taken'] ?? '',
          });
        }
      } catch (_) {}

      state = state.copyWith(
        todayMinutes: todayMin, todaySessions: todayN,
        avgFocus: focusN > 0 ? (focusS / focusN).round() : 0,
        weeklyMinutes: weekMin, weeklySessions: weekN, totalXpEarned: totalXp,
        cardsDue: cardsDue, totalCards: totalCards, masteredCards: mastered,
        cardStreak: maxStreak, quizCount: quizCount,
        avgQuizScore: quizCount > 0 ? scoreSum / quizCount : 0,
        weakTopics: weakSet.toList(), recentQuizzes: recentQuiz,
        subjects: subs, recentSessions: recent, weeklyActivity: wk,
        isLoading: false,
      );

      final p = await SharedPreferences.getInstance();
      await p.setInt('study_today_min', todayMin);
      await p.setInt('study_today_sess', todayN);
      await p.setInt('study_avg_focus', focusN > 0 ? (focusS / focusN).round() : 0);
    } catch (_) { state = state.copyWith(isLoading: false); }
  }
}

final studyProvider = StateNotifierProvider<StudyNotifier, StudyData>((ref) {
  return StudyNotifier(ref.watch(apiServiceProvider));
});

//  STUDY TAB WIDGET
class StudyTab extends ConsumerStatefulWidget {
  const StudyTab({super.key});
  @override ConsumerState<StudyTab> createState() => _StudyTabState();
}

class _StudyTabState extends ConsumerState<StudyTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  int? _prevTab;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }
  @override void dispose() { _enterCtrl.dispose(); super.dispose(); }

  String _fmt(int m) {
    if (m == 0) return '0m';
    final h = m ~/ 60, r = m % 60;
    if (h == 0) return '${r}m';
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  void _comingSoon(String f) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _cardFill,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _outline.withOpacity(0.3), width: 2)),
      content: Text('$f coming soon!', style: GoogleFonts.gaegu(
        fontWeight: FontWeight.w700, color: _brown, fontSize: 15)),
    ));
  }

  //  BUILD
  @override
  Widget build(BuildContext context) {
    // Auto-refresh when user switches TO the study tab
    final currentTab = ref.watch(selectedTabProvider);
    if (currentTab == 2 && _prevTab != 2) {
      Future.microtask(() => ref.read(studyProvider.notifier).refresh());
    }
    _prevTab = currentTab;

    final s = ref.watch(studyProvider);
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
      // Warm golden glow (NOT blue)
      Positioned(top: -120, left: 0, right: 0, child: Container(
        height: 300,
        decoration: BoxDecoration(gradient: RadialGradient(
          center: Alignment.topCenter, radius: 1.0,
          colors: [_goldGlow.withOpacity(0.12), Colors.transparent],
        )),
      )),
      // Content
      SafeArea(child: RefreshIndicator(
        color: _outline, backgroundColor: _cardFill,
        onRefresh: () => ref.read(studyProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(34, 14, 34, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stag(0.00, _header(s)),
              const SizedBox(height: 20),
              _stag(0.06, _timerHero(s)),
              const SizedBox(height: 20),
              _stag(0.12, _quickActions()),
              const SizedBox(height: 20),
              _stag(0.18, _peekRow1(s)),
              const SizedBox(height: 14),
              _stag(0.24, _peekRow2(s)),
              const SizedBox(height: 14),
              _stag(0.30, _resourcesTeaser()),
              const SizedBox(height: 10),
              _stag(0.33, _calendarTeaser()),
              const SizedBox(height: 20),
              _stag(0.36, _insightCard(s)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      )),
    ]);
  }

  //  1. HEADER — title + stat chips (warm, dashboard style)
  Widget _header(StudyData s) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Text('Study Hub', style: GoogleFonts.gaegu(
        fontSize: 28, fontWeight: FontWeight.w700, color: _brown, height: 1.1))),
      // Today chip
      _TopChip(
        icon: Icons.timer_rounded,
        label: _fmt(s.todayMinutes),
        gradTop: const Color(0xFFF0C0B8), gradBot: _pinkHdr,
      ),
      const SizedBox(width: 6),
      // XP chip
      _TopChip(
        icon: Icons.auto_awesome_rounded,
        label: '${s.totalXpEarned}',
        gradTop: const Color(0xFFFFE070), gradBot: const Color(0xFFE8B840),
      ),
    ]);
  }

  //  2. TIMER HERO — CENTERED warm card with circular buttons
  //     (User liked this style from v4)
  //     Warm cream/gold tones instead of blue
  Widget _timerHero(StudyData s) {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline.withOpacity(0.25), width: 2.5),
        boxShadow: [
          BoxShadow(color: _outline.withOpacity(0.08),
            offset: const Offset(0, 5), blurRadius: 0),
          BoxShadow(color: _goldGlow.withOpacity(0.15),
            offset: const Offset(0, 0), blurRadius: 20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          // Warm peach/pink header (NOT blue)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
            decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [_pinkLt, _pinkHdr],
            )),
            child: Row(children: [
              const Icon(Icons.local_fire_department_rounded,
                size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text("Today's Focus", style: GoogleFonts.gaegu(
                fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${s.todaySessions} session${s.todaySessions == 1 ? '' : 's'}',
                  style: GoogleFonts.gaegu(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _brown)),
              ),
            ]),
          ),
          // Big centered timer + circular controls
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(children: [
              // Big time number
              Text(
                _fmt(s.todayMinutes),
                style: GoogleFonts.gaegu(
                  fontSize: 56, fontWeight: FontWeight.w700,
                  color: _brown, height: 1.0),
              ),
              const SizedBox(height: 4),
              Text(
                s.avgFocus > 0
                  ? '${s.avgFocus}% average focus'
                  : 'Ready to start studying?',
                style: GoogleFonts.gaegu(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _brownLt),
              ),
              const SizedBox(height: 16),
              // Circular control buttons (play / pause / stop)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _CircleBtn(
                  gradTop: _greenLt, gradBot: _greenHdr,
                  borderColor: _greenDk, shadowColor: _greenDk,
                  icon: Icons.play_arrow_rounded, size: 56, iconSize: 28,
                  onTap: () => context.push(Routes.studySession),
                ),
                const SizedBox(width: 14),
                _CircleBtn(
                  gradTop: const Color(0xFFFFE888), gradBot: _goldHdr,
                  borderColor: _goldDk, shadowColor: _goldDk,
                  icon: Icons.pause_rounded, size: 56, iconSize: 24,
                  onTap: () => _comingSoon('Pause/resume'),
                ),
                const SizedBox(width: 14),
                _CircleBtn(
                  gradTop: _coralLt, gradBot: _coralHdr,
                  borderColor: const Color(0xFFD08878), shadowColor: const Color(0xFFD08878),
                  icon: Icons.stop_rounded, size: 56, iconSize: 24,
                  onTap: () => _comingSoon('Stop session'),
                ),
              ]),
            ]),
          ),
          // Weekly sparkline strip
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            decoration: BoxDecoration(
              color: _outline.withOpacity(0.03),
              border: Border(top: BorderSide(
                color: _outline.withOpacity(0.08), width: 1))),
            child: _weeklyStrip(s),
          ),
        ]),
      ),
    );
  }

  Widget _weeklyStrip(StudyData s) {
    final maxM = s.weeklyActivity.fold<int>(0, math.max);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday - 1;
    return Row(children: [
      Text('Week: ${_fmt(s.weeklyMinutes)}', style: GoogleFonts.gaegu(
        fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt)),
      const Spacer(),
      ...List.generate(7, (i) {
        final h = maxM > 0
            ? (s.weeklyActivity[i] / maxM * 18).clamp(0.0, 18.0) : 0.0;
        final isT = i == today;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: h > 0 ? h : 3,
              decoration: BoxDecoration(
                gradient: h > 0
                  ? LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: isT
                        ? [_pinkHdr.withOpacity(0.6), _pinkHdr]
                        : [_greenHdr.withOpacity(0.4), _greenHdr.withOpacity(0.7)])
                  : null,
                color: h <= 0 ? _outline.withOpacity(0.08) : null,
                borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 2),
            Text(days[i], style: GoogleFonts.gaegu(
              fontSize: 8, fontWeight: FontWeight.w700,
              color: isT ? _brown : _brownLt.withOpacity(0.5))),
          ]),
        );
      }),
    ]);
  }

  //  3. QUICK ACTIONS — 5 chunky 3D game buttons (2 rows)
  Widget _quickActions() {
    return Column(children: [
      Row(children: [
        Expanded(child: _GameBtn(
          icon: Icons.play_circle_filled_rounded, label: 'Session',
          gradTop: _greenLt, gradBot: _greenHdr, border: _greenDk,
          onTap: () => context.push(Routes.studySession),
        )),
        const SizedBox(width: 10),
        Expanded(child: _GameBtn(
          icon: Icons.library_books_rounded, label: 'Subjects',
          gradTop: _purpleLt, gradBot: _purpleHdr, border: _purpleDk,
          onTap: () => context.push(Routes.subjects),
        )),
        const SizedBox(width: 10),
        Expanded(child: _GameBtn(
          icon: Icons.insights_rounded, label: 'Analytics',
          gradTop: const Color(0xFF90D0D8), gradBot: const Color(0xFF68B8C8),
          border: const Color(0xFF50A0B0),
          onTap: () => context.push(Routes.studyAnalytics),
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        const Spacer(),
        Expanded(flex: 2, child: _GameBtn(
          icon: Icons.quiz_rounded, label: 'Quiz',
          gradTop: _coralLt, gradBot: _coralHdr, border: const Color(0xFFD08878),
          onTap: () => context.push(Routes.quizzes),
        )),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _GameBtn(
          icon: Icons.style_rounded, label: 'Cards',
          gradTop: _sageLt, gradBot: _sageHdr, border: _sageDk,
          onTap: () => context.push(Routes.flashcards),
        )),
        const Spacer(),
      ]),
    ]);
  }

  //  4. PEEK ROW 1 — Subjects + Flashcards
  //     Each card has a DISTINCT visual personality
  Widget _peekRow1(StudyData s) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: GestureDetector(
        onTap: () => context.push(Routes.subjects),
        child: Container(
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outline, width: 3),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
              offset: const Offset(0, 4), blurRadius: 0)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Purple header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_purpleLt, _purpleHdr]),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(17), topRight: Radius.circular(17))),
              child: Row(children: [
                const Icon(Icons.library_books_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Text('Subjects', style: GoogleFonts.gaegu(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 16,
                  color: Colors.white.withOpacity(0.7)),
              ]),
            ),
            // Content: subject dots or empty
            Padding(
              padding: const EdgeInsets.all(12),
              child: s.subjects.isEmpty
                ? _peekEmpty('Add your courses', Icons.school_rounded, _purpleHdr)
                : Column(children: [
                    // Subject count + icon dots
                    Row(children: [
                      Text('${s.subjects.length}', style: GoogleFonts.gaegu(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: _brown, height: 1.0)),
                      const SizedBox(width: 6),
                      Text('course${s.subjects.length == 1 ? '' : 's'}',
                        style: GoogleFonts.gaegu(fontSize: 13,
                          fontWeight: FontWeight.w700, color: _brownLt)),
                    ]),
                    const SizedBox(height: 8),
                    // Colored dots for each subject
                    Wrap(spacing: 6, runSpacing: 6,
                      children: s.subjects.take(6).toList().asMap().entries.map((e) {
                        final colors = [_skyHdr, _purpleHdr, _greenHdr, _coralHdr, _goldHdr, _pinkHdr];
                        final clr = colors[e.key % colors.length];
                        return Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: clr.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: clr.withOpacity(0.4), width: 1.5)),
                          child: Icon(_subjIcon(e.value['icon']), size: 13, color: clr),
                        );
                      }).toList(),
                    ),
                  ]),
            ),
          ]),
        ),
      )),
      const SizedBox(width: 12),
      Expanded(child: GestureDetector(
        onTap: () => context.push(Routes.flashcards),
        child: Container(
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outline, width: 3),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
              offset: const Offset(0, 4), blurRadius: 0)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_sageLt, _sageHdr]),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(17), topRight: Radius.circular(17))),
              child: Row(children: [
                const Icon(Icons.style_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Text('Flashcards', style: GoogleFonts.gaegu(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 16,
                  color: Colors.white.withOpacity(0.7)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: s.totalCards == 0
                ? _peekEmpty('Create cards', Icons.layers_rounded, _sageHdr)
                : Column(children: [
                    // Due count — hero stat
                    Row(children: [
                      Text('${s.cardsDue}', style: GoogleFonts.gaegu(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: s.cardsDue > 0 ? _coralHdr : _greenHdr,
                        height: 1.0)),
                      const SizedBox(width: 6),
                      Text('due', style: GoogleFonts.gaegu(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _brownLt)),
                    ]),
                    const SizedBox(height: 6),
                    // Mini stat pills
                    Row(children: [
                      _tinyPill(Icons.check_circle_rounded, '${s.masteredCards}', _greenHdr),
                      const SizedBox(width: 6),
                      _tinyPill(Icons.layers_rounded, '${s.totalCards}', _sageHdr),
                    ]),
                  ]),
            ),
          ]),
        ),
      )),
    ]);
  }

  //  5. PEEK ROW 2 — Quizzes + Weekly
  Widget _peekRow2(StudyData s) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: GestureDetector(
        onTap: () => _comingSoon('Quiz logging'),
        child: Container(
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outline, width: 3),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
              offset: const Offset(0, 4), blurRadius: 0)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_pinkLt, _pinkHdr]),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(17), topRight: Radius.circular(17))),
              child: Row(children: [
                const Icon(Icons.quiz_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Text('Quizzes', style: GoogleFonts.gaegu(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 16,
                  color: Colors.white.withOpacity(0.7)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: s.quizCount == 0
                ? _peekEmpty('Log your scores', Icons.assignment_rounded, _pinkHdr)
                : Column(children: [
                    Row(children: [
                      // Score in a colored circle
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: (s.avgQuizScore >= 70 ? _greenHdr : _coralHdr)
                            .withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (s.avgQuizScore >= 70 ? _greenHdr : _coralHdr)
                              .withOpacity(0.35), width: 2)),
                        child: Center(child: Text('${s.avgQuizScore.round()}%',
                          style: GoogleFonts.gaegu(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: s.avgQuizScore >= 70 ? _greenDk : _coralHdr))),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('avg score', style: GoogleFonts.gaegu(
                            fontSize: 11, fontWeight: FontWeight.w700, color: _brownLt)),
                          Text('${s.quizCount} taken', style: GoogleFonts.gaegu(
                            fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
                        ],
                      ),
                    ]),
                  ]),
            ),
          ]),
        ),
      )),
      const SizedBox(width: 12),
      Expanded(child: Container(
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline, width: 3),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_greenLt, _greenHdr]),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17), topRight: Radius.circular(17))),
            child: Row(children: [
              const Icon(Icons.bar_chart_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 6),
              Text('This Week', style: GoogleFonts.gaegu(
                fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Text(_fmt(s.weeklyMinutes), style: GoogleFonts.gaegu(
                  fontSize: 28, fontWeight: FontWeight.w700,
                  color: _brown, height: 1.0)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Text('${s.weeklySessions} session${s.weeklySessions == 1 ? '' : 's'}',
                  style: GoogleFonts.gaegu(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt)),
                if (s.avgFocus > 0) ...[
                  Text(' · ${s.avgFocus}% focus', style: GoogleFonts.gaegu(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt)),
                ],
              ]),
            ]),
          ),
        ]),
      )),
    ]);
  }

  //  6. RESOURCES TEASER — warm gold banner
  Widget _resourcesTeaser() {
    return GestureDetector(
      onTap: () => context.push(Routes.resources),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_goldGlow.withOpacity(0.25), _goldGlow.withOpacity(0.1)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _goldDk.withOpacity(0.2), width: 2)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [
                Color(0xFFFFE888), Color(0xFFE8C840)]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _goldDk.withOpacity(0.35), width: 2),
              boxShadow: [BoxShadow(color: _goldDk.withOpacity(0.15),
                offset: const Offset(0, 2), blurRadius: 0)]),
            child: const Icon(Icons.auto_stories_rounded,
              size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study Resources', style: GoogleFonts.gaegu(
                fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
              Text('Smart recommendations', style: GoogleFonts.gaegu(
                fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 20,
            color: _brownLt.withOpacity(0.4)),
        ]),
      ),
    );
  }

  //  6b. CALENDAR TEASER — sky blue banner
  Widget _calendarTeaser() {
    return GestureDetector(
      onTap: () => context.push(Routes.calendar),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_skyHdr.withOpacity(0.2), _skyHdr.withOpacity(0.08)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _skyHdr.withOpacity(0.25), width: 2)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [
                Color(0xFF9DD4F0), Color(0xFF6BB8E0)]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _skyDk.withOpacity(0.35), width: 2),
              boxShadow: [BoxShadow(color: _skyDk.withOpacity(0.15),
                offset: const Offset(0, 2), blurRadius: 0)]),
            child: const Icon(Icons.calendar_month_rounded,
              size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study Calendar', style: GoogleFonts.gaegu(
                fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
              Text('Schedule & Google Calendar sync', style: GoogleFonts.gaegu(
                fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 20,
            color: _brownLt.withOpacity(0.4)),
        ]),
      ),
    );
  }

  //  7. INSIGHT — borderless gradient (dashboard style)
  Widget _insightCard(StudyData s) {
    String title, msg; IconData ic; Color c1, c2, iClr;
    if (s.todayMinutes >= 60) {
      title = 'Great work today!';
      msg = 'You studied ${_fmt(s.todayMinutes)} — remember to take breaks.';
      ic = Icons.celebration_rounded;
      c1 = const Color(0xFFFFF0D8); c2 = const Color(0xFFFFF8E8); iClr = _goldDk;
    } else if (s.cardsDue > 3) {
      title = 'Cards are stacking up';
      msg = '${s.cardsDue} flashcards due — a quick review helps!';
      ic = Icons.style_rounded;
      c1 = const Color(0xFFE8F0D8); c2 = const Color(0xFFF0F8E8); iClr = _sageHdr;
    } else if (s.weeklyMinutes > 0 && s.todayMinutes == 0) {
      title = 'Keep the streak alive';
      msg = '${_fmt(s.weeklyMinutes)} this week. Start today\'s session!';
      ic = Icons.local_fire_department_rounded;
      c1 = const Color(0xFFFFE8DE); c2 = const Color(0xFFFFF0E8); iClr = _coralHdr;
    } else {
      title = 'Study Tip';
      msg = 'Each 30-min session earns 25 XP. High focus gives a 25% bonus!';
      ic = Icons.lightbulb_rounded;
      c1 = const Color(0xFFFFF8E0); c2 = const Color(0xFFFFFAEE); iClr = _goldDk;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
        borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(ic, size: 20, color: iClr),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 2),
            Text(msg, style: GoogleFonts.gaegu(
              fontSize: 14, fontWeight: FontWeight.w600, color: _brownLt, height: 1.3)),
          ],
        )),
      ]),
    );
  }

  //  HELPERS
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

  Widget _peekEmpty(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Icon(icon, size: 22, color: color.withOpacity(0.35)),
        const SizedBox(height: 4),
        Text(text, style: GoogleFonts.gaegu(
          fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt),
          textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _tinyPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.gaegu(
          fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  IconData _subjIcon(dynamic k) {
    const m = {'book': Icons.menu_book_rounded, 'science': Icons.science_rounded,
      'math': Icons.calculate_rounded, 'code': Icons.code_rounded,
      'art': Icons.palette_rounded, 'music': Icons.music_note_rounded,
      'language': Icons.translate_rounded, 'history': Icons.history_edu_rounded};
    return m[k] ?? Icons.menu_book_rounded;
  }
}

//  TOP CHIP — header stat badge (dashboard style)
class _TopChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gradTop, gradBot;
  const _TopChip({required this.icon, required this.label,
    required this.gradTop, required this.gradBot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [gradTop, gradBot]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.15),
          offset: const Offset(0, 2), blurRadius: 0)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.gaegu(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }
}

//  CIRCLE BUTTON — for timer controls
class _CircleBtn extends StatefulWidget {
  final Color gradTop, gradBot, borderColor, shadowColor;
  final IconData icon;
  final double size, iconSize;
  final VoidCallback onTap;
  const _CircleBtn({required this.gradTop, required this.gradBot,
    required this.borderColor, required this.shadowColor,
    required this.icon, this.size = 56, this.iconSize = 24,
    required this.onTap});
  @override State<_CircleBtn> createState() => _CircleBtnState();
}

class _CircleBtnState extends State<_CircleBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, _p ? 3 : 0, 0),
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [widget.gradTop, widget.gradBot]),
          shape: BoxShape.circle,
          border: Border.all(color: widget.borderColor.withOpacity(0.5), width: 2.5),
          boxShadow: _p ? [] : [BoxShadow(
            color: widget.shadowColor.withOpacity(0.35),
            offset: const Offset(0, 3), blurRadius: 0)],
        ),
        child: Icon(widget.icon, size: widget.iconSize, color: Colors.white),
      ),
    );
  }
}

//  GAME BUTTON — chunky 3D (matching dashboard exactly)
class _GameBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color gradTop, gradBot, border;
  final VoidCallback onTap;
  const _GameBtn({required this.icon, required this.label,
    required this.gradTop, required this.gradBot, required this.border,
    required this.onTap});
  @override State<_GameBtn> createState() => _GameBtnState();
}

class _GameBtnState extends State<_GameBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, _p ? 3 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [widget.gradTop, widget.gradBot]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.border.withOpacity(0.5), width: 2),
          boxShadow: _p ? [] : [BoxShadow(
            color: widget.border.withOpacity(0.35),
            offset: const Offset(0, 3), blurRadius: 0)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, size: 20, color: Colors.white),
          const SizedBox(height: 3),
          Text(widget.label, style: GoogleFonts.gaegu(fontSize: 14,
            fontWeight: FontWeight.w700, color: Colors.white),
            overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

//  PAWPRINT BACKGROUND
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const sp = 90.0, rs = 45.0, r = 10.0;
    int idx = 0;
    for (double y = 30; y < size.height; y += sp) {
      final odd = ((y / sp).floor() % 2) == 1;
      for (double x = (odd ? rs : 0) + 30; x < size.width; x += sp) {
        paint.color = _pawClr.withOpacity(0.06 + (idx % 5) * 0.018);
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
