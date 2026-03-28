//  CEREBRO — Flashcard Screen
//  3 Tabs: Review · All Cards · Generate
//  Flip animation · SM-2 spaced repetition · auto-generation
//  + Deck management (create/switch/edit/delete decks)
//  Cozy Pocket Love aesthetic

import 'package:flutter/material.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/widgets/upload_notes_modal.dart';


bool get _darkMode =>
    CerebroTheme.brightnessNotifier.value == Brightness.dark;

Color get _ombre1 => _darkMode ? const Color(0xFF191513) : const Color(0xFFFFFBF7);
Color get _ombre2 => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFF8F3);
Color get _ombre3 => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF3EF);
Color get _ombre4 => _darkMode ? const Color(0xFF312821) : const Color(0xFFFEEDE9);
Color get _cardFill => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF8F4);
Color get _outline => _darkMode ? const Color(0xFFAD7F58) : const Color(0xFF6E5848);
Color get _brown => _darkMode ? const Color(0xFFF2E1CA) : const Color(0xFF4E3828);
Color get _brownLt => _darkMode ? const Color(0xFFDBB594) : const Color(0xFF7A5840);
const _coralHdr = Color(0xFFE8B8A8); // softer terracotta
Color get _coralLt => const Color(0xFFF2CFC2);
const _greenHdr = Color(0xFFB5C4A0); // muted sage
Color get _greenLt => const Color(0xFFCCD8B8);
Color get _greenDk => const Color(0xFF98A869);
const _goldHdr  = Color(0xFFE8D4A0); // muted butter
Color get _goldLt => const Color(0xFFF4E6BE);
const _purpleHdr = Color(0xFFC9B8D9); // muted lav
Color get _purpleLt => const Color(0xFFDCCEE6);
const _skyHdr   = Color(0xFFB6CBD6); // muted slate
Color get _skyLt => const Color(0xFFCCDCE4);
Color get _sageHdr => const Color(0xFFB5C4A0);
// _pawClr — mode-aware: pink in light, barely-lifted BROWN-2 in dark
Color get _pawClr => _darkMode ? const Color(0xFF231D18) : const Color(0xFFEAD0CE); // muted blush
Color get _pinkHdr => const Color(0xFFEAD0CE);
const _presetColors = [
  '#B5C4A0', '#E8B8A8', '#B6CBD6', '#C9B8D9',
  '#E8D4A0', '#EAD0CE', '#B5C4A0', '#CCD8B8',
];

class FlashcardScreen extends ConsumerStatefulWidget {
  /// When set, the screen will auto-select this deck on first load
  /// (used by deep-links from the Subjects page).
  final String? initialDeckId;
  const FlashcardScreen({super.key, this.initialDeckId});
  @override ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _decks = [];
  String? _selectedDeckId;
  String _selectedDeckName = 'All Cards';

  List<Map<String, dynamic>> _allCards = [];
  List<Map<String, dynamic>> _dueCards = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;

  int _reviewIdx = 0;
  bool _isFlipped = false;
  bool _showResult = false;
  int _sessionCorrect = 0;
  int _sessionTotal = 0;
  bool _reviewDone = false;

  final _frontCtrl = TextEditingController();
  final _backCtrl = TextEditingController();
  String? _selectedSubjectId;

  bool _generating = false;
  List<String> _selectedMaterialIds = [];
  final Set<String> _selectedGenTopics = {};
  int _genCount = 10;

  // Why a separate per-tab state block instead of reusing _selectedSubjectId:
  // _selectedSubjectId is the "default subject for new cards" — this one is
  // purely a display filter and users expect those to be independent.
  String _cardsFilterSubjectId = 'all';       // 'all' | subject uuid | 'none'
  String? _cardsFilterTopic;                  // null = all topics
  final TextEditingController _cardsSearchCtrl = TextEditingController();
  String _cardsSearch = '';
  int _cardsPage = 1;
  static const int _cardsPageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    // Pre-seed so the first /study/decks response still respects the deep-link.
    if (widget.initialDeckId != null) {
      _selectedDeckId = widget.initialDeckId;
    }
    _loadDecks();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _frontCtrl.dispose();
    _backCtrl.dispose();
    _cardsSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.get('/study/decks');
      final list = (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _decks = list;
        // If a deck was pre-seeded (deep-link), resolve its name from the fetched list.
        if (_selectedDeckId != null) {
          final match = list.firstWhere(
            (d) => d['id']?.toString() == _selectedDeckId,
            orElse: () => const <String, dynamic>{},
          );
          if (match.isNotEmpty) {
            _selectedDeckName = (match['name'] as String?) ?? 'Deck';
          } else if (list.isNotEmpty) {
            // Seeded id not found — fall back to first deck.
            _selectedDeckId = list[0]['id']?.toString();
            _selectedDeckName = (list[0]['name'] as String?) ?? 'Deck';
          }
        } else if (list.isNotEmpty) {
          // Auto-select first deck if none selected.
          _selectedDeckId = list[0]['id']?.toString();
          _selectedDeckName = (list[0]['name'] as String?) ?? 'Deck';
        }
      });
    } catch (e) {
      // Decks endpoint may not exist yet, fall back to no-deck mode
      setState(() => _decks = []);
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = ref.read(apiServiceProvider);
    try {
      // If a deck is selected, load deck-scoped cards
      final String cardsUrl;
      final String dueUrl;
      if (_selectedDeckId != null) {
        cardsUrl = '/study/decks/$_selectedDeckId';
        dueUrl = '/study/decks/$_selectedDeckId/due';
      } else {
        cardsUrl = '/study/flashcards';
        dueUrl = '/study/flashcards?due_only=true';
      }

      final results = await Future.wait<dynamic>([
        api.get(cardsUrl),
        api.get(dueUrl),
        api.get('/study/materials?limit=100'),
        api.get('/study/subjects'),
      ]);

      // Parse cards — deck endpoint returns {deck info + flashcards list}
      List<Map<String, dynamic>> all;
      if (_selectedDeckId != null) {
        final deckData = results[0].data as Map<String, dynamic>? ?? {};
        all = (deckData['flashcards'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      } else {
        all = (results[0].data as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
      final due = (results[1].data as List?)?.cast<Map<String, dynamic>>() ?? [];
      final mats = (results[2].data as List?)?.cast<Map<String, dynamic>>() ?? [];
      final subs = (results[3].data as List?)?.cast<Map<String, dynamic>>() ?? [];

      setState(() {
        _allCards = all;
        _dueCards = due;
        _materials = mats;
        _subjects = subs;
        _loading = false;
        _reviewIdx = 0;
        _isFlipped = false;
        _showResult = false;
        _reviewDone = _dueCards.isEmpty;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  //  BUILD

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // Match Quiz Hub / Subjects / Subject Detail gutter:
    //   contentW = screenW * 0.94 clamp 360..1500, plus inner 16px padding.
    // The old 0.92/1200 pair produced noticeably different side margins from
    // its sibling screens; keeping these four widths in sync is worth more
    // than squeezing 20px of canvas width.
    final contentW = (screenW * 0.94).clamp(360.0, 1500.0);
    return Scaffold(
      body: Stack(children: [
        // Base gradient
        Positioned.fill(child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [_ombre1, _ombre2, _ombre3, _ombre4],
            ),
          ),
        )),
        // Paw print overlay — matches subjects/resources/calendar
        Positioned.fill(child: IgnorePointer(
          child: CustomPaint(painter: _PawPrintBg()),
        )),
        SafeArea(
          child: Center(
            child: SizedBox(
              width: contentW,
              // Inner 16px padding matches the ListView padding on Quiz Hub
              // and the Padding wrapper on Subjects + Subject Detail. Without
              // this, contentW alone leaves the page hugging the screen
              // edges and feeling cramped.
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  const SizedBox(height: 16),
                  _header(),
                  _deckSelector(),
                  _tabBar(),
                  Expanded(
                    child: _loading
                      ? Center(child: CircularProgressIndicator(color: _outline))
                      : TabBarView(
                          controller: _tabCtrl,
                          children: [_reviewTab(), _allCardsTab(), _generateTab()],
                        ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _backBtn(),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flashcards',
              style: TextStyle(fontFamily: 'Bitroad', fontSize: 26,
                  color: _brown, height: 1.15)),
            const SizedBox(height: 2),
            Text('flip, recall, mark how you went~',
              style: GoogleFonts.gaegu(fontSize: 15, fontWeight: FontWeight.w600,
                  color: _brownLt, height: 1.3)),
          ],
        )),
        _statChip(Icons.layers_rounded, '${_allCards.length}', _sageHdr),
        const SizedBox(width: 6),
        _statChip(Icons.schedule_rounded, '${_dueCards.length} due', _coralHdr),
      ]),
    );
  }

  Widget _backBtn() => GestureDetector(
    onTap: () => Navigator.of(context).pop(),
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Icon(Icons.arrow_back_rounded, color: _brown, size: 20),
    ),
  );

  Widget _statChip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _outline, width: 1.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: _outline),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
    ]),
  );

  //  DECK SELECTOR — horizontal scrolling chips

  Widget _deckSelector() {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        children: [
          // "Manage Decks" button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _showDeckManager,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _goldHdr.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outline.withOpacity(0.45), width: 1.5),
                  boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                    offset: const Offset(3, 3), blurRadius: 0)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.settings_rounded, size: 16, color: _brown),
                  const SizedBox(width: 4),
                  Text('Decks', style: GoogleFonts.gaegu(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
                ]),
              ),
            ),
          ),
          // Upload material button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _pickAndUploadFile(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _coralHdr.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outline.withOpacity(0.45), width: 1.5),
                  boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                    offset: const Offset(3, 3), blurRadius: 0)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.upload_file_rounded, size: 16, color: _brown),
                  const SizedBox(width: 4),
                  Text('Upload', style: GoogleFonts.gaegu(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
                ]),
              ),
            ),
          ),
          // Deck chips
          ..._decks.map((deck) {
            final id = deck['id']?.toString();
            final isSelected = id == _selectedDeckId;
            final color = _colorFromHex(deck['color'] ?? '#A8D5A3');
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDeckId = id;
                    _selectedDeckName = deck['name'] ?? 'Deck';
                  });
                  _loadData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.5) : _cardFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _outline.withOpacity(0.6) : _outline.withOpacity(0.35),
                      width: isSelected ? 2 : 1.5,
                    ),
                    boxShadow: [BoxShadow(
                      color: _outline.withOpacity(0.18),
                      offset: const Offset(3, 3),
                      blurRadius: 0,
                    )],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      deck['name'] ?? 'Deck',
                      style: GoogleFonts.gaegu(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: _brown,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${deck['card_count'] ?? 0}',
                      style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: _brownLt,
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _colorFromHex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  //  DECK MANAGER — create / edit / delete decks

  void _showDeckManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: _outline, width: 3),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // Title row
              Row(children: [
                Text('Your Decks', style: GoogleFonts.gaegu(
                  fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreateDeckDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _greenHdr.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _outline, width: 2),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 18, color: _brown),
                      const SizedBox(width: 4),
                      Text('New Deck', style: GoogleFonts.gaegu(
                        fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Deck list
              Expanded(
                child: _decks.isEmpty
                  ? Center(child: Text('No decks yet. Create one!',
                      style: GoogleFonts.nunito(fontSize: 14, color: _brownLt)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _decks.length,
                      itemBuilder: (ctx, i) => _deckManagerTile(_decks[i], ctx),
                    ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _deckManagerTile(Map<String, dynamic> deck, BuildContext sheetCtx) {
    final color = _colorFromHex(deck['color'] ?? '#A8D5A3');
    final count = deck['card_count'] ?? 0;
    final due = deck['due_count'] ?? 0;
    final mastery = ((deck['mastery_pct'] ?? 0) as num).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline, width: 2),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline, width: 1.5),
          ),
          child: Center(child: Text('$count', style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: _brown))),
        ),
        title: Text(deck['name'] ?? 'Deck', style: GoogleFonts.gaegu(
          fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
        subtitle: Row(children: [
          Text('$due due', style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: due > 0 ? _coralHdr : _brownLt)),
          const SizedBox(width: 8),
          Text('$mastery% mastery', style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w600, color: _greenDk)),
        ]),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: _brownLt),
          color: _cardFill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _outline, width: 2),
          ),
          onSelected: (action) {
            Navigator.pop(sheetCtx);
            if (action == 'edit') _showEditDeckDialog(deck);
            if (action == 'delete') _deleteDeck(deck);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'edit', child: Row(children: [
              Icon(Icons.edit_rounded, size: 18, color: _brownLt),
              const SizedBox(width: 8),
              Text('Edit', style: GoogleFonts.nunito(fontSize: 14, color: _brown)),
            ])),
            PopupMenuItem(value: 'delete', child: Row(children: [
              Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade300),
              const SizedBox(width: 8),
              Text('Delete', style: GoogleFonts.nunito(fontSize: 14, color: Colors.red.shade400)),
            ])),
          ],
        ),
        onTap: () {
          Navigator.pop(sheetCtx);
          setState(() {
            _selectedDeckId = deck['id']?.toString();
            _selectedDeckName = deck['name'] ?? 'Deck';
          });
          _loadData();
        },
      ),
    );
  }

  void _showCreateDeckDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedColor = '#A8D5A3';
    // Default subject: whatever subject filter the user has active on the
    // Flashcards page, so "New Deck" while filtered to Data Structures
    // pre-selects Data Structures. Falls back to null ("Unsorted") if the
    // user hasn't picked a subject filter yet.
    String? selectedSubjectId = _selectedSubjectId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _outline, width: 3),
      ),
      title: Text('New Deck', style: GoogleFonts.gaegu(
        fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _inputField(nameCtrl, 'Deck Name'),
        const SizedBox(height: 12),
        _inputField(descCtrl, 'Description (optional)'),
        const SizedBox(height: 12),
        // Subject picker — wires the deck to a subject so Subject Detail
        // can filter decks by subject_id. Previously omitted, which is
        // why decks showed up as "0" on every subject detail view.
        if (_subjects.isNotEmpty) DropdownButtonFormField<String?>(
          value: selectedSubjectId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Subject (optional)',
            labelStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _outline, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _outline, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _outline, width: 2.2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('No subject',
                style: GoogleFonts.nunito(
                  fontSize: 14, fontStyle: FontStyle.italic, color: _brownLt)),
            ),
            ..._subjects.map((s) => DropdownMenuItem<String?>(
              value: s['id']?.toString(),
              child: Text(s['name'] ?? '',
                style: GoogleFonts.nunito(fontSize: 14, color: _brown),
                overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (v) => setD(() => selectedSubjectId = v),
        ),
        if (_subjects.isNotEmpty) const SizedBox(height: 12),
        // Color picker
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Color:', style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: _presetColors.map((c) {
          final isSelected = c == selectedColor;
          return GestureDetector(
            onTap: () => setD(() => selectedColor = c),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _colorFromHex(c),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? _outline : _outline.withOpacity(0.3),
                  width: isSelected ? 3 : 1.5,
                ),
              ),
              child: isSelected
                ? Icon(Icons.check_rounded, size: 18, color: _brown)
                : null,
            ),
          );
        }).toList()),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.gaegu(fontSize: 18, color: _brownLt))),
        TextButton(onPressed: () async {
          if (nameCtrl.text.trim().isEmpty) return;
          final api = ref.read(apiServiceProvider);
          try {
            await api.post('/study/decks', data: {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'color': selectedColor,
              // Only send subject_id if one was picked — null is a valid
              // "no subject" value server-side but sending the key at all
              // is cleaner when there's a value.
              if (selectedSubjectId != null) 'subject_id': selectedSubjectId,
            });
            if (mounted) Navigator.pop(ctx);
            _loadDecks();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Create failed: $e')));
          }
        }, child: Text('Create', style: GoogleFonts.gaegu(
          fontSize: 18, fontWeight: FontWeight.w700, color: _greenDk))),
      ],
    )));
  }

  void _showEditDeckDialog(Map<String, dynamic> deck) {
    final nameCtrl = TextEditingController(text: deck['name'] ?? '');
    final descCtrl = TextEditingController(text: deck['description'] ?? '');
    String selectedColor = deck['color'] ?? '#A8D5A3';
    // Pre-seed with the deck's current subject_id so existing orphan decks
    // (created before subject_id was surfaced in the UI) can be assigned
    // to a subject from the edit dialog. Works with the matching Pydantic
    // FlashcardDeckUpdate.subject_id field added server-side.
    String? selectedSubjectId = deck['subject_id']?.toString();
    final initialSubjectId = selectedSubjectId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _outline, width: 3),
      ),
      title: Text('Edit Deck', style: GoogleFonts.gaegu(
        fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _inputField(nameCtrl, 'Deck Name'),
        const SizedBox(height: 12),
        _inputField(descCtrl, 'Description'),
        const SizedBox(height: 12),
        if (_subjects.isNotEmpty) DropdownButtonFormField<String?>(
          value: selectedSubjectId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Subject',
            labelStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _outline, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _outline, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _outline, width: 2.2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('No subject',
                style: GoogleFonts.nunito(
                  fontSize: 14, fontStyle: FontStyle.italic, color: _brownLt)),
            ),
            ..._subjects.map((s) => DropdownMenuItem<String?>(
              value: s['id']?.toString(),
              child: Text(s['name'] ?? '',
                style: GoogleFonts.nunito(fontSize: 14, color: _brown),
                overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (v) => setD(() => selectedSubjectId = v),
        ),
        if (_subjects.isNotEmpty) const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Color:', style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: _presetColors.map((c) {
          final isSelected = c == selectedColor;
          return GestureDetector(
            onTap: () => setD(() => selectedColor = c),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _colorFromHex(c),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? _outline : _outline.withOpacity(0.3),
                  width: isSelected ? 3 : 1.5,
                ),
              ),
              child: isSelected
                ? Icon(Icons.check_rounded, size: 18, color: _brown)
                : null,
            ),
          );
        }).toList()),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.gaegu(fontSize: 18, color: _brownLt))),
        TextButton(onPressed: () async {
          if (nameCtrl.text.trim().isEmpty) return;
          final api = ref.read(apiServiceProvider);
          try {
            // Build the patch body: only include subject_id if it changed
            // so we don't accidentally clobber it on no-op edits. When it
            // did change — including to null — send it explicitly so the
            // server's exclude_unset respects the intent.
            final body = <String, dynamic>{
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'color': selectedColor,
            };
            if (selectedSubjectId != initialSubjectId) {
              body['subject_id'] = selectedSubjectId;
            }
            await api.put('/study/decks/${deck['id']}', data: body);
            if (mounted) Navigator.pop(ctx);
            _loadDecks();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Update failed: $e')));
          }
        }, child: Text('Save', style: GoogleFonts.gaegu(
          fontSize: 18, fontWeight: FontWeight.w700, color: _greenDk))),
      ],
    )));
  }

  Future<void> _deleteDeck(Map<String, dynamic> deck) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _outline, width: 3),
      ),
      title: Text('Delete "${deck['name']}"?', style: GoogleFonts.gaegu(
        fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
      content: Text('This will delete the deck and all its cards. This cannot be undone.',
        style: GoogleFonts.nunito(fontSize: 14, color: _brownLt)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: GoogleFonts.gaegu(fontSize: 18, color: _brownLt))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete', style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red))),
      ],
    ));
    if (confirm == true) {
      final api = ref.read(apiServiceProvider);
      try {
        await api.delete('/study/decks/${deck['id']}');
        // If we deleted the selected deck, select the first remaining one
        if (_selectedDeckId == deck['id']?.toString()) {
          _selectedDeckId = null;
          _selectedDeckName = 'All Cards';
        }
        _loadDecks();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 10, 4, 4),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline, width: 2),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _purpleHdr.withOpacity(0.4),
          borderRadius: BorderRadius.circular(11),
        ),
        labelStyle: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w400),
        labelColor: _brown,
        unselectedLabelColor: _brownLt,
        dividerHeight: 0,
        tabs: const [
          Tab(text: 'Review'),
          Tab(text: 'All Cards'),
          Tab(text: 'Generate'),
        ],
      ),
    );
  }


  //  TAB 1: REVIEW (flip cards + grade)

  Widget _reviewTab() {
    if (_dueCards.isEmpty && _allCards.isEmpty) {
      return _emptyState(
        icon: Icons.style_rounded,
        title: 'No flashcards yet',
        subtitle: 'Go to the Generate tab to create cards from your study materials!',
      );
    }

    if (_reviewDone) {
      return _reviewSummary();
    }

    final cards = _dueCards.isNotEmpty ? _dueCards : _allCards;
    if (_reviewIdx >= cards.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _reviewDone = true);
      });
      return const SizedBox();
    }

    final card = cards[_reviewIdx];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
      child: Column(children: [
        // Progress
        Text(
          'Card ${_reviewIdx + 1} of ${cards.length}',
          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (_reviewIdx + 1) / cards.length,
          backgroundColor: _outline.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation(_purpleHdr),
          borderRadius: BorderRadius.circular(8),
          minHeight: 6,
        ),
        const SizedBox(height: 16),

        // The flip card
        Expanded(child: _flipCard(card)),

        const SizedBox(height: 16),

        // Bottom controls
        if (!_isFlipped)
          _bigButton('Tap card to flip', _greenDk, () => setState(() => _isFlipped = true))
        else
          _gradeButtons(card),
      ]),
    );
  }

  Widget _flipCard(Map<String, dynamic> card) {
    return GestureDetector(
      onTap: () => setState(() => _isFlipped = !_isFlipped),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) {
          final rotate = Tween(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut),
          );
          return FadeTransition(opacity: anim, child: ScaleTransition(scale: rotate, child: child));
        },
        child: Container(
          key: ValueKey(_isFlipped),
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _isFlipped ? _purpleLt.withOpacity(0.3) : _cardFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outline, width: 2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
              offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: _isFlipped ? _purpleHdr : _goldHdr,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isFlipped ? 'Answer' : 'Question',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _brown),
                ),
              ),
              const SizedBox(height: 20),
              // Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      _isFlipped ? (card['back_text'] ?? '') : (card['front_text'] ?? ''),
                      style: GoogleFonts.nunito(
                        fontSize: _isFlipped ? 18 : 20,
                        fontWeight: _isFlipped ? FontWeight.w600 : FontWeight.w700,
                        color: _brown,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Tags
              if ((card['tags'] as List?)?.isNotEmpty == true)
                Wrap(
                  spacing: 6,
                  children: (card['tags'] as List).take(3).map<Widget>((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _sageHdr.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(t.toString(), style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
                  )).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradeButtons(Map<String, dynamic> card) {
    return Row(children: [
      Expanded(child: _gradeBtn('Again', Icons.refresh_rounded, Colors.red.shade300, 1, card)),
      const SizedBox(width: 8),
      Expanded(child: _gradeBtn('Hard', Icons.sentiment_dissatisfied_rounded, _coralHdr, 2, card)),
      const SizedBox(width: 8),
      Expanded(child: _gradeBtn('Good', Icons.sentiment_satisfied_rounded, _goldHdr, 4, card)),
      const SizedBox(width: 8),
      Expanded(child: _gradeBtn('Easy', Icons.sentiment_very_satisfied_rounded, _greenHdr, 5, card)),
    ]);
  }

  Widget _gradeBtn(String label, IconData icon, Color color, int quality, Map<String, dynamic> card) {
    return GestureDetector(
      onTap: () => _submitReview(card, quality),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline, width: 2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
            offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _brown, size: 22),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.gaegu(fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
        ]),
      ),
    );
  }

  Future<void> _submitReview(Map<String, dynamic> card, int quality) async {
    final api = ref.read(apiServiceProvider);
    try {
      await api.post('/study/flashcards/${card['id']}/review', data: {'quality': quality});
      setState(() {
        _sessionTotal++;
        if (quality >= 3) _sessionCorrect++;
        _reviewIdx++;
        _isFlipped = false;
        if (_reviewIdx >= (_dueCards.isNotEmpty ? _dueCards.length : _allCards.length)) {
          _reviewDone = true;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review failed: $e')),
        );
      }
    }
  }

  Widget _reviewSummary() {
    final pct = _sessionTotal > 0 ? (_sessionCorrect / _sessionTotal * 100).round() : 0;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline, width: 2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
            offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _sessionTotal == 0 ? Icons.check_circle_rounded : Icons.celebration_rounded,
            size: 60, color: _greenHdr,
          ),
          const SizedBox(height: 12),
          Text(
            _sessionTotal == 0 ? 'All caught up!' : 'Session complete!',
            style: GoogleFonts.gaegu(fontSize: 28, fontWeight: FontWeight.w700, color: _brown),
          ),
          const SizedBox(height: 8),
          if (_sessionTotal > 0) ...[
            Text(
              '$_sessionCorrect / $_sessionTotal correct ($pct%)',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: _brownLt),
            ),
            const SizedBox(height: 4),
            Text(
              '+${_sessionTotal * 5} XP earned',
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: _greenDk),
            ),
          ] else
            Text(
              'No cards due for review right now.\nCome back later or review all cards!',
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: _brownLt),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 20),
          Row(children: [
            if (_allCards.isNotEmpty)
              Expanded(child: _bigButton('Review All', _skyHdr, () {
                setState(() {
                  _dueCards = [];
                  _reviewIdx = 0;
                  _isFlipped = false;
                  _reviewDone = false;
                  _sessionCorrect = 0;
                  _sessionTotal = 0;
                });
              })),
            if (_allCards.isNotEmpty) const SizedBox(width: 10),
            Expanded(child: _bigButton('Done', _greenHdr, () => Navigator.of(context).pop())),
          ]),
        ]),
      ),
    );
  }


  //  TAB 2: ALL CARDS (browse + create + delete)

  //
  // A card is kept by the filter if all of the following match:
  //  - subject filter ('all' / uuid / 'none' for subject-less cards)
  //  - topic filter (matches any tag or topic_refs entry, case-insensitive)
  //  - search query (matches front_text or back_text, case-insensitive)
  //
  // We compute the filtered list fresh on every build — the lists are
  // short enough that memoization would cost more than it saves, and
  // avoiding a second source of truth keeps pagination + edit-invalidation
  // trivially correct.
  List<Map<String, dynamic>> get _filteredCards {
    final q = _cardsSearch.trim().toLowerCase();
    return _allCards.where((c) {
      // Subject filter
      if (_cardsFilterSubjectId == 'none') {
        if (c['subject_id'] != null && c['subject_id'].toString().isNotEmpty) return false;
      } else if (_cardsFilterSubjectId != 'all') {
        if (c['subject_id']?.toString() != _cardsFilterSubjectId) return false;
      }
      // Topic filter
      if (_cardsFilterTopic != null && _cardsFilterTopic!.isNotEmpty) {
        final t = _cardsFilterTopic!.toLowerCase();
        final tags = (c['tags'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? const [];
        final refs = (c['topic_refs'] as List?)
            ?.map((e) => (e is Map ? (e['name'] ?? '').toString() : e.toString()).toLowerCase()).toList()
            ?? const [];
        if (!tags.contains(t) && !refs.contains(t)) return false;
      }
      // Search filter
      if (q.isNotEmpty) {
        final front = (c['front_text'] ?? '').toString().toLowerCase();
        final back = (c['back_text'] ?? '').toString().toLowerCase();
        if (!front.contains(q) && !back.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  int get _cardsTotalPages {
    final n = _filteredCards.length;
    if (n == 0) return 1;
    return ((n - 1) ~/ _cardsPageSize) + 1;
  }

  List<Map<String, dynamic>> _pagedCards(List<Map<String, dynamic>> list) {
    final tp = _cardsTotalPages;
    final page = _cardsPage.clamp(1, tp);
    final start = (page - 1) * _cardsPageSize;
    final end = (start + _cardsPageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  // Topic universe — union of tags + topic_refs across all cards.
  // Used to populate the topic filter dropdown. Case-normalized so
  // "Photosynthesis" and "photosynthesis" collapse into one chip.
  List<String> get _cardsTopicUniverse {
    final seen = <String, String>{}; // normalized -> display
    for (final c in _allCards) {
      for (final t in (c['tags'] as List?) ?? const []) {
        final s = t.toString();
        final k = s.toLowerCase();
        if (k.isNotEmpty) seen.putIfAbsent(k, () => s);
      }
      for (final r in (c['topic_refs'] as List?) ?? const []) {
        final name = (r is Map ? (r['name'] ?? '').toString() : r.toString());
        final k = name.toLowerCase();
        if (k.isNotEmpty) seen.putIfAbsent(k, () => name);
      }
    }
    final out = seen.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  Widget _allCardsTab() {
    final filtered = _filteredCards;
    final tp = _cardsTotalPages;
    final paged = _pagedCards(filtered);
    final topics = _cardsTopicUniverse;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Row(children: [
          // Search field — lightweight, inline, doesn't demand its own row
          Expanded(child: Container(
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outline.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.15),
                offset: const Offset(2, 2), blurRadius: 0)],
            ),
            child: TextField(
              controller: _cardsSearchCtrl,
              style: GoogleFonts.nunito(fontSize: 13, color: _brown),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: _brownLt),
                hintText: 'Search cards…',
                hintStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: _cardsSearch.isEmpty ? null : IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: _brownLt),
                  onPressed: () {
                    _cardsSearchCtrl.clear();
                    setState(() { _cardsSearch = ''; _cardsPage = 1; });
                  },
                ),
              ),
              onChanged: (v) => setState(() { _cardsSearch = v; _cardsPage = 1; }),
            ),
          )),
          const SizedBox(width: 8),
          // Primary CTA — wider + primary color, nudges users toward the
          // generate flow instead of manual entry. Manual still available
          // to the right but visually demoted.
          _miniPill('+ Generate', _purpleHdr, () => _tabCtrl.animateTo(2),
            tip: 'Auto-generate'),
          const SizedBox(width: 6),
          _miniPill('+ Card', _greenHdr, _showCreateDialog,
            tip: 'Create manually'),
        ]),
      ),

      if (_subjects.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterPill('All subjects', _cardsFilterSubjectId == 'all',
                  () => setState(() { _cardsFilterSubjectId = 'all'; _cardsPage = 1; })),
                ..._subjects.map((s) {
                  final id = s['id']?.toString() ?? '';
                  return _filterPill(s['name'] ?? 'Subject',
                    _cardsFilterSubjectId == id,
                    () => setState(() { _cardsFilterSubjectId = id; _cardsPage = 1; }));
                }),
                _filterPill('No subject', _cardsFilterSubjectId == 'none',
                  () => setState(() { _cardsFilterSubjectId = 'none'; _cardsPage = 1; })),
              ],
            ),
          ),
        ),

      if (topics.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _topicChip('all topics', _cardsFilterTopic == null,
                  () => setState(() { _cardsFilterTopic = null; _cardsPage = 1; })),
                for (final t in topics)
                  _topicChip(t, _cardsFilterTopic == t,
                    () => setState(() { _cardsFilterTopic = t; _cardsPage = 1; })),
              ],
            ),
          ),
        ),

      // Count/hint row
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
        child: Row(children: [
          Text('${filtered.length} card${filtered.length == 1 ? '' : 's'}',
            style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: _brownLt)),
          if (filtered.length != _allCards.length) ...[
            const SizedBox(width: 6),
            Text('(of ${_allCards.length})',
              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w500, color: _brownLt)),
          ],
          const Spacer(),
          if (filtered.isNotEmpty)
            Text('Page $_cardsPage / $tp',
              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: _brownLt)),
        ]),
      ),

      Expanded(
        child: _allCards.isEmpty
          ? _emptyAllCards()
          : filtered.isEmpty
            ? _emptyFiltered()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: paged.length,
                itemBuilder: (ctx, i) => _cardTile(paged[i], i),
              ),
      ),

      if (_allCards.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: _cardsPaginationBar(tp),
        ),
    ]);
  }

  // Little pill used for '+ Generate' / '+ Card' toolbar CTAs.
  Widget _miniPill(String label, Color fill, VoidCallback onTap, {String? tip}) {
    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fill.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outline, width: 1.7),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
            offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: Text(label, style: GoogleFonts.gaegu(
          fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
      ),
    );
    return tip == null ? child : Tooltip(message: tip, child: child);
  }

  Widget _filterPill(String label, bool active, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _purpleHdr.withOpacity(0.55) : _cardFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? _outline : _outline.withOpacity(0.35),
            width: active ? 2 : 1.5,
          ),
          boxShadow: [BoxShadow(color: _outline.withOpacity(active ? 0.28 : 0.15),
            offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Text(label, style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: active ? _brown : _brownLt)),
      ),
    ),
  );

  Widget _topicChip(String label, bool active, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _goldHdr.withOpacity(0.55) : _goldLt.withOpacity(0.3),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? _outline : _outline.withOpacity(0.25),
            width: active ? 1.6 : 1),
        ),
        child: Text(label, style: GoogleFonts.nunito(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: active ? _brown : _brownLt)),
      ),
    ),
  );

  Widget _cardsPaginationBar(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _pageBtn('Prev', _cardsPage > 1, () => setState(() => _cardsPage--)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _sageHdr.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline.withOpacity(0.4), width: 1.2),
          ),
          child: Text('Page $_cardsPage / $totalPages',
            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
        ),
        const SizedBox(width: 10),
        _pageBtn('Next', _cardsPage < totalPages, () => setState(() => _cardsPage++)),
      ]),
    );
  }

  Widget _pageBtn(String label, bool enabled, VoidCallback onTap) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: enabled ? _cardFill : _cardFill.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled ? _outline : _outline.withOpacity(0.25),
          width: 1.5),
        boxShadow: enabled
          ? [BoxShadow(color: _outline.withOpacity(0.18),
              offset: const Offset(2, 2), blurRadius: 0)]
          : const [],
      ),
      child: Text(label, style: GoogleFonts.gaegu(
        fontSize: 15, fontWeight: FontWeight.w700,
        color: enabled ? _brown : _brownLt.withOpacity(0.5))),
    ),
  );

  // Primary empty state — zero cards anywhere. Push users toward generate tab.
  Widget _emptyAllCards() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.auto_awesome_rounded, size: 56, color: _purpleHdr.withOpacity(0.8)),
        const SizedBox(height: 10),
        Text('No cards yet',
          style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 4),
        Text('Upload notes and auto-generate smart cards — or create a few manually to get started.',
          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt),
          textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _miniPill('Auto-generate', _purpleHdr, () => _tabCtrl.animateTo(2)),
          const SizedBox(width: 10),
          _miniPill('Create manually', _greenHdr, _showCreateDialog),
        ]),
      ]),
    ));
  }

  // Secondary empty state — filter matched nothing. Offer a clear-all.
  Widget _emptyFiltered() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.filter_alt_off_rounded, size: 52, color: _outline.withOpacity(0.35)),
        const SizedBox(height: 10),
        Text('No cards match',
          style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 4),
        Text('Try a different subject, topic, or search term.',
          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt),
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _miniPill('Clear filters', _sageHdr, () {
          _cardsSearchCtrl.clear();
          setState(() {
            _cardsFilterSubjectId = 'all';
            _cardsFilterTopic = null;
            _cardsSearch = '';
            _cardsPage = 1;
          });
        }),
      ]),
    ));
  }

  Widget _cardTile(Map<String, dynamic> card, int index) {
    final isDue = card['next_review_date'] != null &&
        DateTime.tryParse(card['next_review_date'].toString())?.isBefore(
          DateTime.now().add(const Duration(days: 1))) == true;

    // Resolve subject + deck names for the context badges at the bottom
    // of the tile. Looked up from the already-loaded _subjects / _decks
    // lists so we don't need per-card network round-trips.
    final subjId = card['subject_id']?.toString();
    final deckId = card['deck_id']?.toString();
    final subj = subjId == null ? null : _subjects.firstWhere(
      (s) => s['id']?.toString() == subjId,
      orElse: () => const <String, dynamic>{});
    final deck = deckId == null ? null : _decks.firstWhere(
      (d) => d['id']?.toString() == deckId,
      orElse: () => const <String, dynamic>{});
    final subjName = (subj?['name'] as String?) ?? '';
    final deckName = (deck?['name'] as String?) ?? '';
    final tags = (card['tags'] as List?)?.cast<dynamic>() ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline, width: 2),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
          offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: InkWell(
        // Tap-to-edit — matches the "let users edit auto-generated cards"
        // best practice. Detail-only modal removed; edit dialog includes
        // the stats the old modal exposed plus full editability.
        onTap: () => _showEditCardDialog(card),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Due/ready icon
            Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isDue ? _coralHdr.withOpacity(0.3) : _greenHdr.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDue ? Icons.schedule_rounded : Icons.check_circle_rounded,
                color: _outline, size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card['front_text'] ?? '',
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: _brown),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  card['back_text'] ?? '',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w500, color: _brownLt),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                if (subjName.isNotEmpty || deckName.isNotEmpty || tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    if (subjName.isNotEmpty)
                      _tileBadge(Icons.book_rounded, subjName, _skyHdr),
                    if (deckName.isNotEmpty)
                      _tileBadge(Icons.layers_rounded, deckName, _purpleHdr),
                    for (final t in tags.take(2))
                      _tileBadge(Icons.label_rounded, t.toString(), _sageHdr),
                  ]),
                ],
              ],
            )),
            // Edit hint + delete
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.edit_rounded, color: _brownLt, size: 16),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _deleteCard(card),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400, size: 18),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _tileBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _outline.withOpacity(0.25), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: _brownLt),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
        ),
      ]),
    );
  }

  // Editable dialog — replaces the old view-only detail modal.
  //
  // Lets users edit auto-generated cards (fix a wrong answer, tweak a
  // question, move to a different deck/subject, retag). This is the
  // "auto-gen + CRUD, not pure CRUD" philosophy: auto-gen can seed, humans can
  // refine, SRS state stays untouched so the review signal is honest.
  void _showEditCardDialog(Map<String, dynamic> card) {
    final frontCtrl = TextEditingController(text: card['front_text']?.toString() ?? '');
    final backCtrl = TextEditingController(text: card['back_text']?.toString() ?? '');
    final tagsCtrl = TextEditingController(
      text: ((card['tags'] as List?)?.join(', ')) ?? '');

    // Start each dropdown at the card's current value so "no change" is
    // the default. The initial* copies let us detect actual user edits
    // so we only send changed fields in the PATCH body.
    String? subjectId = card['subject_id']?.toString();
    String? deckId = card['deck_id']?.toString();
    int difficulty = ((card['difficulty'] as num?)?.toInt() ?? 3).clamp(1, 5);

    final initFront = frontCtrl.text;
    final initBack = backCtrl.text;
    final initTags = tagsCtrl.text;
    final initSubjectId = subjectId;
    final initDeckId = deckId;
    final initDifficulty = difficulty;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      return AlertDialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _outline, width: 3),
        ),
        title: Row(children: [
          Text('Edit Flashcard', style: GoogleFonts.gaegu(
            fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
          const Spacer(),
          // Small stats pill — gives users context on the card's SRS
          // history without opening a separate modal.
          Tooltip(
            message: 'Reviews · Correct · Difficulty',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _sageHdr.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _outline.withOpacity(0.3), width: 1),
              ),
              child: Text(
                '${card['total_reviews'] ?? 0} · ${card['correct_reviews'] ?? 0}',
                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: _brownLt)),
            ),
          ),
        ]),
        content: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _inputField(frontCtrl, 'Front (Question)', maxLines: 3),
            const SizedBox(height: 10),
            _inputField(backCtrl, 'Back (Answer)', maxLines: 3),
            const SizedBox(height: 10),
            _inputField(tagsCtrl, 'Tags (comma-separated)'),
            const SizedBox(height: 12),
            if (_subjects.isNotEmpty) DropdownButtonFormField<String?>(
              value: subjectId,
              isExpanded: true,
              decoration: _dropdownDeco('Subject'),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No subject',
                    style: GoogleFonts.nunito(
                      fontSize: 14, fontStyle: FontStyle.italic, color: _brownLt))),
                ..._subjects.map((s) => DropdownMenuItem<String?>(
                  value: s['id']?.toString(),
                  child: Text(s['name'] ?? '',
                    style: GoogleFonts.nunito(fontSize: 14, color: _brown),
                    overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setD(() => subjectId = v),
            ),
            if (_subjects.isNotEmpty) const SizedBox(height: 10),
            if (_decks.isNotEmpty) DropdownButtonFormField<String?>(
              value: deckId,
              isExpanded: true,
              decoration: _dropdownDeco('Deck'),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No deck',
                    style: GoogleFonts.nunito(
                      fontSize: 14, fontStyle: FontStyle.italic, color: _brownLt))),
                ..._decks.map((d) => DropdownMenuItem<String?>(
                  value: d['id']?.toString(),
                  child: Text(d['name'] ?? '',
                    style: GoogleFonts.nunito(fontSize: 14, color: _brown),
                    overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setD(() => deckId = v),
            ),
            if (_decks.isNotEmpty) const SizedBox(height: 12),
            // Difficulty — 1..5 quick-pick row. 3 is the default SM-2
            // baseline; users rarely need finer granularity than this.
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Difficulty:', style: GoogleFonts.gaegu(
                fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
            ),
            const SizedBox(height: 4),
            Row(children: List.generate(5, (i) {
              final val = i + 1;
              final sel = val == difficulty;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => setD(() => difficulty = val),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _purpleHdr.withOpacity(0.55) : _cardFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? _outline : _outline.withOpacity(0.35),
                        width: sel ? 2 : 1.4),
                    ),
                    child: Center(child: Text('$val',
                      style: GoogleFonts.gaegu(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: sel ? _brown : _brownLt))),
                  ),
                ),
              ));
            })),
            const SizedBox(height: 8),
            Text(
              _difficultyHint(difficulty),
              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.gaegu(fontSize: 18, color: _brownLt))),
          TextButton(
            onPressed: () async {
              final front = frontCtrl.text.trim();
              final back = backCtrl.text.trim();
              if (front.isEmpty || back.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Front and back can\'t be empty')));
                return;
              }

              // Build a partial PATCH body — only fields the user actually
              // changed. Tags are normalized: split on comma, trim empties.
              final body = <String, dynamic>{};
              if (front != initFront) body['front_text'] = front;
              if (back != initBack) body['back_text'] = back;
              if (tagsCtrl.text != initTags) {
                body['tags'] = tagsCtrl.text
                  .split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
              }
              if (subjectId != initSubjectId) body['subject_id'] = subjectId;
              if (deckId != initDeckId) body['deck_id'] = deckId;
              if (difficulty != initDifficulty) body['difficulty'] = difficulty;

              if (body.isEmpty) {
                Navigator.pop(ctx);
                return;
              }

              final api = ref.read(apiServiceProvider);
              try {
                await api.put('/study/flashcards/${card['id']}', data: body);
                if (mounted) Navigator.pop(ctx);
                await _loadData();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Card updated'),
                  backgroundColor: _greenDk));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Update failed: $e'),
                  backgroundColor: Colors.red.shade400));
              }
            },
            child: Text('Save',
              style: GoogleFonts.gaegu(
                fontSize: 18, fontWeight: FontWeight.w700, color: _greenDk))),
        ],
      );
    }));
  }

  String _difficultyHint(int d) {
    switch (d) {
      case 1: return 'very easy — you almost always get this right';
      case 2: return 'easy — usually remembered';
      case 3: return 'medium — baseline for new cards';
      case 4: return 'hard — you often stumble';
      default: return 'very hard — surfaces more often in review';
    }
  }

  InputDecoration _dropdownDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _outline, width: 1.5)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _outline, width: 1.5)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _purpleHdr, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  Future<void> _deleteCard(Map<String, dynamic> card) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: _outline, width: 3)),
      title: Text('Delete card?', style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
      content: Text('This cannot be undone.', style: GoogleFonts.nunito(fontSize: 14, color: _brownLt)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: GoogleFonts.gaegu(fontSize: 18, color: _brownLt))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete', style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red))),
      ],
    ));
    if (confirm == true) {
      final api = ref.read(apiServiceProvider);
      try {
        await api.delete('/study/flashcards/${card['id']}');
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _showCreateDialog() {
    _frontCtrl.clear();
    _backCtrl.clear();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: _outline, width: 3)),
      title: Text('New Flashcard', style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _inputField(_frontCtrl, 'Front (Question)', maxLines: 3),
        const SizedBox(height: 12),
        _inputField(_backCtrl, 'Back (Answer)', maxLines: 3),
        const SizedBox(height: 12),
        if (_subjects.isNotEmpty) DropdownButtonFormField<String>(
          value: _selectedSubjectId,
          decoration: InputDecoration(
            labelText: 'Subject (optional)',
            labelStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _subjects.map((s) => DropdownMenuItem(
            value: s['id']?.toString(),
            child: Text(s['name'] ?? '', style: GoogleFonts.nunito(fontSize: 14)),
          )).toList(),
          onChanged: (v) => setD(() => _selectedSubjectId = v),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.gaegu(fontSize: 18, color: _brownLt))),
        TextButton(onPressed: () async {
          if (_frontCtrl.text.trim().isEmpty || _backCtrl.text.trim().isEmpty) return;
          final api = ref.read(apiServiceProvider);
          try {
            await api.post('/study/flashcards', data: {
              'front_text': _frontCtrl.text.trim(),
              'back_text': _backCtrl.text.trim(),
              'subject_id': _selectedSubjectId,
              'deck_id': _selectedDeckId,
              'tags': [],
              'difficulty': 3,
            });
            if (mounted) Navigator.pop(ctx);
            _loadData();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
          }
        }, child: Text('Create', style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w700, color: _greenDk))),
      ],
    )));
  }


  //  TAB 3: GENERATE (from study materials)

  Widget _generateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_purpleHdr, _purpleLt]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline, width: 2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
              offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: Column(children: [
            Icon(Icons.auto_awesome_rounded, size: 32, color: _brown),
            const SizedBox(height: 4),
            Text('Smart Flashcard Generator', style: GoogleFonts.gaegu(
              fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
            Text(
              _selectedDeckId != null
                ? 'Cards will be added to "$_selectedDeckName"'
                : 'Select study materials and generate smart flashcards',
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt),
              textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: 16),

        // Materials selection
        Text('Select Materials:', style: GoogleFonts.gaegu(
          fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 8),

        if (_materials.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outline, width: 2),
            ),
            child: Text(
              'No study materials uploaded yet.\nGo to Quizzes → Materials tab to upload PDFs or notes.',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._materials.map((m) => _materialCheckbox(m)),

        const SizedBox(height: 16),

        // Count selector
        Text('Number of cards:', style: GoogleFonts.gaegu(
          fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 8),
        Row(children: [5, 10, 15, 20].map((n) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _genCount = n),
            child: Container(
              width: 48, height: 40,
              decoration: BoxDecoration(
                color: _genCount == n ? _purpleHdr.withOpacity(0.5) : _cardFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _genCount == n ? _outline : _outline.withOpacity(0.4),
                    width: _genCount == n ? 2 : 1.5),
                boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                  offset: const Offset(3, 3), blurRadius: 0)],
              ),
              child: Center(child: Text('$n', style: GoogleFonts.gaegu(
                fontSize: 20, fontWeight: FontWeight.w700, color: _brown))),
            ),
          ),
        )).toList()),

        const SizedBox(height: 16),

        // Topic picker (only when materials are selected and have topics)
        Builder(builder: (ctx) {
          final selectedMats = _materials.where((m) =>
            _selectedMaterialIds.contains(m['id']?.toString() ?? '')).toList();
          final topics = <String>{};
          for (final m in selectedMats) {
            final ts = (m['topics'] as List?) ?? const [];
            for (final t in ts) { topics.add(t.toString()); }
          }
          if (topics.isEmpty) return const SizedBox.shrink();
          final list = topics.toList()..sort();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Focus on topics (optional):',
                style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w700, color: _brown))),
              GestureDetector(
                onTap: () => setState(() {
                  if (_selectedGenTopics.length == list.length) {
                    _selectedGenTopics.clear();
                  } else {
                    _selectedGenTopics
                      ..clear()
                      ..addAll(list);
                  }
                }),
                child: Text(
                  _selectedGenTopics.length == list.length ? 'clear' : 'all',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _purpleHdr)),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in list)
                GestureDetector(
                  onTap: () => setState(() {
                    if (_selectedGenTopics.contains(t)) { _selectedGenTopics.remove(t); }
                    else { _selectedGenTopics.add(t); }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _selectedGenTopics.contains(t) ? _purpleHdr : _purpleLt.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _outline.withOpacity(0.3), width: 1),
                    ),
                    child: Text(t,
                      style: GoogleFonts.nunito(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: _selectedGenTopics.contains(t) ? Colors.white : _brown)),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
          ]);
        }),

        // Generate button
        _bigButton(
          _generating ? 'Generating...' : 'Generate Flashcards',
          _generating ? _brownLt.withOpacity(0.3) : _greenHdr,
          _generating || _selectedMaterialIds.isEmpty ? null : _generateCards,
        ),

        if (_selectedMaterialIds.isEmpty && _materials.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Select at least one material above',
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _coralHdr)),
          ),
      ]),
    );
  }

  Widget _materialCheckbox(Map<String, dynamic> m) {
    final id = m['id']?.toString() ?? '';
    final selected = _selectedMaterialIds.contains(id);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) _selectedMaterialIds.remove(id);
        else _selectedMaterialIds.add(id);
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        decoration: BoxDecoration(
          color: selected ? _purpleHdr.withOpacity(0.15) : _cardFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _purpleHdr : _outline.withOpacity(0.4),
              width: selected ? 2.5 : 1.5),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
            offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: Row(children: [
          Icon(
            selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            color: selected ? _purpleHdr : _brownLt, size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m['title'] ?? 'Untitled', style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${m['word_count'] ?? 0} words · ${m['source_type'] ?? 'notes'}',
                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w500, color: _brownLt)),
            ],
          )),
          // Trailing delete affordance — isolated from the tile's tap zone
          // via its own GestureDetector so tapping the trash icon never
          // accidentally toggles the "include in auto-generation" checkbox.
          GestureDetector(
            onTap: () => _confirmDeleteMaterial(m),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.delete_outline_rounded,
                size: 20, color: Colors.red.shade400),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmDeleteMaterial(Map<String, dynamic> m) async {
    final title = (m['title'] as String?)?.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _outline, width: 3),
        ),
        title: Text('Delete material?', style: GoogleFonts.gaegu(
          fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
        content: Text(
          title != null && title.isNotEmpty
            ? '"$title" will be removed. Cards already generated from it will stay.'
            : 'This material will be removed. Cards already generated from it will stay.',
          style: GoogleFonts.nunito(fontSize: 14, color: _brown, height: 1.35),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.gaegu(fontSize: 18, color: _brownLt))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red.shade500))),
        ],
      ),
    );
    if (ok != true) return;
    final id = m['id']?.toString();
    if (id == null || id.isEmpty) return;
    final api = ref.read(apiServiceProvider);
    try {
      await api.delete('/study/materials/$id');
      if (!mounted) return;
      setState(() => _selectedMaterialIds.remove(id));
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(title != null && title.isNotEmpty
          ? 'Deleted "$title"'
          : 'Material deleted'),
        backgroundColor: _greenDk,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delete failed: $e'),
        backgroundColor: Colors.red.shade400,
      ));
    }
  }

  Future<void> _generateCards() async {
    setState(() => _generating = true);
    final api = ref.read(apiServiceProvider);
    try {
      final resp = await api.post('/study/flashcards/generate', data: {
        'material_ids': _selectedMaterialIds,
        'count': _genCount,
        if (_selectedDeckId != null) 'deck_id': _selectedDeckId,
        if (_selectedGenTopics.isNotEmpty) 'topic_filter': _selectedGenTopics.toList(),
      });
      final generated = resp.data['generated'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated $generated flashcards!'),
            backgroundColor: _greenDk,
          ),
        );
      }
      _selectedMaterialIds.clear();
      _selectedGenTopics.clear();
      await _loadData();
      _tabCtrl.animateTo(1); // Switch to All Cards tab
    } catch (e) {
      if (mounted) {
        String msg = 'Generation failed';
        if (e.toString().contains('422')) msg = 'Set up GROQ_API_KEY in .env (free at console.groq.com)';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }


  //  SHARED WIDGETS

  Widget _bigButton(String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null ? color.withOpacity(0.3) : color.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline, width: 2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
            offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: Center(
          child: Text(label, style: GoogleFonts.gaegu(
            fontSize: 22, fontWeight: FontWeight.w700,
            color: onTap == null ? _brownLt : _brown)),
        ),
      ),
    );
  }

  //  FILE UPLOAD — shared modal (matches Subjects & Quiz Hub)
  Future<void> _pickAndUploadFile(BuildContext context) async {
    await UploadNotesModal.show(
      context,
      ref: ref,
      subjects: _subjects
          .map((s) => UploadModalSubject(
                id: (s['id'] ?? '').toString(),
                name: (s['name'] ?? '').toString(),
                icon: Icons.book_rounded,
              ))
          .where((s) => s.id.isNotEmpty)
          .toList(),
      onUploaded: (_) => _loadData(),
    );
  }

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
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_purpleLt, _purpleHdr]),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Upload: ${file.name}',
                    style: GoogleFonts.gaegu(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis, maxLines: 1)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Title', style: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt)),
                  ),
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.nunito(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Material title',
                      hintStyle: GoogleFonts.nunito(fontSize: 12, color: _brownLt.withOpacity(0.4)),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _outline.withOpacity(0.12))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _outline.withOpacity(0.12))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _purpleHdr, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Subject', style: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _outline.withOpacity(0.12))),
                    child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                      isExpanded: true, value: selectedSubjectId,
                      hint: Text('Select subject', style: GoogleFonts.nunito(fontSize: 13, color: _brownLt)),
                      items: [
                        DropdownMenuItem<String?>(value: null,
                          child: Text('None', style: GoogleFonts.nunito(fontSize: 13))),
                        ..._subjects.map((s) => DropdownMenuItem<String?>(
                          value: s['id']?.toString(),
                          child: Text(s['name'] ?? '', style: GoogleFonts.nunito(fontSize: 13)))),
                      ],
                      onChanged: (v) => setDlg(() => selectedSubjectId = v),
                    )),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Topics (comma-separated, optional)',
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt)),
                  ),
                  TextField(
                    controller: topicsCtrl,
                    style: GoogleFonts.nunito(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Photosynthesis, Cell division',
                      hintStyle: GoogleFonts.nunito(fontSize: 12, color: _brownLt.withOpacity(0.4)),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _outline.withOpacity(0.12))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _outline.withOpacity(0.12))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _purpleHdr, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_purpleLt, _purpleHdr]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
                        boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                          offset: const Offset(3, 3), blurRadius: 0)]),
                      child: Center(child: Text('Upload & Extract Text',
                        style: GoogleFonts.gaegu(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
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

    final api = ref.read(apiServiceProvider);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
        'title': titleCtrl.text.trim().isEmpty ? file.name : titleCtrl.text.trim(),
        'subject_id': selectedSubjectId ?? '',
        'topics': topicsCtrl.text.trim(),
      });
      await api.post('/study/materials/upload', data: formData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('File uploaded & text extracted!', style: GoogleFonts.nunito()),
          backgroundColor: _greenHdr));
      }
      _loadData();
    } catch (e) {
      debugPrint('Upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e', style: GoogleFonts.nunito()),
          backgroundColor: _coralHdr));
      }
    }
  }

  Widget _emptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: _outline.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text(title, style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.w700, color: _brownLt)),
        const SizedBox(height: 4),
        Text(subtitle, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt),
          textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _inputField(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.nunito(fontSize: 14, color: _brown),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _purpleHdr, width: 2),
        ),
      ),
    );
  }
}

//  PAW-PRINT BACKGROUND — matches subjects/resources reference
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
          Rect.fromCenter(center: Offset.zero, width: pawR * 2.2, height: pawR * 1.8), paint);
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
