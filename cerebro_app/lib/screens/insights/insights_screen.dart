/// Visualizes the Proactive Layer: wellness score, correlations,
/// patterns, and recommendations across Study, Health, and Daily Life.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

const _ombre1 = Color(0xFFFFFBF7);
const _ombre2 = Color(0xFFFFF8F3);
const _ombre3 = Color(0xFFFFF3EF);
const _ombre4 = Color(0xFFFEEDE9);
const _pawClr = Color(0xFFF8BCD0);

const _outline = Color(0xFF6E5848);
const _brown = Color(0xFF4E3828);
const _brownLt = Color(0xFF7A5840);

const _cardFill = Color(0xFFFFF8F4);
const _panelBg = Color(0xFFFFF6EE);

const _greenHdr = Color(0xFFA8D5A3);
const _greenLt = Color(0xFFC2E8BC);
const _greenDk = Color(0xFF88B883);
const _pinkHdr = Color(0xFFE8B0A8);
const _purpleHdr = Color(0xFFCDA8D8);
const _skyHdr = Color(0xFF9DD4F0);
const _coralHdr = Color(0xFFF0A898);
const _goldHdr = Color(0xFFF0D878);

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  late AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _loadInsights();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/insights/dashboard');
      if (res.statusCode == 200) {
        setState(() { _data = res.data; _loading = false; });
        _enterCtrl.forward();
      } else {
        setState(() { _error = 'Failed to load insights'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Could not connect to server'; _loading = false; });
    }
  }

  Widget _stag(double delay, Widget child) {
    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(
            ((_enterCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ombre1,
      body: Stack(
        children: [
          // Pawprint background
          ..._buildPawprints(),
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: _coralHdr))
                      : _error != null
                          ? _buildError()
                          : RefreshIndicator(
                              onRefresh: _loadInsights,
                              color: _coralHdr,
                              child: _buildContent(),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cardFill,
                shape: BoxShape.circle,
                border: Border.all(color: _outline, width: 2),
                boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
                    offset: const Offset(0, 2), blurRadius: 0)],
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _brown, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text('Insights', style: GoogleFonts.gaegu(
            fontSize: 28, fontWeight: FontWeight.w700, color: _brown)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _purpleHdr.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _purpleHdr, width: 1.5),
            ),
            child: Row(children: [
              const Icon(Icons.psychology_rounded, size: 16, color: _brown),
              const SizedBox(width: 4),
              Text('Proactive', style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: _brownLt),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong', style: GoogleFonts.nunito(
              fontSize: 16, fontWeight: FontWeight.w600, color: _brownLt)),
            const SizedBox(height: 8),
            Text(
              'Make sure the backend is running and you\'re logged in.\nTry logging out and back in if the issue persists.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13, color: _brownLt.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInsights,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _coralHdr,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final wellness = d['wellness_score'] as int? ?? 0;
    final breakdown = d['wellness_breakdown'] as Map<String, dynamic>? ?? {};
    final trend = d['wellness_trend'] as String? ?? 'steady';
    final correlations = (d['correlations'] as List?) ?? [];
    final patterns = (d['patterns'] as List?) ?? [];
    final recommendations = (d['recommendations'] as List?) ?? [];
    final weekly = (d['weekly_overview'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        _stag(0.0, _buildWellnessCard(wellness, breakdown, trend)),
        const SizedBox(height: 16),
        if (weekly.isNotEmpty) ...[
          _stag(0.08, _buildWeeklyOverview(weekly)),
          const SizedBox(height: 16),
        ],
        if (correlations.isNotEmpty) ...[
          _stag(0.16, _buildCorrelationsCard(correlations)),
          const SizedBox(height: 16),
        ],
        if (patterns.isNotEmpty) ...[
          _stag(0.24, _buildPatternsCard(patterns)),
          const SizedBox(height: 16),
        ],
        if (recommendations.isNotEmpty) ...[
          _stag(0.32, _buildRecommendationsCard(recommendations)),
          const SizedBox(height: 16),
        ],
        _stag(0.40, _buildDomainSummaries(d)),
      ],
    );
  }

  //  WELLNESS SCORE — big circular gauge

  Widget _buildWellnessCard(int score, Map<String, dynamic> breakdown, String trend) {
    final trendIcon = trend == 'improving'
        ? Icons.trending_up_rounded
        : trend == 'declining'
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final trendColor = trend == 'improving'
        ? _greenHdr
        : trend == 'declining'
            ? _coralHdr
            : _goldHdr;

    return _GameCard(
      headerGradient: const [Color(0xFFF0C0B8), _pinkHdr],
      headerIcon: Icons.favorite_rounded,
      headerTitle: 'Wellness Score',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: trendColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(trendIcon, size: 14, color: _brown),
          const SizedBox(width: 2),
          Text(trend, style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w700, color: _brown)),
        ]),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          width: 140,
          child: CustomPaint(
            painter: _WellnessRingPainter(score / 100, _scoreColor(score)),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$score', style: GoogleFonts.gaegu(
                  fontSize: 44, fontWeight: FontWeight.w700, color: _brown)),
                Text('/ 100', style: GoogleFonts.nunito(
                  fontSize: 12, color: _brownLt)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          _BreakdownChip('Sleep', breakdown['sleep'] ?? 0, 25, _purpleHdr),
          const SizedBox(width: 8),
          _BreakdownChip('Mood', breakdown['mood'] ?? 0, 25, _pinkHdr),
          const SizedBox(width: 8),
          _BreakdownChip('Study', breakdown['study'] ?? 0, 25, _skyHdr),
          const SizedBox(width: 8),
          _BreakdownChip('Habits', breakdown['habits'] ?? 0, 25, _greenHdr),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }

  //  WEEKLY OVERVIEW — 7-day bar chart

  Widget _buildWeeklyOverview(List weekly) {
    return _GameCard(
      headerGradient: const [Color(0xFFB8D8F0), _skyHdr],
      headerIcon: Icons.calendar_view_week_rounded,
      headerTitle: 'Weekly Overview',
      child: Column(children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weekly.map<Widget>((day) {
              final study = (day['study_minutes'] as num?)?.toInt() ?? 0;
              final maxMin = 180; // 3 hours cap for bar height
              final pct = (study / maxMin).clamp(0.0, 1.0);
              final mood = day['mood_score'] as int? ?? 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (study > 0)
                        Text('${study}m', style: GoogleFonts.nunito(
                          fontSize: 9, color: _brownLt, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Container(
                        height: math.max(4, pct * 80),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_skyHdr, _skyHdr.withOpacity(0.5)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _outline.withOpacity(0.3), width: 1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Mood dot
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _moodColor(mood),
                          border: Border.all(color: _outline.withOpacity(0.3), width: 1),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(day['day'] ?? '', style: GoogleFonts.nunito(
                        fontSize: 10, color: _brownLt, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _LegendDot(_skyHdr, 'Study'),
          const SizedBox(width: 12),
          _LegendDot(_greenHdr, 'Good mood'),
          const SizedBox(width: 12),
          _LegendDot(_coralHdr, 'Low mood'),
        ]),
        const SizedBox(height: 4),
      ]),
    );
  }

  //  CORRELATIONS — sleep↔focus, mood↔study, etc.

  Widget _buildCorrelationsCard(List correlations) {
    return _GameCard(
      headerGradient: const [Color(0xFFD8C0E8), _purpleHdr],
      headerIcon: Icons.compare_arrows_rounded,
      headerTitle: 'Correlations',
      child: Column(
        children: correlations.map<Widget>((c) {
          final corr = (c['correlation'] as num?)?.toDouble() ?? 0;
          final strength = c['strength'] as String? ?? 'weak';
          final label = c['label'] as String? ?? '';
          final insight = c['insight'] as String? ?? '';
          final isPositive = corr >= 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(_correlationIcon(c['type']), size: 18, color: _brown),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label, style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPositive ? _greenHdr : _coralHdr).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${isPositive ? "+" : ""}${corr.toStringAsFixed(2)} $strength',
                      style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: isPositive ? _greenDk : _coralHdr),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(insight, style: GoogleFonts.nunito(
                  fontSize: 12, color: _brownLt, height: 1.3)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  //  PATTERNS — detected behavioral patterns

  Widget _buildPatternsCard(List patterns) {
    return _GameCard(
      headerGradient: const [Color(0xFFC2E8BC), _greenHdr],
      headerIcon: Icons.auto_graph_rounded,
      headerTitle: 'Detected Patterns',
      child: Column(
        children: patterns.map<Widget>((p) {
          final severity = p['severity'] as String? ?? 'info';
          final accentColor = severity == 'positive'
              ? _greenHdr
              : severity == 'warning'
                  ? _goldHdr
                  : _skyHdr;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_patternIcon(p['icon']), size: 16, color: _brown),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['title'] ?? '', style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
                      const SizedBox(height: 2),
                      Text(p['description'] ?? '', style: GoogleFonts.nunito(
                        fontSize: 12, color: _brownLt, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  //  RECOMMENDATIONS

  Widget _buildRecommendationsCard(List recommendations) {
    return _GameCard(
      headerGradient: const [Color(0xFFF8D898), _goldHdr],
      headerIcon: Icons.lightbulb_rounded,
      headerTitle: 'Recommendations',
      child: Column(
        children: recommendations.map<Widget>((r) {
          final priority = r['priority'] as String? ?? 'low';
          final priorityColor = priority == 'high'
              ? _coralHdr
              : priority == 'medium'
                  ? _goldHdr
                  : _greenHdr;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: priorityColor.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_recIcon(r['icon']), size: 20, color: _brown),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['title'] ?? '', style: GoogleFonts.nunito(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _brown)),
                        const SizedBox(height: 2),
                        Text(r['description'] ?? '', style: GoogleFonts.nunito(
                          fontSize: 12, color: _brownLt, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  //  DOMAIN SUMMARIES

  Widget _buildDomainSummaries(Map<String, dynamic> d) {
    final study = d['study_summary'] as Map<String, dynamic>? ?? {};
    final sleep = d['sleep_summary'] as Map<String, dynamic>? ?? {};
    final mood = d['mood_summary'] as Map<String, dynamic>? ?? {};
    final habit = d['habit_summary'] as Map<String, dynamic>? ?? {};

    return Column(children: [
      Row(children: [
        Expanded(child: _MiniSummary(
          icon: Icons.menu_book_rounded,
          label: 'Study',
          value: '${study['total_minutes_week'] ?? 0} min',
          subValue: '${study['sessions_count'] ?? 0} sessions',
          color: _skyHdr,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MiniSummary(
          icon: Icons.bedtime_rounded,
          label: 'Sleep',
          value: '${sleep['avg_hours'] ?? '--'}h avg',
          subValue: '${sleep['nights_logged'] ?? 0} nights',
          color: _purpleHdr,
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MiniSummary(
          icon: Icons.mood_rounded,
          label: 'Mood',
          value: mood['dominant_mood'] ?? '--',
          subValue: 'avg ${mood['avg_score'] ?? '--'}/5',
          color: _pinkHdr,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MiniSummary(
          icon: Icons.check_circle_rounded,
          label: 'Habits',
          value: '${habit['avg_completion_pct'] ?? 0}%',
          subValue: 'avg completion',
          color: _greenHdr,
        )),
      ]),
    ]);
  }

  //  HELPERS

  Color _scoreColor(int score) {
    if (score >= 75) return _greenHdr;
    if (score >= 50) return _goldHdr;
    if (score >= 25) return _coralHdr;
    return Colors.red.shade400;
  }

  Color _moodColor(int score) {
    if (score >= 4) return _greenHdr;
    if (score >= 3) return _goldHdr;
    if (score >= 2) return _coralHdr;
    if (score >= 1) return Colors.red.shade300;
    return Colors.grey.shade300;
  }

  IconData _correlationIcon(String? type) {
    return switch (type) {
      'sleep_focus' => Icons.bedtime_rounded,
      'mood_study' => Icons.mood_rounded,
      'sleep_mood' => Icons.nights_stay_rounded,
      'habits_mood' => Icons.check_circle_rounded,
      _ => Icons.analytics_rounded,
    };
  }

  IconData _patternIcon(String? icon) {
    return switch (icon) {
      'trending_up' => Icons.trending_up_rounded,
      'hotel' => Icons.hotel_rounded,
      'warning' => Icons.warning_rounded,
      'dark_mode' => Icons.dark_mode_rounded,
      'sentiment_satisfied' => Icons.sentiment_satisfied_rounded,
      'swap_vert' => Icons.swap_vert_rounded,
      'local_fire_department' => Icons.local_fire_department_rounded,
      _ => Icons.auto_graph_rounded,
    };
  }

  IconData _recIcon(String? icon) {
    return switch (icon) {
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

  List<Widget> _buildPawprints() {
    final paws = <Widget>[];
    final rng = math.Random(42);
    for (int i = 0; i < 12; i++) {
      paws.add(Positioned(
        left: rng.nextDouble() * 400,
        top: rng.nextDouble() * 900,
        child: Transform.rotate(
          angle: rng.nextDouble() * math.pi * 2,
          child: Icon(Icons.pets_rounded, size: 16 + rng.nextDouble() * 12,
              color: _pawClr.withOpacity(0.15 + rng.nextDouble() * 0.1)),
        ),
      ));
    }
    return paws;
  }
}

//  REUSABLE WIDGETS

class _GameCard extends StatelessWidget {
  final List<Color> headerGradient;
  final IconData headerIcon;
  final String headerTitle;
  final Widget? trailing;
  final Widget child;

  const _GameCard({
    required this.headerGradient,
    required this.headerIcon,
    required this.headerTitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0EA), Color(0xFFFFF8F4)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: headerGradient,
              ),
            ),
            child: Row(children: [
              Icon(headerIcon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(headerTitle, style: GoogleFonts.gaegu(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
              const Spacer(),
              if (trailing != null) trailing!,
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: child,
          ),
        ]),
      ),
    );
  }
}

class _BreakdownChip extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  const _BreakdownChip(this.label, this.value, this.max, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(children: [
          Text('$value', style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
          Text('/$max', style: GoogleFonts.nunito(fontSize: 9, color: _brownLt)),
          Text(label, style: GoogleFonts.nunito(
            fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt)),
        ]),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.nunito(fontSize: 10, color: _brownLt)),
    ]);
  }
}

class _MiniSummary extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subValue;
  final Color color;

  const _MiniSummary({
    required this.icon,
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline, width: 2),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
            offset: const Offset(0, 3), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt)),
          ]),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.gaegu(
            fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
          Text(subValue, style: GoogleFonts.nunito(
            fontSize: 11, color: _brownLt)),
        ],
      ),
    );
  }
}

//  WELLNESS RING PAINTER

class _WellnessRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _WellnessRingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final strokeWidth = 12.0;

    // Background ring
    final bgPaint = Paint()
      ..color = _outline.withOpacity(0.1)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WellnessRingPainter old) =>
      old.progress != progress || old.color != color;
}
