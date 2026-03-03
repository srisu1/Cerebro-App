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

const _ombre1   = Color(0xFFFFFBF7);
const _ombre2   = Color(0xFFFFF8F3);
const _ombre3   = Color(0xFFFFF3EF);
const _ombre4   = Color(0xFFFEEDE9);
const _cardFill = Color(0xFFFFF8F4);
const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);
const _coralHdr = Color(0xFFF0A898);
const _coralLt  = Color(0xFFF8C0B0);
const _coralDk  = Color(0xFFD08878);
const _greenHdr = Color(0xFFA8D5A3);
const _greenLt  = Color(0xFFC2E8BC);
const _greenDk  = Color(0xFF88B883);
const _goldHdr  = Color(0xFFF0D878);
const _goldLt   = Color(0xFFFFF0C0);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _skyHdr   = Color(0xFF9DD4F0);
const _skyLt    = Color(0xFFB8E0F8);
const _pawClr   = Color(0xFFF8BCD0);

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
    _tabCtrl = TabController(length: 2, vsync: this);
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
        SafeArea(child: Column(children: [
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
                ),
              ])),
        ])),
      ]),
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_coralLt, _coralHdr]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _coralDk.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: _coralDk.withOpacity(0.15),
          offset: const Offset(0, 4), blurRadius: 12)],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.quiz_rounded, color: Colors.white, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text('Quiz Hub',
          style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white))),
        // Stats pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12)),
          child: Text('${_quizzes.where((q) => q['status'] == 'completed').length} done',
            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline.withOpacity(0.08))),
      child: TabBar(
        controller: _tabCtrl,
        labelStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600),
        labelColor: Colors.white,
        unselectedLabelColor: _brownLt,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [_coralLt, _coralHdr]),
          borderRadius: BorderRadius.circular(12)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        tabs: const [
          Tab(icon: Icon(Icons.list_alt_rounded, size: 16), text: 'Quizzes'),
          Tab(icon: Icon(Icons.description_rounded, size: 16), text: 'Materials'),
        ],
      ),
    );
  }

  void _navigateToQuiz(Map<String, dynamic> quiz) {
    context.push(Routes.takeQuiz, extra: quiz);
  }

}
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

  @override
  Widget build(BuildContext context) {
    if (quizzes.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.quiz_outlined, size: 56, color: _outline.withOpacity(0.15)),
        const SizedBox(height: 12),
        Text('No quizzes yet!',
          style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brownLt)),
        const SizedBox(height: 4),
        Text('Add materials and generate a quiz',
          style: GoogleFonts.nunito(fontSize: 13, color: _brownLt.withOpacity(0.6))),
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
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outline.withOpacity(0.08)),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.04),
                offset: const Offset(0, 2), blurRadius: 6)]),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onTakeQuiz(q),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    // Status / Grade circle
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                          ? _gradeColor(pct).withOpacity(0.15)
                          : _goldLt.withOpacity(0.4),
                        border: Border.all(
                          color: isCompleted ? _gradeColor(pct) : _goldHdr,
                          width: 2),
                      ),
                      child: Center(child: isCompleted
                        ? Text(_gradeLabel(pct), style: GoogleFonts.gaegu(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: _gradeColor(pct)))
                        : Icon(
                            q['status'] == 'in_progress' ? Icons.play_arrow_rounded : Icons.hourglass_empty_rounded,
                            size: 20, color: _goldHdr),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q['title'] ?? 'Untitled',
                          style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: subColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4)),
                            child: Text(subjectName(q['subject_id']),
                              style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700, color: subColor)),
                          ),
                          const SizedBox(width: 6),
                          Text('$totalQ questions', style: GoogleFonts.nunito(fontSize: 10, color: _brownLt)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: q['source'] == 'ai' ? _purpleLt.withOpacity(0.4) : _skyLt.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4)),
                            child: Text(q['source'] == 'ai' ? 'AI' : 'Auto',
                              style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700,
                                color: q['source'] == 'ai' ? _purpleHdr : _skyHdr)),
                          ),
                        ]),
                        if (topics.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(topics.take(3).join(', '),
                            style: GoogleFonts.nunito(fontSize: 10, color: _brownLt.withOpacity(0.7)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    )),
                    // Score or action
                    if (isCompleted)
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${pct.toStringAsFixed(0)}%',
                          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800,
                            color: _gradeColor(pct))),
                        Text('${score.toInt()}/$totalQ',
                          style: GoogleFonts.nunito(fontSize: 10, color: _brownLt)),
                      ])
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_greenLt, _greenHdr]),
                          borderRadius: BorderRadius.circular(10)),
                        child: Text(q['status'] == 'in_progress' ? 'Resume' : 'Start',
                          style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700,
                            color: Colors.white)),
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
class _MaterialsTab extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> subjects;
  final String Function(String?) subjectName;
  final Color Function(String?) subjectColor;
  final VoidCallback onRefresh;
  final dynamic api;

  const _MaterialsTab({
    required this.materials, required this.subjects,
    required this.subjectName, required this.subjectColor,
    required this.onRefresh, required this.api,
  });

  @override State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<_MaterialsTab> {
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
      ),      const SizedBox(height: 4),
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
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _skyHdr : Colors.white,
                  border: Border.all(color: isSelected ? _skyHdr : _outline.withOpacity(0.2), width: 2)),
                child: isSelected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(width: 10),
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
              ])),              GestureDetector(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _greenHdr.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.auto_awesome_rounded, size: 18, color: _greenHdr),
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
class _PawBgPainter extends CustomPainter {
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
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 1.8), paint);
        for (final o in [const Offset(-8, -10), const Offset(0, -13), const Offset(8, -10)]) {
          canvas.drawCircle(o, r * 0.55, paint);
        }
        canvas.restore();
        idx++;
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}
