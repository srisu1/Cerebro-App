/// CEREBRO – Home Dashboard v14 — DYNAMIC + COZY GAME DESIGN
/// Reactive dashboard powered by DashboardProvider (Riverpod).
/// Fetches from API, caches locally, updates in real-time.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/models/expression_state.dart';
import 'package:go_router/go_router.dart';
import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';
import 'package:cerebro_app/widgets/alive_avatar.dart';
import 'package:cerebro_app/widgets/mood_sticker.dart';

const _ombre1  = Color(0xFFFFFBF7);
const _ombre2  = Color(0xFFFFF8F3);
const _ombre3  = Color(0xFFFFF3EF);
const _ombre4  = Color(0xFFFEEDE9);
const _pawClr  = Color(0xFFF8BCD0);

const _outline = Color(0xFF6E5848);
const _brown   = Color(0xFF4E3828);
const _brownLt = Color(0xFF7A5840);

const _cardFill  = Color(0xFFFFF8F4);
const _panelBg   = Color(0xFFFFF6EE);
const _purpleHdr = Color(0xFFCDA8D8);
const _greenLt   = Color(0xFFC2E8BC);
const _green     = Color(0xFFA8D5A3);
const _greenDk   = Color(0xFF88B883);
const _goldGlow  = Color(0xFFF8E080);
const _pinkHdr   = Color(0xFFE8B0A8);
const _skyHdr    = Color(0xFF9DD4F0);
const _coralHdr  = Color(0xFFF0A898);

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});
  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab>
    with TickerProviderStateMixin {
  // UI-only state (not in provider)
  ExpressionState _currentExpression = ExpressionState.neutral;
  String _speechText = '';
  Timer? _speechTimer;
  late AnimationController _enterCtrl;
  String? _lastMood; // tracks mood to update expression

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..forward();
    _startSpeechCycle();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _speechTimer?.cancel();
    super.dispose();
  }

  void _startSpeechCycle() {
    _speechTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        final dash = ref.read(dashboardProvider);
        setState(() {
          _speechText = ExpressionEngine.speechMessage(
              _currentExpression, dash.displayName, streak: dash.streak);
        });
      }
    });
  }

  /// Sync expression to current mood (called from build)
  void _syncExpression(DashboardState dash) {
    if (dash.todayMood != _lastMood) {
      _lastMood = dash.todayMood;
      _currentExpression = dash.todayMood != null
          ? ExpressionEngine.fromMood(dash.todayMood)
          : ExpressionEngine.fromTimeOfDay();
      _speechText = ExpressionEngine.speechMessage(
          _currentExpression, dash.displayName, streak: dash.streak);
    }
    if (_speechText.isEmpty) {
      _speechText = ExpressionEngine.speechMessage(
          _currentExpression, dash.displayName, streak: dash.streak);
    }
  }

  String _formatStudy(int minutes) {
    if (minutes == 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Nighty night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Sweet dreams';
  }

  void _showMoodPopup() {
    final dash = ref.read(dashboardProvider);
    if (dash.avatarConfig == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => _MoodPopup(
        config: dash.avatarConfig!,
        selected: dash.todayMood,
        onPick: (mood) {
          Navigator.of(ctx).pop();
          // Update via provider (persists + syncs API)
          ref.read(dashboardProvider.notifier).logMood(mood);
          setState(() {
            _currentExpression = ExpressionEngine.fromMood(mood);
            _speechText = ExpressionEngine.speechMessage(
                _currentExpression, dash.displayName, streak: dash.streak);
          });
        },
      ),
    );
  }

  void _toggleHabit(int i) {
    ref.read(dashboardProvider.notifier).toggleHabit(i);
  }

  String _formatDate() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  //  MAIN BUILD
  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(dashboardProvider);
    _syncExpression(dash);

    return Stack(children: [
      Positioned.fill(child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_ombre1, _ombre2, _ombre3, _ombre4],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
      )),
      Positioned.fill(child: CustomPaint(painter: _PawPrintBg())),
      Positioned(
        top: -120, left: 0, right: 0,
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.0,
              colors: [
                _goldGlow.withOpacity(0.12),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      SafeArea(
        child: RefreshIndicator(
          color: _outline,
          backgroundColor: _cardFill,
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(34, 14, 34, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stagger(0.0, _buildTopStrip()),
                const SizedBox(height: 24),
                _stagger(0.06, _buildAvatarSection()),
                const SizedBox(height: 24),
                _stagger(0.12, _buildQuickActions()),
                const SizedBox(height: 20),
                _stagger(0.18, _buildStatsCard()),
                const SizedBox(height: 20),
                _stagger(0.24, _buildQuestsCard()),
                const SizedBox(height: 20),
                _stagger(0.28, _buildRecommendedSection()),
                const SizedBox(height: 20),
                _stagger(0.32, _buildInsightCard()),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  //  TOP STRIP — greeting + date pill + currency pills
  Widget _buildTopStrip() {
    final dash = ref.watch(dashboardProvider);
    final todayMood = dash.todayMood;
    return Column(children: [
      // Row 1: Date + Level + Mood chips (compact bar)
      Row(children: [
        // Date chip
        _TopChip(
          icon: Icons.calendar_today_rounded,
          label: _formatDate(),
          gradTop: const Color(0xFFFF85AD),
          gradBot: const Color(0xFFE85A8A),
        ),
        const SizedBox(width: 6),
        // Level chip
        _TopChip(
          icon: Icons.star_rounded,
          label: 'Lv.${dash.level}',
          gradTop: const Color(0xFFFFE070),
          gradBot: const Color(0xFFE8B840),
        ),
        const SizedBox(width: 6),
        // Mood chip
        GestureDetector(
          onTap: _showMoodPopup,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFFF0F0),
                  todayMood != null
                      ? const Color(0xFFFFE0E8)
                      : const Color(0xFFF0E8E0),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outline, width: 2.5),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
                  offset: const Offset(0, 3), blurRadius: 0)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                todayMood != null
                    ? Icons.emoji_emotions_rounded
                    : Icons.add_reaction_rounded,
                size: 13, color: _brownLt,
              ),
              const SizedBox(width: 3),
              Text(
                todayMood != null
                    ? '${todayMood[0].toUpperCase()}${todayMood.substring(1)}'
                    : 'Mood?',
                style: GoogleFonts.gaegu(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _brown),
              ),
            ]),
          ),
        ),
        const Spacer(),
        // Currency pills: Cash (green), Streak (fire)
        Column(mainAxisSize: MainAxisSize.min, children: [
          _CurrencyPill(amount: dash.cash, isCoin: true),
          const SizedBox(height: 4),
          _CurrencyPill(amount: dash.streak, isCoin: false, isStreak: true),
        ]),
      ]),
      const SizedBox(height: 8),
      // Row 2: Greeting
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${_getGreeting()}, ${dash.displayName}!',
          style: GoogleFonts.gaegu(
            fontSize: 26, fontWeight: FontWeight.w700,
            color: _brown, height: 1.15,
          ),
        ),
      ),
    ]);
  }

  //  AVATAR (left) + DIALOG (right, side by side)
  Widget _buildAvatarSection() {
    final avatarConfig = ref.watch(dashboardProvider).avatarConfig;
    return Center(
      child: SizedBox(
        width: 560,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 60),
            IgnorePointer(
              child: SizedBox(
                width: 160,
                height: 230,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (avatarConfig != null)
                      OverflowBox(
                        maxWidth: 500,
                        maxHeight: 500,
                        child: Transform.scale(
                          scale: 0.50,
                          child: AliveAvatar(
                            config: avatarConfig,
                            size: 280,
                            expression: _currentExpression,
                            autoOutfit: true,
                          ),
                        ),
                      )
                    else
                      _placeholderAvatar(),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 55),
            if (_speechText.isNotEmpty)
              Expanded(child: _buildDialogBubble()),
          ],
        ),
      ),
    );
  }

  Widget _placeholderAvatar() {
    return Container(
      width: 120, height: 130,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline, width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.face_rounded, size: 36, color: CerebroTheme.pinkPop),
          const SizedBox(height: 4),
          Text('Create avatar!', textAlign: TextAlign.center,
              style: GoogleFonts.gaegu(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: _brown)),
        ],
      ),
    );
  }

  /// Warm cozy speech bubble — tail points left toward avatar
  Widget _buildDialogBubble() {
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 10),
      child: CustomPaint(
        painter: _CozyBubblePainter(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 90),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 18, 18, 16),
            child: Center(
              child: Text(
                _speechText,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.gaegu(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  //  QUICK ACTIONS — 3 chunky 3D buttons
  Widget _buildQuickActions() {
    return Row(children: [
      Expanded(child: _GameBtn(
        icon: Icons.auto_stories_rounded, label: 'Study',
        gradientTop: const Color(0xFFB8E8C0), gradientBot: _green,
        borderColor: _greenDk,
        onTap: () {
          ref.read(selectedTabProvider.notifier).state = 2; // Study tab
        },
      )),
      const SizedBox(width: 10),
      Expanded(child: _GameBtn(
        icon: Icons.nightlight_round, label: 'Sleep',
        gradientTop: const Color(0xFFC8BDF0), gradientBot: const Color(0xFF9D8AD4),
        borderColor: const Color(0xFF8670C0),
        onTap: () {
          ref.read(selectedTabProvider.notifier).state = 4; // Health tab
          // Could navigate to sleep screen directly in future
        },
      )),
      const SizedBox(width: 10),
      Expanded(child: _GameBtn(
        icon: Icons.favorite_rounded, label: 'Health',
        gradientTop: const Color(0xFF98D8F8), gradientBot: const Color(0xFF5BC0EB),
        borderColor: const Color(0xFF48A8D0),
        onTap: () {
          ref.read(selectedTabProvider.notifier).state = 4; // Health tab
        },
      )),
    ]);
  }

  //  STATS CARD — Today's snapshot with pink header
  Widget _buildStatsCard() {
    final dash = ref.watch(dashboardProvider);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0EA), Color(0xFFFFF8F4)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(children: [
        // Header strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFFF0C0B8), _pinkHdr],
            ),
          ),
          child: Row(children: [
            const Icon(Icons.dashboard_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text("Today's Snapshot", style: GoogleFonts.gaegu(
                fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
          ]),
        ),
        // 2×2 stat tiles
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(children: [
            Row(children: [
              Expanded(child: _StatTile(
                icon: Icons.timer_rounded, label: 'Study',
                value: _formatStudy(dash.studyMinutes),
                color: _skyHdr,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                icon: Icons.bedtime_rounded, label: 'Sleep',
                value: dash.sleepHours ?? '--',
                color: _purpleHdr,
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _StatTile(
                icon: Icons.mood_rounded, label: 'Mood',
                value: dash.todayMood ?? '--',
                color: _pinkHdr,
                onTap: _showMoodPopup,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                icon: Icons.check_circle_rounded, label: 'Habits',
                value: '${dash.habitsDone}/${dash.habits.length}',
                color: _green,
              )),
            ]),
          ]),
        ),
      ]),
      ),
    );
  }

  //  DAILY QUESTS — thick border, quest rows with XP pills
  Widget _buildQuestsCard() {
    final dash = ref.watch(dashboardProvider);
    final habits = dash.habits;
    final habitsDone = dash.habitsDone;
    final progress = habits.isEmpty ? 0.0 : habitsDone / habits.length;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFEEF8EC), Color(0xFFF6FBF5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(children: [
          // Green header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [_greenLt, _green],
              ),
            ),
            child: Row(children: [
              const Icon(Icons.flag_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text('Daily Quests', style: GoogleFonts.gaegu(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
              const Spacer(),
              // Progress circle
              SizedBox(
                width: 30, height: 30,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withOpacity(0.4),
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  Text('$habitsDone', style: GoogleFonts.gaegu(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.white)),
                ]),
              ),
            ]),
          ),
          // Quest rows
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(children: [
              for (int i = 0; i < habits.length; i++) ...[
                if (i > 0) Divider(height: 1,
                    color: _outline.withOpacity(0.08)),
                _questRow(i),
              ],
            ]),
          ),
          // Completion reward banner
          if (habitsDone == habits.length && habits.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_goldGlow.withOpacity(0.3), _goldGlow.withOpacity(0.15)],
                ),
              ),
              child: Center(
                child: Text('All quests done! +${habits.length * 10} XP',
                    style: GoogleFonts.gaegu(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: _brown)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _questRow(int i) {
    final h = ref.watch(dashboardProvider).habits[i];
    final done = h['done'] == true;
    final icons = {
      'water': Icons.water_drop_rounded,
      'book': Icons.menu_book_rounded,
      'fitness': Icons.fitness_center_rounded,
      'edit': Icons.edit_rounded,
      'self_improve': Icons.self_improvement_rounded,
      'no_food': Icons.no_food_rounded,
      'walk': Icons.directions_walk_rounded,
      'phone_off': Icons.phone_disabled_rounded,
      'school': Icons.school_rounded,
      'night': Icons.nights_stay_rounded,
      'check': Icons.check_rounded,
    };
    return GestureDetector(
      onTap: () => _toggleHabit(i),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          // Soft checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: done ? _green : Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: done ? _greenDk : _outline.withOpacity(0.4),
                width: 2.5,
              ),
              boxShadow: [BoxShadow(color: (done ? _greenDk : _outline).withOpacity(0.15),
                  offset: const Offset(0, 2), blurRadius: 0)],
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          // Icon circle
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: done
                  ? _green.withOpacity(0.12)
                  : const Color(0xFFF5EDE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icons[h['icon']] ?? Icons.check_rounded,
              size: 14,
              color: done ? _green : _brownLt.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(child: Text(h['name'] ?? '', style: GoogleFonts.nunito(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: done ? _brownLt : _brown,
              decoration: done ? TextDecoration.lineThrough : null))),
          // XP pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: done ? _green.withOpacity(0.15) : const Color(0xFFF0EBE4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (done ? _greenDk : _outline).withOpacity(0.2), width: 1.5),
            ),
            child: Text(
              done ? '+10' : '10',
              style: GoogleFonts.gaegu(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: done ? _green : _brownLt.withOpacity(0.5)),
            ),
          ),
        ]),
      ),
    );
  }

  //  RECOMMENDED RESOURCES — AI picks

  List<Map<String, dynamic>> _recommendedResources = [];
  bool _recsLoaded = false;

  Future<void> _loadRecommendations() async {
    if (_recsLoaded) return; // only load once per session
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/study/recommendations');
      final data = res.data as Map<String, dynamic>? ?? {};
      final recs = (data['recommendations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() { _recommendedResources = recs.take(3).toList(); _recsLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _recsLoaded = true);
    }
  }

  Widget _buildRecommendedSection() {
    // Kick off lazy load
    if (!_recsLoaded) {
      _loadRecommendations();
      return const SizedBox.shrink();
    }
    if (_recommendedResources.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E0), Color(0xFFFFFAEE)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(children: [
          // Gold header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_goldGlow, Color(0xFFFFF0C0)]),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: _brown),
              const SizedBox(width: 6),
              Text('Recommended for You', style: GoogleFonts.gaegu(
                fontSize: 17, fontWeight: FontWeight.w700, color: _brown)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(Routes.resources),
                child: Text('See All →', style: GoogleFonts.gaegu(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _brownLt)),
              ),
            ]),
          ),
          // Resource cards
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(
              children: _recommendedResources.map((rec) => _miniResourceCard(rec)).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _miniResourceCard(Map<String, dynamic> rec) {
    final type = rec['resource_type']?.toString() ?? 'article';
    final color = type == 'video' ? _skyHdr
        : type == 'article' || type == 'textbook' ? _coralHdr
        : type == 'practice' ? _green
        : _goldGlow;
    final icon = type == 'video' ? Icons.play_circle_rounded
        : type == 'article' || type == 'textbook' ? Icons.article_rounded
        : type == 'practice' ? Icons.quiz_rounded
        : Icons.lightbulb_rounded;

    return GestureDetector(
      onTap: () => context.push(Routes.resources),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _panelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outline.withOpacity(0.2), width: 2),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.08),
              offset: const Offset(0, 2), blurRadius: 0)],
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _brown),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rec['title'] ?? 'Resource',
                style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w700, color: _brown),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              Text(
                rec['why_recommended'] ?? rec['description'] ?? '',
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
          )),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 16, color: _brownLt.withOpacity(0.5)),
        ]),
      ),
    );
  }

  //  INSIGHT CARD — warm gradient, thick border
  Widget _buildInsightCard() {
    final insight = _getInsight();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [insight.bgStart, insight.bgEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: Row(children: [
        // Icon in soft circle
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(insight.icon, size: 20, color: insight.iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(insight.title, style: GoogleFonts.gaegu(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
              const SizedBox(height: 2),
              Text(insight.message, style: GoogleFonts.gaegu(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: _brownLt, height: 1.3)),
            ],
          ),
        ),
      ]),
    );
  }

  _Insight _getInsight() {
    final dash = ref.read(dashboardProvider);
    if (dash.streak >= 7) {
      return _Insight(
        title: 'Amazing Streak!',
        message: '${dash.streak} days strong! Consistency builds mastery.',
        icon: Icons.local_fire_department_rounded,
        iconColor: CerebroTheme.coral,
        bgStart: const Color(0xFFFFE8DE),
        bgEnd: const Color(0xFFFFF0E8),
      );
    }
    if (dash.studyMinutes >= 60) {
      return _Insight(
        title: 'Study Champion!',
        message: 'You studied ${_formatStudy(dash.studyMinutes)} today — take a break!',
        icon: Icons.auto_stories_rounded,
        iconColor: CerebroTheme.sky,
        bgStart: const Color(0xFFE4F2FF),
        bgEnd: const Color(0xFFF0F8FF),
      );
    }
    if (dash.habitsDone == dash.habits.length && dash.habits.isNotEmpty) {
      return _Insight(
        title: 'All Quests Done!',
        message: 'You completed every quest. You\'re a superstar!',
        icon: Icons.stars_rounded,
        iconColor: const Color(0xFFE8B840),
        bgStart: const Color(0xFFFFF8E0),
        bgEnd: const Color(0xFFFFFAEE),
      );
    }
    return _Insight(
      title: 'Tip of the Day',
      message: 'Start by logging your mood and tackling your daily quests!',
      icon: Icons.lightbulb_rounded,
      iconColor: const Color(0xFFE8B840),
      bgStart: const Color(0xFFFFF8E0),
      bgEnd: const Color(0xFFFFFAEE),
    );
  }

  //  STAGGER ANIMATION
  Widget _stagger(double delay, Widget child) {
    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(
          ((_enterCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
        return Opacity(opacity: t, child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)), child: child));
      },
    );
  }
}

//  INSIGHT DATA
class _Insight {
  final String title, message;
  final IconData icon;
  final Color iconColor, bgStart, bgEnd;
  const _Insight({required this.title, required this.message, required this.icon,
    required this.iconColor, required this.bgStart, required this.bgEnd});
}

//  CURRENCY PILL — store-style green pill with icon
//  TOP CHIP — compact badge for date / level / mood
class _TopChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gradTop, gradBot;
  const _TopChip({
    required this.icon, required this.label,
    required this.gradTop, required this.gradBot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [gradTop, gradBot],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline, width: 2.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 3), blurRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.gaegu(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
        )),
      ]),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  final int amount;
  final bool isCoin;
  final bool isStreak;
  final bool isXp;
  const _CurrencyPill({
    required this.amount, this.isCoin = false, this.isStreak = false,
    this.isXp = false,
  });

  @override
  Widget build(BuildContext context) {
    // Pill colors based on type
    final List<Color> pillGrad;
    final Color pillBorder;
    if (isXp) {
      pillGrad = const [Color(0xFFFFE888), Color(0xFFE8C840)];
      pillBorder = const Color(0xFFD0B048);
    } else {
      pillGrad = const [Color(0xFFD0F0CA), _green];
      pillBorder = _greenDk;
    }

    return SizedBox(height: 36, width: 105, child: Stack(
      clipBehavior: Clip.none,
      children: [
        // Pill body
        Positioned(left: 16, top: 2, child: Container(
          constraints: const BoxConstraints(minWidth: 60),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: pillGrad),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: pillBorder, width: 2.5),
            boxShadow: [BoxShadow(color: pillBorder.withOpacity(0.35),
                offset: const Offset(0, 3), blurRadius: 0)],
          ),
          alignment: Alignment.center,
          child: Text('$amount', style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
            shadows: [Shadow(color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 1), blurRadius: 0)])),
        )),
        // Icon
        Positioned(left: -2, top: -1, child: isStreak
          ? Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8866), Color(0xFFE85540)]),
                shape: BoxShape.circle,
                border: Border.all(color: _outline, width: 2.5),
              ),
              child: const Icon(Icons.local_fire_department_rounded,
                  size: 18, color: Colors.white),
            )
          : isXp
            ? Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE888), Color(0xFFE8C840)]),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD0B048), width: 2.5),
                ),
                child: const Icon(Icons.star_rounded,
                    size: 18, color: Colors.white),
              )
            : Image.asset('assets/store/coin.png', width: 36, height: 36,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _fallbackCoin()),
        ),
      ],
    ));
  }

  static Widget _fallbackCoin() {
    return Container(width: 34, height: 34, decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFE8D060),
      border: Border.all(color: const Color(0xFFC8A840), width: 2.5),
    ), child: Center(child: Text('\$', style: GoogleFonts.gaegu(
      fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFA08020)))));
  }
}

//  GAME BUTTON — chunky 3D button (store-style)
class _GameBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color gradientTop, gradientBot, borderColor;
  final VoidCallback onTap;
  const _GameBtn({
    required this.icon, required this.label,
    required this.gradientTop, required this.gradientBot,
    required this.borderColor, required this.onTap,
  });
  @override State<_GameBtn> createState() => _GameBtnState();
}

class _GameBtnState extends State<_GameBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [widget.gradientTop, widget.gradientBot],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline, width: 3),
          boxShadow: _pressed ? [] : [
            BoxShadow(color: _outline.withOpacity(0.3),
                offset: const Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 20, color: Colors.white),
            const SizedBox(height: 3),
            Text(widget.label, style: GoogleFonts.gaegu(fontSize: 14,
                fontWeight: FontWeight.w700, color: Colors.white),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

//  STAT TILE — mini card inside stats grid
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final VoidCallback? onTap;
  const _StatTile({
    required this.icon, required this.label, required this.value,
    required this.color, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline.withOpacity(0.18), width: 2),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.08),
            offset: const Offset(0, 2), blurRadius: 0)],
      ),
      child: Row(children: [
        // Icon in soft colored circle
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.gaegu(
                fontSize: 13, fontWeight: FontWeight.w700, color: _brownLt)),
            Text(value, style: GoogleFonts.gaegu(
                fontSize: 18, fontWeight: FontWeight.w700, color: _brown),
                overflow: TextOverflow.ellipsis, maxLines: 1),
          ],
        )),
      ]),
    );
    if (onTap != null) return GestureDetector(onTap: onTap, child: tile);
    return tile;
  }
}

//  RPG DIALOG BOX — PRESERVED EXACTLY
class _CozyBubblePainter extends CustomPainter {
  static const _radius = 18.0;
  static const _border = 3.0;
  static const _tailW = 16.0;  // how far left the tail pokes out
  static const _tailH = 22.0;  // vertical height of tail opening

  static const _fillColor = Color(0xFFFFF8F2);
  static const _borderColor = Color(0xFF6E5848);  // warm brown matching theme

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h), Radius.circular(_radius));

    // Soft shadow (warm, not harsh)
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 5, w, h), Radius.circular(_radius));
    canvas.drawRRect(shadowRect,
      Paint()..color = _borderColor.withOpacity(0.12));

    // Fill
    canvas.drawRRect(boxRect, Paint()..color = _fillColor);

    // Left tail pointing toward avatar
    final tailCY = h / 2;
    final tailTip = Offset(-_tailW, tailCY);
    final tailTop = Offset(0, tailCY - _tailH / 2);
    final tailBot = Offset(0, tailCY + _tailH / 2);

    // Tail border
    final tailOuter = Path()
      ..moveTo(tailTip.dx, tailTip.dy)
      ..lineTo(tailTop.dx, tailTop.dy)
      ..lineTo(tailBot.dx, tailBot.dy)
      ..close();
    canvas.drawPath(tailOuter, Paint()..color = _borderColor);

    // Tail fill (inset to show border)
    final tailInner = Path()
      ..moveTo(tailTip.dx + 6, tailTip.dy)
      ..lineTo(tailTop.dx, tailTop.dy + 5)
      ..lineTo(tailBot.dx, tailBot.dy - 5)
      ..close();
    canvas.drawPath(tailInner, Paint()..color = _fillColor);

    // Border
    canvas.drawRRect(boxRect, Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//  MOOD POPUP — PRESERVED EXACTLY
class _MoodPopup extends StatelessWidget {
  final AvatarConfig config;
  final String? selected;
  final ValueChanged<String> onPick;

  const _MoodPopup({
    required this.config, required this.selected, required this.onPick,
  });

  static const _moods = [
    {'key': 'happy',    'label': 'Happy',    'color': Color(0xFFFFF9E0)},
    {'key': 'sad',      'label': 'Sad',      'color': Color(0xFFE8F0FF)},
    {'key': 'calm',     'label': 'Calm',     'color': Color(0xFFE8FFF0)},
    {'key': 'excited',  'label': 'Excited',  'color': Color(0xFFFFF0E0)},
    {'key': 'tired',    'label': 'Tired',    'color': Color(0xFFEDE5FF)},
    {'key': 'anxious',  'label': 'Anxious',  'color': Color(0xFFFFE8EC)},
    {'key': 'grateful', 'label': 'Grateful', 'color': Color(0xFFFFF0F8)},
    {'key': 'angry',    'label': 'Angry',    'color': Color(0xFFFFE0E0)},
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 540,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF8),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _outline.withOpacity(0.2), width: 2),
            boxShadow: [
              BoxShadow(color: _outline.withOpacity(0.08),
                  offset: const Offset(0, 8), blurRadius: 32),
              BoxShadow(color: Colors.black.withOpacity(0.06),
                  offset: const Offset(0, 2), blurRadius: 8),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warm header — soft peach/coral, not hot pink
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFF0C0B8), Color(0xFFE8A8A0)]),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('How are you feeling?', style: GoogleFonts.gaegu(
                          fontSize: 24, fontWeight: FontWeight.w700,
                          color: _brown)),
                      Positioned(
                        right: 16,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: _brown.withOpacity(0.6)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Grid — bigger stickers, smaller tile boxes
                Container(
                  color: const Color(0xFFFFFBF8),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: _moods.map((m) {
                      final key = m['key'] as String;
                      final label = m['label'] as String;
                      final tileColor = m['color'] as Color;
                      final isSel = selected == key;
                      return GestureDetector(
                        onTap: () => onPick(key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFFFFE0E8)
                                : tileColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel
                                  ? const Color(0xFFE8A8A0)
                                  : _outline.withOpacity(0.15),
                              width: isSel ? 2.5 : 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: MoodSticker(
                                  config: config,
                                  mood: key,
                                  size: 100,
                                ),
                              ),
                              Text(label, style: GoogleFonts.gaegu(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? _brown : _brownLt)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//  PAWPRINT BACKGROUND (matching store_tab.dart exactly)
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
    c.save();
    c.translate(cx, cy);
    c.rotate(a);
    c.drawOval(Rect.fromCenter(
      center: Offset.zero, width: r * 2.2, height: r * 1.8), p);
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
