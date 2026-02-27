import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

const _ombre1   = Color(0xFFFFFBF7);
const _ombre2   = Color(0xFFFFF8F3);
const _ombre3   = Color(0xFFFFF3EF);
const _ombre4   = Color(0xFFFEEDE9);
const _cardFill = Color(0xFFFFF8F4);
const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);
const _skyHdr   = Color(0xFF9DD4F0);
const _skyLt    = Color(0xFFB8E0F8);
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
const _goldLt   = Color(0xFFFFF0C0);
const _goldDk   = Color(0xFFD4B850);
const _sageHdr  = Color(0xFF90C8A0);
const _sageLt   = Color(0xFFB0D8B8);

const _iconMap = <String, IconData>{
  'book': Icons.menu_book_rounded,
  'science': Icons.science_rounded,
  'math': Icons.calculate_rounded,
  'code': Icons.code_rounded,
  'art': Icons.palette_rounded,
  'music': Icons.music_note_rounded,
  'language': Icons.translate_rounded,
  'history': Icons.history_edu_rounded,
  'health': Icons.favorite_rounded,
  'globe': Icons.public_rounded,
  'law': Icons.gavel_rounded,
  'finance': Icons.attach_money_rounded,
  'psychology': Icons.psychology_rounded,
  'engineering': Icons.engineering_rounded,
  'writing': Icons.edit_note_rounded,
  'film': Icons.movie_rounded,
};

IconData _iconFor(String? key) => _iconMap[key] ?? Icons.menu_book_rounded;

const _presetColors = <String>[
  '#9DD4F0', '#E8B0A8', '#A8D5A3', '#CDA8D8', '#F0A898',
  '#F0D878', '#90C8A0', '#E0B0C8', '#B8C8E8', '#D0C098',
  '#F8B890', '#A0D8D0', '#C8A0E0', '#E8D0A0', '#B0D0E8',
  '#D8B0B0',
];

Color _colorFromHex(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}


class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;
  String _sortBy = 'name'; // name, recent, proficiency
  String _search = '';
  final _searchCtrl = TextEditingController();
  late AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fetchSubjects();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSubjects() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get('/study/subjects');
      final data = resp.data is List ? resp.data as List : [];
      _subjects = data.map<Map<String, dynamic>>((s) => {
        'id': s['id']?.toString() ?? '',
        'name': s['name'] ?? 'Untitled',
        'code': s['code'] ?? '',
        'color': s['color'] ?? '#9DD4F0',
        'icon': s['icon'] ?? 'book',
        'proficiency': double.tryParse(s['current_proficiency']?.toString() ?? '0') ?? 0.0,
        'target': double.tryParse(s['target_proficiency']?.toString() ?? '100') ?? 100.0,
        'created_at': s['created_at'],
      }).toList();
    } catch (e) {
      debugPrint('Subjects fetch error: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
      _enterCtrl.forward(from: 0);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _subjects;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) =>
        s['name'].toString().toLowerCase().contains(q) ||
        s['code'].toString().toLowerCase().contains(q)).toList();
    }
    switch (_sortBy) {
      case 'recent':
        list.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        break;
      case 'proficiency':
        list.sort((a, b) => (b['proficiency'] as double).compareTo(a['proficiency'] as double));
        break;
      default:
        list.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    }
    return list;
  }

  Future<void> _createSubject(Map<String, dynamic> data) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/study/subjects', data: data);
      await _fetchSubjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Subject created!', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _greenHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create: $e', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _updateSubject(String id, Map<String, dynamic> data) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.put('/study/subjects/$id', data: data);
      await _fetchSubjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Subject updated!', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _greenHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: $e', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _deleteSubject(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: _cardFill,
        title: Text('Delete "$name"?', style: GoogleFonts.gaegu(
          fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
        content: Text(
          'This will permanently delete this subject and all its linked sessions, quizzes, and flashcards.',
          style: GoogleFonts.nunito(fontSize: 13, color: _brownLt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600, color: _brownLt)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _coralHdr,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Delete', style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = ref.read(apiServiceProvider);
      await api.delete('/study/subjects/$id');
      await _fetchSubjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"$name" deleted', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _greenHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: $e', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showSubjectDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final codeCtrl = TextEditingController(text: existing?['code'] ?? '');
    final targetCtrl = TextEditingController(
      text: (existing?['target'] ?? 100.0).toStringAsFixed(0));
    String selectedColor = existing?['color'] ?? '#9DD4F0';
    String selectedIcon = existing?['icon'] ?? 'book';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 420,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(20)),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _colorFromHex(selectedColor).withOpacity(0.3),
                      _colorFromHex(selectedColor).withOpacity(0.12)]),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _colorFromHex(selectedColor).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _colorFromHex(selectedColor).withOpacity(0.3))),
                      child: Icon(_iconFor(selectedIcon), size: 18,
                        color: _colorFromHex(selectedColor)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      isEdit ? 'Edit Subject' : 'New Subject',
                      style: GoogleFonts.gaegu(fontSize: 22,
                        fontWeight: FontWeight.w700, color: _brown))),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _outline.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.close_rounded, size: 16, color: _brownLt)),
                    ),
                  ]),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _fieldLabel('Subject Name *'),
                    const SizedBox(height: 6),
                    _textField(nameCtrl, 'e.g. Calculus II', maxLength: 100),
                    const SizedBox(height: 14),

                    _fieldLabel('Course Code'),
                    const SizedBox(height: 6),
                    _textField(codeCtrl, 'e.g. MATH 202', maxLength: 50),
                    const SizedBox(height: 14),

                    _fieldLabel('Target Proficiency (%)'),
                    const SizedBox(height: 6),
                    _textField(targetCtrl, '100', maxLength: 3,
                      keyboardType: TextInputType.number),
                    const SizedBox(height: 16),

                    _fieldLabel('Color'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: _presetColors.map((hex) {
                      final isSel = selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setDState(() => selectedColor = hex),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: _colorFromHex(hex),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSel ? _brown : _outline.withOpacity(0.1),
                              width: isSel ? 2.5 : 1),
                            boxShadow: isSel ? [BoxShadow(
                              color: _colorFromHex(hex).withOpacity(0.4),
                              blurRadius: 6)] : null),
                          child: isSel ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white) : null,
                        ),
                      );
                    }).toList()),
                    const SizedBox(height: 16),

                    _fieldLabel('Icon'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: _iconMap.entries.map((e) {
                      final isSel = selectedIcon == e.key;
                      return GestureDetector(
                        onTap: () => setDState(() => selectedIcon = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: isSel
                                ? _colorFromHex(selectedColor).withOpacity(0.2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel
                                  ? _colorFromHex(selectedColor)
                                  : _outline.withOpacity(0.08),
                              width: isSel ? 2 : 1)),
                          child: Icon(e.value, size: 16,
                            color: isSel
                                ? _colorFromHex(selectedColor) : _brownLt.withOpacity(0.5)),
                        ),
                      );
                    }).toList()),
                    const SizedBox(height: 20),

                    Row(children: [
                      if (isEdit) ...[
                        Expanded(child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _deleteSubject(existing['id'], existing['name']);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.15))),
                            child: Center(child: Text('Delete', style: GoogleFonts.nunito(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: Colors.red.withOpacity(0.7)))),
                          ),
                        )),
                        const SizedBox(width: 10),
                      ],
                      Expanded(flex: 2, child: GestureDetector(
                        onTap: () {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('Subject name is required',
                                style: GoogleFonts.nunito(fontSize: 12)),
                              backgroundColor: _coralHdr,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            ));
                            return;
                          }
                          final target = double.tryParse(targetCtrl.text) ?? 100.0;
                          final body = <String, dynamic>{
                            'name': nameCtrl.text.trim(),
                            'code': codeCtrl.text.trim().isNotEmpty
                                ? codeCtrl.text.trim() : null,
                            'color': selectedColor,
                            'icon': selectedIcon,
                            'target_proficiency': target.clamp(0, 100),
                          };
                          Navigator.pop(ctx);
                          if (isEdit) {
                            _updateSubject(existing['id'], body);
                          } else {
                            _createSubject(body);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              _colorFromHex(selectedColor),
                              _colorFromHex(selectedColor).withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _colorFromHex(selectedColor), width: 2),
                            boxShadow: [BoxShadow(
                              color: _colorFromHex(selectedColor).withOpacity(0.3),
                              blurRadius: 8, offset: const Offset(0, 3))]),
                          child: Center(child: Text(
                            isEdit ? 'Save Changes' : 'Create Subject',
                            style: GoogleFonts.gaegu(fontSize: 16,
                              fontWeight: FontWeight.w700, color: Colors.white))),
                        ),
                      )),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
    style: GoogleFonts.nunito(fontSize: 12,
      fontWeight: FontWeight.w700, color: _brownLt));

  Widget _textField(TextEditingController ctrl, String hint,
      {int? maxLength, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: GoogleFonts.nunito(fontSize: 13, color: _brown),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(fontSize: 13,
          color: _brownLt.withOpacity(0.35)),
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _outline.withOpacity(0.08))),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _outline.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _skyHdr.withOpacity(0.4), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }

  Widget _stag(double delay, Widget child) {
    return FadeTransition(
      opacity: _enterCtrl.drive(
        Tween<double>(begin: 0, end: 1).chain(
          CurveTween(curve: Interval(delay, (delay + 0.15).clamp(0, 1),
            curve: Curves.easeOut)))),
      child: SlideTransition(
        position: _enterCtrl.drive(
          Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).chain(
            CurveTween(curve: Interval(delay, (delay + 0.15).clamp(0, 1),
              curve: Curves.easeOut)))),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _ombre1,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _PawBgPainter())),

        SafeArea(
          child: RefreshIndicator(
            color: _outline,
            backgroundColor: _cardFill,
            onRefresh: _fetchSubjects,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _stag(0.0, Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _outline.withOpacity(0.08))),
                        child: Icon(Icons.arrow_back_rounded, size: 18, color: _brown)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subjects', style: GoogleFonts.gaegu(
                          fontSize: 28, fontWeight: FontWeight.w700,
                          color: _brown, height: 1.1)),
                        Text('${_subjects.length} subject${_subjects.length == 1 ? '' : 's'}',
                          style: GoogleFonts.nunito(fontSize: 12, color: _brownLt)),
                      ],
                    )),
                    GestureDetector(
                      onTap: () => _showSubjectDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_purpleLt, _purpleHdr]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _purpleDk, width: 2),
                          boxShadow: [BoxShadow(
                            color: _purpleDk.withOpacity(0.35),
                            offset: const Offset(0, 4), blurRadius: 10)]),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('New', style: GoogleFonts.gaegu(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    ),
                  ]),
                ))),

                SliverToBoxAdapter(child: _stag(0.08, Padding(
                  padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                  child: Row(children: [
                    Expanded(child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _outline.withOpacity(0.08), width: 1.5)),
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.nunito(fontSize: 12, color: _brown),
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          hintText: 'Search subjects...',
                          hintStyle: GoogleFonts.nunito(fontSize: 12,
                            color: _brownLt.withOpacity(0.35)),
                          prefixIcon: Icon(Icons.search_rounded, size: 16,
                            color: _brownLt.withOpacity(0.35)),
                          suffixIcon: _search.isNotEmpty ? GestureDetector(
                            onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
                            child: Icon(Icons.close_rounded, size: 14,
                              color: _brownLt.withOpacity(0.4)),
                          ) : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                      ),
                    )),
                    const SizedBox(width: 8),
                    _sortChip('name', 'A-Z', Icons.sort_by_alpha_rounded),
                    const SizedBox(width: 4),
                    _sortChip('recent', 'New', Icons.schedule_rounded),
                    const SizedBox(width: 4),
                    _sortChip('proficiency', 'Skill', Icons.trending_up_rounded),
                  ]),
                ))),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                _loading
                  ? SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(
                        strokeWidth: 2, color: _purpleHdr)))
                  : filtered.isEmpty
                    ? SliverFillRemaining(child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            _search.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.library_books_rounded,
                            size: 48, color: _brownLt.withOpacity(0.25)),
                          const SizedBox(height: 10),
                          Text(
                            _search.isNotEmpty
                                ? 'No matching subjects'
                                : 'No subjects yet',
                            style: GoogleFonts.gaegu(fontSize: 18,
                              fontWeight: FontWeight.w700, color: _brownLt)),
                          if (_search.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: GestureDetector(
                                onTap: () => _showSubjectDialog(),
                                child: Text('Tap + to create your first!',
                                  style: GoogleFonts.nunito(fontSize: 13,
                                    color: _purpleHdr, fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ])))
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.88),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _stag(0.12 + i * 0.04,
                              _SubjectCard(
                                subject: filtered[i],
                                onTap: () => _showSubjectDialog(existing: filtered[i]),
                                onDelete: () => _deleteSubject(
                                  filtered[i]['id'], filtered[i]['name']),
                              )),
                            childCount: filtered.length),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sortChip(String key, String label, IconData icon) {
    final sel = _sortBy == key;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _purpleHdr.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? _purpleHdr.withOpacity(0.3) : _outline.withOpacity(0.08),
            width: sel ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: sel ? _purpleHdr : _brownLt.withOpacity(0.4)),
          const SizedBox(width: 3),
          Text(label, style: GoogleFonts.nunito(fontSize: 10,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? _purpleDk : _brownLt)),
        ]),
      ),
    );
  }
}


class _SubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _SubjectCard({required this.subject, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = subject['name'] as String;
    final code = subject['code'] as String;
    final color = _colorFromHex(subject['color'] as String);
    final icon = _iconFor(subject['icon'] as String?);
    final prof = (subject['proficiency'] as double).clamp(0.0, 100.0);
    final target = (subject['target'] as double).clamp(0.0, 100.0);
    final progress = target > 0 ? (prof / target).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline.withOpacity(0.08), width: 1.5),
          boxShadow: [BoxShadow(
            color: color.withOpacity(0.08),
            offset: const Offset(0, 4), blurRadius: 12)]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  color.withOpacity(0.25), color.withOpacity(0.12)])),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.gaegu(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _brown),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                    if (code.isNotEmpty)
                      Text(code, style: GoogleFonts.nunito(fontSize: 10,
                        color: _brownLt.withOpacity(0.6))),
                  ],
                )),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 16,
                    color: _brownLt.withOpacity(0.4)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                  color: _cardFill,
                  onSelected: (v) {
                    if (v == 'edit') onTap();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Row(children: [
                      Icon(Icons.edit_rounded, size: 14, color: _skyHdr),
                      const SizedBox(width: 8),
                      Text('Edit', style: GoogleFonts.nunito(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _brown)),
                    ])),
                    PopupMenuItem(value: 'delete', child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 14,
                        color: Colors.red.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Text('Delete', style: GoogleFonts.nunito(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.red.withOpacity(0.6))),
                    ])),
                  ],
                ),
              ]),
            ),

            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    SizedBox(
                      width: 46, height: 46,
                      child: Stack(alignment: Alignment.center, children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 4,
                          backgroundColor: color.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation(color)),
                        Text('${prof.toInt()}%', style: GoogleFonts.gaegu(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Proficiency', style: GoogleFonts.nunito(
                          fontSize: 10, color: _brownLt.withOpacity(0.5))),
                        const SizedBox(height: 2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: color.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(color)),
                        ),
                        const SizedBox(height: 3),
                        Text('${prof.toInt()} / ${target.toInt()}%',
                          style: GoogleFonts.nunito(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: _brownLt)),
                      ],
                    )),
                  ]),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: prof >= target && target > 0
                          ? _greenHdr.withOpacity(0.1)
                          : color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        prof >= target && target > 0
                            ? Icons.check_circle_rounded
                            : Icons.trending_up_rounded,
                        size: 11,
                        color: prof >= target && target > 0 ? _greenDk : color),
                      const SizedBox(width: 4),
                      Text(
                        prof >= target && target > 0
                            ? 'Target reached!'
                            : '${(target - prof).toInt()}% to goal',
                        style: GoogleFonts.nunito(fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: prof >= target && target > 0 ? _greenDk : _brownLt)),
                    ]),
                  ),
                ],
              ),
            )),
          ]),
        ),
      ),
    );
  }
}


class _PawBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Vertical ombré gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [_ombre1, _ombre2, _ombre3, _ombre4],
      stops: const [0.0, 0.3, 0.65, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Subtle pawprints
    final pawPaint = Paint()..color = _outline.withOpacity(0.018);
    const pawSize = 14.0;
    for (var y = 30.0; y < size.height; y += 80) {
      for (var x = 20.0; x < size.width; x += 90) {
        final ox = x + (y % 160 == 30 ? 40 : 0);
        // Pad
        canvas.drawOval(Rect.fromCenter(
          center: Offset(ox, y), width: pawSize, height: pawSize * 0.85), pawPaint);
        // Toes
        for (var i = -1; i <= 1; i++) {
          canvas.drawCircle(
            Offset(ox + i * (pawSize * 0.32), y - pawSize * 0.55),
            pawSize * 0.2, pawPaint);
        }
        canvas.drawCircle(
          Offset(ox + pawSize * 0.48, y - pawSize * 0.35),
          pawSize * 0.18, pawPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
