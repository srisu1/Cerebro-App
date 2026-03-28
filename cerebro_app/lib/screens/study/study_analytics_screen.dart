// Study analytics — Overview, Map, Gaps, Coach, Schedule tabs.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cerebro_app/providers/auth_provider.dart';


bool get _darkMode =>
    CerebroTheme.brightnessNotifier.value == Brightness.dark;

Color get _ombre1 => _darkMode ? const Color(0xFF191513) : const Color(0xFFFFFBF7);
Color get _ombre2 => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFF8F3);
Color get _ombre3 => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF3EF);
Color get _ombre4 => _darkMode ? const Color(0xFF312821) : const Color(0xFFFEEDE9);
Color get _pawClr => _darkMode ? const Color(0xFF231D18) : const Color(0xFFF8BCD0);
Color get _outline => _darkMode ? const Color(0xFFAD7F58) : const Color(0xFF6E5848);
Color get _brown => _darkMode ? const Color(0xFFF2E1CA) : const Color(0xFF4E3828);
Color get _brownLt => _darkMode ? const Color(0xFFDBB594) : const Color(0xFF7A5840);
Color get _brownSoft => _darkMode ? const Color(0xFFBD926C) : const Color(0xFF9A8070);
Color get _cardFill => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF8F4);
Color get _cream => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFDEFDB);
// Mellow palette (primary surfaces)
Color get _mTerra => const Color(0xFFD9B5A6);
Color get _mSlate => const Color(0xFFB6CBD6);
Color get _mSage => const Color(0xFFB5C4A0);
Color get _mMint => const Color(0xFFC8DCC2);
Color get _mLav => const Color(0xFFC9B8D9);
Color get _mButter => const Color(0xFFE8D4A0);
Color get _mBlush => const Color(0xFFEAD0CE);
Color get _mSand => const Color(0xFFE8D9C2);
// Accent depths
Color get _olive => const Color(0xFF98A869);
Color get _oliveDk => const Color(0xFF58772F);
Color get _coral => const Color(0xFFF7AEAE);
Color get _red => const Color(0xFFEF6262);
Color get _gold => const Color(0xFFE4BC83);
const _bitroad = 'Bitroad';

// Nullable `color` + in-body fallback — `_brown` is a runtime mode-aware
// getter now, so it can't be a default parameter expression.
TextStyle _gaegu({double size = 14, FontWeight weight = FontWeight.w600,
        Color? color, double? h}) =>
    GoogleFonts.gaegu(fontSize: size, fontWeight: weight, color: color ?? _brown, height: h);
TextStyle _nunito({double size = 12, FontWeight weight = FontWeight.w600,
        Color? color, double? h, double? letter}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color ?? _brown,
        height: h, letterSpacing: letter);

Color _hexColor(String hex) {
  final h = hex.replaceFirst('#', '').trim();
  return Color(int.tryParse('FF${h.length == 6 ? h : "D9B5A6"}', radix: 16) ?? 0xFFD9B5A6);
}

// Heat ramp — red (weak) → butter (fair) → sage (strong).
Color _heatColor(double v) {
  final c = v.clamp(0.0, 100.0);
  if (c < 40) return Color.lerp(_red, _gold, c / 40)!;
  if (c < 70) return Color.lerp(_gold, _mSage, (c - 40) / 30)!;
  return Color.lerp(_mSage, _olive, (c - 70) / 30)!;
}

double? _asD(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _asI(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

BoxDecoration _pocketCard({Color? fill, Color? borderColor, double radius = 16}) =>
    BoxDecoration(
      color: fill ?? _cardFill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? _outline, width: 2),
      boxShadow: [BoxShadow(
        color: (borderColor ?? _outline).withOpacity(0.18),
        offset: const Offset(3, 3), blurRadius: 0)],
    );

BoxDecoration _softCard({Color? fill, double radius = 14}) => BoxDecoration(
      color: fill ?? _cardFill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _outline.withOpacity(0.18), width: 1.2),
      boxShadow: [BoxShadow(
        color: _outline.withOpacity(0.12),
        offset: const Offset(2, 2), blurRadius: 0)],
    );


//  MAIN SCREEN
class StudyAnalyticsScreen extends ConsumerStatefulWidget {
  const StudyAnalyticsScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<StudyAnalyticsScreen> createState() => _StudyAnalyticsScreenState();
}

class _StudyAnalyticsScreenState extends ConsumerState<StudyAnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  late final AnimationController _enter;

  Map<String, dynamic>? _data;
  Map<String, dynamic>? _coach;
  bool _loading = true;
  bool _coachLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _enter = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800))..forward();
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _fetchAnalytics() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get('/study/analytics');
      _data = resp.data is Map ? Map<String, dynamic>.from(resp.data) : {};
    } catch (e) {
      _error = e.toString();
      debugPrint('[ANALYTICS] fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
    // Kick off coach in background — non-blocking.
    if (_data != null && _error == null && _coach == null) {
      _fetchCoach();
    }
  }

  Future<void> _fetchCoach({bool force = false}) async {
    if (_coachLoading) return;
    if (!mounted) return;
    setState(() { _coachLoading = true; });
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get('/study/analytics/ai-coach');
      if (!mounted) return;
      setState(() {
        _coach = resp.data is Map ? Map<String, dynamic>.from(resp.data) : {};
      });
    } catch (e) {
      debugPrint('[ANALYTICS] coach fetch error: $e');
    } finally {
      if (mounted) setState(() { _coachLoading = false; });
    }
  }

  // Stagger animation that matches subjects_screen exactly.
  Widget _stagger(double delay, Widget child) {
    return RepaintBoundary(child: AnimatedBuilder(
      animation: _enter, child: child,
      builder: (_, c) {
        final t = Curves.easeOutCubic.transform(
            ((_enter.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
        return IgnorePointer(
          ignoring: t < 1.0,
          child: Opacity(opacity: t,
            child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c)),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final contentW = (screenW * 0.94).clamp(360.0, 1500.0);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_ombre1, _ombre2, _ombre3, _ombre4],
          ),
        ),
        child: CustomPaint(
          painter: _PawPrintBg(),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: SizedBox(
                width: contentW,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    const SizedBox(height: 16),
                    _stagger(0.00, _header()),
                    const SizedBox(height: 16),
                    _stagger(0.10, _tabBar()),
                    const SizedBox(height: 12),
                    Expanded(child: _stagger(0.18, _body())),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  //  HEADER
  Widget _header() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _BackPill(onTap: () => Navigator.of(context).maybePop()),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Study Analytics',
            style: TextStyle(fontFamily: _bitroad, fontSize: 26,
                color: _brown, height: 1.15)),
          const SizedBox(height: 2),
          Text('your study, decoded — readiness, gaps, momentum, & a coach~',
            style: _gaegu(size: 15, color: _brownSoft, h: 1.3)),
        ],
      )),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _Pill(icon: Icons.bolt_rounded,
          label: '${_streakDays()}d streak',
          color: _streakDays() > 0 ? _mButter : _mSand),
        _Pill(icon: Icons.trending_up_rounded,
          label: _momentumLabel(),
          color: _momentumColor(), highlight: _momentumDelta() > 0),
        GestureDetector(
          onTap: () { _tabCtrl.animateTo(3); _fetchCoach(force: true); },
          child: _Pill(icon: Icons.auto_awesome_rounded,
              label: 'Coach', color: _mLav),
        ),
        GestureDetector(
          onTap: _loading ? null : _fetchAnalytics,
          child: _Pill(icon: Icons.refresh_rounded, label: 'Refresh',
              color: _mSage.withOpacity(0.85), highlight: true),
        ),
      ]),
    ]);
  }

  // NOTE: hero strip of 5 _StatTile cards was removed — every metric in it
  // duplicated content elsewhere on the same screen (readiness ring, header
  // chips, trend card, Gaps tab, Schedule tab). Removing it is the single
  // biggest visual decluttering of the overview page.

  int _streakDays() {
    final overview = (_data?['overview'] as Map?)?.cast<String, dynamic>() ?? {};
    return _asI(overview['streak_days']);
  }

  double _momentumDelta() {
    final overview = (_data?['overview'] as Map?)?.cast<String, dynamic>() ?? {};
    return _asD(overview['momentum_delta']) ?? 0;
  }

  String _momentumLabel() {
    final d = _momentumDelta();
    if (d == 0) return 'flat vs last wk';
    if (d > 0) return '+${d.toInt()}m vs last wk';
    return '${d.toInt()}m vs last wk';
  }

  Color _momentumColor() {
    final d = _momentumDelta();
    if (d > 30) return _mMint;
    if (d > 0) return _mSage.withOpacity(0.85);
    if (d == 0) return _mSand;
    if (d > -30) return _mBlush;
    return _mTerra;
  }

  //  TAB BAR — pill row that matches subjects' _FilterPill aesthetic
  Widget _tabBar() {
    final tabs = <(IconData, String, Color)>[
      (Icons.dashboard_rounded,        'Overview', _mSage),
      (Icons.grid_view_rounded,        'Map',      _mSlate),
      (Icons.warning_amber_rounded,    'Gaps',     _mTerra),
      (Icons.auto_awesome_rounded,     'Coach',    _mLav),
      (Icons.calendar_month_rounded,   'Schedule', _mButter),
    ];
    return SizedBox(
      height: 44,
      child: Row(children: List.generate(tabs.length, (i) {
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
          child: AnimatedBuilder(
            animation: _tabCtrl,
            builder: (ctx, _) {
              final isActive = _tabCtrl.index == i;
              return GestureDetector(
                onTap: () => _tabCtrl.animateTo(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: isActive ? tabs[i].$3 : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? _outline : _outline.withOpacity(0.25),
                      width: isActive ? 2 : 1.5,
                    ),
                    boxShadow: isActive
                      ? [BoxShadow(color: _outline.withOpacity(0.28),
                            offset: const Offset(3, 3), blurRadius: 0)]
                      : [BoxShadow(color: _outline.withOpacity(0.14),
                            offset: const Offset(2, 2), blurRadius: 0)],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(tabs[i].$1, size: 15, color: _brown),
                    const SizedBox(width: 5),
                    Text(tabs[i].$2,
                      style: TextStyle(fontFamily: _bitroad,
                        fontSize: 14,
                        color: _brown,
                        fontWeight: isActive ? FontWeight.w900 : FontWeight.w700)),
                  ]),
                ),
              );
            },
          ),
        ));
      })),
    );
  }

  //  BODY
  Widget _body() {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState();
    if (_data == null) return _emptyDataState();
    return TabBarView(
      controller: _tabCtrl,
      physics: const ClampingScrollPhysics(),
      children: [
        _OverviewTab(data: _data!),
        _MapTab(data: _data!),
        _GapsTab(data: _data!),
        _CoachTab(
          data: _data!,
          coach: _coach,
          loading: _coachLoading,
          onRegenerate: () => _fetchCoach(force: true),
          onJumpToGaps: () => _tabCtrl.animateTo(2),
          onJumpToSchedule: () => _tabCtrl.animateTo(4),
        ),
        _ScheduleTab(data: _data!),
      ],
    );
  }

  Widget _loadingState() {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(children: [
        CircularProgressIndicator(color: _olive, strokeWidth: 3),
        const SizedBox(height: 14),
        Text('Crunching your study data...',
          style: _gaegu(size: 16, color: _brownSoft, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('quizzes · sessions · flashcards · topics',
          style: _nunito(size: 11, color: _brownSoft)),
      ]),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _mTerra.withOpacity(0.25),
            shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.3), width: 2.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: Icon(Icons.cloud_off_rounded, size: 36, color: _brown),
        ),
        const SizedBox(height: 14),
        Text("Couldn't load analytics",
          style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
        const SizedBox(height: 4),
        Text(_error ?? '', textAlign: TextAlign.center,
          style: _gaegu(size: 13, color: _brownSoft)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _fetchAnalytics,
          child: _Pill(icon: Icons.refresh_rounded, label: 'Retry', color: _mSage),
        ),
      ]),
    );
  }

  Widget _emptyDataState() {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _cream, shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.3), width: 2.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: Icon(Icons.insights_rounded, size: 36, color: _brownLt),
        ),
        const SizedBox(height: 14),
        Text('No analytics yet',
          style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
        const SizedBox(height: 4),
        Text('Log a study session or take a quiz to populate this page.',
          textAlign: TextAlign.center,
          style: _gaegu(size: 13, color: _brownSoft)),
      ]),
    );
  }
}


//  TAB 1: OVERVIEW
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final overview = (data['overview'] as Map?)?.cast<String, dynamic>() ?? {};
    final trends   = (data['trends']   as Map?)?.cast<String, dynamic>() ?? {};
    final preds    = (data['predictions'] as Map?)?.cast<String, dynamic>() ?? {};
    final topSubjects = (data['top_subjects'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final forgetting = (data['forgetting_risk'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final daily30 = ((trends['daily_minutes_30'] as List?) ?? [])
        .map((e) => _asD(e) ?? 0).toList();

    final readiness = _asD(overview['exam_readiness']) ?? 0;
    final confidence = _asD(preds['confidence']) ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Readiness card
            Expanded(flex: 2, child: _ReadinessCard(
              readiness: readiness, confidence: confidence,
              streak: _asI(overview['streak_days']),
              momentum: _asD(overview['momentum_delta']) ?? 0,
            )),
            const SizedBox(width: 14),
            // Trend card
            Expanded(flex: 3, child: _TrendCard(
              daily: daily30,
              thisWeek: _asI(overview['this_week_minutes']),
              lastWeek: _asI(overview['last_week_minutes']),
              bestHour: _asI(trends['best_study_hour']),
              sessions30d: _asI(overview['sessions_30d']),
            )),
          ],
        )),
        const SizedBox(height: 14),

        _SectionHeader('Top Subjects', icon: Icons.emoji_events_rounded,
          tint: _mButter, count: topSubjects.length),
        const SizedBox(height: 10),
        if (topSubjects.isEmpty)
          _InlineEmpty('Add a subject to start tracking proficiency.', _mSlate)
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topSubjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _TopSubjectCard(s: topSubjects[i]),
            ),
          ),

        const SizedBox(height: 18),

        _SectionHeader('Best Study Windows (last 30d)',
          icon: Icons.access_time_rounded, tint: _mLav,
          subtitle: 'when you actually log focus'),
        const SizedBox(height: 10),
        _HourlyHeatmap(
          hourly: ((trends['hourly_minutes'] as List?) ?? List.filled(24, 0))
              .map((e) => _asD(e) ?? 0).toList(),
          bestHour: _asI(trends['best_study_hour']),
        ),

        const SizedBox(height: 18),

        _SectionHeader('Forgetting Risk',
          icon: Icons.timer_off_rounded, tint: _mTerra,
          subtitle: 'topics you used to know — about to fade',
          count: forgetting.length),
        const SizedBox(height: 10),
        if (forgetting.isEmpty)
          _InlineEmpty('Nothing on the brink — you\'re reviewing on schedule.', _mMint)
        else
          Column(children: [
            for (final f in forgetting.take(4)) _ForgettingRow(item: f),
          ]),
      ]),
    );
  }
}


class _ReadinessCard extends StatelessWidget {
  final double readiness, confidence, momentum;
  final int streak;
  const _ReadinessCard({
    required this.readiness, required this.confidence,
    required this.streak, required this.momentum,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = _heatColor(readiness);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _pocketCard(fill: _cardFill, radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ringColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ringColor.withOpacity(0.4), width: 1),
            ),
            child: Text('READINESS',
              style: _nunito(size: 10, weight: FontWeight.w900,
                  color: _brown, letter: 1.0)),
          ),
          const Spacer(),
          Text('${(confidence * 100).toInt()}% conf',
            style: _nunito(size: 11, color: _brownSoft, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        Center(child: SizedBox(
          width: 140, height: 140,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 140, height: 140,
              child: CircularProgressIndicator(
                value: (readiness / 100).clamp(0.0, 1.0),
                strokeWidth: 12,
                backgroundColor: _outline.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${readiness.toInt()}',
                style: TextStyle(fontFamily: _bitroad,
                    fontSize: 48, color: _brown, height: 1.0)),
              Text('% READY',
                style: _nunito(size: 10, weight: FontWeight.w900,
                    color: _brownLt, letter: 1.2, h: 1.4)),
            ]),
          ]),
        )),
        const SizedBox(height: 14),
        Row(children: [
          _MetaPill(icon: Icons.local_fire_department_rounded,
            label: '${streak}d', sub: 'streak', tint: _mButter),
          const SizedBox(width: 8),
          Expanded(child: _MetaPill(icon: momentum >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
            label: '${momentum >= 0 ? '+' : ''}${momentum.toInt()}m',
            sub: 'vs last wk',
            tint: momentum >= 0 ? _mSage.withOpacity(0.85) : _mBlush)),
        ]),
      ]),
    );
  }
}


class _TrendCard extends StatelessWidget {
  final List<double> daily;
  final int thisWeek, lastWeek, sessions30d, bestHour;
  const _TrendCard({
    required this.daily, required this.thisWeek, required this.lastWeek,
    required this.sessions30d, required this.bestHour,
  });

  @override
  Widget build(BuildContext context) {
    final total = daily.fold<double>(0, (a, b) => a + b);
    final avg = daily.isEmpty ? 0.0 : total / daily.length;
    final hasData = daily.any((v) => v > 0);
    final maxY = (daily.isEmpty ? 30.0 : daily.reduce(math.max) * 1.25)
        .clamp(30.0, 999.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _pocketCard(fill: _cardFill, radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _mSlate.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _mSlate.withOpacity(0.7), width: 1),
            ),
            child: Text('30-DAY TREND',
              style: _nunito(size: 10, weight: FontWeight.w900,
                  color: _brown, letter: 1.0)),
          ),
          const Spacer(),
          Text('${total.toInt()}m total',
            style: _nunito(size: 11, color: _brownSoft, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: hasData
            ? LineChart(LineChartData(
                minY: 0, maxY: maxY,
                gridData: FlGridData(show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: _outline.withOpacity(0.06), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 30,
                    interval: maxY / 3,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('${v.toInt()}m', style: _nunito(
                        size: 9, color: _brownSoft)),
                    ))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    interval: 7,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      final lbl = i == 0 ? '30d ago'
                          : i == 7 ? '23d'
                          : i == 14 ? '16d'
                          : i == 21 ? '9d'
                          : i >= 29 ? 'today' : '';
                      if (lbl.isEmpty) return const SizedBox();
                      return Padding(padding: const EdgeInsets.only(top: 4),
                        child: Text(lbl, style: _nunito(
                          size: 9, color: _brownSoft, weight: FontWeight.w700)));
                    })),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: _cardFill,
                    tooltipBorder: BorderSide(color: _outline.withOpacity(0.3)),
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      '${s.y.toInt()} min',
                      _nunito(size: 11, weight: FontWeight.w800, color: _brown),
                    )).toList(),
                  ),
                ),
                lineBarsData: [LineChartBarData(
                  spots: List.generate(daily.length,
                    (i) => FlSpot(i.toDouble(), daily[i])),
                  isCurved: true, curveSmoothness: 0.25,
                  color: _olive, barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [_olive.withOpacity(0.32), _olive.withOpacity(0.0)]),
                  ),
                )],
              ))
            : Center(child: Text('No sessions logged in 30 days',
                style: _gaegu(size: 13, color: _brownSoft))),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _MetaChip(label: 'this week', value: '${thisWeek}m', color: _mSage)),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(label: 'last week', value: '${lastWeek}m', color: _mSlate)),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(label: 'sessions', value: '$sessions30d', color: _mLav)),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(
            label: 'avg/day',
            value: '${avg.toStringAsFixed(0)}m',
            color: _mButter,
          )),
        ]),
      ]),
    );
  }
}


class _HourlyHeatmap extends StatelessWidget {
  final List<double> hourly;
  final int bestHour;
  const _HourlyHeatmap({required this.hourly, required this.bestHour});

  @override
  Widget build(BuildContext context) {
    final maxV = hourly.isEmpty ? 0.0 : hourly.reduce(math.max);
    final hasData = maxV > 0;

    String fmtHour(int h) {
      if (h <= 0) return '12am';
      if (h < 12) return '${h}am';
      if (h == 12) return '12pm';
      return '${h - 12}pm';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _softCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bedtime_rounded, size: 14, color: _brownLt),
          const SizedBox(width: 6),
          Text('00', style: _nunito(size: 10, color: _brownSoft, weight: FontWeight.w700)),
          const Spacer(),
          if (hasData)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _mLav.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _mLav, width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 12, color: _brown),
                const SizedBox(width: 4),
                Text('peak: ${fmtHour(bestHour)}',
                  style: _nunito(size: 10, weight: FontWeight.w800, color: _brown)),
              ]),
            ),
          const SizedBox(width: 6),
          Text('23', style: _nunito(size: 10, color: _brownSoft, weight: FontWeight.w700)),
          const SizedBox(width: 4),
          Icon(Icons.wb_sunny_rounded, size: 14, color: _brownLt),
        ]),
        const SizedBox(height: 10),
        if (!hasData)
          Padding(padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(child: Text(
              'Log a session to discover your best study window.',
              style: _gaegu(size: 13, color: _brownSoft)))),
        if (hasData) Row(children: [
          for (int h = 0; h < 24; h++) Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.2),
            child: Tooltip(
              message: '${fmtHour(h)} · ${hourly[h].toInt()}m',
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: hourly[h] == 0
                    ? _outline.withOpacity(0.05)
                    : Color.lerp(_mSlate.withOpacity(0.2),
                        _olive, (hourly[h] / maxV).clamp(0.05, 1.0))!,
                  borderRadius: BorderRadius.circular(4),
                  border: h == bestHour
                    ? Border.all(color: _outline, width: 1.5)
                    : Border.all(color: _outline.withOpacity(0.08), width: 0.6),
                ),
              ),
            ),
          )),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (final lbl in ['12am', '6am', '12pm', '6pm', '11pm']) Expanded(
            child: Text(lbl, textAlign: TextAlign.center,
              style: _nunito(size: 9, color: _brownSoft, weight: FontWeight.w700))),
        ]),
      ]),
    );
  }
}


class _TopSubjectCard extends StatelessWidget {
  final Map<String, dynamic> s;
  const _TopSubjectCard({required this.s});
  @override
  Widget build(BuildContext context) {
    final color = _hexColor(s['color'] ?? '#9DD4F0');
    final prof = _asD(s['proficiency']) ?? 0;
    // Dark mode: layer the subject tint over the card surface so the card
    // has body; without this the 0.18 alpha vanishes against the dark bg.
    final bg = _darkMode
        ? Color.alphaBlend(color.withOpacity(0.22), const Color(0xFF29221D))
        : color.withOpacity(0.18);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: _softCard(fill: bg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              border: Border.all(color: _outline.withOpacity(0.4), width: 1))),
          const SizedBox(width: 6),
          Expanded(child: Text(s['name']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: _bitroad, fontSize: 15, color: _brown))),
        ]),
        const Spacer(),
        Text('${prof.toInt()}%',
          style: TextStyle(fontFamily: _bitroad, fontSize: 28, color: _brown, height: 1)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (prof / 100).clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: _darkMode
                ? Colors.black.withOpacity(0.35)
                : Colors.white.withOpacity(0.45),
            valueColor: AlwaysStoppedAnimation(_heatColor(prof)),
          ),
        ),
        const SizedBox(height: 4),
        Text('proficiency',
          style: _nunito(size: 10, color: _brownSoft, weight: FontWeight.w700, letter: 0.5)),
      ]),
    );
  }
}


class _ForgettingRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ForgettingRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final color = _hexColor(item['subject_color'] ?? '#D9B5A6');
    final risk = _asD(item['risk_score']) ?? 0;
    final prof = _asD(item['proficiency']) ?? 0;
    final days = _asI(item['days_since_studied']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: _softCard(),
      child: Row(children: [
        Container(width: 6, height: 36,
          decoration: BoxDecoration(color: color,
              borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['topic']?.toString() ?? '',
            style: TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${item['subject_name'] ?? ''} · ${prof.toInt()}% proficiency · ${days}d ago',
            style: _gaegu(size: 11, color: _brownSoft, weight: FontWeight.w600)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _heatColor(100 - risk).withOpacity(0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _heatColor(100 - risk), width: 1),
          ),
          child: Text('${risk.toInt()}% risk',
            style: _nunito(size: 11, weight: FontWeight.w900, color: _brown)),
        ),
      ]),
    );
  }
}


//  TAB 2: KNOWLEDGE MAP
class _MapTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MapTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final km = (data['knowledge_map'] as Map?)?.cast<String, dynamic>() ?? {};
    final subjects = (km['subjects'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (subjects.isEmpty || subjects.every((s) => (s['topics'] as List? ?? []).isEmpty)) {
      return Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _mSlate.withOpacity(0.3), shape: BoxShape.circle,
              border: Border.all(color: _outline.withOpacity(0.3), width: 2.5),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                  offset: const Offset(3, 3), blurRadius: 0)],
            ),
            child: Icon(Icons.grid_view_rounded, size: 36, color: _brownLt),
          ),
          const SizedBox(height: 14),
          Text('No topics yet',
            style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
          const SizedBox(height: 4),
          Text('Run a quiz or upload notes to seed the knowledge map.',
            textAlign: TextAlign.center,
            style: _gaegu(size: 13, color: _brownSoft)),
        ])),
      );
    }

    // Sort subjects: highest proficiency first.
    final sorted = [...subjects];
    sorted.sort((a, b) => (_asD(b['proficiency']) ?? 0)
        .compareTo(_asD(a['proficiency']) ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Legend
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: _softCard(fill: _cream.withOpacity(0.7)),
          child: Row(children: [
            Icon(Icons.palette_rounded, size: 14, color: _brownLt),
            const SizedBox(width: 8),
            Text('Topic colour scale: ',
              style: _nunito(size: 11, weight: FontWeight.w700, color: _brownSoft)),
            const SizedBox(width: 4),
            _LegendDot(_red, '<40 weak'),
            const SizedBox(width: 8),
            _LegendDot(_gold, '40–70 fair'),
            const SizedBox(width: 8),
            _LegendDot(_olive, '70+ strong'),
            const Spacer(),
            Text('${sorted.length} subject${sorted.length == 1 ? '' : 's'}',
              style: _nunito(size: 11, weight: FontWeight.w800, color: _brown)),
          ]),
        ),
        const SizedBox(height: 14),
        for (final s in sorted) Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SubjectMapCard(subject: s),
        ),
      ]),
    );
  }
}


class _SubjectMapCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  const _SubjectMapCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(subject['color'] ?? '#9DD4F0');
    final topics = (subject['topics'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final prof = _asD(subject['proficiency']) ?? 0;
    final avgFromTopics = topics.isEmpty ? 0.0
        : topics.map((t) => _asD(t['proficiency']) ?? 0).fold(0.0, (a, b) => a + b)
          / topics.length;
    // Use prof if backend provided it, else avg of topics (some accounts have 0 stored on Subject).
    final displayProf = prof > 0 ? prof : avgFromTopics;

    final weakest = topics.isEmpty ? null : topics.reduce(
      (a, b) => (_asD(a['proficiency']) ?? 0) < (_asD(b['proficiency']) ?? 0) ? a : b);
    final strongest = topics.isEmpty ? null : topics.reduce(
      (a, b) => (_asD(a['proficiency']) ?? 0) > (_asD(b['proficiency']) ?? 0) ? a : b);

    return Container(
      decoration: _pocketCard(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Coloured header strip
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(color: color.withOpacity(0.55)),
          child: Row(children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                border: Border.all(color: _outline, width: 1.5)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(subject['name']?.toString() ?? '',
              style: TextStyle(fontFamily: _bitroad, fontSize: 19, color: _brown))),
            Text('${displayProf.toInt()}%',
              style: TextStyle(fontFamily: _bitroad, fontSize: 24, color: _brown)),
            const SizedBox(width: 4),
            Text('avg', style: _nunito(size: 11, color: _brown, weight: FontWeight.w700)),
          ]),
        ),
        // Quick stats — use Wrap so conditional chips don't leave orphan
        // spacers in a Row (which used to break layout when the chip
        // widget itself wrapped in Expanded).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _MetaChip(label: 'topics', value: '${topics.length}', color: _mSlate),
            if (strongest != null) _MetaChip(
              label: 'strongest',
              value: '${(_asD(strongest['proficiency']) ?? 0).toInt()}%',
              color: _mSage),
            if (weakest != null) _MetaChip(
              label: 'weakest',
              value: '${(_asD(weakest['proficiency']) ?? 0).toInt()}%',
              color: _mTerra.withOpacity(0.65)),
          ]),
        ),
        // Topic list
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: topics.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('No topics yet — extract from a note or upload material.',
                  style: _gaegu(size: 12, color: _brownSoft)),
              )
            : Column(children: [
                for (final t in topics) _TopicProficiencyRow(topic: t),
              ]),
        ),
      ]),
    );
  }
}


class _TopicProficiencyRow extends StatelessWidget {
  final Map<String, dynamic> topic;
  const _TopicProficiencyRow({required this.topic});
  @override
  Widget build(BuildContext context) {
    final p = _asD(topic['proficiency']) ?? 0;
    final color = _heatColor(p);
    final sessions = _asI(topic['session_count']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(flex: 3, child: Text(topic['name']?.toString() ?? '',
          style: _gaegu(size: 13, color: _brown, weight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(flex: 5, child: Stack(children: [
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: _outline.withOpacity(0.06),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          FractionallySizedBox(
            widthFactor: (p / 100).clamp(0.02, 1.0),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _outline.withOpacity(0.3), width: 1),
              ),
            ),
          ),
        ])),
        const SizedBox(width: 10),
        SizedBox(width: 36, child: Text('${p.toInt()}%',
          textAlign: TextAlign.right,
          style: _nunito(size: 11, weight: FontWeight.w900, color: _brown))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _outline.withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${sessions}s',
            style: _nunito(size: 10, weight: FontWeight.w700, color: _brownSoft)),
        ),
      ]),
    );
  }
}


//  TAB 3: GAPS
class _GapsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GapsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final gaps = (data['gaps'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final flagged = (data['flagged_subjects'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (gaps.isEmpty && flagged.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _mMint.withOpacity(0.6), shape: BoxShape.circle,
              border: Border.all(color: _outline.withOpacity(0.3), width: 2.5),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                  offset: const Offset(3, 3), blurRadius: 0)],
            ),
            child: Icon(Icons.check_circle_rounded, size: 36, color: _brown),
          ),
          const SizedBox(height: 14),
          Text('No gaps detected!',
            style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
          const SizedBox(height: 4),
          Text('Every topic is at fair-or-better proficiency.',
            textAlign: TextAlign.center,
            style: _gaegu(size: 13, color: _brownSoft)),
        ])),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (gaps.isNotEmpty) ...[
          _SectionHeader('Weak Topics', icon: Icons.warning_amber_rounded,
            tint: _mTerra, count: gaps.length,
            subtitle: 'sorted by severity, then by proficiency'),
          const SizedBox(height: 10),
          for (final g in gaps) _GapCard(g: g),
        ],
        if (flagged.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionHeader('Flagged Subjects', icon: Icons.flag_rounded,
            tint: _mBlush, count: flagged.length,
            subtitle: 'far below your set target'),
          const SizedBox(height: 10),
          for (final f in flagged) _FlaggedCard(f: f),
        ],
      ]),
    );
  }
}


class _GapCard extends StatelessWidget {
  final Map<String, dynamic> g;
  const _GapCard({required this.g});

  @override
  Widget build(BuildContext context) {
    final severity = (g['severity'] as String?) ?? 'medium';
    final prof = _asD(g['proficiency']) ?? 0;
    final quizAvg = _asD(g['quiz_avg']) ?? 0;
    final focusAvg = _asD(g['focus_avg']) ?? 0;
    final cardAcc = _asD(g['card_accuracy']) ?? 0;
    final days = _asI(g['days_since_studied']);
    final subColor = _hexColor(g['subject_color'] ?? '#9DD4F0');

    final sevColor = severity == 'critical' ? _red
        : severity == 'high' ? const Color(0xFFF0A060) : _gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sevColor.withOpacity(0.7), width: 2),
        boxShadow: [BoxShadow(color: sevColor.withOpacity(0.28),
            offset: const Offset(3, 3), blurRadius: 0)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 6, color: sevColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sevColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: sevColor, width: 1)),
                child: Text(severity.toUpperCase(),
                  style: _nunito(size: 10, weight: FontWeight.w900,
                      color: _brown, letter: 0.8)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(g['topic']?.toString() ?? '',
                style: TextStyle(fontFamily: _bitroad, fontSize: 16, color: _brown))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: subColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: subColor, width: 1)),
                child: Text(g['subject_name']?.toString() ?? '',
                  style: _nunito(size: 10, weight: FontWeight.w800, color: _brown)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _MiniMetric(label: 'Proficiency', value: prof, color: sevColor)),
              const SizedBox(width: 10),
              Expanded(child: _MiniMetric(label: 'Quiz', value: quizAvg, color: _mSlate)),
              const SizedBox(width: 10),
              Expanded(child: _MiniMetric(label: 'Focus', value: focusAvg, color: _mLav)),
              const SizedBox(width: 10),
              Expanded(child: _MiniMetric(label: 'Cards', value: cardAcc * 100, color: _mSage)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: _mSage.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _mSage.withOpacity(0.5), width: 1),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_rounded, size: 14, color: _oliveDk),
                const SizedBox(width: 8),
                Expanded(child: Text(g['recommended_action']?.toString() ?? '',
                  style: _gaegu(size: 12, color: _brown, weight: FontWeight.w700, h: 1.3))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: days > 14 ? _mTerra.withOpacity(0.5)
                        : days > 7 ? _mButter.withOpacity(0.5)
                        : Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _outline.withOpacity(0.3), width: 1),
                  ),
                  child: Text(days >= 999 ? 'never' : '${days}d ago',
                    style: _nunito(size: 10, weight: FontWeight.w900, color: _brown)),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}


class _FlaggedCard extends StatelessWidget {
  final Map<String, dynamic> f;
  const _FlaggedCard({required this.f});
  @override
  Widget build(BuildContext context) {
    final current = _asD(f['current_proficiency']) ?? 0;
    final target = _asD(f['target_proficiency']) ?? 100;
    final gap = _asD(f['gap_percentage']) ?? 0;
    final color = _hexColor(f['color'] ?? '#9DD4F0');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: _softCard(),
      child: Row(children: [
        Container(width: 6, height: 40,
          decoration: BoxDecoration(color: color,
              borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f['name']?.toString() ?? '',
            style: TextStyle(fontFamily: _bitroad, fontSize: 15, color: _brown)),
          const SizedBox(height: 2),
          Text('${current.toInt()}% now · ${target.toInt()}% target',
            style: _gaegu(size: 11, color: _brownSoft, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              LinearProgressIndicator(
                value: (target / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: _outline.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(_outline.withOpacity(0.18)),
              ),
              LinearProgressIndicator(
                value: (current / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ]),
          ),
        ])),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _coral.withOpacity(0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _coral, width: 1)),
          child: Text('-${gap.toInt()}%',
            style: _nunito(size: 12, weight: FontWeight.w900, color: _brown)),
        ),
      ]),
    );
  }
}


//  TAB 4: COACH
class _CoachTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? coach;
  final bool loading;
  final VoidCallback onRegenerate, onJumpToGaps, onJumpToSchedule;
  const _CoachTab({
    required this.data, required this.coach, required this.loading,
    required this.onRegenerate, required this.onJumpToGaps,
    required this.onJumpToSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final briefing = (coach?['briefing'] as Map?)?.cast<String, dynamic>();

    if (loading && briefing == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(children: [
          CircularProgressIndicator(color: _mLav),
          const SizedBox(height: 14),
          Text('Drafting your coach briefing...',
            style: _gaegu(size: 16, color: _brownSoft, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('synthesizing your study stats',
            style: _nunito(size: 11, color: _brownSoft)),
        ]),
      );
    }

    if (briefing == null) {
      // Auto-kick the first fetch the moment this tab renders without data.
      // Guarded by `loading` so we don't double-trigger while a request is
      // already in flight.
      if (!loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onRegenerate());
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _pocketCard(fill: _mLav.withOpacity(0.25), radius: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _mLav.withOpacity(0.55), shape: BoxShape.circle,
                    border: Border.all(color: _outline.withOpacity(0.3), width: 2),
                    boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                        offset: const Offset(3, 3), blurRadius: 0)],
                  ),
                  child: Icon(Icons.auto_awesome_rounded, size: 22, color: _brown),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your Study Coach',
                      style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
                    Text(loading ? 'drafting your briefing…'
                        : 'tap Generate to fetch a fresh briefing',
                      style: _gaegu(size: 12, color: _brownSoft, weight: FontWeight.w700)),
                  ],
                )),
                if (loading)
                  SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _mLav)),
              ]),
              const SizedBox(height: 12),
              Text(
                'Your coach reads your real study data — sessions, quiz scores, '
                'flashcard accuracy, focus scores, and forgetting curves — then '
                'turns it into plain-English guidance. Nothing mocked, nothing '
                'invented. If briefing hasn\'t loaded yet, tap below to retry.',
                style: _gaegu(size: 13, color: _brown, weight: FontWeight.w600, h: 1.35)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: loading ? null : onRegenerate,
                child: _Pill(icon: Icons.auto_awesome_rounded,
                    label: loading ? 'Generating…' : 'Generate briefing',
                    color: _mLav, highlight: false),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          // Even without a briefing, surface real numbers so the tab is
          // never blank and always feels responsive.
          _CoachDataPeek(data: data),
        ]),
      );
    }

    final headline = briefing['headline']?.toString() ?? '';
    final narrative = briefing['narrative']?.toString() ?? '';
    final strengths = (briefing['strengths'] as List?)
        ?.map((e) => e.toString()).toList() ?? [];
    final focus = (briefing['focus'] as List?)
        ?.map((e) => e.toString()).toList() ?? [];
    final moves = (briefing['next_moves'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final mood = (briefing['mood'] as String?) ?? 'steady';
    final source = (coach?['source'] ?? briefing['source'])?.toString() ?? 'ai';

    final moodLabel = {
      'on_fire': '🔥 on fire',
      'steady': 'steady',
      'rebuilding': 'rebuilding',
      'drifting': 'drifting',
    }[mood] ?? 'steady';
    final moodColor = {
      'on_fire': _mButter,
      'steady': _mSage.withOpacity(0.85),
      'rebuilding': _mLav,
      'drifting': _mBlush,
    }[mood] ?? _mSage;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Headline card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _pocketCard(fill: _mLav.withOpacity(0.25), radius: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: moodColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _outline.withOpacity(0.4), width: 1.2),
                ),
                child: Text(moodLabel.toUpperCase(),
                  style: _nunito(size: 10, weight: FontWeight.w900,
                      color: _brown, letter: 0.8)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _cardFill.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _outline.withOpacity(0.25), width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(source == 'heuristic' ? Icons.functions_rounded
                      : Icons.auto_awesome_rounded,
                      size: 11, color: _brownLt),
                  const SizedBox(width: 4),
                  Text(source == 'heuristic' ? 'rule-based' : 'auto · $source',
                    style: _nunito(size: 9, weight: FontWeight.w800, color: _brownLt)),
                ]),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: loading ? null : onRegenerate,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _cardFill.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _outline.withOpacity(0.3), width: 1),
                  ),
                  child: loading
                    ? SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _brown))
                    : Icon(Icons.refresh_rounded, size: 14, color: _brown),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(headline,
              style: TextStyle(fontFamily: _bitroad, fontSize: 22,
                  color: _brown, height: 1.2)),
            if (narrative.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(narrative,
                style: _gaegu(size: 14, color: _brown, weight: FontWeight.w600, h: 1.4)),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        // Strengths + Focus row — plain Row with top-aligned children.
        // We used to wrap this in IntrinsicHeight to keep both cards
        // the same height, but IntrinsicHeight with Expanded(Text)
        // descendants throws "BoxConstraints forces an infinite height"
        // on some Flutter builds, which blanks the entire Coach tab.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _CoachListCard(
              title: 'Strengths',
              icon: Icons.workspace_premium_rounded,
              tint: _mSage.withOpacity(0.4),
              tintBorder: _olive,
              items: strengths,
              emptyMsg: 'Building data…',
            )),
            const SizedBox(width: 14),
            Expanded(child: _CoachListCard(
              title: 'Focus Patterns',
              icon: Icons.psychology_rounded,
              tint: _mSlate.withOpacity(0.45),
              tintBorder: _mSlate,
              items: focus,
              emptyMsg: 'Need more sessions to detect patterns.',
            )),
          ],
        ),
        const SizedBox(height: 18),

        // Next Moves
        _SectionHeader('Next 3 Moves', icon: Icons.flag_circle_rounded,
          tint: _mButter, subtitle: 'ranked by what unlocks the most progress'),
        const SizedBox(height: 10),
        if (moves.isEmpty)
          _InlineEmpty('No moves recommended right now — log a session to get fresh ideas.', _mLav)
        else
          for (int i = 0; i < moves.length; i++) _CoachMoveCard(
            rank: i + 1,
            move: moves[i],
            tint: i == 0 ? _mTerra.withOpacity(0.55)
                : i == 1 ? _mButter.withOpacity(0.55)
                : _mSage.withOpacity(0.5),
          ),

        const SizedBox(height: 14),
        // Quick jump buttons
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: onJumpToGaps,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: _softCard(fill: _mTerra.withOpacity(0.28)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: _brown),
                const SizedBox(width: 6),
                Text('See all gaps',
                  style: _gaegu(size: 13, color: _brown, weight: FontWeight.w800)),
              ]),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: onJumpToSchedule,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: _softCard(fill: _mButter.withOpacity(0.4)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.calendar_month_rounded, size: 16, color: _brown),
                const SizedBox(width: 6),
                Text('Open schedule',
                  style: _gaegu(size: 13, color: _brown, weight: FontWeight.w800)),
              ]),
            ),
          )),
        ]),
      ]),
    );
  }
}


// Fallback summary for Coach tab while the briefing loads.
class _CoachDataPeek extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CoachDataPeek({required this.data});
  @override
  Widget build(BuildContext context) {
    final overview = (data['overview'] as Map?)?.cast<String, dynamic>() ?? {};
    final readiness = _asD(overview['exam_readiness']) ?? 0;
    final weekMins = _asI(overview['this_week_minutes']);
    final topicsTotal = _asI(overview['topics_total']);
    final topicsWeak = _asI(overview['topics_weak']);
    final streak = _asI(overview['streak_days']);
    final gaps = (data['knowledge_gaps'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _pocketCard(fill: _cardFill, radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _mSage.withOpacity(0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _olive.withOpacity(0.5), width: 1),
            ),
            child: Icon(Icons.table_chart_rounded, size: 14, color: _brown),
          ),
          const SizedBox(width: 8),
          Text('LIVE DATA SNAPSHOT',
            style: TextStyle(fontFamily: _bitroad, fontSize: 13, color: _brown)),
        ]),
        const SizedBox(height: 4),
        Text('pulled from your own sessions, quizzes & cards — no mocks.',
          style: _gaegu(size: 11, color: _brownSoft, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _MetaChip(label: 'readiness', value: '${readiness.toInt()}%', color: _mSage),
          _MetaChip(label: 'this week', value: '${weekMins}m', color: _mLav),
          _MetaChip(label: 'streak', value: '${streak}d', color: _mButter),
          _MetaChip(label: 'weak topics',
            value: topicsTotal == 0 ? '—' : '$topicsWeak/$topicsTotal',
            color: _mTerra.withOpacity(0.6)),
          _MetaChip(label: 'gaps', value: '${gaps.length}',
            color: _mBlush),
        ]),
      ]),
    );
  }
}


class _CoachListCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color tint, tintBorder;
  final List<String> items;
  final String emptyMsg;
  const _CoachListCard({
    required this.title, required this.icon, required this.tint,
    required this.tintBorder, required this.items, required this.emptyMsg,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _pocketCard(fill: tint, borderColor: tintBorder, radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: _brown),
          const SizedBox(width: 6),
          Text(title.toUpperCase(),
            style: _nunito(size: 11, weight: FontWeight.w900,
                color: _brown, letter: 1.0)),
        ]),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(emptyMsg, style: _gaegu(size: 12, color: _brownSoft))
        else
          for (final s in items) Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _brown.withOpacity(0.6),
                    shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(s,
                style: _gaegu(size: 13, color: _brown,
                    weight: FontWeight.w600, h: 1.35))),
            ]),
          ),
      ]),
    );
  }
}


class _CoachMoveCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> move;
  final Color tint;
  const _CoachMoveCard({required this.rank, required this.move, required this.tint});
  @override
  Widget build(BuildContext context) {
    final title = move['title']?.toString() ?? '';
    final why = move['why']?.toString() ?? '';
    final mins = _asI(move['minutes']);
    // NOTE: do NOT use `Row(crossAxisAlignment.stretch)` here. This Row
    // sits inside a SingleChildScrollView > Column, which passes
    // unbounded height down. With `stretch`, the Row would forward an
    // infinite-height constraint to the rank badge container, causing
    // the "BoxConstraints forces an infinite height" assertion. Instead
    // we use IntrinsicHeight, which sizes the Row to the tallest child
    // first, then `stretch` works against a finite height. Because the
    // children here have no Expanded(Text) descendants, IntrinsicHeight
    // can compute safely (unlike the Coach Strengths/Focus row).
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _pocketCard(fill: _cardFill, radius: 16),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint),
            child: Text('$rank',
              style: TextStyle(fontFamily: _bitroad, fontSize: 28, color: _brown)),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text(title,
                style: TextStyle(fontFamily: _bitroad, fontSize: 16, color: _brown)),
              if (why.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(why,
                  style: _gaegu(size: 12, color: _brownSoft, weight: FontWeight.w600, h: 1.3)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                _SmallPill(icon: Icons.timer_rounded, label: '${mins}m', tint: _mSlate.withOpacity(0.55)),
                const SizedBox(width: 6),
                _SmallPill(icon: Icons.bolt_rounded,
                  label: rank == 1 ? 'do first' : rank == 2 ? 'next up' : 'soon',
                  tint: rank == 1 ? _mTerra.withOpacity(0.55)
                      : rank == 2 ? _mButter.withOpacity(0.55)
                      : _mSage.withOpacity(0.5)),
              ]),
            ]),
          )),
        ],
      )),
    );
  }
}


//  TAB 5: SCHEDULE
class _ScheduleTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ScheduleTab({required this.data});
  @override
  Widget build(BuildContext context) {
    final sched = (data['schedule'] as Map?)?.cast<String, dynamic>() ?? {};
    final recs = (sched['recommendations'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final cardsDue = _asI(sched['flashcards_due']);
    final cardsOverdue = _asI(sched['flashcards_overdue']);
    final preds = (data['predictions'] as Map?)?.cast<String, dynamic>() ?? {};
    final subjPred = (preds['subject_predictions'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    if (recs.isEmpty && cardsDue == 0 && subjPred.isEmpty) {
      // Even when there's nothing urgent, show live data so the tab
      // isn't a wall of whitespace. Everything below reads from real
      // analytics — no mocks.
      final overview = (data['overview'] as Map?)?.cast<String, dynamic>() ?? {};
      final weekMins = _asI(overview['this_week_minutes']);
      final streak = _asI(overview['streak_days']);
      final topicsTotal = _asI(overview['topics_total']);
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _pocketCard(fill: _mMint.withOpacity(0.45), radius: 18),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _mMint.withOpacity(0.85), shape: BoxShape.circle,
                  border: Border.all(color: _outline.withOpacity(0.35), width: 2),
                  boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                      offset: const Offset(3, 3), blurRadius: 0)],
                ),
                child: Icon(Icons.calendar_today_rounded, size: 26, color: _brown),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("You're on track!",
                    style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
                  const SizedBox(height: 2),
                  Text('No gaps flagged, no cards due, no forecasts yet. '
                      'Keep logging sessions and quizzes to unlock a schedule.',
                    style: _gaegu(size: 12, color: _brown, weight: FontWeight.w700, h: 1.3)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 14),
          _SectionHeader('Today\'s snapshot', icon: Icons.today_rounded,
            tint: _mSlate, subtitle: 'live from your account — no mocks'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _pocketCard(radius: 16),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              _MetaChip(label: 'this week', value: '${weekMins}m', color: _mLav),
              _MetaChip(label: 'streak', value: '${streak}d', color: _mButter),
              _MetaChip(label: 'topics', value: '$topicsTotal', color: _mSage),
              _MetaChip(label: 'cards due', value: '$cardsDue', color: _mSand),
            ]),
          ),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Flashcard summary card
        if (cardsDue > 0 || cardsOverdue > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold, width: 2),
              boxShadow: [BoxShadow(color: _gold.withOpacity(0.3),
                  offset: const Offset(3, 3), blurRadius: 0)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Container(height: 6, color: _gold),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _mButter.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
                    ),
                    child: Icon(Icons.style_rounded, size: 22, color: _brown),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text('Flashcard Review',
                      style: TextStyle(fontFamily: _bitroad,
                          fontSize: 17, color: _brown)),
                    Text(
                      '$cardsDue card${cardsDue == 1 ? '' : 's'} due'
                      '${cardsOverdue > 0 ? ' · $cardsOverdue overdue' : ''}',
                      style: _gaegu(size: 12, color: _brownSoft, weight: FontWeight.w700)),
                  ])),
                  if (cardsOverdue > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: _coral.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _coral, width: 1)),
                      child: Text('$cardsOverdue late',
                        style: _nunito(size: 11, weight: FontWeight.w900, color: _brown)),
                    ),
                ]),
              ),
            ]),
          ),

        if (recs.isNotEmpty) ...[
          _SectionHeader('Study Priorities', icon: Icons.flag_rounded,
            tint: _mTerra, count: recs.length,
            subtitle: 'sorted by urgency · severity-weighted'),
          const SizedBox(height: 10),
          for (int i = 0; i < recs.length; i++)
            _PriorityCard(rank: i + 1, r: recs[i]),
        ],

        if (subjPred.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionHeader('30 / 90-Day Forecast', icon: Icons.trending_up_rounded,
            tint: _mSlate, subtitle: 'projected proficiency by subject'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: _pocketCard(radius: 16),
            child: Column(children: [
              // header row
              Row(children: [
                Expanded(flex: 5, child: Text('Subject',
                  style: _nunito(size: 10, weight: FontWeight.w900,
                    color: _brownSoft, letter: 0.6))),
                SizedBox(width: 48, child: Text('Now', textAlign: TextAlign.center,
                  style: _nunito(size: 10, weight: FontWeight.w900, color: _brownSoft))),
                SizedBox(width: 48, child: Text('30d', textAlign: TextAlign.center,
                  style: _nunito(size: 10, weight: FontWeight.w900, color: _mSlate))),
                SizedBox(width: 48, child: Text('90d', textAlign: TextAlign.center,
                  style: _nunito(size: 10, weight: FontWeight.w900, color: _mLav))),
                const SizedBox(width: 30),
              ]),
              const SizedBox(height: 4),
              const Divider(height: 8, color: Color(0x22000000)),
              for (final p in subjPred) _ForecastRow(p: p),
            ]),
          ),
        ],
      ]),
    );
  }
}


class _PriorityCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> r;
  const _PriorityCard({required this.rank, required this.r});
  @override
  Widget build(BuildContext context) {
    final priority = (r['priority'] as String?) ?? 'medium';
    final subColor = _hexColor(r['subject_color'] ?? '#9DD4F0');
    final mins = _asI(r['recommended_mins']);
    final urgency = _asD(r['urgency']) ?? 0;

    final prioColor = priority == 'critical' ? _red
        : priority == 'high' ? const Color(0xFFF0A060) : _gold;

    // Same fix as _CoachMoveCard: IntrinsicHeight gives the Row a
    // bounded height before `stretch` propagates down, otherwise the
    // rank badge receives h=Infinity and throws.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _pocketCard(radius: 16),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: prioColor.withOpacity(0.22)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, children: [
              Text('#$rank',
                style: TextStyle(fontFamily: _bitroad, fontSize: 22, color: _brown)),
              Text('${urgency.toStringAsFixed(1)}',
                style: _nunito(size: 9, weight: FontWeight.w800, color: _brownLt)),
            ]),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: subColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: subColor, width: 1)),
                  child: Text(r['subject_name']?.toString() ?? '',
                    style: _nunito(size: 10, weight: FontWeight.w800, color: _brown)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: prioColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: prioColor, width: 1)),
                  child: Text(priority.toUpperCase(),
                    style: _nunito(size: 9, weight: FontWeight.w900,
                        color: _brown, letter: 0.7)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(r['topic']?.toString() ?? '',
                style: TextStyle(fontFamily: _bitroad, fontSize: 16, color: _brown)),
              const SizedBox(height: 2),
              Text(r['reason']?.toString() ?? '',
                style: _gaegu(size: 11, color: _brownSoft, weight: FontWeight.w600, h: 1.3)),
              const SizedBox(height: 8),
              Row(children: [
                _SmallPill(icon: Icons.timer_rounded, label: '${mins}m',
                  tint: _mSlate.withOpacity(0.55)),
                const SizedBox(width: 6),
                _SmallPill(icon: Icons.label_rounded,
                  label: r['session_type']?.toString() ?? 'practice',
                  tint: _mLav.withOpacity(0.55)),
              ]),
            ]),
          )),
        ],
      )),
    );
  }
}


class _ForecastRow extends StatelessWidget {
  final Map<String, dynamic> p;
  const _ForecastRow({required this.p});
  @override
  Widget build(BuildContext context) {
    final color = _hexColor(p['color'] ?? '#9DD4F0');
    final cur = _asD(p['current']) ?? 0;
    final p30 = _asD(p['predicted_30d']) ?? 0;
    final p90 = _asD(p['predicted_90d']) ?? 0;
    final trend = (p['trend'] as String?) ?? 'steady';
    final trendIcon = trend == 'improving' ? Icons.trending_up_rounded
        : trend == 'declining' ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final trendColor = trend == 'improving' ? _olive
        : trend == 'declining' ? _coral : _gold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 5, child: Row(children: [
          Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              border: Border.all(color: _outline.withOpacity(0.3), width: 1))),
          const SizedBox(width: 8),
          Expanded(child: Text(p['name']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
            style: _gaegu(size: 13, color: _brown, weight: FontWeight.w800))),
        ])),
        SizedBox(width: 48, child: Text('${cur.toInt()}', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: _bitroad, fontSize: 15, color: _brown))),
        SizedBox(width: 48, child: Text('${p30.toInt()}', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: _bitroad, fontSize: 15,
              color: trend == 'improving' ? _oliveDk : _brown))),
        SizedBox(width: 48, child: Text('${p90.toInt()}', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: _bitroad, fontSize: 15,
              color: trend == 'improving' ? _oliveDk : _brown))),
        SizedBox(width: 30, child: Icon(trendIcon, size: 18, color: trendColor)),
      ]),
    );
  }
}


//  SHARED WIDGETS

class _BackPill extends StatelessWidget {
  final VoidCallback onTap;
  const _BackPill({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
            offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Icon(Icons.arrow_back_rounded, size: 20, color: _brown),
    ),
  );
}


class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool highlight;
  const _Pill({required this.icon, required this.label, required this.color,
      this.highlight = false});
  @override
  Widget build(BuildContext context) {
    final txt = highlight ? Colors.white : _brown;
    final ic = highlight ? Colors.white : _outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.28),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: ic),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontFamily: _bitroad, fontSize: 13, color: txt)),
      ]),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color tint;
  final String? subtitle;
  final int? count;
  const _SectionHeader(this.title, {required this.icon, required this.tint,
      this.subtitle, this.count});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.16),
              offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Icon(icon, size: 16, color: _brown),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
          style: TextStyle(fontFamily: _bitroad, fontSize: 18, color: _brown)),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(subtitle!,
            style: _gaegu(size: 11, color: _brownSoft, weight: FontWeight.w600)),
      ])),
      if (count != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: tint.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _outline.withOpacity(0.25), width: 1),
          ),
          child: Text('$count',
            style: _nunito(size: 11, weight: FontWeight.w900, color: _brown)),
        ),
    ]);
  }
}


class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color tint;
  const _MetaPill({required this.icon, required this.label, required this.sub,
      required this.tint});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _outline.withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.14),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: _brown),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label,
            style: TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown, height: 1.0)),
          Text(sub,
            style: _nunito(size: 9, color: _brownLt, weight: FontWeight.w800, h: 1.1)),
        ]),
      ]),
    );
  }
}


// Small labelled value pill. Callers must wrap in Expanded/Flexible.
class _MetaChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetaChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
        Text(value,
          style: TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown, height: 1.1),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label,
          style: _nunito(size: 9, weight: FontWeight.w800, color: _brownLt, letter: 0.4)),
      ]),
    );
  }
}


// Labelled progress bar. Callers must wrap in Expanded/Flexible.
class _MiniMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniMetric({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Text(label,
          style: _nunito(size: 9, weight: FontWeight.w900, color: _brownSoft, letter: 0.4)),
        const Spacer(),
        Text('${value.toInt()}%',
          style: _nunito(size: 10, weight: FontWeight.w900, color: _brown)),
      ]),
      const SizedBox(height: 3),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (value / 100).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: color.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}


class _SmallPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  const _SmallPill({required this.icon, required this.label, required this.tint});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _outline.withOpacity(0.3), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: _brown),
        const SizedBox(width: 4),
        Text(label,
          style: _nunito(size: 10, weight: FontWeight.w800, color: _brown)),
      ]),
    );
  }
}


class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(3),
          border: Border.all(color: _outline.withOpacity(0.3), width: 1))),
      const SizedBox(width: 4),
      Text(label,
        style: _nunito(size: 10, weight: FontWeight.w700, color: _brownLt)),
    ]);
  }
}


class _InlineEmpty extends StatelessWidget {
  final String text;
  final Color tint;
  const _InlineEmpty(this.text, this.tint);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withOpacity(0.55),
            width: 1.5, style: BorderStyle.solid),
      ),
      child: Center(child: Text(text,
        textAlign: TextAlign.center,
        style: _gaegu(size: 13, color: _brown, weight: FontWeight.w700))),
    );
  }
}


//  PAW-PRINT BACKGROUND  (matches subjects/resources reference)
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const spacing = 90.0;
    const rowShift = 45.0;
    const pawR = 10.0;
    int idx = 0;
    for (double y = 30; y < size.height; y += spacing) {
      final isOddRow = ((y / spacing).floor() % 2) == 1;
      final xOffset = isOddRow ? rowShift : 0.0;
      for (double x = xOffset + 30; x < size.width; x += spacing) {
        paint.color = _pawClr.withOpacity(0.06 + (idx % 5) * 0.018);
        final angle = (idx % 4) * 0.3 - 0.3;
        canvas.save(); canvas.translate(x, y); canvas.rotate(angle);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero,
            width: pawR * 2.2, height: pawR * 1.8), paint);
        final tr = pawR * 0.52;
        canvas.drawCircle(Offset(-pawR * 1.0, -pawR * 1.35), tr, paint);
        canvas.drawCircle(Offset(-pawR * 0.38, -pawR * 1.65), tr, paint);
        canvas.drawCircle(Offset(pawR * 0.38, -pawR * 1.65), tr, paint);
        canvas.drawCircle(Offset(pawR * 1.0, -pawR * 1.35), tr, paint);
        canvas.restore();
        idx++;
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}
