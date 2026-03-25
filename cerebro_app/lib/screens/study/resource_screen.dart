/// Study Tab look: cream/terra-cotta ombre + paw-prints,
/// Bitroad for headings/values, Gaegu for body, hard-offset shadows,
/// pill chips, and a Health-Tab-style detail modal.
///
/// DATA SOURCE: `GET /study/recommendations` (cached 6h server-side).
/// The backend correlates the user's quiz/flashcard/subject performance
/// into weak areas, runs them through an AI provider to draft resource
/// suggestions, then resolves real URLs via YouTube / Wikipedia / Khan
/// Academy. We do NOT keep any mock data here — if the user has no quiz
/// history yet, the empty state nudges them to take a quiz.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

const _ombre1 = Color(0xFFFFFBF7);
const _ombre2 = Color(0xFFFFF8F3);
const _ombre3 = Color(0xFFFFF3EF);
const _ombre4 = Color(0xFFFEEDE9);
const _pawClr = Color(0xFFF8BCD0);

const _outline   = Color(0xFF6E5848);
const _brown     = Color(0xFF4E3828);
const _brownLt   = Color(0xFF7A5840);
const _brownSoft = Color(0xFF9A8070);

const _cream    = Color(0xFFFDEFDB);
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
const _greenLt  = Color(0xFFC2E8BC);
const _skyHdr   = Color(0xFF9DD4F0);
const _purpleHdr = Color(0xFFCDA8D8);

const _mTerra   = Color(0xFFD9B5A6);
const _mSlate   = Color(0xFFB6CBD6);
const _mSage    = Color(0xFFB5C4A0);
const _mMint    = Color(0xFFC8DCC2);
const _mLav     = Color(0xFFC9B8D9);
const _mButter  = Color(0xFFE8D4A0);
const _mBlush   = Color(0xFFEAD0CE);
const _mSand    = Color(0xFFE8D9C2);

TextStyle _gaegu({double size = 14, FontWeight weight = FontWeight.w600, Color color = _brown, double? h}) =>
    GoogleFonts.gaegu(fontSize: size, fontWeight: weight, color: color, height: h);
const _bitroad = 'Bitroad';

// Mapped from the `/study/recommendations` payload. `technique` maps
// onto the `practice` chip since the user-facing UI only exposes a
// handful of kinds — we keep the original enum so the palette/icons
// keep working without a wider refactor.
enum _ResKind { video, article, pdf, flashcards, podcast, practice }

class _Resource {
  final String id;
  final String title;
  final String source;
  final String subject;       // topic or subject name surfaced in the chip
  final _ResKind kind;
  final int minutes;
  final double rating;        // AI doesn't rate — we synthesize from difficulty
  final bool bookmarked;
  final String summary;       // description
  /// Why this came back for *this* user ("your thermodynamics score is 35%").
  /// Shown in the detail modal as the AI's justification line.
  final String whyRecommended;
  /// Real URL resolved server-side (YouTube watch URL, Wikipedia article,
  /// Khan Academy exercise, Google fallback). null if the AI call failed
  /// and we're showing a search fallback.
  final String? url;
  /// Human label for the primary CTA, e.g. "Watch on YouTube".
  final String urlLabel;
  /// beginner / intermediate / advanced
  final String difficulty;
  _Resource({
    required this.id,
    required this.title,
    required this.source,
    required this.subject,
    required this.kind,
    required this.minutes,
    required this.rating,
    required this.summary,
    required this.whyRecommended,
    required this.url,
    required this.urlLabel,
    required this.difficulty,
    this.bookmarked = false,
  });

  /// Parse one entry from the backend recommendations payload.
  /// Defensive — the AI occasionally drops fields, so every read has a
  /// sensible default rather than crashing the list.
  factory _Resource.fromJson(Map<String, dynamic> j, int index) {
    final rawType = (j['resource_type'] as String?)?.toLowerCase() ?? 'article';
    final kind = switch (rawType) {
      'video' => _ResKind.video,
      'article' || 'textbook' || 'reading' => _ResKind.article,
      'practice' || 'exercise' || 'problems' => _ResKind.practice,
      'technique' || 'strategy' || 'tip' => _ResKind.practice,
      'flashcards' => _ResKind.flashcards,
      'podcast' => _ResKind.podcast,
      _ => _ResKind.article,
    };
    final diff = ((j['difficulty'] as String?) ?? 'intermediate').toLowerCase();
    // Translate difficulty into a "rating" pill so the old UI fields
    // still mean something — beginner = 4.2, intermediate = 4.5, advanced = 4.8.
    final rating = diff == 'advanced'
        ? 4.8
        : diff == 'beginner' ? 4.2 : 4.5;
    return _Resource(
      id: 'rec-$index',
      title: (j['title'] as String?) ?? 'Recommended resource',
      source: (j['source'] as String?) ?? 'AI-picked',
      subject: (j['topic'] as String?) ?? 'General',
      kind: kind,
      minutes: (j['estimated_minutes'] is int)
          ? j['estimated_minutes'] as int
          : int.tryParse(j['estimated_minutes']?.toString() ?? '') ?? 15,
      rating: rating,
      summary: (j['description'] as String?) ?? '',
      whyRecommended: (j['why_recommended'] as String?) ?? '',
      url: j['url'] as String?,
      urlLabel: (j['url_label'] as String?) ?? 'Open',
      difficulty: diff,
    );
  }
}

Color _kindColor(_ResKind k) => switch (k) {
      _ResKind.video      => _mTerra,
      _ResKind.article    => _mSlate,
      _ResKind.pdf        => _mButter,
      _ResKind.flashcards => _mLav,
      _ResKind.podcast    => _mMint,
      _ResKind.practice   => _mSand,
    };
IconData _kindIcon(_ResKind k) => switch (k) {
      _ResKind.video      => Icons.play_circle_rounded,
      _ResKind.article    => Icons.article_rounded,
      _ResKind.pdf        => Icons.picture_as_pdf_rounded,
      _ResKind.flashcards => Icons.style_rounded,
      _ResKind.podcast    => Icons.headphones_rounded,
      _ResKind.practice   => Icons.edit_note_rounded,
    };
String _kindLabel(_ResKind k) => switch (k) {
      _ResKind.video      => 'Video',
      _ResKind.article    => 'Article',
      _ResKind.pdf        => 'PDF',
      _ResKind.flashcards => 'Flashcards',
      _ResKind.podcast    => 'Podcast',
      _ResKind.practice   => 'Practice',
    };

// NOTE: The mock `_demoResources` list that used to live here has been
// removed. Resources are now fetched from `/study/recommendations` — a
// real AI endpoint driven by the user's actual quiz/flashcard history
// (see cerebro_backend/app/routers/study.py::get_resource_recommendations).

//  RESOURCE SCREEN
class ResourceScreen extends ConsumerStatefulWidget {
  const ResourceScreen({super.key});
  @override
  ConsumerState<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends ConsumerState<ResourceScreen>
    with TickerProviderStateMixin {
  _ResKind? _kindFilter;
  String? _subjectFilter;
  String _query = '';
  bool _onlyBookmarks = false;
  late final AnimationController _enter;
  final Set<String> _bookmarks = {};

  // `_resources` is the full list returned by the AI recommendations
  // endpoint. `_loading` gates the skeleton. `_refreshing` is a lighter
  // indicator used by the "refresh" pill so users know a bypass-cache
  // call is in flight without losing the current list.
  List<_Resource> _resources = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _emptyMessage; // set when API returns [] with a friendly hint

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadRecommendations();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// Fetch AI recommendations from the backend. Default is cached-OK;
  /// pass `force=true` to hit `/study/recommendations/refresh`.
  Future<void> _loadRecommendations({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      if (force) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final res = force
          ? await api.post('/study/recommendations/refresh')
          : await api.get('/study/recommendations');
      final data = (res.data is Map<String, dynamic>)
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      final raw = (data['recommendations'] as List?) ?? const [];
      final parsed = <_Resource>[];
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (item is Map<String, dynamic>) {
          parsed.add(_Resource.fromJson(item, i));
        }
      }
      if (!mounted) return;
      setState(() {
        _resources = parsed;
        _loading = false;
        _refreshing = false;
        _emptyMessage = parsed.isEmpty
            ? (data['message'] as String?) ??
                'No recommendations yet — complete a quiz or review flashcards so we can spot what to suggest.'
            : null;
      });
      _enter
        ..reset()
        ..forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Could not load recommendations. '
            'Check the backend is running and an AI key is set.';
      });
    }
  }

  List<String> get _subjects => {for (final r in _resources) r.subject}.toList()..sort();

  List<_Resource> get _filtered {
    Iterable<_Resource> it = _resources;
    if (_kindFilter != null) it = it.where((r) => r.kind == _kindFilter);
    if (_subjectFilter != null) it = it.where((r) => r.subject == _subjectFilter);
    if (_onlyBookmarks) it = it.where((r) => _bookmarks.contains(r.id));
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      it = it.where((r) =>
          r.title.toLowerCase().contains(q) ||
          r.source.toLowerCase().contains(q) ||
          r.subject.toLowerCase().contains(q));
    }
    return it.toList();
  }

  Future<void> _openExternalUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Using platformDefault keeps the app alive on desktop (opens in
    // the system browser) and behaves correctly on mobile too.
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  void _toggleBookmark(_Resource r) {
    setState(() {
      if (_bookmarks.contains(r.id)) _bookmarks.remove(r.id);
      else _bookmarks.add(r.id);
    });
  }

  void _openDetail(_Resource r) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _ResourceDetailModal(
        resource: r,
        bookmarked: _bookmarks.contains(r.id),
        onToggleBookmark: () => _toggleBookmark(r),
        onOpen: () => _openExternalUrl(r.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final contentW = (screenW * 0.92).clamp(360.0, 1200.0);
    final crossAxis = contentW >= 1050 ? 3 : (contentW >= 720 ? 2 : 1);

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
              child: Column(children: [
                const SizedBox(height: 16),
                _stagger(0.00, _header()),
                const SizedBox(height: 14),
                if (_loading)
                  Expanded(child: _loadingState())
                else if (_error != null)
                  Expanded(child: _errorState())
                else if (_resources.isEmpty)
                  Expanded(child: _noDataState())
                else ...[
                  _stagger(0.06, _searchBar()),
                  const SizedBox(height: 10),
                  _stagger(0.08, _kindPills()),
                  const SizedBox(height: 10),
                  _stagger(0.10, _subjectChips()),
                  const SizedBox(height: 18),
                  _stagger(0.14, _featuredCard()),
                  const SizedBox(height: 18),
                  Expanded(
                    child: RefreshIndicator(
                      color: _oliveDk,
                      onRefresh: () => _loadRecommendations(force: true),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 110),
                        child: _stagger(0.18, _grid(crossAxis)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _loadingState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: _oliveDk, strokeWidth: 2.6),
      const SizedBox(height: 14),
      Text('Reading your study history…',
        style: _gaegu(size: 15, color: _brownLt, weight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('The AI is picking videos, articles, and practice for your weak areas.',
        textAlign: TextAlign.center,
        style: _gaegu(size: 12, color: _brownSoft)),
    ]),
  );

  Widget _errorState() => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 74, height: 74,
        decoration: BoxDecoration(
          color: _mBlush, shape: BoxShape.circle,
          border: Border.all(color: _outline.withOpacity(0.3), width: 2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
              offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: const Icon(Icons.cloud_off_rounded, size: 32, color: _brown),
      ),
      const SizedBox(height: 12),
      const Text('Recommendations unavailable',
        style: TextStyle(fontFamily: _bitroad, fontSize: 19, color: _brown)),
      const SizedBox(height: 6),
      Text(_error ?? 'Please try again.',
        textAlign: TextAlign.center,
        style: _gaegu(size: 13, color: _brownSoft, weight: FontWeight.w600)),
      const SizedBox(height: 16),
      _SoftButton(
        label: 'retry', icon: Icons.refresh_rounded,
        fill: _olive, textColor: Colors.white,
        onTap: () => _loadRecommendations(force: true),
      ),
    ])),
  );

  Widget _noDataState() => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 74, height: 74,
        decoration: BoxDecoration(
          color: _mLav, shape: BoxShape.circle,
          border: Border.all(color: _outline.withOpacity(0.3), width: 2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
              offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: const Icon(Icons.auto_awesome_rounded, size: 32, color: Colors.white),
      ),
      const SizedBox(height: 12),
      const Text('No recommendations yet',
        style: TextStyle(fontFamily: _bitroad, fontSize: 19, color: _brown)),
      const SizedBox(height: 6),
      Text(
        _emptyMessage ??
            'Take a quiz or review some flashcards — once we know your weak areas we can suggest videos, articles, and practice problems tailored to you.',
        textAlign: TextAlign.center,
        style: _gaegu(size: 13, color: _brownSoft, weight: FontWeight.w600, h: 1.4)),
      const SizedBox(height: 16),
      _SoftButton(
        label: 'refresh', icon: Icons.refresh_rounded,
        fill: _olive, textColor: Colors.white,
        onTap: () => _loadRecommendations(force: true),
      ),
    ])),
  );

  Widget _header() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('AI Recommendations',
          style: TextStyle(fontFamily: _bitroad, fontSize: 26, color: _brown, height: 1.15)),
        const SizedBox(height: 2),
        Text(
          _loading
            ? 'Reading your study history…'
            : _resources.isEmpty
                ? 'Complete a quiz so we can suggest something!'
                : 'Picked for your weak areas — tap a card to dig in~',
          style: _gaegu(size: 15, color: _brownSoft, h: 1.3)),
      ]),
    ),
    Wrap(spacing: 7, runSpacing: 7, children: [
      GestureDetector(
        onTap: _refreshing ? null : () => _loadRecommendations(force: true),
        child: _Pill(
          icon: _refreshing ? Icons.hourglass_empty_rounded : Icons.refresh_rounded,
          label: _refreshing ? 'refreshing…' : 'refresh',
          color: _mSlate.withOpacity(0.55)),
      ),
      if (_resources.isNotEmpty)
        _Pill(icon: Icons.auto_awesome_rounded,
            label: '${_resources.length} picks', color: _mLav.withOpacity(0.55)),
      GestureDetector(
        onTap: () => setState(() => _onlyBookmarks = !_onlyBookmarks),
        child: _Pill(
          icon: _onlyBookmarks ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: '${_bookmarks.length} saved',
          color: _onlyBookmarks ? _mSage.withOpacity(0.85) : _mButter.withOpacity(0.6),
          highlight: _onlyBookmarks,
        ),
      ),
    ]),
  ]);

  Widget _searchBar() => Container(
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
            hintText: 'Search videos, articles, decks...',
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
  );

  Widget _kindPills() {
    final kinds = [null, ..._ResKind.values];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final k in kinds) ...[
          _FilterPill(
            label: k == null ? 'All types' : _kindLabel(k),
            icon: k == null ? Icons.all_inclusive_rounded : _kindIcon(k),
            selected: _kindFilter == k,
            color: k == null ? _cream : _kindColor(k).withOpacity(0.55),
            onTap: () => setState(() => _kindFilter = k),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }

  Widget _subjectChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterPill(
          label: 'All subjects', icon: Icons.school_rounded,
          selected: _subjectFilter == null,
          color: _cream,
          onTap: () => setState(() => _subjectFilter = null),
        ),
        for (final s in _subjects) ...[
          const SizedBox(width: 8),
          _FilterPill(
            label: s, icon: Icons.bookmark_rounded,
            selected: _subjectFilter == s,
            color: _mBlush.withOpacity(0.55),
            onTap: () => setState(() => _subjectFilter = s),
          ),
        ],
      ]),
    );
  }

  Widget _featuredCard() {
    if (_filtered.isEmpty) return const SizedBox.shrink();
    final f = _filtered.first;
    final c = _kindColor(f.kind);
    return GestureDetector(
      onTap: () => _openDetail(f),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [c.withOpacity(0.65), c.withOpacity(0.4)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _outline.withOpacity(0.3), width: 2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.25),
              offset: const Offset(4, 4), blurRadius: 0)],
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(_kindIcon(f.kind), size: 30, color: _brown),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _outline.withOpacity(0.3), width: 1),
                  ),
                  child: Text('FEATURED',
                    style: _gaegu(size: 9, weight: FontWeight.w700, color: _brown)
                        .copyWith(letterSpacing: 0.6)),
                ),
                const SizedBox(width: 6),
                Text(f.subject,
                  style: _gaegu(size: 11, weight: FontWeight.w700, color: _brown.withOpacity(0.75))),
              ]),
              const SizedBox(height: 4),
              Text(f.title,
                style: const TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown, height: 1.2),
                overflow: TextOverflow.ellipsis, maxLines: 2),
              const SizedBox(height: 2),
              Text(f.summary,
                style: _gaegu(size: 13, weight: FontWeight.w600, color: _brown.withOpacity(0.75), h: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          )),
          const SizedBox(width: 14),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.22),
                  offset: const Offset(2, 2), blurRadius: 0)],
            ),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: _brown),
          ),
        ]),
      ),
    );
  }

  Widget _grid(int crossAxis) {
    final items = _filtered.length > 1 ? _filtered.sublist(1) : <_Resource>[];
    if (items.isEmpty) return _emptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxis,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (_, i) => _ResourceCard(
        resource: items[i],
        bookmarked: _bookmarks.contains(items[i].id),
        onTap: () => _openDetail(items[i]),
        onBookmark: () => _toggleBookmark(items[i]),
      ),
    );
  }

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Column(children: [
      Container(
        width: 74, height: 74,
        decoration: BoxDecoration(
          color: _cream, shape: BoxShape.circle,
          border: Border.all(color: _outline.withOpacity(0.3), width: 2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
              offset: const Offset(3, 3), blurRadius: 0)],
        ),
        child: Icon(Icons.travel_explore_rounded, size: 32, color: _brownLt),
      ),
      const SizedBox(height: 12),
      const Text('No resources match',
        style: TextStyle(fontFamily: _bitroad, fontSize: 19, color: _brown)),
      const SizedBox(height: 4),
      Text('Try clearing a filter or another search term',
        style: _gaegu(size: 13, color: _brownSoft, weight: FontWeight.w700)),
    ]),
  );

  // Stagger animation. Passes `child` through AnimatedBuilder (so the subtree
  // isn't rebuilt every frame) and ignores pointer events while animating —
  // prevents the desktop `_debugDuringDeviceUpdate` mouse-tracker assertion
  // that fires when hit-test regions change mid-update.
  Widget _stagger(double delay, Widget child) => RepaintBoundary(
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

//  RESOURCE CARD
class _ResourceCard extends StatelessWidget {
  final _Resource resource;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;
  const _ResourceCard({required this.resource, required this.bookmarked,
    required this.onTap, required this.onBookmark});

  @override
  Widget build(BuildContext context) {
    final c = _kindColor(resource.kind);
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header strip
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: c.withOpacity(0.42),
                border: Border(bottom: BorderSide(color: _outline.withOpacity(0.18), width: 1.4)),
              ),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _outline.withOpacity(0.3), width: 1.3),
                  ),
                  child: Icon(_kindIcon(resource.kind), size: 19, color: _brown),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_kindLabel(resource.kind).toUpperCase(),
                      style: _gaegu(size: 10, weight: FontWeight.w700,
                        color: _brown.withOpacity(0.75)).copyWith(letterSpacing: 0.7)),
                    Text(resource.subject,
                      style: const TextStyle(fontFamily: _bitroad, fontSize: 13, color: _brown)),
                  ],
                )),
                GestureDetector(
                  onTap: onBookmark,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: bookmarked ? _olive : Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: bookmarked ? _oliveDk : _outline.withOpacity(0.3), width: 1.3),
                    ),
                    child: Icon(
                      bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 16, color: bookmarked ? Colors.white : _brown,
                    ),
                  ),
                ),
              ]),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(resource.title,
                    style: const TextStyle(fontFamily: _bitroad, fontSize: 16, color: _brown, height: 1.25),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(resource.source,
                    style: _gaegu(size: 12, weight: FontWeight.w700, color: _brownSoft)),
                  const Spacer(),
                  Row(children: [
                    _MiniPill(icon: Icons.schedule_rounded,
                        label: '${resource.minutes} min', color: _mSlate.withOpacity(0.45)),
                    const SizedBox(width: 6),
                    _MiniPill(icon: Icons.star_rounded,
                        label: resource.rating.toStringAsFixed(1), color: _mButter.withOpacity(0.55)),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

//  DETAIL MODAL (Health-tab style)
class _ResourceDetailModal extends StatelessWidget {
  final _Resource resource;
  final bool bookmarked;
  final VoidCallback onToggleBookmark;
  /// Launches the real resource URL resolved by the backend — if we
  /// couldn't resolve one (unlikely), the call is a no-op.
  final Future<void> Function() onOpen;
  const _ResourceDetailModal({
    required this.resource, required this.bookmarked,
    required this.onToggleBookmark, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 600,
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
                // Top row: kind tag + circular close
                Row(children: [
                  Expanded(child: Text(_kindLabel(resource.kind).toUpperCase(),
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
                // Icon chip + title + source subtitle
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
                    child: Icon(_kindIcon(resource.kind), size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(resource.title,
                        style: const TextStyle(fontFamily: _bitroad, fontSize: 22, color: _brown, height: 1.15),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(resource.source,
                        style: _gaegu(size: 14, weight: FontWeight.w700, color: _brownLt)),
                    ]),
                  )),
                ]),
                const SizedBox(height: 20),

                // Stats strip
                Row(children: [
                  Expanded(child: _StatTile(icon: Icons.school_rounded, label: 'Subject',
                      value: resource.subject, bgColor: _mSlate.withOpacity(0.5))),
                  const SizedBox(width: 8),
                  Expanded(child: _StatTile(icon: Icons.schedule_rounded, label: 'Duration',
                      value: '${resource.minutes} min', bgColor: _mButter.withOpacity(0.55))),
                  const SizedBox(width: 8),
                  Expanded(child: _StatTile(icon: Icons.star_rounded, label: 'Rating',
                      value: resource.rating.toStringAsFixed(1),
                      bgColor: _mSage.withOpacity(0.85), isHighlight: true)),
                ]),
                const SizedBox(height: 16),

                // Summary as a white pill card with olive leading chip (medication-modal vibe)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _outline, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                    ],
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _olive,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _outline, width: 1.5),
                      ),
                      child: const Icon(Icons.description_rounded, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('SUMMARY',
                          style: _gaegu(size: 11, weight: FontWeight.w700, color: _oliveDk)
                              .copyWith(letterSpacing: 0.7)),
                        const SizedBox(height: 2),
                        Text(resource.summary.isEmpty
                            ? 'A resource tailored to your current weak area.'
                            : resource.summary,
                          style: const TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown, height: 1.4)),
                      ],
                    )),
                  ]),
                ),
                // "Why recommended" — the AI's actual justification line,
                // tied to the user's own performance numbers. This is the
                // feature that makes the page feel personalised instead
                // of mock.
                if (resource.whyRecommended.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: _mLav.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.auto_awesome_rounded, size: 18, color: _brown),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('WHY THIS RESOURCE',
                            style: _gaegu(size: 11, weight: FontWeight.w700, color: _brown)
                                .copyWith(letterSpacing: 0.7)),
                          const SizedBox(height: 2),
                          Text(resource.whyRecommended,
                            style: _gaegu(size: 13, weight: FontWeight.w600, color: _brown, h: 1.4)),
                        ],
                      )),
                    ]),
                  ),
                ],
                const SizedBox(height: 22),

                Row(children: [
                  Expanded(
                    child: _SoftButton(
                      label: bookmarked ? 'saved' : 'save',
                      icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      fill: bookmarked ? _olive : _cream,
                      textColor: bookmarked ? Colors.white : _brown,
                      onTap: onToggleBookmark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _SoftButton(
                    label: resource.url == null ? 'search online' : resource.urlLabel.toLowerCase(),
                    icon: Icons.open_in_new_rounded,
                    fill: _olive, textColor: Colors.white,
                    onTap: () {
                      onOpen();
                      Navigator.of(context).pop();
                    },
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

//  SHARED WIDGETS
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _outline.withOpacity(0.25), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: _outline),
      const SizedBox(width: 4),
      Text(label, style: _gaegu(size: 11, weight: FontWeight.w700, color: _brown)),
    ]),
  );
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.icon, required this.selected,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? _olive : color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? _oliveDk : _outline.withOpacity(0.25),
          width: 1.5),
        boxShadow: selected
            ? [BoxShadow(color: _oliveDk.withOpacity(0.4),
                offset: const Offset(2, 2), blurRadius: 0)]
            : [BoxShadow(color: _outline.withOpacity(0.15),
                offset: const Offset(1, 1), blurRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: selected ? Colors.white : _outline),
        const SizedBox(width: 5),
        Text(label,
          style: TextStyle(fontFamily: _bitroad, fontSize: 12,
            color: selected ? Colors.white : _brown)),
      ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _outline.withOpacity(0.15), width: 1),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.1),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: iconBorder, width: 1),
          ),
          child: Icon(icon, size: 13, color: isHighlight ? Colors.white : _brownLt),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
              style: TextStyle(fontFamily: _bitroad, fontSize: 14, color: textColor),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            Text(label.toUpperCase(),
              style: _gaegu(size: 9, weight: FontWeight.w700, color: labelColor).copyWith(letterSpacing: 0.5)),
          ],
        )),
      ]),
    );
  }
}

class _SoftButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fill;
  final Color textColor;
  final VoidCallback onTap;
  const _SoftButton({required this.label, required this.fill, required this.onTap,
    this.icon, this.textColor = _brown});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
        ],
        Text(label,
          style: _gaegu(size: 18, weight: FontWeight.w700, color: textColor)),
      ]),
    ),
  );
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
