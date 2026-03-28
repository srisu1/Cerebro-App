// Subject detail — Overview, Topics, Content tabs for a single subject.

import 'package:flutter/material.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/widgets/upload_notes_modal.dart';
import 'package:cerebro_app/screens/study/flashcard_screen.dart';
import 'package:cerebro_app/screens/study/quiz_screen.dart';


bool get _darkMode =>
    CerebroTheme.brightnessNotifier.value == Brightness.dark;

Color get _ombre1 => _darkMode ? const Color(0xFF191513) : const Color(0xFFFFFBF7);
Color get _ombre4 => _darkMode ? const Color(0xFF312821) : const Color(0xFFFEEDE9);
Color get _cardFill => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF8F4);
Color get _cream => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFDEFDB);
Color get _panelBg => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFF6EE);
Color get _outline => _darkMode ? const Color(0xFFAD7F58) : const Color(0xFF6E5848);
Color get _brown => _darkMode ? const Color(0xFFF2E1CA) : const Color(0xFF4E3828);
Color get _brownLt => _darkMode ? const Color(0xFFDBB594) : const Color(0xFF7A5840);
Color get _brownSoft => _darkMode ? const Color(0xFFBD926C) : const Color(0xFF9A8070);
Color get _olive => const Color(0xFF98A869);
Color get _oliveDk => const Color(0xFF58772F);
Color get _mSage => const Color(0xFFB5C4A0);
Color get _mTerra => const Color(0xFFD9B5A6);
Color get _mSlate => const Color(0xFFB6CBD6);
Color get _mLav => const Color(0xFFC9B8D9);
Color get _mButter => const Color(0xFFE8D4A0);
Color get _mBlush => const Color(0xFFEAD0CE);
Color get _red => const Color(0xFFEF6262);
// Paw overlay color — matches sibling screens.
Color get _pawClr => _darkMode ? const Color(0xFF231D18) : const Color(0xFFF8BCD0);
class _SubjectSummary {
  final String id;
  final String name;
  final String code;
  final Color accent;
  final double currentProf;
  final double targetProf;
  final IconData icon;
  const _SubjectSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.accent,
    required this.currentProf,
    required this.targetProf,
    required this.icon,
  });
}

Color _hexToColor(String hex) {
  var s = hex.replaceFirst('#', '').trim();
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFFD9B5A6);
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String _fmtDate(DateTime dt) {
  final now = DateTime.now();
  final d = now.difference(dt);
  if (d.inDays >= 7) {
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
  }
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
  return 'just now';
}

IconData _iconForSource(String s) {
  switch (s) {
    case 'pdf_upload':     return Icons.picture_as_pdf_rounded;
    case 'image_upload':   return Icons.image_rounded;
    case 'pasted':         return Icons.content_paste_rounded;
    case 'session_import': return Icons.timer_rounded;
    case 'typed':
    default:               return Icons.edit_note_rounded;
  }
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

// Unified "activity" comparator — newest first. Prefer `created_at`,
// fall back to `date_taken`, then `updated_at`, then `start_time`.
DateTime? _activityDate(Map<String, dynamic> m) {
  return _parseDate(m['created_at'])
      ?? _parseDate(m['date_taken'])
      ?? _parseDate(m['updated_at'])
      ?? _parseDate(m['start_time']);
}

//  PUBLIC ENTRY POINT
class SubjectDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final String? initialSubjectName; // optional hint while loading
  final String? initialColorHex;
  final String? initialIconKey;
  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    this.initialSubjectName,
    this.initialColorHex,
    this.initialIconKey,
  });

  @override
  ConsumerState<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;

  bool _loadingSubject = true;
  bool _loadingData    = true;
  String? _error;

  _SubjectSummary? _subject;

  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _sessions  = [];
  List<Map<String, dynamic>> _decks     = [];
  // `_quizzes` is the MERGED list of `/study/quizzes` (source='quiz') and
  // `/study/generated-quizzes` (source='generated_quiz') — sorted desc.
  List<Map<String, dynamic>> _quizzes   = [];
  List<Map<String, dynamic>> _topics    = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadSubject();
    await _loadContent();
  }

  Future<void> _loadSubject() async {
    setState(() { _loadingSubject = true; });
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.get('/study/subjects/${widget.subjectId}');
      final j = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final hex = (j['color'] as String?) ?? widget.initialColorHex ?? '#D9B5A6';
      setState(() {
        _subject = _SubjectSummary(
          id: j['id']?.toString() ?? widget.subjectId,
          name: (j['name'] as String?) ?? widget.initialSubjectName ?? 'Subject',
          code: (j['code'] as String?) ?? '',
          accent: _hexToColor(hex),
          currentProf: _asDouble(j['current_proficiency']) ?? 0,
          targetProf:  _asDouble(j['target_proficiency'])  ?? 100,
          icon: Icons.menu_book_rounded,
        );
        _loadingSubject = false;
      });
    } catch (e) {
      debugPrint('Subject load error: $e');
      setState(() {
        _subject = _SubjectSummary(
          id: widget.subjectId,
          name: widget.initialSubjectName ?? 'Subject',
          code: '',
          accent: _hexToColor(widget.initialColorHex ?? '#D9B5A6'),
          currentProf: 0, targetProf: 100,
          icon: Icons.menu_book_rounded,
        );
        _loadingSubject = false;
      });
    }
  }

  Future<void> _loadContent() async {
    if (!mounted) return;
    setState(() { _loadingData = true; _error = null; });
    final api = ref.read(apiServiceProvider);
    final sid = widget.subjectId;
    try {
      final results = await Future.wait([
        api.get('/study/materials',         queryParams: {'subject_id': sid}),
        api.get('/study/sessions',          queryParams: {'subject_id': sid}),
        api.get('/study/decks',             queryParams: {'subject_id': sid}),
        api.get('/study/quizzes',           queryParams: {'subject_id': sid}),
        api.get('/study/subjects/$sid/topics'),
        api.get('/study/generated-quizzes', queryParams: {'subject_id': sid}),
      ]);

      List<Map<String, dynamic>> toList(dynamic d) {
        if (d is List) {
          return d.whereType<Map<String, dynamic>>().toList();
        }
        return <Map<String, dynamic>>[];
      }

      // Tag each quiz list with its source so the UI and delete
      // routes know which endpoint to call.
      final completedQuizzes = toList(results[3].data).map((q) {
        final out = Map<String, dynamic>.from(q);
        out['_source'] = 'quiz';
        return out;
      }).toList();
      final generatedQuizzes = toList(results[5].data).map((q) {
        final out = Map<String, dynamic>.from(q);
        out['_source'] = 'generated_quiz';
        return out;
      }).toList();

      final merged = <Map<String, dynamic>>[
        ...completedQuizzes,
        ...generatedQuizzes,
      ];
      merged.sort((a, b) {
        final da = _activityDate(a);
        final db = _activityDate(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da); // newest first
      });

      if (!mounted) return;
      setState(() {
        _materials = toList(results[0].data);
        _sessions  = toList(results[1].data);
        _decks     = toList(results[2].data);
        _quizzes   = merged;
        _topics    = toList(results[4].data);
        _loadingData = false;
      });
    } catch (e) {
      debugPrint('Subject content load error: $e');
      if (!mounted) return;
      setState(() { _loadingData = false; _error = e.toString(); });
    }
  }

  //
  // When a Topic pill on the Topics tab is tapped, surface every piece
  // of subject content currently linked to that topic. We don't hit a
  // dedicated `/topics/{id}/items` endpoint — instead we filter the
  // already-loaded `_materials`, `_decks`, `_quizzes`, `_sessions` lists
  // by the topic name. That keeps this purely client-side, instant, and
  // free of an extra network round-trip.
  //
  // Match strategy: case-insensitive, whitespace-collapsed equality on
  // the topic's `name` against the strings inside each item's tag array
  // (`topics`, `topics_tested`, `topics_covered`, `tags`, `topic_focus`).
  //
  // Items with no matches still render the empty-state hint so the
  // user understands tapping the topic worked — we just have nothing to
  // show yet.
  String _normalizeTag(String raw) =>
      raw.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).join(' ').toLowerCase();

  bool _itemHasTopic(List<dynamic> tagList, String topicName) {
    final wanted = _normalizeTag(topicName);
    if (wanted.isEmpty) return false;
    for (final t in tagList) {
      if (_normalizeTag(t.toString()) == wanted) return true;
    }
    return false;
  }

  void _showTopicDetail(Map<String, dynamic> t) {
    final topicName = (t['name'] as String?) ?? 'Topic';
    final colorHex = (t['color'] as String?) ?? '#C9B8D9';
    final accent = _hexToColor(colorHex);

    final linkedMaterials = _materials.where((m) =>
      _itemHasTopic((m['topics'] as List?) ?? const [], topicName)).toList();
    final linkedSessions = _sessions.where((s) =>
      _itemHasTopic((s['topics_covered'] as List?) ?? const [], topicName)).toList();
    final linkedDecks = _decks.where((d) =>
      _itemHasTopic((d['topics'] as List?) ?? const [], topicName)).toList();
    final linkedQuizzes = _quizzes.where((q) {
      final tested = (q['topics_tested'] as List?) ?? const [];
      final focus  = (q['topic_focus']   as List?) ?? const [];
      final tags   = (q['topics']        as List?) ?? const [];
      return _itemHasTopic(tested, topicName)
          || _itemHasTopic(focus,  topicName)
          || _itemHasTopic(tags,   topicName);
    }).toList();

    final total = linkedMaterials.length + linkedSessions.length
        + linkedDecks.length + linkedQuizzes.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _outline.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2))),
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 6),
              child: Row(children: [
                Container(
                  width: 12, height: 32,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _outline.withOpacity(0.5), width: 1)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(topicName,
                    style: GoogleFonts.gaegu(
                      fontSize: 22, fontWeight: FontWeight.w700, color: _brown),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                  Text('$total linked item${total == 1 ? '' : 's'}',
                    style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      letterSpacing: 1.2, color: _brownLt)),
                ])),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: _brownLt, size: 22),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]),
            ),
            const Divider(height: 1, indent: 18, endIndent: 18),
            // Body
            Expanded(child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: total == 0
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle,
                          border: Border.all(color: _outline, width: 1.4),
                          boxShadow: [BoxShadow(
                            color: _outline.withOpacity(0.3),
                            offset: const Offset(2, 2), blurRadius: 0)]),
                        child: const Icon(Icons.label_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 12),
                      Text('Nothing tagged yet',
                        style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
                      const SizedBox(height: 6),
                      Text('Add this topic to a note, deck or quiz and it will show up here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(fontSize: 12, color: _brownSoft, height: 1.4)),
                    ]),
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (linkedMaterials.isNotEmpty) ...[
                      _sectionHeaderPill(
                        dotColor: _mSlate,
                        label: 'Notes (${linkedMaterials.length})'),
                      const SizedBox(height: 8),
                      for (final m in linkedMaterials)
                        Padding(padding: const EdgeInsets.only(bottom: 8),
                          child: _MaterialRow(
                            mat: m,
                            onTap: () { Navigator.pop(ctx); _openMaterialDetail(m); },
                            onDelete: () async { Navigator.pop(ctx); await _deleteMaterial(m); },
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (linkedDecks.isNotEmpty) ...[
                      _sectionHeaderPill(
                        dotColor: _mBlush,
                        label: 'Decks (${linkedDecks.length})'),
                      const SizedBox(height: 8),
                      for (final d in linkedDecks)
                        Padding(padding: const EdgeInsets.only(bottom: 8),
                          child: _DeckRow(
                            deck: d,
                            onTap: () { Navigator.pop(ctx); _openDeck(d); },
                            onDelete: () async { Navigator.pop(ctx); await _deleteDeck(d); },
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (linkedQuizzes.isNotEmpty) ...[
                      _sectionHeaderPill(
                        dotColor: _olive,
                        label: 'Quizzes (${linkedQuizzes.length})'),
                      const SizedBox(height: 8),
                      for (final q in linkedQuizzes)
                        Padding(padding: const EdgeInsets.only(bottom: 8),
                          child: _QuizRow(
                            quiz: q,
                            onTap: () { Navigator.pop(ctx); _openQuizResult(q); },
                            onDelete: () async { Navigator.pop(ctx); await _deleteQuiz(q); },
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (linkedSessions.isNotEmpty) ...[
                      _sectionHeaderPill(
                        dotColor: _mButter,
                        label: 'Sessions (${linkedSessions.length})'),
                      const SizedBox(height: 8),
                      for (final s in linkedSessions)
                        Padding(padding: const EdgeInsets.only(bottom: 8),
                          child: _SessionRowCompact(session: s)),
                    ],
                  ]),
            )),
          ]),
        ),
      ),
    );
  }

  Future<void> _uploadMaterial() async {
    if (_subject == null) return;
    await UploadNotesModal.show(
      context,
      ref: ref,
      subjects: [UploadModalSubject(
        id: _subject!.id,
        name: _subject!.name,
        icon: _subject!.icon,
      )],
      preselectedSubjectId: _subject!.id,
      onUploaded: (_) => _loadContent(),
    );
  }

  // Creates a flashcard deck scoped to this subject. Exists on the
  // Subject Detail page so users never have to leave, filter the
  // Flashcards page, then remember to pick the Subject dropdown — they
  // can just tap "+ deck" here and the subject_id is baked in.
  Future<void> _createDeck() async {
    if (_subject == null) return;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    const presets = <String>[
      '#A8D5A3', '#F4B9B2', '#F9E3A2', '#C8BEE8', '#B6D9E2', '#E8C4A0',
    ];
    String color = presets.first;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _outline, width: 3),
        ),
        title: Text('New deck for ${_subject!.name}',
          style: GoogleFonts.gaegu(
            fontSize: 22, fontWeight: FontWeight.w700, color: _brown),
          maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: GoogleFonts.nunito(fontSize: 14, color: _brown),
              decoration: InputDecoration(
                labelText: 'Deck name',
                labelStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 2.2)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: GoogleFonts.nunito(fontSize: 14, color: _brown),
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 2.2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Color',
              style: GoogleFonts.gaegu(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final hex in presets)
                GestureDetector(
                  onTap: () => setD(() => color = hex),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Color(int.parse('FF${hex.substring(1)}', radix: 16)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color == hex ? _outline : _outline.withOpacity(0.3),
                        width: color == hex ? 3 : 1.5),
                    ),
                    child: color == hex
                      ? Icon(Icons.check_rounded, size: 16, color: _brown)
                      : null,
                  ),
                ),
            ]),
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.gaegu(
              fontSize: 16, color: _brownLt)),
          ),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                await ref.read(apiServiceProvider).post('/study/decks', data: {
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'color': color,
                  // This is the whole point of having the CTA here —
                  // the subject_id gets baked in automatically so the
                  // new deck shows up under this subject immediately.
                  'subject_id': _subject!.id,
                });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('Create failed: $e',
                      style: GoogleFonts.nunito()),
                    backgroundColor: _mTerra));
                }
              }
            },
            child: Text('Create',
              style: GoogleFonts.gaegu(
                fontSize: 16, fontWeight: FontWeight.w700, color: _oliveDk)),
          ),
        ],
      )),
    );

    if (created == true) {
      _snack('Deck created for ${_subject!.name}');
      _loadContent();
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.gaegu(
          fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
        content: Text(body, style: GoogleFonts.nunito(fontSize: 13, color: _brownLt)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.gaegu(fontSize: 16, color: _brownLt))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.gaegu(
              fontSize: 16, fontWeight: FontWeight.w700, color: _red))),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito()),
      backgroundColor: bg ?? _mSage,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _deleteMaterial(Map<String, dynamic> m) async {
    if (!await _confirm('Delete "${m['title'] ?? 'material'}"?',
        'This removes it from all quiz and flashcard generation. Cannot be undone.')) return;
    try {
      await ref.read(apiServiceProvider).delete('/study/materials/${m['id']}');
      _snack('Material deleted');
      _loadContent();
    } catch (e) {
      _snack('Delete failed: $e', bg: _mTerra);
    }
  }

  Future<void> _deleteDeck(Map<String, dynamic> d) async {
    if (!await _confirm('Delete "${d['name'] ?? 'deck'}"?',
        'All cards in this deck will also be deleted.')) return;
    try {
      await ref.read(apiServiceProvider).delete('/study/decks/${d['id']}');
      _snack('Deck deleted');
      _loadContent();
    } catch (e) {
      _snack('Delete failed: $e', bg: _mTerra);
    }
  }

  Future<void> _deleteQuiz(Map<String, dynamic> q) async {
    final source = (q['_source'] as String?) ?? 'quiz';
    final isGenerated = source == 'generated_quiz';
    final title = isGenerated
      ? 'Delete this generated quiz?'
      : 'Delete this quiz result?';
    final body = isGenerated
      ? 'This auto-generated quiz and its question set will be permanently removed.'
      : 'The quiz history entry will be permanently removed.';
    if (!await _confirm(title, body)) return;
    try {
      final path = isGenerated
        ? '/study/generated-quizzes/${q['id']}'
        : '/study/quizzes/${q['id']}';
      await ref.read(apiServiceProvider).delete(path);
      _snack('Quiz deleted');
      _loadContent();
    } catch (e) {
      _snack('Delete failed: $e', bg: _mTerra);
    }
  }

  Future<void> _createTopic() async {
    if (_subject == null) return;
    final nameCtrl = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New topic',
              style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 4),
            Text('Add a topic to ${_subject!.name}',
              style: GoogleFonts.nunito(fontSize: 12, color: _brownSoft)),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: GoogleFonts.nunito(fontSize: 14, color: _brown),
              decoration: InputDecoration(
                hintText: 'e.g. Photosynthesis',
                hintStyle: GoogleFonts.nunito(fontSize: 13, color: _brownSoft),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 1.2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _oliveDk, width: 1.5)),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _PillBtn(
                label: 'cancel', fill: _cream,
                onTap: () => Navigator.pop(ctx, false))),
              const SizedBox(width: 8),
              Expanded(child: _PillBtn(
                label: 'create', fill: _olive, textColor: Colors.white,
                onTap: () => Navigator.pop(ctx, true))),
            ]),
          ]),
        ),
      ),
    );
    if (proceed != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(apiServiceProvider).post('/study/topics', data: {
        'subject_id': _subject!.id,
        'name': nameCtrl.text.trim(),
      });
      _snack('Topic added');
      _loadContent();
    } catch (e) {
      _snack('Create failed: $e', bg: _mTerra);
    }
  }

  Future<void> _renameTopic(Map<String, dynamic> t) async {
    final ctrl = TextEditingController(text: (t['name'] as String?) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rename topic',
              style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.nunito(fontSize: 14, color: _brown),
              decoration: InputDecoration(
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 1.2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _outline, width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _oliveDk, width: 1.5)),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _PillBtn(
                label: 'cancel', fill: _cream,
                onTap: () => Navigator.pop(ctx, false))),
              const SizedBox(width: 8),
              Expanded(child: _PillBtn(
                label: 'save', fill: _olive, textColor: Colors.white,
                onTap: () => Navigator.pop(ctx, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      await ref.read(apiServiceProvider).put('/study/topics/${t['id']}', data: {
        'name': ctrl.text.trim(),
      });
      _snack('Topic renamed');
      _loadContent();
    } catch (e) {
      _snack('Rename failed: $e', bg: _mTerra);
    }
  }

  Future<void> _deleteTopic(Map<String, dynamic> t) async {
    if (!await _confirm('Delete topic "${t['name']}"?',
        'This unlinks the topic from all materials, sessions, quizzes and decks.')) return;
    try {
      await ref.read(apiServiceProvider).delete('/study/topics/${t['id']}');
      _snack('Topic deleted');
      _loadContent();
    } catch (e) {
      _snack('Delete failed: $e', bg: _mTerra);
    }
  }

  //
  // Re-runs topic extraction over every material already attached
  // to this subject. Uploads already trigger extraction automatically
  // (server-side in `/materials` and `/materials/upload`), so this button
  // is primarily a backfill affordance for:
  //   • materials created before auto-extract shipped
  //   • the occasional case where extraction returned [] (e.g. no key, rate
  //     limit, flaky provider) and the user wants to retry
  //
  // The endpoint is idempotent — names that already exist as Topic rows
  // are deduped via `resolve_topics_from_names` on the server, so
  // spamming this button does no harm.
  Future<void> _autoExtractTopicsForSubject() async {
    if (_subject == null) return;
    if (_materials.isEmpty) {
      _snack('Upload a note first — topics are extracted from your material.');
      return;
    }
    final proceed = await _confirm(
      'Auto-extract topics?',
      'We'll scan ${_materials.length} material${_materials.length == 1 ? '' : 's'} '
      'and propose topic names. Existing topics are preserved — matching '
      'names are deduped. You can rename or delete anything afterwards.',
    );
    if (!proceed) return;

    final api = ref.read(apiServiceProvider);
    int succeeded = 0, failed = 0, totalAdded = 0;

    _snack('Extracting topics… this can take a few seconds per note.');
    for (final m in _materials) {
      final mid = m['id']?.toString();
      if (mid == null || mid.isEmpty) continue;
      try {
        final res = await api.post('/study/materials/$mid/extract-topics');
        final data = (res.data is Map<String, dynamic>)
            ? res.data as Map<String, dynamic>
            : <String, dynamic>{};
        final added = (data['added_count'] is int)
            ? data['added_count'] as int
            : int.tryParse(data['added_count']?.toString() ?? '') ?? 0;
        totalAdded += added;
        succeeded++;
      } catch (e) {
        debugPrint('[auto-extract] material=$mid failed: $e');
        failed++;
      }
    }

    if (!mounted) return;
    if (succeeded == 0) {
      _snack('Extraction failed for all materials. Check your API key.',
          bg: _mTerra);
    } else if (totalAdded == 0) {
      _snack('Done — no new topics (already up to date).');
    } else {
      final word = totalAdded == 1 ? 'topic' : 'topics';
      final tail = failed > 0 ? ' ($failed skipped)' : '';
      _snack('Added $totalAdded new $word across $succeeded material'
          '${succeeded == 1 ? '' : 's'}$tail.');
    }
    _loadContent();
  }

  //
  // Layout language:
  //   The page centers its content inside a `contentW` column, matching
  //   sibling screens (subjects_screen / flashcard_screen / analytics).
  //   This gives generous left/right breathing room on wide viewports and
  //   caps the max column width so line-lengths stay readable on large
  //   displays. Inner tab bodies intentionally use zero horizontal
  //   padding — the contentW wrapper is the single source of truth for
  //   horizontal spacing so nothing double-pads.
  @override
  Widget build(BuildContext context) {
    final sub = _subject;
    final accent = sub?.accent ?? _mSage;
    final screenW = MediaQuery.of(context).size.width;
    // Slightly wider than sibling screens so a subject with dense content
    // (stats grid + recent activity feed + topic cards) doesn't leave
    // huge empty gutters on a wide-desktop viewport.
    final contentW = (screenW * 0.94).clamp(360.0, 1500.0);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _ombre1,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_ombre1, _ombre4])),
        child: CustomPaint(
          painter: _PawPrintBg(),
          child: SafeArea(
            child: Center(
              child: SizedBox(
                width: contentW,
                // Inner 16px horizontal gutter so the visible side spacing
                // on Subject Detail matches Quiz Hub one-for-one (same
                // contentW + same inner padding). This was the missing
                // 16px that made this page look tighter than siblings.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                  // Top breathing room — matches "My Subjects" / analytics
                  // top-of-page spacing so the header isn't glued to the
                  // notch / window chrome. Bumped to 40 so the Bitroad
                  // heading gets real air above it instead of feeling
                  // stuck to the top edge on desktop viewports.
                  const SizedBox(height: 40),
                  _header(sub),
                  const SizedBox(height: 16),
                  _tabBar(accent),
                  const SizedBox(height: 16),
                  Expanded(child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _OverviewTab(
                        loading: _loadingData,
                        error: _error,
                        materialsCount: _materials.length,
                        sessionsCount:  _sessions.length,
                        decksCount:     _decks.length,
                        quizzesCount:   _quizzes.length,
                        topicsCount:    _topics.length,
                        recentMaterials: _materials.take(5).toList(),
                        recentSessions:  _sessions.take(5).toList(),
                        recentQuizzes:   _quizzes.take(5).toList(),
                        subject: sub,
                        onRefresh: _loadContent,
                        onOpenMaterial: (m) => _openMaterialDetail(m),
                        onOpenDeck: _openDeck,
                        onOpenQuiz: _openQuizResult,
                      ),
                      _TopicsTab(
                        loading: _loadingData,
                        topics: _topics,
                        materialsCount: _materials.length,
                        subjectAccent: accent,
                        onCreate: _createTopic,
                        onRename: _renameTopic,
                        onDelete: _deleteTopic,
                        onOpen: _showTopicDetail,
                        onAutoExtract: _autoExtractTopicsForSubject,
                      ),
                      _ContentTab(
                        loading: _loadingData,
                        materials: _materials,
                        decks: _decks,
                        quizzes: _quizzes,
                        subjectAccent: accent,
                        onUpload: _uploadMaterial,
                        onCreateDeck: _createDeck,
                        onDeleteMaterial: _deleteMaterial,
                        onDeleteDeck: _deleteDeck,
                        onDeleteQuiz: _deleteQuiz,
                        onOpenMaterial: _openMaterialDetail,
                        onOpenDeck: _openDeck,
                        onOpenQuiz: _openQuizResult,
                      ),
                    ],
                  )),
                ]),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(_SubjectSummary? s) {
    final accent = s?.accent ?? _mSage;
    final name = s?.name ?? (widget.initialSubjectName ?? 'Subject');
    final code = s?.code ?? '';
    final prog = s == null
      ? 0.0
      : (s.targetProf <= 0 ? 0.0 : (s.currentProf / s.targetProf).clamp(0.0, 1.0));
    // Header padding is ZERO horizontal — the outer contentW wrapper
    // owns horizontal breathing room so we don't double-pad.
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
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
          ),
          const SizedBox(width: 16),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _outline, width: 1.6),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.55),
                offset: const Offset(2.5, 2.5), blurRadius: 0)]),
            child: Icon(s?.icon ?? Icons.menu_book_rounded, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            // Page title — Bitroad, matching the "My Subjects" heading on
            // the sibling Subjects screen. 26px preserves one-line fit even
            // for long subject names (we still ellipsize as a safeguard).
            Text(name,
              style: TextStyle(
                fontFamily: 'Bitroad', fontSize: 26,
                color: _brown, height: 1.15),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            if (code.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(code.toUpperCase(),
                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w900,
                  letterSpacing: 1.4, color: accent)),
            ),
          ])),
          const SizedBox(width: 12),
          _HeaderIconBtn(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onTap: _loadAll,
          ),
        ]),
        const SizedBox(height: 14),
        // Proficiency strip — inline, compact, not inside a card.
        if (s != null) Row(children: [
          Icon(Icons.trending_up_rounded, size: 14, color: accent),
          const SizedBox(width: 6),
          Text('PROFICIENCY',
            style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w900,
              letterSpacing: 1.6, color: _brownLt)),
          const SizedBox(width: 10),
          Expanded(child: Stack(children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _outline.withOpacity(0.3), width: 1)),
            ),
            FractionallySizedBox(
              widthFactor: prog.toDouble().clamp(0.0, 1.0),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                    colors: [accent.withOpacity(0.85), accent]),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _outline.withOpacity(0.38), width: 1)),
              ),
            ),
          ])),
          const SizedBox(width: 10),
          Text('${s.currentProf.round()} / ${s.targetProf.round()}%',
            style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: _brownLt)),
        ]),
      ]),
    );
  }

  // No horizontal padding — outer contentW wrapper provides side margins.
  Widget _tabBar(Color accent) {
    return AnimatedBuilder(
      animation: _tabCtrl,
      builder: (_, __) {
        return Row(children: [
          _tabPill('Overview', 0, accent),
          const SizedBox(width: 16),
          _tabPill('Topics',   1, accent),
          const SizedBox(width: 16),
          _tabPill('Content',  2, accent),
        ]);
      },
    );
  }

  Widget _tabPill(String label, int index, Color accent) {
    final active = _tabCtrl.index == index;
    return Expanded(child: GestureDetector(
      onTap: () => _tabCtrl.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? accent : _cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? _outline : _outline.withOpacity(0.32),
            width: 1.6),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(active ? 0.4 : 0.22),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Center(child: Text(label.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4,
            color: active ? Colors.white : _brown))),
      ),
    ));
  }

  void _openDeck(Map<String, dynamic> d) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FlashcardScreen(initialDeckId: d['id']?.toString()),
    ));
  }

  void _openQuizResult(Map<String, dynamic> q) {
    // Branch on source so we're ready to deep-link differently in future
    // (e.g. generated quizzes may open directly to the attempt flow
    // while completed quizzes open a review screen).
    final source = (q['_source'] as String?) ?? 'quiz';
    switch (source) {
      case 'generated_quiz':
      case 'quiz':
      default:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const QuizScreen(),
        ));
        break;
    }
  }

  void _openMaterialDetail(Map<String, dynamic> m) {
    final content = (m['content'] as String?) ?? '';
    final topics = ((m['topics'] as List?) ?? const []).map((e) => e.toString()).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _outline.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 6),
              child: Row(children: [
                Expanded(child: Text((m['title'] as String?) ?? 'Untitled',
                  style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown),
                  overflow: TextOverflow.ellipsis, maxLines: 2)),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: _red, size: 22),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _deleteMaterial(m);
                  },
                ),
              ]),
            ),
            if (topics.isNotEmpty) Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in topics)
                  _MiniPill(icon: Icons.label_rounded, label: t, color: _mLav),
              ]),
            ),
            const Divider(height: 1, indent: 18, endIndent: 18),
            Expanded(child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(18),
              child: Text(content.isEmpty ? '(no content)' : content,
                style: GoogleFonts.nunito(fontSize: 14, height: 1.6, color: _brown)),
            )),
          ]),
        ),
      ),
    );
  }
}

//  Shared card foundation — matches sibling `_sectionCard`.
//  Public to this file only.
Widget _tintedCard({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
  Color? tint,
}) {
  final hasTint = tint != null;
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: hasTint ? null : _cardFill.withOpacity(0.94),
      gradient: hasTint
          ? LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                tint.withOpacity(0.35),
                _cardFill.withOpacity(0.72),
              ])
          : null,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: hasTint ? tint.withOpacity(0.42) : _outline.withOpacity(0.32),
        width: 1.8),
      boxShadow: [BoxShadow(
        color: hasTint ? tint.withOpacity(0.26) : _outline.withOpacity(0.24),
        offset: const Offset(3, 3), blurRadius: 0)]),
    child: child,
  );
}

Widget _sectionHeaderPill({
  required Color dotColor,
  required String label,
  String? subtitle,
  Widget? trailing,
}) {
  return Row(children: [
    Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
    const SizedBox(width: 10),
    Text(label.toUpperCase(),
      style: GoogleFonts.nunito(
        fontSize: 13, fontWeight: FontWeight.w900,
        color: dotColor, letterSpacing: 1.8)),
    if (subtitle != null) ...[
      const SizedBox(width: 10),
      Flexible(child: Text(subtitle,
        style: GoogleFonts.gaegu(
          fontSize: 15, fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic, color: _brownLt),
        overflow: TextOverflow.ellipsis, maxLines: 1)),
    ],
    if (trailing != null) ...[
      const Spacer(),
      trailing,
    ],
  ]);
}

//  OVERVIEW TAB  (activity summary — fits one viewport)
class _OverviewTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final int materialsCount;
  final int sessionsCount;
  final int decksCount;
  final int quizzesCount;
  final int topicsCount;
  final List<Map<String, dynamic>> recentMaterials;
  final List<Map<String, dynamic>> recentSessions;
  final List<Map<String, dynamic>> recentQuizzes;
  final _SubjectSummary? subject;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onOpenMaterial;
  final void Function(Map<String, dynamic>) onOpenDeck;
  final void Function(Map<String, dynamic>) onOpenQuiz;

  const _OverviewTab({
    required this.loading,
    required this.error,
    required this.materialsCount,
    required this.sessionsCount,
    required this.decksCount,
    required this.quizzesCount,
    required this.topicsCount,
    required this.recentMaterials,
    required this.recentSessions,
    required this.recentQuizzes,
    required this.subject,
    required this.onRefresh,
    required this.onOpenMaterial,
    required this.onOpenDeck,
    required this.onOpenQuiz,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: _oliveDk, strokeWidth: 2.5));
    }
    if (error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: _red, size: 36),
          const SizedBox(height: 10),
          Text(error!, textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 13, color: _brownSoft)),
          const SizedBox(height: 12),
          _PillBtn(label: 'retry', fill: _olive, textColor: Colors.white, onTap: onRefresh),
        ]),
      ));
    }

    final isEmpty = materialsCount == 0 && sessionsCount == 0
      && quizzesCount == 0 && decksCount == 0 && topicsCount == 0;

    // Merge into a single unified activity feed — newest first, top 5.
    final feed = <_ActivityItem>[];
    for (final m in recentMaterials) {
      final dt = _activityDate(m);
      feed.add(_ActivityItem(
        type: _ActivityType.material,
        title: (m['title'] as String?) ?? 'Untitled',
        subtitle: _materialSubtitle(m),
        date: dt,
        iconData: _iconForSource((m['source_type'] as String?) ?? 'typed'),
        tint: _mSlate,
        payload: m,
        onTap: () => onOpenMaterial(m),
      ));
    }
    for (final s in recentSessions) {
      final dt = _activityDate(s);
      feed.add(_ActivityItem(
        type: _ActivityType.session,
        title: (s['title'] as String?) ?? 'Study session',
        subtitle: _sessionSubtitle(s),
        date: dt,
        iconData: Icons.schedule_rounded,
        tint: _mButter,
        payload: s,
      ));
    }
    for (final q in recentQuizzes) {
      final dt = _activityDate(q);
      final source = (q['_source'] as String?) ?? 'quiz';
      feed.add(_ActivityItem(
        type: _ActivityType.quiz,
        title: (q['title'] as String?) ?? 'Quiz',
        subtitle: _quizSubtitle(q),
        date: dt,
        iconData: source == 'generated_quiz'
          ? Icons.auto_awesome_rounded
          : Icons.quiz_rounded,
        tint: source == 'generated_quiz' ? _mLav : _mSage,
        payload: q,
        onTap: () => onOpenQuiz(q),
      ));
    }
    feed.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    final top = feed.take(5).toList();

    return RefreshIndicator(
      color: _oliveDk,
      onRefresh: onRefresh,
      // Zero horizontal padding — the outer contentW column already provides
      // left/right margins. Bottom padding 20 keeps the last card off the
      // screen edge without leaving a dead zone.
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _statsGrid(),
          const SizedBox(height: 18),
          if (isEmpty) _emptyState() else _recentActivityCard(top),
        ]),
      ),
    );
  }

  String _materialSubtitle(Map<String, dynamic> m) {
    final words = (m['word_count'] is int) ? m['word_count'] as int
      : int.tryParse(m['word_count']?.toString() ?? '') ?? 0;
    final src = (m['source_type'] as String?) ?? 'typed';
    return '$words words · ${_prettySource(src)}';
  }

  String _sessionSubtitle(Map<String, dynamic> s) {
    final mins = (s['duration_minutes'] is int) ? s['duration_minutes'] as int
      : int.tryParse(s['duration_minutes']?.toString() ?? '') ?? 0;
    return '$mins min session';
  }

  String _quizSubtitle(Map<String, dynamic> q) {
    final source = (q['_source'] as String?) ?? 'quiz';
    if (source == 'generated_quiz') {
      final qc = (q['question_count'] is int) ? q['question_count'] as int
        : (q['total_questions'] is int) ? q['total_questions'] as int
        : int.tryParse(q['question_count']?.toString()
          ?? q['total_questions']?.toString() ?? '') ?? 0;
      return qc > 0 ? 'Generated · $qc questions' : 'Generated quiz';
    }
    final pct = _asDouble(q['percentage']) ?? 0;
    return 'Scored ${pct.round()}%';
  }

  String _prettySource(String s) {
    switch (s) {
      case 'pdf_upload':     return 'PDF';
      case 'image_upload':   return 'Image';
      case 'pasted':         return 'Pasted';
      case 'session_import': return 'Session';
      case 'typed':          return 'Typed';
      default:               return s;
    }
  }

  Widget _statsGrid() {
    final cells = [
      _StatCell(label: 'Topics',  value: '$topicsCount',    icon: Icons.label_rounded,       tint: _mLav),
      _StatCell(label: 'Notes',   value: '$materialsCount', icon: Icons.description_rounded, tint: _mSlate),
      _StatCell(label: 'Decks',   value: '$decksCount',     icon: Icons.style_rounded,       tint: _mBlush),
      _StatCell(label: 'Quizzes', value: '$quizzesCount',   icon: Icons.quiz_rounded,        tint: _mSage),
    ];
    return Row(children: [
      for (int i = 0; i < cells.length; i++) ...[
        if (i > 0) const SizedBox(width: 16),
        Expanded(child: cells[i]),
      ],
    ]);
  }

  Widget _recentActivityCard(List<_ActivityItem> items) {
    return _tintedCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeaderPill(
          dotColor: _oliveDk,
          label: 'Recent activity',
          subtitle: "what you've been up to",
          trailing: items.isEmpty ? null : Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1)),
            child: Text('${items.length}',
              style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w900, color: _brownLt)),
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text('Nothing recent yet — upload notes, start a session, or generate a quiz.',
              style: GoogleFonts.nunito(
                fontSize: 12, color: _brownSoft, height: 1.4)),
          )
        else
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(
              height: 1, thickness: 1,
              color: _outline.withOpacity(0.12)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _ActivityRow(item: items[i]),
            ),
          ],
      ]),
    );
  }

  Widget _emptyState() {
    return _tintedCard(
      tint: _mButter,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: _mButter, shape: BoxShape.circle,
            border: Border.all(color: _outline, width: 1.4),
            boxShadow: [BoxShadow(
              color: _outline.withOpacity(0.3),
              offset: const Offset(2, 2), blurRadius: 0)]),
          child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 12),
        Text('Nothing here yet',
          style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 4),
        Text('Upload notes, start a session, or generate quizzes to fill this subject.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 12, color: _brownSoft, height: 1.4)),
      ]),
    );
  }
}

enum _ActivityType { material, session, quiz }

class _ActivityItem {
  final _ActivityType type;
  final String title;
  final String subtitle;
  final DateTime? date;
  final IconData iconData;
  final Color tint;
  final Map<String, dynamic> payload;
  final VoidCallback? onTap;
  _ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.iconData,
    required this.tint,
    required this.payload,
    this.onTap,
  });
}

class _ActivityRow extends StatelessWidget {
  final _ActivityItem item;
  const _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final source = (item.payload['_source'] as String?) ?? '';
    final isGenerated = source == 'generated_quiz';
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: item.tint,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _outline.withOpacity(0.35), width: 1.2)),
          child: Icon(item.iconData, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(item.title,
              style: GoogleFonts.gaegu(
                fontSize: 15, fontWeight: FontWeight.w700, color: _brown),
              overflow: TextOverflow.ellipsis, maxLines: 1)),
            if (item.type == _ActivityType.quiz && isGenerated) ...[
              const SizedBox(width: 6),
              _TagPill(label: 'Auto', color: _mLav),
            ],
          ]),
          Row(children: [
            Flexible(child: Text(item.subtitle,
              style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w600, color: _brownSoft),
              overflow: TextOverflow.ellipsis, maxLines: 1)),
          ]),
        ])),
        if (item.date != null) Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(_fmtDate(item.date!),
            style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w700, color: _brownLt)),
        ),
      ]),
    );
  }
}

//  COMPACT STAT CELL (tinted — matches sibling design)
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  const _StatCell({required this.label, required this.value,
    required this.icon, required this.tint});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            tint.withOpacity(0.35),
            _cardFill.withOpacity(0.72),
          ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withOpacity(0.45), width: 1.6),
        boxShadow: [BoxShadow(
          color: tint.withOpacity(0.3),
          offset: const Offset(2.5, 2.5), blurRadius: 0)],
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: tint,
            shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.38), width: 1.2),
            boxShadow: [BoxShadow(
              color: _outline.withOpacity(0.25),
              offset: const Offset(1.5, 1.5), blurRadius: 0)]),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
              style: GoogleFonts.gaegu(
                fontSize: 24, fontWeight: FontWeight.w700, color: _brown, height: 1.0)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w900,
                letterSpacing: 1.2, color: _brownLt)),
          ],
        )),
      ]),
    );
  }
}

//  TOPICS TAB
class _TopicsTab extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> topics;
  // Number of materials attached; disables extract pill when zero.
  final int materialsCount;
  final Color subjectAccent;
  final Future<void> Function() onCreate;
  final Future<void> Function(Map<String, dynamic>) onRename;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  /// Tap handler — opens the topic-detail bottom sheet showing every
  /// piece of content linked to the topic.
  final void Function(Map<String, dynamic>) onOpen;
  // Re-runs topic extraction across all materials; server dedupes matches.
  final Future<void> Function() onAutoExtract;
  const _TopicsTab({
    required this.loading,
    required this.topics,
    required this.materialsCount,
    required this.subjectAccent,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    required this.onOpen,
    required this.onAutoExtract,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: _oliveDk, strokeWidth: 2.5));
    }
    // Zero horizontal padding — outer contentW wrapper handles side margins.
    final canAutoExtract = materialsCount > 0;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 14),
        child: _tintedCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: _sectionHeaderPill(
            dotColor: subjectAccent,
            label: '${topics.length} topic${topics.length == 1 ? '' : 's'}',
            subtitle: canAutoExtract
                ? 'Scans your notes — editable after'
                : 'upload a note to auto-extract',
            // Two-button trailing: Auto-extract + manual add. Wrap lets
            // this fold gracefully on narrower viewports.
            trailing: Wrap(spacing: 6, runSpacing: 6, children: [
              _PillBtn(
                label: '✨ Auto-extract',
                fill: canAutoExtract ? _mLav : _cream,
                textColor: canAutoExtract ? Colors.white : _brownSoft,
                onTap: () => onAutoExtract(),
              ),
              _PillBtn(
                label: '+ add', fill: _olive, textColor: Colors.white,
                onTap: () => onCreate(),
              ),
            ]),
          ),
        ),
      ),
      Expanded(child: topics.isEmpty
        ? _topicEmpty()
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => _topicCard(topics[i]),
          ),
      ),
    ]);
  }

  Widget _topicEmpty() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: _tintedCard(
        tint: _mLav,
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _mLav, shape: BoxShape.circle,
              border: Border.all(color: _outline, width: 1.4),
              boxShadow: [BoxShadow(
                color: _outline.withOpacity(0.3),
                offset: const Offset(2, 2), blurRadius: 0)]),
            child: const Icon(Icons.label_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text('No topics yet',
            style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(height: 4),
          Text(
            materialsCount > 0
              ? 'Tap "Auto-extract" — We'll scan your $materialsCount note${materialsCount == 1 ? '' : 's'} and propose topic names you can edit.'
              : 'Topics auto-populate when you upload notes. You can also add them manually any time.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 12, color: _brownSoft, height: 1.4)),
          const SizedBox(height: 14),
          // Primary action depends on whether there's source material.
          // With materials → Auto-extract is the headline CTA; manual add
          // is a secondary chip below. Without materials → only manual
          // add is shown (no point pretending Auto-extract works on nothing).
          if (materialsCount > 0) ...[
            _PillBtn(
              label: '✨ Auto-extract topics',
              fill: _mLav, textColor: Colors.white,
              onTap: () => onAutoExtract(),
            ),
            const SizedBox(height: 8),
            _PillBtn(
              label: '+ add manually', fill: _cream, textColor: _brown,
              onTap: () => onCreate()),
          ] else
            _PillBtn(
              label: '+ add topic', fill: _olive, textColor: Colors.white,
              onTap: () => onCreate()),
        ]),
      ),
    ));
  }

  Widget _topicCard(Map<String, dynamic> t) {
    final name = (t['name'] as String?) ?? 'Topic';
    final colorHex = (t['color'] as String?) ?? '#C9B8D9';
    final accent = _hexToColor(colorHex);
    final materialCount = (t['material_count'] is int) ? t['material_count'] as int
      : int.tryParse(t['material_count']?.toString() ?? '') ?? 0;
    final quizCount = (t['quiz_count'] is int) ? t['quiz_count'] as int
      : int.tryParse(t['quiz_count']?.toString() ?? '') ?? 0;
    final deckCount = (t['deck_count'] is int) ? t['deck_count'] as int
      : int.tryParse(t['deck_count']?.toString() ?? '') ?? 0;
    final mastery = _asDouble(t['mastery']) ?? 0;

    // Outer GestureDetector makes the whole pill tappable — the rename /
    // delete IconButtons inside swallow their own taps, so this doesn't
    // hijack those actions.
    return GestureDetector(
      onTap: () => onOpen(t),
      behavior: HitTestBehavior.opaque,
      child: _tintedCard(
      tint: accent,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 10, height: 28,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _outline.withOpacity(0.5), width: 1)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name,
            style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w700, color: _brown),
            overflow: TextOverflow.ellipsis, maxLines: 1)),
          IconButton(
            tooltip: 'Rename',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_rounded, size: 18, color: _brownLt),
            onPressed: () => onRename(t),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: _red),
            onPressed: () => onDelete(t),
          ),
        ]),
        if (materialCount > 0 || quizCount > 0 || deckCount > 0) Padding(
          padding: const EdgeInsets.only(top: 4, left: 20),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            if (materialCount > 0) _MiniPill(icon: Icons.description_rounded,
              label: '$materialCount note${materialCount == 1 ? '' : 's'}', color: _mSlate),
            if (deckCount > 0) _MiniPill(icon: Icons.style_rounded,
              label: '$deckCount deck${deckCount == 1 ? '' : 's'}', color: _mBlush),
            if (quizCount > 0) _MiniPill(icon: Icons.quiz_rounded,
              label: '$quizCount quiz${quizCount == 1 ? '' : 'zes'}', color: subjectAccent),
          ]),
        ),
        if (mastery > 0) Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 10, 0),
          child: Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (mastery / 100).clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: _cream,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            )),
            const SizedBox(width: 8),
            Text('${mastery.round()}%',
              style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w800, color: _brownLt)),
          ]),
        ),
      ]),
      ),
    );
  }
}

//  CONTENT TAB  (materials, decks, quizzes — full list with actions)
class _ContentTab extends StatefulWidget {
  final bool loading;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> decks;
  final List<Map<String, dynamic>> quizzes;
  final Color subjectAccent;
  final Future<void> Function() onUpload;
  final Future<void> Function() onCreateDeck;
  final Future<void> Function(Map<String, dynamic>) onDeleteMaterial;
  final Future<void> Function(Map<String, dynamic>) onDeleteDeck;
  final Future<void> Function(Map<String, dynamic>) onDeleteQuiz;
  final void Function(Map<String, dynamic>) onOpenMaterial;
  final void Function(Map<String, dynamic>) onOpenDeck;
  final void Function(Map<String, dynamic>) onOpenQuiz;
  const _ContentTab({
    required this.loading,
    required this.materials,
    required this.decks,
    required this.quizzes,
    required this.subjectAccent,
    required this.onUpload,
    required this.onCreateDeck,
    required this.onDeleteMaterial,
    required this.onDeleteDeck,
    required this.onDeleteQuiz,
    required this.onOpenMaterial,
    required this.onOpenDeck,
    required this.onOpenQuiz,
  });
  @override
  State<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<_ContentTab> {
  int _filter = 0; // 0 = all, 1 = materials, 2 = decks, 3 = quizzes

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Center(child: CircularProgressIndicator(color: _oliveDk, strokeWidth: 2.5));
    }
    final isEmpty = widget.materials.isEmpty && widget.decks.isEmpty && widget.quizzes.isEmpty;
    // Zero horizontal padding — outer contentW wrapper handles side margins.
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 14),
        child: _tintedCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(children: [
            Expanded(child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip('all', 0),
                const SizedBox(width: 10),
                _filterChip('notes (${widget.materials.length})', 1),
                const SizedBox(width: 10),
                _filterChip('decks (${widget.decks.length})', 2),
                const SizedBox(width: 10),
                _filterChip('quizzes (${widget.quizzes.length})', 3),
              ]),
            )),
            const SizedBox(width: 8),
            _PillBtn(label: '+ upload', fill: widget.subjectAccent, textColor: Colors.white,
              onTap: () => widget.onUpload()),
            const SizedBox(width: 8),
            // "+ deck" creates a flashcard deck already scoped to this
            // subject — no Flashcards-page side-trip required. Kept
            // visually secondary (cream fill, brown text) so "+ upload"
            // stays the primary CTA.
            _PillBtn(label: '+ deck', fill: _cream, textColor: _brown,
              onTap: () => widget.onCreateDeck()),
          ]),
        ),
      ),
      Expanded(child: isEmpty
        ? _empty()
        : ListView(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
            children: [
              if ((_filter == 0 || _filter == 1) && widget.materials.isNotEmpty) ...[
                _sectionHeader(Icons.description_rounded, 'NOTES', widget.materials.length, _mSlate),
                const SizedBox(height: 8),
                for (final m in widget.materials)
                  Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: _MaterialRow(
                      mat: m,
                      onTap: () => widget.onOpenMaterial(m),
                      onDelete: () => widget.onDeleteMaterial(m),
                    )),
                const SizedBox(height: 10),
              ],
              if ((_filter == 0 || _filter == 2) && widget.decks.isNotEmpty) ...[
                _sectionHeader(Icons.style_rounded, 'FLASHCARD DECKS', widget.decks.length, _mBlush),
                const SizedBox(height: 8),
                for (final d in widget.decks)
                  Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: _DeckRow(
                      deck: d,
                      onTap: () => widget.onOpenDeck(d),
                      onDelete: () => widget.onDeleteDeck(d),
                    )),
                const SizedBox(height: 10),
              ],
              if ((_filter == 0 || _filter == 3) && widget.quizzes.isNotEmpty) ...[
                _sectionHeader(Icons.quiz_rounded, 'QUIZZES', widget.quizzes.length, _olive),
                const SizedBox(height: 8),
                for (final q in widget.quizzes)
                  Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: _QuizRow(
                      quiz: q,
                      onTap: () => widget.onOpenQuiz(q),
                      onDelete: () => widget.onDeleteQuiz(q),
                    )),
              ],
            ],
          ),
      ),
    ]);
  }

  Widget _filterChip(String label, int value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  widget.subjectAccent,
                  widget.subjectAccent.withOpacity(0.75),
                ])
            : null,
          color: active ? null : _cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? _outline : _outline.withOpacity(0.32),
            width: 1.4),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(active ? 0.38 : 0.18),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Text(label,
          style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.3,
            color: active ? Colors.white : _brown)),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label, int count, Color dotColor) => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 2, left: 2),
    child: _sectionHeaderPill(
      dotColor: dotColor,
      label: label,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _outline.withOpacity(0.3), width: 1)),
        child: Text('$count',
          style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w900, color: _brownLt)),
      ),
    ),
  );

  Widget _empty() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: _tintedCard(
        tint: widget.subjectAccent,
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: widget.subjectAccent, shape: BoxShape.circle,
              border: Border.all(color: _outline, width: 1.4),
              boxShadow: [BoxShadow(
                color: _outline.withOpacity(0.3),
                offset: const Offset(2, 2), blurRadius: 0)]),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text('No content yet',
            style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(height: 4),
          Text('Upload your first notes to start building quizzes and flashcards.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 12, color: _brownSoft, height: 1.4)),
          const SizedBox(height: 14),
          _PillBtn(label: '+ upload', fill: _olive, textColor: Colors.white,
            onTap: () => widget.onUpload()),
        ]),
      ),
    ));
  }
}

class _MaterialRow extends StatelessWidget {
  final Map<String, dynamic> mat;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _MaterialRow({required this.mat, required this.onTap, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final title = (mat['title'] as String?) ?? 'Untitled';
    final src = (mat['source_type'] as String?) ?? 'typed';
    final words = (mat['word_count'] is int) ? mat['word_count'] as int
      : int.tryParse(mat['word_count']?.toString() ?? '') ?? 0;
    final topics = ((mat['topics'] as List?) ?? const []).map((e) => e.toString()).toList();
    final created = DateTime.tryParse(mat['created_at']?.toString() ?? '');
    return GestureDetector(
      onTap: onTap,
      child: _tintedCard(
        tint: _mSlate,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _mSlate,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.45), width: 1.2),
              boxShadow: [BoxShadow(
                color: _outline.withOpacity(0.22),
                offset: const Offset(1.5, 1.5), blurRadius: 0)]),
            child: Icon(_iconForSource(src), size: 18, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            Row(children: [
              Text('$words words',
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brownSoft)),
              if (created != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.schedule_rounded, size: 10, color: _brownSoft),
                const SizedBox(width: 2),
                Text(_fmtDate(created),
                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brownSoft)),
              ],
            ]),
            if (topics.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 4, runSpacing: 3, children: [
                for (final t in topics.take(4))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _mLav.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: _outline.withOpacity(0.2), width: 1)),
                    child: Text(t,
                      style: GoogleFonts.nunito(
                        fontSize: 9, fontWeight: FontWeight.w700, color: _brownLt)),
                  ),
              ]),
            ),
          ])),
          _TrashBtn(onTap: onDelete),
        ]),
      ),
    );
  }
}

class _DeckRow extends StatelessWidget {
  final Map<String, dynamic> deck;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _DeckRow({required this.deck, required this.onTap, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final name = (deck['name'] as String?) ?? 'Deck';
    final count = (deck['total_cards'] is int) ? deck['total_cards'] as int
      : (deck['card_count'] is int) ? deck['card_count'] as int
      : int.tryParse(deck['total_cards']?.toString() ?? deck['card_count']?.toString() ?? '') ?? 0;
    final updated = DateTime.tryParse(deck['updated_at']?.toString() ?? '');
    return GestureDetector(
      onTap: onTap,
      child: _tintedCard(
        tint: _mBlush,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _mBlush,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.45), width: 1.2),
              boxShadow: [BoxShadow(
                color: _outline.withOpacity(0.22),
                offset: const Offset(1.5, 1.5), blurRadius: 0)]),
            child: const Icon(Icons.style_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
              style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            Row(children: [
              Text('$count card${count == 1 ? '' : 's'}',
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brownSoft)),
              if (updated != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.schedule_rounded, size: 10, color: _brownSoft),
                const SizedBox(width: 2),
                Text(_fmtDate(updated),
                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brownSoft)),
              ],
            ]),
          ])),
          _TrashBtn(onTap: onDelete),
        ]),
      ),
    );
  }
}

class _QuizRow extends StatelessWidget {
  final Map<String, dynamic> quiz;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _QuizRow({required this.quiz, required this.onTap, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final source = (quiz['_source'] as String?) ?? 'quiz';
    final isGenerated = source == 'generated_quiz';
    final title = (quiz['title'] as String?) ?? 'Quiz';
    final date = DateTime.tryParse(
      quiz['date_taken']?.toString() ?? quiz['created_at']?.toString() ?? '');
    final topics = ((quiz['topics_tested'] as List?) ?? const []).map((e) => e.toString()).toList();
    final pct = _asDouble(quiz['percentage']) ?? 0;
    final int qCount = (quiz['question_count'] is int) ? quiz['question_count'] as int
      : (quiz['total_questions'] is int) ? quiz['total_questions'] as int
      : int.tryParse(quiz['question_count']?.toString()
        ?? quiz['total_questions']?.toString() ?? '') ?? 0;

    final iconTint = isGenerated ? _mLav : _mSage;
    final iconData = isGenerated ? Icons.auto_awesome_rounded : Icons.quiz_rounded;

    return GestureDetector(
      onTap: onTap,
      child: _tintedCard(
        tint: iconTint,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconTint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.45), width: 1.2),
              boxShadow: [BoxShadow(
                color: _outline.withOpacity(0.22),
                offset: const Offset(1.5, 1.5), blurRadius: 0)]),
            child: Icon(iconData, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(title,
                style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                overflow: TextOverflow.ellipsis, maxLines: 1)),
              if (isGenerated) ...[
                const SizedBox(width: 6),
                _TagPill(label: 'GENERATED', color: _mLav),
              ],
            ]),
            Row(children: [
              if (date != null) Text(_fmtDate(date),
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brownSoft)),
              if (isGenerated && qCount > 0) ...[
                if (date != null) const SizedBox(width: 8),
                Text('$qCount question${qCount == 1 ? '' : 's'}',
                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brownSoft)),
              ],
            ]),
            if (topics.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Wrap(spacing: 4, children: [
                for (final t in topics.take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _mLav.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: _outline.withOpacity(0.2), width: 1)),
                    child: Text(t,
                      style: GoogleFonts.nunito(
                        fontSize: 9, fontWeight: FontWeight.w700, color: _brownLt)),
                  ),
              ]),
            ),
          ])),
          if (!isGenerated) Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: (pct >= 70 ? _mSage : pct >= 50 ? _mButter : _mTerra).withOpacity(0.55),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1)),
            child: Text('${pct.round()}%',
              style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
          ),
          const SizedBox(width: 6),
          _TrashBtn(onTap: onDelete),
        ]),
      ),
    );
  }
}

//  Shared sub-widgets
class _PillBtn extends StatelessWidget {
  final String label;
  final Color fill;
  final Color? textColor;
  final VoidCallback onTap;
  const _PillBtn({
    required this.label, required this.fill,
    this.textColor, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline, width: 1.4),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(0.55),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Text(label,
          style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.3,
            color: textColor ?? _brown)),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniPill({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _brown),
        const SizedBox(width: 4),
        Text(label,
          style: GoogleFonts.nunito(
            fontSize: 10, fontWeight: FontWeight.w800, color: _brown)),
      ]),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final Color color;
  const _TagPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _outline.withOpacity(0.4), width: 1),
      ),
      child: Text(label,
        style: GoogleFonts.nunito(
          fontSize: 9, fontWeight: FontWeight.w900,
          letterSpacing: 0.6, color: Colors.white)),
    );
  }
}

class _TrashBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _TrashBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _mTerra.withOpacity(0.3),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _red.withOpacity(0.35), width: 1)),
        child: Icon(Icons.delete_outline_rounded, size: 16, color: _red),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconBtn({
    required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _cardFill.withOpacity(0.88),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline.withOpacity(0.32), width: 1.5),
            boxShadow: [BoxShadow(
              color: _outline.withOpacity(0.22),
              offset: const Offset(2.5, 2.5), blurRadius: 0)],
          ),
          child: Icon(icon, size: 20, color: _brownLt),
        ),
      ),
    );
  }
}

// Sessions don't have their own row widget in this file because the Content
// tab doesn't surface them as a first-class list. The topic detail sheet
// does though, so we render a minimal non-interactive card: icon + title +
// duration + timestamp. Tap-to-open is intentionally not wired yet (there
// is no session detail destination on mobile).
class _SessionRowCompact extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionRowCompact({required this.session});
  @override
  Widget build(BuildContext context) {
    final title = (session['title'] as String?) ?? 'Study session';
    final mins = (session['duration_minutes'] is int) ? session['duration_minutes'] as int
        : int.tryParse(session['duration_minutes']?.toString() ?? '') ?? 0;
    final started = DateTime.tryParse(session['start_time']?.toString() ?? '');
    return _tintedCard(
      tint: _mButter,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _mButter,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline.withOpacity(0.45), width: 1.2)),
          child: const Icon(Icons.schedule_rounded, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
            style: GoogleFonts.gaegu(fontSize: 15, fontWeight: FontWeight.w700, color: _brown),
            overflow: TextOverflow.ellipsis, maxLines: 1),
          Row(children: [
            Text('$mins min',
              style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brownSoft)),
            if (started != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.schedule_rounded, size: 10, color: _brownSoft),
              const SizedBox(width: 2),
              Text(_fmtDate(started),
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brownSoft)),
            ],
          ]),
        ])),
      ]),
    );
  }
}

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
        final opFactor = 0.05 + (idx % 5) * 0.012;
        paint.color = _pawClr.withOpacity(opFactor);
        final angle = (idx % 4) * 0.3 - 0.3;
        _drawCatPaw(canvas, paint, x, y, pawR, angle);
        idx++;
      }
    }
  }

  void _drawCatPaw(Canvas c, Paint p, double cx, double cy, double r, double a) {
    c.save(); c.translate(cx, cy); c.rotate(a);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 1.8), p);
    final tr = r * 0.52;
    c.drawCircle(Offset(-r * 1.0, -r * 1.35), tr, p);
    c.drawCircle(Offset(-r * 0.38, -r * 1.65), tr, p);
    c.drawCircle(Offset(r * 0.38, -r * 1.65), tr, p);
    c.drawCircle(Offset(r * 1.0, -r * 1.35), tr, p);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// Unused-but-preserved panel background color so the import stays valid
// for future extensions (e.g. filter drawers). Getter form because
// `_panelBg` is now mode-aware.
// ignore: unused_element
Color get _panelBgRef => _panelBg;
