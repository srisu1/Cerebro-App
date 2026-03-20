import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';

// COLORS
const _ombre1 = Color(0xFFFFFBF7);
const _ombre2 = Color(0xFFFFF8F3);
const _ombre3 = Color(0xFFFFF3EF);
const _ombre4 = Color(0xFFFEEDE9);
const _pawClr = Color(0xFFF8BCD0);

const _outline = Color(0xFF6E5848);
const _brown = Color(0xFF4E3828);
const _brownLt = Color(0xFF7A5840);

const _cardFill = Color(0xFFFFF8F4);
const _panelBg = Color(0xFFFFF6EE);
const _goldGlow = Color(0xFFF8E080);

const _coralHdr = Color(0xFFF0A898);
const _coralLt = Color(0xFFF8C0B0);
const _pinkHdr = Color(0xFFE8B0A8);
const _pinkLt = Color(0xFFF0C0B8);
const _greenHdr = Color(0xFFA8D5A3);
const _greenLt = Color(0xFFC2E8BC);
const _greenDk = Color(0xFF88B883);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _purpleDk = Color(0xFFAA88C0);
const _skyHdr = Color(0xFF9DD4F0);
const _skyLt = Color(0xFF98D4F0);
const _skyDk = Color(0xFF6BB8E0);
const _sageHdr = Color(0xFF90C8A0);
const _sageLt = Color(0xFFB0D8B8);
const _sageDk = Color(0xFF70A880);
const _goldHdr = Color(0xFFF0D878);
const _goldDk = Color(0xFFD4B850);

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

  // Goals
  List<Map<String, dynamic>> _goals = [];
  bool _addingGoal = false;
  TextEditingController _goalCtrl = TextEditingController();

  // Routines
  List<bool> _morningDone = [false, false, false, false];
  List<bool> _eveningDone = [false, false, false, false];

  // Activity tracking
  String? _activeCategory;
  DateTime? _activityStart;
  Timer? _activityTimer;
  List<Map<String, dynamic>> _activityLog = [];
  Duration _activeDuration = Duration.zero;

  final _categories = [
    {
      'key': 'study',
      'label': 'Study',
      'icon': Icons.menu_book_rounded,
      'color': const Color(0xFF9DD4F0)
    },
    {
      'key': 'exercise',
      'label': 'Exercise',
      'icon': Icons.fitness_center_rounded,
      'color': const Color(0xFFA8D5A3)
    },
    {
      'key': 'social',
      'label': 'Social',
      'icon': Icons.people_rounded,
      'color': const Color(0xFFE8B0A8)
    },
    {
      'key': 'rest',
      'label': 'Rest',
      'icon': Icons.hotel_rounded,
      'color': const Color(0xFFCDA8D8)
    },
    {
      'key': 'creative',
      'label': 'Creative',
      'icon': Icons.brush_rounded,
      'color': const Color(0xFFF0A898)
    },
    {
      'key': 'errands',
      'label': 'Errands',
      'icon': Icons.shopping_bag_rounded,
      'color': const Color(0xFFF0D878)
    },
  ];

  @override
  void initState() {
    super.initState();
    _enterCtrl =
        AnimationController(duration: const Duration(milliseconds: 900), vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _activityTimer?.cancel();
    _goalCtrl.dispose();
    _questAddCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    final today = _getTodayKey();

    // Load goals
    final goalsJson = _prefs.getString('daily_goals_$today');
    if (goalsJson != null) {
      _goals = List<Map<String, dynamic>>.from(jsonDecode(goalsJson));
    } else {
      _goals = [];
    }

    // Load morning routine
    final morningJson = _prefs.getString('daily_morning_$today');
    if (morningJson != null) {
      _morningDone = List<bool>.from(jsonDecode(morningJson));
    } else {
      _morningDone = [false, false, false, false];
    }

    // Load evening routine
    final eveningJson = _prefs.getString('daily_evening_$today');
    if (eveningJson != null) {
      _eveningDone = List<bool>.from(jsonDecode(eveningJson));
    } else {
      _eveningDone = [false, false, false, false];
    }

    // Load activity log
    final activityJson = _prefs.getString('activity_log_$today');
    if (activityJson != null) {
      _activityLog = List<Map<String, dynamic>>.from(jsonDecode(activityJson));
    } else {
      _activityLog = [];
    }

    setState(() => _loaded = true);
    _enterCtrl.forward();
  }

  Future<void> _saveGoals() async {
    _prefs.setString('daily_goals_${_getTodayKey()}', jsonEncode(_goals));
  }

  Future<void> _saveMorning() async {
    _prefs.setString('daily_morning_${_getTodayKey()}', jsonEncode(_morningDone));
  }

  Future<void> _saveEvening() async {
    _prefs.setString('daily_evening_${_getTodayKey()}', jsonEncode(_eveningDone));
  }

  Future<void> _saveActivityLog() async {
    _prefs.setString('activity_log_${_getTodayKey()}', jsonEncode(_activityLog));
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _calcScore() {
    int score = 0;
    // Goals: 10 pts each (max 30)
    score += _goals.where((g) => g['done'] == true).length * 10;
    // Morning routine: 5 pts each (max 20)
    score += _morningDone.where((d) => d).length * 5;
    // Evening routine: 5 pts each (max 20)
    score += _eveningDone.where((d) => d).length * 5;
    // Activity tracking: 10 pts per 30 min logged (max 30)
    int totalMinutes = _activityLog.fold(0, (sum, e) => sum + (e['minutes'] as int? ?? 0));
    score += (totalMinutes ~/ 30 * 10).clamp(0, 30);
    return score.clamp(0, 100);
  }

  Color _scoreColor(int score) {
    if (score < 30) return Colors.red.shade400;
    if (score < 70) return const Color(0xFFF0D878);
    return _greenHdr;
  }

  void _toggleGoal(int idx) {
    setState(() => _goals[idx]['done'] = !_goals[idx]['done']);
    _saveGoals();
  }

  void _deleteGoal(int idx) {
    setState(() => _goals.removeAt(idx));
    _saveGoals();
  }

  void _addGoal() {
    if (_goals.length >= 3) return;
    setState(() => _addingGoal = true);
  }

  void _submitGoal() {
    if (_goalCtrl.text.trim().isEmpty) return;
    setState(() {
      _goals.add({'text': _goalCtrl.text.trim(), 'done': false});
      _goalCtrl.clear();
      _addingGoal = false;
    });
    _saveGoals();
  }

  void _cancelGoal() {
    setState(() {
      _addingGoal = false;
      _goalCtrl.clear();
    });
  }

  void _toggleMorning(int idx) {
    setState(() => _morningDone[idx] = !_morningDone[idx]);
    _saveMorning();
  }

  void _toggleEvening(int idx) {
    setState(() => _eveningDone[idx] = !_eveningDone[idx]);
    _saveEvening();
  }

  void _toggleActivity(String key) {
    if (_activeCategory == key) {
      // Stop tracking
      _stopActivity();
    } else {
      // Switch or start
      if (_activeCategory != null) {
        _stopActivity();
      }
      setState(() {
        _activeCategory = key;
        _activityStart = DateTime.now();
        _activeDuration = Duration.zero;
      });
      _activityTimer?.cancel();
      _activityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_activityStart != null) {
          setState(() {
            _activeDuration = DateTime.now().difference(_activityStart!);
          });
        }
      });
    }
  }

  void _stopActivity() {
    if (_activeCategory != null && _activityStart != null) {
      final minutes = _activeDuration.inMinutes;
      if (minutes > 0) {
        setState(() {
          _activityLog.add({'category': _activeCategory, 'minutes': minutes});
          _activeCategory = null;
          _activityStart = null;
          _activeDuration = Duration.zero;
        });
        _saveActivityLog();
      } else {
        setState(() {
          _activeCategory = null;
          _activityStart = null;
          _activeDuration = Duration.zero;
        });
      }
    }
    _activityTimer?.cancel();
  }

  int _getTotalMinutes(String category) {
    return _activityLog
        .where((e) => e['category'] == category)
        .fold(0, (sum, e) => sum + (e['minutes'] as int? ?? 0));
  }

  Widget _stag(double delay, Widget child) {
    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(
            ((_enterCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: _ombre1,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final score = _calcScore();
    final scoreColor = _scoreColor(score);

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_ombre1, _ombre2, _ombre3, _ombre4],
                stops: [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _PawPrintBg())),
        Positioned(
          top: -120,
          left: 0,
          right: 0,
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
        SafeArea(
          child: RefreshIndicator(
            color: _outline,
            backgroundColor: _cardFill,
            onRefresh: () async => _loadData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(34, 14, 34, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER: "My Day" + Score Ring
                  _stag(
                    0.0,
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Day',
                            style: GoogleFonts.gaegu(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _brown,
                            ),
                          ),
                          _buildScoreRing(score, scoreColor),
                        ],
                      ),
                    ),
                  ),

                  // TODAY'S GOALS (HERO CARD)
                  _stag(
                    0.05,
                    _buildGoalsCard(),
                  ),
                  const SizedBox(height: 20),

                  // MORNING & EVENING ROUTINES
                  _stag(
                    0.1,
                    Row(
                      children: [
                        Expanded(
                            child: _buildRoutineCard(
                                'Morning', _morningDone, _greenHdr, _toggleMorning)),
                        const SizedBox(width: 14),
                        Expanded(
                            child: _buildRoutineCard(
                                'Evening', _eveningDone, _purpleHdr, _toggleEvening)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ACTIVITY TRACKER
                  _stag(
                    0.15,
                    _buildActivityTracker(),
                  ),
                  const SizedBox(height: 20),

                  // MANAGE DAILY QUESTS
                  _stag(
                    0.2,
                    _buildQuestManager(),
                  ),
                  const SizedBox(height: 20),

                  // QUICK ACTIONS
                  _stag(
                    0.25,
                    _buildQuickActions(),
                  ),
                  const SizedBox(height: 20),

                  // DAILY SCORE BREAKDOWN
                  _stag(
                    0.25,
                    _buildScoreBreakdown(score),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreRing(int score, Color color) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100.0,
            strokeWidth: 3.5,
            valueColor: AlwaysStoppedAnimation(color),
            backgroundColor: color.withOpacity(0.2),
          ),
          Text(
            '$score',
            style: GoogleFonts.gaegu(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _brown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsCard() {
    final complete = _goals.where((g) => g['done'] == true).length;
    final allDone = _goals.isNotEmpty && complete == _goals.length;

    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_coralHdr, _coralLt],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.adjust_rounded, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Today\'s Goals',
                      style: GoogleFonts.gaegu(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$complete/${_goals.length.clamp(0, 3)}',
                    style: GoogleFonts.gaegu(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Goals list
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                ..._goals.asMap().entries.map((e) {
                  final idx = e.key;
                  final goal = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleGoal(idx),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              border: Border.all(color: _coralHdr, width: 2),
                              borderRadius: BorderRadius.circular(6),
                              color:
                                  goal['done'] == true ? _coralHdr : Colors.transparent,
                            ),
                            child: goal['done'] == true
                                ? const Icon(Icons.check_rounded,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            goal['text'],
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _brown,
                              decoration: goal['done'] == true
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteGoal(idx),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: _brownLt),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                if (_addingGoal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const SizedBox(width: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _goalCtrl,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'What do you want to achieve?',
                              hintStyle: GoogleFonts.gaegu(
                                fontSize: 14,
                                color: _brownLt,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 0),
                            ),
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: _brown,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _submitGoal,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _greenHdr,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _cancelGoal,
                          child: Icon(Icons.close_rounded,
                              size: 18, color: _brownLt),
                        ),
                      ],
                    ),
                  ),
                if (_goals.length < 3 && !_addingGoal)
                  GestureDetector(
                    onTap: _addGoal,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 18, color: _coralHdr),
                          const SizedBox(width: 6),
                          Text(
                            'Add Goal',
                            style: GoogleFonts.gaegu(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _coralHdr,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Completion banner
          if (allDone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_goldHdr, _goldDk],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Text(
                'All goals crushed! +50 XP',
                textAlign: TextAlign.center,
                style: GoogleFonts.gaegu(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(String title, List<bool> items, Color headerColor,
      Function(int) onTap) {
    final itemsList = title == 'Morning'
        ? ['Wake up on time', 'Hydrate', 'Stretch / Move', 'Plan your day']
        : ['Review what you did', 'Prepare tomorrow', 'Screen off by 10pm', 'Wind down'];
    final done = items.where((d) => d).length;

    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [headerColor, headerColor.withOpacity(0.8)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.gaegu(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$done/${items.length}',
                  style: GoogleFonts.gaegu(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: itemsList.asMap().entries.map((e) {
                final idx = e.key;
                final label = e.value;
                return GestureDetector(
                  onTap: () => onTap(idx),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            border: Border.all(color: headerColor, width: 1.5),
                            borderRadius: BorderRadius.circular(4),
                            color: items[idx] ? headerColor : Colors.transparent,
                          ),
                          child: items[idx]
                              ? Icon(Icons.check_rounded,
                                  size: 13, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _brown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTracker() {
    final categoryData = {
      'study': _getTotalMinutes('study'),
      'exercise': _getTotalMinutes('exercise'),
      'social': _getTotalMinutes('social'),
      'rest': _getTotalMinutes('rest'),
      'creative': _getTotalMinutes('creative'),
      'errands': _getTotalMinutes('errands'),
    };
    final totalMinutes = categoryData.values.fold(0, (a, b) => a + b);

    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline_rounded, size: 20, color: _skyHdr),
              const SizedBox(width: 8),
              Text(
                'Right Now',
                style: GoogleFonts.gaegu(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _brown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_activeCategory != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _skyHdr.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Active: ${_activeCategory!.capitalize()} — ${_formatDuration(_activeDuration)}',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _skyDk,
                ),
              ),
            )
          else
            Text(
              'Tap a category to start tracking',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: _brownLt,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final isActive = _activeCategory == cat['key'];
              final color = cat['color'] as Color;
              return GestureDetector(
                onTap: () => _toggleActivity(cat['key'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? Colors.white : color.withOpacity(0.5),
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat['icon'] as IconData,
                          size: 18, color: Colors.white),
                      const SizedBox(height: 2),
                      Text(
                        cat['label'] as String,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (totalMinutes > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Today\'s distribution:',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: _brownLt,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: categoryData.entries.map((e) {
                    final mins = e.value;
                    final pct = mins / totalMinutes;
                    final catColor = _categories
                        .firstWhere((c) => c['key'] == e.key)['color'] as Color;
                    return Expanded(
                      flex: (pct * 100).toInt().clamp(1, 100),
                      child: Container(
                        color: catColor,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // QUEST MANAGER — add / edit / delete daily quests
  final _questAddCtrl = TextEditingController();

  Widget _buildQuestManager() {
    final dash = ref.watch(dashboardProvider);
    final habits = dash.habits;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4EC), Color(0xFFFFFAF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [_coralLt, _coralHdr],
              ),
            ),
            child: Row(children: [
              const Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text('Manage Quests', style: GoogleFonts.gaegu(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
              const Spacer(),
              Text('${habits.length} quests', style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9))),
            ]),
          ),

          // Quest list
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Column(children: [
              for (int i = 0; i < habits.length; i++) ...[
                if (i > 0) Divider(height: 1, color: _outline.withOpacity(0.08)),
                _questManagerRow(i, habits[i]),
              ],
            ]),
          ),

          // Add new quest row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _outline.withOpacity(0.3), width: 2),
                  ),
                  child: TextField(
                    controller: _questAddCtrl,
                    style: GoogleFonts.nunito(fontSize: 14, color: _brown),
                    decoration: InputDecoration(
                      hintText: 'Add new quest...',
                      hintStyle: GoogleFonts.nunito(fontSize: 14,
                          color: _brownLt.withOpacity(0.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) => _addNewQuest(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addNewQuest,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_greenLt, _greenHdr],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _outline, width: 2.5),
                    boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
                        offset: const Offset(0, 2), blurRadius: 0)],
                  ),
                  child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _questManagerRow(int index, Map<String, dynamic> habit) {
    final iconMap = {
      'water': Icons.water_drop_rounded,
      'book': Icons.menu_book_rounded,
      'fitness': Icons.fitness_center_rounded,
      'self_improve': Icons.self_improvement_rounded,
      'no_food': Icons.no_food_rounded,
      'walk': Icons.directions_walk_rounded,
      'phone_off': Icons.phone_disabled_rounded,
      'school': Icons.school_rounded,
      'night': Icons.nights_stay_rounded,
      'check': Icons.check_rounded,
      'edit': Icons.edit_rounded,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        // Icon
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF5EDE5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            iconMap[habit['icon']] ?? Icons.flag_rounded,
            size: 16, color: _brownLt,
          ),
        ),
        const SizedBox(width: 10),
        // Quest name
        Expanded(
          child: Text(habit['name'] ?? '', style: GoogleFonts.nunito(
              fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
        ),
        // Edit button
        GestureDetector(
          onTap: () => _showEditQuestDialog(index, habit),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.edit_rounded, size: 18,
                color: _brownLt.withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 4),
        // Delete button
        GestureDetector(
          onTap: () => _confirmDeleteQuest(index, habit['name'] ?? ''),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 18,
                color: Colors.red.shade300),
          ),
        ),
      ]),
    );
  }

  void _addNewQuest() {
    final text = _questAddCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(dashboardProvider.notifier).addQuest(text);
    _questAddCtrl.clear();
  }

  void _showEditQuestDialog(int index, Map<String, dynamic> habit) {
    final editCtrl = TextEditingController(text: habit['name'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _outline, width: 2.5),
        ),
        title: Text('Edit Quest', style: GoogleFonts.gaegu(
            fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          style: GoogleFonts.nunito(fontSize: 16, color: _brown),
          decoration: InputDecoration(
            hintText: 'Quest name',
            hintStyle: GoogleFonts.nunito(color: _brownLt.withOpacity(0.5)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _outline.withOpacity(0.3))),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _outline)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700, color: _brownLt)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = editCtrl.text.trim();
              if (newName.isNotEmpty) {
                ref.read(dashboardProvider.notifier).updateQuest(index, name: newName);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _greenHdr,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Save', style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteQuest(int index, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _outline, width: 2.5),
        ),
        title: Text('Delete Quest?', style: GoogleFonts.gaegu(
            fontSize: 24, fontWeight: FontWeight.w700, color: _brown)),
        content: Text('Remove "$name" from your daily quests?',
            style: GoogleFonts.nunito(fontSize: 15, color: _brownLt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep', style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700, color: _brownLt)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(dashboardProvider.notifier).deleteQuest(index);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Delete', style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _GameBtn(
            icon: Icons.adjust_rounded,
            label: 'Add Goal',
            gradientTop: _coralHdr,
            gradientBot: _coralLt,
            borderColor: _coralHdr,
            onTap: _addGoal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GameBtn(
            icon: Icons.checklist_rounded,
            label: 'Start Routine',
            gradientTop: _greenHdr,
            gradientBot: _greenLt,
            borderColor: _greenHdr,
            onTap: () {
              // Highlight next unchecked morning step
              for (int i = 0; i < _morningDone.length; i++) {
                if (!_morningDone[i]) {
                  _toggleMorning(i);
                  break;
                }
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GameBtn(
            icon: Icons.play_circle_outlined,
            label: 'Log Activity',
            gradientTop: _skyHdr,
            gradientBot: _skyLt,
            borderColor: _skyHdr,
            onTap: () {
              // Scroll to activity tracker
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBreakdown(int score) {
    final goalPts = _goals.where((g) => g['done'] == true).length * 10;
    final morningPts = _morningDone.where((d) => d).length * 5;
    final eveningPts = _eveningDone.where((d) => d).length * 5;
    int totalMinutes = _activityLog.fold(0, (sum, e) => sum + (e['minutes'] as int? ?? 0));
    final activityPts = (totalMinutes ~/ 30 * 10).clamp(0, 30);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ScorePill('Goals', goalPts, 30, _coralHdr),
        _ScorePill('Morning', morningPts, 20, _greenHdr),
        _ScorePill('Evening', eveningPts, 20, _purpleHdr),
        _ScorePill('Activity', activityPts, 30, _skyHdr),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;

  const _ScorePill(this.label, this.value, this.max, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _outline.withOpacity(0.2), width: 1),
      ),
      child: Text(
        '$label: $value/$max',
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GameBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color gradientTop, gradientBot, borderColor;
  final VoidCallback onTap;

  const _GameBtn({
    required this.icon,
    required this.label,
    required this.gradientTop,
    required this.gradientBot,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_GameBtn> createState() => _GameBtnState();
}

class _GameBtnState extends State<_GameBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [widget.gradientTop, widget.gradientBot],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.borderColor.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: widget.borderColor.withOpacity(0.35),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 20, color: Colors.white),
            const SizedBox(height: 3),
            Text(
              widget.label,
              style: GoogleFonts.gaegu(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

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

extension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
