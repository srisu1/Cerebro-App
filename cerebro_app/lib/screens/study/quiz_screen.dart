//  CEREBRO — Quiz Hub (3 Tabs)
//  My Quizzes · Study Materials · Schedule
//  Cozy Pocket Love aesthetic · Dynamic quiz generation

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/widgets/upload_notes_modal.dart';

const _ombre1   = Color(0xFFFFFBF7);
const _ombre2   = Color(0xFFFFF8F3);
const _ombre3   = Color(0xFFFFF3EF);
const _ombre4   = Color(0xFFFEEDE9);
const _cardFill = Color(0xFFFFF8F4);
const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);
const _coralHdr = Color(0xFFE8B8A8); // softer terracotta
const _coralLt  = Color(0xFFF2CFC2);
const _coralDk  = Color(0xFFC8997F);
const _greenHdr = Color(0xFFB5C4A0); // muted sage
const _greenLt  = Color(0xFFCCD8B8);
const _greenDk  = Color(0xFF98A869);
const _goldHdr  = Color(0xFFE8D4A0); // muted butter
const _goldLt   = Color(0xFFF4E6BE);
const _purpleHdr = Color(0xFFC9B8D9); // muted lav
const _purpleLt = Color(0xFFDCCEE6);
const _skyHdr   = Color(0xFFB6CBD6); // muted slate
const _skyLt    = Color(0xFFCCDCE4);
const _pawClr   = Color(0xFFEAD0CE); // muted blush

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});
  @override ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _subjects = [];
  Map<String, dynamic>? _schedule;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.get('/study/generated-quizzes?limit=100'),
        api.get('/study/materials?limit=100'),
        api.get('/study/subjects'),
        api.get('/study/quiz-schedule'),
      ]);
      _quizzes = _toList(results[0].data);
      _materials = _toList(results[1].data);
      _subjects = _toList(results[2].data);
      _schedule = results[3].data is Map ? Map<String, dynamic>.from(results[3].data) : null;
    } catch (e) {
      debugPrint('Quiz hub load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _toList(dynamic data) {
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  String _subjectName(String? id) {
    if (id == null) return 'General';
    return _subjects.where((s) => s['id'] == id).firstOrNull?['name'] ?? 'Unknown';
  }

  Color _subjectColor(String? id) {
    if (id == null) return _skyHdr;
    final hex = _subjects.where((s) => s['id'] == id).firstOrNull?['color'] as String?;
    if (hex != null && hex.length >= 7) {
      try { return Color(int.parse('FF${hex.substring(1)}', radix: 16)); } catch (_) {}
    }
    return _skyHdr;
  }

  @override
  Widget build(BuildContext context) {
    // Quiz Hub now follows the same constrained-width layout as My Subjects
    // and Subject Detail: scale gutters with viewport, but cap the column
    // so wide-desktop displays don't stretch quiz cards into a giant
    // letterbox. 0.94 / max 1500 keeps the value in lockstep with the
    // sibling screens for visual rhythm.
    final screenW = MediaQuery.of(context).size.width;
    final contentW = (screenW * 0.94).clamp(360.0, 1500.0);
    return Scaffold(
      backgroundColor: _ombre1,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _PawBgPainter())),
        Positioned.fill(child: IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_ombre1.withOpacity(0.0), _ombre2.withOpacity(0.3),
                     _ombre3.withOpacity(0.5), _ombre4.withOpacity(0.6)],
          )),
        ))),
        SafeArea(child: Center(child: SizedBox(
          width: contentW,
          child: Column(children: [
            _header(),
            const SizedBox(height: 6),
            _tabBar(),
            Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(color: _coralHdr))
              : TabBarView(controller: _tabCtrl, children: [
                  _QuizzesTab(
                    quizzes: _quizzes, subjects: _subjects,
                    subjectName: _subjectName, subjectColor: _subjectColor,
                    onRefresh: _loadAll, api: ref.read(apiServiceProvider),
                    onTakeQuiz: _navigateToQuiz,
                  ),
                  _MaterialsTab(
                    materials: _materials, subjects: _subjects,
                    subjectName: _subjectName, subjectColor: _subjectColor,
                    onRefresh: _loadAll, api: ref.read(apiServiceProvider),
                    onGenerateQuiz: _generateQuizFromMaterials,
                  ),
                  _ScheduleTab(
                    schedule: _schedule, subjects: _subjects,
                    api: ref.read(apiServiceProvider),
                    onRefresh: _loadAll,
                    onGenerateNow: _generateScheduledQuiz,
                  ),
                ])),
          ]),
        ))),
      ]),
    );
  }

  Widget _header() {
    final doneCount = _quizzes.where((q) => q['status'] == 'completed').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button — cream square with 2px outline + hard shadow (Focus Mode)
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quiz Hub',
                  style: TextStyle(fontFamily: 'Bitroad', fontSize: 26,
                      color: _brown, height: 1.15)),
                const SizedBox(height: 2),
                Text('pick a quiz, pace yourself, earn your stars~',
                  style: GoogleFonts.gaegu(fontSize: 15, fontWeight: FontWeight.w600,
                      color: _brownLt, height: 1.3)),
              ],
            ),
          ),
          // Trailing stats pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _greenHdr.withOpacity(0.45),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _outline.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                  offset: const Offset(3, 3), blurRadius: 0)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: _brown),
              const SizedBox(width: 4),
              Text('$doneCount done',
                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: _brown)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.14),
            offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600),
        labelColor: _brown,
        unselectedLabelColor: _brownLt,
        indicator: BoxDecoration(
          color: _greenHdr.withOpacity(0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        tabs: const [
          Tab(icon: Icon(Icons.list_alt_rounded, size: 16), text: 'Quizzes'),
          Tab(icon: Icon(Icons.description_rounded, size: 16), text: 'Materials'),
          Tab(icon: Icon(Icons.schedule_rounded, size: 16), text: 'Schedule'),
        ],
      ),
    );
  }

  void _navigateToQuiz(Map<String, dynamic> quiz) {
    context.push(Routes.takeQuiz, extra: quiz);
  }

  Future<void> _generateQuizFromMaterials(List<String> materialIds, {String? subjectId, int count = 10, List<String>? topicFilter}) async {
    try {
      final api = ref.read(apiServiceProvider);
      final body = {
        'material_ids': materialIds,
        'question_count': count,
        'question_types': ['mcq', 'true_false', 'fill_blank'],
        if (subjectId != null) 'subject_id': subjectId,
        if (topicFilter != null && topicFilter.isNotEmpty) 'topic_filter': topicFilter,
      };
      final resp = await api.post('/study/generate-quiz', data: body);
      if (resp.data != null) {
        await _loadAll();
        _tabCtrl.animateTo(0); // Switch to quizzes tab
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Quiz generated! Tap to start.',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            backgroundColor: _greenHdr,
          ));
        }
      }
    } catch (e) {
      debugPrint('Generate quiz error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to generate quiz: $e', style: GoogleFonts.nunito()),
          backgroundColor: _coralHdr,
        ));
      }
    }
  }

  Future<void> _generateScheduledQuiz() async {
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.post('/study/quiz-schedule/generate-now');
      if (resp.data != null) {
        await _loadAll();
        _tabCtrl.animateTo(0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Smart quiz generated from your weak topics!',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            backgroundColor: _greenHdr,
          ));
        }
      }
    } catch (e) {
      debugPrint('Scheduled quiz error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e', style: GoogleFonts.nunito()),
          backgroundColor: _coralHdr,
        ));
      }
    }
  }
}


//  TAB 1: MY QUIZZES
class _QuizzesTab extends StatelessWidget {
  final List<Map<String, dynamic>> quizzes;
  final List<Map<String, dynamic>> subjects;
  final String Function(String?) subjectName;
  final Color Function(String?) subjectColor;
  final VoidCallback onRefresh;
  final dynamic api;
  final void Function(Map<String, dynamic>) onTakeQuiz;

  const _QuizzesTab({
    required this.quizzes, required this.subjects,
    required this.subjectName, required this.subjectColor,
    required this.onRefresh, required this.api, required this.onTakeQuiz,
  });

  Color _gradeColor(double pct) {
    if (pct >= 90) return _greenHdr;
    if (pct >= 75) return _greenLt;
    if (pct >= 60) return _goldHdr;
    if (pct >= 40) return _coralLt;
    return _coralHdr;
  }

  String _gradeLabel(double pct) {
    if (pct >= 90) return 'A';
    if (pct >= 80) return 'B+';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    return 'F';
  }

  Widget _miniChip(String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1),
      ),
      child: Text(label,
        style: GoogleFonts.gaegu(fontSize: 12, fontWeight: FontWeight.w700, color: _brown, height: 1.1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (quizzes.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _goldHdr.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outline.withOpacity(0.4), width: 2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
              offset: const Offset(3, 3), blurRadius: 0)]),
          child: const Icon(Icons.quiz_outlined, size: 48, color: _brown),
        ),
        const SizedBox(height: 14),
        const Text('No quizzes yet~',
          style: TextStyle(fontFamily: 'Bitroad', fontSize: 22, color: _brown, height: 1.15)),
        const SizedBox(height: 4),
        Text('add materials and generate a quiz',
          style: GoogleFonts.gaegu(fontSize: 14, color: _brownLt, fontWeight: FontWeight.w600)),
      ]));
    }

    return RefreshIndicator(
      color: _coralHdr,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: quizzes.length,
        itemBuilder: (ctx, i) {
          final q = quizzes[i];
          final isCompleted = q['status'] == 'completed';
          final score = double.tryParse(q['score_achieved']?.toString() ?? '0') ?? 0;
          final maxS = double.tryParse(q['max_score']?.toString() ?? '1') ?? 1;
          final pct = maxS > 0 ? (score / maxS * 100) : 0.0;
          final topics = (q['topic_focus'] as List?)?.cast<String>() ?? [];
          final totalQ = q['total_questions'] ?? 0;
          final subColor = subjectColor(q['subject_id']);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _outline.withOpacity(0.4), width: 2),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)]),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTakeQuiz(q),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    // Status / Grade tile — Focus Mode
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: isCompleted
                          ? _gradeColor(pct).withOpacity(0.55)
                          : _goldHdr.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _outline.withOpacity(0.4), width: 1.5),
                      ),
                      child: Center(child: isCompleted
                        ? Text(_gradeLabel(pct), style: const TextStyle(
                            fontFamily: 'Bitroad', fontSize: 20, color: _brown, height: 1.0))
                        : Icon(
                            q['status'] == 'in_progress' ? Icons.play_arrow_rounded : Icons.edit_note_rounded,
                            size: 28, color: _brown),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q['title'] ?? 'Untitled',
                          style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w800, color: _brown, height: 1.15),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _miniChip(subjectName(q['subject_id']), subColor),
                          _miniChip('$totalQ questions', _skyHdr),
                          _miniChip(q['source'] == 'ai' ? 'AI' : 'Auto',
                            q['source'] == 'ai' ? _purpleHdr : _goldHdr),
                        ]),
                        if (topics.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(topics.take(3).join(' · '),
                            style: GoogleFonts.gaegu(fontSize: 12, color: _brownLt.withOpacity(0.85), height: 1.2),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    )),
                    const SizedBox(width: 10),
                    // Score or action — Focus Mode pill
                    if (isCompleted)
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _gradeColor(pct).withOpacity(0.55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _outline.withOpacity(0.4), width: 1.5),
                          ),
                          child: Text('${pct.toStringAsFixed(0)}%',
                            style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w800, color: _brown)),
                        ),
                        const SizedBox(height: 2),
                        Text('${score.toInt()}/$totalQ',
                          style: GoogleFonts.gaegu(fontSize: 12, color: _brownLt, fontWeight: FontWeight.w600)),
                      ])
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _greenHdr.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _outline.withOpacity(0.4), width: 1.5),
                          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                            offset: const Offset(2, 2), blurRadius: 0)]),
                        child: Text(q['status'] == 'in_progress' ? 'Resume' : 'Start',
                          style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w800,
                            color: _brown)),
                      ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


//  TAB 2: STUDY MATERIALS
class _MaterialsTab extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> subjects;
  final String Function(String?) subjectName;
  final Color Function(String?) subjectColor;
  final VoidCallback onRefresh;
  final dynamic api;
  final Future<void> Function(List<String>, {String? subjectId, int count, List<String>? topicFilter}) onGenerateQuiz;

  const _MaterialsTab({
    required this.materials, required this.subjects,
    required this.subjectName, required this.subjectColor,
    required this.onRefresh, required this.api,
    required this.onGenerateQuiz,
  });

  @override ConsumerState<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends ConsumerState<_MaterialsTab> {
  Set<String> _selected = {};
  bool _uploading = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Top actions bar — 2 rows
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          // Add Notes
          Expanded(child: _actionBtn(
            icon: Icons.edit_note_rounded,
            label: 'Add Notes',
            colors: [_skyLt, _skyHdr],
            onTap: () => _showAddMaterialDialog(context),
          )),
          const SizedBox(width: 6),
          // Upload File
          Expanded(child: _actionBtn(
            icon: Icons.upload_file_rounded,
            label: _uploading ? 'Uploading…' : 'Upload File',
            colors: [_purpleLt, _purpleHdr],
            onTap: _uploading ? null : () => _pickAndUploadFile(context),
          )),
          const SizedBox(width: 6),
          // Import Sessions
          Expanded(child: _actionBtn(
            icon: Icons.download_rounded,
            label: _importing ? 'Importing…' : 'From Sessions',
            colors: [_goldLt, _goldHdr],
            onTap: _importing ? null : () => _importFromSessions(context),
          )),
        ]),
      ),
      // Generate row (shown when materials selected)
      if (_selected.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SizedBox(width: double.infinity, child: _actionBtn(
            icon: Icons.auto_awesome_rounded,
            label: 'Generate Quiz (${_selected.length} selected)',
            colors: [_greenLt, _greenHdr],
            onTap: () => _showGenerateDialog(context),
          )),
        ),
      const SizedBox(height: 4),
      // Materials list
      Expanded(child: widget.materials.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.note_add_outlined, size: 56, color: _outline.withOpacity(0.15)),
            const SizedBox(height: 12),
            Text('No study materials yet',
              style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brownLt)),
            const SizedBox(height: 4),
            Text('Add notes, upload PDFs, or import from sessions',
              style: GoogleFonts.nunito(fontSize: 13, color: _brownLt.withOpacity(0.6))),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: widget.materials.length,
            itemBuilder: (ctx, i) => _materialCard(ctx, widget.materials[i]),
          ),
      ),
    ]);
  }

  Widget _materialCard(BuildContext context, Map<String, dynamic> m) {
    final isSelected = _selected.contains(m['id']);
    final subColor = widget.subjectColor(m['subject_id']);
    final words = m['word_count'] ?? 0;
    final topics = (m['topics'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? _skyLt.withOpacity(0.15) : _cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isSelected ? _skyHdr : _outline.withOpacity(0.08), width: isSelected ? 2 : 1)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
            if (isSelected) _selected.remove(m['id']);
            else _selected.add(m['id']);
          }),
          onLongPress: () => _showMaterialDetail(context, m),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // Checkbox
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _skyHdr : Colors.white,
                  border: Border.all(color: isSelected ? _skyHdr : _outline.withOpacity(0.2), width: 2)),
                child: isSelected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m['title'] ?? 'Untitled', style: GoogleFonts.gaegu(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: subColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text(widget.subjectName(m['subject_id']),
                      style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700, color: subColor)),
                  ),
                  const SizedBox(width: 6),
                  Text('$words words', style: GoogleFonts.nunito(fontSize: 10, color: _brownLt)),
                  if (m['source_type'] != null && m['source_type'] != 'typed' && m['source_type'] != 'pasted') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: m['source_type'] == 'pdf_upload' ? _coralLt.withOpacity(0.3)
                             : m['source_type'] == 'session_import' ? _goldLt.withOpacity(0.5)
                             : _purpleLt.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          m['source_type'] == 'pdf_upload' ? Icons.picture_as_pdf_rounded
                        : m['source_type'] == 'session_import' ? Icons.history_rounded
                        : Icons.image_rounded,
                          size: 10,
                          color: m['source_type'] == 'pdf_upload' ? _coralDk
                               : m['source_type'] == 'session_import' ? _goldHdr
                               : _purpleHdr),
                        const SizedBox(width: 2),
                        Text(
                          m['source_type'] == 'pdf_upload' ? 'PDF'
                        : m['source_type'] == 'session_import' ? 'Session'
                        : 'Image',
                          style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.w700,
                            color: m['source_type'] == 'pdf_upload' ? _coralDk
                                 : m['source_type'] == 'session_import' ? _goldHdr
                                 : _purpleHdr)),
                      ]),
                    ),
                  ],
                ]),
                if (topics.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Wrap(spacing: 4, children: topics.take(4).map((t) =>
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _purpleLt.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4)),
                      child: Text(t, style: GoogleFonts.nunito(fontSize: 9, color: _purpleHdr)),
                    )).toList()),
                ],
              ])),
              // Quick generate button
              GestureDetector(
                onTap: () => widget.onGenerateQuiz([m['id']], subjectId: m['subject_id']),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _greenHdr.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.auto_awesome_rounded, size: 18, color: _greenHdr),
                ),
              ),
              const SizedBox(width: 6),
              // Delete button — direct affordance (also available via long-press detail)
              GestureDetector(
                onTap: () => _confirmDeleteMaterial(context, m),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _coralHdr.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline_rounded, size: 18, color: _coralHdr),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required List<Color> colors,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.last.withOpacity(0.4))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 3),
          Flexible(child: Text(label,
            style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            overflow: TextOverflow.ellipsis, maxLines: 1)),
        ]),
      ),
    );
  }

  Future<void> _pickAndUploadFile(BuildContext context) async {
    setState(() => _uploading = true);
    try {
      await UploadNotesModal.show(
        context,
        ref: ref,
        subjects: widget.subjects
            .map((s) => UploadModalSubject(
                  id: (s['id'] ?? '').toString(),
                  name: (s['name'] ?? '').toString(),
                  icon: Icons.book_rounded,
                ))
            .where((s) => s.id.isNotEmpty)
            .toList(),
        onUploaded: (_) => widget.onRefresh(),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _confirmDeleteMaterial(BuildContext context, Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${m['title'] ?? 'Untitled'}"?',
          style: GoogleFonts.gaegu(fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
        content: Text(
          'This will permanently delete this study material and remove it from all quiz / flashcard generation sources. This cannot be undone.',
          style: GoogleFonts.nunito(fontSize: 13, color: _brownLt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.gaegu(fontSize: 16, color: _brownLt))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.gaegu(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red.shade400))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await widget.api.delete('/study/materials/${m['id']}');
      setState(() => _selected.remove(m['id']));
      widget.onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Material deleted', style: GoogleFonts.nunito()),
          backgroundColor: _greenHdr));
      }
    } catch (e) {
      debugPrint('Delete material error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e', style: GoogleFonts.nunito()),
          backgroundColor: _coralHdr));
      }
    }
  }

  // Retained for reference — previous inline dialog implementation.
  // ignore: unused_element
  Future<void> _legacyPickAndUploadFile(BuildContext context) async {
    // Use FileType.any on macOS — custom extensions can gray out files
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    // Validate extension manually
    final ext = file.extension?.toLowerCase() ?? '';
    final allowed = ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'md'];
    if (!allowed.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unsupported file type: .$ext\nAllowed: PDF, PNG, JPG, TXT, MD'),
        backgroundColor: Colors.red.shade400,
      ));
      return;
    }

    // Show a title input dialog
    final titleCtrl = TextEditingController(text: file.name.split('.').first);
    String? selectedSubjectId;
    final topicsCtrl = TextEditingController();

    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return Dialog(
          backgroundColor: _cardFill,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_purpleLt, _purpleHdr]),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Upload: ${file.name}', style: GoogleFonts.gaegu(
                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis, maxLines: 1)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Title'),
                  _field(titleCtrl, 'Material title'),
                  const SizedBox(height: 10),
                  _label('Subject'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _outline.withOpacity(0.12))),
                    child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                      isExpanded: true, value: selectedSubjectId,
                      hint: Text('Select subject', style: GoogleFonts.nunito(fontSize: 13, color: _brownLt)),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text('None', style: GoogleFonts.nunito(fontSize: 13))),
                        ...widget.subjects.map((s) => DropdownMenuItem<String?>(
                          value: s['id'], child: Text(s['name'] ?? '', style: GoogleFonts.nunito(fontSize: 13)))),
                      ],
                      onChanged: (v) => setDlg(() => selectedSubjectId = v),
                    )),
                  ),
                  const SizedBox(height: 10),
                  _label('Topics (comma-separated, optional)'),
                  _field(topicsCtrl, 'e.g. Photosynthesis, Cell division'),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_purpleLt, _purpleHdr]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _purpleHdr.withOpacity(0.4), width: 2),
                        boxShadow: [BoxShadow(color: _purpleHdr.withOpacity(0.25),
                          offset: const Offset(0, 3), blurRadius: 0)]),
                      child: Center(child: Text('Upload & Extract Text', style: GoogleFonts.gaegu(
                        fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
                  )),
                ]),
              ),
            ]),
          ),
        );
      }),
    );

    if (shouldUpload != true || !context.mounted) return;

    setState(() => _uploading = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
        'title': titleCtrl.text.trim().isEmpty ? file.name : titleCtrl.text.trim(),
        'subject_id': selectedSubjectId ?? '',
        'topics': topicsCtrl.text.trim(),
      });

      await widget.api.post('/study/materials/upload', data: formData);
      widget.onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('File uploaded & text extracted!', style: GoogleFonts.nunito()),
          backgroundColor: _greenHdr));
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e', style: GoogleFonts.nunito()),
          backgroundColor: _coralHdr));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _importFromSessions(BuildContext context) async {
    setState(() => _importing = true);
    try {
      final res = await widget.api.post('/study/materials/import-sessions');
      final count = res.data?['imported_count'] ?? 0;
      widget.onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imported $count session note(s) as materials!', style: GoogleFonts.nunito()),
          backgroundColor: _greenHdr));
      }
    } catch (e) {
      debugPrint('Import sessions error: $e');
      if (context.mounted) {
        final msg = e.toString().contains('422')
            ? 'No new session notes to import'
            : 'Import failed: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, style: GoogleFonts.nunito()),
          backgroundColor: e.toString().contains('422') ? _goldHdr : _coralHdr));
      }
    }
    if (mounted) setState(() => _importing = false);
  }

  void _showMaterialDetail(BuildContext context, Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: _outline.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Expanded(child: Text(m['title'] ?? 'Untitled',
                style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown))),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: _coralHdr, size: 22),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await widget.api.delete('/study/materials/${m['id']}');
                    widget.onRefresh();
                  } catch (e) { debugPrint('Delete material error: $e'); }
                },
              ),
            ]),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(m['content'] ?? '',
                style: GoogleFonts.nunito(fontSize: 14, height: 1.6, color: _brown)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showAddMaterialDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final topicsCtrl = TextEditingController();
    String? selectedSubjectId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return Dialog(
          backgroundColor: _cardFill,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_skyLt, _skyHdr]),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.note_add_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Add Study Material', style: GoogleFonts.gaegu(
                    fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
              // Form
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Title'),
                  _field(titleCtrl, 'e.g. Chapter 3 Notes'),
                  const SizedBox(height: 10),
                  _label('Subject'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _outline.withOpacity(0.12))),
                    child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                      isExpanded: true, value: selectedSubjectId,
                      hint: Text('Select subject', style: GoogleFonts.nunito(fontSize: 13, color: _brownLt)),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text('None', style: GoogleFonts.nunito(fontSize: 13))),
                        ...widget.subjects.map((s) => DropdownMenuItem<String?>(
                          value: s['id'], child: Text(s['name'] ?? '', style: GoogleFonts.nunito(fontSize: 13)))),
                      ],
                      onChanged: (v) => setDlg(() => selectedSubjectId = v),
                    )),
                  ),
                  const SizedBox(height: 10),
                  _label('Study Notes'),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 8, minLines: 5,
                    style: GoogleFonts.nunito(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Paste or type your study notes here...',
                      hintStyle: GoogleFonts.nunito(fontSize: 12, color: _brownLt.withOpacity(0.4)),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _outline.withOpacity(0.12))),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _outline.withOpacity(0.12))),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _skyHdr, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _label('Topics (comma-separated)'),
                  _field(topicsCtrl, 'e.g. Photosynthesis, Cell division'),
                  const SizedBox(height: 16),
                  // Save
                  SizedBox(width: double.infinity, child: GestureDetector(
                    onTap: () async {
                      final title = titleCtrl.text.trim();
                      final content = contentCtrl.text.trim();
                      if (title.isEmpty || content.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Title required & notes must be at least 10 characters',
                            style: GoogleFonts.nunito()),
                          backgroundColor: _coralHdr));
                        return;
                      }
                      final topics = topicsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                      try {
                        await widget.api.post('/study/materials', data: {
                          'title': title,
                          'content': content,
                          'source_type': 'pasted',
                          'topics': topics,
                          if (selectedSubjectId != null) 'subject_id': selectedSubjectId,
                        });
                        Navigator.pop(ctx);
                        widget.onRefresh();
                      } catch (e) {
                        debugPrint('Add material error: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error: $e', style: GoogleFonts.nunito()),
                            backgroundColor: _coralHdr));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_skyLt, _skyHdr]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _skyHdr.withOpacity(0.4), width: 2),
                        boxShadow: [BoxShadow(color: _skyHdr.withOpacity(0.25),
                          offset: const Offset(0, 3), blurRadius: 0)]),
                      child: Center(child: Text('Save Material', style: GoogleFonts.gaegu(
                        fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
                  )),
                ]),
              )),
            ]),
          ),
        );
      }),
    );
  }

  void _showGenerateDialog(BuildContext context) {
    int count = 10;
    // Build a unique, sorted list of topics across the selected materials.
    final selectedMaterials = widget.materials.where((m) => _selected.contains(m['id'])).toList();
    final allTopics = <String>{};
    String? sharedSubjectId;
    bool subjectConflict = false;
    for (final m in selectedMaterials) {
      final ts = (m['topics'] as List?) ?? const [];
      for (final t in ts) { allTopics.add(t.toString()); }
      final sid = m['subject_id']?.toString();
      if (sid != null && sid.isNotEmpty) {
        if (sharedSubjectId == null) { sharedSubjectId = sid; }
        else if (sharedSubjectId != sid) { subjectConflict = true; }
      }
    }
    final topicList = allTopics.toList()..sort();
    final selectedTopics = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          backgroundColor: _cardFill,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Generate Quiz', style: GoogleFonts.gaegu(
            fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 460),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_selected.length} material(s) selected',
                  style: GoogleFonts.nunito(fontSize: 14, color: _brownLt)),
                if (subjectConflict) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('⚠ Materials span multiple subjects',
                    style: GoogleFonts.nunito(fontSize: 11, color: _coralHdr)),
                ),
                const SizedBox(height: 14),
                Text('Questions',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt)),
                Slider(
                  value: count.toDouble(), min: 5, max: 25, divisions: 4,
                  label: '$count',
                  activeColor: _greenHdr,
                  onChanged: (v) => setDlg(() => count = v.toInt()),
                ),
                Text('$count questions (MCQ + T/F + Fill-blank)',
                  style: GoogleFonts.nunito(fontSize: 12, color: _brownLt)),
                if (topicList.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Text('Focus on topics (optional)',
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt))),
                    GestureDetector(
                      onTap: () => setDlg(() {
                        if (selectedTopics.length == topicList.length) {
                          selectedTopics.clear();
                        } else {
                          selectedTopics
                            ..clear()
                            ..addAll(topicList);
                        }
                      }),
                      child: Text(
                        selectedTopics.length == topicList.length ? 'clear' : 'all',
                        style: GoogleFonts.nunito(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _greenHdr)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final t in topicList)
                      GestureDetector(
                        onTap: () => setDlg(() {
                          if (selectedTopics.contains(t)) { selectedTopics.remove(t); }
                          else { selectedTopics.add(t); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: selectedTopics.contains(t) ? _purpleHdr : _purpleLt.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _outline.withOpacity(0.25), width: 1),
                          ),
                          child: Text(t,
                            style: GoogleFonts.nunito(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: selectedTopics.contains(t) ? Colors.white : _brown)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(selectedTopics.isEmpty
                      ? 'no filter — quiz draws from all topics'
                      : '${selectedTopics.length} topic${selectedTopics.length == 1 ? '' : 's'} selected',
                    style: GoogleFonts.nunito(fontSize: 10, color: _brownLt.withOpacity(0.75))),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: _brownLt))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onGenerateQuiz(
                  _selected.toList(),
                  count: count,
                  subjectId: !subjectConflict ? sharedSubjectId : null,
                  topicFilter: selectedTopics.isEmpty ? null : selectedTopics.toList(),
                );
                setState(() => _selected = {});
              },
              child: Text('Generate', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: _greenHdr))),
          ],
        );
      }),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt)),
  );

  Widget _field(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    style: GoogleFonts.nunito(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(fontSize: 12, color: _brownLt.withOpacity(0.4)),
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _outline.withOpacity(0.12))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _outline.withOpacity(0.12))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _skyHdr, width: 1.5)),
    ),
  );
}


//  TAB 3: QUIZ SCHEDULE
//  QUIZ SCHEDULE TAB
//
//  Narrow scope: configure automatic quiz generation — frequency,
//  day-of-week, question count, enabled switch, and a "Generate Now"
//  escape hatch. The broader "universal smart scheduler" (which plans
//  focus sessions + flashcards + quizzes + light review across the
//  week) lives under the Study Calendar screen now, where it belongs
//  alongside the day/month grid it populates.
class _ScheduleTab extends StatefulWidget {
  final Map<String, dynamic>? schedule;
  final List<Map<String, dynamic>> subjects;
  final dynamic api;
  final VoidCallback onRefresh;
  final Future<void> Function() onGenerateNow;

  const _ScheduleTab({
    required this.schedule, required this.subjects,
    required this.api, required this.onRefresh,
    required this.onGenerateNow,
  });

  @override State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  String _frequency = 'weekly';    // 'weekly' | 'biweekly' | 'monthly'
  int _dayOfWeek    = 0;           // 0 = Mon … 6 = Sun
  int _questionCount = 10;         // 5..25
  bool _enabled      = true;

  bool _saving     = false;
  bool _generating = false;

  // The Calendar screen's Smart Scheduler can also place quiz blocks on the
  // week. When it's enabled + scheduling quizzes, we surface a banner so the
  // user understands the two schedulers are coordinating rather than fighting.
  Map<String, dynamic>? _smartCfg;

  static const _dayLabels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  static const _freqOptions = [
    ('weekly',   'Weekly'),
    ('biweekly', 'Biweekly'),
    ('monthly',  'Monthly'),
  ];

  @override
  void initState() {
    super.initState();
    _hydrate(widget.schedule);
    _loadSmartCfg();
  }

  Future<void> _loadSmartCfg() async {
    try {
      final resp = await widget.api.get('/study/smart-schedule/config');
      if (!mounted) return;
      final data = resp?.data;
      if (data is Map) {
        setState(() => _smartCfg = Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // Non-fatal — the schedule tab just won't show the smart-scheduler
      // banner. Either the endpoint is unreachable or the user has no config.
    }
  }

  bool get _smartActiveForQuizzes =>
      _smartCfg != null &&
      (_smartCfg!['enabled'] ?? false) == true &&
      (_smartCfg!['enable_quizzes'] ?? false) == true;

  @override
  void didUpdateWidget(covariant _ScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedule != widget.schedule) {
      _hydrate(widget.schedule);
    }
  }

  void _hydrate(Map<String, dynamic>? s) {
    if (s == null) return;
    _frequency     = (s['frequency'] ?? 'weekly').toString();
    _dayOfWeek     = (s['day_of_week'] is int) ? s['day_of_week'] : 0;
    _questionCount = (s['question_count'] is int) ? s['question_count'] : 10;
    _enabled       = s['enabled'] ?? true;
  }

  String _formatNextDue() {
    final n = widget.schedule?['next_due_at'];
    if (n == null) return 'Not scheduled yet';
    try {
      final dt = DateTime.parse(n.toString()).toLocal();
      final diff = dt.difference(DateTime.now());
      if (diff.isNegative) return 'Due now';
      final days = diff.inDays;
      if (days == 0) return 'Later today';
      if (days == 1) return 'Tomorrow';
      if (days < 7) return 'In $days days';
      return DateFormat('EEE, MMM d').format(dt);
    } catch (_) { return 'Scheduled'; }
  }

  Future<void> _saveSchedule() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.post('/study/quiz-schedule', data: {
        'frequency': _frequency,
        'day_of_week': _dayOfWeek,
        'question_count': _questionCount,
        'question_types': ['mcq', 'true_false', 'fill_blank'],
        'enabled': _enabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Schedule saved',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          backgroundColor: _greenHdr));
      }
      widget.onRefresh();
    } catch (e) {
      debugPrint('Quiz schedule save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Couldn\'t save schedule', style: GoogleFonts.nunito()),
          backgroundColor: _coralDk));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _generateNow() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      await widget.onGenerateNow();
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _hero(),
        const SizedBox(height: 14),
        if (_smartActiveForQuizzes) ...[
          _smartBanner(),
          const SizedBox(height: 12),
        ],
        _frequencyCard(),
        const SizedBox(height: 12),
        _dayCard(),
        const SizedBox(height: 12),
        _countCard(),
        const SizedBox(height: 16),
        _saveButton(),
        const SizedBox(height: 10),
        _generateNowButton(),
        const SizedBox(height: 18),
        _footnote(),
      ]),
    );
  }

  Widget _hero() {
    final due = _formatNextDue();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_goldLt.withOpacity(0.55), _coralLt.withOpacity(0.45)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _goldHdr.withOpacity(0.35), width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _outline.withOpacity(0.18))),
          child: const Icon(Icons.quiz_rounded, size: 22, color: _coralDk),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Smart Quiz Schedule',
            style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w800, color: _brown)),
          const SizedBox(height: 2),
          Text(
            'Auto-generates a fresh quiz from your weakest topics on a '
            'cadence you pick. Next: $due',
            style: GoogleFonts.nunito(fontSize: 12, color: _brownLt, height: 1.35)),
        ])),
        const SizedBox(width: 8),
        Switch(
          value: _enabled,
          activeColor: _greenDk,
          onChanged: (v) => setState(() => _enabled = v),
        ),
      ]),
    );
  }

  Widget _frequencyCard() {
    return _settingsCard(
      icon: Icons.repeat_rounded, iconColor: _greenDk,
      title: 'Frequency',
      subtitle: 'How often should we generate a new quiz?',
      child: Row(children: [
        for (int i = 0; i < _freqOptions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _freqChip(_freqOptions[i].$1, _freqOptions[i].$2)),
        ],
      ]),
    );
  }

  Widget _freqChip(String value, String label) {
    final selected = _frequency == value;
    return GestureDetector(
      onTap: () => setState(() => _frequency = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _greenHdr.withOpacity(0.55) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _greenDk.withOpacity(0.55) : _outline.withOpacity(0.18),
            width: selected ? 1.6 : 1.0),
        ),
        child: Text(label,
          style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: selected ? _brown : _brownLt)),
      ),
    );
  }

  Widget _dayCard() {
    return _settingsCard(
      icon: Icons.calendar_today_rounded, iconColor: _coralDk,
      title: 'Day of week',
      subtitle: _frequency == 'monthly'
          ? 'We\'ll pick the first ${_dayLabels[_dayOfWeek]} of each month'
          : 'Which day should quizzes land on?',
      child: Row(children: [
        for (int i = 0; i < _dayLabels.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(child: _dayChip(i)),
        ],
      ]),
    );
  }

  Widget _dayChip(int index) {
    final selected = _dayOfWeek == index;
    return GestureDetector(
      onTap: () => setState(() => _dayOfWeek = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _coralHdr.withOpacity(0.6) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _coralDk.withOpacity(0.6) : _outline.withOpacity(0.15),
            width: selected ? 1.6 : 1.0),
        ),
        child: Text(_dayLabels[index],
          style: GoogleFonts.nunito(
            fontSize: 11.5, fontWeight: FontWeight.w800,
            color: selected ? _brown : _brownLt)),
      ),
    );
  }

  Widget _countCard() {
    return _settingsCard(
      icon: Icons.format_list_numbered_rounded, iconColor: _purpleHdr,
      title: 'Questions per quiz',
      subtitle: 'How many questions should each generated quiz contain?',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$_questionCount',
            style: GoogleFonts.gaegu(
              fontSize: 26, fontWeight: FontWeight.w800, color: _brown)),
          const SizedBox(width: 6),
          Text('questions',
            style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: _brownLt)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _purpleHdr,
            inactiveTrackColor: _purpleLt.withOpacity(0.5),
            thumbColor: _purpleHdr,
            overlayColor: _purpleHdr.withOpacity(0.15),
            valueIndicatorColor: _purpleHdr,
            trackHeight: 5,
          ),
          child: Slider(
            min: 5, max: 25, divisions: 20,
            value: _questionCount.toDouble(),
            label: '$_questionCount',
            onChanged: (v) => setState(() => _questionCount = v.round()),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('5', style: GoogleFonts.nunito(fontSize: 11, color: _brownLt)),
          Text('25', style: GoogleFonts.nunito(fontSize: 11, color: _brownLt)),
        ]),
      ]),
    );
  }

  Widget _settingsCard({
    required IconData icon, required Color iconColor,
    required String title, required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withOpacity(0.10)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
        ]),
        const SizedBox(height: 2),
        Text(subtitle,
          style: GoogleFonts.nunito(fontSize: 11, color: _brownLt)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _saveButton() {
    return GestureDetector(
      onTap: _saving ? null : _saveSchedule,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _saving
              ? [Colors.grey.shade300, Colors.grey.shade400]
              : [_greenLt, _greenHdr]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _greenDk.withOpacity(0.45), width: 2),
          boxShadow: _saving ? null : [BoxShadow(
            color: _greenDk.withOpacity(0.25),
            offset: const Offset(0, 3), blurRadius: 0)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_saving)
            const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            const Icon(Icons.save_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(_saving ? 'Saving…' : 'Save schedule',
            style: GoogleFonts.gaegu(
              fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _generateNowButton() {
    return GestureDetector(
      onTap: _generating ? null : _generateNow,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _coralDk.withOpacity(0.45), width: 1.6),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_generating)
            const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _coralDk))
          else
            const Icon(Icons.bolt_rounded, color: _coralDk, size: 18),
          const SizedBox(width: 8),
          Text(_generating ? 'Generating…' : 'Generate a smart quiz now',
            style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w800, color: _coralDk)),
        ]),
      ),
    );
  }

  Widget _footnote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Tip: the broader week-wide planner — focus sessions, flashcards, light review '
        'and quizzes slotted around your calendar — lives on the Study Calendar screen.',
        style: GoogleFonts.nunito(fontSize: 11, color: _brownLt.withOpacity(0.7), height: 1.4),
        textAlign: TextAlign.center),
    );
  }

  // two schedulers aren't treated as independent systems by the user. ──
  Widget _smartBanner() {
    final cfg = _smartCfg ?? const {};
    final perWeek = (cfg['quiz_per_week'] is int) ? cfg['quiz_per_week'] : 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: _purpleHdr.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _purpleHdr.withOpacity(0.35), width: 1.2),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _purpleHdr.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.auto_awesome_rounded, size: 15, color: _brown),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Smart Scheduler is also planning quizzes',
            style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w800, color: _brown)),
          const SizedBox(height: 2),
          Text(
            '$perWeek quiz block${perWeek == 1 ? '' : 's'}/week are placed by the week-wide '
            'planner in Calendar → Smart Scheduler. This cadence above runs alongside them.',
            style: GoogleFonts.nunito(fontSize: 11, color: _brownLt, height: 1.35)),
        ])),
      ]),
    );
  }
}


//  PAWPRINT BACKGROUND
class _PawBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const sp = 90.0, rs = 45.0, r = 10.0;
    int idx = 0;
    for (double y = 30; y < size.height; y += sp) {
      final odd = ((y / sp).floor() % 2) == 1;
      for (double x = (odd ? rs : 0) + 30; x < size.width; x += sp) {
        paint.color = _pawClr.withOpacity(0.05 + (idx % 5) * 0.014);
        final a = (idx % 4) * 0.3 - 0.3;
        canvas.save(); canvas.translate(x, y); canvas.rotate(a);
        // Pad (oval) — matches subjects/resources reference paw
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 1.8), paint);
        // Four toes above the pad
        final tr = r * 0.52;
        canvas.drawCircle(Offset(-r * 1.0, -r * 1.35), tr, paint);
        canvas.drawCircle(Offset(-r * 0.38, -r * 1.65), tr, paint);
        canvas.drawCircle(Offset(r * 0.38, -r * 1.65), tr, paint);
        canvas.drawCircle(Offset(r * 1.0, -r * 1.35), tr, paint);
        canvas.restore();
        idx++;
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}
