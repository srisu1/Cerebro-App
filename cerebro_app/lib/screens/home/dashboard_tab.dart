// Dashboard tab — greeting, avatar, XP bar, stats, quests, insight.

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
import 'package:cerebro_app/providers/notifications_provider.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';
import 'package:cerebro_app/widgets/alive_avatar.dart';
import 'package:cerebro_app/widgets/mood_sticker.dart';
import 'package:cerebro_app/screens/health/health_tab.dart';
import 'dart:math' as math;


bool get _darkMode =>
    CerebroTheme.brightnessNotifier.value == Brightness.dark;

Color get _ombre1 => _darkMode ? const Color(0xFF191513) : const Color(0xFFFFFBF7);
Color get _ombre2 => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFF8F3);
Color get _ombre3 => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF3EF);
Color get _ombre4 => _darkMode ? const Color(0xFF312821) : const Color(0xFFFEEDE9);
Color get _pawClr => _darkMode ? const Color(0xFF231D18) : const Color(0xFFF8BCD0);
Color get _outline => _darkMode ? const Color(0xFFAD7F58) : const Color(0xFF6E5848);
Color get _brown => _darkMode ? const Color(0xFFF2E1CA) : const Color(0xFF4E3828);
Color get _brownLt => _darkMode ? const Color(0xFFDBB594) : const Color(0xFF7A5840);
Color get _brownSoft => _darkMode ? const Color(0xFFBD926C) : const Color(0xFF9A8070);
Color get _cardFill => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF8F4);
Color get _panelBg => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFF6EE);
Color get _cream => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFDEFDB);
Color get _olive => const Color(0xFF98A869);
Color get _oliveDk => const Color(0xFF58772F);
Color get _pinkLt => _darkMode ? const Color(0xFF411C35) : const Color(0xFFFFD5F5);
Color get _pink => const Color(0xFFFEA9D3);
Color get _pinkDk => const Color(0xFFE890B8);
Color get _coral => const Color(0xFFF7AEAE);
Color get _gold => const Color(0xFFE4BC83);
Color get _orange => const Color(0xFFFFBC5C);
Color get _red => const Color(0xFFEF6262);
Color get _blueLt => _darkMode ? const Color(0xFF102A4C) : const Color(0xFFDDF6FF);
Color get _green => const Color(0xFFA8D5A3);
Color get _greenLt => _darkMode ? const Color(0xFF143125) : const Color(0xFFC2E8BC);
Color get _greenDk => const Color(0xFF88B883);
Color get _goldGlow => const Color(0xFFF8E080);
Color get _purpleHdr => const Color(0xFFCDA8D8);
// Soft sage tint — used as the cash-pill background so the
// sage dollar-bill sticker reads as part of the pill instead
// of clashing with a warm gold/tan fill.
Color get _cashTint => _darkMode ? const Color(0xFF29331B) : const Color(0xFFDCE8C9);
Color get _skyHdr => const Color(0xFF9DD4F0);
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
    // Kick off a notifications fetch on first paint. This also makes the
    // backend materialise any day-before reminders for events coming up
    // in the next 24h — and, when the user has daily_reminders_enabled,
    // sends the corresponding email.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationsProvider.notifier).refresh();
    });
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
                Text('LEVEL UP!', style: GoogleFonts.gaegu(
                  fontSize: 32, fontWeight: FontWeight.w900,
                  color: _brown, letterSpacing: 2)),
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
                    child: Text('Awesome!', style: GoogleFonts.gaegu(
                      fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
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
    if (currentTab == 0 && _prevTab != 0) {
      Future.microtask(() => ref.read(dashboardProvider.notifier).refresh());
    }
    _prevTab = currentTab;

    final dash = ref.watch(dashboardProvider);
    _syncExpression(dash);

    // Level-up celebration
    if (dash.pendingLevelUp != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLevelUpCelebration(dash.pendingLevelUp!);
        ref.read(dashboardProvider.notifier).clearLevelUp();
      });
    }

    // Lazy load resources
    if (!_recsLoaded) _loadRecommendations();

    return Stack(children: [
      // Ombré background
      Positioned.fill(child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_ombre1, _ombre2, _ombre3, _ombre4],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
      )),
      Positioned.fill(child: CustomPaint(painter: _PawPrintBg())),

      // Content
      SafeArea(
        child: RefreshIndicator(
          color: _outline,
          backgroundColor: _cardFill,
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 800;
              final sidePad = isWide ? 80.0 : 24.0;
              // Navbar height + breathing room
              const navH = 80.0;
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(sidePad, 28, sidePad, 0),
                        child: _stagger(0.0, _buildTopBar(dash)),
                      ),

                      // This gets pushed DOWN by spaceBetween
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Avatar + speech
                          _stagger(0.04, _buildAvatarSection(dash, constraints.maxWidth - sidePad * 2)),

                          // XP divider
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: sidePad),
                            child: _stagger(0.08, _buildXpDivider(dash)),
                          ),
                          const SizedBox(height: 10),

                          // Content (streak, stats, quests, insight)
                          Padding(
                            padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, navH),
                            child: Column(
                              children: [
                                if (isWide)
                                  _stagger(0.14, _buildTwoColumnContent(dash))
                                else ...[
                                  _stagger(0.14, _buildWeeklyStreak(dash)),
                                  const SizedBox(height: 16),
                                  _stagger(0.18, _buildStatsCard(dash)),
                                  const SizedBox(height: 16),
                                  _stagger(0.22, _buildQuestsCard(dash)),
                                  const SizedBox(height: 16),
                                  _stagger(0.26, _buildInsightTip(dash)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }

  //  TOP BAR — greeting left, pills right
  Widget _buildTopBar(DashboardState dash) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()}, ${dash.displayName}!',
                style: TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 28,
                  color: _brown,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _getCerebroSays(dash),
                style: GoogleFonts.gaegu(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _brownLt,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Pills
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pill(icon: Icons.calendar_today_rounded, label: _formatDate(), color: _pinkLt),
            const SizedBox(width: 7),
            _Pill(icon: Icons.star_rounded, label: 'Lv. ${dash.level}', color: _gold),
            const SizedBox(width: 7),
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
            const SizedBox(width: 7),
            _Pill(iconWidget: const _CashBill(size: 18), label: '${dash.cash}', color: _cashTint),
            const SizedBox(width: 7),
            _Pill(icon: Icons.local_fire_department_rounded, label: '${dash.streak}', color: _orange),
            const SizedBox(width: 7),
            // Live-wired bell — count reflects real unread notifications.
            // Tapping opens a tray; pull-to-refresh inside the tray (and
            // the dashboard open itself) re-fetches the list.
            GestureDetector(
              onTap: () => _openNotificationTray(),
              child: _NotifBell(count: ref.watch(
                notificationsProvider.select((s) => s.unreadCount))),
            ),
          ],
        ),
      ],
    );
  }

  void _openNotificationTray() {
    // Refresh once on open so the tray shows the freshest state without
    // waiting for the full dashboard to reload.
    ref.read(notificationsProvider.notifier).refresh();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationTraySheet(),
    );
  }

  //  AVATAR + SPEECH BUBBLE (compact, no fixed height)
  Widget _buildAvatarSection(DashboardState dash, double contentW) {
    // The avatar clothes layer overflows the widget box downward by ~100px at
    // scale 0.45. The fix is to raise the CENTER of the avatar high enough
    // that even the clothes clear above the XP bar (which starts at sectionH).
    // With top=-100, bottom=20, sectionH=165 (large screen):
    //   Positioned height = 165+100-20 = 245px
    //   Avatar layout center in SizedBox = -100 + 245/2 = 22.5px
    //   Clothes visual offset from center ≈ 103px → clothes at ~125px
    //   SizedBox bottom = 165px → 40px clearance ✅
    final isSmall  = contentW < 400;
    final isMedium = contentW < 700;

    final double avatarScale = isSmall ? 0.35 : (isMedium ? 0.40 : 0.45);
    final double avatarSize  = isSmall ? 260.0 : (isMedium ? 280.0 : 310.0);
    final double sectionH    = isSmall ? 130.0 : (isMedium ? 150.0 : 165.0);
    // Raise by increasing magnitude of top. bottom=20 keeps some pull from below.
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
          // Avatar — Center alignment keeps the avatar's visual center at
          // (avatarTop + Positioned_height / 2) in SizedBox coordinates.
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
          ),  // end avatar
          // Speech bubble — to the right of the avatar head
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
        color: _darkMode ? const Color(0xFF3E1A1A) : const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline, width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face_rounded, size: 36, color: CerebroTheme.pinkPop),
          const SizedBox(height: 4),
          Text('Create avatar!', textAlign: TextAlign.center,
              style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble() {
    // Warm cream in light, warm mid-brown paper in dark (still distinct from
    // page bg but no longer glows white against a pitch background).
    final bubbleFill = _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFFBF8);
    return CustomPaint(
      painter: _CozyBubblePainter(
        fillColor: bubbleFill,
        borderColor: _outline,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 16, 14),
        child: Text(
          _speechText,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.gaegu(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _brown,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  //  XP DIVIDER BAR
  Widget _buildXpDivider(DashboardState dash) {
    final xpPerLevel = 500; // matches provider
    final currentXp = dash.totalXp;
    final levelXp = dash.level * xpPerLevel;
    final prevLevelXp = (dash.level - 1) * xpPerLevel;
    final progress = levelXp > prevLevelXp
        ? ((currentXp - prevLevelXp) / (levelXp - prevLevelXp)).clamp(0.0, 1.0)
        : 0.0;

    // HTML: .xp-div-track { flex: 0 0 22% } — centered row with fixed-width track
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Lv. ${dash.level}',
            style: TextStyle(fontFamily: 'Bitroad', fontSize: 12, color: _brownLt)),
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
                    gradient: LinearGradient(colors: [_olive, _oliveDk]),
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
          // Left column (40%)
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
          // Right column (60%)
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
    final todayIdx = DateTime.now().weekday - 1; // 0=Mon
    // Streak logic: streak days ending on today (inclusive)
    // If any habit is done today, today counts as done
    final streakDays = dash.streak.clamp(0, 7);
    final todayHasProgress = dash.habitsDone > 0;

    // Effective display streak: at least 1 if any habit done today
    final displayStreak = todayHasProgress
        ? math.max(streakDays, 1)
        : streakDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: _oliveDk),
            const SizedBox(width: 7),
            Text('Weekly Streak',
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
              child: Text('${displayStreak} days',
                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 13),
        // Day circles
        Row(
          children: List.generate(7, (i) {
            final isToday = i == todayIdx;
            // A day is "done" if it falls within the streak window
            // Streak window: from (todayIdx - displayStreak + 1) to todayIdx
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

  //  TODAY'S SNAPSHOT — 2×3 stat grid (matching HTML)
  Widget _buildStatsCard(DashboardState dash) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.show_chart_rounded, size: 16, color: _oliveDk),
            const SizedBox(width: 7),
            Text("Today's Snapshot",
              style: TextStyle(fontFamily: 'Bitroad', fontSize: 15, color: _brown)),
          ],
        ),
        const SizedBox(height: 13),
        // 2×3 grid
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

  //  TODAY'S QUESTS — card with progress ring + quest rows
  Widget _buildQuestsCard(DashboardState dash) {
    final habits = dash.habits;
    final habitsDone = dash.habitsDone;
    final progress = habits.isEmpty ? 0.0 : habitsDone / habits.length;
    final remaining = habits.length - habitsDone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.description_rounded, size: 16, color: _oliveDk),
            const SizedBox(width: 7),
            Text("Today's Quests",
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
        // Quest card
        Container(
          decoration: BoxDecoration(
            color: _cardFill.withOpacity(0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.5),
            child: Column(
              children: [
                // Progress header
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Row(
                    children: [
                      // Progress ring
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
                            style: TextStyle(
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
                // Quest rows
                ...List.generate(habits.length, (i) => _questRow(i)),
                // Completion banner
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
                        style: GoogleFonts.gaegu(fontSize: 17, fontWeight: FontWeight.w700, color: _brown)),
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
          // Checkbox
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
          // Name
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
          // XP badge
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
              style: TextStyle(fontFamily: 'Bitroad', fontSize: 11, color: _brown)),
          ),
        ]),
      ),
    );
  }

  //  DAILY INSIGHT TIP
  //  Tapping (or tapping "See more") opens the full cross-
  //  domain Insights screen.
  Widget _buildInsightTip(DashboardState dash) {
    final insight = _getInsight(dash);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(Routes.insights),
      child: Container(
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
                color: _cardFill,
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
                  Row(children: [
                    Text('DAILY INSIGHT',
                      style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 0.7, color: _pinkDk)),
                    const Spacer(),
                    Text('See more →',
                      style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 0.3, color: _pinkDk)),
                  ]),
                  const SizedBox(height: 3),
                  Text(insight,
                    style: GoogleFonts.gaegu(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: _brown, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
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

//  PILL — compact status badge (matching HTML .pill)
class _Pill extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;        // overrides `icon` when provided
  final String label;
  final Color color;
  const _Pill({this.icon, this.iconWidget, required this.label, required this.color})
      : assert(icon != null || iconWidget != null,
               'Provide either icon or iconWidget');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.28),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        iconWidget ?? Icon(icon, size: 14, color: _outline),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.gaegu(
          fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
      ]),
    );
  }
}

//  CASH BILL STICKER — tilted sage dollar-bill, matches store
class _CashBill extends StatelessWidget {
  final double size;
  final Color fill;
  final Color border;
  final Color glyphColor;
  const _CashBill({
    this.size = 16,
    this.fill      = const Color(0xFF98A869),  // palette sage
    this.border    = const Color(0xFF58772F),  // palette olive-dk
    this.glyphColor = const Color(0xFFF9FDEC), // palette cream-yellow
  });

  @override
  Widget build(BuildContext context) {
    final double w = size;
    final double h = size * 0.66;
    return Transform.rotate(
      angle: -0.15,
      child: Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(size * 0.15),
          border: Border.all(color: border, width: size * 0.09),
        ),
        child: Center(child: Text('\$',
          style: GoogleFonts.gaegu(
            fontSize: size * 0.58, fontWeight: FontWeight.w700,
            color: glyphColor, height: 1))),
      ),
    );
  }
}

//  NOTIFICATION BELL (matching HTML .notif)
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

//  STAT TILE — mini card in 2×3 grid (matching HTML .sc)
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
    // In dark mode, a stark white icon well looks disconnected on a tinted
    // pastel tile; fall back to BROWN-2 so it reads as a recessed notch.
    final iconBg = isHighlight
        ? Colors.white.withOpacity(0.2)
        : (_darkMode ? const Color(0xFF231D18) : Colors.white);
    final iconBorder = isHighlight
        ? Colors.white.withOpacity(0.25)
        : _outline.withOpacity(_darkMode ? 0.3 : 0.1);

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

//  PROGRESS RING PAINTER (for quest progress)
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

    // Background circle
    canvas.drawCircle(center, radius,
      Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth);

    // Foreground arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start from top
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

//  COZY SPEECH BUBBLE (preserved)
class _CozyBubblePainter extends CustomPainter {
  static const _radius = 18.0;
  static const _border = 2.0;
  static const _tailW = 12.0;
  static const _tailH = 18.0;

  final Color fillColor;
  final Color borderColor;
  _CozyBubblePainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h), Radius.circular(_radius));

    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 5, w, h), Radius.circular(_radius));
    canvas.drawRRect(shadowRect, Paint()..color = borderColor.withOpacity(0.12));

    canvas.drawRRect(boxRect, Paint()..color = fillColor);

    final tailCY = h / 2;
    final tailTip = Offset(-_tailW, tailCY);
    final tailTop = Offset(0, tailCY - _tailH / 2);
    final tailBot = Offset(0, tailCY + _tailH / 2);

    final tailOuter = Path()..moveTo(tailTip.dx, tailTip.dy)
      ..lineTo(tailTop.dx, tailTop.dy)..lineTo(tailBot.dx, tailBot.dy)..close();
    canvas.drawPath(tailOuter, Paint()..color = borderColor);

    final tailInner = Path()..moveTo(tailTip.dx + 6, tailTip.dy)
      ..lineTo(tailTop.dx, tailTop.dy + 5)..lineTo(tailBot.dx, tailBot.dy - 5)..close();
    canvas.drawPath(tailInner, Paint()..color = fillColor);

    canvas.drawRRect(boxRect, Paint()
      ..color = borderColor..style = PaintingStyle.stroke..strokeWidth = _border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//  MOOD POPUP (preserved exactly)
class _MoodPopup extends StatelessWidget {
  final AvatarConfig config;
  final String? selected;
  final ValueChanged<String> onPick;
  const _MoodPopup({required this.config, required this.selected, required this.onPick});

  // Mood meta (labels + keys) — colors are resolved at build-time below
  // so we can swap in dark-mode tints without losing the const list.
  static const _moodKeys = [
    {'key': 'happy',   'label': 'Happy'},
    {'key': 'sad',     'label': 'Sad'},
    {'key': 'anxious', 'label': 'Anxious'},
    {'key': 'calm',    'label': 'Calm'},
    {'key': 'excited', 'label': 'Excited'},
    {'key': 'tired',   'label': 'Tired'},
    {'key': 'angry',   'label': 'Angry'},
    {'key': 'focused', 'label': 'Focused'},
  ];

  /// Mood tile fill — mode-aware. Light = airy pastel, dark = muted CRUMBS
  /// shade-4 of the same hue (so "happy" still reads gold, not slate).
  Color _moodTint(String key) {
    if (_darkMode) {
      switch (key) {
        case 'happy':   return const Color(0xFF3E2F15); // AMBER 4
        case 'sad':     return const Color(0xFF102A4C); // BLUE 4
        case 'anxious': return const Color(0xFF3A1F28); // PINK/WINE 4
        case 'calm':    return const Color(0xFF14331F); // GREEN 4
        case 'excited': return const Color(0xFF402A15); // ORANGE 4
        case 'tired':   return const Color(0xFF2E1F45); // PURPLE 4
        case 'angry':   return const Color(0xFF3E1A1A); // RED 4
        case 'focused': return const Color(0xFF143125); // SAGE 4
      }
      return const Color(0xFF29221D);
    }
    switch (key) {
      case 'happy':   return const Color(0xFFFFF9E0);
      case 'sad':     return const Color(0xFFE8F0FF);
      case 'anxious': return const Color(0xFFFFE8EC);
      case 'calm':    return const Color(0xFFE8FFF0);
      case 'excited': return const Color(0xFFFFF0E0);
      case 'tired':   return const Color(0xFFEDE5FF);
      case 'angry':   return const Color(0xFFFFE0E0);
      case 'focused': return const Color(0xFFF0FFF0);
    }
    return const Color(0xFFFFFBF8);
  }

  @override
  Widget build(BuildContext context) {
    // Modal surfaces — BROWN 2/3 in dark, near-white cream in light.
    final modalBg   = _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFFBF8);
    final bodyBg    = _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFFBF8);
    // Header gradient — muted rose in dark mode, original peach in light.
    final hdrColors = _darkMode
        ? const [Color(0xFF5C2E2E), Color(0xFF4A2222)]
        : const [Color(0xFFF0C0B8), Color(0xFFE8A8A0)];
    final selFill   = _darkMode ? const Color(0xFF4A2433) : const Color(0xFFFFE0E8);
    final selBorder = _darkMode ? const Color(0xFFE88FA0) : const Color(0xFFE8A8A0);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 540,
          decoration: BoxDecoration(
            color: modalBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _outline.withOpacity(_darkMode ? 0.5 : 0.2), width: 2),
            boxShadow: [
              BoxShadow(color: _outline.withOpacity(_darkMode ? 0.25 : 0.08),
                  offset: const Offset(0, 8), blurRadius: 32),
              BoxShadow(color: Colors.black.withOpacity(_darkMode ? 0.4 : 0.06),
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: hdrColors),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('How are you feeling?', style: GoogleFonts.gaegu(
                          fontSize: 24, fontWeight: FontWeight.w700,
                          color: _darkMode ? const Color(0xFFF2E1CA) : _brown)),
                      Positioned(
                        right: 16,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: _darkMode ? Colors.black.withOpacity(0.35) : _cardFill.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close_rounded, size: 16,
                                color: _darkMode ? const Color(0xFFF2E1CA) : _brown.withOpacity(0.6)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: bodyBg,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: _moodKeys.map((m) {
                      final key = m['key'] as String;
                      final label = m['label'] as String;
                      final tileColor = _moodTint(key);
                      final isSel = selected == key;
                      return GestureDetector(
                        onTap: () => onPick(key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSel ? selFill : tileColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel ? selBorder : _outline.withOpacity(_darkMode ? 0.35 : 0.15),
                              width: isSel ? 2.5 : 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(child: MoodSticker(config: config, mood: key, size: 100)),
                              Text(label, style: GoogleFonts.gaegu(
                                  fontSize: 14, fontWeight: FontWeight.w700,
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

//  PAWPRINT BACKGROUND (preserved)
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


//  NOTIFICATION TRAY SHEET
//  Bottom sheet surfaced when the user taps the bell.
//  - Lists recent notifications newest-first
//  - Tap a row to jump to its deep-link (events → calendar)
//  - "Mark all read" clears the red dot in one go
//  - Swipe individual rows left to dismiss
class _NotificationTraySheet extends ConsumerWidget {
  const _NotificationTraySheet();

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'event_reminder': return Icons.alarm_rounded;
      case 'event_created':  return Icons.event_available_rounded;
      case 'ai_schedule':    return Icons.auto_awesome_rounded;
      default:               return Icons.notifications_rounded;
    }
  }

  Color _tintFor(String kind) {
    switch (kind) {
      case 'event_reminder': return _orange;
      case 'event_created':  return _greenLt;
      case 'ai_schedule':    return _pinkLt;
      default:               return _coral;
    }
  }

  String _relativeTime(DateTime then) {
    final diff = DateTime.now().difference(then);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${then.month}/${then.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final notif = ref.read(notificationsProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: _outline, width: 2),
          ),
          child: Column(
            children: [
              // Grab handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: _outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                child: Row(children: [
                  Icon(Icons.notifications_rounded, color: _outline, size: 22),
                  const SizedBox(width: 8),
                  Text('Notifications', style: GoogleFonts.gaegu(
                    fontSize: 22, fontWeight: FontWeight.w900, color: _brown)),
                  const Spacer(),
                  if (state.unreadCount > 0)
                    TextButton(
                      onPressed: () => notif.markAllRead(),
                      child: Text('Mark all read', style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _outline)),
                    ),
                ]),
              ),
              Divider(color: _outline.withOpacity(0.2), height: 1),
              // Body
              Expanded(
                child: state.loading && state.items.isEmpty
                    ? Center(child: CircularProgressIndicator(color: _coral))
                    : state.items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.notifications_none_rounded,
                                    size: 56, color: _outline.withOpacity(0.35)),
                                const SizedBox(height: 12),
                                Text("You're all caught up!",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.gaegu(
                                    fontSize: 18, fontWeight: FontWeight.w700,
                                    color: _brown)),
                                const SizedBox(height: 4),
                                Text('New events and reminders will show up here.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: _brownSoft)),
                              ]),
                            ),
                          )
                        : RefreshIndicator(
                            color: _coral,
                            onRefresh: () => notif.refresh(),
                            child: ListView.separated(
                              controller: scroll,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              itemCount: state.items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final n = state.items[i];
                                return Dismissible(
                                  key: ValueKey(n.id),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) => notif.dismiss(n.id),
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: _red.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.delete_rounded, color: Colors.white),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () async {
                                      if (!n.read) await notif.markRead(n.id);
                                      if (!ctx.mounted) return;
                                      // event_id deep-link → jump to calendar
                                      if (n.eventId != null) {
                                        Navigator.pop(ctx);
                                        context.push('/study/calendar');
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: n.read
                                            ? _cardFill
                                            : _cream.withOpacity(0.75),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: _outline.withOpacity(n.read ? 0.18 : 0.35),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 36, height: 36,
                                            decoration: BoxDecoration(
                                              color: _tintFor(n.kind),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: _outline.withOpacity(0.25), width: 1.5),
                                            ),
                                            child: Icon(_iconFor(n.kind),
                                              size: 18, color: _outline),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(children: [
                                                  Expanded(
                                                    child: Text(n.title,
                                                      style: GoogleFonts.gaegu(
                                                        fontSize: 15,
                                                        fontWeight: n.read
                                                            ? FontWeight.w700
                                                            : FontWeight.w900,
                                                        color: _brown)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(_relativeTime(n.createdAt),
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: _brownSoft)),
                                                ]),
                                                const SizedBox(height: 2),
                                                Text(n.body,
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 12, height: 1.4,
                                                    fontWeight: FontWeight.w600,
                                                    color: _brownSoft)),
                                              ]),
                                          ),
                                          if (!n.read)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8, top: 6),
                                              width: 8, height: 8,
                                              decoration: BoxDecoration(
                                                color: _red, shape: BoxShape.circle),
                                            ),
                                        ]),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
