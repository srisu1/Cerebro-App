// Improved dashboard tab with updated typography and card layout.

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
import 'package:cerebro_app/screens/health/health_tab.dart';
import 'dart:math' as math;

const _ombre1  = Color(0xFFFFFBF7);
const _ombre2  = Color(0xFFFFF8F3);
const _ombre3  = Color(0xFFFFF3EF);
const _ombre4  = Color(0xFFFEEDE9);
const _pawClr  = Color(0xFFF8BCD0);

const _outline = Color(0xFF6E5848);
const _brown   = Color(0xFF4E3828);
const _brownLt = Color(0xFF7A5840);
const _brownSoft = Color(0xFF9A8070);

const _cardFill  = Color(0xFFFFF8F4);
const _panelBg   = Color(0xFFFFF6EE);
const _cream     = Color(0xFFFDEFDB);
const _olive     = Color(0xFF98A869);
const _oliveDk   = Color(0xFF58772F);
const _pinkLt    = Color(0xFFFFD5F5);
const _pink      = Color(0xFFFEA9D3);
const _pinkDk    = Color(0xFFE890B8);
const _coral     = Color(0xFFF7AEAE);
const _gold      = Color(0xFFE4BC83);
const _orange    = Color(0xFFFFBC5C);
const _red       = Color(0xFFEF6262);
const _blueLt    = Color(0xFFDDF6FF);
const _green     = Color(0xFFA8D5A3);
const _greenLt   = Color(0xFFC2E8BC);
const _greenDk   = Color(0xFF88B883);
const _goldGlow  = Color(0xFFF8E080);
const _purpleHdr = Color(0xFFCDA8D8);
const _skyHdr    = Color(0xFF9DD4F0);

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});
  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab>
    with TickerProviderStateMixin {
  // UI-only state
  ExpressionState _currentExpression = ExpressionState.neutral;
  String _speechText = '';
  Timer? _speechTimer;
  late AnimationController _enterCtrl;
  String? _lastMood;
  int? _prevTab;

  // Recommended resources (lazy-loaded)
  List<Map<String, dynamic>> _recommendedResources = [];
  bool _recsLoaded = false;

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

  void _syncExpression(DashboardState dash) {
    final effectiveMood = dash.todayMood ?? dash.backendExpression;
    if (effectiveMood != _lastMood) {
      _lastMood = effectiveMood;
      _currentExpression = effectiveMood != null
          ? ExpressionEngine.fromMood(effectiveMood)
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

  String _getCerebroSays(DashboardState dash) {
    final tips = <String>[];
    final sleepVal = double.tryParse(dash.sleepHours ?? '');
    if (sleepVal != null && sleepVal > 0) {
      if (sleepVal >= 8) tips.add('Great sleep last night! Your brain is ready to learn.');
      else if (sleepVal < 6) tips.add('You slept under 6h — take it easy today.');
    }
    if (dash.streak >= 7) tips.add('${dash.streak}-day streak! Consistency is your superpower.');
    else if (dash.streak >= 3) tips.add('${dash.streak} days in a row — keep the momentum!');
    if (dash.studyMinutes > 60) tips.add('${dash.studyMinutes}min studied today — impressive!');
    else if (dash.studyMinutes == 0) tips.add('No study yet today — even 15 min makes a difference!');
    final doneCount = dash.habits.where((h) => h['done'] == true).length;
    final total = dash.habits.length;
    if (total > 0 && doneCount == total) tips.add('All quests done! You\'re crushing it today!');
    else if (total > 0 && doneCount == 0) tips.add('Your daily quests await — start with just one!');
    if (dash.level >= 10) tips.add('Level ${dash.level}! You\'re becoming a Cerebro master.');
    if (tips.isEmpty) return 'All quests on track — you\'re crushing it~';
    return tips[DateTime.now().minute % tips.length];
  }

  String _formatDate() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
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

  void _showLevelUpCelebration(int level) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (ctx, a1, a2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(a1.value),
          child: Opacity(opacity: a1.value, child: child),
        );
      },
      pageBuilder: (ctx, a1, a2) {
        final title = level <= 5 ? 'Novice' :
                      level <= 10 ? 'Apprentice' :
                      level <= 20 ? 'Scholar' : 'Master';
        return Center(child: Material(
          color: Colors.transparent,
          child: Container(
            width: 340, height: 320,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF8E0), Color(0xFFFFF0D0)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _outline, width: 3.5),
              boxShadow: [
                BoxShadow(color: _goldGlow.withOpacity(0.6),
                    blurRadius: 40, spreadRadius: 8),
                BoxShadow(color: _outline.withOpacity(0.3),
                    offset: const Offset(0, 8), blurRadius: 0),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFFFFE870), Color(0xFFFFB830)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: _outline, width: 3),
                    boxShadow: [BoxShadow(color: _goldGlow.withOpacity(0.5),
                        blurRadius: 20, spreadRadius: 4)],
                  ),
                  child: const Icon(Icons.star_rounded, size: 48, color: Color(0xFF8B6914)),
                ),
                const SizedBox(height: 16),
                const Text('LEVEL UP!', style: TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 34,
                  fontWeight: FontWeight.w400,
                  color: _brown,
                  letterSpacing: 3,
                )),
                const SizedBox(height: 4),
                Text('Level $level — $title', style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _brownLt)),
                const SizedBox(height: 16),
                Text('Keep going, you\'re amazing!',
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600,
                    color: _brownLt.withOpacity(0.8))),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFE870), Color(0xFFE8C040)]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _outline, width: 2.5),
                      boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
                          offset: const Offset(0, 4), blurRadius: 0)],
                    ),
                    child: const Text('Awesome!', style: TextStyle(
                      fontFamily: 'Bitroad',
                      fontSize: 20,
                      color: _brown,
                    )),
                  ),
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  void _toggleHabit(int i) {
    ref.read(dashboardProvider.notifier).toggleHabit(i);
  }

  Future<void> _loadRecommendations() async {
    if (_recsLoaded) return;
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

  //  MAIN BUILD
  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(selectedTabProvider);
    if (currentTab != 0 && currentTab == _prevTab) return const SizedBox.shrink();
    _prevTab = currentTab;

    final dash = ref.watch(dashboardProvider);
    _syncExpression(dash);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dash.shouldShowLevelUp && mounted) {
        ref.read(dashboardProvider.notifier).markLevelUpSeen();
        _showLevelUpCelebration(dash.level);
      }
    });

    final screenW = MediaQuery.of(context).size.width;
    final contentW = (screenW * 0.92).clamp(360.0, 1200.0);
    final isWide = contentW >= 900;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _stagger(0.0, _buildHeaderRow(dash)),
                  const SizedBox(height: 16),
                  _stagger(0.08, _buildAvatarSection(dash, contentW)),
                  const SizedBox(height: 8),
                  _stagger(0.12, _buildXpDivider(dash)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: isWide
                          ? _stagger(0.16, _buildTwoColumnContent(dash))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _stagger(0.16, _buildWeeklyStreak(dash)),
                                const SizedBox(height: 18),
                                _stagger(0.20, _buildStatsCard(dash)),
                                const SizedBox(height: 18),
                                _stagger(0.24, _buildQuestsCard(dash)),
                                const SizedBox(height: 16),
                                _stagger(0.28, _buildInsightTip(dash)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  //  HEADER ROW (greeting + pills)
  Widget _buildHeaderRow(DashboardState dash) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()}, ${dash.displayName}',
                style: const TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 22,
                  color: _brown,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getCerebroSays(dash),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _brownSoft,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Right: pills
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _Pill(
              icon: Icons.calendar_today_rounded,
              label: _formatDate(),
              color: _purpleHdr.withOpacity(0.5),
            ),
            _Pill(
              icon: Icons.stars_rounded,
              label: 'Lv. ${dash.level}',
              color: _skyHdr.withOpacity(0.5),
            ),
            GestureDetector(
              onTap: _showMoodPopup,
              child: _Pill(
                icon: dash.todayMood != null
                    ? Icons.emoji_emotions_rounded
                    : Icons.add_reaction_rounded,
                label: dash.todayMood != null
                    ? '${dash.todayMood![0].toUpperCase()}${dash.todayMood!.substring(1)}'
                    : 'Mood?',
                color: _coral,
              ),
            ),
            _Pill(icon: Icons.monetization_on_rounded, label: '${dash.cash}', color: _gold),
            _Pill(icon: Icons.local_fire_department_rounded, label: '${dash.streak}d', color: _orange),
            _NotifBell(count: 3),
          ],
        ),
      ],
    );
  }

  //  AVATAR + SPEECH BUBBLE
  Widget _buildAvatarSection(DashboardState dash, double contentW) {
    final isSmall  = contentW < 400;
    final isMedium = contentW < 700;

    final double avatarScale = isSmall ? 0.35 : (isMedium ? 0.40 : 0.45);
    final double avatarSize  = isSmall ? 260.0 : (isMedium ? 280.0 : 310.0);
    final double sectionH    = isSmall ? 130.0 : (isMedium ? 150.0 : 165.0);
    final double avatarTop   = isSmall ? -65.0 : (isMedium ? -80.0 : -100.0);
    const double avatarBottom = 20.0;

    final double bubbleLeft = isSmall
        ? contentW / 2 + 95
        : (isMedium ? contentW / 2 + 130 : contentW / 2 + 175);
    final double bubbleTop = isSmall ? 20.0 : (isMedium ? 25.0 : 30.0);
    final double bubbleW   = isSmall ? 145.0 : (isMedium ? 165.0 : 195.0);

    return SizedBox(
      height: sectionH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: avatarTop,
            bottom: avatarBottom,
            child: Center(
              child: IgnorePointer(
                child: dash.avatarConfig != null
                    ? OverflowBox(
                        maxWidth: 560,
                        maxHeight: 560,
                        child: Transform.scale(
                          scale: avatarScale,
                          child: AliveAvatar(
                            config: dash.avatarConfig!,
                            size: avatarSize,
                            expression: _currentExpression,
                          ),
                        ),
                      )
                    : _placeholderAvatar(),
              ),
            ),
          ),
          if (_speechText.isNotEmpty)
            Positioned(
              left: bubbleLeft,
              top: bubbleTop,
              child: SizedBox(
                width: bubbleW,
                child: _buildSpeechBubble(),
              ),
            ),
        ],
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
          const Text(
            'Create avatar!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Bitroad',
              fontSize: 14,
              color: _brown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble() {
    return CustomPaint(
      painter: _CozyBubblePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 16, 14),
        child: Text(
          _speechText,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Bitroad',
            fontSize: 15,
            color: _brown,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  //  XP DIVIDER BAR
  Widget _buildXpDivider(DashboardState dash) {
    final xpPerLevel = 500;
    final currentXp = dash.totalXp;
    final levelXp = dash.level * xpPerLevel;
    final prevLevelXp = (dash.level - 1) * xpPerLevel;
    final progress = levelXp > prevLevelXp
        ? ((currentXp - prevLevelXp) / (levelXp - prevLevelXp)).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Lv. ${dash.level}',
            style: const TextStyle(fontFamily: 'Bitroad', fontSize: 12, color: _brownLt)),
          const SizedBox(width: 14),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.22,
            height: 8,
            child: Container(
              decoration: BoxDecoration(
                color: _olive.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _outline.withOpacity(0.25), width: 1),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_olive, _oliveDk]),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text('${currentXp - prevLevelXp} / ${levelXp - prevLevelXp} XP',
            style: GoogleFonts.nunito(
              fontSize: 11, fontWeight: FontWeight.w700, color: _brownSoft)),
        ],
      ),
    );
  }

  //  TWO-COLUMN CONTENT (wide layout)
  Widget _buildTwoColumnContent(DashboardState dash) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildWeeklyStreak(dash),
                const SizedBox(height: 16),
                Expanded(child: _buildStatsCard(dash)),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                Expanded(child: _buildQuestsCard(dash)),
                const SizedBox(height: 12),
                _buildInsightTip(dash),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //  WEEKLY STREAK
  Widget _buildWeeklyStreak(DashboardState dash) {
    const dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final todayIdx = DateTime.now().weekday - 1;
    final streakDays = dash.streak.clamp(0, 7);
    final todayHasProgress = dash.habitsDone > 0;

    final displayStreak = todayHasProgress
        ? math.max(streakDays, 1)
        : streakDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: _oliveDk),
            const SizedBox(width: 7),
            const Text('Weekly Streak',
              style: TextStyle(fontFamily: 'Bitroad', fontSize: 15, color: _brown)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _olive,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _oliveDk, width: 1.5),
                boxShadow: [BoxShadow(color: _oliveDk.withOpacity(0.4),
                    offset: const Offset(1, 1), blurRadius: 0)],
              ),
              child: Text('$displayStreak days',
                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: List.generate(7, (i) {
            final isToday = i == todayIdx;
            final startIdx = todayIdx - displayStreak + 1;
            final isDone = i >= startIdx && i <= todayIdx && displayStreak > 0;

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: isToday ? _cream : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isToday ? _outline.withOpacity(0.35) : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: isToday
                      ? [BoxShadow(color: _outline.withOpacity(0.22),
                          offset: const Offset(2, 2), blurRadius: 0)]
                      : [],
                ),
                child: Column(
                  children: [
                    Text(dayLabels[i],
                      style: GoogleFonts.nunito(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: _brownSoft, letterSpacing: 0.3)),
                    const SizedBox(height: 3),
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: isDone ? _olive : _cream,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? _oliveDk : _outline.withOpacity(0.35),
                          width: 2,
                        ),
                        boxShadow: isDone
                            ? [BoxShadow(color: _oliveDk.withOpacity(0.4),
                                offset: const Offset(1, 1), blurRadius: 0)]
                            : [BoxShadow(color: _outline.withOpacity(0.1),
                                offset: const Offset(1, 1), blurRadius: 0)],
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 3),
                    Text(isDone ? '+XP' : '—',
                      style: GoogleFonts.nunito(
                        fontSize: 9, fontWeight: FontWeight.w700, color: _brownSoft)),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  //  TODAY'S SNAPSHOT
  Widget _buildStatsCard(DashboardState dash) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart_rounded, size: 16, color: _oliveDk),
            const SizedBox(width: 7),
            const Text("Today's Snapshot",
              style: TextStyle(fontFamily: 'Bitroad', fontSize: 15, color: _brown)),
          ],
        ),
        const SizedBox(height: 13),
        Column(
          children: [
            Row(children: [
              Expanded(child: _StatTile(
                icon: Icons.menu_book_rounded, label: 'Study',
                value: _formatStudy(dash.studyMinutes),
                bgColor: _blueLt.withOpacity(0.38),
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                icon: Icons.nightlight_round, label: 'Sleep',
                value: dash.sleepHours ?? '--',
                bgColor: _pinkLt.withOpacity(0.3),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: _showMoodPopup,
                child: _StatTile(
                  icon: Icons.emoji_emotions_rounded, label: 'Mood',
                  value: dash.todayMood ?? '--',
                  bgColor: _gold.withOpacity(0.24),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                icon: Icons.check_circle_rounded, label: 'Habits',
                value: '${dash.habitsDone}/${dash.habits.length}',
                bgColor: _olive.withOpacity(0.65),
                isHighlight: true,
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Consumer(
                builder: (context, ref2, _) {
                  final health = ref2.watch(healthProvider);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ref2.read(healthProvider.notifier).incrementWater();
                    },
                    onLongPress: () {
                      ref2.read(healthProvider.notifier).decrementWater();
                    },
                    child: _StatTile(
                      icon: Icons.water_drop_rounded, label: 'Water',
                      value: '${health.waterGlasses}/8',
                      bgColor: _cream.withOpacity(0.6),
                    ),
                  );
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                icon: Icons.gps_fixed_rounded, label: 'Focus',
                value: dash.studyMinutes > 0 ? '${(dash.studyMinutes / 0.6).clamp(0, 100).toInt()}%' : '--',
                bgColor: _coral.withOpacity(0.3),
              )),
            ]),
          ],
        ),
      ],
    );
  }

  //  TODAY'S QUESTS
  Widget _buildQuestsCard(DashboardState dash) {
    final habits = dash.habits;
    final habitsDone = dash.habitsDone;
    final progress = habits.isEmpty ? 0.0 : habitsDone / habits.length;
    final remaining = habits.length - habitsDone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description_rounded, size: 16, color: _oliveDk),
            const SizedBox(width: 7),
            const Text("Today's Quests",
              style: TextStyle(fontFamily: 'Bitroad', fontSize: 15, color: _brown)),
            const Spacer(),
            GestureDetector(
              onTap: () => ref.read(selectedTabProvider.notifier).state = 1,
              child: Text('See All →', style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.5),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36, height: 36,
                        child: Stack(alignment: Alignment.center, children: [
                          SizedBox(
                            width: 36, height: 36,
                            child: CustomPaint(
                              painter: _ProgressRingPainter(
                                progress: progress,
                                bgColor: _olive.withOpacity(0.18),
                                fgColor: _olive,
                                strokeWidth: 4,
                              ),
                            ),
                          ),
                          Text('$habitsDone/${habits.length}',
                            style: const TextStyle(
                              fontFamily: 'Bitroad', fontSize: 10, color: _brown)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$habitsDone of ${habits.length} quests done',
                              style: GoogleFonts.nunito(
                                fontSize: 14, fontWeight: FontWeight.w800, color: _brown)),
                            Text('$remaining remaining',
                              style: GoogleFonts.nunito(
                                fontSize: 11, fontWeight: FontWeight.w600, color: _brownSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _outline.withOpacity(0.06)),
                ...List.generate(habits.length, (i) => _questRow(i)),
                if (habitsDone == habits.length && habits.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_goldGlow.withOpacity(0.3), _goldGlow.withOpacity(0.15)]),
                    ),
                    child: Center(
                      child: Text('All quests done! +${habits.length * 10} XP',
                        style: const TextStyle(
                          fontFamily: 'Bitroad',
                          fontSize: 17,
                          color: _brown,
                        )),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _questRow(int i) {
    final h = ref.watch(dashboardProvider).habits[i];
    final done = h['done'] == true;
    final icons = {
      'water': Icons.water_drop_rounded, 'book': Icons.menu_book_rounded,
      'fitness': Icons.fitness_center_rounded, 'edit': Icons.edit_rounded,
      'self_improve': Icons.self_improvement_rounded, 'no_food': Icons.no_food_rounded,
      'walk': Icons.directions_walk_rounded, 'phone_off': Icons.phone_disabled_rounded,
      'school': Icons.school_rounded, 'night': Icons.nights_stay_rounded,
      'check': Icons.check_rounded,
    };
    return GestureDetector(
      onTap: () => _toggleHabit(i),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: i < ref.read(dashboardProvider).habits.length - 1
                ? BorderSide(color: _outline.withOpacity(0.06))
                : BorderSide.none,
          ),
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: done ? _olive : _cream,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: done ? _oliveDk : _outline.withOpacity(0.35), width: 1.5),
              boxShadow: [BoxShadow(color: (done ? _oliveDk : _outline).withOpacity(0.18),
                  offset: const Offset(1, 1), blurRadius: 0)],
            ),
            child: done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h['name'] ?? '',
                style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: done ? _olive : _brown,
                  decoration: done ? TextDecoration.lineThrough : null)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _outline.withOpacity(0.25), width: 1),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.12),
                  offset: const Offset(1, 1), blurRadius: 0)],
            ),
            child: Text(done ? '+10' : '10',
              style: const TextStyle(fontFamily: 'Bitroad', fontSize: 11, color: _brown)),
          ),
        ]),
      ),
    );
  }

  //  DAILY INSIGHT TIP
  Widget _buildInsightTip(DashboardState dash) {
    final insight = _getInsight(dash);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: _pinkLt.withOpacity(0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.18), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _outline.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(Icons.lightbulb_outline_rounded, size: 12, color: _pinkDk),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY INSIGHT',
                  style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 0.7, color: _pinkDk)),
                const SizedBox(height: 3),
                Text(insight,
                  style: const TextStyle(
                    fontFamily: 'Bitroad',
                    fontSize: 15,
                    color: _brown,
                    height: 1.4,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInsight(DashboardState dash) {
    if (dash.streak >= 7) return '${dash.streak} days strong! Consistency builds mastery.';
    if (dash.studyMinutes >= 60) return 'You studied ${_formatStudy(dash.studyMinutes)} today — take a well-deserved break!';
    if (dash.habitsDone == dash.habits.length && dash.habits.isNotEmpty) return 'All quests done! You\'re a superstar today!';
    final sleepVal = double.tryParse(dash.sleepHours ?? '');
    if (sleepVal != null && sleepVal >= 7) return 'Focus drops 23% with less than 6h sleep — you got ${dash.sleepHours} last night. Great shape!';
    return 'Start by logging your mood and tackling your daily quests!';
  }

  //  STAGGER ANIMATION
  // Stagger animation. Passes `child` through AnimatedBuilder (so the subtree
  // isn't rebuilt every frame) and ignores pointer events while animating —
  // prevents the desktop `_debugDuringDeviceUpdate` mouse-tracker assertion
  // that fires when hit-test regions change mid-update.
  Widget _stagger(double delay, Widget child) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _enterCtrl,
        child: child,
        builder: (_, c) {
          final t = Curves.easeOutCubic.transform(
            ((_enterCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
          return IgnorePointer(
            ignoring: t < 1.0,
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - t)), child: c),
            ),
          );
        },
      ),
    );
  }
}

//  PILL
class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
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
        Icon(icon, size: 13, color: _outline),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
          fontFamily: 'Bitroad',
          fontSize: 13,
          color: _brown,
        )),
      ]),
    );
  }
}

//  NOTIFICATION BELL
class _NotifBell extends StatelessWidget {
  final int count;
  const _NotifBell({this.count = 0});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _coral,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.28),
                offset: const Offset(2, 2), blurRadius: 0)],
          ),
          child: Icon(Icons.notifications_rounded, size: 18, color: _outline),
        ),
        if (count > 0)
          Positioned(
            top: -4, right: -4,
            child: Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: _red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text('$count',
                  style: GoogleFonts.nunito(
                    fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }
}

//  STAT TILE
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color bgColor;
  final bool isHighlight;
  const _StatTile({
    required this.icon, required this.label, required this.value,
    required this.bgColor, this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isHighlight ? Colors.white : _brown;
    final labelColor = isHighlight ? Colors.white.withOpacity(0.85) : _brownSoft;
    final iconBg = isHighlight ? Colors.white.withOpacity(0.2) : Colors.white;
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
              style: TextStyle(fontFamily: 'Bitroad', fontSize: 17, color: textColor),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            Text(label.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 0.5, color: labelColor)),
          ],
        )),
      ]),
    );
  }
}

//  PROGRESS RING PAINTER
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color bgColor, fgColor;
  final double strokeWidth;
  _ProgressRingPainter({
    required this.progress, required this.bgColor,
    required this.fgColor, required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(center, radius,
      Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = fgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress;
}

//  COZY SPEECH BUBBLE
class _CozyBubblePainter extends CustomPainter {
  static const _radius = 18.0;
  static const _border = 2.0;
  static const _tailW = 12.0;
  static const _tailH = 18.0;
  static const _fillColor = Color(0xFFFFFBF8);
  static const _borderColor = Color(0xFF6E5848);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h), Radius.circular(_radius));

    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 5, w, h), Radius.circular(_radius));
    canvas.drawRRect(shadowRect, Paint()..color = _borderColor.withOpacity(0.12));

    canvas.drawRRect(boxRect, Paint()..color = _fillColor);

    final tailCY = h / 2;
    final tailTip = Offset(-_tailW, tailCY);
    final tailTop = Offset(0, tailCY - _tailH / 2);
    final tailBot = Offset(0, tailCY + _tailH / 2);

    final tailOuter = Path()..moveTo(tailTip.dx, tailTip.dy)
      ..lineTo(tailTop.dx, tailTop.dy)..lineTo(tailBot.dx, tailBot.dy)..close();
    canvas.drawPath(tailOuter, Paint()..color = _borderColor);

    final tailInner = Path()..moveTo(tailTip.dx + 6, tailTip.dy)
      ..lineTo(tailTop.dx, tailTop.dy + 5)..lineTo(tailBot.dx, tailBot.dy - 5)..close();
    canvas.drawPath(tailInner, Paint()..color = _fillColor);

    canvas.drawRRect(boxRect, Paint()
      ..color = _borderColor..style = PaintingStyle.stroke..strokeWidth = _border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//  MOOD POPUP
class _MoodPopup extends StatelessWidget {
  final AvatarConfig config;
  final String? selected;
  final ValueChanged<String> onPick;
  const _MoodPopup({required this.config, required this.selected, required this.onPick});

  static const _moods = [
    {'key': 'happy',   'label': 'Happy',   'color': Color(0xFFFFF9E0)},
    {'key': 'sad',     'label': 'Sad',     'color': Color(0xFFE8F0FF)},
    {'key': 'anxious', 'label': 'Anxious', 'color': Color(0xFFFFE8EC)},
    {'key': 'calm',    'label': 'Calm',    'color': Color(0xFFE8FFF0)},
    {'key': 'excited', 'label': 'Excited', 'color': Color(0xFFFFF0E0)},
    {'key': 'tired',   'label': 'Tired',   'color': Color(0xFFEDE5FF)},
    {'key': 'angry',   'label': 'Angry',   'color': Color(0xFFFFE0E0)},
    {'key': 'focused', 'label': 'Focused', 'color': Color(0xFFF0FFF0)},
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
                      const Text('How are you feeling?', style: TextStyle(
                        fontFamily: 'Bitroad',
                        fontSize: 24,
                        color: _brown,
                      )),
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
                            child: Icon(Icons.close_rounded, size: 16, color: _brown.withOpacity(0.6)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFFFFE0E8) : tileColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel ? const Color(0xFFE8A8A0) : _outline.withOpacity(0.15),
                              width: isSel ? 2.5 : 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(child: MoodSticker(config: config, mood: key, size: 100)),
                              Text(label, style: const TextStyle(
                                fontFamily: 'Bitroad',
                                fontSize: 14,
                                color: _brownLt,
                              )),
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

//  PAWPRINT BACKGROUND
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
