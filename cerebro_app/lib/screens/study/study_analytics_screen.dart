//  Knowledge Map · Gap Detection · Predictions · Smart Schedule

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/config/router.dart';

const _ombre1   = Color(0xFFFFFBF7);
const _ombre2   = Color(0xFFFFF8F3);
const _ombre3   = Color(0xFFFFF3EF);
const _ombre4   = Color(0xFFFEEDE9);
const _cardFill = Color(0xFFFFF8F4);
const _panelBg  = Color(0xFFFFFAF6);
const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);
const _skyHdr   = Color(0xFF9DD4F0);
const _skyDk    = Color(0xFF78B8D8);
const _pinkHdr  = Color(0xFFE8B0A8);
const _greenHdr = Color(0xFFA8D5A3);
const _greenDk  = Color(0xFF88B883);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleDk = Color(0xFFAA88C0);
const _coralHdr = Color(0xFFF0A898);
const _goldHdr  = Color(0xFFF0D878);
const _sageHdr  = Color(0xFF90C8A0);
const _sageDk   = Color(0xFF70A880);

Color _hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

Color _heatColor(double v) {
  final c = v.clamp(0.0, 100.0);
  if (c < 40)  return Color.lerp(const Color(0xFFE85050), const Color(0xFFF0A060), c / 40)!;
  if (c < 70)  return Color.lerp(const Color(0xFFF0A060), const Color(0xFFF0D878), (c - 40) / 30)!;
  return Color.lerp(const Color(0xFFF0D878), const Color(0xFF70B868), (c - 70) / 30)!;
}

BoxDecoration _pocketCard({Color? fill, Color? borderColor, double radius = 16}) {
  return BoxDecoration(
    color: fill ?? _cardFill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? _outline, width: 2.5),
    boxShadow: [BoxShadow(color: borderColor ?? _outline, offset: const Offset(0, 3), blurRadius: 0)],
  );
}

BoxDecoration _softCard({Color? fill, double radius = 14}) {
  return BoxDecoration(
    color: fill ?? _cardFill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
  );
}


//  MAIN SCREEN
class StudyAnalyticsScreen extends ConsumerStatefulWidget {
  const StudyAnalyticsScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<StudyAnalyticsScreen> createState() => _StudyAnalyticsScreenState();
}

class _StudyAnalyticsScreenState extends ConsumerState<StudyAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAnalytics() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get('/study/analytics');
      _data = resp.data is Map ? resp.data as Map<String, dynamic> : {};
    } catch (e) {
      _error = e.toString();
      debugPrint('Analytics fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_ombre1, _ombre2, _ombre3, _ombre4],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            _header(),
            const SizedBox(height: 6),
            // Quick stats bar (only when data loaded)
            if (!_loading && _error == null && _data != null)
              _quickStats(),
            const SizedBox(height: 4),
            _tabBar(),
            const SizedBox(height: 8),
            Expanded(child: _body()),
          ]),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline, width: 2.5),
              boxShadow: const [BoxShadow(color: _outline, offset: Offset(0, 3), blurRadius: 0)],
            ),
            child: const Icon(Icons.arrow_back_rounded, color: _outline, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Study Analytics', style: GoogleFonts.gaegu(
            fontSize: 28, fontWeight: FontWeight.w700, color: _brown)),
        ),
        GestureDetector(
          onTap: _loading ? null : _fetchAnalytics,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _sageHdr.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline, width: 2),
              boxShadow: const [BoxShadow(color: _outline, offset: Offset(0, 2), blurRadius: 0)],
            ),
            child: _loading
              ? const Padding(padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2, color: _brown))
              : const Icon(Icons.refresh_rounded, color: _brown, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _quickStats() {
    final pred = _data?['predictions'] as Map<String, dynamic>? ?? {};
    final readiness = (pred['exam_readiness'] as num?)?.toDouble() ?? 0;
    final gaps = (_data?['gaps'] as List?)?.length ?? 0;
    final sched = _data?['schedule'] as Map<String, dynamic>? ?? {};
    final cardsDue = sched['flashcards_due'] as int? ?? 0;
    final weeklyMins = (pred['weekly_minutes'] as List?)
        ?.map((e) => (e as num).toDouble()).toList() ?? [];
    final totalMins = weeklyMins.fold(0.0, (a, b) => a + b);

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _statChip(Icons.school_rounded, '${readiness.toInt()}%', 'Exam Ready',
            readiness >= 70 ? _greenHdr : readiness >= 50 ? _goldHdr : _coralHdr),
          _statChip(Icons.warning_amber_rounded, '$gaps', 'Gaps',
            gaps == 0 ? _greenHdr : gaps <= 3 ? _goldHdr : _coralHdr),
          _statChip(Icons.style_rounded, '$cardsDue', 'Cards Due',
            cardsDue == 0 ? _greenHdr : cardsDue <= 10 ? _goldHdr : _coralHdr),
          _statChip(Icons.timer_rounded, '${totalMins.toInt()}m', 'This Week', _skyHdr),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.3), width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700, color: _brown, height: 1)),
          Text(label, style: GoogleFonts.nunito(
            fontSize: 9, fontWeight: FontWeight.w600, color: _brownLt, height: 1)),
        ]),
      ]),
    );
  }

  Widget _tabBar() {
    final tabs = [
      (Icons.grid_view_rounded, 'Map', _sageHdr),
      (Icons.warning_amber_rounded, 'Gaps', _coralHdr),
      (Icons.trending_up_rounded, 'Predict', _skyHdr),
      (Icons.calendar_month_rounded, 'Schedule', _purpleHdr),
    ];

    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(4, (i) {
          return Expanded(child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
            child: AnimatedBuilder(
              animation: _tabCtrl,
              builder: (ctx, _) {
                final isActive = _tabCtrl.index == i;
                return GestureDetector(
                  onTap: () => _tabCtrl.animateTo(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isActive ? tabs[i].$3.withOpacity(0.5) : _cardFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? _outline : _outline.withOpacity(0.35),
                        width: isActive ? 2.5 : 1.5,
                      ),
                      boxShadow: [BoxShadow(
                        color: _outline,
                        offset: Offset(0, isActive ? 2 : 1),
                        blurRadius: 0,
                      )],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(tabs[i].$1, size: 14, color: isActive ? _brown : _brownLt),
                      const SizedBox(width: 4),
                      Text(tabs[i].$2, style: GoogleFonts.gaegu(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: _brown,
                      )),
                    ]),
                  ),
                );
              },
            ),
          ));
        }),
      ),
    );
  }

  Widget _body() {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState();
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _KnowledgeMapTab(data: _data!),
        _GapsTab(data: _data!),
        _PredictionsTab(data: _data!),
        _ScheduleTab(data: _data!),
      ],
    );
  }

  Widget _loadingState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 30),
        const CircularProgressIndicator(color: _sageHdr),
        const SizedBox(height: 14),
        Text('Analyzing your study data...', style: GoogleFonts.gaegu(
          fontSize: 20, fontWeight: FontWeight.w700, color: _brownLt)),
        const SizedBox(height: 4),
        Text('Crunching quizzes, flashcards & sessions', style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt)),
        const SizedBox(height: 24),
        ...List.generate(3, (_) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 60,
          decoration: BoxDecoration(
            color: _cardFill.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _outline.withOpacity(0.1)),
          ),
        )),
      ]),
    );
  }

  Widget _errorState() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: _coralHdr.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.cloud_off_rounded, size: 32, color: _coralHdr),
      ),
      const SizedBox(height: 12),
      Text('Could not load analytics', style: GoogleFonts.gaegu(
        fontSize: 20, fontWeight: FontWeight.w700, color: _brownLt)),
      const SizedBox(height: 4),
      Text('Check your connection and try again', style: GoogleFonts.nunito(
        fontSize: 12, color: _brownLt)),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _fetchAnalytics,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: _pocketCard(fill: _sageHdr.withOpacity(0.3)),
          child: Text('Retry', style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
        ),
      ),
    ]));
  }
}


//  TAB 1: KNOWLEDGE MAP
class _KnowledgeMapTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _KnowledgeMapTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final km = data['knowledge_map'] as Map<String, dynamic>? ?? {};
    final subjects = (km['subjects'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (subjects.isEmpty || subjects.every((s) => (s['topics'] as List? ?? []).isEmpty)) {
      return _emptyState(Icons.grid_view_rounded, _sageHdr,
        'Complete sessions & quizzes\nto build your knowledge map');
    }

    // Collect all unique topics
    final allTopics = <String>{};
    for (final s in subjects) {
      for (final t in (s['topics'] as List? ?? [])) {
        allTopics.add(t['name'] as String);
      }
    }
    final topicList = allTopics.toList()..sort();

    // Build proficiency matrix
    final matrix = <String, Map<String, double>>{};
    for (final t in topicList) { matrix[t] = {}; }
    for (final s in subjects) {
      for (final t in (s['topics'] as List? ?? [])) {
        matrix[t['name'] as String]?[s['name'] as String] =
            (t['proficiency'] as num?)?.toDouble() ?? 0;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Legend
        Row(children: [
          Text('Topic Proficiency', style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
          const Spacer(),
          _legendDot(const Color(0xFFE85050), 'Weak'),
          const SizedBox(width: 8),
          _legendDot(const Color(0xFFF0D878), 'Fair'),
          const SizedBox(width: 8),
          _legendDot(const Color(0xFF70B868), 'Strong'),
        ]),
        const SizedBox(height: 10),

        // Heatmap grid
        Container(
          decoration: _pocketCard(radius: 14),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Subject headers
              Container(
                color: _sageHdr.withOpacity(0.15),
                child: Row(children: [
                  SizedBox(width: 110, child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 6),
                    child: Text('Topic', style: GoogleFonts.gaegu(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _brown)))),
                  for (final s in subjects)
                    SizedBox(
                      width: 64,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                        child: Column(children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: _hexColor(s['color'] ?? '#9DD4F0'),
                              shape: BoxShape.circle,
                              border: Border.all(color: _outline.withOpacity(0.3), width: 1),
                            )),
                          const SizedBox(height: 3),
                          Text(s['name'] as String, style: GoogleFonts.nunito(
                            fontSize: 9, fontWeight: FontWeight.w700, color: _brown),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis, maxLines: 2),
                        ])),
                    ),
                ]),
              ),

              // Topic rows
              for (int i = 0; i < topicList.length; i++)
                Container(
                  color: i.isEven ? Colors.transparent : _outline.withOpacity(0.03),
                  child: _heatmapRow(topicList[i], subjects, matrix[topicList[i]] ?? {}),
                ),
              const SizedBox(height: 4),
            ]),
          ),
        ),

        // Subject summary cards
        const SizedBox(height: 16),
        Text('Subject Overview', style: GoogleFonts.gaegu(
          fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: subjects.map((s) {
          final prof = (s['proficiency'] as num?)?.toDouble() ?? 0;
          final color = _hexColor(s['color'] ?? '#9DD4F0');
          final topicCount = (s['topics'] as List? ?? []).length;
          return Container(
            width: 155, padding: const EdgeInsets.all(12),
            decoration: _softCard(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                    border: Border.all(color: _outline.withOpacity(0.3), width: 1))),
                const SizedBox(width: 6),
                Expanded(child: Text(s['name'] as String, style: GoogleFonts.gaegu(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _brown),
                  overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (prof / 100).clamp(0, 1), minHeight: 6,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(color))),
              const SizedBox(height: 4),
              Text('${prof.toInt()}% · $topicCount topics', style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt)),
            ]),
          );
        }).toList()),
      ]),
    );
  }

  Widget _heatmapRow(String topic, List<Map<String, dynamic>> subjects,
      Map<String, double> profMap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        SizedBox(width: 110, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
          child: Text(topic, style: GoogleFonts.nunito(
            fontSize: 10, color: _brown, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis))),
        for (final s in subjects)
          _heatCell(profMap[s['name'] as String]),
      ]),
    );
  }

  Widget _heatCell(double? proficiency) {
    if (proficiency == null) {
      return SizedBox(width: 64, height: 30, child: Center(
        child: Container(
          width: 28, height: 26,
          decoration: BoxDecoration(
            color: _outline.withOpacity(0.04),
            borderRadius: BorderRadius.circular(6)),
          child: Center(child: Text('-', style: GoogleFonts.nunito(
            fontSize: 10, color: _brownLt.withOpacity(0.3)))))));
    }
    return SizedBox(width: 64, height: 30, child: Center(
      child: Tooltip(
        message: '${proficiency.toInt()}% proficiency',
        child: Container(
          width: 28, height: 26,
          decoration: BoxDecoration(
            color: _heatColor(proficiency),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _outline.withOpacity(0.2), width: 1)),
          child: Center(child: Text('${proficiency.toInt()}',
            style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700,
              color: proficiency < 50 ? Colors.white : _brown)))))));
  }

  static Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 3),
      Text(label, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt)),
    ]);
  }
}


//  TAB 2: KNOWLEDGE GAPS
class _GapsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GapsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final gaps = (data['gaps'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final flagged = (data['flagged_subjects'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (gaps.isEmpty && flagged.isEmpty) {
      return _emptyState(Icons.check_circle_rounded, _greenHdr,
        'No knowledge gaps detected!\nGreat work — keep it up');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (gaps.isNotEmpty) ...[
          Row(children: [
            Text('Weak Topics', style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _coralHdr.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${gaps.length} found', style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
            ),
          ]),
          const SizedBox(height: 8),
          for (final g in gaps) _gapCard(g),
        ],

        if (flagged.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Flagged Subjects', style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(height: 8),
          for (final f in flagged) _flaggedCard(f),
        ],
      ]),
    );
  }

  Widget _gapCard(Map<String, dynamic> g) {
    final severity = g['severity'] as String? ?? 'medium';
    final proficiency = (g['proficiency'] as num?)?.toDouble() ?? 0;
    final quizAvg = (g['quiz_avg'] as num?)?.toDouble() ?? 0;
    final focusAvg = (g['focus_avg'] as num?)?.toDouble() ?? 0;
    final cardAcc = (g['card_accuracy'] as num?)?.toDouble() ?? 0;
    final rawDays = g['days_since_studied'];
    final days = rawDays is int ? rawDays : 0;
    final subColor = _hexColor(g['subject_color'] ?? '#9DD4F0');

    final sevColor = severity == 'critical' ? const Color(0xFFE85050)
        : severity == 'high' ? const Color(0xFFF0A060) : _goldHdr;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sevColor.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: sevColor.withOpacity(0.3), offset: const Offset(0, 2), blurRadius: 0)],
      ),
      child: Column(children: [
        // Colored header strip
        Container(
          height: 5,
          decoration: BoxDecoration(
            color: sevColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: sevColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(severity.toUpperCase(), style: GoogleFonts.nunito(
                  fontSize: 9, fontWeight: FontWeight.w800, color: sevColor))),
              const SizedBox(width: 6),
              Expanded(child: Text(g['topic'] ?? '', style: GoogleFonts.gaegu(
                fontSize: 16, fontWeight: FontWeight.w700, color: _brown))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: subColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(g['subject_name'] ?? '', style: GoogleFonts.nunito(
                  fontSize: 9, fontWeight: FontWeight.w600, color: _brown))),
            ]),
            const SizedBox(height: 10),
            // Mini progress bars
            Row(children: [
              _miniBar('Quiz', quizAvg, _skyHdr),
              const SizedBox(width: 8),
              _miniBar('Focus', focusAvg, _purpleHdr),
              const SizedBox(width: 8),
              _miniBar('Cards', cardAcc * 100, _greenHdr),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: days > 7 ? _coralHdr.withOpacity(0.12) : _outline.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(days > 365 ? 'Never' : '${days}d ago',
                  style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700,
                    color: days > 7 ? _coralHdr : _brownLt)),
              ),
            ]),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _sageHdr.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_rounded, size: 13, color: _sageDk),
                const SizedBox(width: 6),
                Expanded(child: Text(g['recommended_action'] ?? '', style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _brown, height: 1.3))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _miniBar(String label, double value, Color color) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label ${value.toInt()}%', style: GoogleFonts.nunito(
        fontSize: 9, fontWeight: FontWeight.w700, color: _brownLt)),
      const SizedBox(height: 3),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (value / 100).clamp(0, 1), minHeight: 5,
          backgroundColor: color.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation(color))),
    ]));
  }

  Widget _flaggedCard(Map<String, dynamic> f) {
    final current = (f['current_proficiency'] as num?)?.toDouble() ?? 0;
    final target = (f['target_proficiency'] as num?)?.toDouble() ?? 100;
    final gap = (f['gap_percentage'] as num?)?.toDouble() ?? 0;
    final color = _hexColor(f['color'] ?? '#9DD4F0');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _softCard(),
      child: Row(children: [
        Container(
          width: 6, height: 36,
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f['name'] ?? '', style: GoogleFonts.gaegu(
            fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(height: 2),
          Text('${current.toInt()}% / ${target.toInt()}% target · ${gap.toInt()}% gap',
            style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _coralHdr.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
          child: Text('-${gap.toInt()}%', style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w800, color: _coralHdr))),
      ]),
    );
  }
}


//  TAB 3: PREDICTIONS
class _PredictionsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PredictionsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final pred = data['predictions'] as Map<String, dynamic>? ?? {};
    final readiness = (pred['exam_readiness'] as num?)?.toDouble() ?? 0;
    final confidence = (pred['confidence'] as num?)?.toDouble() ?? 0;
    final subjPred = (pred['subject_predictions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final weeklyMins = (pred['weekly_minutes'] as List?)
        ?.map((e) => (e as num).toDouble()).toList() ?? List.filled(7, 0.0);
    final weeklyFocus = (pred['weekly_focus'] as List?)
        ?.map((e) => (e as num).toDouble()).toList() ?? List.filled(7, 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Exam readiness gauge + forecasts
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Gauge card
          Container(
            width: 130, padding: const EdgeInsets.all(14),
            decoration: _pocketCard(radius: 16),
            child: Column(children: [
              SizedBox(
                width: 80, height: 80,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 80, height: 80,
                    child: CircularProgressIndicator(
                      value: (readiness / 100).clamp(0, 1),
                      strokeWidth: 8,
                      backgroundColor: _outline.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation(
                        readiness >= 80 ? _greenHdr : readiness >= 60 ? _goldHdr : _coralHdr),
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${readiness.toInt()}', style: GoogleFonts.gaegu(
                      fontSize: 28, fontWeight: FontWeight.w700, color: _brown)),
                    Text('%', style: GoogleFonts.nunito(
                      fontSize: 10, fontWeight: FontWeight.w700, color: _brownLt, height: 0.5)),
                  ]),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Exam Ready', style: GoogleFonts.gaegu(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
              Text('${(confidence * 100).toInt()}% confidence',
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt)),
            ]),
          ),
          const SizedBox(width: 10),
          // Forecasts
          Expanded(child: Container(
            padding: const EdgeInsets.all(12),
            decoration: _pocketCard(radius: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('30/90-Day Forecast', style: GoogleFonts.gaegu(
                fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
              const SizedBox(height: 2),
              // Column headers
              Row(children: [
                const Expanded(child: SizedBox()),
                SizedBox(width: 32, child: Text('Now', textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.w700, color: _brownLt))),
                const SizedBox(width: 4),
                SizedBox(width: 32, child: Text('30d', textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.w700, color: _skyHdr))),
                const SizedBox(width: 4),
                SizedBox(width: 32, child: Text('90d', textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.w700, color: _purpleHdr))),
                const SizedBox(width: 18),
              ]),
              const SizedBox(height: 4),
              if (subjPred.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Add subjects to see predictions', style: GoogleFonts.nunito(
                    fontSize: 11, color: _brownLt.withOpacity(0.5))),
                )
              else
                for (final sp in subjPred) _forecastRow(sp),
            ]),
          )),
        ]),
        const SizedBox(height: 16),

        // Weekly study chart
        Text('Weekly Activity', style: GoogleFonts.gaegu(
          fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 8),
        Container(
          height: 180, padding: const EdgeInsets.fromLTRB(8, 14, 14, 8),
          decoration: _pocketCard(radius: 16),
          child: BarChart(BarChartData(
            maxY: weeklyMins.isEmpty ? 30 : (weeklyMins.reduce(math.max) * 1.3).clamp(30, 999),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: _cardFill,
                tooltipRoundedRadius: 8,
                tooltipBorder: BorderSide(color: _outline.withOpacity(0.3)),
                getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                  '${rod.toY.toInt()} min',
                  GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: _brown)))),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 32,
                getTitlesWidget: (v, _) => Text('${v.toInt()}m',
                  style: GoogleFonts.nunito(fontSize: 9, color: _brownLt)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(days[v.toInt().clamp(0, 6)],
                      style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700, color: _brownLt)),
                  );
                }))),
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: _outline.withOpacity(0.06), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(7, (i) => BarChartGroupData(
              x: i,
              barRods: [BarChartRodData(
                toY: weeklyMins[i],
                width: 18,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [_sageHdr.withOpacity(0.3), _sageHdr]),
              )],
            )),
          )),
        ),
        const SizedBox(height: 8),
        // Focus trend
        Container(
          padding: const EdgeInsets.all(10),
          decoration: _softCard(),
          child: Row(children: [
            Icon(Icons.psychology_rounded, size: 16, color: _purpleHdr),
            const SizedBox(width: 8),
            Text('Focus: ', style: GoogleFonts.gaegu(
              fontSize: 13, fontWeight: FontWeight.w700, color: _brown)),
            for (int i = 0; i < 7; i++) ...[
              Container(
                width: 28,
                padding: const EdgeInsets.symmetric(vertical: 3),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: weeklyFocus[i] > 0
                      ? _heatColor(weeklyFocus[i]).withOpacity(0.2)
                      : _outline.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(weeklyFocus[i] > 0 ? '${weeklyFocus[i].toInt()}' : '-',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700,
                    color: weeklyFocus[i] > 0 ? _brown : _brownLt.withOpacity(0.3)))),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _forecastRow(Map<String, dynamic> sp) {
    final color = _hexColor(sp['color'] ?? '#9DD4F0');
    final current = (sp['current'] as num?)?.toDouble() ?? 0;
    final p30 = (sp['predicted_30d'] as num?)?.toDouble() ?? 0;
    final p90 = (sp['predicted_90d'] as num?)?.toDouble() ?? 0;
    final trend = sp['trend'] as String? ?? 'steady';

    final trendIcon = trend == 'improving' ? Icons.trending_up_rounded
        : trend == 'declining' ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final trendColor = trend == 'improving' ? _greenDk
        : trend == 'declining' ? _coralHdr : _goldHdr;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Container(width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Expanded(child: Text(sp['name'] ?? '', style: GoogleFonts.nunito(
          fontSize: 10, fontWeight: FontWeight.w600, color: _brown),
          overflow: TextOverflow.ellipsis)),
        SizedBox(width: 32, child: Text('${current.toInt()}', textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brownLt))),
        const Icon(Icons.chevron_right_rounded, size: 10, color: _brownLt),
        SizedBox(width: 32, child: Text('${p30.toInt()}', textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _skyDk))),
        const Icon(Icons.chevron_right_rounded, size: 10, color: _brownLt),
        SizedBox(width: 32, child: Text('${p90.toInt()}', textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _purpleDk))),
        const SizedBox(width: 4),
        Icon(trendIcon, size: 14, color: trendColor),
      ]),
    );
  }
}


//  TAB 4: SMART SCHEDULE
class _ScheduleTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ScheduleTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final sched = data['schedule'] as Map<String, dynamic>? ?? {};
    final recs = (sched['recommendations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final cardsDue = sched['flashcards_due'] as int? ?? 0;
    final cardsOverdue = sched['flashcards_overdue'] as int? ?? 0;

    if (recs.isEmpty && cardsDue == 0) {
      return _emptyState(Icons.check_circle_rounded, _greenHdr,
        "You're on track!\nNo urgent study needed right now");
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Flashcard summary
        if (cardsDue > 0 || cardsOverdue > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _goldHdr.withOpacity(0.6), width: 2),
              boxShadow: [BoxShadow(color: _goldHdr.withOpacity(0.3), offset: const Offset(0, 2), blurRadius: 0)],
            ),
            child: Column(children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _goldHdr,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _goldHdr.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.style_rounded, size: 20, color: _brown),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flashcard Review', style: GoogleFonts.gaegu(
                        fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
                      Text(
                        '$cardsDue card${cardsDue == 1 ? '' : 's'} due'
                        '${cardsOverdue > 0 ? ' · $cardsOverdue overdue' : ''}',
                        style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
                    ],
                  )),
                  if (cardsOverdue > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _coralHdr.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text('$cardsOverdue late', style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w800, color: _coralHdr))),
                ]),
              ),
            ]),
          ),

        // Priority recommendations
        if (recs.isNotEmpty) ...[
          Row(children: [
            Text('Study Priorities', style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _purpleHdr.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8)),
              child: Text('${recs.length} items', style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
            ),
          ]),
          const SizedBox(height: 8),
          for (int i = 0; i < recs.length; i++)
            _priorityCard(recs[i], i + 1),
        ],
      ]),
    );
  }

  Widget _priorityCard(Map<String, dynamic> r, int rank) {
    final priority = r['priority'] as String? ?? 'medium';
    final subColor = _hexColor(r['subject_color'] ?? '#9DD4F0');
    final mins = r['recommended_mins'] as int? ?? 30;

    final prioColor = priority == 'critical' ? const Color(0xFFE85050)
        : priority == 'high' ? const Color(0xFFF0A060) : _goldHdr;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _softCard(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Rank strip
        Container(
          width: 32,
          decoration: BoxDecoration(
            color: prioColor.withOpacity(0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13), bottomLeft: Radius.circular(13)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(child: Text('#$rank', style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700, color: prioColor))),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: subColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(r['subject_name'] ?? '', style: GoogleFonts.nunito(
                  fontSize: 9, fontWeight: FontWeight.w700, color: _brown))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: prioColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(priority.toUpperCase(), style: GoogleFonts.nunito(
                  fontSize: 8, fontWeight: FontWeight.w800, color: prioColor))),
            ]),
            const SizedBox(height: 4),
            Text(r['topic'] ?? '', style: GoogleFonts.gaegu(
              fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 2),
            Text(r['reason'] ?? '', style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt)),
            const SizedBox(height: 8),
            Row(children: [
              _infoPill(Icons.timer_rounded, '${mins}m', _skyHdr),
              const SizedBox(width: 6),
              _infoPill(Icons.label_rounded, r['session_type'] ?? '', _purpleHdr),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _infoPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(text, style: GoogleFonts.nunito(
          fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
      ]),
    );
  }
}


//  SHARED EMPTY STATE
Widget _emptyState(IconData icon, Color color, String message) {
  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18)),
      child: Icon(icon, size: 32, color: color),
    ),
    const SizedBox(height: 12),
    Text(message, textAlign: TextAlign.center, style: GoogleFonts.gaegu(
      fontSize: 18, fontWeight: FontWeight.w700, color: _brownLt)),
  ]));
}
