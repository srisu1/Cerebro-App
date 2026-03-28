// Achievements screen — categorised grid, tap for detail sheet.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/services/api_service.dart';


bool get _darkMode =>
    CerebroTheme.brightnessNotifier.value == Brightness.dark;

Color get _ombre1 => _darkMode ? const Color(0xFF191513) : const Color(0xFFFFFBF7);
Color get _ombre2 => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFF8F3);
Color get _ombre3 => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF3EF);
Color get _ombre4 => _darkMode ? const Color(0xFF312821) : const Color(0xFFFEEDE9);
Color get _brown => const Color(0xFF5C3D2E);
Color get _brownLt => _darkMode ? const Color(0xFFDBB594) : const Color(0xFF7A5840);
Color get _outline => const Color(0xFFB89880);
Color get _cardFill => const Color(0xFFFFFCF8);
Color get _goldHdr => const Color(0xFFE8C840);
Color get _goldDk => const Color(0xFFC8A830);
Color get _goldLt => const Color(0xFFFFF8E0);
Color get _greenHdr => const Color(0xFF88C888);
Color get _greenLt => const Color(0xFFE0F8E0);
Color get _purpleHdr => const Color(0xFF9D8AD4);
Color get _purpleLt => const Color(0xFFE8E0F8);
Color get _coralHdr => const Color(0xFFD89080);
Color get _pinkHdr => const Color(0xFFE8A8A0);
Color get _skyHdr => const Color(0xFF80B8D0);
IconData _iconFromString(String? name) {
  const map = {
    'school': Icons.school_rounded,
    'menu_book': Icons.menu_book_rounded,
    'timer': Icons.timer_rounded,
    'star': Icons.star_rounded,
    'flash_on': Icons.flash_on_rounded,
    'bedtime': Icons.bedtime_rounded,
    'mood': Icons.mood_rounded,
    'favorite': Icons.favorite_rounded,
    'medication': Icons.medication_rounded,
    'repeat': Icons.repeat_rounded,
    'calendar_month': Icons.calendar_month_rounded,
    'wb_sunny': Icons.wb_sunny_rounded,
    'emoji_events': Icons.emoji_events_rounded,
    'workspace_premium': Icons.workspace_premium_rounded,
  };
  return map[name] ?? Icons.emoji_events_rounded;
}

Color _rarityColor(String? rarity) {
  switch (rarity) {
    case 'common':    return _greenHdr;
    case 'rare':      return _skyHdr;
    case 'epic':      return _purpleHdr;
    case 'legendary': return _goldHdr;
    default:          return _greenHdr;
  }
}

Color _rarityBg(String? rarity) {
  switch (rarity) {
    case 'common':    return _greenLt;
    case 'rare':      return const Color(0xFFE0F0F8);
    case 'epic':      return _purpleLt;
    case 'legendary': return _goldLt;
    default:          return _greenLt;
  }
}

String _rarityLabel(String? rarity) {
  switch (rarity) {
    case 'common':    return '★ Common';
    case 'rare':      return '★★ Rare';
    case 'epic':      return '★★★ Epic';
    case 'legendary': return '★★★★ Legendary';
    default:          return '★ Common';
  }
}

const _categories = ['all', 'study', 'health', 'daily'];
const _categoryLabels = {'all': 'All', 'study': 'Study', 'health': 'Health', 'daily': 'Daily'};
const _categoryIcons = {
  'all': Icons.grid_view_rounded,
  'study': Icons.school_rounded,
  'health': Icons.favorite_rounded,
  'daily': Icons.today_rounded,
};

//  ACHIEVEMENTS SCREEN
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});
  @override ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _newlyUnlocked = [];
  bool _loading = true;
  String _selectedCategory = 'all';
  int _totalUnlocked = 0;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _loadAchievements();
  }

  @override
  void dispose() { _enterCtrl.dispose(); super.dispose(); }

  Future<void> _loadAchievements() async {
    try {
      final api = ref.read(apiServiceProvider);

      // First, check for newly unlocked achievements
      try {
        final checkRes = await api.post('/gamification/achievements/check', data: {});
        if (checkRes.statusCode == 200 && checkRes.data != null) {
          final unlocked = checkRes.data['newly_unlocked'] as List? ?? [];
          if (unlocked.isNotEmpty) {
            _newlyUnlocked = unlocked.cast<Map<String, dynamic>>();
          }
        }
      } catch (_) {}

      // Then fetch all achievements with progress
      final res = await api.get('/gamification/achievements');
      if (res.statusCode == 200 && res.data is List) {
        final list = (res.data as List).cast<Map<String, dynamic>>();
        setState(() {
          _achievements = list;
          _totalUnlocked = list.where((a) => a['is_unlocked'] == true).length;
          _loading = false;
        });

        // Show notification for newly unlocked
        if (_newlyUnlocked.isNotEmpty && mounted) {
          _showUnlockCelebration(_newlyUnlocked);
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUnlockCelebration(List<Map<String, dynamic>> unlocked) {
    for (final a in unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _goldLt,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _goldDk.withOpacity(0.4), width: 2)),
        content: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_goldHdr, _goldDk]),
              shape: BoxShape.circle),
            child: Icon(_iconFromString(a['icon'] as String?),
              color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Achievement Unlocked!', style: GoogleFonts.gaegu(
                fontSize: 14, fontWeight: FontWeight.w700, color: _goldDk)),
              Text(a['name'] as String? ?? '', style: GoogleFonts.gaegu(
                fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
            ],
          )),
          Text('+${a['xp_reward'] ?? 0} XP', style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700, color: _goldDk)),
        ]),
      ));
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == 'all') return _achievements;
    return _achievements.where((a) => a['category'] == _selectedCategory).toList();
  }

  Animation<double> _stagger(int i) => CurvedAnimation(
    parent: _enterCtrl,
    curve: Interval(
      (i * 0.06).clamp(0.0, 0.7),
      ((i * 0.06) + 0.4).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ombre1,
      body: Stack(children: [
        // Background
        Positioned.fill(child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_ombre1, _ombre2, _ombre3, _ombre4],
            stops: [0.0, 0.3, 0.6, 1.0],
          )),
        )),

        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: _brown),
                onPressed: () => Navigator.of(context).pop()),
              Text('Achievements', style: GoogleFonts.gaegu(
                fontSize: 28, fontWeight: FontWeight.w700, color: _brown)),
              const SizedBox(width: 8),
              Icon(Icons.emoji_events_rounded, color: _goldHdr, size: 24),
              const Spacer(),
              // Progress pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _goldLt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _goldDk.withOpacity(0.3), width: 1.5)),
                child: Text(
                  '$_totalUnlocked / ${_achievements.length}',
                  style: GoogleFonts.gaegu(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _goldDk)),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _brown : _cardFill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? _brown : _outline.withOpacity(0.2),
                        width: 1.5),
                      boxShadow: selected ? [BoxShadow(
                        color: _brown.withOpacity(0.15),
                        offset: const Offset(0, 3), blurRadius: 0)] : null),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_categoryIcons[cat], size: 16,
                        color: selected ? Colors.white : _brownLt),
                      const SizedBox(width: 6),
                      Text(_categoryLabels[cat]!, style: GoogleFonts.gaegu(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : _brownLt)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _loading
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 40, height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3, color: _goldHdr)),
                    const SizedBox(height: 12),
                    Text('Loading achievements...', style: GoogleFonts.nunito(
                      fontSize: 13, color: _brownLt)),
                  ],
                ))
              : _filtered.isEmpty
                ? Center(child: Text('No achievements in this category',
                    style: GoogleFonts.nunito(fontSize: 14, color: _brownLt)))
                : RefreshIndicator(
                    onRefresh: _loadAchievements,
                    color: _goldHdr,
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final a = _filtered[index];
                        return FadeTransition(
                          opacity: _stagger(index),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(_stagger(index)),
                            child: _AchievementCard(
                              data: a,
                              onTap: () => _showDetail(a),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ])),
      ]),
    );
  }

  void _showDetail(Map<String, dynamic> a) {
    final unlocked = a['is_unlocked'] == true;
    final rarity = a['rarity'] as String? ?? 'common';
    final progress = (a['progress_pct'] as num?)?.toInt() ?? 0;
    final rarColor = _rarityColor(rarity);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: _outline.withOpacity(0.15), width: 2)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            // Badge icon — large
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: unlocked
                  ? LinearGradient(colors: [rarColor.withOpacity(0.3), rarColor.withOpacity(0.1)])
                  : null,
                color: unlocked ? null : Colors.grey.shade200,
                shape: BoxShape.circle,
                border: Border.all(
                  color: unlocked ? rarColor : Colors.grey.shade300, width: 3),
                boxShadow: unlocked ? [
                  BoxShadow(color: rarColor.withOpacity(0.3),
                    blurRadius: 20, spreadRadius: 2),
                ] : null),
              child: Icon(
                _iconFromString(a['icon'] as String?),
                size: 40,
                color: unlocked ? rarColor : Colors.grey.shade400),
            ),
            const SizedBox(height: 16),

            // Name
            Text(a['name'] as String? ?? '', style: GoogleFonts.gaegu(
              fontSize: 26, fontWeight: FontWeight.w700,
              color: unlocked ? _brown : _brownLt)),
            const SizedBox(height: 4),

            // Rarity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _rarityBg(rarity),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: rarColor.withOpacity(0.3))),
              child: Text(_rarityLabel(rarity), style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w700, color: rarColor)),
            ),
            const SizedBox(height: 12),

            // Description
            Text(a['description'] as String? ?? '', style: GoogleFonts.nunito(
              fontSize: 14, color: _brownLt, height: 1.4),
              textAlign: TextAlign.center),
            const SizedBox(height: 16),

            // Progress bar
            if (!unlocked) ...[
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 10,
                    backgroundColor: _outline.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(rarColor)),
                )),
                const SizedBox(width: 10),
                Text('$progress%', style: GoogleFonts.gaegu(
                  fontSize: 16, fontWeight: FontWeight.w700, color: rarColor)),
              ]),
              const SizedBox(height: 8),
              Text('${a['progress'] ?? 0} / ${a['condition_value'] ?? '?'}',
                style: GoogleFonts.nunito(fontSize: 12, color: _brownLt)),
              const SizedBox(height: 16),
            ],

            // Rewards
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _rewardChip(Icons.star_rounded, '+${a['xp_reward'] ?? 0} XP', _goldHdr, _goldLt),
              const SizedBox(width: 12),
              _rewardChip(Icons.monetization_on_rounded, '+${a['coin_reward'] ?? 0}', _greenHdr, _greenLt),
            ]),

            if (unlocked && a['unlocked_at'] != null) ...[
              const SizedBox(height: 12),
              Text('Unlocked ${_formatDate(a['unlocked_at'] as String)}',
                style: GoogleFonts.nunito(fontSize: 12, color: _brownLt.withOpacity(0.6))),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _rewardChip(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.gaegu(
          fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return ''; }
  }
}

//  ACHIEVEMENT CARD — Grid tile
class _AchievementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _AchievementCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocked = data['is_unlocked'] == true;
    final rarity = data['rarity'] as String? ?? 'common';
    final progress = (data['progress_pct'] as num?)?.toInt() ?? 0;
    final rarColor = _rarityColor(rarity);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unlocked ? rarColor.withOpacity(0.5) : _outline.withOpacity(0.12),
            width: unlocked ? 2.5 : 1.5),
          boxShadow: [
            BoxShadow(color: _outline.withOpacity(0.04),
              offset: const Offset(0, 4), blurRadius: 12),
            if (unlocked)
              BoxShadow(color: rarColor.withOpacity(0.15),
                blurRadius: 16, spreadRadius: 2),
          ]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge circle
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: unlocked
                  ? LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [rarColor.withOpacity(0.25), rarColor.withOpacity(0.08)])
                  : null,
                color: unlocked ? null : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: unlocked ? rarColor.withOpacity(0.5) : Colors.grey.shade300,
                  width: 2.5),
                boxShadow: unlocked ? [
                  BoxShadow(color: rarColor.withOpacity(0.2),
                    offset: const Offset(0, 3), blurRadius: 0),
                ] : null),
              child: Icon(
                _iconFromString(data['icon'] as String?),
                size: 30,
                color: unlocked ? rarColor : Colors.grey.shade400),
            ),
            const SizedBox(height: 10),

            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                data['name'] as String? ?? '',
                style: GoogleFonts.gaegu(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: unlocked ? _brown : _brownLt.withOpacity(0.5)),
                textAlign: TextAlign.center,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 6),

            // Progress or unlocked indicator
            if (unlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: rarColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(_rarityLabel(rarity), style: GoogleFonts.nunito(
                  fontSize: 10, fontWeight: FontWeight.w700, color: rarColor)),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 6,
                    backgroundColor: _outline.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(rarColor.withOpacity(0.6))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
