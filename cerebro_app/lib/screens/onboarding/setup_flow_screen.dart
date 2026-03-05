/// CEREBRO - Comprehensive Post-Registration Setup Flow (Toca Boca Aesthetic)
/// 7-step onboarding: University, Year, Subjects, Goals, Sleep, Habits, Mood.
/// Collects all info needed for the full app to work from day one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';
import 'dart:convert';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';

class SetupFlowScreen extends ConsumerStatefulWidget {
  const SetupFlowScreen({super.key});

  @override
  ConsumerState<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends ConsumerState<SetupFlowScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 7;
  bool _isSubmitting = false;

  final _universityController = TextEditingController();
  final _courseController = TextEditingController();

  int _yearOfStudy = 1;

  final List<_SubjectEntry> _subjects = [];
  final _subjectNameController = TextEditingController();
  String _selectedSubjectColor = '#FF6B9D';

  final Set<String> _selectedGoals = {};
  double _dailyStudyHours = 2.0;

  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 30);

  final Set<String> _selectedHabits = {};

  int _selectedMood = -1; // index into mood list

  late AnimationController _fadeAC;
  late Animation<double> _fadeAnim;
  late AnimationController _iconBounceAC;

  static const _subjectColors = [
    '#FF6B9D', '#7DD3FC', '#7BC9A0', '#FFB5C5',
    '#FFCA4E', '#B8A9E8', '#FF8C7A', '#5FB085',
    '#5BC0EB', '#E85A8A', '#9D8AD4', '#E5B345',
  ];

  static final _studyGoals = [
    _GoalItem('Improve GPA', Icons.trending_up_rounded, CerebroTheme.pinkPop),
    _GoalItem('Stay Organized', Icons.calendar_today_rounded, CerebroTheme.sky),
    _GoalItem('Better Sleep', Icons.bedtime_rounded, CerebroTheme.lavender),
    _GoalItem('Build Habits', Icons.repeat_rounded, CerebroTheme.sage),
    _GoalItem('Reduce Stress', Icons.spa_rounded, CerebroTheme.gold),
    _GoalItem('Exam Prep', Icons.quiz_rounded, CerebroTheme.coral),
    _GoalItem('Time Management', Icons.schedule_rounded, CerebroTheme.skyDark),
    _GoalItem('Stay Motivated', Icons.local_fire_department_rounded, CerebroTheme.coralDark),
  ];

  static final _habitPresets = [
    _HabitItem('Drink Water', Icons.water_drop_rounded, CerebroTheme.sky, '#7DD3FC'),
    _HabitItem('Exercise', Icons.fitness_center_rounded, CerebroTheme.coral, '#FF8C7A'),
    _HabitItem('Read', Icons.auto_stories_rounded, CerebroTheme.lavender, '#B8A9E8'),
    _HabitItem('Meditate', Icons.self_improvement_rounded, CerebroTheme.sage, '#7BC9A0'),
    _HabitItem('No Junk Food', Icons.no_food_rounded, CerebroTheme.pinkPop, '#FF6B9D'),
    _HabitItem('Walk 10k Steps', Icons.directions_walk_rounded, CerebroTheme.sageDark, '#5FB085'),
    _HabitItem('No Social Media', Icons.phone_disabled_rounded, CerebroTheme.coralDark, '#E67A6A'),
    _HabitItem('Study 2+ Hours', Icons.school_rounded, CerebroTheme.skyDark, '#5BC0EB'),
    _HabitItem('Sleep Before 12', Icons.nights_stay_rounded, CerebroTheme.lavenderDark, '#9D8AD4'),
  ];

  static final _moods = [
    _MoodItem('Happy', '😊', CerebroTheme.gold),
    _MoodItem('Excited', '🤩', CerebroTheme.pinkPop),
    _MoodItem('Calm', '😌', CerebroTheme.sage),
    _MoodItem('Focused', '🧐', CerebroTheme.sky),
    _MoodItem('Tired', '😴', CerebroTheme.lavender),
    _MoodItem('Stressed', '😰', CerebroTheme.coral),
    _MoodItem('Sad', '😔', CerebroTheme.skyDark),
    _MoodItem('Anxious', '😟', CerebroTheme.coralDark),
  ];

  static final _stepConfigs = [
    _StepConfig(Icons.school_rounded, "Let's get to\nknow you!", 'Tell us about your studies.', CerebroTheme.pinkPop),
    _StepConfig(Icons.emoji_events_rounded, 'What year are\nyou in?', 'Select your current year of study.', CerebroTheme.sky),
    _StepConfig(Icons.book_rounded, 'Add your\nsubjects', 'What are you studying right now?', CerebroTheme.sage),
    _StepConfig(Icons.flag_rounded, 'Set your\ngoals', 'What do you want to achieve?', CerebroTheme.gold),
    _StepConfig(Icons.bedtime_rounded, 'Your sleep\nschedule', 'When do you usually sleep?', CerebroTheme.lavender),
    _StepConfig(Icons.repeat_rounded, 'Pick some\nhabits', 'Build healthy routines.', CerebroTheme.coral),
    _StepConfig(Icons.mood_rounded, 'How are you\nfeeling?', "Let's start with a mood check!", CerebroTheme.pinkPop),
  ];

  @override
  void initState() {
    super.initState();
    _fadeAC = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAC, curve: Curves.easeOut),
    );
    _fadeAC.forward();

    _iconBounceAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _universityController.dispose();
    _courseController.dispose();
    _subjectNameController.dispose();
    _fadeAC.dispose();
    _iconBounceAC.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submitSetup();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _addSubject() {
    final name = _subjectNameController.text.trim();
    if (name.isEmpty) return;
    if (_subjects.length >= 10) return;

    setState(() {
      _subjects.add(_SubjectEntry(name: name, color: _selectedSubjectColor));
      _subjectNameController.clear();
      // Cycle to next color
      final currentIdx = _subjectColors.indexOf(_selectedSubjectColor);
      _selectedSubjectColor = _subjectColors[(currentIdx + 1) % _subjectColors.length];
    });
  }

  void _removeSubject(int index) {
    setState(() => _subjects.removeAt(index));
  }

  Future<void> _submitSetup() async {
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiServiceProvider);

      // 1. Update user profile (university, course, year)
      try {
        await api.put('/auth/me', data: {
          'university': _universityController.text.trim(),
          'course': _courseController.text.trim(),
          'year_of_study': _yearOfStudy,
        });
      } catch (_) {}

      // 2. Create subjects
      for (final subject in _subjects) {
        try {
          await api.post('/study/subjects', data: {
            'name': subject.name,
            'color': subject.color,
            'icon': 'book',
          });
        } catch (_) {}
      }

      // 3. Save sleep schedule locally (used by sleep tracking later)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cerebro_bedtime_hour', _bedtime.hour);
      await prefs.setInt('cerebro_bedtime_min', _bedtime.minute);
      await prefs.setInt('cerebro_wake_hour', _wakeTime.hour);
      await prefs.setInt('cerebro_wake_min', _wakeTime.minute);

      // 4. Save selected goals locally
      await prefs.setStringList('cerebro_goals', _selectedGoals.toList());
      await prefs.setDouble('cerebro_daily_study_hours', _dailyStudyHours);

      // 5. Save selected habits — both as names list AND as quest_definitions + daily_habits
      await prefs.setStringList('cerebro_initial_habits', _selectedHabits.toList());
      // Build quest definitions so dashboard provider picks them up immediately
      final questDefs = _selectedHabits.map((name) {
        final icon = habitIconMap[name] ?? 'check';
        return {'name': name, 'icon': icon};
      }).toList();
      final habitsWithDone = questDefs.map((q) => {...q, 'done': false}).toList();
      await prefs.setString('quest_definitions', jsonEncode(questDefs));
      await prefs.setString('daily_habits', jsonEncode(habitsWithDone));
      // Set today's date so the dashboard knows quests are fresh
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await prefs.setString('habits_date', todayKey);

      // 6. Save initial mood locally
      if (_selectedMood >= 0 && _selectedMood < _moods.length) {
        await prefs.setString('cerebro_initial_mood', _moods[_selectedMood].label);
      }

      // 7. Mark setup as complete
      await prefs.setBool(AppConstants.setupCompleteKey, true);

      if (mounted) context.go('/avatar-setup');
    } catch (e) {
      // Even if API fails, let user continue
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.setupCompleteKey, true);
      if (mounted) context.go('/avatar-setup');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  //  BUILD
  @override
  Widget build(BuildContext context) {
    final config = _stepConfigs[_currentStep];

    return Scaffold(
      backgroundColor: CerebroTheme.cream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(config),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _currentStep = i);
                  _iconBounceAC.reset();
                  _iconBounceAC.forward();
                },
                children: [
                  _buildUniversityStep(),
                  _buildYearStep(),
                  _buildSubjectsStep(),
                  _buildGoalsStep(),
                  _buildSleepStep(),
                  _buildHabitsStep(),
                  _buildMoodStep(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: _CuteButton(
                onTap: _isSubmitting ? null : _nextStep,
                color: config.color,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white,
                        ),
                      )
                    : Text(
                        _currentStep == _totalSteps - 1
                            ? "Let's Go! →"
                            : 'Continue',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  HEADER (progress + back + skip)
  Widget _buildHeader(_StepConfig config) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              if (_currentStep > 0)
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: CerebroTheme.outline, width: 2.5),
                      boxShadow: [CerebroTheme.shadow3DSmall],
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: CerebroTheme.outline, size: 18),
                  ),
                )
              else
                const SizedBox(width: 38),

              // Step counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: config.color.withOpacity(0.3), width: 1.5),
                ),
                child: Text(
                  '${_currentStep + 1} of $_totalSteps',
                  style: GoogleFonts.nunito(
                    color: config.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),

              // Skip button
              GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(AppConstants.setupCompleteKey, true);
                  if (mounted) context.go('/avatar-setup');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CerebroTheme.creamDark, width: 2),
                  ),
                  child: Text(
                    'Skip',
                    style: GoogleFonts.nunito(
                      color: CerebroTheme.brown,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Segmented progress bar
          Row(
            children: List.generate(_totalSteps, (i) {
              final isComplete = i < _currentStep;
              final isCurrent = i == _currentStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 4 : 0),
                  height: 6,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? config.color
                        : isCurrent
                            ? config.color.withOpacity(0.5)
                            : CerebroTheme.creamDark,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  //  STEP TITLE HEADER (reusable)
  Widget _stepHeader(_StepConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Icon badge
        TweenAnimationBuilder<double>(
          key: ValueKey(_currentStep),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: config.color, width: 2.5),
            ),
            child: Icon(config.icon, size: 28, color: config.color),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          config.title,
          style: GoogleFonts.nunito(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: CerebroTheme.outline,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          config.subtitle,
          style: GoogleFonts.nunito(
            color: CerebroTheme.brown,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  //  STEP 1: University & Course
  Widget _buildUniversityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(_stepConfigs[0]),
          _fieldLabel('University / College'),
          const SizedBox(height: 6),
          _cuteTextField(
            controller: _universityController,
            hint: 'e.g., London Metropolitan University',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 18),
          _fieldLabel('Course / Program'),
          const SizedBox(height: 6),
          _cuteTextField(
            controller: _courseController,
            hint: 'e.g., Computer Science',
            icon: Icons.book_outlined,
          ),
          const SizedBox(height: 24),
          _infoCard(
            icon: Icons.auto_awesome_rounded,
            text: "This helps CEREBRO personalize your study insights and connect you with relevant resources.",
            color: CerebroTheme.pinkPop,
          ),
        ],
      ),
    );
  }

  //  STEP 2: Year of Study
  Widget _buildYearStep() {
    final years = ['1st Year', '2nd Year', '3rd Year', '4th Year', 'Masters', 'PhD'];
    final icons = [
      Icons.looks_one_rounded, Icons.looks_two_rounded,
      Icons.looks_3_rounded, Icons.looks_4_rounded,
      Icons.workspace_premium_rounded, Icons.science_rounded,
    ];
    final colors = [
      CerebroTheme.pinkPop, CerebroTheme.sky, CerebroTheme.sage,
      CerebroTheme.gold, CerebroTheme.lavender, CerebroTheme.coral,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(_stepConfigs[1]),
          ...List.generate(years.length, (index) {
            final isSelected = _yearOfStudy == index + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => _yearOfStudy = index + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: isSelected ? colors[index] : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? CerebroTheme.outline : CerebroTheme.creamDark,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: isSelected ? [CerebroTheme.shadow3DSmall] : [],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : icons[index],
                        color: isSelected ? Colors.white : colors[index],
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        years[index],
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : CerebroTheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  //  STEP 3: Subjects
  Widget _buildSubjectsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(_stepConfigs[2]),

          // Subject input row
          Row(
            children: [
              // Color picker dot
              GestureDetector(
                onTap: _showColorPicker,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Color(int.parse('FF${_selectedSubjectColor.substring(1)}', radix: 16)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CerebroTheme.outline, width: 2.5),
                    boxShadow: [CerebroTheme.shadow3DSmall],
                  ),
                  child: const Icon(Icons.palette_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              // Subject name field
              Expanded(
                child: TextField(
                  controller: _subjectNameController,
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g., Mathematics',
                    hintStyle: GoogleFonts.nunito(
                        color: CerebroTheme.creamDark, fontSize: 14, fontWeight: FontWeight.w500),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CerebroTheme.creamDark, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CerebroTheme.creamDark, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CerebroTheme.sage, width: 2.5),
                    ),
                  ),
                  onSubmitted: (_) => _addSubject(),
                ),
              ),
              const SizedBox(width: 10),
              // Add button
              GestureDetector(
                onTap: _addSubject,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: CerebroTheme.sage,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CerebroTheme.outline, width: 2.5),
                    boxShadow: [CerebroTheme.shadow3DSmall],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Subject list
          if (_subjects.isEmpty)
            _infoCard(
              icon: Icons.lightbulb_rounded,
              text: "Add at least one subject so your study dashboard is ready from day one!",
              color: CerebroTheme.sage,
            )
          else
            ...List.generate(_subjects.length, (i) {
              final s = _subjects[i];
              final c = Color(int.parse('FF${s.color.substring(1)}', radix: 16));
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c, width: 2.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.book_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.name,
                            style: GoogleFonts.nunito(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: CerebroTheme.outline)),
                      ),
                      GestureDetector(
                        onTap: () => _removeSubject(i),
                        child: Icon(Icons.close_rounded,
                            color: CerebroTheme.brown.withOpacity(0.4), size: 20),
                      ),
                    ],
                  ),
                ),
              );
            }),

          if (_subjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_subjects.length}/10 subjects added',
                style: GoogleFonts.nunito(
                  color: CerebroTheme.brown, fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CerebroTheme.outline, width: 3),
            boxShadow: [CerebroTheme.shadow3D],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick a colour',
                  style: GoogleFonts.nunito(
                      fontSize: 18, fontWeight: FontWeight.w800, color: CerebroTheme.outline)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _subjectColors.map((hex) {
                  final c = Color(int.parse('FF${hex.substring(1)}', radix: 16));
                  final isSelected = hex == _selectedSubjectColor;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedSubjectColor = hex);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? CerebroTheme.outline : c,
                          width: isSelected ? 3 : 2,
                        ),
                        boxShadow: isSelected ? [CerebroTheme.shadow3DSmall] : [],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //  STEP 4: Goals & Study Time
  Widget _buildGoalsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(_stepConfigs[3]),

          // Goal chips
          Text('Select all that apply',
              style: GoogleFonts.nunito(
                  color: CerebroTheme.brown, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _studyGoals.map((goal) {
              final isSelected = _selectedGoals.contains(goal.label);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedGoals.remove(goal.label);
                  } else {
                    _selectedGoals.add(goal.label);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? goal.color : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? CerebroTheme.outline : CerebroTheme.creamDark,
                      width: isSelected ? 2.5 : 2,
                    ),
                    boxShadow: isSelected ? [CerebroTheme.shadow3DSmall] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(goal.icon, size: 18,
                          color: isSelected ? Colors.white : goal.color),
                      const SizedBox(width: 6),
                      Text(goal.label,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700, fontSize: 13,
                            color: isSelected ? Colors.white : CerebroTheme.outline,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // Daily study hours
          Text('Daily study target',
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800, fontSize: 15, color: CerebroTheme.outline)),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CerebroTheme.outline, width: 3),
                boxShadow: [CerebroTheme.shadow3D],
              ),
              child: Text(
                '${_dailyStudyHours.toStringAsFixed(_dailyStudyHours % 1 == 0 ? 0 : 1)} hours',
                style: GoogleFonts.nunito(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: CerebroTheme.gold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: CerebroTheme.gold,
              inactiveTrackColor: CerebroTheme.creamDark,
              thumbColor: CerebroTheme.gold,
              overlayColor: CerebroTheme.gold.withOpacity(0.2),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: _dailyStudyHours,
              min: 0.5,
              max: 8,
              divisions: 15,
              onChanged: (v) => setState(() => _dailyStudyHours = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('30 min', style: GoogleFonts.nunito(
                    color: CerebroTheme.brown, fontSize: 11, fontWeight: FontWeight.w600)),
                Text('8 hours', style: GoogleFonts.nunito(
                    color: CerebroTheme.brown, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //  STEP 5: Sleep Schedule
  Widget _buildSleepStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(_stepConfigs[4]),

          // Bedtime picker
          _timePickerCard(
            label: 'Bedtime',
            icon: Icons.nights_stay_rounded,
            time: _bedtime,
            color: CerebroTheme.lavender,
            onTap: () => _pickTime(isBedtime: true),
          ),
          const SizedBox(height: 14),

          // Wake time picker
          _timePickerCard(
            label: 'Wake Up',
            icon: Icons.wb_sunny_rounded,
            time: _wakeTime,
            color: CerebroTheme.gold,
            onTap: () => _pickTime(isBedtime: false),
          ),

          const SizedBox(height: 20),

          // Sleep hours display
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: CerebroTheme.lavender.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CerebroTheme.lavender.withOpacity(0.3), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, color: CerebroTheme.lavender, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '${_calculateSleepHours()} hours of sleep',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: CerebroTheme.lavenderDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _infoCard(
            icon: Icons.tips_and_updates_rounded,
            text: "CEREBRO will use this to remind you about bedtime and track your sleep quality.",
            color: CerebroTheme.lavender,
          ),
        ],
      ),
    );
  }

  Widget _timePickerCard({
    required String label,
    required IconData icon,
    required TimeOfDay time,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CerebroTheme.outline, width: 3),
          boxShadow: [CerebroTheme.shadow3DSmall],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w600, color: CerebroTheme.brown)),
                Text(
                  _formatTime(time),
                  style: GoogleFonts.nunito(
                    fontSize: 28, fontWeight: FontWeight.w900, color: CerebroTheme.outline,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.edit_rounded, color: CerebroTheme.brown.withOpacity(0.4), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isBedtime}) async {
    final initial = isBedtime ? _bedtime : _wakeTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: isBedtime ? CerebroTheme.lavender : CerebroTheme.gold,
              surface: Colors.white,
              onSurface: CerebroTheme.outline,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isBedtime) {
          _bedtime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _calculateSleepHours() {
    int bedMins = _bedtime.hour * 60 + _bedtime.minute;
    int wakeMins = _wakeTime.hour * 60 + _wakeTime.minute;
    int diff = wakeMins - bedMins;
    if (diff <= 0) diff += 24 * 60; // crosses midnight
    final hours = diff / 60;
    return hours.toStringAsFixed(1);
  }

  //  STEP 6: Habits
  Widget _buildHabitsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(_stepConfigs[5]),
          Text('Pick habits you want to build',
              style: GoogleFonts.nunito(
                  color: CerebroTheme.brown, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Habit grid (2 columns)
          ...List.generate((_habitPresets.length / 2).ceil(), (row) {
            final i1 = row * 2;
            final i2 = i1 + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: _habitChip(_habitPresets[i1])),
                  const SizedBox(width: 8),
                  if (i2 < _habitPresets.length)
                    Expanded(child: _habitChip(_habitPresets[i2]))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            );
          }),

          if (_selectedHabits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _infoCard(
                icon: Icons.emoji_events_rounded,
                text: "You'll earn ${_selectedHabits.length * 10} XP daily by completing all selected habits!",
                color: CerebroTheme.coral,
              ),
            ),
        ],
      ),
    );
  }

  Widget _habitChip(_HabitItem habit) {
    final isSelected = _selectedHabits.contains(habit.label);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedHabits.remove(habit.label);
        } else {
          _selectedHabits.add(habit.label);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? habit.color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? habit.color : CerebroTheme.creamDark,
            width: isSelected ? 2.5 : 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: habit.color.withOpacity(0.15),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isSelected ? habit.color : habit.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(habit.icon, size: 17,
                  color: isSelected ? Colors.white : habit.color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(habit.label,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? habit.color : CerebroTheme.outline,
                  )),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: habit.color, size: 18),
          ],
        ),
      ),
    );
  }

  //  STEP 7: Initial Mood
  Widget _buildMoodStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(_stepConfigs[6]),

          // Mood grid (2x4)
          ...List.generate((_moods.length / 2).ceil(), (row) {
            final i1 = row * 2;
            final i2 = i1 + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: _moodCard(i1)),
                  const SizedBox(width: 10),
                  if (i2 < _moods.length)
                    Expanded(child: _moodCard(i2))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
          _infoCard(
            icon: Icons.auto_awesome_rounded,
            text: "Your avatar's expression will match your mood. Track daily for insights!",
            color: CerebroTheme.pinkPop,
          ),
          const SizedBox(height: 8),
          // Teaser for next step
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CerebroTheme.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CerebroTheme.gold.withOpacity(0.3), width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.face_rounded, color: CerebroTheme.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Next up: create your personal avatar companion!",
                    style: GoogleFonts.nunito(
                      color: CerebroTheme.goldDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodCard(int index) {
    final mood = _moods[index];
    final isSelected = _selectedMood == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMood = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? mood.color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? CerebroTheme.outline : CerebroTheme.creamDark,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected ? [CerebroTheme.shadow3DSmall] : [],
        ),
        child: Column(
          children: [
            Text(mood.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text(
              mood.label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : CerebroTheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  SHARED WIDGETS
  Widget _fieldLabel(String text) => Text(text,
      style: GoogleFonts.nunito(
          fontWeight: FontWeight.w800, fontSize: 13, color: CerebroTheme.outline));

  Widget _cuteTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
            color: CerebroTheme.creamDark, fontSize: 14, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: CerebroTheme.brown.withOpacity(0.5), size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CerebroTheme.creamDark, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CerebroTheme.creamDark, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CerebroTheme.pinkPop, width: 2.5),
        ),
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: GoogleFonts.nunito(
                    color: CerebroTheme.outline, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

//  DATA CLASSES

class _SubjectEntry {
  final String name;
  final String color;
  _SubjectEntry({required this.name, required this.color});
}

class _GoalItem {
  final String label;
  final IconData icon;
  final Color color;
  const _GoalItem(this.label, this.icon, this.color);
}

class _HabitItem {
  final String label;
  final IconData icon;
  final Color color;
  final String colorHex;
  const _HabitItem(this.label, this.icon, this.color, this.colorHex);
}

class _MoodItem {
  final String label;
  final String emoji;
  final Color color;
  const _MoodItem(this.label, this.emoji, this.color);
}

class _StepConfig {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _StepConfig(this.icon, this.title, this.subtitle, this.color);
}

//  CUTE BUTTON (Toca Boca press-down effect)
class _CuteButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Color color;
  final Widget child;

  const _CuteButton({
    required this.onTap,
    required this.color,
    required this.child,
  });

  @override
  State<_CuteButton> createState() => _CuteButtonState();
}

class _CuteButtonState extends State<_CuteButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 54,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CerebroTheme.outline, width: 3.5),
          boxShadow: [
            if (!_pressed) CerebroTheme.shadow3D,
          ],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}
