//  CEREBRO — Cross-Domain Insights  (v2 — Study-Analytics shell parity)
//
//  Rebuilt from scratch to match the rest of the app (Subjects / Study
//  Analytics shell): mellow palette, pocket cards, Bitroad headings,
//  paw-print bg, stagger-in animations, pill tabs.
//
//  Tabs:
//   • Pulse    — Wellness ring + trend, headline, weekly stream, domain chips
//   • Patterns — Correlations table, detected patterns, cross-domain links
//   • Rhythms  — Weekday bars, hourly heatmap, sleep↔mood scatter
//   • Plan     — Prioritised recommendations with deep-links to each screen
//
//  Backend powering this: GET /api/v1/insights/dashboard

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/widgets/mood_sticker.dart';

const _ombre1 = Color(0xFFFFFBF7);
const _ombre2 = Color(0xFFFFF8F3);
const _ombre3 = Color(0xFFFFF3EF);
const _ombre4 = Color(0xFFFEEDE9);
const _pawClr = Color(0xFFF8BCD0);

const _outline   = Color(0xFF6E5848);
const _brown     = Color(0xFF4E3828);
const _brownLt   = Color(0xFF7A5840);
const _brownSoft = Color(0xFF9A8070);

const _cardFill = Color(0xFFFFF8F4);
const _cream    = Color(0xFFFDEFDB);

// Mellow palette (primary surfaces)
const _mTerra  = Color(0xFFD9B5A6);
const _mSlate  = Color(0xFFB6CBD6);
const _mSage   = Color(0xFFB5C4A0);
const _mMint   = Color(0xFFC8DCC2);
const _mLav    = Color(0xFFC9B8D9);
const _mButter = Color(0xFFE8D4A0);
const _mBlush  = Color(0xFFEAD0CE);
const _mSand   = Color(0xFFE8D9C2);

// Accent depths
const _olive   = Color(0xFF98A869);
const _coral   = Color(0xFFF7AEAE);
const _red     = Color(0xFFEF6262);
const _gold    = Color(0xFFE4BC83);

const _bitroad = 'Bitroad';

TextStyle _gaegu({double size = 14, FontWeight weight = FontWeight.w600,
        Color color = _brown, double? h}) =>
    GoogleFonts.gaegu(fontSize: size, fontWeight: weight, color: color, height: h);

TextStyle _nunito({double size = 12, FontWeight weight = FontWeight.w600,
        Color color = _brown, double? h, double? letter}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color,
        height: h, letterSpacing: letter);

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

// Heat ramp — red (weak) → gold (fair) → sage (strong).
Color _heatColor(double v) {
  final c = v.clamp(0.0, 100.0);
  if (c < 40) return Color.lerp(_red, _gold, c / 40)!;
  if (c < 70) return Color.lerp(_gold, _mSage, (c - 40) / 30)!;
  return Color.lerp(_mSage, _olive, (c - 70) / 30)!;
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
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  late final AnimationController _enter;

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _enter = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800))..forward();
    _fetch();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get('/insights/dashboard');
      if (!mounted) return;
      _data = resp.data is Map ? Map<String, dynamic>.from(resp.data) : {};
    } catch (e, st) {
      debugPrint('[INSIGHTS] fetch error: $e\n$st');
      if (mounted) _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

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
        decoration: const BoxDecoration(
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
                    const SizedBox(height: 12),
                    if (_data != null && (_data!['is_synthetic'] == true))
                      _stagger(0.04, _previewBanner()),
                    if (_data != null && (_data!['is_synthetic'] == true))
                      const SizedBox(height: 12),
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
    final data = _data ?? {};
    final score = _asI(data['wellness_score']);
    final trend = (data['wellness_trend'] as String?) ?? 'steady';
    final streak = _asI(data['streak_days']);

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _BackPill(onTap: () => Navigator.of(context).maybePop()),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Insights',
            style: TextStyle(fontFamily: _bitroad, fontSize: 26,
                color: _brown, height: 1.15)),
          const SizedBox(height: 2),
          Text('how your sleep, mood, study, and habits move together~',
            style: _gaegu(size: 15, color: _brownSoft, h: 1.3)),
        ],
      )),
      Wrap(spacing: 7, runSpacing: 7, children: [
        if (score > 0)
          _Pill(icon: Icons.favorite_rounded,
            label: '$score/100',
            color: _wellnessTintFor(score)),
        if (streak > 0)
          _Pill(icon: Icons.local_fire_department_rounded,
            label: '${streak}d streak', color: _mButter),
        _Pill(icon: _trendIcon(trend), label: trend,
          color: _trendColor(trend), highlight: trend == 'improving'),
        GestureDetector(
          onTap: _loading ? null : _fetch,
          child: _Pill(icon: Icons.refresh_rounded, label: 'Refresh',
              color: _mSage.withOpacity(0.85), highlight: true),
        ),
      ]),
    ]);
  }

  Color _wellnessTintFor(int score) {
    if (score >= 80) return _mSage;
    if (score >= 60) return _mMint;
    if (score >= 40) return _mButter;
    if (score >= 20) return _mBlush;
    return _mTerra;
  }

  IconData _trendIcon(String t) => switch (t) {
    'improving' => Icons.trending_up_rounded,
    'declining' => Icons.trending_down_rounded,
    _ => Icons.trending_flat_rounded,
  };
  Color _trendColor(String t) => switch (t) {
    'improving' => _mSage.withOpacity(0.85),
    'declining' => _mBlush,
    _ => _mSand,
  };

  Widget _previewBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: _softCard(fill: _mButter.withOpacity(0.28)),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _mButter,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.15),
                offset: const Offset(2, 2), blurRadius: 0)],
          ),
          child: const Icon(Icons.auto_awesome_rounded, size: 16, color: _brown),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sample insights',
              style: const TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown)),
            Text('You haven\'t logged much yet — these charts mix your real data with a demo preview.',
              style: _gaegu(size: 12, color: _brownSoft, h: 1.3)),
          ],
        )),
      ]),
    );
  }

  //  TAB BAR
  Widget _tabBar() {
    final tabs = <(IconData, String, Color)>[
      (Icons.favorite_rounded,         'Pulse',    _mBlush),
      (Icons.compare_arrows_rounded,   'Patterns', _mLav),
      (Icons.schedule_rounded,         'Rhythms',  _mSage),
      (Icons.lightbulb_outline_rounded,'Plan',     _mButter),
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
                      style: TextStyle(fontFamily: _bitroad, fontSize: 14,
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
    if (_data == null || _data!.isEmpty) return _emptyState();
    final avatarConfig = ref.watch(dashboardProvider).avatarConfig;
    return TabBarView(
      controller: _tabCtrl,
      physics: const ClampingScrollPhysics(),
      children: [
        _PulseTab(data: _data!, onRefresh: _fetch),
        _PatternsTab(data: _data!),
        _RhythmsTab(data: _data!, avatarConfig: avatarConfig),
        _PlanTab(data: _data!),
      ],
    );
  }

  Widget _loadingState() {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(children: [
        const CircularProgressIndicator(color: _olive, strokeWidth: 3),
        const SizedBox(height: 14),
        Text('Weaving your cross-domain story...',
          style: _gaegu(size: 16, color: _brownSoft, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('sleep · mood · study · habits',
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
            color: _mTerra.withOpacity(0.25), shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.3), width: 2.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: const Icon(Icons.cloud_off_rounded, size: 36, color: _brown),
        ),
        const SizedBox(height: 14),
        const Text("Couldn't load insights",
          style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(_error ?? '', textAlign: TextAlign.center,
            style: _gaegu(size: 12, color: _brownSoft)),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _fetch,
          child: _Pill(icon: Icons.refresh_rounded, label: 'Retry', color: _mSage),
        ),
      ]),
    );
  }

  Widget _emptyState() {
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
          child: const Icon(Icons.insights_rounded, size: 36, color: _brownLt),
        ),
        const SizedBox(height: 14),
        const Text('Nothing to show yet',
          style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
        const SizedBox(height: 4),
        Text('Log a mood, a sleep, or a study session to start building patterns.',
          textAlign: TextAlign.center,
          style: _gaegu(size: 13, color: _brownSoft)),
      ]),
    );
  }
}


//  TAB 1: PULSE
class _PulseTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const _PulseTab({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final score = _asI(data['wellness_score']);
    final breakdown = (data['wellness_breakdown'] as Map?)
        ?.cast<String, dynamic>() ?? {};
    final trend = (data['wellness_trend'] as String?) ?? 'steady';
    final headline = (data['headline'] as String?) ?? '';
    final history14 = ((data['wellness_history_14'] as List?) ?? [])
        .map((e) => _asD(e)).toList();
    final streams = (data['metric_streams_14'] as Map?)
        ?.cast<String, dynamic>() ?? {};
    final study = (data['study_summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final sleep = (data['sleep_summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final moodS = (data['mood_summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final habit = (data['habit_summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final weekly = (data['weekly_overview'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _olive,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IntrinsicHeight(child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _WellnessRingCard(
                score: score, trend: trend,
                breakdown: breakdown.map((k, v) => MapEntry(k, _asI(v))),
              )),
              const SizedBox(width: 14),
              Expanded(flex: 3, child: _HistoryCard(history: history14)),
            ],
          )),
          const SizedBox(height: 12),

          if (headline.isNotEmpty) _HeadlineCard(text: headline),
          if (headline.isNotEmpty) const SizedBox(height: 18),

          //    Deliberately NOT study minutes (that's in Study Analytics).
          _SectionHeader('Sleep this week',
            icon: Icons.nights_stay_rounded, tint: _mLav,
            subtitle: 'hours per night vs. your 7h target'),
          const SizedBox(height: 10),
          if (weekly.isEmpty)
            _InlineEmpty('Log a night of sleep to populate this week.', _mSand)
          else
            _WeeklyStrip(days: weekly),

          const SizedBox(height: 18),

          _SectionHeader('14-day streams',
            icon: Icons.show_chart_rounded, tint: _mLav,
            subtitle: 'each line tracks one signal over time'),
          const SizedBox(height: 10),
          _MetricStreamsCard(streams: streams),

          const SizedBox(height: 18),

          _SectionHeader('Domain pulse', icon: Icons.grain_rounded, tint: _mButter),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DomainChip(
              icon: Icons.menu_book_rounded, label: 'Study',
              value: '${_asI(study['total_minutes_week'])}m',
              sub: '${_asI(study['sessions_count'])} sessions this week',
              color: _mSlate)),
            const SizedBox(width: 10),
            Expanded(child: _DomainChip(
              icon: Icons.bedtime_rounded, label: 'Sleep',
              value: _asD(sleep['avg_hours']) == null
                ? '--' : '${_asD(sleep['avg_hours'])!.toStringAsFixed(1)}h',
              sub: '${_asI(sleep['nights_logged'])} nights logged',
              color: _mLav)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DomainChip(
              icon: Icons.mood_rounded, label: 'Mood',
              value: (moodS['dominant_mood'] as String?)?.isNotEmpty == true
                ? _capitalise(moodS['dominant_mood'] as String)
                : '--',
              sub: 'avg ${_asD(moodS['avg_score'])?.toStringAsFixed(1) ?? '--'}/5',
              color: _mBlush)),
            const SizedBox(width: 10),
            Expanded(child: _DomainChip(
              icon: Icons.check_circle_rounded, label: 'Habits',
              value: '${_asI(habit['avg_completion_pct'])}%',
              sub: 'avg completion',
              color: _mSage)),
          ]),
        ]),
      ),
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}


class _WellnessRingCard extends StatelessWidget {
  final int score;
  final String trend;
  final Map<String, int> breakdown;
  const _WellnessRingCard({required this.score, required this.trend,
      required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final ringColor = _heatColor(score.toDouble());
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _pocketCard(radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ringColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ringColor.withOpacity(0.45), width: 1),
            ),
            child: Text('WELLNESS',
              style: _nunito(size: 10, weight: FontWeight.w900,
                  color: _brown, letter: 1.0)),
          ),
          const Spacer(),
          Icon(_trendIcon(trend), size: 15, color: _brownLt),
        ]),
        const SizedBox(height: 14),
        Center(child: SizedBox(
          width: 140, height: 140,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 140, height: 140,
              child: CircularProgressIndicator(
                value: (score / 100).clamp(0.0, 1.0),
                strokeWidth: 12,
                backgroundColor: _outline.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$score',
                style: const TextStyle(fontFamily: _bitroad,
                    fontSize: 48, color: _brown, height: 1.0)),
              Text('of 100',
                style: _nunito(size: 10, weight: FontWeight.w900,
                    color: _brownLt, letter: 1.2, h: 1.4)),
            ]),
          ]),
        )),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _BreakdownPip('Sleep', breakdown['sleep'] ?? 0, _mLav)),
          const SizedBox(width: 6),
          Expanded(child: _BreakdownPip('Mood', breakdown['mood'] ?? 0, _mBlush)),
          const SizedBox(width: 6),
          Expanded(child: _BreakdownPip('Study', breakdown['study'] ?? 0, _mSlate)),
          const SizedBox(width: 6),
          Expanded(child: _BreakdownPip('Habits', breakdown['habits'] ?? 0, _mSage)),
        ]),
      ]),
    );
  }

  IconData _trendIcon(String t) => switch (t) {
    'improving' => Icons.trending_up_rounded,
    'declining' => Icons.trending_down_rounded,
    _ => Icons.trending_flat_rounded,
  };
}


class _BreakdownPip extends StatelessWidget {
  final String label;
  final int value; // out of 25
  final Color color;
  const _BreakdownPip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(children: [
        Text('$value',
          style: const TextStyle(fontFamily: _bitroad, fontSize: 16, color: _brown,
            height: 1.0)),
        Text('/25',
          style: _nunito(size: 8, color: _brownLt, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
          style: _nunito(size: 9, color: _brownLt, weight: FontWeight.w900,
              letter: 0.4)),
      ]),
    );
  }
}


class _HistoryCard extends StatelessWidget {
  final List<double?> history;
  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final present = history.whereType<double>().toList();
    final hasData = present.length >= 2;
    const maxY = 110.0; // headroom so the 100 label isn't clipped

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _pocketCard(radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _mSage.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _mSage.withOpacity(0.7), width: 1),
            ),
            child: Text('14-DAY WELLNESS',
              style: _nunito(size: 10, weight: FontWeight.w900,
                  color: _brown, letter: 1.0)),
          ),
          const Spacer(),
          if (hasData)
            Text('avg ${present.reduce((a, b) => a + b) ~/ present.length}',
              style: _nunito(size: 11, color: _brownSoft, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: hasData
            ? LineChart(LineChartData(
                minY: 0, maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: _outline.withOpacity(0.06), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  // Right padding so last data point can breathe
                  rightTitles: const AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 8,
                      getTitlesWidget: _empty)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 4,
                      getTitlesWidget: _empty)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 30, interval: 50,
                    getTitlesWidget: (v, _) {
                      if (v > 100.5) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('${v.toInt()}',
                          style: _nunito(size: 9, color: _brownSoft)));
                    })),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(
                      showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: _cardFill,
                    tooltipBorder: BorderSide(color: _outline.withOpacity(0.3)),
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      '${s.y.toInt()}',
                      _nunito(size: 11, weight: FontWeight.w800, color: _brown),
                    )).toList(),
                  ),
                ),
                lineBarsData: [LineChartBarData(
                  spots: [
                    for (int i = 0; i < history.length; i++)
                      if (history[i] != null) FlSpot(i.toDouble(), history[i]!),
                  ],
                  isCurved: true, curveSmoothness: 0.18,
                  preventCurveOverShooting: true,
                  color: _olive, barWidth: 2.8,
                  dotData: FlDotData(show: true,
                    getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                      radius: 3, color: _olive,
                      strokeColor: _cardFill, strokeWidth: 1.5)),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [_olive.withOpacity(0.3), _olive.withOpacity(0.0)]),
                  ),
                )],
              ))
            : Center(child: Text('Log for a couple days to grow this line.',
                style: _gaegu(size: 13, color: _brownSoft))),
        ),
        if (hasData) ...[
          const SizedBox(height: 6),
          // External x-axis labels — guaranteed not to clip
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('14d ago',
                  style: _nunito(size: 9, color: _brownSoft, weight: FontWeight.w700)),
                Text('1wk',
                  style: _nunito(size: 9, color: _brownSoft, weight: FontWeight.w700)),
                Text('today',
                  style: _nunito(size: 9, color: _brownSoft, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// Spacer for fl_chart axis title slots (kept empty just to claim space).
Widget _empty(double v, TitleMeta m) => const SizedBox();


class _HeadlineCard extends StatelessWidget {
  final String text;
  const _HeadlineCard({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _pocketCard(
        fill: _mBlush.withOpacity(0.30), borderColor: _mBlush, radius: 16),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _mBlush,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.15),
                offset: const Offset(2, 2), blurRadius: 0)],
          ),
          child: const Icon(Icons.auto_awesome_rounded, size: 18, color: _brown),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text,
          style: _gaegu(size: 14, weight: FontWeight.w700, color: _brown, h: 1.35))),
      ]),
    );
  }
}


/// Weekly strip showing SLEEP HOURS per day for the last 7 days. Deliberately
/// cross-domain — Study Analytics already shows study minutes by day, so this
/// card's job is to surface the sleep pattern (and how it compares to the
/// recommended 7h target).
///
/// Each column: sleep hours number above, vertical bar filling toward the
/// 7h target, day label below. A dashed target line sits across the bars
/// at 7h so undersleep is visually obvious. Summary strip under the chart
/// gives the weekly average, best night, and number of nights ≥ 7h.
class _WeeklyStrip extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const _WeeklyStrip({required this.days});

  static const double _targetSleep = 7.0;   // nightly target
  static const double _sleepScale  = 10.0;  // bar scale ceiling (hours)

  @override
  Widget build(BuildContext context) {
    const barSlotHeight = 82.0;

    final sleepVals = days.map((d) => _asD(d['sleep_hours']) ?? 0).toList();
    double sleepSum = 0; int sleepN = 0;
    for (final s in sleepVals) { if (s > 0) { sleepSum += s; sleepN++; } }
    final avgSleep = sleepN == 0 ? 0.0 : sleepSum / sleepN;

    // Best-night index (highest hours); -1 if no nights logged.
    int bestIdx = -1;
    double bestVal = 0;
    for (int i = 0; i < sleepVals.length; i++) {
      if (sleepVals[i] > bestVal) { bestVal = sleepVals[i]; bestIdx = i; }
    }
    final bestDayLabel = bestIdx >= 0 ? (days[bestIdx]['day']?.toString() ?? '') : '—';
    final nightsOnTarget = sleepVals.where((s) => s >= _targetSleep).length;

    // Target line y-offset within the bar stack.
    final targetTop = 16 /* hours label */
      + (barSlotHeight - (_targetSleep / _sleepScale) * barSlotHeight);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: _softCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: barSlotHeight + 22,
          child: Stack(children: [
            // Bars row
            Positioned.fill(child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (int i = 0; i < days.length; i++) Expanded(
                child: _WeeklyBar(
                  hours: sleepVals[i],
                  scale: _sleepScale,
                  target: _targetSleep,
                  slotHeight: barSlotHeight,
                  isBest: i == bestIdx && sleepVals[i] > 0,
                ),
              )],
            )),
            // 7h target dashed line
            Positioned(
              left: 0, right: 0, top: targetTop,
              child: CustomPaint(
                size: const Size.fromHeight(1),
                painter: _DashedLinePainter(
                  color: _outline.withOpacity(0.55),
                  dashWidth: 4, dashGap: 3),
              ),
            ),
            Positioned(
              right: 0, top: targetTop - 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _outline.withOpacity(0.35), width: 0.8),
                ),
                child: Text('7h target',
                  style: _nunito(size: 8.5, color: _brownSoft,
                      weight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [for (final d in days) Expanded(
          child: Text(d['day']?.toString() ?? '',
            textAlign: TextAlign.center,
            style: _nunito(size: 11, color: _brown, weight: FontWeight.w800)),
        )]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline.withOpacity(0.2), width: 1),
          ),
          child: Row(children: [
            _WeeklyStat(label: 'weekly avg',
              value: avgSleep > 0 ? '${avgSleep.toStringAsFixed(1)}h' : '—'),
            _WeeklyDivider(),
            _WeeklyStat(label: 'best night',
              value: bestIdx >= 0 ? bestDayLabel : '—'),
            _WeeklyDivider(),
            _WeeklyStat(label: 'on target',
              value: '$nightsOnTarget/7'),
          ]),
        ),
      ]),
    );
  }
}


/// One vertical sleep-hours bar. Color flips to sage above the 7h target
/// and blush when short. Hours label sits above each bar when > 0.
class _WeeklyBar extends StatelessWidget {
  final double hours;
  final double scale;
  final double target;
  final double slotHeight;
  final bool isBest;
  const _WeeklyBar({required this.hours, required this.scale,
      required this.target, required this.slotHeight, required this.isBest});

  @override
  Widget build(BuildContext context) {
    final pct = (hours / scale).clamp(0.0, 1.0);
    final barH = hours <= 0 ? 0.0 : math.max(4.0, pct * slotHeight);
    final onTarget = hours >= target;

    // Bar color: sage if on-target, blush if short, star-accent if "best".
    final List<Color> colors;
    if (isBest) {
      colors = [_mSage, _mSage.withOpacity(0.55)];
    } else if (onTarget) {
      colors = [_mSage.withOpacity(0.85), _mSage.withOpacity(0.45)];
    } else {
      colors = [_mBlush, _mBlush.withOpacity(0.45)];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 16,
          child: hours > 0
            ? Text('${hours.toStringAsFixed(1)}h',
                textAlign: TextAlign.center,
                style: _nunito(size: 9.5, color: _brownSoft,
                    weight: FontWeight.w800))
            : null,
        ),
        SizedBox(
          height: slotHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: barH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _outline.withOpacity(isBest ? 0.55 : 0.3),
                  width: isBest ? 1.4 : 1),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}


class _WeeklyStat extends StatelessWidget {
  final String label;
  final String value;
  const _WeeklyStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
          style: const TextStyle(fontFamily: _bitroad, fontSize: 14,
              color: _brown, height: 1.0)),
        const SizedBox(height: 2),
        Text(label,
          style: _nunito(size: 9.5, color: _brownSoft,
              weight: FontWeight.w800, letter: 0.4)),
      ],
    ));
  }
}


class _WeeklyDivider extends StatelessWidget {
  const _WeeklyDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 24,
    color: _outline.withOpacity(0.15),
  );
}


/// Dashed horizontal line used to draw the "your average" indicator across
/// the 7-day study bars.
class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashGap;
  _DashedLinePainter({required this.color,
      this.dashWidth = 4, this.dashGap = 3});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0),
        Offset(math.min(x + dashWidth, size.width), 0), paint);
      x += dashWidth + dashGap;
    }
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}


class _MetricStreamsCard extends StatefulWidget {
  final Map<String, dynamic> streams;
  const _MetricStreamsCard({required this.streams});
  @override
  State<_MetricStreamsCard> createState() => _MetricStreamsCardState();
}

class _MetricStreamsCardState extends State<_MetricStreamsCard> {
  int _selected = 0;

  List<(String, String, Color, double, String)> _streamSpecs() => [
    ('sleep_hours',   'Sleep',  _mLav,    12.0, 'h'),
    ('mood_score',    'Mood',   _mBlush,  5.0,  '/5'),
    ('study_minutes', 'Study',  _mSlate,  -1,   'm'),
    ('focus_score',   'Focus',  _olive,   100.0,'%'),
    ('habit_pct',     'Habits', _mSage,   100.0,'%'),
  ];

  @override
  Widget build(BuildContext context) {
    final specs = _streamSpecs();
    final current = specs[_selected];
    final raw = (widget.streams[current.$1] as List?) ?? [];
    final values = raw.map((e) => _asD(e)).toList();
    final nonNull = values.whereType<double>().toList();
    final maxY = current.$4 > 0
      ? current.$4
      : (nonNull.isEmpty ? 60.0 : nonNull.reduce(math.max) * 1.25).clamp(10.0, 999.0);
    // Render the chart as soon as there's anything to render. fl_chart
    // handles sparse data fine — a single point draws as a dot with the
    // filled area underneath. The old ">= 2" threshold was nagging the
    // user with "Not enough data for mood yet" even on real logged data.
    final hasData = nonNull.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _pocketCard(radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Chip selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (int i = 0; i < specs.length; i++) Padding(
              padding: EdgeInsets.only(right: i < specs.length - 1 ? 6 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _selected = i),
                child: _StreamChip(
                  label: specs[i].$2, color: specs[i].$3,
                  active: _selected == i),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: hasData
            ? LineChart(LineChartData(
                minY: 0, maxY: maxY * 1.08, // 8% headroom so peaks can breathe
                clipData: const FlClipData.all(),
                gridData: FlGridData(show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: _outline.withOpacity(0.06), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 4,
                      getTitlesWidget: _empty)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 8,
                      getTitlesWidget: _empty)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 34,
                    interval: maxY / 3,
                    getTitlesWidget: (v, _) {
                      if (v > maxY * 1.01) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('${v.toStringAsFixed(v >= 10 ? 0 : 1)}${current.$5}',
                          style: _nunito(size: 9, color: _brownSoft)));
                    })),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(
                      showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: _cardFill,
                    tooltipBorder: BorderSide(color: _outline.withOpacity(0.3)),
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(s.y >= 10 ? 0 : 1)}${current.$5}',
                      _nunito(size: 11, weight: FontWeight.w800, color: _brown),
                    )).toList(),
                  ),
                ),
                lineBarsData: [LineChartBarData(
                  spots: [
                    for (int i = 0; i < values.length; i++)
                      if (values[i] != null) FlSpot(i.toDouble(), values[i]!),
                  ],
                  isCurved: true, curveSmoothness: 0.18,
                  preventCurveOverShooting: true,
                  color: current.$3.withOpacity(0.95), barWidth: 3,
                  dotData: FlDotData(show: true,
                    getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                      radius: 3, color: current.$3,
                      strokeColor: _cardFill, strokeWidth: 1.5)),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [current.$3.withOpacity(0.35), current.$3.withOpacity(0.0)]),
                  ),
                )],
              ))
            : Center(child: Text(
                'Not enough data for ${current.$2.toLowerCase()} yet.',
                style: _gaegu(size: 13, color: _brownSoft))),
        ),
        if (hasData) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 34, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('14d',
                  style: _nunito(size: 9, color: _brownSoft, weight: FontWeight.w700)),
                Text('1wk',
                  style: _nunito(size: 9, color: _brownSoft, weight: FontWeight.w700)),
                Text('today',
                  style: _nunito(size: 9, color: _brownSoft, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}


class _StreamChip extends StatelessWidget {
  final String label; final Color color; final bool active;
  const _StreamChip({required this.label, required this.color, required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color : color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? _outline : _outline.withOpacity(0.22),
          width: active ? 2 : 1.2),
        boxShadow: active
          ? [BoxShadow(color: _outline.withOpacity(0.2),
              offset: const Offset(2, 2), blurRadius: 0)]
          : null,
      ),
      child: Text(label,
        style: TextStyle(fontFamily: _bitroad,
            fontSize: 13,
            color: active ? _brown : _brownLt,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700)),
    );
  }
}


class _DomainChip extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  const _DomainChip({required this.icon, required this.label,
      required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: _softCard(fill: color.withOpacity(0.22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, size: 13, color: _brown),
          ),
          const SizedBox(width: 7),
          Text(label.toUpperCase(),
            style: _nunito(size: 10, weight: FontWeight.w900,
                color: _brown, letter: 0.8)),
        ]),
        const SizedBox(height: 8),
        Text(value,
          style: const TextStyle(fontFamily: _bitroad,
              fontSize: 22, color: _brown, height: 1.05)),
        const SizedBox(height: 2),
        Text(sub,
          style: _nunito(size: 10, color: _brownSoft, weight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}


//  TAB 2: PATTERNS
class _PatternsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PatternsTab({required this.data});
  @override
  Widget build(BuildContext context) {
    final correlations = (data['correlations'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final patterns = (data['patterns'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    // Split the list into visually distinct tiers so the strongest signals
    // actually feel strongest. Backend already sorted by |r| desc and
    // filtered out anything < 0.3.
    //   • headline  → the single strongest (only if |r| >= 0.35)
    //   • top       → the next 2 after the headline (strong/moderate)
    //   • tail      → everything else, shown as compact rows
    Map<String, dynamic>? headline;
    List<Map<String, dynamic>> top = [];
    List<Map<String, dynamic>> tail = [];
    if (correlations.isNotEmpty) {
      final first = correlations.first;
      final firstMag = ((_asD(first['correlation']) ?? 0)).abs();
      if (firstMag >= 0.35) {
        headline = first;
        top = correlations.skip(1).take(2).toList();
        tail = correlations.skip(3).toList();
      } else {
        // Nothing strong enough to "headline" — just show the list as top/tail.
        top = correlations.take(3).toList();
        tail = correlations.skip(3).toList();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeader('Cross-domain correlations',
          icon: Icons.compare_arrows_rounded, tint: _mLav,
          subtitle: 'your strongest signals, sorted by impact',
          count: correlations.length),
        const SizedBox(height: 10),
        if (correlations.isEmpty)
          _InlineEmpty(
            'Log sleep, mood, and study for a week or so to surface links.',
            _mSand)
        else ...[
          if (headline != null) ...[
            _CorrelationHeadline(item: headline),
            const SizedBox(height: 14),
          ],
          if (top.isNotEmpty) ...[
            _MiniHeader(
              label: headline == null ? 'Top signals' : 'Other strong links',
              tint: _mSage,
            ),
            const SizedBox(height: 8),
            for (final c in top) _CorrelationRow(item: c),
          ],
          if (tail.isNotEmpty) ...[
            const SizedBox(height: 8),
            _MiniHeader(label: 'Weaker but still worth noting', tint: _mSand),
            const SizedBox(height: 8),
            for (final c in tail) _CorrelationCompactRow(item: c),
          ],
        ],

        const SizedBox(height: 20),

        _SectionHeader('Detected patterns',
          icon: Icons.auto_graph_rounded, tint: _mSage,
          subtitle: 'rules of thumb we can see in your data',
          count: patterns.length),
        const SizedBox(height: 10),
        if (patterns.isEmpty)
          _InlineEmpty(
            'Nothing distinctive yet — keep logging and patterns will surface.',
            _mSand)
        else
          Column(children: [
            for (final p in patterns) _PatternRow(item: p),
          ]),
      ]),
    );
  }
}


class _CorrelationRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CorrelationRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final corr = _asD(item['correlation']) ?? 0;
    final strength = item['strength']?.toString() ?? 'weak';
    final label = item['label']?.toString() ?? '';
    final insight = item['insight']?.toString() ?? '';
    final n = _asI(item['n_samples']);
    final isPos = corr >= 0;
    final magnitude = corr.abs();
    final barColor = _strengthColor(strength, isPos);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _softCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: barColor, shape: BoxShape.circle,
              border: Border.all(color: _outline.withOpacity(0.25), width: 0.8),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(label,
            style: const TextStyle(fontFamily: _bitroad, fontSize: 16, color: _brown))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: barColor, width: 1),
            ),
            child: Text(
              '${isPos ? "+" : ""}${corr.toStringAsFixed(2)} · $strength',
              style: _nunito(size: 10, weight: FontWeight.w900, color: _brown)),
          ),
        ]),
        const SizedBox(height: 10),
        // Symmetric bar: centerline at zero, slides left (neg) or right (pos)
        _CorrelationBar(value: corr, color: barColor),
        const SizedBox(height: 8),
        Text(insight,
          style: _gaegu(size: 13, color: _brown, h: 1.35, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('$n days compared',
          style: _nunito(size: 10, color: _brownSoft, weight: FontWeight.w700)),
      ]),
    );
  }

  Color _strengthColor(String s, bool pos) {
    final base = pos ? _mSage : _mBlush;
    if (s == 'strong') return pos ? _olive : _red;
    if (s == 'moderate') return base;
    return _mSand;
  }
}


/// Small all-caps divider label for the tiered correlation list.
/// Lives between sections ("Top signals" / "Weaker but still worth noting")
/// so the hierarchy reads at a glance.
class _MiniHeader extends StatelessWidget {
  final String label;
  final Color tint;
  const _MiniHeader({required this.label, required this.tint});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 18, height: 3,
        decoration: BoxDecoration(
          color: tint, borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(label.toUpperCase(),
        style: _nunito(
          size: 10.5, weight: FontWeight.w900,
          color: _brownSoft, letter: 1.3)),
    ]);
  }
}


/// Featured card for the single strongest correlation. Bigger type, a
/// pocket-style decoration, and a "STRONGEST SIGNAL" badge so the user
/// instantly sees which relationship matters most in their data.
class _CorrelationHeadline extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CorrelationHeadline({required this.item});

  Color _strengthColor(String s, bool pos) {
    final base = pos ? _mSage : _mBlush;
    if (s == 'strong') return pos ? _olive : _red;
    if (s == 'moderate') return base;
    return _mSand;
  }

  @override
  Widget build(BuildContext context) {
    final corr = _asD(item['correlation']) ?? 0;
    final strength = item['strength']?.toString() ?? 'moderate';
    final label = item['label']?.toString() ?? '';
    final insight = item['insight']?.toString() ?? '';
    final n = _asI(item['n_samples']);
    final isPos = corr >= 0;
    final barColor = _strengthColor(strength, isPos);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: _pocketCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _mButter.withOpacity(0.55),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outline.withOpacity(0.25), width: 0.8),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded, size: 11, color: _brown),
              const SizedBox(width: 4),
              Text('STRONGEST SIGNAL',
                style: _nunito(
                  size: 9.5, weight: FontWeight.w900,
                  color: _brown, letter: 1.3)),
            ]),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.28),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: barColor, width: 1.1),
            ),
            child: Text(
              '${isPos ? "+" : ""}${corr.toStringAsFixed(2)} · $strength',
              style: _nunito(size: 10.5, weight: FontWeight.w900, color: _brown)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(label,
          style: const TextStyle(
            fontFamily: _bitroad, fontSize: 20, color: _brown, height: 1.1)),
        const SizedBox(height: 10),
        _CorrelationBar(value: corr, color: barColor),
        const SizedBox(height: 10),
        Text(insight,
          style: _gaegu(size: 14, color: _brown, h: 1.4, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Based on $n days of overlapping data',
          style: _nunito(size: 10.5, color: _brownSoft, weight: FontWeight.w700)),
      ]),
    );
  }
}


/// Compact card for the "tail" correlations — the ones that passed the
/// relevance filter (|r| >= 0.3) but aren't headline-worthy. Still shows
/// the label, coefficient pill, AND the insight explanation so every
/// surfaced correlation gets a "so what" readable by the user. Only the
/// big symmetric bar chart is dropped (coefficient pill + tight bar is
/// enough for lesser signals).
class _CorrelationCompactRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CorrelationCompactRow({required this.item});

  Color _strengthColor(String s, bool pos) {
    final base = pos ? _mSage : _mBlush;
    if (s == 'strong') return pos ? _olive : _red;
    if (s == 'moderate') return base;
    return _mSand;
  }

  @override
  Widget build(BuildContext context) {
    final corr = _asD(item['correlation']) ?? 0;
    final strength = item['strength']?.toString() ?? 'weak';
    final label = item['label']?.toString() ?? '';
    final insight = item['insight']?.toString() ?? '';
    final n = _asI(item['n_samples']);
    final isPos = corr >= 0;
    final barColor = _strengthColor(strength, isPos);
    final magnitude = corr.abs().clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: _cream.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _outline.withOpacity(0.18), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: barColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(label,
            style: _nunito(size: 12.5, weight: FontWeight.w800, color: _brown),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.22),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: barColor.withOpacity(0.8), width: 0.9),
            ),
            child: Text(
              '${isPos ? "+" : ""}${corr.toStringAsFixed(2)} · $strength',
              style: _nunito(size: 10, weight: FontWeight.w900, color: _brown)),
          ),
        ]),
        // Tight horizontal strength bar — gives the eye a quick magnitude
        // read without the full centered +/– scale on the headline card.
        const SizedBox(height: 7),
        LayoutBuilder(builder: (ctx, bc) {
          final w = bc.maxWidth;
          return Stack(children: [
            Container(
              height: 4, width: w,
              decoration: BoxDecoration(
                color: _outline.withOpacity(0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              height: 4, width: w * magnitude,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ]);
        }),
        const SizedBox(height: 7),
        if (insight.isNotEmpty)
          Text(insight,
            style: _gaegu(
              size: 12.5, color: _brown, h: 1.35, weight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text('$n days compared',
          style: _nunito(size: 9.5, color: _brownSoft, weight: FontWeight.w700)),
      ]),
    );
  }
}


class _CorrelationBar extends StatelessWidget {
  final double value; // -1..1
  final Color color;
  const _CorrelationBar({required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, bc) {
      final w = bc.maxWidth;
      final mid = w / 2;
      final clamp = value.clamp(-1.0, 1.0);
      final half = (clamp.abs() * (mid - 4));
      return Stack(children: [
        Container(height: 10,
          decoration: BoxDecoration(
            color: _outline.withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        Positioned(
          left: clamp < 0 ? mid - half : mid,
          top: 0,
          child: Container(
            width: half, height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        // Centerline tick
        Positioned(
          left: mid - 0.6, top: -2,
          child: Container(width: 1.2, height: 14,
            color: _outline.withOpacity(0.5)),
        ),
      ]);
    });
  }
}


class _PatternRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _PatternRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final severity = (item['severity'] as String?) ?? 'info';
    final tint = severity == 'positive'
      ? _mSage
      : severity == 'warning' ? _mBlush : _mSlate;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _softCard(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 4, height: 36,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['title']?.toString() ?? '',
              style: const TextStyle(fontFamily: _bitroad, fontSize: 15, color: _brown)),
            const SizedBox(height: 3),
            Text(item['description']?.toString() ?? '',
              style: _gaegu(size: 12, color: _brownSoft, h: 1.35,
                  weight: FontWeight.w600)),
          ],
        )),
      ]),
    );
  }

}


//  TAB 3: RHYTHMS
class _RhythmsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final AvatarConfig? avatarConfig;
  const _RhythmsTab({required this.data, this.avatarConfig});

  @override
  Widget build(BuildContext context) {
    final rhythms = (data['rhythms'] as Map?)?.cast<String, dynamic>() ?? {};
    final byWeekday = (rhythms['by_weekday'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final scatter = (rhythms['sleep_mood_scatter'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final bedtimeSpread = _asD(rhythms['bedtime_spread_hours']);
    final bedtimeMedian = _asD(rhythms['bedtime_median']);

    final records = (data['day_records_30'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    // Every chart on this tab combines ≥2 wellness domains.
    // Single-domain views (study-only weekday bars, study-only hourly heat-
    // map, 30-day study trend) live on Study Analytics — not here. Insights
    // is the cross-domain lens: sleep ↔ mood ↔ habits ↔ study all at once.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 1. What actually drives your best days? Compares top-tier mood
        // days vs low-tier days across 4 metrics. Highly actionable — the
        // most "coach-like" view on the whole screen.
        _SectionHeader('What fuels your best days',
          icon: Icons.auto_awesome_rounded, tint: _mSage,
          subtitle: 'your top-mood days vs low-mood days, side by side'),
        const SizedBox(height: 10),
        _BestDaysFormula(records: records),

        const SizedBox(height: 18),

        // 2. Causal lag view: last night's sleep → today's mood.
        _SectionHeader('Sleep → next-day mood',
          icon: Icons.nightlight_round_rounded, tint: _mLav,
          subtitle: "last night's hours (bars) vs today's mood (dots)"),
        const SizedBox(height: 10),
        _SleepLagMoodChart(records: records),

        const SizedBox(height: 18),

        // 3. Weekday mood + sleep (kept — already cross-domain).
        _SectionHeader('Which weekday feels best',
          icon: Icons.mood_rounded, tint: _mSlate,
          subtitle: 'avg mood score + avg sleep per day of the week'),
        const SizedBox(height: 10),
        if (byWeekday.isEmpty)
          _InlineEmpty('Log your mood on a few weekdays to see the pattern.',
            _mSand)
        else
          _WeekdayGrid(days: byWeekday),

        const SizedBox(height: 18),

        // 4. Sleep ↔ mood scatter (30-day window now, clipping fixed).
        _SectionHeader('Sleep vs mood',
          icon: Icons.scatter_plot_rounded, tint: _mBlush,
          subtitle: 'each sticker = one of your last 30 days'),
        const SizedBox(height: 10),
        if (scatter.isEmpty)
          _InlineEmpty('Log sleep and a mood on the same day to drop a sticker here.',
            _mSand)
        else
          _SleepMoodScatter(points: scatter, avatarConfig: avatarConfig),

        const SizedBox(height: 18),

        // 5. Bedtime consistency — this reads the rhythms.bedtime_* fields
        // that were already in the payload but never rendered anywhere.
        _SectionHeader('Bedtime consistency',
          icon: Icons.schedule_rounded, tint: _mButter,
          subtitle: 'how steady your lights-out time has been'),
        const SizedBox(height: 10),
        _BedtimeConsistencyCard(records: records,
          spread: bedtimeSpread, median: bedtimeMedian),

        const SizedBox(height: 18),

        // 6. Habits → mood lift. Closes the loop: mood isn't just sleep-
        // driven, it's also behaviour-driven.
        _SectionHeader('Habits → mood lift',
          icon: Icons.favorite_rounded, tint: _mBlush,
          subtitle: 'mood on full-habit days vs skip days'),
        const SizedBox(height: 10),
        _HabitMoodLiftCard(records: records),
      ]),
    );
  }
}


/// Horizontal bar chart: one row per weekday (Mon…Sun), bar length = avg
/// mood score (1–5) for that day of the week. Trailing metric: avg sleep
/// hours on that weekday. The day with the highest mood gets a sage tint
/// plus a star so "which weekday feels best" is obvious.
///
/// Deliberately cross-domain (mood + sleep) so it doesn't duplicate Study
/// Analytics, which already shows study minutes by weekday.
class _WeekdayGrid extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const _WeekdayGrid({required this.days});

  @override
  Widget build(BuildContext context) {
    // Mood bar is always on a fixed 0..5 scale — no normalization needed.
    const moodMax = 5.0;

    // Best weekday by mood (for accent + star).
    int bestIdx = -1;
    double bestMood = 0;
    for (int i = 0; i < days.length; i++) {
      final m = _asD(days[i]['mood_score']) ?? 0;
      if (m > bestMood) { bestMood = m; bestIdx = i; }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _pocketCard(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 34, right: 4, bottom: 6),
          child: Row(children: [
            Expanded(child: Text('avg mood',
              style: _nunito(size: 9, color: _brownSoft,
                  weight: FontWeight.w800, letter: 0.4))),
            SizedBox(width: 46, child: Text('avg sleep',
              textAlign: TextAlign.right,
              style: _nunito(size: 9, color: _brownSoft,
                  weight: FontWeight.w800, letter: 0.4))),
          ]),
        ),
        for (int i = 0; i < days.length; i++)
          _WeekdayRow(
            label: days[i]['day']?.toString() ?? '',
            mood: _asD(days[i]['mood_score']) ?? 0,
            sleep: _asD(days[i]['sleep_hours']) ?? 0,
            moodMax: moodMax,
            isBest: i == bestIdx && bestMood > 0,
          ),
      ]),
    );
  }
}


class _WeekdayRow extends StatelessWidget {
  final String label;
  final double mood;      // 0..5
  final double sleep;     // hours
  final double moodMax;
  final bool isBest;
  const _WeekdayRow({required this.label, required this.mood,
      required this.sleep, required this.moodMax, required this.isBest});

  @override
  Widget build(BuildContext context) {
    final pct = (mood / moodMax).clamp(0.0, 1.0);
    final barColors = isBest
      ? [_mSage, _mSage.withOpacity(0.55)]
      : [_mBlush, _mBlush.withOpacity(0.45)];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 30,
          child: Text(label,
            style: _nunito(size: 11, color: _brown,
                weight: FontWeight.w800))),
        const SizedBox(width: 4),
        // Mood bar (0..5 scale)
        Expanded(child: SizedBox(
          height: 20,
          child: LayoutBuilder(builder: (ctx, bc) {
            final trackW = bc.maxWidth;
            final fillW = math.max(2.0, pct * trackW);
            return Stack(children: [
              // Track with tick marks at 1,2,3,4 (so a viewer can tell the scale)
              Positioned.fill(child: Container(
                decoration: BoxDecoration(
                  color: _outline.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _outline.withOpacity(0.12),
                      width: 0.8),
                ),
              )),
              for (int tick = 1; tick <= 4; tick++) Positioned(
                left: (tick / moodMax) * trackW - 0.5,
                top: 4, bottom: 4,
                child: Container(width: 1,
                  color: _outline.withOpacity(0.08)),
              ),
              if (mood > 0) Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: fillW,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: barColors),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _outline.withOpacity(isBest ? 0.55 : 0.3),
                      width: isBest ? 1.4 : 1),
                  ),
                ),
              ),
              // Mood value inside bar (or to the right if bar is too short)
              Positioned(
                left: fillW > 46 ? 8 : fillW + 6,
                top: 0, bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(mood > 0 ? mood.toStringAsFixed(1) : '—',
                    style: _nunito(size: 10.5,
                        color: fillW > 46 ? _brown : _brownSoft,
                        weight: FontWeight.w900)),
                ),
              ),
              if (isBest && mood > 0) Positioned(
                right: 6, top: 0, bottom: 0,
                child: Icon(Icons.star_rounded, size: 14, color: _brown),
              ),
            ]);
          }),
        )),
        const SizedBox(width: 8),
        // Trailing avg sleep hours for context
        SizedBox(width: 46,
          child: Text(sleep > 0 ? '${sleep.toStringAsFixed(1)}h' : '—',
            textAlign: TextAlign.right,
            style: _nunito(size: 10.5, color: _brownSoft,
                weight: FontWeight.w800))),
      ]),
    );
  }
}


class _SleepMoodScatter extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final AvatarConfig? avatarConfig;
  const _SleepMoodScatter({required this.points, this.avatarConfig});

  // Convert a numeric mood score (1-5) to one of the avatar expressions.
  String _moodForScore(double s) {
    if (s >= 4.5) return 'excited';
    if (s >= 3.5) return 'happy';
    if (s >= 2.5) return 'calm';
    if (s >= 1.5) return 'tired';
    return 'sad';
  }

  Color _moodTint(double s) {
    if (s >= 4) return _mSage;
    if (s >= 3) return _mMint;
    if (s >= 2) return _mButter;
    return _mBlush;
  }

  @override
  Widget build(BuildContext context) {
    const minX = 3.0;  // hours of sleep (x axis)
    const maxX = 11.0;
    const chartH = 220.0;
    const leftGutter = 44.0;   // wider so stickers near low-sleep edge
                               // never bleed into the y-axis labels
    const rightGutter = 24.0;  // breathing room at the high-sleep edge
    const topGutter = 18.0;
    const bottomGutter = 30.0; // x-axis labels
    const stickerSize = 38.0;    // slightly smaller overall footprint
    const stickerZoom = 0.55;    // < 1.0 so the head sits inside the box
                                 // with padding; zoom=1.0 was cropping
                                 // chins/foreheads on the larger avatars

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _pocketCard(radius: 16),
      child: SizedBox(
        height: chartH,
        child: LayoutBuilder(builder: (ctx, bc) {
          final w = bc.maxWidth;
          final plotW = w - leftGutter - rightGutter;
          final plotH = chartH - topGutter - bottomGutter;

          double xFor(double sleep) {
            final clamped = sleep.clamp(minX, maxX);
            return leftGutter + (clamped - minX) / (maxX - minX) * plotW;
          }
          double yFor(double mood) {
            // mood is 1..5 → invert so high mood sits at top
            final clamped = mood.clamp(1.0, 5.0);
            return topGutter + (1 - (clamped - 1) / 4) * plotH;
          }

          // Keeps the sticker fully inside the plot regardless of where
          // the data point lands. Without this, an edge-case x=3h sticker
          // drew partly behind the y-axis labels (the "cut" the user saw).
          double clampLeft(double left) =>
              left.clamp(2.0, w - stickerSize - 2.0);
          double clampTop(double top) =>
              top.clamp(2.0, chartH - stickerSize - 2.0);

          // De-duplicate / cluster points that share the same (sleep, mood)
          // so identical days don't render a sticker on top of a sticker.
          final seen = <String, int>{};
          final stickers = <Widget>[];
          for (final p in points) {
            final s = _asD(p['sleep']) ?? 0;
            final m = _asD(p['mood']) ?? 0;
            final key = '${(s * 2).round()}_${m.round()}';
            final count = (seen[key] ?? 0) + 1;
            seen[key] = count;

            final cx = xFor(s);
            final cy = yFor(m);
            final hasConfig = avatarConfig != null;
            final mood = _moodForScore(m);
            // NO background circle — the sticker itself is the marker.
            // zoom:1.0 = no internal scaling, so the avatar's natural head
            // crop lands cleanly inside the SizedBox without clipping the
            // chin or forehead.
            final left = clampLeft(cx - stickerSize / 2 + (count - 1) * 3.0);
            final top  = clampTop (cy - stickerSize / 2 - (count - 1) * 2.0);
            stickers.add(Positioned(
              left: left, top: top,
              child: SizedBox(
                width: stickerSize, height: stickerSize,
                child: hasConfig
                  ? MoodSticker(
                      config: avatarConfig!, mood: mood,
                      size: stickerSize, zoom: stickerZoom)
                  : Container(
                      decoration: BoxDecoration(
                        color: _moodTint(m).withOpacity(0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: _outline.withOpacity(0.4),
                            width: 1.4),
                      ),
                      child: Center(child: Icon(_moodIcon(m),
                          size: 22, color: _brown)),
                    ),
              ),
            ));
          }

          // Y-axis labels (mood 1..5, bottom to top)
          final yLabels = <Widget>[
            for (int i = 1; i <= 5; i++) Positioned(
              left: 0, top: yFor(i.toDouble()) - 6,
              child: SizedBox(width: leftGutter - 6,
                child: Text('$i', textAlign: TextAlign.right,
                  style: _nunito(size: 10, color: _brownSoft,
                      weight: FontWeight.w700))),
            ),
          ];
          // X-axis labels (hours)
          final xLabels = <Widget>[
            for (final h in [4, 6, 8, 10]) Positioned(
              left: xFor(h.toDouble()) - 12,
              top: chartH - bottomGutter + 6,
              child: SizedBox(width: 24,
                child: Text('${h}h', textAlign: TextAlign.center,
                  style: _nunito(size: 10, color: _brownSoft,
                      weight: FontWeight.w700))),
            ),
          ];

          // Grid lines
          final grid = <Widget>[
            for (int i = 1; i <= 5; i++) Positioned(
              left: leftGutter, top: yFor(i.toDouble()),
              child: Container(width: plotW, height: 1,
                color: _outline.withOpacity(0.06))),
            for (final h in [4, 6, 8, 10]) Positioned(
              left: xFor(h.toDouble()), top: topGutter,
              child: Container(width: 1, height: plotH,
                color: _outline.withOpacity(0.06))),
          ];

          // Axis title labels (Mood / Hours slept)
          final axisTitles = <Widget>[
            Positioned(
              left: leftGutter, top: 0,
              child: Text('mood',
                style: _nunito(size: 9, color: _brownSoft,
                    weight: FontWeight.w800, letter: 0.4)),
            ),
            Positioned(
              right: 4, bottom: 0,
              child: Text('hours slept',
                style: _nunito(size: 9, color: _brownSoft,
                    weight: FontWeight.w800, letter: 0.4)),
            ),
          ];

          return Stack(clipBehavior: Clip.hardEdge, children: [
            ...grid, ...yLabels, ...xLabels, ...stickers, ...axisTitles,
          ]);
        }),
      ),
    );
  }

  IconData _moodIcon(double s) {
    if (s >= 4) return Icons.sentiment_very_satisfied_rounded;
    if (s >= 3) return Icons.sentiment_satisfied_rounded;
    if (s >= 2) return Icons.sentiment_neutral_rounded;
    return Icons.sentiment_dissatisfied_rounded;
  }
}


//  CROSS-DOMAIN WIDGETS  (used by the Rhythms tab)

/// "What fuels your best days" — splits the last 30 days into top-tier
/// mood days vs low-tier mood days, then compares avg sleep / study /
/// habits / focus side by side. This is the single most actionable view
/// on the screen: it answers "what actually makes a good day good".
///
/// Cross-domain: takes the user's mood (outcome) and correlates it
/// against sleep, study, habits, focus (inputs) simultaneously.
class _BestDaysFormula extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _BestDaysFormula({required this.records});

  double _mean(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  @override
  Widget build(BuildContext context) {
    // Only compare days where we actually know the mood.
    final rated = records
        .where((r) => (_asD(r['mood_score']) ?? 0) > 0)
        .toList()
      ..sort((a, b) => (_asD(b['mood_score']) ?? 0)
          .compareTo(_asD(a['mood_score']) ?? 0));

    if (rated.length < 4) {
      return _InlineEmpty(
        'Log moods on a few more days to unlock this comparison.',
        _mSage);
    }

    // Top third vs bottom third — keeps the buckets balanced but biased
    // toward the extremes so the signal stands out.
    final bucket = math.max(2, (rated.length / 3).floor());
    final hi = rated.take(bucket).toList();
    final lo = rated.skip(rated.length - bucket).toList();

    double avgOf(List<Map<String, dynamic>> days, String key,
        {bool nonZeroOnly = false}) {
      final xs = <double>[];
      for (final d in days) {
        final v = _asD(d[key]);
        if (v == null) continue;
        if (nonZeroOnly && v == 0) continue;
        xs.add(v);
      }
      return _mean(xs);
    }

    // Per-metric averages (high-mood vs low-mood bucket)
    final hiSleep = avgOf(hi, 'sleep_hours');
    final loSleep = avgOf(lo, 'sleep_hours');
    final hiStudy = avgOf(hi, 'study_minutes');
    final loStudy = avgOf(lo, 'study_minutes');
    final hiHabit = avgOf(hi, 'habits_pct');
    final loHabit = avgOf(lo, 'habits_pct');
    final hiFocus = avgOf(hi, 'focus_avg', nonZeroOnly: true);
    final loFocus = avgOf(lo, 'focus_avg', nonZeroOnly: true);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _pocketCard(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row: label + two bucket chips
        Row(children: [
          Expanded(child: Text('metric',
            style: _nunito(size: 10, color: _brownSoft,
                weight: FontWeight.w800, letter: 0.3))),
          const SizedBox(width: 8),
          _BucketChip(
            label: 'top ${hi.length}',
            tint: _mSage,
            mood: _meanMood(hi)),
          const SizedBox(width: 8),
          _BucketChip(
            label: 'low ${lo.length}',
            tint: _mBlush,
            mood: _meanMood(lo)),
        ]),
        const SizedBox(height: 12),
        _BestDaysRow(label: 'Sleep',    hi: hiSleep, lo: loSleep,
            unit: 'h',  scale: 10),
        const SizedBox(height: 10),
        _BestDaysRow(label: 'Study',    hi: hiStudy, lo: loStudy,
            unit: 'm',  scale: math.max(60.0, math.max(hiStudy, loStudy))),
        const SizedBox(height: 10),
        _BestDaysRow(label: 'Habits',   hi: hiHabit, lo: loHabit,
            unit: '%',  scale: 100),
        const SizedBox(height: 10),
        _BestDaysRow(label: 'Focus',    hi: hiFocus, lo: loFocus,
            unit: '%',  scale: 100),
      ]),
    );
  }

  double _meanMood(List<Map<String, dynamic>> days) {
    final xs = <double>[];
    for (final d in days) {
      final v = _asD(d['mood_score']);
      if (v != null && v > 0) xs.add(v);
    }
    return _mean(xs);
  }
}

class _BucketChip extends StatelessWidget {
  final String label;
  final Color tint;
  final double mood;
  const _BucketChip({required this.label, required this.tint,
      required this.mood});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.8),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(label,
          style: _nunito(size: 9, weight: FontWeight.w900, color: _brown,
              letter: 0.3)),
        Text('mood ${mood.toStringAsFixed(1)}',
          style: _nunito(size: 9, weight: FontWeight.w600, color: _brown)),
      ]),
    );
  }
}

class _BestDaysRow extends StatelessWidget {
  final String label;
  final double hi;
  final double lo;
  final String unit;
  final double scale;
  const _BestDaysRow({required this.label, required this.hi,
      required this.lo, required this.unit, required this.scale});

  String _fmt(double v) {
    if (unit == 'h') return '${v.toStringAsFixed(1)}h';
    if (unit == 'm') return '${v.round()}m';
    return '${v.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final hiPct = (scale <= 0 ? 0.0 : (hi / scale).clamp(0.0, 1.0)).toDouble();
    final loPct = (scale <= 0 ? 0.0 : (lo / scale).clamp(0.0, 1.0)).toDouble();
    // Delta pill — which bucket is higher, by how much.
    final diff = hi - lo;
    final isPos = diff > 0;
    return Row(children: [
      SizedBox(width: 60,
        child: Text(label,
          style: _nunito(size: 12, weight: FontWeight.w800, color: _brown))),
      const SizedBox(width: 8),
      Expanded(child: Column(children: [
        _BestDaysBar(pct: hiPct, tint: _mSage, value: _fmt(hi)),
        const SizedBox(height: 5),
        _BestDaysBar(pct: loPct, tint: _mBlush, value: _fmt(lo)),
      ])),
      const SizedBox(width: 8),
      Container(
        width: 56,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: (isPos ? _mSage : _mBlush).withOpacity(0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _outline.withOpacity(0.25), width: 1),
        ),
        child: Text(
          '${isPos ? '+' : ''}${_fmt(diff.abs()).replaceAll('+','')}',
          textAlign: TextAlign.center,
          style: _nunito(size: 10, weight: FontWeight.w900, color: _brown)),
      ),
    ]);
  }
}

class _BestDaysBar extends StatelessWidget {
  final double pct;
  final Color tint;
  final String value;
  const _BestDaysBar({required this.pct, required this.tint,
      required this.value});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, bc) {
      final w = bc.maxWidth;
      return SizedBox(
        height: 14,
        child: Stack(children: [
          Container(width: w, height: 14,
            decoration: BoxDecoration(
              color: _outline.withOpacity(0.08),
              borderRadius: BorderRadius.circular(7))),
          Container(
            width: math.max(14.0, w * pct),
            height: 14,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1),
            ),
          ),
          Positioned(
            right: 6, top: 0, bottom: 0,
            child: Center(child: Text(value,
              style: _nunito(size: 9, weight: FontWeight.w900, color: _brown))),
          ),
        ]),
      );
    });
  }
}


/// "Sleep → next-day mood" — dual-axis lag view. Last 14 days (rolling).
/// Each column pairs night[i-1] sleep (top bar) with day[i] mood (bottom
/// sticker-dot). Makes the causal link visible: did a bad night of sleep
/// turn into a bad-mood day?
class _SleepLagMoodChart extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _SleepLagMoodChart({required this.records});

  @override
  Widget build(BuildContext context) {
    // Pair each day i with night i-1 (yesterday's sleep ➜ today's mood).
    // We walk the tail of the 30-day window so we always get the most
    // recent ~14 usable pairs.
    final pairs = <Map<String, dynamic>>[];
    for (int i = 1; i < records.length; i++) {
      final nightSleep = _asD(records[i - 1]['sleep_hours']);
      final todayMood  = _asD(records[i]['mood_score']) ?? 0;
      pairs.add({
        'dow': records[i]['dow'],
        'sleep': nightSleep,
        'mood': todayMood > 0 ? todayMood : null,
      });
    }
    final tail = pairs.length > 14
        ? pairs.sublist(pairs.length - 14)
        : pairs;

    // Need at least a couple of complete pairs to be worth rendering.
    final complete = tail.where(
      (p) => p['sleep'] != null && p['mood'] != null).length;
    if (complete < 2) {
      return _InlineEmpty(
        'Log sleep for a couple of nights and mood the next morning to unlock this.',
        _mLav);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _pocketCard(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // legend
        Row(children: [
          _LegendSwatch(color: _mLav, label: "last night's sleep"),
          const SizedBox(width: 14),
          _LegendSwatch(color: _mSage, label: "today's mood",
              squareShape: false),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            for (final p in tail) Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.6),
                child: _SleepMoodLagColumn(
                  dow: (p['dow'] as String?) ?? '',
                  sleep: _asD(p['sleep']),
                  mood: _asD(p['mood']),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SleepMoodLagColumn extends StatelessWidget {
  final String dow;
  final double? sleep;   // hours (0-12 scale)
  final double? mood;    // 1-5
  const _SleepMoodLagColumn({required this.dow, required this.sleep,
      required this.mood});

  Color _moodColor(double m) {
    if (m >= 4) return _mSage;
    if (m >= 3) return _mMint;
    if (m >= 2) return _mButter;
    return _mBlush;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, bc) {
      // top 80 px = sleep bar zone (0-10h), bottom 40 px = mood dot zone
      const barZone = 80.0;
      const gap = 4.0;
      const dotZone = 30.0;
      const labelZone = 14.0;

      double sleepH = 0;
      if (sleep != null) {
        sleepH = (sleep!.clamp(0.0, 10.0) / 10.0 * barZone);
      }
      return SizedBox(
        height: barZone + gap + dotZone + labelZone,
        child: Column(children: [
          // SLEEP BAR ZONE
          SizedBox(height: barZone, child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 14,
              height: math.max(2.0, sleepH),
              decoration: BoxDecoration(
                color: sleep == null ? _outline.withOpacity(0.12) : _mLav,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                border: Border.all(
                    color: _outline.withOpacity(0.35), width: 1),
              ),
            ),
          )),
          const SizedBox(height: gap),
          // MOOD DOT ZONE — vertical position = mood level
          SizedBox(
            height: dotZone,
            child: mood == null
                ? const SizedBox.shrink()
                : Align(
                    // mood 5 → top of dot zone, mood 1 → bottom
                    alignment: Alignment(
                        0, 1 - ((mood!.clamp(1.0, 5.0) - 1) / 4) * 2),
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: _moodColor(mood!),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _outline.withOpacity(0.5), width: 1),
                      ),
                    ),
                  ),
          ),
          SizedBox(height: labelZone, child: Center(
            child: Text(
              dow.isNotEmpty ? dow.substring(0, 1) : '',
              style: _nunito(size: 9, color: _brownSoft,
                  weight: FontWeight.w800)),
          )),
        ]),
      );
    });
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool squareShape;
  const _LegendSwatch({required this.color, required this.label,
      this.squareShape = true});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: squareShape ? 12 : 10,
        height: squareShape ? 12 : 10,
        decoration: BoxDecoration(
          color: color,
          shape: squareShape ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: squareShape ? BorderRadius.circular(3) : null,
          border: Border.all(color: _outline.withOpacity(0.35), width: 1),
        ),
      ),
      const SizedBox(width: 6),
      Text(label,
        style: _nunito(size: 10, color: _brown, weight: FontWeight.w700)),
    ]);
  }
}


/// Bedtime consistency — renders each night's bedtime as a dot on a 19:00-
/// 03:00 horizontal timeline, overlaid with the median bedtime and the
/// ±spread band. Reads rhythms.bedtime_median + bedtime_spread_hours,
/// fields that were already in the /insights payload but unused.
class _BedtimeConsistencyCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final double? spread;   // std-dev in hours
  final double? median;   // median bedtime hour (decimal, 0-24)
  const _BedtimeConsistencyCard({required this.records,
      required this.spread, required this.median});

  // x-axis covers 19:00 (7pm) through 27:00 (3am next day).
  static const double _minH = 19.0;
  static const double _maxH = 27.0;

  String _fmtHour(double h) {
    final hour = h % 24;
    final hh = hour.floor();
    final mm = ((hour - hh) * 60).round();
    final suffix = hh >= 12 ? 'pm' : 'am';
    final disp = hh == 0 ? 12 : (hh > 12 ? hh - 12 : hh);
    return '$disp:${mm.toString().padLeft(2, '0')}$suffix';
  }

  double _norm(double hour) {
    // map 19-27 to 0-1, handling past-midnight times (0-3 become 24-27).
    var h = hour;
    if (h < _minH - 0.5) h += 24;   // e.g. 00:30 → 24:30
    return ((h - _minH) / (_maxH - _minH)).clamp(0.0, 1.0);
  }

  String _verdict(double s) {
    if (s < 0.5) return 'rock steady';
    if (s < 1.0) return 'pretty steady';
    if (s < 1.8) return 'a little variable';
    return 'quite variable';
  }

  @override
  Widget build(BuildContext context) {
    final bedtimes = <double>[];
    for (final r in records) {
      final h = _asD(r['bedtime_hour']);
      if (h != null) bedtimes.add(h);
    }
    if (median == null || bedtimes.length < 3) {
      return _InlineEmpty(
        'Log your bedtime for 3+ nights to unlock your consistency pattern.',
        _mButter);
    }

    final med = median!;
    final sp  = spread ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _pocketCard(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // headline stats
        Row(children: [
          _Pill(
            icon: Icons.bedtime_rounded,
            label: 'usually ${_fmtHour(med)}',
            color: _mButter,
          ),
          const SizedBox(width: 8),
          _Pill(
            icon: Icons.swap_horiz_rounded,
            label: '±${sp.toStringAsFixed(1)}h',
            color: _mLav,
          ),
          const Spacer(),
          Text(_verdict(sp),
            style: _gaegu(size: 12, color: _brown, weight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        // timeline
        LayoutBuilder(builder: (ctx, bc) {
          final w = bc.maxWidth;
          const h = 52.0;
          final medX = _norm(med) * w;
          final bandL = _norm(med - sp) * w;
          final bandR = _norm(med + sp) * w;
          return SizedBox(
            height: h,
            child: Stack(children: [
              // baseline line
              Positioned(
                left: 0, right: 0, top: h / 2 - 1,
                child: Container(height: 2,
                  color: _outline.withOpacity(0.18)),
              ),
              // spread band
              if (sp > 0) Positioned(
                left: bandL, top: h / 2 - 9,
                child: Container(
                  width: math.max(2.0, bandR - bandL), height: 18,
                  decoration: BoxDecoration(
                    color: _mLav.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: _outline.withOpacity(0.25), width: 1),
                  ),
                ),
              ),
              // median marker
              Positioned(
                left: medX - 1.5, top: h / 2 - 14,
                child: Container(width: 3, height: 28, color: _brown),
              ),
              // per-night dots
              for (final b in bedtimes) Positioned(
                left: _norm(b) * w - 4, top: h / 2 - 4,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: _mButter,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _outline.withOpacity(0.5), width: 1),
                  ),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 6),
        // tick labels
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final t in ['7pm', '9pm', '11pm', '1am', '3am']) Text(t,
            style: _nunito(size: 9, color: _brownSoft,
                weight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}


/// "Habits → mood lift" — the simplest, highest-signal correlation on the
/// screen. Groups the last 30 days into full-habit days (80%+ complete)
/// and skip days (<50% complete), shows the avg mood on each. The delta
/// tells the user in one number whether habits actually move their mood.
class _HabitMoodLiftCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _HabitMoodLiftCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final full = <double>[];
    final skip = <double>[];
    int fullDays = 0, skipDays = 0;
    for (final r in records) {
      final mood = _asD(r['mood_score']) ?? 0;
      final pct  = _asD(r['habits_pct']);
      if (mood <= 0 || pct == null) continue;
      if (pct >= 80) { full.add(mood); fullDays++; }
      else if (pct < 50) { skip.add(mood); skipDays++; }
    }

    double mean(List<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    if (fullDays < 2 || skipDays < 2) {
      return _InlineEmpty(
        'Need a few full-habit AND a few skip days with moods before the lift shows up.',
        _mBlush);
    }

    final full_ = mean(full);
    final skip_ = mean(skip);
    final delta = full_ - skip_;
    final isPositive = delta >= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _pocketCard(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: _HabitMoodTile(
              label: 'full-habit days',
              sub: '$fullDays days · 80%+ complete',
              mood: full_, tint: _mSage,
              icon: Icons.check_circle_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HabitMoodTile(
              label: 'skip days',
              sub: '$skipDays days · under 50%',
              mood: skip_, tint: _mBlush,
              icon: Icons.error_outline_rounded),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (isPositive ? _mSage : _mBlush).withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline.withOpacity(0.25), width: 1.2),
          ),
          child: Row(children: [
            Icon(
              isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 18, color: _brown),
            const SizedBox(width: 8),
            Expanded(child: Text(
              isPositive
                ? 'Your mood is ${delta.toStringAsFixed(1)} pts higher on full-habit days.'
                : 'Your mood is actually higher on skip days by ${delta.abs().toStringAsFixed(1)} pts — worth a closer look.',
              style: _gaegu(size: 13, weight: FontWeight.w800, color: _brown))),
          ]),
        ),
      ]),
    );
  }
}

class _HabitMoodTile extends StatelessWidget {
  final String label, sub;
  final double mood;
  final Color tint;
  final IconData icon;
  const _HabitMoodTile({required this.label, required this.sub,
      required this.mood, required this.tint, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: _brown),
          const SizedBox(width: 6),
          Expanded(child: Text(label,
            style: _nunito(size: 11, weight: FontWeight.w900, color: _brown))),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(mood.toStringAsFixed(1),
            style: const TextStyle(
                fontFamily: _bitroad, fontSize: 28, color: _brown, height: 1)),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('/ 5',
              style: _nunito(size: 11, color: _brownSoft,
                  weight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 2),
        Text(sub,
          style: _nunito(size: 10, color: _brownSoft,
              weight: FontWeight.w600)),
      ]),
    );
  }
}


//  TAB 4: PLAN
class _PlanTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PlanTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final recs = (data['recommendations'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final high = recs.where((r) => r['priority'] == 'high').toList();
    final med = recs.where((r) => r['priority'] == 'medium').toList();
    final low = recs.where((r) => r['priority'] == 'low').toList();
    final condCtx = (data['condition_context'] as Map?)
        ?.cast<String, dynamic>() ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (condCtx['conditions'] is List &&
            (condCtx['conditions'] as List).isNotEmpty) ...[
          _ConditionBanner(ctx: condCtx),
          const SizedBox(height: 14),
        ],
        if (recs.isEmpty)
          _InlineEmpty(
            'No strong recommendations yet — your system looks balanced.',
            _mMint),
        if (high.isNotEmpty) ...[
          _SectionHeader('Do today', icon: Icons.priority_high_rounded,
              tint: _mBlush, subtitle: 'highest-leverage moves',
              count: high.length),
          const SizedBox(height: 10),
          for (final r in high) _RecCard(item: r, priority: 'high'),
          const SizedBox(height: 16),
        ],
        if (med.isNotEmpty) ...[
          _SectionHeader('Try this week', icon: Icons.flag_rounded,
              tint: _mButter, subtitle: 'nice nudges to stack up',
              count: med.length),
          const SizedBox(height: 10),
          for (final r in med) _RecCard(item: r, priority: 'medium'),
          const SizedBox(height: 16),
        ],
        if (low.isNotEmpty) ...[
          _SectionHeader('Keep it going', icon: Icons.eco_rounded,
              tint: _mSage, subtitle: 'low-pressure reminders',
              count: low.length),
          const SizedBox(height: 10),
          for (final r in low) _RecCard(item: r, priority: 'low'),
        ],
      ]),
    );
  }
}


class _RecCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String priority;
  const _RecCard({required this.item, required this.priority});

  @override
  Widget build(BuildContext context) {
    final tint = priority == 'high'
      ? _mBlush
      : priority == 'medium' ? _mButter : _mSage;
    final deeplink = item['deeplink'] as String?;
    final title = item['title']?.toString() ?? '';
    final desc = item['description']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _softCard(fill: tint.withOpacity(0.22)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline.withOpacity(0.32), width: 1.2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(2, 2), blurRadius: 0)],
          ),
          child: Icon(_recIcon(item['icon']?.toString()),
              size: 18, color: _brown),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: const TextStyle(fontFamily: _bitroad, fontSize: 15, color: _brown)),
            const SizedBox(height: 4),
            Text(desc,
              style: _gaegu(size: 12, color: _brown, h: 1.4,
                  weight: FontWeight.w600)),
            if (deeplink != null && deeplink.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  try {
                    context.push(deeplink);
                  } catch (_) { /* no-op; path may not exist in current build */ }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: _brown),
                    const SizedBox(width: 5),
                    Text(_deeplinkLabel(deeplink),
                      style: const TextStyle(fontFamily: _bitroad,
                          fontSize: 12, color: _brown)),
                  ]),
                ),
              ),
            ],
          ],
        )),
      ]),
    );
  }

  String _deeplinkLabel(String path) {
    if (path.contains('/health/sleep')) return 'Open sleep';
    if (path.contains('/health/mood')) return 'Open mood';
    if (path.contains('/study/session')) return 'Start session';
    if (path.contains('/study')) return 'Open study';
    if (path.contains('/home')) return 'Home';
    return 'Open';
  }

  IconData _recIcon(String? icon) => switch (icon) {
    'bedtime' => Icons.bedtime_rounded,
    'mood' => Icons.mood_rounded,
    'school' => Icons.school_rounded,
    'check_circle' => Icons.check_circle_rounded,
    'insights' => Icons.insights_rounded,
    'local_fire_department' => Icons.local_fire_department_rounded,
    'emoji_events' => Icons.emoji_events_rounded,
    _ => Icons.lightbulb_rounded,
  };
}


//  SHARED CHROME

class _BackPill extends StatelessWidget {
  final VoidCallback onTap;
  const _BackPill({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
            offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: const Icon(Icons.arrow_back_rounded, size: 20, color: _brown),
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
          style: const TextStyle(fontFamily: _bitroad, fontSize: 18, color: _brown)),
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


//  PAW-PRINT BACKGROUND
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


//  CONDITION-AWARE BANNER
//  Sits at the top of the Plan tab when the user has declared any
//  medical_conditions in the setup wizard. Turns the raw list into
//  a friendly "Aware mode" card with condition chips + the
//  backend-supplied tips/watch-counts.
class _ConditionBanner extends StatelessWidget {
  final Map<String, dynamic> ctx;
  const _ConditionBanner({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final conditions = ((ctx['conditions'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    final tips = ((ctx['tips'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final flagged = (ctx['flagged_counts'] as Map?)
        ?.cast<String, dynamic>() ?? {};
    if (conditions.isEmpty && tips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _softCard(fill: _mLav.withOpacity(0.22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _mLav,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.32), width: 1.2),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                  offset: const Offset(2, 2), blurRadius: 0)],
            ),
            child: const Icon(Icons.auto_awesome, size: 16, color: _brown),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aware mode',
                style: _gaegu(size: 15, weight: FontWeight.w900, color: _brown)),
              Text('Your tips are tuned to your profile',
                style: _nunito(size: 11, color: _brownSoft,
                    weight: FontWeight.w700)),
            ],
          )),
        ]),
        const SizedBox(height: 10),
        if (conditions.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in conditions)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _outline.withOpacity(0.28),
                      width: 1),
                ),
                child: Text(c,
                  style: _nunito(size: 11, weight: FontWeight.w800,
                      color: _brown)),
              ),
          ]),
        if (tips.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final t in tips) _ConditionTipRow(
            condition: (t['condition'] ?? '').toString(),
            tip: (t['tip'] ?? '').toString(),
            watchHit: () {
              final v = flagged[(t['condition'] ?? '').toString()];
              if (v is num) return v.toInt();
              return 0;
            }(),
            watchTotal: ((t['watch'] as List?) ?? const []).length,
          ),
        ],
      ]),
    );
  }
}


class _ConditionTipRow extends StatelessWidget {
  final String condition;
  final String tip;
  final int watchHit;
  final int watchTotal;
  const _ConditionTipRow({
    required this.condition,
    required this.tip,
    required this.watchHit,
    required this.watchTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(condition,
            style: _gaegu(size: 13, weight: FontWeight.w900, color: _brown))),
          if (watchTotal > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (watchHit > 0 ? _mBlush : _mSage).withOpacity(0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _outline.withOpacity(0.28), width: 1),
              ),
              child: Text('$watchHit/$watchTotal logged',
                style: _nunito(size: 10, weight: FontWeight.w900,
                    color: _brown)),
            ),
        ]),
        const SizedBox(height: 4),
        Text(tip,
          style: _nunito(size: 12, color: _brown,
              weight: FontWeight.w600, h: 1.3)),
      ]),
    );
  }
}
