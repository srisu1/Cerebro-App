//  Personalised learning resources from AI analysis
//  Filter chips: All · Videos · Articles · Practice · Techniques
//  Cozy Pocket Love aesthetic

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

const _ombre1   = Color(0xFFFFFBF7);
const _ombre2   = Color(0xFFFFF8F3);
const _ombre3   = Color(0xFFFFF3EF);
const _ombre4   = Color(0xFFFEEDE9);
const _cardFill = Color(0xFFFFF8F4);
const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);
const _coralHdr = Color(0xFFF0A898);
const _greenHdr = Color(0xFFA8D5A3);
const _greenDk  = Color(0xFF88B883);
const _goldHdr  = Color(0xFFF0D878);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _skyHdr   = Color(0xFF9DD4F0);
const _sageHdr  = Color(0xFF90C8A0);

enum _FilterType { all, video, article, practice, technique }

class ResourceScreen extends ConsumerStatefulWidget {
  const ResourceScreen({super.key});
  @override ConsumerState<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends ConsumerState<ResourceScreen> {
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _allRecs = [];
  List<Map<String, dynamic>> _weakAreas = [];
  bool _loading = true;
  bool _refreshing = false;
  _FilterType _activeFilter = _FilterType.all;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() { _loading = true; _error = null; });
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.get('/study/recommendations');
      _parseData(res.data);
    } catch (e) {
      setState(() {
        _error = e.toString().contains('422')
            ? 'Set up GROQ_API_KEY in .env (free at console.groq.com)'
            : 'Failed to load recommendations';
        _loading = false;
      });
    }
  }

  Future<void> _refreshRecommendations() async {
    setState(() => _refreshing = true);
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.post('/study/recommendations/refresh', data: {});
      _parseData(res.data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Refresh failed: $e'),
          backgroundColor: _coralHdr,
        ));
      }
    }
    if (mounted) setState(() => _refreshing = false);
  }

  void _parseData(dynamic raw) {
    final d = raw as Map<String, dynamic>? ?? {};
    final recs = (d['recommendations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final weak = (d['weak_areas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    setState(() {
      _data = d;
      _allRecs = recs;
      _weakAreas = weak;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredRecs {
    if (_activeFilter == _FilterType.all) return _allRecs;
    final type = _activeFilter.name; // "video", "article", "practice", "technique"
    return _allRecs.where((r) {
      final rt = r['resource_type']?.toString() ?? '';
      if (_activeFilter == _FilterType.article) return rt == 'article' || rt == 'textbook';
      return rt == type;
    }).toList();
  }

  //  BUILD

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
            if (!_loading && _weakAreas.isNotEmpty) _weakAreasStrip(),
            _filterChips(),
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
        _backBtn(),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Resources', style: GoogleFonts.gaegu(
            fontSize: 28, fontWeight: FontWeight.w700, color: _brown)),
        ),
        if (_data['cache_hit'] == true)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _sageHdr.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('cached', style: GoogleFonts.nunito(
                fontSize: 9, fontWeight: FontWeight.w700, color: _greenDk)),
            ),
          ),
        GestureDetector(
          onTap: _refreshing ? null : _refreshRecommendations,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _goldHdr.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline, width: 2),
              boxShadow: const [BoxShadow(color: _outline, offset: Offset(0, 2), blurRadius: 0)],
            ),
            child: _refreshing
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2, color: _brown))
              : const Icon(Icons.refresh_rounded, color: _brown, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _backBtn() => GestureDetector(
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
  );

  Widget _weakAreasStrip() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: Text('Weak areas:', style: GoogleFonts.gaegu(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brownLt)),
            ),
          ),
          ..._weakAreas.map((w) {
            final prof = (w['proficiency'] as num?)?.toInt() ?? 0;
            final severity = w['severity']?.toString() ?? 'medium';
            final color = severity == 'critical' ? _coralHdr
                : severity == 'high' ? _goldHdr
                : _sageHdr;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _outline.withOpacity(0.4), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${w['topic']} · $prof%',
                    style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _brown),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _filterChips() {
    final filters = [
      (_FilterType.all, 'All', Icons.auto_awesome_rounded, _purpleHdr),
      (_FilterType.video, 'Videos', Icons.play_circle_rounded, _skyHdr),
      (_FilterType.article, 'Articles', Icons.article_rounded, _coralHdr),
      (_FilterType.practice, 'Practice', Icons.quiz_rounded, _greenHdr),
      (_FilterType.technique, 'Techniques', Icons.lightbulb_rounded, _goldHdr),
    ];

    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: filters.map((f) {
          final isActive = _activeFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = f.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? f.$4.withOpacity(0.5) : _cardFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? _outline : _outline.withOpacity(0.4),
                    width: isActive ? 2.5 : 1.5,
                  ),
                  boxShadow: [BoxShadow(
                    color: _outline,
                    offset: Offset(0, isActive ? 2 : 1),
                    blurRadius: 0,
                  )],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.$3, size: 16, color: isActive ? _brown : _brownLt),
                  const SizedBox(width: 4),
                  Text(f.$2, style: GoogleFonts.gaegu(
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: _brown,
                  )),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState();
    if (_allRecs.isEmpty) return _emptyState();

    final recs = _filteredRecs;
    if (recs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_list_rounded, size: 48, color: _outline.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text('No ${_activeFilter.name} resources', style: GoogleFonts.gaegu(
              fontSize: 20, fontWeight: FontWeight.w700, color: _brownLt)),
            const SizedBox(height: 4),
            Text('Try a different filter', style: GoogleFonts.nunito(
              fontSize: 13, color: _brownLt)),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshRecommendations,
      color: _purpleHdr,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: recs.length,
        itemBuilder: (ctx, i) => _resourceCard(recs[i]),
      ),
    );
  }

  Widget _resourceCard(Map<String, dynamic> rec) {
    final type = rec['resource_type']?.toString() ?? 'article';
    final typeInfo = _typeVisuals(type);
    final hasUrl = rec['url'] != null && rec['url'].toString().isNotEmpty;
    final mins = rec['estimated_minutes'] ?? 0;
    final difficulty = rec['difficulty']?.toString() ?? 'intermediate';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (hasUrl) {
          _openUrl(rec['url']);
        } else {
          _showDetail(rec);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline, width: 2.5),
          boxShadow: const [BoxShadow(color: _outline, offset: Offset(0, 3), blurRadius: 0)],
        ),
        child: Column(children: [
          // Colour header strip
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: typeInfo.$2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title row
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: typeInfo.$2.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeInfo.$1, size: 18, color: _brown),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec['title'] ?? 'Resource',
                      style: GoogleFonts.gaegu(fontSize: 17, fontWeight: FontWeight.w700, color: _brown),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    if (rec['source'] != null)
                      Text(
                        rec['source'],
                        style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt),
                      ),
                  ],
                )),
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeInfo.$2.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(typeInfo.$3, style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
                ),
              ]),

              const SizedBox(height: 8),

              // Why recommended
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _purpleHdr.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.auto_awesome, size: 14, color: _purpleHdr),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rec['why_recommended'] ?? rec['description'] ?? '',
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _brown, height: 1.3),
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 8),

              // Bottom info row
              Row(children: [
                if (mins > 0) ...[
                  Icon(Icons.schedule_rounded, size: 13, color: _brownLt),
                  const SizedBox(width: 3),
                  Text('${mins}min', style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
                  const SizedBox(width: 12),
                ],
                _difficultyBadge(difficulty),
                const Spacer(),
                if (rec['related_topic'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _sageHdr.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(rec['related_topic'], style: GoogleFonts.nunito(
                      fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt)),
                  ),
                if (hasUrl) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: type == 'video' ? _skyHdr.withOpacity(0.3)
                          : type == 'practice' ? _greenHdr.withOpacity(0.3)
                          : _coralHdr.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        type == 'video' ? Icons.play_arrow_rounded
                            : type == 'article' ? Icons.open_in_new_rounded
                            : type == 'practice' ? Icons.launch_rounded
                            : Icons.open_in_new_rounded,
                        size: 12, color: _brown,
                      ),
                      const SizedBox(width: 3),
                      Text(rec['url_label'] ?? 'Open', style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
                    ]),
                  ),
                ] else ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _goldHdr.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('View tip', style: GoogleFonts.nunito(
                      fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
                  ),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  (IconData, Color, String) _typeVisuals(String type) {
    switch (type) {
      case 'video': return (Icons.play_circle_rounded, _skyHdr, 'Video');
      case 'article': return (Icons.article_rounded, _coralHdr, 'Article');
      case 'textbook': return (Icons.menu_book_rounded, _coralHdr, 'Textbook');
      case 'practice': return (Icons.quiz_rounded, _greenHdr, 'Practice');
      case 'technique': return (Icons.lightbulb_rounded, _goldHdr, 'Technique');
      default: return (Icons.link_rounded, _purpleHdr, 'Resource');
    }
  }

  Widget _difficultyBadge(String difficulty) {
    final color = difficulty == 'beginner' ? _greenHdr
        : difficulty == 'advanced' ? _coralHdr
        : _goldHdr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(difficulty, style: GoogleFonts.nunito(
        fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open link'),
        backgroundColor: _coralHdr,
      ));
    }
  }

  void _showDetail(Map<String, dynamic> rec) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _outline, width: 3),
      ),
      title: Text(rec['title'] ?? 'Resource', style: GoogleFonts.gaegu(
        fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
      content: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rec['source'] != null)
            Text(rec['source'], style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: _brownLt)),
          const SizedBox(height: 12),
          Text(rec['description'] ?? '', style: GoogleFonts.nunito(
            fontSize: 14, fontWeight: FontWeight.w600, color: _brown, height: 1.4)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _purpleHdr.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(rec['why_recommended'] ?? '', style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w600, color: _brown)),
          ),
        ],
      )),
      actions: [TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text('Close', style: GoogleFonts.gaegu(
          fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
      )],
    ));
  }

  Widget _loadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: _purpleHdr),
        const SizedBox(height: 16),
        Text('Analysing your study data...', style: GoogleFonts.gaegu(
          fontSize: 20, fontWeight: FontWeight.w700, color: _brownLt)),
        const SizedBox(height: 4),
        Text('AI is finding the best resources for you', style: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt)),
        const SizedBox(height: 24),
        // Skeleton cards
        ...List.generate(3, (_) => _skeletonCard()),
      ]),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 100,
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withOpacity(0.2), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 200, height: 14, decoration: BoxDecoration(
            color: _outline.withOpacity(0.08), borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 8),
          Container(width: double.infinity, height: 10, decoration: BoxDecoration(
            color: _outline.withOpacity(0.06), borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 6),
          Container(width: 150, height: 10, decoration: BoxDecoration(
            color: _outline.withOpacity(0.06), borderRadius: BorderRadius.circular(6))),
        ]),
      ),
    );
  }

  Widget _errorState() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 64, color: _coralHdr.withOpacity(0.5)),
        const SizedBox(height: 12),
        Text('Oops!', style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.w700, color: _brownLt)),
        const SizedBox(height: 4),
        Text(_error!, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt),
          textAlign: TextAlign.center),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _loadRecommendations,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: _purpleHdr.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outline, width: 2),
              boxShadow: const [BoxShadow(color: _outline, offset: Offset(0, 2), blurRadius: 0)],
            ),
            child: Text('Try Again', style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
          ),
        ),
      ]),
    ));
  }

  Widget _emptyState() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.auto_stories_rounded, size: 64, color: _outline.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text('No recommendations yet', style: GoogleFonts.gaegu(
          fontSize: 24, fontWeight: FontWeight.w700, color: _brownLt)),
        const SizedBox(height: 4),
        Text(
          'Take some quizzes or review flashcards first!\nThe AI needs data about your strengths and weak areas.',
          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt),
          textAlign: TextAlign.center,
        ),
      ]),
    ));
  }
}
