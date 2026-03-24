/// Matches the Study Tab design language:
///   • Cream/terra-cotta ombre background + paw-print overlay
///   • Bitroad for headings/values, Gaegu for body text
///   • Hard-offset shadows, thick brown outlines, pill chips
///   • Modals styled like the Health Tab (gradient header bar + close pill)
///
/// UI-only: provider names are kept in comments; wire up to your
/// existing subjectsProvider once dropped in.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/screens/study/flashcard_screen.dart';
import 'package:cerebro_app/screens/study/quiz_screen.dart';
import 'package:cerebro_app/screens/study/subject_detail_screen.dart';
import 'package:cerebro_app/widgets/upload_notes_modal.dart';

const _ombre1  = Color(0xFFFFFBF7);
const _ombre2  = Color(0xFFFFF8F3);
const _ombre3  = Color(0xFFFFF3EF);
const _ombre4  = Color(0xFFFEEDE9);
const _pawClr  = Color(0xFFF8BCD0);

const _outline   = Color(0xFF6E5848);
const _brown     = Color(0xFF4E3828);
const _brownLt   = Color(0xFF7A5840);
const _brownSoft = Color(0xFF9A8070);

const _cardFill  = Color(0xFFFFF8F4);
const _panelBg   = Color(0xFFFFF6EE);
const _cream     = Color(0xFFFDEFDB);

const _olive    = Color(0xFF98A869);
const _oliveDk  = Color(0xFF58772F);
const _pinkLt   = Color(0xFFFFD5F5);
const _pink     = Color(0xFFFEA9D3);
const _pinkDk   = Color(0xFFE890B8);
const _coral    = Color(0xFFF7AEAE);
const _gold     = Color(0xFFE4BC83);
const _orange   = Color(0xFFFFBC5C);
const _red      = Color(0xFFEF6262);
const _blueLt   = Color(0xFFDDF6FF);
const _purpleHdr = Color(0xFFCDA8D8);
const _skyHdr    = Color(0xFF9DD4F0);

// Used as the *primary* accent surface so the screen feels calmer.
// The bright tones above stay for legacy refs / state highlights.
const _mTerra   = Color(0xFFD9B5A6); // dusty terracotta  (was _coral)
const _mSlate   = Color(0xFFB6CBD6); // dusty slate-blue  (was _skyHdr)
const _mSage    = Color(0xFFB5C4A0); // calm sage         (was bright olive bg)
const _mMint    = Color(0xFFC8DCC2); // soft mint         (was _greenLt)
const _mLav     = Color(0xFFC9B8D9); // dusty lavender    (was _purpleHdr)
const _mButter  = Color(0xFFE8D4A0); // soft butter       (was _orange / _gold)
const _mBlush   = Color(0xFFEAD0CE); // washed blush      (was _pinkLt)
const _mSand    = Color(0xFFE8D9C2); // warm sand         (neutral fill)

TextStyle _gaegu({double size = 14, FontWeight weight = FontWeight.w600, Color color = _brown, double? h}) =>
    GoogleFonts.gaegu(fontSize: size, fontWeight: weight, color: color, height: h);

const _bitroad = 'Bitroad';

/// UI model that mirrors the backend `SubjectResponse`.
class _SubjectUi {
  final String id;
  final String name;
  final String code;
  final int totalTopics;     // computed client-side once sessions/topics wired
  final int completedTopics; // computed client-side
  final int avgScore;        // current_proficiency rounded 0..100
  final int targetScore;     // target_proficiency rounded 0..100
  final Color accent;        // parsed from backend "#RRGGBB"
  final String colorHex;     // original hex (for PUT updates)
  final IconData icon;       // parsed from backend icon string
  final String iconKey;      // original icon key (for PUT updates)
  final String nextExam;     // placeholder until exams are wired
  _SubjectUi({
    required this.id,
    required this.name,
    required this.code,
    required this.totalTopics,
    required this.completedTopics,
    required this.avgScore,
    required this.targetScore,
    required this.accent,
    required this.colorHex,
    required this.icon,
    required this.iconKey,
    required this.nextExam,
  });

  double get progress => targetScore == 0 ? 0 : (avgScore / targetScore).clamp(0, 1);

  factory _SubjectUi.fromJson(Map<String, dynamic> j) {
    final colorHex = (j['color'] as String?) ?? '#D9B5A6';
    final iconKey  = (j['icon']  as String?) ?? 'book';
    final cur = _asDouble(j['current_proficiency']) ?? 0.0;
    final tgt = _asDouble(j['target_proficiency'])  ?? 100.0;
    return _SubjectUi(
      id: j['id']?.toString() ?? '',
      name: (j['name'] as String?) ?? 'Untitled',
      code: (j['code'] as String?) ?? '',
      totalTopics: 0,
      completedTopics: 0,
      avgScore: cur.round(),
      targetScore: tgt.round(),
      accent: _hexToColor(colorHex),
      colorHex: colorHex,
      icon: _iconFromKey(iconKey),
      iconKey: iconKey,
      nextExam: cur >= tgt ? 'completed' : '—',
    );
  }
}

/// Lightweight UI model for an uploaded study material.
class _MaterialUi {
  final String id;
  final String title;
  final String content;
  final String sourceType;
  final List<String> topics;
  final int wordCount;
  final DateTime? createdAt;
  _MaterialUi({
    required this.id,
    required this.title,
    required this.content,
    required this.sourceType,
    required this.topics,
    required this.wordCount,
    required this.createdAt,
  });
  factory _MaterialUi.fromJson(Map<String, dynamic> j) => _MaterialUi(
    id: j['id']?.toString() ?? '',
    title: (j['title'] as String?) ?? 'Untitled',
    content: (j['content'] as String?) ?? '',
    sourceType: (j['source_type'] as String?) ?? 'typed',
    topics: ((j['topics'] as List?) ?? const []).map((e) => e.toString()).toList(),
    wordCount: (j['word_count'] is int) ? j['word_count'] as int
        : int.tryParse(j['word_count']?.toString() ?? '') ?? 0,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
  );
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
String _labelForSource(String s) {
  switch (s) {
    case 'pdf_upload':     return 'PDF';
    case 'image_upload':   return 'Image';
    case 'pasted':         return 'Pasted';
    case 'session_import': return 'Session';
    case 'typed':          return 'Typed';
    default:               return s;
  }
}
String _relDate(DateTime dt) {
  final now = DateTime.now();
  final d = now.difference(dt);
  if (d.inDays >= 7) return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
  return 'just now';
}

/// Session note model (StudySession with notes / topics).
class _SessionNoteUi {
  final String id;
  final String title;
  final String notes;
  final List<String> topics;
  final int durationMinutes;
  final DateTime? startTime;
  _SessionNoteUi({
    required this.id,
    required this.title,
    required this.notes,
    required this.topics,
    required this.durationMinutes,
    required this.startTime,
  });
  factory _SessionNoteUi.fromJson(Map<String, dynamic> j) => _SessionNoteUi(
    id: j['id']?.toString() ?? '',
    title: (j['title'] as String?) ?? 'Study session',
    notes: (j['notes'] as String?) ?? '',
    topics: ((j['topics_covered'] as List?) ?? const []).map((e) => e.toString()).toList(),
    durationMinutes: (j['duration_minutes'] is int) ? j['duration_minutes'] as int
      : int.tryParse(j['duration_minutes']?.toString() ?? '') ?? 0,
    startTime: DateTime.tryParse(j['start_time']?.toString() ?? ''),
  );
}

/// Flashcard deck model.
class _DeckUi {
  final String id;
  final String name;
  final String description;
  final int cardCount;
  final DateTime? updatedAt;
  _DeckUi({
    required this.id,
    required this.name,
    required this.description,
    required this.cardCount,
    required this.updatedAt,
  });
  factory _DeckUi.fromJson(Map<String, dynamic> j) => _DeckUi(
    id: j['id']?.toString() ?? '',
    name: (j['name'] as String?) ?? 'Deck',
    description: (j['description'] as String?) ?? '',
    cardCount: (j['total_cards'] is int) ? j['total_cards'] as int
      : (j['card_count'] is int) ? j['card_count'] as int
      : int.tryParse(j['total_cards']?.toString() ?? j['card_count']?.toString() ?? '') ?? 0,
    updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? ''),
  );
}

/// Quiz result model (historical quiz from /study/quizzes).
class _QuizUi {
  final String id;
  final String title;
  final double percentage;
  final List<String> topics;
  final DateTime? dateTaken;
  _QuizUi({
    required this.id,
    required this.title,
    required this.percentage,
    required this.topics,
    required this.dateTaken,
  });
  factory _QuizUi.fromJson(Map<String, dynamic> j) => _QuizUi(
    id: j['id']?.toString() ?? '',
    title: (j['title'] as String?) ?? 'Quiz',
    percentage: _asDouble(j['percentage']) ?? 0.0,
    topics: ((j['topics_tested'] as List?) ?? const []).map((e) => e.toString()).toList(),
    dateTaken: DateTime.tryParse(j['date_taken']?.toString() ?? j['created_at']?.toString() ?? ''),
  );
}

// Backend Decimals can come back as String or num — normalize safely.
double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

Color _hexToColor(String hex) {
  var s = hex.replaceFirst('#', '').trim();
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFFD9B5A6);
}
String _colorToHex(Color c) {
  final r = c.red.toRadixString(16).padLeft(2, '0');
  final g = c.green.toRadixString(16).padLeft(2, '0');
  final b = c.blue.toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}

const Map<String, IconData> _iconMap = {
  'book':        Icons.menu_book_rounded,
  'menu_book':   Icons.menu_book_rounded,
  'functions':   Icons.functions_rounded,
  'math':        Icons.functions_rounded,
  'bolt':        Icons.bolt_rounded,
  'physics':     Icons.bolt_rounded,
  'science':     Icons.science_rounded,
  'chemistry':   Icons.science_rounded,
  'biotech':     Icons.biotech_rounded,
  'biology':     Icons.biotech_rounded,
  'computer':    Icons.computer_rounded,
  'code':        Icons.computer_rounded,
  'palette':     Icons.palette_rounded,
  'art':         Icons.palette_rounded,
  'language':    Icons.language_rounded,
  'english':     Icons.language_rounded,
  'history':     Icons.history_edu_rounded,
  'geography':   Icons.public_rounded,
  'music':       Icons.music_note_rounded,
  'pe':          Icons.sports_rounded,
};
IconData _iconFromKey(String key) => _iconMap[key.toLowerCase()] ?? Icons.menu_book_rounded;
String _keyFromIcon(IconData ic) {
  for (final e in _iconMap.entries) {
    if (e.value == ic) return e.key;
  }
  return 'book';
}

const _greenLt = Color(0xFFC2E8BC);

//  SUBJECTS SCREEN
class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});
  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen>
    with TickerProviderStateMixin {
  String _filter = 'all'; // all | inprogress | mastered
  String _query = '';
  late final AnimationController _enter;

  List<_SubjectUi> _subjects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubjects());
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/study/subjects');
      final data = res.data;
      final list = <_SubjectUi>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) list.add(_SubjectUi.fromJson(item));
        }
      }
      if (!mounted) return;
      setState(() { _subjects = list; _loading = false; });
    } catch (e) {
      debugPrint('Load subjects error: $e');
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<_SubjectUi> get _filtered {
    Iterable<_SubjectUi> it = _subjects;
    if (_filter == 'inprogress') it = it.where((s) => s.progress < 1.0);
    if (_filter == 'mastered')   it = it.where((s) => s.progress >= 1.0);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      it = it.where((s) => s.name.toLowerCase().contains(q) || s.code.toLowerCase().contains(q));
    }
    return it.toList();
  }

  void _showAddSubject() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _AddSubjectModal(onSaved: _loadSubjects),
    );
  }

  void _showSubjectDetail(_SubjectUi s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SubjectDetailScreen(
        subjectId: s.id,
        initialSubjectName: s.name,
        initialColorHex: s.colorHex,
        initialIconKey: s.iconKey,
      ),
    )).then((_) {
      // Returning from the detail page — refresh counts / proficiency.
      if (mounted) _loadSubjects();
    });
  }

  // Quick-preview modal (legacy) — retained for potential entry from
  // the dashboard tab. Not used from the main list anymore.
  // ignore: unused_element
  void _showSubjectDetailModal(_SubjectUi s) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _SubjectDetailModal(
        subject: s,
        onChanged: _loadSubjects,
      ),
    );
  }

  Future<void> _pickAndUploadFile(BuildContext context, {String? preselectedSubjectId}) async {
    await UploadNotesModal.show(
      context,
      ref: ref,
      subjects: _subjects
          .map((s) => UploadModalSubject(id: s.id, name: s.name, icon: s.icon))
          .toList(),
      preselectedSubjectId: preselectedSubjectId,
      onUploaded: (_) {
        // Reload after a successful upload so the new material chip appears.
        if (mounted) _loadSubjects();
      },
    );
  }

  // Old inline upload dialog — preserved as `_legacyPickAndUploadFile` so we
  // can still nuke it once smoke tests pass on every screen.
  // ignore: unused_element
  Future<void> _legacyPickAndUploadFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

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

    final titleCtrl = TextEditingController(text: file.name.split('.').first);
    final topicsCtrl = TextEditingController();
    String? pickedSubjectId;

    final shouldUpload = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 560,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _outline, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(6, 6), blurRadius: 0),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  // Top row: uppercase tag + circular close
                  Row(children: [
                    Expanded(child: Text('UPLOAD NOTES',
                      style: TextStyle(
                        fontFamily: _bitroad, fontSize: 13,
                        color: _oliveDk, letterSpacing: 1.8))),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _outline, width: 1.5),
                        ),
                        child: const Icon(Icons.close_rounded, size: 17, color: _brown),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Icon chip + heading + subtitle
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: _olive,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _outline, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                        ],
                      ),
                      child: const Icon(Icons.upload_file_rounded, size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(file.name,
                          style: const TextStyle(fontFamily: _bitroad, fontSize: 22, color: _brown, height: 1.1),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text('extract the text & save it under a subject.',
                          style: _gaegu(size: 14, color: _brownLt)),
                      ]),
                    )),
                  ]),
                  const SizedBox(height: 22),

                  _medInput(ctrl: titleCtrl, hint: 'note title', icon: Icons.title_rounded),
                  const SizedBox(height: 14),
                  _medDropdown(
                    value: pickedSubjectId,
                    hint: 'link to a subject (optional)',
                    icon: Icons.folder_rounded,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('no subject (general)',
                          style: TextStyle(fontFamily: 'Gaegu', color: _brownSoft)),
                      ),
                      ..._subjects.map((s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(s.icon, size: 16, color: _brown),
                          const SizedBox(width: 8),
                          Flexible(child: Text(s.name,
                            style: GoogleFonts.gaegu(fontSize: 16, color: _brown, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis)),
                        ]),
                      )),
                    ],
                    onChanged: (v) => setLocal(() => pickedSubjectId = v),
                  ),
                  const SizedBox(height: 14),
                  _medInput(ctrl: topicsCtrl, hint: 'topics, comma-separated (optional)', icon: Icons.label_rounded),
                  const SizedBox(height: 24),

                  Row(children: [
                    Expanded(flex: 2, child: _SoftButton(
                      label: 'cancel', fill: _cream,
                      onTap: () => Navigator.of(ctx).pop(false),
                    )),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: _SoftButton(
                      label: 'upload & extract', fill: _olive, textColor: Colors.white,
                      onTap: () => Navigator.of(ctx).pop(true),
                    )),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      )),
    );

    if (shouldUpload != true || !context.mounted) return;

    final api = ref.read(apiServiceProvider);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
        'title': titleCtrl.text.trim().isEmpty ? file.name : titleCtrl.text.trim(),
        if (pickedSubjectId != null && pickedSubjectId!.isNotEmpty)
          'subject_id': pickedSubjectId,
        'topics': topicsCtrl.text.trim(),
      });
      await api.post('/study/materials/upload', data: formData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('File uploaded & text extracted!', style: GoogleFonts.nunito()),
          backgroundColor: _mSage));
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e', style: GoogleFonts.nunito()),
          backgroundColor: _mTerra));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final contentW = (screenW * 0.92).clamp(360.0, 1200.0);
    final isWide = contentW >= 900;
    final crossAxis = contentW >= 1050 ? 3 : (contentW >= 720 ? 2 : 1);

    return Material(
      type: MaterialType.transparency,
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [_ombre1, _ombre2, _ombre3, _ombre4],
        ),
      ),
      child: CustomPaint(
        painter: _PawPrintBg(),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: SizedBox(
              width: contentW,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _stagger(0.00, _header()),
                  const SizedBox(height: 14),
                  _stagger(0.06, _searchAndFilters()),
                  const SizedBox(height: 18),
                  _stagger(0.12, _statsStrip()),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 110),
                      child: _stagger(0.18, _grid(isWide, crossAxis)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            child: Icon(Icons.arrow_back_rounded, size: 20, color: _brown),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Subjects',
                style: TextStyle(fontFamily: _bitroad, fontSize: 26, color: _brown, height: 1.15)),
              const SizedBox(height: 2),
              Text('Pick a subject to keep your streak alive~',
                style: _gaegu(size: 15, color: _brownSoft, h: 1.3)),
            ],
          ),
        ),
        Wrap(
          spacing: 7, runSpacing: 7,
          children: [
            _Pill(icon: Icons.view_module_rounded, label: '${_subjects.length} subjects', color: _mSlate.withOpacity(0.55)),
            _Pill(icon: Icons.emoji_events_rounded,
                label: '${_subjects.where((s) => s.progress >= 1).length} mastered',
                color: _mSage.withOpacity(0.85), highlight: true),
            GestureDetector(
              onTap: () => _pickAndUploadFile(context),
              child: _Pill(icon: Icons.upload_file_rounded, label: 'Upload', color: _mButter),
            ),
            GestureDetector(
              onTap: _showAddSubject,
              child: _Pill(icon: Icons.add_rounded, label: 'Add', color: _mTerra),
            ),
          ],
        ),
      ],
    );
  }

  Widget _searchAndFilters() {
    return Column(
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 18, color: _brownLt),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: _gaegu(size: 15, color: _brown, weight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search subject or code...',
                  hintStyle: _gaegu(size: 15, color: _brownSoft),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _FilterPill(label: 'All',        selected: _filter == 'all',        onTap: () => setState(() => _filter = 'all')),
          const SizedBox(width: 8),
          _FilterPill(label: 'In Progress',selected: _filter == 'inprogress', onTap: () => setState(() => _filter = 'inprogress')),
          const SizedBox(width: 8),
          _FilterPill(label: 'Mastered',   selected: _filter == 'mastered',   onTap: () => setState(() => _filter = 'mastered')),
          const Spacer(),
          Text('${_filtered.length} showing',
              style: _gaegu(size: 12, color: _brownSoft, weight: FontWeight.w700)),
        ]),
      ],
    );
  }

  Widget _statsStrip() {
    final total = _subjects.length;
    final mastered = _subjects.where((s) => s.progress >= 1).length;
    final avg = total == 0 ? 0 :
        (_subjects.map((s) => s.avgScore).reduce((a, b) => a + b) / total).round();
    final totalTopics = _subjects.fold<int>(0, (a, s) => a + s.completedTopics);

    return Row(children: [
      Expanded(child: _StatTile(icon: Icons.school_rounded, label: 'Total',
          value: '$total', bgColor: _mSlate.withOpacity(0.5))),
      const SizedBox(width: 10),
      Expanded(child: _StatTile(icon: Icons.military_tech_rounded, label: 'Mastered',
          value: '$mastered', bgColor: _mSage.withOpacity(0.85), isHighlight: true)),
      const SizedBox(width: 10),
      Expanded(child: _StatTile(icon: Icons.auto_graph_rounded, label: 'Avg Score',
          value: '$avg%', bgColor: _mButter.withOpacity(0.55))),
      const SizedBox(width: 10),
      Expanded(child: _StatTile(icon: Icons.topic_rounded, label: 'Topics',
          value: '$totalTopics', bgColor: _mBlush.withOpacity(0.7))),
    ]);
  }

  Widget _grid(bool isWide, int crossAxis) {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState();
    final items = _filtered;
    if (items.isEmpty) return _emptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxis,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (_, i) => _SubjectCard(
        subject: items[i],
        onTap: () => _showSubjectDetail(items[i]),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _cream,
            shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.3), width: 2.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: Icon(Icons.auto_stories_rounded, size: 36, color: _brownLt),
        ),
        const SizedBox(height: 14),
        const Text('No subjects found',
          style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
        const SizedBox(height: 4),
        Text('Try a different filter or add a new subject',
          style: _gaegu(size: 14, color: _brownSoft)),
      ]),
    );
  }

  Widget _loadingState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(children: [
        const CircularProgressIndicator(color: _mTerra, strokeWidth: 3),
        const SizedBox(height: 14),
        Text('Loading your subjects...',
          style: _gaegu(size: 14, color: _brownSoft)),
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
          child: Icon(Icons.error_outline_rounded, size: 36, color: _brown),
        ),
        const SizedBox(height: 14),
        const Text("Couldn't load subjects",
          style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
        const SizedBox(height: 4),
        Text(_error ?? '', textAlign: TextAlign.center,
          style: _gaegu(size: 13, color: _brownSoft)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _loadSubjects,
          child: _Pill(icon: Icons.refresh_rounded, label: 'Retry', color: _mSage),
        ),
      ]),
    );
  }

  // NOTE: passes `child` through AnimatedBuilder so the subtree isn't
  // rebuilt every frame, and wraps in IgnorePointer while animating so
  // mouse hit-testing doesn't race with the render update (fixes the
  // `_debugDuringDeviceUpdate` mouse-tracker assertion on desktop).
  Widget _stagger(double delay, Widget child) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _enter,
        child: child,
        builder: (_, c) {
          final t = Curves.easeOutCubic.transform(((_enter.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
          return IgnorePointer(
            ignoring: t < 1.0,
            child: Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c),
            ),
          );
        },
      ),
    );
  }
}

//  SUBJECT CARD
class _SubjectCard extends StatelessWidget {
  final _SubjectUi subject;
  final VoidCallback onTap;
  const _SubjectCard({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mastered = subject.progress >= 1.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
              offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent band / header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                decoration: BoxDecoration(
                  color: subject.accent.withOpacity(mastered ? 0.7 : 0.42),
                  border: Border(bottom: BorderSide(color: _outline.withOpacity(0.18), width: 1.5)),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outline.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(subject.icon, size: 20, color: _brown),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject.name,
                          style: const TextStyle(fontFamily: _bitroad, fontSize: 17, color: _brown),
                          overflow: TextOverflow.ellipsis, maxLines: 1),
                        const SizedBox(height: 1),
                        Text(subject.code,
                          style: _gaegu(size: 11, weight: FontWeight.w700,
                            color: _brown.withOpacity(0.7))),
                      ],
                    ),
                  ),
                  if (mastered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _mButter,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
                      ),
                      child: const Text('★',
                        style: TextStyle(fontFamily: _bitroad, fontSize: 12, color: _brown)),
                    ),
                ]),
              ),

              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('${subject.completedTopics}/${subject.totalTopics} topics',
                          style: _gaegu(size: 13, weight: FontWeight.w700, color: _brown)),
                        const Spacer(),
                        Text('${(subject.progress * 100).round()}%',
                          style: const TextStyle(fontFamily: _bitroad, fontSize: 15, color: _brown)),
                      ]),
                      const SizedBox(height: 8),
                      // Progress bar
                      SizedBox(
                        height: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _olive.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _outline.withOpacity(0.22), width: 1),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: subject.progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [subject.accent, subject.accent.withOpacity(0.85)]),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(children: [
                        _MiniPill(
                          icon: Icons.auto_graph_rounded,
                          label: '${subject.avgScore}% avg',
                          color: _mSlate.withOpacity(0.45),
                        ),
                        const SizedBox(width: 6),
                        _MiniPill(
                          icon: Icons.event_rounded,
                          label: subject.nextExam,
                          color: subject.nextExam == 'completed' ? _mSage.withOpacity(0.55) : _mTerra.withOpacity(0.55),
                        ),
                      ]),
                    ],
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

//  ADD SUBJECT MODAL (Health-tab style)
class _AddSubjectModal extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;
  final _SubjectUi? existing; // if present, edit mode
  const _AddSubjectModal({this.onSaved, this.existing});
  @override
  ConsumerState<_AddSubjectModal> createState() => _AddSubjectModalState();
}

class _AddSubjectModalState extends ConsumerState<_AddSubjectModal> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late Color _accent;
  late IconData _icon;
  bool _saving = false;

  static const _palette = [_mTerra, _mSlate, _mSage, _mMint, _mLav, _mButter, _mBlush, _mSand];
  static const _icons = [
    Icons.functions_rounded, Icons.bolt_rounded, Icons.science_rounded,
    Icons.biotech_rounded, Icons.menu_book_rounded, Icons.computer_rounded,
    Icons.palette_rounded, Icons.language_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.existing?.code ?? '');
    _accent = widget.existing?.accent ?? _mTerra;
    _icon = widget.existing?.icon ?? Icons.menu_book_rounded;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a subject name', style: GoogleFonts.nunito()),
        backgroundColor: _mTerra));
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(apiServiceProvider);
    final body = <String, dynamic>{
      'name': name,
      if (_codeCtrl.text.trim().isNotEmpty) 'code': _codeCtrl.text.trim(),
      'color': _colorToHex(_accent),
      'icon': _keyFromIcon(_icon),
    };
    try {
      if (widget.existing == null) {
        await api.post('/study/subjects', data: body);
      } else {
        await api.put('/study/subjects/${widget.existing!.id}', data: body);
      }
      if (!mounted) return;
      widget.onSaved?.call();
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Save subject error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e', style: GoogleFonts.nunito()),
        backgroundColor: _mTerra));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 540,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _outline, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(6, 6), blurRadius: 0),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // Top row: uppercase tag + circular close button
                Row(children: [
                  Expanded(child: Text('SUBJECTS',
                    style: TextStyle(
                      fontFamily: _bitroad, fontSize: 13,
                      color: _oliveDk, letterSpacing: 1.8))),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _outline, width: 1.5),
                      ),
                      child: const Icon(Icons.close_rounded, size: 17, color: _brown),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // Icon chip + heading + subtitle
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _olive,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _outline, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                      ],
                    ),
                    child: Icon(_icon, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.existing == null ? 'Add a Subject' : 'Edit Subject',
                        style: const TextStyle(fontFamily: _bitroad, fontSize: 24, color: _brown, height: 1.1)),
                      const SizedBox(height: 6),
                      Text('track what you are studying. keep tabs on progress.',
                        style: _gaegu(size: 14, color: _brownLt)),
                    ]),
                  )),
                ]),
                const SizedBox(height: 22),

                _medInput(ctrl: _nameCtrl, hint: 'subject name (e.g. Biology)', icon: Icons.menu_book_rounded),
                const SizedBox(height: 14),
                _medInput(ctrl: _codeCtrl, hint: 'course code (e.g. BIO-120)', icon: Icons.qr_code_2_rounded),
                const SizedBox(height: 22),

                Text('pick a colour',
                  style: _gaegu(size: 16, weight: FontWeight.w700, color: _oliveDk)),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final c in _palette)
                    GestureDetector(
                      onTap: () => setState(() => _accent = c),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _outline,
                            width: _accent == c ? 3 : 1.5),
                          boxShadow: _accent == c
                              ? const [BoxShadow(color: Colors.black,
                                  offset: Offset(3, 3), blurRadius: 0)]
                              : [],
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 20),

                Text('pick an icon',
                  style: _gaegu(size: 16, weight: FontWeight.w700, color: _oliveDk)),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final ic in _icons)
                    GestureDetector(
                      onTap: () => setState(() => _icon = ic),
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: _icon == ic ? _olive : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _outline, width: 2),
                          boxShadow: _icon == ic
                              ? const [BoxShadow(color: Colors.black,
                                  offset: Offset(3, 3), blurRadius: 0)]
                              : [],
                        ),
                        child: Icon(ic, size: 22,
                          color: _icon == ic ? Colors.white : _brown),
                      ),
                    ),
                ]),
                const SizedBox(height: 24),

                Row(children: [
                  Expanded(flex: 2, child: _SoftButton(
                    label: 'cancel', fill: _cream,
                    onTap: _saving ? () {} : () => Navigator.of(context).pop(),
                  )),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: _SoftButton(
                    label: _saving ? 'saving...'
                        : (widget.existing == null ? 'save subject' : 'update subject'),
                    fill: _olive, textColor: Colors.white,
                    onTap: _saving ? () {} : _save,
                  )),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

}

// Large rounded-pill input field with leading olive icon chip (medication-modal style).
Widget _medInput({
  required TextEditingController ctrl,
  required String hint,
  required IconData icon,
}) => Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _outline, width: 2),
    boxShadow: const [
      BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
    ],
  ),
  padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
  child: Row(children: [
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: _olive,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline, width: 1.5),
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    ),
    const SizedBox(width: 12),
    Expanded(child: TextField(
      controller: ctrl,
      style: _gaegu(size: 16, weight: FontWeight.w600, color: _brown),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _gaegu(size: 16, color: _brownSoft),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    )),
  ]),
);

// Matching dropdown row for the modal style.
Widget _medDropdown<T>({
  required T? value,
  required String hint,
  required IconData icon,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) => Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _outline, width: 2),
    boxShadow: const [
      BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
    ],
  ),
  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
  child: Row(children: [
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: _olive,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline, width: 1.5),
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    ),
    const SizedBox(width: 12),
    Expanded(child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded, color: _brownLt),
        hint: Text(hint, style: _gaegu(size: 16, color: _brownSoft)),
        style: _gaegu(size: 16, weight: FontWeight.w600, color: _brown),
        dropdownColor: Colors.white,
        items: items,
        onChanged: onChanged,
      ),
    )),
  ]),
);

//  SUBJECT DETAIL MODAL (Health-tab style)
class _SubjectDetailModal extends ConsumerStatefulWidget {
  final _SubjectUi subject;
  final VoidCallback? onChanged;
  const _SubjectDetailModal({required this.subject, this.onChanged});

  @override
  ConsumerState<_SubjectDetailModal> createState() => _SubjectDetailModalState();
}

class _SubjectDetailModalState extends ConsumerState<_SubjectDetailModal> {
  bool _deleting = false;
  bool _loadingAll = true;
  String? _loadError;
  List<_MaterialUi> _materials = [];
  List<_SessionNoteUi> _sessions = [];
  List<_DeckUi> _decks = [];
  List<_QuizUi> _quizzes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { _loadingAll = true; _loadError = null; });
    final api = ref.read(apiServiceProvider);
    final sid = widget.subject.id;
    try {
      final results = await Future.wait([
        api.get('/study/materials', queryParams: {'subject_id': sid}),
        api.get('/study/sessions',  queryParams: {'subject_id': sid}),
        api.get('/study/decks',     queryParams: {'subject_id': sid}),
        api.get('/study/quizzes',   queryParams: {'subject_id': sid}),
      ]);
      final mats = <_MaterialUi>[];
      final sess = <_SessionNoteUi>[];
      final deks = <_DeckUi>[];
      final qzs = <_QuizUi>[];
      if (results[0].data is List) for (final i in results[0].data as List) {
        if (i is Map<String, dynamic>) mats.add(_MaterialUi.fromJson(i));
      }
      if (results[1].data is List) for (final i in results[1].data as List) {
        if (i is Map<String, dynamic>) {
          // Only keep sessions that actually have notes or topics — they're the
          // ones worth surfacing as "uploaded notes" under a subject.
          final hasNotes = ((i['notes'] as String?)?.trim().isNotEmpty ?? false);
          final hasTopics = ((i['topics_covered'] as List?)?.isNotEmpty ?? false);
          if (hasNotes || hasTopics) sess.add(_SessionNoteUi.fromJson(i));
        }
      }
      if (results[2].data is List) for (final i in results[2].data as List) {
        if (i is Map<String, dynamic>) deks.add(_DeckUi.fromJson(i));
      }
      if (results[3].data is List) for (final i in results[3].data as List) {
        if (i is Map<String, dynamic>) qzs.add(_QuizUi.fromJson(i));
      }
      if (!mounted) return;
      setState(() {
        _materials = mats; _sessions = sess; _decks = deks; _quizzes = qzs;
        _loadingAll = false;
      });
    } catch (e) {
      debugPrint('Load subject content error: $e');
      if (!mounted) return;
      setState(() { _loadingAll = false; _loadError = e.toString(); });
    }
  }

  Future<void> _loadMaterials() => _loadAll();

  Future<void> _deleteMaterial(_MaterialUi m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Delete "${m.title}"?',
              style: const TextStyle(fontFamily: _bitroad, fontSize: 18, color: _brown)),
            const SizedBox(height: 6),
            Text('This removes the uploaded notes from this subject.',
              style: _gaegu(size: 13, color: _brownSoft)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _SoftButton(label: 'cancel', fill: _cream,
                onTap: () => Navigator.pop(ctx, false))),
              const SizedBox(width: 10),
              Expanded(child: _SoftButton(label: 'delete', fill: _red, textColor: Colors.white,
                onTap: () => Navigator.pop(ctx, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiServiceProvider).delete('/study/materials/${m.id}');
      _loadMaterials();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delete failed: $e', style: GoogleFonts.nunito()),
        backgroundColor: _mTerra));
    }
  }

  void _viewMaterial(_MaterialUi m) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => Dialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_mTerra, _mBlush]),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(children: [
                Icon(_iconForSource(m.sourceType), color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(m.title,
                  style: GoogleFonts.gaegu(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  overflow: TextOverflow.ellipsis, maxLines: 1)),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                _MiniPill(icon: Icons.source_rounded, label: _labelForSource(m.sourceType),
                  color: _mSlate.withOpacity(0.45)),
                _MiniPill(icon: Icons.text_snippet_rounded, label: '${m.wordCount} words',
                  color: _mSage.withOpacity(0.45)),
                if (m.createdAt != null)
                  _MiniPill(icon: Icons.schedule_rounded, label: _relDate(m.createdAt!),
                    color: _mButter.withOpacity(0.6)),
                for (final t in m.topics)
                  _MiniPill(icon: Icons.label_rounded, label: t, color: _mBlush.withOpacity(0.55)),
              ]),
            ),
            const Divider(color: _outline, thickness: 0.4, height: 8),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Text(m.content,
                style: GoogleFonts.nunito(fontSize: 13.5, color: _brown, height: 1.5)),
            )),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Delete ${widget.subject.name}?',
              style: const TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
            const SizedBox(height: 8),
            Text('This will remove the subject and unlink its materials. This cannot be undone.',
              style: _gaegu(size: 13, color: _brownSoft)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _SoftButton(
                label: 'cancel', fill: _cream,
                onTap: () => Navigator.of(ctx).pop(false))),
              const SizedBox(width: 10),
              Expanded(child: _SoftButton(
                label: 'delete', fill: _red, textColor: Colors.white,
                onTap: () => Navigator.of(ctx).pop(true))),
            ]),
          ]),
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await ref.read(apiServiceProvider).delete('/study/subjects/${widget.subject.id}');
      if (!mounted) return;
      widget.onChanged?.call();
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Delete subject error: $e');
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delete failed: $e', style: GoogleFonts.nunito()),
        backgroundColor: _mTerra));
    }
  }

  void _openEdit() {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _AddSubjectModal(
        existing: widget.subject,
        onSaved: widget.onChanged,
      ),
    );
  }

  Widget _contentSections() {
    if (_loadingAll) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: const SizedBox(width: 22, height: 22,
          child: CircularProgressIndicator(color: _mTerra, strokeWidth: 2.5)),
      );
    }
    if (_loadError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _mTerra.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.2), width: 1),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: _brown, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_loadError!,
            style: _gaegu(size: 12, color: _brownSoft),
            overflow: TextOverflow.ellipsis, maxLines: 2)),
          GestureDetector(onTap: _loadAll,
            child: const Icon(Icons.refresh_rounded, color: _brown, size: 18)),
        ]),
      );
    }
    final isAllEmpty = _materials.isEmpty && _sessions.isEmpty
        && _decks.isEmpty && _quizzes.isEmpty;
    if (isAllEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.18), width: 1.2),
        ),
        child: Row(children: [
          const Icon(Icons.auto_stories_outlined, color: _brownLt, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Nothing here yet. Upload notes, start a study session, or build a flashcard deck and tag this subject.',
            style: _gaegu(size: 12.5, color: _brownSoft, h: 1.3))),
        ]),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 340),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_materials.isNotEmpty) ...[
            _sectionHeader(Icons.description_rounded, 'UPLOADED NOTES', _materials.length),
            const SizedBox(height: 6),
            for (int i = 0; i < _materials.length; i++) ...[
              _MaterialRow(
                mat: _materials[i],
                onTap: () => _viewMaterial(_materials[i]),
                onDelete: () => _deleteMaterial(_materials[i]),
              ),
              if (i != _materials.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
          ],
          if (_sessions.isNotEmpty) ...[
            _sectionHeader(Icons.edit_note_rounded, 'SESSION NOTES', _sessions.length),
            const SizedBox(height: 6),
            for (int i = 0; i < _sessions.length; i++) ...[
              _SessionRow(sess: _sessions[i], onTap: () => _viewSession(_sessions[i])),
              if (i != _sessions.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
          ],
          if (_decks.isNotEmpty) ...[
            _sectionHeader(Icons.style_rounded, 'FLASHCARD DECKS', _decks.length),
            const SizedBox(height: 6),
            for (int i = 0; i < _decks.length; i++) ...[
              _DeckRow(deck: _decks[i], onTap: () => _openDeck(_decks[i])),
              if (i != _decks.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
          ],
          if (_quizzes.isNotEmpty) ...[
            _sectionHeader(Icons.quiz_rounded, 'QUIZZES', _quizzes.length),
            const SizedBox(height: 6),
            for (int i = 0; i < _quizzes.length; i++) ...[
              _QuizRow(quiz: _quizzes[i], onTap: () => _openQuiz(_quizzes[i])),
              if (i != _quizzes.length - 1) const SizedBox(height: 8),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(children: [
        Icon(icon, size: 16, color: _oliveDk),
        const SizedBox(width: 6),
        Text(label,
          style: _gaegu(size: 11, weight: FontWeight.w700, color: _oliveDk)
            .copyWith(letterSpacing: 1.2)),
        const Spacer(),
        Text('$count',
          style: const TextStyle(fontFamily: _bitroad, fontSize: 12, color: _brownSoft)),
      ]),
    );
  }

  void _viewSession(_SessionNoteUi s) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => Dialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: BoxDecoration(
                color: _mSage,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: _outline.withOpacity(0.3), width: 1.5)),
              ),
              child: Row(children: [
                const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(s.title,
                  style: GoogleFonts.gaegu(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  overflow: TextOverflow.ellipsis, maxLines: 2)),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                _MiniPill(icon: Icons.timer_rounded, label: '${s.durationMinutes} min',
                  color: _mSlate.withOpacity(0.45)),
                if (s.startTime != null)
                  _MiniPill(icon: Icons.schedule_rounded, label: _relDate(s.startTime!),
                    color: _mButter.withOpacity(0.6)),
                for (final t in s.topics)
                  _MiniPill(icon: Icons.label_rounded, label: t, color: _mBlush.withOpacity(0.55)),
              ]),
            ),
            const Divider(color: _outline, thickness: 0.4, height: 8),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Text(s.notes.isEmpty ? '(no written notes for this session)' : s.notes,
                style: GoogleFonts.nunito(
                  fontSize: 13.5,
                  color: s.notes.isEmpty ? _brownSoft : _brown,
                  fontStyle: s.notes.isEmpty ? FontStyle.italic : FontStyle.normal,
                  height: 1.5)),
            )),
          ]),
        ),
      ),
    );
  }

  void _openDeck(_DeckUi d) {
    Navigator.of(context).pop(); // close detail modal
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FlashcardScreen(initialDeckId: d.id),
    ));
  }

  void _openQuiz(_QuizUi q) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const QuizScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 560,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outline, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(6, 6), blurRadius: 0),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // Top row: code tag + circular close
                Row(children: [
                  Expanded(child: Text(subject.code.toUpperCase(),
                    style: TextStyle(
                      fontFamily: _bitroad, fontSize: 13,
                      color: _oliveDk, letterSpacing: 1.8))),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _outline, width: 1.5),
                      ),
                      child: const Icon(Icons.close_rounded, size: 17, color: _brown),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // Icon chip + subject name
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _olive,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _outline, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                      ],
                    ),
                    child: Icon(subject.icon, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(subject.name,
                      style: const TextStyle(fontFamily: _bitroad, fontSize: 24, color: _brown, height: 1.1),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                ]),
                const SizedBox(height: 20),

                // Stats strip
                Row(children: [
                  Expanded(child: _StatTile(icon: Icons.topic_rounded, label: 'Topics',
                      value: '${subject.completedTopics}/${subject.totalTopics}',
                      bgColor: _blueLt.withOpacity(0.45))),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(icon: Icons.trending_up_rounded, label: 'Progress',
                      value: '${(subject.progress * 100).round()}%',
                      bgColor: _olive.withOpacity(0.65), isHighlight: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(icon: Icons.auto_graph_rounded, label: 'Avg',
                      value: '${subject.avgScore}%', bgColor: _gold.withOpacity(0.3))),
                ]),
                const SizedBox(height: 16),

                // Next-exam callout as a pill row (medication-modal style)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _outline, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _olive,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _outline, width: 1.5),
                      ),
                      child: const Icon(Icons.event_rounded, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('NEXT EXAM',
                          style: _gaegu(size: 11, weight: FontWeight.w700, color: _oliveDk)
                              .copyWith(letterSpacing: 0.7)),
                        Text(subject.nextExam,
                          style: const TextStyle(fontFamily: _bitroad, fontSize: 15, color: _brown)),
                      ],
                    )),
                  ]),
                ),
                const SizedBox(height: 20),

                _contentSections(),
                const SizedBox(height: 22),

                Row(children: [
                  Expanded(child: _SoftButton(
                    label: _deleting ? 'deleting...' : 'delete',
                    fill: _red, textColor: Colors.white,
                    onTap: _deleting ? () {} : _confirmDelete)),
                  const SizedBox(width: 10),
                  Expanded(child: _SoftButton(
                    label: 'edit', fill: _cream,
                    onTap: _deleting ? () {} : _openEdit)),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _SoftButton(
                    label: 'close', fill: _olive, textColor: Colors.white,
                    onTap: () => Navigator.of(context).pop())),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

//  SHARED WIDGETS (match dashboard_tab_improved)
class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool highlight;
  const _Pill({required this.icon, required this.label, required this.color, this.highlight = false});
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

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniPill({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _outline.withOpacity(0.25), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: _outline),
      const SizedBox(width: 4),
      Text(label, style: _gaegu(size: 10, weight: FontWeight.w700, color: _brown)),
    ]),
  );
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? _olive : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? _oliveDk : _outline.withOpacity(0.25), width: 1.5),
        boxShadow: selected
            ? [BoxShadow(color: _oliveDk.withOpacity(0.4), offset: const Offset(2, 2), blurRadius: 0)]
            : [BoxShadow(color: _outline.withOpacity(0.12), offset: const Offset(1, 1), blurRadius: 0)],
      ),
      child: Text(label,
        style: TextStyle(fontFamily: _bitroad, fontSize: 13,
          color: selected ? Colors.white : _brown)),
    ),
  );
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color bgColor;
  final bool isHighlight;
  const _StatTile({required this.icon, required this.label, required this.value,
    required this.bgColor, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    final textColor  = isHighlight ? Colors.white : _brown;
    final labelColor = isHighlight ? Colors.white.withOpacity(0.85) : _brownSoft;
    final iconBg     = isHighlight ? Colors.white.withOpacity(0.2) : Colors.white;
    final iconBorder = isHighlight ? Colors.white.withOpacity(0.25) : _outline.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline.withOpacity(0.15), width: 1),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.1),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: iconBorder, width: 1),
          ),
          child: Icon(icon, size: 15, color: isHighlight ? Colors.white : _brownLt),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
              style: TextStyle(fontFamily: _bitroad, fontSize: 17, color: textColor),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            Text(label.toUpperCase(),
              style: _gaegu(size: 10, weight: FontWeight.w700, color: labelColor).copyWith(letterSpacing: 0.5)),
          ],
        )),
      ]),
    );
  }
}

class _SoftButton extends StatelessWidget {
  final String label;
  final Color fill;
  final Color textColor;
  final VoidCallback onTap;
  const _SoftButton({required this.label, required this.fill, required this.onTap,
    this.textColor = _brown});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Text(label,
        style: _gaegu(size: 18, weight: FontWeight.w700, color: textColor)),
    ),
  );
}

//  MATERIAL ROW (subject detail modal)
class _MaterialRow extends StatelessWidget {
  final _MaterialUi mat;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _MaterialRow({required this.mat, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.18), width: 1.2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.1),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _mTerra.withOpacity(0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.2), width: 1),
            ),
            child: Icon(_iconForSource(mat.sourceType), size: 18, color: _brown),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mat.title,
                style: const TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text([
                _labelForSource(mat.sourceType),
                '${mat.wordCount} words',
                if (mat.createdAt != null) _relDate(mat.createdAt!),
              ].join(' · '),
                style: _gaegu(size: 11, color: _brownSoft, weight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.delete_outline_rounded, size: 18, color: _brownLt),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: _brownLt.withOpacity(0.6), size: 18),
        ]),
      ),
    );
  }
}

//  SESSION-NOTE ROW (subject detail modal)
class _SessionRow extends StatelessWidget {
  final _SessionNoteUi sess;
  final VoidCallback onTap;
  const _SessionRow({required this.sess, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      '${sess.durationMinutes} min',
      if (sess.startTime != null) _relDate(sess.startTime!),
      if (sess.topics.isNotEmpty) sess.topics.take(2).join(', '),
    ].join(' · ');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.18), width: 1.2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.1),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _mSage.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.2), width: 1),
            ),
            child: const Icon(Icons.edit_note_rounded, size: 18, color: _brown),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(sess.title,
                style: const TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(meta,
                style: _gaegu(size: 11, color: _brownSoft, weight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: _brownLt.withOpacity(0.6), size: 18),
        ]),
      ),
    );
  }
}

//  DECK ROW (subject detail modal)
class _DeckRow extends StatelessWidget {
  final _DeckUi deck;
  final VoidCallback onTap;
  const _DeckRow({required this.deck, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      '${deck.cardCount} card${deck.cardCount == 1 ? '' : 's'}',
      if (deck.updatedAt != null) _relDate(deck.updatedAt!),
      if (deck.description.isNotEmpty) deck.description,
    ].join(' · ');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.18), width: 1.2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.1),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _mSlate.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.2), width: 1),
            ),
            child: const Icon(Icons.style_rounded, size: 18, color: _brown),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(deck.name,
                style: const TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(meta,
                style: _gaegu(size: 11, color: _brownSoft, weight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: _brownLt.withOpacity(0.6), size: 18),
        ]),
      ),
    );
  }
}

//  QUIZ ROW (subject detail modal)
class _QuizRow extends StatelessWidget {
  final _QuizUi quiz;
  final VoidCallback onTap;
  const _QuizRow({required this.quiz, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = quiz.percentage.clamp(0.0, 100.0);
    final scoreColor = pct >= 80
      ? _mSage
      : pct >= 60
        ? _mButter
        : _mTerra.withOpacity(0.6);
    final meta = <String>[
      if (quiz.dateTaken != null) _relDate(quiz.dateTaken!),
      if (quiz.topics.isNotEmpty) quiz.topics.take(2).join(', '),
    ].join(' · ');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.18), width: 1.2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.1),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: scoreColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.2), width: 1),
            ),
            child: const Icon(Icons.quiz_rounded, size: 18, color: _brown),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(quiz.title,
                style: const TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(meta.isEmpty ? 'Completed quiz' : meta,
                style: _gaegu(size: 11, color: _brownSoft, weight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: scoreColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _outline.withOpacity(0.25), width: 1),
            ),
            child: Text('${pct.toStringAsFixed(0)}%',
              style: const TextStyle(fontFamily: _bitroad, fontSize: 12, color: _brown)),
          ),
          Icon(Icons.chevron_right_rounded, color: _brownLt.withOpacity(0.6), size: 18),
        ]),
      ),
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
        final opFactor = 0.06 + (idx % 5) * 0.018;
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
