/// Matches study_refined.html prototype exactly (desktop layout).
///
/// Desktop layout (maxWidth > 900):
///  HERO     — fixed 32% viewport / min 240px
///             • back btn + title absolutely positioned top-left
///             • pills absolutely positioned top-right
///             • timer CENTERED within hero region
///  CONTENT  — fills remaining viewport, no scroll
///             LEFT  45% — Quick Actions + Overview peek grid (stretches)
///             RIGHT 55% — Weekly Activity card (bars stretch vertical)
///                         + Resources + Calendar teasers + Tip
///
/// Narrow layout (<= 900): stacked scrollable fallback (mobile).
///
/// All data/model/provider code is unchanged.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';
import 'package:cerebro_app/providers/study_session_provider.dart';
import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';

const _ombre1  = Color(0xFFFFFBF7);
const _ombre2  = Color(0xFFFFF8F3);
const _ombre3  = Color(0xFFFFF3EF);
const _ombre4  = Color(0xFFFEEDE9);
const _pawClr  = Color(0xFFF8BCD0);

const _outline = Color(0xFF6E5848);   // --bdr / --ink-mid
const _brown   = Color(0xFF4E3828);   // --ink / --bdr-dk
const _brownLt = Color(0xFF7A5840);
const _inkSoft = Color(0xFF9A8070);   // --ink-soft — HTML wb-day, t-sub, tc-sub

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

// Olive — matches prototype --olive / --olive-dk
const _olive   = Color(0xFF98A869);
const _oliveDk = Color(0xFF58772F);

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

/// Defensive numeric coercion.
///
/// Backend serializes SQLAlchemy `Decimal` columns (current_proficiency,
/// target_proficiency, quiz `score_achieved`, etc.) as JSON *strings*
/// ("80.0"), not floats. Calling `.toDouble()` on a String throws
/// `NoSuchMethodError`, and because the per-endpoint blocks below are
/// wrapped in `try { ... } catch (_) {}`, a single bad row used to
/// silently empty the whole subjects list (→ "0 subjects") and zero out
/// avgQuizScore (→ "0% avg"). This helper accepts num *or* String.
double _asDoubleAny(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
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

      // Isolate the sessions fetch so a network / parse failure here
      // can't short-circuit the subjects + quizzes + flashcards loads
      // and strand the dashboard showing "0 subjects · 0% avg".
      List<dynamic> sessions = const [];
      try {
        final sessRes = await _api.get('/study/sessions');
        sessions = sessRes.data is List ? sessRes.data as List : const [];
      } catch (_) {}
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
          // current_proficiency / target_proficiency arrive as Decimal
          // strings — use the tolerant helper so one row can't blow up
          // the whole subjects list and strand the dashboard at "0".
          subs.add({
            'id': s['id'], 'name': s['name'] ?? 'Untitled',
            'code': s['code'] ?? '', 'color': s['color'] ?? '#9DD4F0',
            'icon': s['icon'] ?? 'book',
            'proficiency': _asDoubleAny(s['current_proficiency'], 0.0),
            'target': _asDoubleAny(s['target_proficiency'], 100.0),
            // Derived topic counts from the enriched /study/subjects response.
            'topics_total': (s['topics_total'] is int)
                ? s['topics_total'] as int
                : int.tryParse(s['topics_total']?.toString() ?? '') ?? 0,
            'topics_mastered': (s['topics_mastered'] is int)
                ? s['topics_mastered'] as int
                : int.tryParse(s['topics_mastered']?.toString() ?? '') ?? 0,
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
          // Quiz scores are Decimal on the backend → JSON string. Use
          // the tolerant coercion so a single row can't drop the
          // average to 0% for the whole dashboard.
          final sc = _asDoubleAny(q['score_achieved'], 0);
          final mx = _asDoubleAny(q['max_score'], 100);
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

  //  BUILD — branches on viewport width
  //   • Desktop (>900px): fixed-viewport hero + 2-col content
  //   • Narrow (<=900px): stacked scrollable fallback
  @override
  Widget build(BuildContext context) {
    // Auto-refresh when user switches TO the study tab
    final currentTab = ref.watch(selectedTabProvider);
    if (currentTab == 2 && _prevTab != 2) {
      Future.microtask(() => ref.read(studyProvider.notifier).refresh());
    }
    _prevTab = currentTab;

    final s    = ref.watch(studyProvider);
    final dash = ref.watch(dashboardProvider);   // real XP + streak

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
      // Content
      SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (ctx, c) {
            // Desktop threshold: 900px is a reasonable breakpoint for
            // a true 2-column layout. Below that, fall back to stacked scroll.
            final isDesktop = c.maxWidth > 900;
            if (isDesktop) {
              return _buildDesktopLayout(s, dash, c);
            }
            return _buildNarrowLayout(s, dash, c);
          },
        ),
      ),
    ]);
  }

  //  DESKTOP LAYOUT — matches study_refined.html exactly
  //  Column { Hero (32vh / min 240), Content (fills rest) }
  Widget _buildDesktopLayout(StudyData s, DashboardState dash, BoxConstraints c) {
    // 80px horizontal padding on very wide screens, scales down smoothly
    final hPad = c.maxWidth > 1280 ? 80.0
              : c.maxWidth > 1024 ? 60.0
              : 40.0;
    // .hero { height ~38vh; min-height:260px } — bigger so timer breathes
    // more and doesn't feel cramped against the top pills.
    final heroH = math.max(c.maxHeight * 0.38, 260.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HERO ── Stack: back+title (top-left), pills (top-right), timer (centered)
        SizedBox(
          height: heroH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Top-left: back button + page title
              Positioned(
                top: 20, left: hPad,
                child: _stag(0.00, _buildHeroTop()),
              ),
              // Top-right: 3 stat pills
              Positioned(
                top: 20, right: hPad,
                child: _stag(0.00, _buildHeroPills(s, dash)),
              ),
              // Timer block — centred horizontally, pushed slightly below
              // vertical centre so the playback buttons clear the pills row
              // above. Y=0.15 means the block sits a touch lower than centre,
              // giving the "Today's Focus" label enough top-space to breathe.
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0.0, 0.15),
                  child: _stag(0.06, _buildTimerCenter(s)),
                ),
              ),
            ],
          ),
        ),
        // CONTENT ── fills remaining viewport, no scroll
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT 45%
                Expanded(
                  flex: 45,
                  child: _stag(0.10, _buildLeftColumnDesktop(s)),
                ),
                const SizedBox(width: 40),   // .content gap:40px
                // RIGHT 55%
                Expanded(
                  flex: 55,
                  child: _stag(0.14, _buildRightColumnDesktop(s)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  //  NARROW LAYOUT — original scrollable stack (phone/tablet)
  Widget _buildNarrowLayout(StudyData s, DashboardState dash, BoxConstraints c) {
    return RefreshIndicator(
      color: _outline, backgroundColor: _cardFill,
      onRefresh: () => ref.read(studyProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stag(0.00, _buildHeader(s, dash)),
              const SizedBox(height: 14),
              _stag(0.06, _buildTimerCenter(s)),
              const SizedBox(height: 20),
              _stag(0.12, Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildQuickActionsSection(),
                  const SizedBox(height: 18),
                  _buildOverviewGrid(s, stretch: false),
                  const SizedBox(height: 18),
                  _buildWeeklyActivityCard(s, stretch: false),
                  const SizedBox(height: 12),
                  _buildResourcesTeaser(),
                  const SizedBox(height: 8),
                  _buildCalendarTeaser(),
                  const SizedBox(height: 12),
                  _buildTipCard(s),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  //  HEADER (narrow-layout only)  — back btn + title + pills in one row
  Widget _buildHeader(StudyData s, DashboardState dash) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      _backButton(),
      const SizedBox(width: 10),
      Expanded(child: Text('Study Hub', style: const TextStyle(
        fontFamily: 'Bitroad', fontSize: 24, color: _brown))),
      _TopChip(icon: Icons.timer_rounded, label: _fmt(s.todayMinutes),
        bgColor: const Color(0xFFF7AEAE)),
      const SizedBox(width: 7),
      _TopChip(icon: Icons.star_rounded, label: '${dash.totalXp} XP',
        bgColor: const Color(0xFFE4BC83)),
      const SizedBox(width: 7),
      _TopChip(icon: Icons.bolt_rounded, label: '${dash.streak}',
        bgColor: const Color(0xFFFFBC5C)),
    ]);
  }

  //  DESKTOP HERO-TOP (left) — back btn + title only
  //  Mirrors .hero-top in HTML
  Widget _buildHeroTop() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _backButton(),
      const SizedBox(width: 10),
      Text('Study Hub', style: const TextStyle(
        fontFamily: 'Bitroad', fontSize: 26, color: _brown)),
    ]);
  }

  // Back button — used by both desktop hero-top and narrow header
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
        child: Icon(Icons.chevron_left_rounded, size: 20, color: _outline),
      ),
    );
  }

  //  DESKTOP HERO-PILLS (right) — 3 stat pills
  //  Mirrors .hero-pills in HTML
  Widget _buildHeroPills(StudyData s, DashboardState dash) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _TopChip(icon: Icons.timer_rounded, label: _fmt(s.todayMinutes),
        bgColor: const Color(0xFFF7AEAE)),
      const SizedBox(width: 7),
      _TopChip(icon: Icons.star_rounded, label: '${dash.totalXp} XP',
        bgColor: const Color(0xFFE4BC83)),
      const SizedBox(width: 7),
      _TopChip(icon: Icons.bolt_rounded, label: '${dash.streak}',
        bgColor: const Color(0xFFFFBC5C)),
    ]);
  }

  //  TIMER CENTER — floating, label + big time + status + 3 btns
  //  Used in BOTH desktop hero (centered) and narrow stacked layout
  //
  //  Reactive to studySessionProvider:
  //    • idle    → shows today's totals + Play (start) Pause Stop (disabled)
  //    • running → shows live elapsed (HH:MM:SS) + Pause + Stop active
  //    • paused  → shows live elapsed (frozen) + Resume + Stop active
  //
  //  Pause is the same button as Resume — its icon swaps based on phase.
  Widget _buildTimerCenter(StudyData s) {
    // Watch the global session — every tick of the provider's 1Hz ticker
    // rebuilds this subtree so the elapsed display advances live.
    final session = ref.watch(studySessionProvider);
    final notifier = ref.read(studySessionProvider.notifier);
    final live = session.isLive;

    // Display string switches between "12m" (today's totals) and the live
    // session timer (MM:SS for under an hour, H:MM:SS otherwise) so the
    // hero feels like a real stopwatch when a session is running.
    final timeLabel = live
        ? _formatLiveTime(session.elapsedSeconds)
        : _fmt(s.todayMinutes);

    // Subtitle reflects current session state, falling back to the
    // average focus / "ready to study" prompts when idle.
    final subtitle = live
        ? (session.phase == SessionPhase.paused
            ? 'Paused — ${session.distractions} distraction${session.distractions == 1 ? '' : 's'}'
            : (session.subjectName ?? session.title ?? 'Focus session'))
        : (s.avgFocus > 0
            ? '${s.avgFocus}% average focus'
            : 'Ready to start studying?');

    final isPaused = session.phase == SessionPhase.paused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // .tc-label — when live, label flips to "LIVE SESSION" so the user
        // can tell at a glance the timer is real-time, not a daily total.
        Text(
          live ? 'LIVE SESSION' : "TODAY'S FOCUS",
          style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: live ? _oliveDk : _inkSoft),
        ),
        const SizedBox(height: 2),
        // .tc-time: Gaegu 4.6rem (~74px) — big bold time. Shrinks slightly
        // when displaying the live HH:MM:SS so it never overflows the hero.
        Text(
          timeLabel,
          style: GoogleFonts.gaegu(
            fontSize: live ? 60 : 74,
            fontWeight: FontWeight.w700,
            color: _brown, height: 0.85),
        ),
        const SizedBox(height: 6),
        // .tc-sub
        Text(
          subtitle,
          style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: _inkSoft),
        ),
        const SizedBox(height: 18),
        // 3 circle buttons — olive / gold / coral
        // HTML: .cb{width:48px;height:48px; border:2.5px solid var(--bdr);
        //       box-shadow:0 4px 0 rgba(110,88,72,.5)} — UNIFORM brown border+shadow
        // Inner SVG: width:18px;height:18px (play triangle a bit larger visually)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // PLAY button — always routes into the full session screen.
          // If a live session exists, the screen reads the provider and
          // renders running state; otherwise it shows the setup picker.
          _CircleBtn(
            gradTop: _olive, gradBot: _oliveDk,
            borderColor: _outline, shadowColor: _outline,
            icon: Icons.play_arrow_rounded, size: 48, iconSize: 20,
            onTap: () => context.push(Routes.studySession),
          ),
          const SizedBox(width: 14),
          // PAUSE / RESUME — same physical button, swaps icon based on
          // phase. Disabled (greyed) when idle.
          _CircleBtn(
            gradTop: live
                ? const Color(0xFFE4BC83)
                : const Color(0xFFE4BC83).withOpacity(0.35),
            gradBot: live
                ? const Color(0xFFC8A060)
                : const Color(0xFFC8A060).withOpacity(0.35),
            borderColor: _outline, shadowColor: _outline,
            icon: isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            size: 48, iconSize: 18,
            onTap: live
                ? () {
                    if (isPaused) {
                      notifier.resume();
                    } else {
                      notifier.pause();
                    }
                  }
                : () => _comingSoon('Start a session first'),
          ),
          const SizedBox(width: 14),
          // STOP — opens the End Session bottom sheet (Save / Discard /
          // Cancel). Disabled (greyed) when idle.
          _CircleBtn(
            gradTop: live
                ? const Color(0xFFF7AEAE)
                : const Color(0xFFF7AEAE).withOpacity(0.35),
            gradBot: live
                ? const Color(0xFFE890B8)
                : const Color(0xFFE890B8).withOpacity(0.35),
            borderColor: _outline, shadowColor: _outline,
            icon: Icons.stop_rounded, size: 48, iconSize: 18,
            onTap: live
                ? () => _requestWrapUp()
                : () => _comingSoon('Start a session first'),
          ),
        ]),
      ],
    );
  }

  /// Format elapsed seconds for the live hero timer.
  ///   < 1h  →  MM:SS
  ///   ≥ 1h  →  H:MM:SS
  String _formatLiveTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  /// Send the user to the full Wrapped rating screen when they tap Stop.
  ///
  /// Ending a session is no longer a one-tap-and-done action — we want
  /// users to consciously rate focus, add notes, and pick topics before
  /// the row is finalized. We:
  ///   1) Flip the provider's `endRequested` flag + pause the clock.
  ///   2) Push the full session screen. Its adoption logic picks up the
  ///      flag and jumps straight to its completion / rating phase.
  Future<void> _requestWrapUp() async {
    ref.read(studySessionProvider.notifier).requestEnd();
    if (!mounted) return;
    await context.push(Routes.studySession);
  }

  //  LEFT COLUMN (desktop) — Quick Actions + Overview
  //  Overview stretches to fill remaining vertical space
  Widget _buildLeftColumnDesktop(StudyData s) {
    // Use natural-height overview cards (stretch: false). Any leftover
    // vertical space becomes empty padding at the bottom rather than
    // inflating the peek cells to 150px+ tall.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuickActionsSection(),
        const SizedBox(height: 16),           // .p-left{gap:16px}
        _buildOverviewGrid(s, stretch: false),
        // Swallow remaining space — keeps the column layout stable
        // without forcing cards to stretch.
        const Spacer(),
      ],
    );
  }

  //  RIGHT COLUMN (desktop) — Weekly (stretches) + Teasers + Tip
  Widget _buildRightColumnDesktop(StudyData s) {
    // Weekly Activity card flexes to fill leftover space, but a LayoutBuilder
    // caps it at 280px so the AI tip card never gets pushed off screen on
    // tall viewports. Any surplus vertical space becomes a gentle bottom
    // gap rather than inflating the chart.
    return LayoutBuilder(
      builder: (ctx, c) {
        // Teasers (~48px each) + tip (~50px) + 3 gaps (14px) = ~200px fixed
        const fixedBelow = 2 * 48.0 + 50.0 + 3 * 14.0;
        final weeklyH = (c.maxHeight - fixedBelow).clamp(200.0, 280.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: weeklyH,
              child: _buildWeeklyActivityCard(s, stretch: true),
            ),
            const SizedBox(height: 14),
            _buildResourcesTeaser(),
            const SizedBox(height: 14),
            _buildCalendarTeaser(),
            const SizedBox(height: 14),
            _buildTipCard(s),
          ],
        );
      },
    );
  }

  //  SECTION TITLE helper — icon + label (matches .sec-t)
  Widget _sectionTitle(String label, IconData icon, {Widget? trailing}) {
    return Padding(
      // .sec-t{margin-bottom:13px}
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(children: [
        // .sec-t svg: olive-dk, 16×16
        Icon(icon, size: 16, color: _oliveDk),
        const SizedBox(width: 7),
        // .sec-t h3: font-family:'Bitroad'; font-size:1rem (16px)
        Text(label, style: const TextStyle(
          fontFamily: 'Bitroad', fontSize: 16, color: _brown)),
        if (trailing != null) ...[const Spacer(), trailing],
      ]),
    );
  }

  //  QUICK ACTIONS — 5 chunky 3D game buttons (3 + 2 rows)
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Quick Actions', Icons.bolt_rounded),
        // Row 1: Session (olive hero CTA), Subjects, Analytics
        Row(children: [
          Expanded(child: _GameBtn(
            // HTML: plain play triangle (no circle wrapper), SOLID olive bg
            icon: Icons.play_arrow_rounded, label: 'Session',
            gradTop: _olive, gradBot: _olive,
            border: _oliveDk,
            contentColor: Colors.white,
            onTap: () => context.push(Routes.studySession),
          )),
          const SizedBox(width: 8),
          Expanded(child: _GameBtn(
            // HTML: single-spine book ("book-open") — match with menu_book
            icon: Icons.menu_book_rounded, label: 'Subjects',
            gradTop: const Color(0xFFF7AEAE).withOpacity(0.42),
            gradBot: const Color(0xFFF7AEAE).withOpacity(0.42),
            border: _outline.withOpacity(0.22),
            contentColor: _brown,
            onTap: () => context.push(Routes.subjects),
          )),
          const SizedBox(width: 8),
          Expanded(child: _GameBtn(
            // HTML: heartbeat/activity line — show_chart is closer match
            icon: Icons.show_chart_rounded, label: 'Analytics',
            gradTop: const Color(0xFFE4BC83).withOpacity(0.48),
            gradBot: const Color(0xFFE4BC83).withOpacity(0.48),
            border: _outline.withOpacity(0.22),
            contentColor: _brown,
            onTap: () => context.push(Routes.studyAnalytics),
          )),
        ]),
        const SizedBox(height: 8),
        // Row 2: Quiz, Cards — LEFT-ALIGNED (empty 3rd slot on right, matching HTML)
        Row(children: [
          Expanded(child: _GameBtn(
            // HTML: help icon (circle + ?)  — match with help_outline
            icon: Icons.help_outline_rounded, label: 'Quiz',
            gradTop: const Color(0xFFFFD5F5).withOpacity(0.42),
            gradBot: const Color(0xFFFFD5F5).withOpacity(0.42),
            border: _outline.withOpacity(0.22),
            contentColor: _brown,
            onTap: () => context.push(Routes.quizzes),
          )),
          const SizedBox(width: 8),
          Expanded(child: _GameBtn(
            // HTML: plain card rectangle + top line — match with credit_card
            icon: Icons.credit_card_rounded, label: 'Cards',
            gradTop: const Color(0xFFFDEFDB).withOpacity(0.55),
            gradBot: const Color(0xFFFDEFDB).withOpacity(0.55),
            border: _outline.withOpacity(0.22),
            contentColor: _brown,
            onTap: () => context.push(Routes.flashcards),
          )),
          const SizedBox(width: 8),
          // History — opens the Past Sessions sheet. Previously the only
          // path to past sessions was the setup phase of the session
          // screen, which becomes unreachable once a session is live.
          // This cell surfaces it as a first-class Hub affordance.
          Expanded(child: _GameBtn(
            icon: Icons.history_rounded, label: 'History',
            gradTop: const Color(0xFFDDF6FF).withOpacity(0.42),
            gradBot: const Color(0xFFDDF6FF).withOpacity(0.42),
            border: _outline.withOpacity(0.22),
            contentColor: _brown,
            onTap: () => context.push(Routes.pastSessions),
          )),
        ]),
      ],
    );
  }

  //  OVERVIEW GRID — 2×2 compact peek cells
  //  When [stretch]==true (desktop), the grid fills vertically so cells
  //  grow to occupy the full left-column remaining space.
  Widget _buildOverviewGrid(StudyData s, {bool stretch = false}) {
    // When [stretch]==true the Rows are wrapped in Expanded (bounded height),
    // so CrossAxisAlignment.stretch is safe. When [stretch]==false the Rows
    // are laid out with unbounded height inside a Column, so we must NOT use
    // CrossAxisAlignment.stretch (would force infinite height); wrap in
    // IntrinsicHeight so cells still end up equal-height without the crash.
    final crossA = stretch
      ? CrossAxisAlignment.stretch
      : CrossAxisAlignment.center;
    final rowSubjectsCards = Row(
      crossAxisAlignment: crossA,
      children: [
        Expanded(child: _peekCell(
          // HTML uses single-spine book (book-open) — match with menu_book
          icon: Icons.menu_book_rounded,
          value: '${s.subjects.length}',
          label: 'Subjects',
          bg: const Color(0xFFDDF6FF).withOpacity(0.38),
          onTap: () => context.push(Routes.subjects),
        )),
        const SizedBox(width: 10),
        Expanded(child: _peekCell(
          // HTML uses plain rect+line (credit-card shape)
          icon: Icons.credit_card_rounded,
          value: '${s.cardsDue}',
          label: 'Cards Due',
          bg: const Color(0xFFFDEFDB).withOpacity(0.42),
          onTap: () => context.push(Routes.flashcards),
        )),
      ],
    );
    final rowQuizWeek = Row(
      crossAxisAlignment: crossA,
      children: [
        Expanded(child: _peekCell(
          // HTML uses help icon (circle + ?)
          icon: Icons.help_outline_rounded,
          value: s.quizCount > 0 ? '${s.avgQuizScore.round()}%' : '--',
          label: 'Avg Score',
          bg: const Color(0xFFFFD5F5).withOpacity(0.3),
          onTap: () => context.push(Routes.quizzes),
        )),
        const SizedBox(width: 10),
        Expanded(child: _peekCell(
          icon: Icons.calendar_today_rounded,
          value: _fmt(s.weeklyMinutes),
          label: 'This Week',
          bg: const Color(0xFFE4BC83).withOpacity(0.24),
          onTap: () => context.push(Routes.studyAnalytics),
        )),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Overview', Icons.grid_view_rounded),
        // Each row stretches equally in desktop mode; fixed-height in narrow
        if (stretch) ...[
          Expanded(child: rowSubjectsCards),
          const SizedBox(height: 10),
          Expanded(child: rowQuizWeek),
        ] else ...[
          rowSubjectsCards,
          const SizedBox(height: 10),
          rowQuizWeek,
        ],
      ],
    );
  }

  Widget _peekCell({
    required IconData icon,
    required String value,
    required String label,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          // .peek: border:1px solid rgba(110,88,72,.15); box-shadow:2px 2px 0 rgba(110,88,72,.1)
          border: Border.all(color: _outline.withOpacity(0.15), width: 1),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(0.10),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon box 28×28
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _outline.withOpacity(0.1), width: 1)),
              child: Icon(icon, size: 14, color: _brownLt),
            ),
            const SizedBox(height: 6),
            // peek-val: Bitroad 1.25rem (20px)
            Text(value, style: const TextStyle(
              fontFamily: 'Bitroad', fontSize: 20,
              color: _brown, height: 1.0)),
            const SizedBox(height: 2),
            // peek-lb: Apercu(→Nunito) 10px uppercase tracked (letter-spacing 0.5)
            Text(label.toUpperCase(), style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 0.5, color: _inkSoft)),
          ],
        ),
      ),
    );
  }

  //  WEEKLY ACTIVITY — section title OUTSIDE card, bars stretch
  //  Today = coral/pink gradient; others = olive gradient
  //  HTML structure:
  //    <div sec-t>Weekly Activity | Details→</div>   ← outside
  //    <div class="card week-wrap">
  //      <div class="week-hdr">total + change</div>
  //      <div class="week-bars">…bars stretch…</div>
  //    </div>
  Widget _buildWeeklyActivityCard(StudyData s, {bool stretch = false}) {
    final maxM = s.weeklyActivity.fold<int>(0, math.max);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday - 1; // 0=Mon … 6=Sun

    // Bars area — stretches to fill card in desktop; fixed 90px slot in narrow
    // mode. Each column is [bar slot] + 5px gap + [day label ~14px]; we
    // subtract label+gap from the available height so nothing overflows.
    Widget barsArea() {
      return LayoutBuilder(
        builder: (ctx, c) {
          const labelSpace = 20.0; // 5px gap + ~14px label + tiny buffer
          final avail = c.hasBoundedHeight && c.maxHeight.isFinite
            ? (c.maxHeight - labelSpace).clamp(40.0, 500.0)
            : 70.0;
          final maxBarH = avail;
          const minBarH = 5.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final rawH = maxM > 0
                ? (s.weeklyActivity[i] / maxM * maxBarH)
                : 0.0;
              final barH = rawH.clamp(minBarH, maxBarH);
              final isT = i == today;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: maxBarH,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            height: barH,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isT
                                  ? [const Color(0xFFF7AEAE),
                                     const Color(0xFFE890B8)]
                                  : [const Color(0xFFB8C87A),
                                     const Color(0xFF98A869)],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                                bottom: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(days[i], style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: isT ? _brown : _inkSoft)),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      );
    }

    // Card contents: week-hdr (top, bordered-bottom) + bars area (fills rest)
    final card = Container(
      decoration: BoxDecoration(
        // .card: background rgba(255,255,255,.88); border:1.5px; shadow:3px 3px 0
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // .week-hdr — total + change, with bottom divider
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(_fmt(s.weeklyMinutes), style: const TextStyle(
                fontFamily: 'Bitroad', fontSize: 22, color: _brown)),
              const SizedBox(width: 9),
              Text(
                s.weeklySessions > 0
                  ? '${s.weeklySessions} session${s.weeklySessions == 1 ? '' : 's'}'
                  : 'this week',
                style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _olive)),
            ]),
          ),
          Divider(height: 1, color: _outline.withOpacity(0.06)),
          // Bars — stretch to fill remaining card height
          if (stretch)
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: barsArea(),
            ))
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SizedBox(height: 90, child: barsArea()),
            ),
        ],
      ),
    );

    // Outer wrapper: section title outside + card below (HTML parity)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _sectionTitle(
          'Weekly Activity', Icons.bar_chart_rounded,
          trailing: GestureDetector(
            onTap: () => context.push(Routes.studyAnalytics),
            child: Text('Details →', style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
          ),
        ),
        if (stretch) Expanded(child: card) else card,
      ],
    );
  }

  //  RESOURCES TEASER — warm gold banner
  Widget _buildResourcesTeaser() {
    return GestureDetector(
      onTap: () => context.push(Routes.resources),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFDEFDB).withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline.withOpacity(0.12), width: 1)),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFE4BC83).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outline.withOpacity(0.2), width: 1.5)),
            child: const Icon(Icons.auto_stories_rounded,
              size: 14, color: _brownLt),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study Resources', style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
              Text('Smart recommendations', style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w600, color: _inkSoft)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 14,
            color: _outline.withOpacity(0.2)),
        ]),
      ),
    );
  }

  //  CALENDAR TEASER — sky blue banner
  Widget _buildCalendarTeaser() {
    return GestureDetector(
      onTap: () => context.push(Routes.calendar),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDDF6FF).withOpacity(0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline.withOpacity(0.12), width: 1)),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFDDF6FF).withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outline.withOpacity(0.2), width: 1.5)),
            child: const Icon(Icons.calendar_month_rounded,
              size: 14, color: _brownLt),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study Calendar', style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
              Text('Schedule & Google Calendar sync', style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w600, color: _inkSoft)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 14,
            color: _outline.withOpacity(0.2)),
        ]),
      ),
    );
  }

  //  TIP CARD — compact row (lightbulb circle + Gaegu text)
  //  Matches prototype .tip — de-emphasised background
  Widget _buildTipCard(StudyData s) {
    String msg; IconData ic; Color iClr;

    if (s.todayMinutes >= 60) {
      msg = 'You studied ${_fmt(s.todayMinutes)} — remember to take breaks!';
      ic = Icons.celebration_rounded; iClr = _goldDk;
    } else if (s.cardsDue > 3) {
      msg = '${s.cardsDue} flashcards due — a quick review helps!';
      ic = Icons.style_rounded; iClr = _sageHdr;
    } else if (s.weeklyMinutes > 0 && s.todayMinutes == 0) {
      msg = '${_fmt(s.weeklyMinutes)} this week. Start today\'s session!';
      ic = Icons.local_fire_department_rounded; iClr = _coralHdr;
    } else {
      msg = 'Each 30-min session earns 25 XP. High focus gives a 25% bonus!';
      ic = Icons.lightbulb_rounded; iClr = const Color(0xFFE890B8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD5F5).withOpacity(0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.18), width: 1)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.3), width: 1.5)),
          child: Icon(ic, size: 12, color: iClr),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(msg, style: GoogleFonts.gaegu(
          fontSize: 15, fontWeight: FontWeight.w700,
          color: _brown, height: 1.4))),
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

  IconData _subjIcon(dynamic k) {
    const m = {'book': Icons.menu_book_rounded, 'science': Icons.science_rounded,
      'math': Icons.calculate_rounded, 'code': Icons.code_rounded,
      'art': Icons.palette_rounded, 'music': Icons.music_note_rounded,
      'language': Icons.translate_rounded, 'history': Icons.history_edu_rounded};
    return m[k] ?? Icons.menu_book_rounded;
  }
}

//  TOP CHIP — header stat pill  (matches prototype .pill exactly)
//  Solid fill, fully-rounded, hard 2×2 offset shadow, dark border
class _TopChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  const _TopChip({required this.icon, required this.label,
    required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        // .pill: border:1.5px solid rgba(110,88,72,.35); box-shadow:2px 2px 0 rgba(.28)
        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.28),
          offset: const Offset(2, 2), blurRadius: 0)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: _outline),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.gaegu(
          fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
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
        transform: Matrix4.translationValues(0, _p ? 4 : 0, 0),
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [widget.gradTop, widget.gradBot]),
          shape: BoxShape.circle,
          // HTML .cb: border:2.5px solid var(--bdr) — solid, no opacity
          border: Border.all(color: widget.borderColor, width: 2.5),
          // HTML .cb: box-shadow:0 4px 0 rgba(110,88,72,.5)
          boxShadow: _p ? [] : [BoxShadow(
            color: widget.shadowColor.withOpacity(0.5),
            offset: const Offset(0, 4), blurRadius: 0)],
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
  final Color contentColor;
  final VoidCallback onTap;
  const _GameBtn({required this.icon, required this.label,
    required this.gradTop, required this.gradBot, required this.border,
    this.contentColor = Colors.white,
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
          border: Border.all(color: widget.border, width: 1.5),
          boxShadow: _p ? [] : [BoxShadow(
            color: widget.border,
            offset: const Offset(0, 3), blurRadius: 0)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, size: 20, color: widget.contentColor),
          const SizedBox(height: 3),
          Text(widget.label, style: GoogleFonts.gaegu(fontSize: 14,
            fontWeight: FontWeight.w700, color: widget.contentColor),
            overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

//  END SESSION BOTTOM SHEET
//  Shown when the user taps Stop on the hero (or triggers the
//  cross-tab guard). Presents three clear choices:
//     • Save    — focus_score slider + notes → PUT /sessions/{id}/end
//     • Discard — marks the session as discarded (focus_score=1)
//     • Cancel  — dismiss, session stays live
class _EndSessionSheet extends ConsumerStatefulWidget {
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  const _EndSessionSheet({required this.onSave, required this.onDiscard});

  @override
  ConsumerState<_EndSessionSheet> createState() => _EndSessionSheetState();
}

class _EndSessionSheetState extends ConsumerState<_EndSessionSheet> {
  @override
  Widget build(BuildContext context) {
    // Pull current session stats so the sheet can show the user what they
    // actually did — "5m focused · 0 distractions" is far more useful than
    // a generic "end session?" confirm.
    final s = ref.watch(studySessionProvider);
    final mins = (s.elapsedSeconds / 60).floor();
    final secs = s.elapsedSeconds % 60;
    final elapsed = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48, height: 4,
              decoration: BoxDecoration(
                color: _outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('End this session?',
              style: GoogleFonts.gaegu(
                  fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(height: 6),
          Text(
            'You focused for $elapsed with ${s.distractions} '
            'distraction${s.distractions == 1 ? '' : 's'}.',
            style: GoogleFonts.gaegu(fontSize: 15, color: _inkSoft),
          ),
          const SizedBox(height: 20),
          // Save button — primary, olive fill
          _sheetBtn(
            label: 'Save session',
            bg: _olive, fg: Colors.white,
            icon: Icons.check_rounded,
            onTap: widget.onSave,
          ),
          const SizedBox(height: 10),
          // Discard — muted, warns the user the session won't be counted
          _sheetBtn(
            label: 'Discard',
            bg: const Color(0xFFF7AEAE), fg: _brown,
            icon: Icons.delete_outline_rounded,
            onTap: widget.onDiscard,
          ),
          const SizedBox(height: 10),
          // Cancel — neutral
          _sheetBtn(
            label: 'Keep studying',
            bg: _cardFill, fg: _brown,
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _sheetBtn({
    required String label,
    required Color bg, required Color fg,
    required IconData icon, required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.4), width: 1.5),
        ),
        child: Row(children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.gaegu(
              fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
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
