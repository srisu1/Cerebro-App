// Daily tab — quests, morning/evening routines, daily score.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';


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
Color get _cream => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFDEFDB);
Color get _olive => const Color(0xFF98A869);
Color get _oliveDk => const Color(0xFF58772F);
Color get _coral => const Color(0xFFF7AEAE);
Color get _orange => const Color(0xFFFFBC5C);
Color get _red => const Color(0xFFEF6262);
Color get _gold => const Color(0xFFE4BC83);
Color get _lavender => const Color(0xFFDDBDE8);
Color get _goldGlow => const Color(0xFFF8E080);
// Quest icon preset mapping (mirrors dashboardProvider's habitIconMap keys).
const Map<String, IconData> _questIcons = {
  'water':        Icons.water_drop_rounded,
  'book':         Icons.menu_book_rounded,
  'fitness':      Icons.fitness_center_rounded,
  'edit':         Icons.edit_rounded,
  'self_improve': Icons.self_improvement_rounded,
  'no_food':      Icons.no_food_rounded,
  'walk':         Icons.directions_walk_rounded,
  'phone_off':    Icons.phone_disabled_rounded,
  'school':       Icons.school_rounded,
  'night':        Icons.nights_stay_rounded,
  'check':        Icons.check_rounded,
};

IconData _iconFor(String key) => _questIcons[key] ?? Icons.check_rounded;

class DailyTab extends ConsumerStatefulWidget {
  const DailyTab({Key? key}) : super(key: key);
  @override
  ConsumerState<DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends ConsumerState<DailyTab>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late SharedPreferences _prefs;
  bool _loaded = false;

  // Routines — items are editable; done state is per-day.
  List<String> _morningItems = [];
  List<bool>   _morningDone  = [];
  List<String> _eveningItems = [];
  List<bool>   _eveningDone  = [];

  static const _defaultMorning = <String>[
    'Wake up on time',
    'Hydrate',
    'Stretch / move',
    'Plan your day',
  ];
  static const _defaultEvening = <String>[
    'Review your day',
    'Prep tomorrow',
    'Screens off by 10',
    'Wind down',
  ];

  //  LIFECYCLE
  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  //  PERSISTENCE
  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    final today = _todayKey();

    // Morning items (persist across days). ALL lists must be growable
    // because _addMorningItem / _addEveningItem call .add() on them.
    final mItemsJson = _prefs.getString('daily_morning_items');
    _morningItems = mItemsJson != null
        ? List<String>.from(jsonDecode(mItemsJson) as List, growable: true)
        : List<String>.from(_defaultMorning, growable: true);

    // Morning done (per-day).
    final mDoneJson = _prefs.getString('daily_morning_done_$today');
    _morningDone = mDoneJson != null
        ? List<bool>.from(jsonDecode(mDoneJson) as List, growable: true)
        : List<bool>.filled(_morningItems.length, false, growable: true);
    // Guard against length mismatch after edits:
    if (_morningDone.length != _morningItems.length) {
      _morningDone =
          List<bool>.filled(_morningItems.length, false, growable: true);
    }

    // Evening items + done.
    final eItemsJson = _prefs.getString('daily_evening_items');
    _eveningItems = eItemsJson != null
        ? List<String>.from(jsonDecode(eItemsJson) as List, growable: true)
        : List<String>.from(_defaultEvening, growable: true);
    final eDoneJson = _prefs.getString('daily_evening_done_$today');
    _eveningDone = eDoneJson != null
        ? List<bool>.from(jsonDecode(eDoneJson) as List, growable: true)
        : List<bool>.filled(_eveningItems.length, false, growable: true);
    if (_eveningDone.length != _eveningItems.length) {
      _eveningDone =
          List<bool>.filled(_eveningItems.length, false, growable: true);
    }

    if (!mounted) return;
    setState(() => _loaded = true);
    _enterCtrl.forward();
  }

  Future<void> _saveMorning() async {
    await _prefs.setString('daily_morning_items', jsonEncode(_morningItems));
    await _prefs.setString(
        'daily_morning_done_${_todayKey()}', jsonEncode(_morningDone));
  }

  Future<void> _saveEvening() async {
    await _prefs.setString('daily_evening_items', jsonEncode(_eveningItems));
    await _prefs.setString(
        'daily_evening_done_${_todayKey()}', jsonEncode(_eveningDone));
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _formatDate() {
    final n = DateTime.now();
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[n.weekday - 1]}, ${months[n.month - 1]} ${n.day}';
  }

  //  SCORE — based on real completions
  int _calcScore(DashboardState dash) {
    // Quests (up to 40 pts) — proportional to % complete.
    final q = dash.habits;
    final qDone = q.where((h) => h['done'] == true).length;
    final qScore = q.isEmpty ? 0 : ((qDone / q.length) * 40).round();

    // Morning (up to 30).
    final mDone = _morningDone.where((d) => d).length;
    final mScore = _morningItems.isEmpty
        ? 0
        : ((mDone / _morningItems.length) * 30).round();

    // Evening (up to 30).
    final eDone = _eveningDone.where((d) => d).length;
    final eScore = _eveningItems.isEmpty
        ? 0
        : ((eDone / _eveningItems.length) * 30).round();

    return (qScore + mScore + eScore).clamp(0, 100);
  }

  Color _scoreColor(int s) {
    if (s < 30) return _red;
    if (s < 70) return _gold;
    return _olive;
  }

  String _motivationalLine(int score) {
    if (score == 0)   return 'Fresh slate — pick one thing to begin.';
    if (score < 30)   return 'Good start. One more win builds momentum.';
    if (score < 70)   return 'You are finding your rhythm today.';
    if (score < 100)  return 'You are crushing it — keep going!';
    return 'Perfect day. You are unstoppable.';
  }

  //  ACTIONS
  // Smaller XP value for routine steps (vs. full quests at 10).
  static const int _xpPerRoutineStep = 5;

  void _toggleMorning(int i) {
    final wasDone = _morningDone[i];
    setState(() => _morningDone[i] = !wasDone);
    _saveMorning();
    // Award XP on completion transition (not on un-check).
    if (!wasDone) {
      ref.read(dashboardProvider.notifier).awardXp(_xpPerRoutineStep);
    }
  }

  void _toggleEvening(int i) {
    final wasDone = _eveningDone[i];
    setState(() => _eveningDone[i] = !wasDone);
    _saveEvening();
    if (!wasDone) {
      ref.read(dashboardProvider.notifier).awardXp(_xpPerRoutineStep);
    }
  }

  void _addMorningItem(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() {
      _morningItems.add(t);
      _morningDone.add(false);
    });
    _saveMorning();
  }

  void _editMorningItem(int i, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() => _morningItems[i] = t);
    _saveMorning();
  }

  void _deleteMorningItem(int i) {
    setState(() {
      _morningItems.removeAt(i);
      _morningDone.removeAt(i);
    });
    _saveMorning();
  }

  void _addEveningItem(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() {
      _eveningItems.add(t);
      _eveningDone.add(false);
    });
    _saveEvening();
  }

  void _editEveningItem(int i, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() => _eveningItems[i] = t);
    _saveEvening();
  }

  void _deleteEveningItem(int i) {
    setState(() {
      _eveningItems.removeAt(i);
      _eveningDone.removeAt(i);
    });
    _saveEvening();
  }

  // Quest actions delegate to dashboardProvider so home stays in sync.
  void _toggleQuest(int i) {
    ref.read(dashboardProvider.notifier).toggleHabit(i);
  }

  Future<void> _addQuest() async {
    final result = await _showQuestSheet(
      title: 'New Quest',
      initialName: '',
      initialIcon: 'check',
      primaryLabel: 'Add',
    );
    if (result == null) return;
    final name = result['name'] as String;
    final icon = result['icon'] as String;
    await ref.read(dashboardProvider.notifier).addQuest(name, icon: icon);
  }

  Future<void> _editQuest(int i) async {
    final dash = ref.read(dashboardProvider);
    if (i < 0 || i >= dash.habits.length) return;
    final h = dash.habits[i];
    final result = await _showQuestSheet(
      title: 'Edit Quest',
      initialName: h['name'] as String? ?? '',
      initialIcon: h['icon'] as String? ?? 'check',
      primaryLabel: 'Save',
    );
    if (result == null) return;
    await ref.read(dashboardProvider.notifier).updateQuest(
          i,
          name: result['name'] as String,
          icon: result['icon'] as String,
        );
  }

  Future<void> _deleteQuest(int i) async {
    final dash = ref.read(dashboardProvider);
    if (i < 0 || i >= dash.habits.length) return;
    final h = dash.habits[i];
    final confirm = await _showConfirmDialog(
      title: 'Delete quest?',
      body: '"${h['name']}" will be removed from your daily list.',
      dangerLabel: 'Delete',
    );
    if (confirm == true) {
      await ref.read(dashboardProvider.notifier).deleteQuest(i);
    }
  }

  //  STAGGER-IN HELPER
  Widget _stag(double delay, Widget child) => AnimatedBuilder(
        animation: _enterCtrl,
        builder: (_, __) {
          final t = Curves.easeOutCubic.transform(
              ((_enterCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
          return Opacity(
            opacity: t,
            child: Transform.translate(
                offset: Offset(0, 18 * (1 - t)), child: child),
          );
        },
      );

  //  BUILD
  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: _ombre1,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dash = ref.watch(dashboardProvider);
    final score = _calcScore(dash);
    final scoreColor = _scoreColor(score);

    return Stack(children: [
      // Ombré background
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_ombre1, _ombre2, _ombre3, _ombre4],
              stops: [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
      ),
      // Paw-print backdrop
      Positioned.fill(child: CustomPaint(painter: _PawPrintBg())),
      // Top glow
      Positioned(
        top: -120, left: 0, right: 0,
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.0,
              colors: [_goldGlow.withOpacity(0.12), Colors.transparent],
            ),
          ),
        ),
      ),

      // Content
      SafeArea(
        child: RefreshIndicator(
          color: _outline,
          backgroundColor: _cardFill,
          onRefresh: () async {
            await ref.read(dashboardProvider.notifier).refresh();
            await _loadData();
          },
          child: LayoutBuilder(
            builder: (ctx, c) {
              final isWide = c.maxWidth > 720;
              final sidePad = isWide ? 80.0 : 24.0;
              const navH = 90.0;
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(sidePad, 20, sidePad, navH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero — back arrow + My Day + date + motivation + score ring
                    _stag(0.02, _buildHero(score, scoreColor)),
                    const SizedBox(height: 24),

                    // My Quests
                    _stag(
                      0.06,
                      _sectionTitle(
                        Icons.auto_awesome_rounded,
                        'My Quests',
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          _countBadge(
                            '${dash.habits.where((h) => h['done'] == true).length}/${dash.habits.length}',
                          ),
                          const SizedBox(width: 6),
                          _iconBtn(Icons.add_rounded, _oliveDk,
                              onTap: _addQuest,
                              size: 26,
                              iconSize: 14),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _stag(0.06, _buildQuestsCard(dash)),
                    const SizedBox(height: 22),

                    // Morning / Evening
                    if (isWide)
                      _stag(0.10, _buildRoutinesRow())
                    else
                      _stag(0.10, _buildRoutinesColumn()),
                    const SizedBox(height: 22),

                    // Score breakdown
                    _stag(
                      0.16,
                      _sectionTitle(
                        Icons.leaderboard_rounded,
                        'Daily Score',
                        trailing: _countBadge(
                          '$score/100',
                          color: scoreColor,
                          textColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _stag(0.16, _buildScoreCard(dash)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }

  //  HERO — back arrow + My Day + date + motivation + score ring
  //  (single row; back button parallels the score ring)
  Widget _buildHero(int score, Color scoreColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back arrow (returns to Home tab)
        GestureDetector(
          onTap: () => ref.read(selectedTabProvider.notifier).state = 0,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: _outline.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _outline.withOpacity(0.28),
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Icon(Icons.chevron_left_rounded,
                size: 20, color: _outline),
          ),
        ),
        const SizedBox(width: 12),
        // My Day + date + motivation
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Day',
                style: TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 28,
                  color: _brown,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(),
                style: GoogleFonts.gaegu(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _brownLt,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _motivationalLine(score),
                style: GoogleFonts.gaegu(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _brownSoft,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Score ring — parallel to back arrow on the right
        _ScoreRing(score: score, color: scoreColor, size: 92),
      ],
    );
  }

  //  SECTION HELPERS
  Widget _sectionTitle(IconData icon, String title, {Widget? trailing}) {
    return Row(children: [
      Icon(icon, size: 17, color: _oliveDk),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontFamily: 'Bitroad',
          fontSize: 16,
          color: _brown,
          height: 1.1,
        ),
      ),
      const Spacer(),
      if (trailing != null) trailing,
    ]);
  }

  Widget _countBadge(String text, {Color? color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? _cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.18),
            offset: const Offset(1, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor ?? _brown,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    // Warmer cream tint + lower opacity so the ombre + paw-print bg
    // shows through and the page does not feel "white".
    return Container(
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.2),
            offset: const Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.5),
        child: child,
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    Color color, {
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    double size = 30,
    double iconSize = 16,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _outline.withOpacity(0.22),
              offset: const Offset(1, 1),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }

  //  QUESTS CARD — synced with dashboardProvider
  Widget _buildQuestsCard(DashboardState dash) {
    final quests = dash.habits;
    final allDone = quests.isNotEmpty &&
        quests.every((h) => h['done'] == true);

    return _card(
      child: Column(children: [
        if (quests.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Column(children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 28, color: _brownSoft),
              const SizedBox(height: 6),
              Text(
                'No quests yet. Tap + to add one.',
                style: GoogleFonts.gaegu(
                  fontSize: 14,
                  color: _brownSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),

        for (int i = 0; i < quests.length; i++)
          _QuestRow(
            key: ValueKey('quest_$i'),
            quest: quests[i],
            isLast: i == quests.length - 1,
            onToggle: () => _toggleQuest(i),
            onEdit:   () => _editQuest(i),
            onDelete: () => _deleteQuest(i),
          ),

        // All-done banner
        if (allDone)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_goldGlow.withOpacity(0.45),
                         _goldGlow.withOpacity(0.2)],
              ),
            ),
            child: Center(
              child: Text(
                'All quests cleared today!',
                style: GoogleFonts.gaegu(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _brown,
                ),
              ),
            ),
          ),
      ]),
    );
  }

  //  ROUTINES (editable)
  Widget _buildRoutinesRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildRoutineBlock(
          icon: Icons.wb_twilight_rounded,
          title: 'Morning',
          badgeColor: _orange.withOpacity(0.55),
          badgeTextColor: Colors.white,
          items: _morningItems,
          done: _morningDone,
          onToggle: _toggleMorning,
          onAdd: () => _showRoutineTextSheet(
            title: 'New Morning Step',
            primaryLabel: 'Add',
            onSubmit: _addMorningItem,
          ),
          onEdit: (i) => _showRoutineTextSheet(
            title: 'Edit Morning Step',
            initial: _morningItems[i],
            primaryLabel: 'Save',
            onSubmit: (t) => _editMorningItem(i, t),
          ),
          onDelete: _deleteMorningItem,
        )),
        const SizedBox(width: 14),
        Expanded(child: _buildRoutineBlock(
          icon: Icons.nightlight_round,
          title: 'Evening',
          badgeColor: _lavender,
          items: _eveningItems,
          done: _eveningDone,
          onToggle: _toggleEvening,
          onAdd: () => _showRoutineTextSheet(
            title: 'New Evening Step',
            primaryLabel: 'Add',
            onSubmit: _addEveningItem,
          ),
          onEdit: (i) => _showRoutineTextSheet(
            title: 'Edit Evening Step',
            initial: _eveningItems[i],
            primaryLabel: 'Save',
            onSubmit: (t) => _editEveningItem(i, t),
          ),
          onDelete: _deleteEveningItem,
        )),
      ],
    );
  }

  Widget _buildRoutinesColumn() {
    return Column(children: [
      _buildRoutineBlock(
        icon: Icons.wb_twilight_rounded,
        title: 'Morning',
        badgeColor: _orange.withOpacity(0.55),
        badgeTextColor: Colors.white,
        items: _morningItems,
        done: _morningDone,
        onToggle: _toggleMorning,
        onAdd: () => _showRoutineTextSheet(
          title: 'New Morning Step',
          primaryLabel: 'Add',
          onSubmit: _addMorningItem,
        ),
        onEdit: (i) => _showRoutineTextSheet(
          title: 'Edit Morning Step',
          initial: _morningItems[i],
          primaryLabel: 'Save',
          onSubmit: (t) => _editMorningItem(i, t),
        ),
        onDelete: _deleteMorningItem,
      ),
      const SizedBox(height: 22),
      _buildRoutineBlock(
        icon: Icons.nightlight_round,
        title: 'Evening',
        badgeColor: _lavender,
        items: _eveningItems,
        done: _eveningDone,
        onToggle: _toggleEvening,
        onAdd: () => _showRoutineTextSheet(
          title: 'New Evening Step',
          primaryLabel: 'Add',
          onSubmit: _addEveningItem,
        ),
        onEdit: (i) => _showRoutineTextSheet(
          title: 'Edit Evening Step',
          initial: _eveningItems[i],
          primaryLabel: 'Save',
          onSubmit: (t) => _editEveningItem(i, t),
        ),
        onDelete: _deleteEveningItem,
      ),
    ]);
  }

  Widget _buildRoutineBlock({
    required IconData icon,
    required String title,
    required Color badgeColor,
    Color? badgeTextColor,
    required List<String> items,
    required List<bool> done,
    required void Function(int) onToggle,
    required VoidCallback onAdd,
    required void Function(int) onEdit,
    required void Function(int) onDelete,
  }) {
    final doneCount = done.where((d) => d).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          icon,
          title,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _countBadge(
              '$doneCount/${items.length}',
              color: badgeColor,
              textColor: badgeTextColor,
            ),
            const SizedBox(width: 6),
            _iconBtn(Icons.add_rounded, _oliveDk,
                onTap: onAdd, size: 26, iconSize: 14),
          ]),
        ),
        const SizedBox(height: 10),
        _card(
          child: Column(children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No steps yet. Tap + to add one.',
                  style: GoogleFonts.gaegu(
                    fontSize: 13,
                    color: _brownSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            for (int i = 0; i < items.length; i++)
              _RoutineRow(
                key: ValueKey('${title}_$i'),
                text: items[i],
                done: done[i],
                isLast: i == items.length - 1,
                onToggle: () => onToggle(i),
                onEdit:   () => onEdit(i),
                onDelete: () => onDelete(i),
              ),
          ]),
        ),
      ],
    );
  }

  //  SCORE BREAKDOWN
  Widget _buildScoreCard(DashboardState dash) {
    final q = dash.habits;
    final qDone = q.where((h) => h['done'] == true).length;
    final qPts = q.isEmpty ? 0 : ((qDone / q.length) * 40).round();

    final mDone = _morningDone.where((d) => d).length;
    final mPts = _morningItems.isEmpty
        ? 0
        : ((mDone / _morningItems.length) * 30).round();

    final eDone = _eveningDone.where((d) => d).length;
    final ePts = _eveningItems.isEmpty
        ? 0
        : ((eDone / _eveningItems.length) * 30).round();

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          _scoreRow(Icons.auto_awesome_rounded, 'Quests',  qPts, 40, _coral),
          const SizedBox(height: 10),
          _scoreRow(Icons.wb_twilight_rounded,  'Morning', mPts, 30, _orange),
          const SizedBox(height: 10),
          _scoreRow(Icons.nightlight_round,     'Evening', ePts, 30, _lavender),
        ]),
      ),
    );
  }

  Widget _scoreRow(
      IconData icon, String label, int val, int max, Color color) {
    final pct = max == 0 ? 0.0 : (val / max).clamp(0.0, 1.0);
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _outline.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _outline.withOpacity(0.2),
              offset: const Offset(1, 1),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: _brown),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _brown,
                  ),
                ),
              ),
              Text(
                '$val / $max',
                style: TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 12,
                  color: _brown,
                ),
              ),
            ]),
            const SizedBox(height: 5),
            Container(
              height: 7,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: _outline.withOpacity(0.15), width: 0.8),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: _outline.withOpacity(0.3),
                        offset: const Offset(0, 1),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  //  DIALOGS — quest editor + routine text sheet + confirm
  Future<Map<String, String>?> _showQuestSheet({
    required String title,
    required String initialName,
    required String initialIcon,
    required String primaryLabel,
  }) {
    return showGeneralDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'quest',
      barrierColor: Colors.black.withOpacity(0.22),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, child) {
        final curve =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 4 * anim.value, sigmaY: 4 * anim.value),
          child: Opacity(
            opacity: anim.value,
            child: Transform.scale(
              scale: 0.9 + 0.1 * curve.value,
              child: _QuestEditorDialog(
                title: title,
                initialName: initialName,
                initialIcon: initialIcon,
                primaryLabel: primaryLabel,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRoutineTextSheet({
    required String title,
    String initial = '',
    required String primaryLabel,
    required void Function(String) onSubmit,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'routine',
      barrierColor: Colors.black.withOpacity(0.22),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, child) {
        final curve =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 4 * anim.value, sigmaY: 4 * anim.value),
          child: Opacity(
            opacity: anim.value,
            child: Transform.scale(
              scale: 0.9 + 0.1 * curve.value,
              child: _RoutineTextDialog(
                title: title,
                controller: ctrl,
                primaryLabel: primaryLabel,
                onSubmit: (t) {
                  onSubmit(t);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String dangerLabel,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'confirm',
      barrierColor: Colors.black.withOpacity(0.22),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 3 * anim.value, sigmaY: 3 * anim.value),
          child: Opacity(
            opacity: anim.value,
            child: Transform.scale(
              scale: 0.92 + 0.08 * anim.value,
              child: Material(
                type: MaterialType.transparency,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      color: _cardFill,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _outline, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _outline.withOpacity(0.35),
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Bitroad',
                              fontSize: 20,
                              color: _brown,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _brownLt,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.of(ctx).pop(false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _cream,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _outline.withOpacity(0.3),
                                        width: 1.2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _brown,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.of(ctx).pop(true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _red,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _outline.withOpacity(0.45),
                                        width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _outline.withOpacity(0.25),
                                        offset: const Offset(1, 1),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      dangerLabel,
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

//  QUEST ROW (separate widget so ValueKey works cleanly)
class _QuestRow extends StatelessWidget {
  final Map<String, dynamic> quest;
  final bool isLast;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _QuestRow({
    super.key,
    required this.quest,
    required this.isLast,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = quest['done'] == true;
    final name = quest['name'] as String? ?? '';
    final iconKey = quest['icon'] as String? ?? 'check';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: !isLast
              ? Border(
                  bottom: BorderSide(color: _outline.withOpacity(0.06)))
              : null,
        ),
        child: Row(children: [
          _MiniCheckbox(done: done),
          const SizedBox(width: 10),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: done
                  ? _olive.withOpacity(0.25)
                  : _cream.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: _outline.withOpacity(0.2), width: 1),
            ),
            child: Icon(_iconFor(iconKey),
                size: 15, color: done ? _oliveDk : _brownLt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: done ? _olive : _brown,
                decoration:
                    done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.edit_rounded, size: 15, color: _brownSoft),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 16, color: _brownSoft),
            ),
          ),
        ]),
      ),
    );
  }
}

//  ROUTINE ROW (editable list item)
class _RoutineRow extends StatelessWidget {
  final String text;
  final bool done;
  final bool isLast;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RoutineRow({
    super.key,
    required this.text,
    required this.done,
    required this.isLast,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          border: !isLast
              ? Border(
                  bottom: BorderSide(color: _outline.withOpacity(0.06)))
              : null,
        ),
        child: Row(children: [
          _MiniCheckbox(done: done),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: done ? _olive : _brown,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.edit_rounded, size: 14, color: _brownSoft),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close_rounded, size: 15, color: _brownSoft),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MiniCheckbox extends StatelessWidget {
  final bool done;
  const _MiniCheckbox({required this.done});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: done ? _olive : _cream,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: done ? _oliveDk : _outline.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (done ? _oliveDk : _outline).withOpacity(0.2),
            offset: const Offset(1, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

//  QUEST EDITOR DIALOG — name field + icon grid
class _QuestEditorDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final String initialIcon;
  final String primaryLabel;
  const _QuestEditorDialog({
    required this.title,
    required this.initialName,
    required this.initialIcon,
    required this.primaryLabel,
  });

  @override
  State<_QuestEditorDialog> createState() => _QuestEditorDialogState();
}

class _QuestEditorDialogState extends State<_QuestEditorDialog> {
  late TextEditingController _ctrl;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
    _iconKey = widget.initialIcon;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop({'name': name, 'icon': _iconKey});
  }

  @override
  Widget build(BuildContext context) {
    final iconKeys = _questIcons.keys.toList();
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 28,
            right: 28,
            top: 28,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _outline, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _outline.withOpacity(0.4),
                  offset: const Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 22, color: _oliveDk),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: 'Bitroad',
                      fontSize: 20,
                      color: _brown,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded,
                        size: 20, color: _brownSoft),
                  ),
                ]),
                const SizedBox(height: 14),

                // Name input
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cream.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _outline.withOpacity(0.3), width: 1.2),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Quest name',
                      hintStyle: GoogleFonts.nunito(
                          fontSize: 14, color: _brownSoft),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _brown,
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ICON',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _brownSoft,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: iconKeys.map((k) {
                    final active = k == _iconKey;
                    return GestureDetector(
                      onTap: () => setState(() => _iconKey = k),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: active
                              ? _olive.withOpacity(0.85)
                              : _cream,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? _oliveDk
                                : _outline.withOpacity(0.25),
                            width: active ? 2 : 1.2,
                          ),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: _oliveDk.withOpacity(0.35),
                                    offset: const Offset(1, 2),
                                    blurRadius: 0,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          _questIcons[k],
                          size: 18,
                          color: active ? Colors.white : _brown,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _cream,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: _outline.withOpacity(0.3),
                              width: 1.2),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _brown,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _submit,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _olive,
                          borderRadius: BorderRadius.circular(11),
                          border:
                              Border.all(color: _oliveDk, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _oliveDk.withOpacity(0.35),
                              offset: const Offset(1, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.primaryLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//  ROUTINE TEXT DIALOG — simple name editor
class _RoutineTextDialog extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String primaryLabel;
  final void Function(String) onSubmit;
  const _RoutineTextDialog({
    required this.title,
    required this.controller,
    required this.primaryLabel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 28,
            right: 28,
            top: 28,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _outline, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _outline.withOpacity(0.4),
                  offset: const Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(Icons.edit_rounded, size: 20, color: _oliveDk),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Bitroad',
                      fontSize: 19,
                      color: _brown,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded,
                        size: 20, color: _brownSoft),
                  ),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cream.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _outline.withOpacity(0.3), width: 1.2),
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    onSubmitted: (v) => onSubmit(v),
                    decoration: InputDecoration(
                      hintText: 'Step name',
                      hintStyle: GoogleFonts.nunito(
                          fontSize: 14, color: _brownSoft),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _brown,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _cream,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: _outline.withOpacity(0.3),
                              width: 1.2),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _brown,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onSubmit(controller.text),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _olive,
                          borderRadius: BorderRadius.circular(11),
                          border:
                              Border.all(color: _oliveDk, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _oliveDk.withOpacity(0.35),
                              offset: const Offset(1, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            primaryLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//  SCORE RING (sticker-stamp circle with ring arc + number)
class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  final double size;
  const _ScoreRing({
    required this.score,
    required this.color,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          decoration: BoxDecoration(
            color: _cardFill,
            shape: BoxShape.circle,
            border: Border.all(color: _outline, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: _outline.withOpacity(0.35),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: CustomPaint(
            painter: _RingPainter(
              progress: (score / 100).clamp(0.0, 1.0),
              bgColor: color.withOpacity(0.18),
              fgColor: color,
              strokeWidth: 7,
            ),
            size: Size(size - 16, size - 16),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '$score',
            style: TextStyle(
              fontFamily: 'Bitroad',
              fontSize: 28,
              color: _brown,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'SCORE',
            style: GoogleFonts.nunito(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: _brownSoft,
              letterSpacing: 1.2,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color bgColor, fgColor;
  final double strokeWidth;
  _RingPainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final bg = Paint()
      ..color = bgColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    if (progress <= 0) return;
    final fg = Paint()
      ..color = fgColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.fgColor != fgColor ||
      old.bgColor != bgColor;
}

//  PAW-PRINT BACKDROP
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _pawClr.withOpacity(0.12);
    const r = 5.0;
    for (double y = -10; y < size.height + 40; y += 90) {
      for (double x = -10; x < size.width + 40; x += 90) {
        final ox = (y ~/ 90).isOdd ? 45.0 : 0.0;
        _drawPaw(canvas, Offset(x + ox, y), r, paint);
      }
    }
  }

  void _drawPaw(Canvas c, Offset o, double r, Paint p) {
    c.drawCircle(o + Offset(0, r * 1.2), r * 1.1, p);
    c.drawCircle(o + Offset(-r * 1.1, -r * 0.5), r * 0.7, p);
    c.drawCircle(o + Offset(r * 1.1, -r * 0.5), r * 0.7, p);
    c.drawCircle(o + Offset(-r * 0.3, -r * 1.5), r * 0.6, p);
    c.drawCircle(o + Offset(r * 0.3, -r * 1.5), r * 0.6, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
