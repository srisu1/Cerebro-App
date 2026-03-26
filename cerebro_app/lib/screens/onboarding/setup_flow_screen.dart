// Post-onboarding setup wizard — 8 steps collecting user profile,
// institution, subjects, study/sleep preferences, daily goals, and mood.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/services/api_service.dart';
import 'dart:convert';
import 'dart:async';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';

//  STEP DATA
class _StepInfo {
  final String title;
  final String subtitle;
  const _StepInfo(this.title, this.subtitle);
}

// Each step feeds a concrete Cerebro system — nothing here is "vibes-only".
// See _submitSetup() for the exact fields each step writes to the backend.
// NOTE: Daily Goals lives in the wizard so a brand-new user lands on a
// dashboard with real quests from minute one. Medications stays OUT of the
// wizard — users can add/remove meds from the Health tab with dosage,
// schedule, and notes, which is far more flexibility than a setup flow.
// Settings (profile_tab.dart) intentionally omits Daily Goals and Medications
// too; both are edited in-app near the features that use them.
// If the user skips the wizard or finishes without picking any habits, the
// backend seeds four sensible defaults (see daily.py::_FALLBACK_DEFAULT_HABITS)
// and _submitSetup() pre-populates the local prefs cache so the dashboard
// never renders an empty quest list.
const _stepInfos = [
  _StepInfo('About You',          "What kind of student are you?"),        // institution_type
  _StepInfo('Your Institution',   'Where do you study?'),                   // name / course / year
  _StepInfo('Your Subjects',      'Pick or add your subjects'),             // /study/subjects
  _StepInfo('Study Time',         'How many hours a day?'),                 // daily_study_hours
  _StepInfo('Sleep Schedule',     'Good rest = good grades'),               // bedtime / wake_time
  _StepInfo('Daily Goals',        "Pick today's quests"),                   // /daily/habits seed
  _StepInfo('Medical Conditions', 'Cerebro keeps these in mind'),           // medical_conditions
  _StepInfo('How Are You Feeling?','Set your starting mood'),               // initial_mood
];

// Institution type definitions
class _InstitutionType {
  final String key;
  final String label;
  final String icon;
  final String desc;
  const _InstitutionType(this.key, this.label, this.icon, this.desc);
}

const _institutionTypes = [
  _InstitutionType('school', 'School', 'S', 'GCSE / O-Levels / Secondary'),
  _InstitutionType('sixth_form', 'Sixth Form', '6', 'A-Levels / IB / BTEC'),
  _InstitutionType('college', 'College', 'C', 'Diploma / Foundation / HND'),
  _InstitutionType('university', 'University', 'U', 'Undergraduate / Postgrad'),
];

//  SETUP FLOW SCREEN
class SetupFlowScreen extends ConsumerStatefulWidget {
  const SetupFlowScreen({super.key});
  @override
  ConsumerState<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends ConsumerState<SetupFlowScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  final int _totalSteps = 8;
  bool _isSubmitting = false;
  // Max items the user can pick as starting Daily Goals in the wizard.
  // Enforced visually via the counter pill + "at cap" chip disabled state
  // in _step6DailyGoals(), and respected by _submitSetup() when it posts
  // the habit list to /daily/habits.
  static const int _maxDailyGoals = 4;

  // Card pop-in animation
  late final AnimationController _cardAc;
  late final Animation<double> _cardScale, _cardFade, _cardSlide;

  // Step transition animation
  late final AnimationController _stepAc;

  String? _institutionType;  // school, sixth_form, college, university

  final _institutionNameController = TextEditingController();
  final _courseController = TextEditingController();
  int _yearOfStudy = 1;
  String? _degreeLevel;  // undergraduate, masters, phd (for university/college)

  // Institution search
  List<Map<String, String>> _institutionResults = [];
  bool _searchingInstitutions = false;
  String? _selectedAffiliation;  // e.g. "Affiliated with London Metropolitan University"

  final List<_SubjectEntry> _subjects = [];
  final _subjectNameController = TextEditingController();
  int _colorIdx = 0;
  static const _subjectColors = [
    '#fea9d3', '#ddf6ff', '#98a869', '#f7aeae', '#ffbc5c',
    '#e4bc83', '#ffd5f5', '#ef6262', '#58772f', '#fdefdb',
  ];
  List<_SuggestedSubject> _suggestedSubjects = [];
  bool _loadingSuggestions = false;
  bool _suggestionsLoaded = false;

  // Subject search results (when user types in add-your-own)
  List<_SubjectSearchResult> _subjectSearchResults = [];
  bool _searchingSubjects = false;

  // Debounce timers
  Timer? _instSearchDebounce;
  Timer? _subjectSearchDebounce;

  // The old "pick a goal" chips (Improve GPA / Stay Organized / ...) were
  // removed because they didn't map to any concrete Cerebro feature.
  // We keep only the daily-hours target, which IS wired into the smart
  // scheduler + AI coach recommendations.
  double _dailyStudyHours = 3.0;
  bool _studyHoursPersonalised = false;

  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 30);

  // Selection is capped at _maxDailyGoals. These items are promoted to
  // today's quests on first login (see _submitSetup — SharedPreferences
  // 'quest_definitions' + 'daily_habits').
  final Set<String> _selectedHabits = {};

  // Stored on users.medical_conditions. Used to personalise the symptom
  // chip picker in the Health tab and to flavour Insights correlations.
  final Set<String> _selectedConditions = {};
  final _conditionInputController = TextEditingController();
  // Live query: as the user types in the "Add another" field, preset
  // chips filter + an autocomplete suggestions list surfaces any
  // extended presets that match. Empty string = show everything.
  String _conditionQuery = '';

  // Creates real rows in the medications table on submit so reminders +
  // adherence tracking work from day one.
  final List<_MedicationEntry> _medications = [];

  int _selectedMood = -1;

  static const _habitItems = [
    _HabitDef('Drink Water',      Color(0xFFDDF6FF)),
    _HabitDef('Exercise',         Color(0xFFF7AEAE)),
    _HabitDef('Read',             Color(0xFFFFD5F5)),
    _HabitDef('Meditate',         Color(0xFF98A869)),
    _HabitDef('No Junk Food',     Color(0xFFFEA9D3)),
    _HabitDef('Walk 10k Steps',   Color(0xFF58772F)),
    _HabitDef('No Social Media',  Color(0xFFEF6262)),
    _HabitDef('Study 2+ Hours',   Color(0xFFDDF6FF)),
    _HabitDef('Sleep Before 12',  Color(0xFFE4BC83)),
  ];

  // Common conditions — user can toggle preset chips AND add custom ones.
  // Intentionally broad so almost any student sees at least one relevant
  // option. Custom conditions get normalised (title-case, trimmed) before
  // being added to the set.
  static const _conditionPresets = [
    'Migraine', 'ADHD', 'Anxiety', 'Depression', 'PCOS', 'Asthma',
    'Diabetes', 'IBS', 'Insomnia', 'Hypertension', 'Dyslexia', 'Eczema',
  ];

  // Extended catalog — never shown as chips up-front (keeps the chip
  // grid tight) but surfaces via the type-ahead suggestions row when
  // the user starts typing in the custom input.
  static const _conditionAutocomplete = [
    'Migraine', 'ADHD', 'Anxiety', 'Depression', 'PCOS', 'Asthma',
    'Diabetes', 'IBS', 'Insomnia', 'Hypertension', 'Dyslexia', 'Eczema',
    'Acid Reflux', 'Acne', 'Allergies', 'Anemia', 'Arthritis',
    'Autism', 'Bipolar', 'Celiac', 'Chronic Fatigue', 'Chronic Pain',
    'Concussion', 'Crohn\'s', 'Endometriosis', 'Epilepsy', 'Fibromyalgia',
    'GERD', 'Hypothyroidism', 'Hyperthyroidism', 'Lupus',
    'Lyme Disease', 'Migraine with Aura', 'Narcolepsy', 'OCD',
    'Osteoporosis', 'POTS', 'PMDD', 'PTSD', 'Psoriasis',
    'Rheumatoid Arthritis', 'Sciatica', 'Scoliosis', 'Seasonal Allergies',
    'Sinusitis', 'Sleep Apnea', 'Tinnitus', 'TMJ', 'Tourette\'s',
    'Ulcerative Colitis',
  ];

  static const _moodItems = [
    _MoodDef('Happy', Color(0xFFFFBC5C)),
    _MoodDef('Excited', Color(0xFFFEA9D3)),
    _MoodDef('Calm', Color(0xFFDDF6FF)),
    _MoodDef('Focused', Color(0xFF98A869)),
    _MoodDef('Tired', Color(0xFFE4BC83)),
    _MoodDef('Stressed', Color(0xFFEF6262)),
    _MoodDef('Sad', Color(0xFFF7AEAE)),
    _MoodDef('Anxious', Color(0xFFFFD5F5)),
  ];

  @override
  void initState() {
    super.initState();

    _cardAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _cardScale = Tween(begin: 0.96, end: 1.0).animate(
        CurvedAnimation(parent: _cardAc, curve: Curves.elasticOut));
    _cardFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardAc, curve: const Interval(0.0, 0.5)));
    _cardSlide = Tween(begin: 12.0, end: 0.0).animate(
        CurvedAnimation(parent: _cardAc, curve: Curves.easeOut));

    _stepAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _cardAc.dispose();
    _stepAc.dispose();
    _institutionNameController.dispose();
    _courseController.dispose();
    _subjectNameController.dispose();
    _conditionInputController.dispose();
    _instSearchDebounce?.cancel();
    _subjectSearchDebounce?.cancel();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      final nextStep = _currentStep + 1;
      setState(() => _currentStep = nextStep);
      _stepAc.forward(from: 0);
      // When arriving at subjects step, fetch AI suggestions
      if (nextStep == 2 && !_suggestionsLoaded) {
        _fetchSuggestedSubjects();
      }
      // Personalise study hours when arriving at goals step
      if (nextStep == 3 && !_studyHoursPersonalised) {
        _studyHoursPersonalised = true;
        setState(() => _dailyStudyHours = _recommendedStudyHours());
      }
    } else {
      _submitSetup();
    }
  }

  Future<void> _fetchSuggestedSubjects() async {
    if (_loadingSuggestions) return;
    setState(() => _loadingSuggestions = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.post('/study/suggest-subjects', data: {
        'institution_type': _institutionType ?? 'university',
        'institution_name': _institutionNameController.text.trim(),
        'course': _courseController.text.trim(),
        'year_of_study': _yearOfStudy,
        'degree_level': _degreeLevel,
        'affiliation': _selectedAffiliation,
      });
      if (resp.statusCode == 200 && resp.data is List) {
        final list = (resp.data as List).map((s) => _SuggestedSubject(
          name: s['name'] ?? '',
          code: s['code'],
          color: s['color'] ?? '#fea9d3',
        )).toList();
        if (mounted) {
          setState(() {
            _suggestedSubjects = list;
            _suggestionsLoaded = true;
          });
        }
      }
    } catch (e) {
      print('[SETUP] Subject suggestion failed: $e');
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _searchSubjects(String query) async {
    if (query.trim().length < 2) {
      setState(() { _subjectSearchResults = []; _searchingSubjects = false; });
      return;
    }
    setState(() => _searchingSubjects = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.post('/study/search-subjects', data: {
        'query': query.trim(),
        'institution_type': _institutionType ?? 'university',
        'institution_name': _institutionNameController.text.trim(),
        'course': _courseController.text.trim(),
        'affiliation': _selectedAffiliation,
      });
      if (resp.statusCode == 200 && resp.data is List) {
        final list = (resp.data as List).map((e) => _SubjectSearchResult(
          name: e['name']?.toString() ?? '',
          code: e['code']?.toString(),
        )).toList();
        if (mounted) setState(() => _subjectSearchResults = list);
      }
    } catch (e) {
      print('[SETUP] Subject search failed: $e');
    } finally {
      if (mounted) setState(() => _searchingSubjects = false);
    }
  }

  Future<void> _searchInstitutions(String query) async {
    if (query.trim().length < 3) {
      setState(() { _institutionResults = []; _searchingInstitutions = false; });
      return;
    }
    setState(() => _searchingInstitutions = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.post('/study/search-institutions', data: {
        'query': query.trim(),
        'institution_type': _institutionType ?? 'university',
      });
      if (resp.statusCode == 200 && resp.data is List) {
        final list = (resp.data as List).map((e) => {
          'name': e['name']?.toString() ?? '',
          'affiliation': e['affiliation']?.toString() ?? '',
          'country': e['country']?.toString() ?? '',
        }).toList();
        if (mounted) setState(() => _institutionResults = list);
      }
    } catch (e) {
      print('[SETUP] Institution search failed: $e');
    } finally {
      if (mounted) setState(() => _searchingInstitutions = false);
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _stepAc.forward(from: 0);
    }
  }

  void _addSubject() {
    final name = _subjectNameController.text.trim();
    if (name.isEmpty || _subjects.length >= 10) return;
    setState(() {
      _subjects.add(_SubjectEntry(name: name, color: _subjectColors[_colorIdx]));
      _subjectNameController.clear();
      _colorIdx = (_colorIdx + 1) % _subjectColors.length;
    });
  }

  void _removeSubject(int i) => setState(() => _subjects.removeAt(i));

  String _calcSleepHours() {
    int bed = _bedtime.hour * 60 + _bedtime.minute;
    int wake = _wakeTime.hour * 60 + _wakeTime.minute;
    int diff = wake - bed;
    if (diff <= 0) diff += 24 * 60;
    return (diff / 60).toStringAsFixed(1);
  }

  Future<void> _pickTime({required bool isBedtime}) async {
    final initial = isBedtime ? _bedtime : _wakeTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: CerebroTheme.pinkAccent,
            surface: Colors.white,
            onSurface: CerebroTheme.text1,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isBedtime) _bedtime = picked; else _wakeTime = picked;
      });
    }
  }

  Future<void> _submitSetup() async {
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiServiceProvider);

      // Persist the full wizard payload to users row — single source of truth
      // for the smart study system, quiz generator, insights, and gamification.
      String _fmtTime(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
      final double _sleepHoursTarget = double.tryParse(_calcSleepHours()) ?? 8.0;
      final String? _moodName =
          (_selectedMood >= 0 && _selectedMood < _moodItems.length)
              ? _moodItems[_selectedMood].label
              : null;

      try {
        await api.put('/auth/me', data: {
          'institution_type': _institutionType,
          'university': _institutionNameController.text.trim(),
          'course': _courseController.text.trim(),
          'year_of_study': _yearOfStudy,
          'degree_level': _degreeLevel,
          if (_selectedAffiliation != null && _selectedAffiliation!.isNotEmpty)
            'affiliation': _selectedAffiliation,
          'daily_study_hours': _dailyStudyHours,
          // study_goals intentionally omitted — the vague chips step was
          // removed. The `Daily Goals` step now feeds initial_habits, which
          // is what the quest system actually reads.
          'bedtime': _fmtTime(_bedtime),
          'wake_time': _fmtTime(_wakeTime),
          'sleep_hours_target': _sleepHoursTarget,
          if (_moodName != null) 'initial_mood': _moodName,
          'initial_habits': _selectedHabits.toList(),
          'medical_conditions': _selectedConditions.toList(),
        });
      } catch (_) {}

      for (final subject in _subjects) {
        try {
          await api.post('/study/subjects', data: {
            'name': subject.name,
            'color': subject.color,
            'code': subject.code,
            'icon': 'book',
          });
        } catch (_) {}
      }

      // Medications are no longer collected in the wizard — users add them
      // from the Health tab's Medications screen, which is more flexible
      // (reminder schedules, days-of-week picker, etc.). This loop still
      // runs defensively in case `_medications` is populated by a future
      // re-introduction of the step.
      for (final med in _medications) {
        try {
          await api.post('/health/medications', data: {
            'name': med.name,
            'dosage': med.dosage,
            'frequency': med.frequency,
            if (med.frequency == 'daily')
              'times_of_day': ['${_fmtTime(med.time)}'],
            'days_of_week': [1, 2, 3, 4, 5, 6, 7],
            'reminder_enabled': true,
          });
        } catch (_) {}
      }

      // The Daily Goals step was pulled from the wizard; _selectedHabits
      // will normally be empty. When it IS empty we ALWAYS call the
      // backend's seed-defaults endpoint so the user lands on Today's
      // Quests with 4 fallback habits already populated — no empty state.
      // If the step is ever re-introduced and picks exist, we wipe the
      // existing rows first so the quest card reflects the fresh picks.
      if (_selectedHabits.isNotEmpty) {
        try {
          final listRes = await api.get('/daily/habits');
          if (listRes.statusCode == 200) {
            final existing = (listRes.data as List?) ?? [];
            for (final h in existing) {
              final hid = h['id'];
              if (hid == null) continue;
              try {
                await api.delete('/daily/habits/$hid');
              } catch (_) {}
            }
          }
        } catch (_) {}
        for (final habitName in _selectedHabits) {
          try {
            await api.post('/daily/habits', data: {
              'name': habitName,
              'icon': habitIconMap[habitName] ?? 'check',
            });
          } catch (_) {}
        }
      } else {
        // User didn't pick any quests (either the Daily Goals step was
        // pulled or they skipped everything) — explicitly seed the 4
        // fallback defaults on the backend. Safe to call: the endpoint
        // is a no-op when the user already has habits, so it only ever
        // creates rows on an empty slate.
        try {
          await api.post('/daily/habits/seed-defaults');
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cerebro_bedtime_hour', _bedtime.hour);
      await prefs.setInt('cerebro_bedtime_min', _bedtime.minute);
      await prefs.setInt('cerebro_wake_hour', _wakeTime.hour);
      await prefs.setInt('cerebro_wake_min', _wakeTime.minute);
      await prefs.setDouble('cerebro_daily_study_hours', _dailyStudyHours);
      await prefs.setStringList('cerebro_initial_habits', _selectedHabits.toList());
      await prefs.setStringList('cerebro_medical_conditions', _selectedConditions.toList());

      // Compute quest defs from wizard picks. When the wizard has no picks
      // (Daily Goals step was pulled from the flow), mirror the backend's
      // _FALLBACK_DEFAULT_HABITS so the dashboard has 4 real quests to show
      // before /daily/habits returns from the backend.
      final wizardQuestDefs = _selectedHabits.map((name) {
        final icon = habitIconMap[name] ?? 'check';
        return {'name': name, 'icon': icon};
      }).toList();
      final questDefs = wizardQuestDefs.isNotEmpty
          ? wizardQuestDefs
          : const [
              {'name': 'Drink Water',    'icon': 'water'},
              {'name': 'Read 15 min',    'icon': 'book'},
              {'name': 'Walk 10k Steps', 'icon': 'walk'},
              {'name': 'Stretch',        'icon': 'fitness'},
            ];
      final habitsWithDone = questDefs.map((q) => {...q, 'done': false}).toList();
      await prefs.setString('quest_definitions', jsonEncode(questDefs));
      await prefs.setString('daily_habits', jsonEncode(habitsWithDone));
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await prefs.setString('habits_date', todayKey);

      if (_selectedMood >= 0 && _selectedMood < _moodItems.length) {
        await prefs.setString('cerebro_initial_mood', _moodItems[_selectedMood].label);
      }

      await prefs.setBool(AppConstants.setupCompleteKey, true);
      if (mounted) context.go('/avatar-setup');
    } catch (e) {
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
    return Scaffold(
      backgroundColor: CerebroTheme.creamWarm,
      body: Stack(
        children: [
          // Diamond pattern background (cream variant)
          Positioned.fill(child: _CreamDiamondPattern()),

          // Centered card
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AnimatedBuilder(
                animation: _cardAc,
                builder: (ctx, _) => Opacity(
                  opacity: _cardFade.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, _cardSlide.value),
                    child: Transform.scale(
                      scale: _cardScale.value.clamp(0.96, 1.0),
                      child: Center(
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 1400),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: CerebroTheme.text1, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: CerebroTheme.text1.withOpacity(0.5),
                                offset: const Offset(8, 8),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: _cardLayout(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  CARD LAYOUT — horizontal split
  Widget _cardLayout() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Use horizontal split if wide enough, otherwise stack vertically
        final wide = constraints.maxWidth > 600;
        if (wide) {
          return Row(
            children: [
              // Left panel (44%)
              SizedBox(
                width: constraints.maxWidth * 0.44,
                child: _leftPanel(),
              ),
              // Vertical divider
              Container(width: 3, color: CerebroTheme.text1),
              // Right panel (flex)
              Expanded(child: _rightPanel()),
            ],
          );
        } else {
          // Narrow: skip left panel, full-width form
          return _rightPanel();
        }
      },
    );
  }

  //  LEFT PANEL — illustration + brand block
  Widget _leftPanel() {
    return Column(
      children: [
        // Illustration area
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.5, -1.0),
                end: Alignment(0.5, 1.0),
                stops: [0.0, 0.5, 1.0],
                colors: [
                  CerebroTheme.creamWarm,
                  CerebroTheme.greenPale,
                  CerebroTheme.pinkLight,
                ],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: SizedBox(
                      width: 700,
                      height: 520,
                      child: SvgPicture.asset(
                        'assets/illustrations/setup_illustration.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Brand block
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: CerebroTheme.creamWarm,
            border: Border(top: BorderSide(color: CerebroTheme.text1, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Setup Wizard',
                style: TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 35,
                  color: CerebroTheme.text1,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text("Let's personalise your Cerebro experience~",
                style: GoogleFonts.gaegu(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CerebroTheme.text2,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //  RIGHT PANEL — progress + content + footer
  Widget _rightPanel() {
    return Column(
      children: [
        // Progress strip
        _progressStrip(),
        // Content area (scrollable)
        Expanded(child: _contentArea()),
        // Footer with Back/Next
        _footer(),
      ],
    );
  }

  //  PROGRESS STRIP
  Widget _progressStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: const BoxDecoration(
        color: CerebroTheme.creamWarm,
        border: Border(bottom: BorderSide(color: CerebroTheme.text1, width: 3)),
      ),
      child: Row(
        children: [
          // Step indicator label
          Text(
            'STEP ${_currentStep + 1} OF $_totalSteps',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: CerebroTheme.text3,
            ),
          ),
          const SizedBox(width: 16),
          // Progress segments
          ...List.generate(_totalSteps, (i) {
            final done = i < _currentStep;
            final active = i == _currentStep;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 5 : 0),
                height: 10,
                decoration: BoxDecoration(
                  color: done
                      ? CerebroTheme.pinkAccent
                      : active
                          ? CerebroTheme.olive
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CerebroTheme.text1, width: 2),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  //  CONTENT AREA
  Widget _contentArea() {
    final info = _stepInfos[_currentStep];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_currentStep),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 28, 40, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(info.title,
                style: const TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 34,
                  color: CerebroTheme.text1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(info.subtitle,
                style: GoogleFonts.gaegu(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CerebroTheme.olive,
                ),
              ),
              const SizedBox(height: 22),
              // Step body
              _buildStepBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    // Step order matches _stepInfos. Medications stays out of the wizard —
    // it's edited from the Health tab where dosage/schedule live.
    switch (_currentStep) {
      case 0: return _step1InstitutionType();
      case 1: return _step2InstitutionDetails();
      case 2: return _step3Subjects();
      case 3: return _step4StudyTime();
      case 4: return _step5Sleep();
      case 5: return _step6DailyGoals();
      case 6: return _step7Conditions();
      case 7: return _step9Mood();
      default: return const SizedBox();
    }
  }

  //  FOOTER
  Widget _footer() {
    final isLast = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 14, 32, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CerebroTheme.text1, width: 3)),
      ),
      child: Row(
        children: [
          // Leading slot: Back on steps 2+, empty spacer on step 1.
          if (_currentStep > 0)
            _GameBtn(
              label: 'Back',
              icon: Icons.chevron_left_rounded,
              iconFirst: true,
              color: Colors.white,
              textColor: CerebroTheme.text1,
              shadowColor: CerebroTheme.text1,
              onTap: _back,
            )
          else
            const SizedBox(width: 80),
          const Spacer(),
          // Skip slot: visible on EVERY step (including the last), and
          // always exits the entire wizard straight to /home rather than
          // just advancing to the next step. We also stamp the setup/
          // avatar/onboarding completion flags so downstream guards don't
          // bounce the user right back here on the next app launch.
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _GameBtn(
                label: 'Skip',
                icon: Icons.keyboard_double_arrow_right_rounded,
                color: Colors.white,
                textColor: CerebroTheme.text3,
                shadowColor: CerebroTheme.text1,
                onTap: _isSubmitting ? null : _skip,
              ),
            ),
          // Next / Finish button
          _GameBtn(
            label: isLast ? 'Finish' : 'Next',
            icon: isLast ? Icons.check_rounded : Icons.play_arrow_rounded,
            color: CerebroTheme.pinkAccent,
            textColor: CerebroTheme.text1,
            shadowColor: CerebroTheme.text1,
            onTap: _isSubmitting ? null : _next,
            isLoading: _isSubmitting,
          ),
        ],
      ),
    );
  }

  /// Skip the entire wizard — stamp every completion flag as done and
  /// jump to /home. The user can still edit any of these fields later
  /// from Profile → Settings. Keeping the button destructive of the
  /// wizard (rather than just advancing one step) makes the "for now
  /// the wizard is off" escape hatch easy to find: one button, one tap,
  /// every step.
  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompleteKey, true);
    await prefs.setBool(AppConstants.setupCompleteKey, true);
    await prefs.setBool(AppConstants.avatarCreatedKey, true);
    if (!mounted) return;
    context.go('/home');
  }

  //  STEP 1: Institution Type
  Widget _step1InstitutionType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("I'm studying at a...",
          style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: CerebroTheme.text2,
          ),
        ),
        const SizedBox(height: 12),
        _optionGrid(
          count: _institutionTypes.length,
          columns: 2,
          builder: (i) {
            final t = _institutionTypes[i];
            final sel = _institutionType == t.key;
            return GestureDetector(
              onTap: () => setState(() {
                _institutionType = t.key;
                // Reset year when type changes
                _yearOfStudy = 1;
                _suggestionsLoaded = false;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                decoration: BoxDecoration(
                  color: sel ? CerebroTheme.pinkLight : const Color(0xFFFEFDFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CerebroTheme.text1, width: 2.5),
                  boxShadow: sel
                      ? [const BoxShadow(color: CerebroTheme.text1, offset: Offset(4, 4), blurRadius: 0)]
                      : [],
                ),
                child: Column(
                  children: [
                    Text(t.icon,
                      style: const TextStyle(fontFamily: 'Bitroad', fontSize: 26, color: CerebroTheme.text1),
                    ),
                    const SizedBox(height: 5),
                    Text(t.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.gaegu(
                        fontSize: 18, fontWeight: FontWeight.w700, color: CerebroTheme.text1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(t.desc,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12, fontWeight: FontWeight.w500, color: CerebroTheme.text3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  //  STEP 2: Institution Details + Year
  Widget _step2InstitutionDetails() {
    // Dynamic labels based on institution type
    final instLabel = _institutionType == 'school'
        ? 'School Name'
        : _institutionType == 'sixth_form'
            ? 'Sixth Form / College Name'
            : _institutionType == 'college'
                ? 'College Name'
                : 'University Name';
    final instHint = _institutionType == 'school'
        ? 'e.g., Budhanilkantha School'
        : _institutionType == 'sixth_form'
            ? 'e.g., Islington College'
            : _institutionType == 'college'
                ? 'e.g., Islington College'
                : 'e.g., London Metropolitan University';
    final courseLabel = _institutionType == 'school'
        ? 'Stream / Board'
        : _institutionType == 'sixth_form'
            ? 'Qualification (e.g., A-Levels, IB)'
            : _institutionType == 'college'
                ? 'Program / Diploma'
                : 'Course / Degree';
    final courseHint = _institutionType == 'school'
        ? 'e.g., Science Stream, GCSE'
        : _institutionType == 'sixth_form'
            ? 'e.g., A-Levels, IB Diploma'
            : _institutionType == 'college'
                ? 'e.g., HND Computing, Foundation Art'
                : 'e.g., BSc Computer Science';

    // Show degree level for university / college
    final showDegreeLevel = _institutionType == 'university' || _institutionType == 'college';

    // Dynamic year options based on degree level
    final yearOptions = _getYearOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Institution name with search
        _formLabel(instLabel),
        const SizedBox(height: 5),
        _formInput(_institutionNameController, instHint, onChanged: (v) {
          _instSearchDebounce?.cancel();
          _instSearchDebounce = Timer(const Duration(milliseconds: 500), () {
            _searchInstitutions(v);
          });
        }),

        // Search results dropdown
        if (_searchingInstitutions)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: CerebroTheme.olive)),
                const SizedBox(width: 8),
                Text('Searching...', style: GoogleFonts.nunito(fontSize: 13, color: CerebroTheme.text3)),
              ],
            ),
          )
        else if (_institutionResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CerebroTheme.text1, width: 2),
              boxShadow: const [BoxShadow(color: CerebroTheme.text1, offset: Offset(3, 3), blurRadius: 0)],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _institutionResults.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: CerebroTheme.dividerGreen),
              itemBuilder: (ctx, i) {
                final inst = _institutionResults[i];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _institutionNameController.text = inst['name'] ?? '';
                      _selectedAffiliation = inst['affiliation']?.isNotEmpty == true ? inst['affiliation'] : null;
                      _institutionResults = [];
                      _suggestionsLoaded = false;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inst['name'] ?? '',
                          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: CerebroTheme.text1)),
                        if (inst['affiliation']?.isNotEmpty == true)
                          Text(inst['affiliation']!,
                            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w500, color: CerebroTheme.olive)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Affiliation badge
        if (_selectedAffiliation != null && _selectedAffiliation!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: CerebroTheme.greenPale,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CerebroTheme.olive, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: CerebroTheme.olive),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_selectedAffiliation!,
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: CerebroTheme.oliveDark)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Degree level selector (university/college only)
        if (showDegreeLevel) ...[
          _formLabel('Level of Study'),
          const SizedBox(height: 8),
          Row(
            children: [
              _degreeLevelChip('undergraduate', 'Undergraduate'),
              const SizedBox(width: 8),
              _degreeLevelChip('masters', 'Masters'),
              const SizedBox(width: 8),
              _degreeLevelChip('phd', 'PhD / Doctorate'),
            ],
          ),
          const SizedBox(height: 14),
        ],

        _formLabel(courseLabel),
        const SizedBox(height: 5),
        _formInput(_courseController, courseHint),
        const SizedBox(height: 16),

        _formLabel('Year / Grade'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(yearOptions.length, (i) {
            final sel = _yearOfStudy == i + 1;
            return GestureDetector(
              onTap: () => setState(() {
                _yearOfStudy = i + 1;
                _suggestionsLoaded = false;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? CerebroTheme.pinkLight : const Color(0xFFFEFDFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CerebroTheme.text1, width: 2.5),
                  boxShadow: sel
                      ? [const BoxShadow(color: CerebroTheme.text1, offset: Offset(3, 3), blurRadius: 0)]
                      : [],
                ),
                child: Text(yearOptions[i],
                  style: GoogleFonts.gaegu(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CerebroTheme.text1,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _degreeLevelChip(String key, String label) {
    final sel = _degreeLevel == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _degreeLevel = key;
          _yearOfStudy = 1;
          _suggestionsLoaded = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? CerebroTheme.pinkLight : const Color(0xFFFEFDFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CerebroTheme.text1, width: 2.5),
            boxShadow: sel
                ? [const BoxShadow(color: CerebroTheme.text1, offset: Offset(3, 3), blurRadius: 0)]
                : [],
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: CerebroTheme.text1,
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getYearOptions() {
    switch (_institutionType) {
      case 'school':
        return ['Year 7', 'Year 8', 'Year 9', 'Year 10', 'Year 11', 'Year 12'];
      case 'sixth_form':
        return ['Year 12 / AS', 'Year 13 / A2'];
      case 'college':
      case 'university':
        // Dynamic based on degree level
        switch (_degreeLevel) {
          case 'masters':
            return ['1st Year', '2nd Year'];
          case 'phd':
            return ['1st Year', '2nd Year', '3rd Year', '4th Year'];
          case 'undergraduate':
          default:
            return ['1st Year', '2nd Year', '3rd Year', '4th Year'];
        }
      default:
        return ['Year 1', 'Year 2', 'Year 3', 'Year 4'];
    }
  }

  //  STEP 3: Subjects (AI Suggestions + Custom)
  Widget _step3Subjects() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI suggestions section
        if (_loadingSuggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: CerebroTheme.olive),
                ),
                const SizedBox(width: 10),
                Text('Finding subjects for you...',
                  style: GoogleFonts.gaegu(
                    fontSize: 17, fontWeight: FontWeight.w700, color: CerebroTheme.text2,
                  ),
                ),
              ],
            ),
          )
        else if (_suggestedSubjects.isNotEmpty) ...[
          Text('Suggested for you',
            style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w700, color: CerebroTheme.olive,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedSubjects.map((s) {
              final alreadyAdded = _subjects.any((sub) => sub.name == s.name);
              return GestureDetector(
                onTap: alreadyAdded
                    ? null
                    : () {
                        if (_subjects.length >= 10) return;
                        setState(() {
                          _subjects.add(_SubjectEntry(name: s.name, color: s.color, code: s.code));
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: alreadyAdded ? CerebroTheme.pinkLight : const Color(0xFFFEFDFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: alreadyAdded ? CerebroTheme.pinkAccent : CerebroTheme.text1,
                      width: 2.5,
                    ),
                    boxShadow: alreadyAdded
                        ? [const BoxShadow(color: CerebroTheme.text1, offset: Offset(3, 3), blurRadius: 0)]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (alreadyAdded)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.check, size: 14, color: CerebroTheme.text1),
                        ),
                      Text(s.name,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CerebroTheme.text1,
                        ),
                      ),
                      if (s.code != null) ...[
                        const SizedBox(width: 6),
                        Text(s.code!,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: CerebroTheme.text3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 1.5,
            color: CerebroTheme.dividerGreen,
          ),
          const SizedBox(height: 12),
        ],

        // Custom add section with search
        Text("Search & add subjects",
          style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: CerebroTheme.text2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _formInput(_subjectNameController, 'Type to search subjects...',
                  onSubmit: (_) => _addSubject(),
                  onChanged: (v) {
                    _subjectSearchDebounce?.cancel();
                    _subjectSearchDebounce = Timer(const Duration(milliseconds: 500), () {
                      _searchSubjects(v);
                    });
                  }),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _colorIdx = (_colorIdx + 1) % _subjectColors.length),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _parseColor(_subjectColors[_colorIdx]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CerebroTheme.text1, width: 2.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addSubject,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: CerebroTheme.olive,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CerebroTheme.text1, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: CerebroTheme.text1, offset: Offset(3, 3), blurRadius: 0),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),

        // Subject search results dropdown
        if (_searchingSubjects)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: CerebroTheme.olive)),
                const SizedBox(width: 8),
                Text('Searching modules...', style: GoogleFonts.nunito(fontSize: 13, color: CerebroTheme.text3)),
              ],
            ),
          )
        else if (_subjectSearchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CerebroTheme.text1, width: 2),
              boxShadow: const [BoxShadow(color: CerebroTheme.text1, offset: Offset(3, 3), blurRadius: 0)],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _subjectSearchResults.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: CerebroTheme.dividerGreen),
              itemBuilder: (ctx, i) {
                final sr = _subjectSearchResults[i];
                final alreadyAdded = _subjects.any((s) => s.name == sr.name);
                return InkWell(
                  onTap: alreadyAdded ? null : () {
                    if (_subjects.length >= 10) return;
                    setState(() {
                      _subjects.add(_SubjectEntry(
                        name: sr.name,
                        code: sr.code,
                        color: _subjectColors[_colorIdx],
                      ));
                      _colorIdx = (_colorIdx + 1) % _subjectColors.length;
                      _subjectNameController.clear();
                      _subjectSearchResults = [];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(sr.name,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: alreadyAdded ? CerebroTheme.text3 : CerebroTheme.text1,
                            ),
                          ),
                        ),
                        if (sr.code != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CerebroTheme.greenPale,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: CerebroTheme.dividerGreen, width: 1),
                            ),
                            child: Text(sr.code!,
                              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: CerebroTheme.olive)),
                          ),
                        if (alreadyAdded)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.check_circle, size: 16, color: CerebroTheme.olive),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 10),

        // Added subjects
        if (_subjects.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_subjects.length, (i) {
              final s = _subjects[i];
              final c = _parseColor(s.color);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c, width: 2.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.name,
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: CerebroTheme.text1),
                    ),
                    if (s.code != null) ...[
                      const SizedBox(width: 4),
                      Text('(${s.code})',
                        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w500, color: CerebroTheme.text3),
                      ),
                    ],
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () => _removeSubject(i),
                      child: Text('x',
                        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: CerebroTheme.text1.withOpacity(0.6)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

        const SizedBox(height: 6),
        Text('${_subjects.length}/10 subjects added',
          style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: CerebroTheme.text3),
        ),
      ],
    );
  }

  //  STEP 4: Goals & Study Time
  double _recommendedStudyHours() {
    switch (_institutionType) {
      case 'school':
        return 1.5;  // GCSE / secondary students
      case 'sixth_form':
        return 3.0;  // A-Level students need more independent study
      case 'college':
        if (_degreeLevel == 'masters') return 4.0;
        if (_degreeLevel == 'phd') return 5.0;
        return 2.5;  // Diploma / foundation
      case 'university':
        if (_degreeLevel == 'masters') return 4.0;
        if (_degreeLevel == 'phd') return 5.0;
        return 3.0;  // Undergraduate
      default:
        return 2.5;
    }
  }

  String _studyRecommendationText() {
    switch (_institutionType) {
      case 'school':
        return 'For secondary school students, 1-2 hours of focused study per day is a solid start alongside homework~';
      case 'sixth_form':
        return 'A-Level students typically need 3-4 hours of independent study daily to stay on top of their subjects~';
      case 'college':
        if (_degreeLevel == 'masters') return 'Masters students usually benefit from 4-5 hours of daily study including research and reading~';
        if (_degreeLevel == 'phd') return 'PhD research demands 5-6 hours of focused work daily — but balance is key!';
        return 'College students do well with 2-3 hours of focused study alongside coursework~';
      case 'university':
        if (_degreeLevel == 'masters') return 'Masters students usually benefit from 4-5 hours of daily study including research and reading~';
        if (_degreeLevel == 'phd') return 'PhD research demands 5-6 hours of focused work daily — but balance is key!';
        return 'Undergrad students typically aim for 3-4 hours of self-study per day outside lectures~';
      default:
        return 'We recommend starting with 2-3 hours and adjusting as you go~';
    }
  }

  Widget _step4StudyTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily study target',
          style: GoogleFonts.gaegu(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CerebroTheme.text2,
          ),
        ),
        const SizedBox(height: 4),
        // Slider value
        Center(
          child: Text(
            '${_dailyStudyHours.toStringAsFixed(_dailyStudyHours % 1 == 0 ? 0 : 1)} hours',
            style: const TextStyle(
              fontFamily: 'Bitroad',
              fontSize: 26,
              color: CerebroTheme.text1,
            ),
          ),
        ),
        // Slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: CerebroTheme.olive,
            inactiveTrackColor: CerebroTheme.inputBorder,
            thumbColor: CerebroTheme.pinkAccent,
            overlayColor: CerebroTheme.pinkAccent.withOpacity(0.2),
            trackHeight: 10,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
          ),
          child: Slider(
            value: _dailyStudyHours,
            min: 0.5,
            max: 8,
            divisions: 15,
            onChanged: (v) => setState(() => _dailyStudyHours = v),
          ),
        ),
        const SizedBox(height: 8),
        // Personalised recommendation
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: CerebroTheme.greenPale,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CerebroTheme.dividerGreen, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 8),
                child: Icon(Icons.lightbulb_outline_rounded, size: 18, color: CerebroTheme.olive),
              ),
              Expanded(
                child: Text(
                  _studyRecommendationText(),
                  style: GoogleFonts.gaegu(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CerebroTheme.text2,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //  STEP 5: Sleep Schedule
  Widget _step5Sleep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _timeCard(
                label: 'Bedtime',
                value: _formatTime24(_bedtime),
                onTap: () => _pickTime(isBedtime: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _timeCard(
                label: 'Wake Up',
                value: _formatTime24(_wakeTime),
                onTap: () => _pickTime(isBedtime: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Info box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: CerebroTheme.greenPale,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CerebroTheme.dividerGreen, width: 2),
          ),
          child: Text(
            "That's about ${_calcSleepHours()} hours of sleep~",
            textAlign: TextAlign.center,
            style: GoogleFonts.gaegu(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: CerebroTheme.text2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeCard({required String label, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFDFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CerebroTheme.text1, width: 2.5),
        ),
        child: Column(
          children: [
            Text(label.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: CerebroTheme.text3,
              ),
            ),
            const SizedBox(height: 3),
            Text(value,
              style: const TextStyle(
                fontFamily: 'Bitroad',
                fontSize: 22,
                color: CerebroTheme.text1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime24(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  //  STEP 6: Daily Goals — picks seed today's quests
  //  (Selection capped at _maxDailyGoals; already-full taps show a snack)
  Widget _step6DailyGoals() {
    final atCap = _selectedHabits.length >= _maxDailyGoals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${_selectedHabits.length} / $_maxDailyGoals picked',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: atCap ? CerebroTheme.olive : CerebroTheme.text3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _habitItems.map((h) {
            final sel = _selectedHabits.contains(h.label);
            final disabled = !sel && atCap;
            return Opacity(
              opacity: disabled ? 0.5 : 1.0,
              child: _chip(
                label: h.label,
                selected: sel,
                accentColor: h.color,
                onTap: () {
                  if (sel) {
                    setState(() => _selectedHabits.remove(h.label));
                  } else if (!atCap) {
                    setState(() => _selectedHabits.add(h.label));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('You can pick up to $_maxDailyGoals daily goals~',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      backgroundColor: CerebroTheme.olive,
                      duration: const Duration(seconds: 1),
                    ));
                  }
                },
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: CerebroTheme.greenPale,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CerebroTheme.dividerGreen, width: 2),
          ),
          child: Text(
            'Your picks become today\'s quests — each checked off earns 10 XP.',
            textAlign: TextAlign.center,
            style: GoogleFonts.gaegu(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: CerebroTheme.text2,
            ),
          ),
        ),
      ],
    );
  }

  //  STEP 7: Medical Conditions — populates users.medical_conditions.
  //  Symptom screen + Insights both read these back.
  Widget _step7Conditions() {
    // Empty query = show all presets in the top chip grid, no suggestions.
    // Non-empty query = filter chips to matches + show autocomplete
    // row with unselected extended presets that match the query.
    final q = _conditionQuery.trim().toLowerCase();
    final visiblePresets = q.isEmpty
        ? _conditionPresets
        : _conditionPresets.where((c) => c.toLowerCase().contains(q)).toList();
    final autocompleteMatches = q.isEmpty
        ? const <String>[]
        : _conditionAutocomplete
            .where((c) =>
                c.toLowerCase().contains(q) &&
                !_selectedConditions.contains(c) &&
                !_conditionPresets.contains(c))
            .take(8)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tap any that apply, or add your own',
          style: GoogleFonts.gaegu(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: CerebroTheme.text3,
          ),
        ),
        const SizedBox(height: 10),
        // Preset chips (filtered when query active)
        if (visiblePresets.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visiblePresets.map((c) {
              final sel = _selectedConditions.contains(c);
              return _chip(
                label: c,
                selected: sel,
                onTap: () => setState(() {
                  if (sel) _selectedConditions.remove(c);
                  else _selectedConditions.add(c);
                }),
              );
            }).toList(),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('No presets match "$_conditionQuery" — add a custom one below.',
              style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: CerebroTheme.text3,
              ),
            ),
          ),
        const SizedBox(height: 14),
        // Custom condition input
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _formInput(
                _conditionInputController,
                'Add another (e.g. "Chronic fatigue")',
                onSubmit: (_) => _addCustomCondition(),
                onChanged: (v) => setState(() => _conditionQuery = v),
              ),
            ),
            const SizedBox(width: 10),
            _GameBtn(
              label: 'ADD',
              color: CerebroTheme.pinkAccent,
              onTap: _addCustomCondition,
            ),
          ],
        ),
        // Renders as soon as the user types — taps add directly to the
        // selected set without them having to hit ADD. Purely additive:
        // the free-form input still works for truly custom entries.
        if (autocompleteMatches.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Did you mean…',
            style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: CerebroTheme.text3, letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: autocompleteMatches.map((c) {
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedConditions.add(c);
                  _conditionInputController.clear();
                  _conditionQuery = '';
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CerebroTheme.creamWarm,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CerebroTheme.text1, width: 2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded, size: 14, color: CerebroTheme.text1),
                    const SizedBox(width: 4),
                    Text(c, style: GoogleFonts.gaegu(
                      fontSize: 15, fontWeight: FontWeight.w700, color: CerebroTheme.text1)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
        // Chosen custom conditions row (anything not in presets)
        if (_selectedConditions.any((c) => !_conditionPresets.contains(c))) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _selectedConditions
              .where((c) => !_conditionPresets.contains(c))
              .map((c) => GestureDetector(
                onTap: () => setState(() => _selectedConditions.remove(c)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CerebroTheme.pinkLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CerebroTheme.text1, width: 2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(c, style: GoogleFonts.gaegu(
                      fontSize: 15, fontWeight: FontWeight.w700, color: CerebroTheme.text1)),
                    const SizedBox(width: 6),
                    const Icon(Icons.close_rounded, size: 14, color: CerebroTheme.text1),
                  ]),
                ),
              ))
              .toList(),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: CerebroTheme.greenPale,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CerebroTheme.dividerGreen, width: 2),
          ),
          child: Text(
            'Cerebro uses these to personalise your symptom picker & insights — never shared.',
            textAlign: TextAlign.center,
            style: GoogleFonts.gaegu(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CerebroTheme.text2,
            ),
          ),
        ),
      ],
    );
  }

  void _addCustomCondition() {
    final raw = _conditionInputController.text.trim();
    if (raw.isEmpty) return;
    // Title-case each word so "migraine" / "MIGRAINE" dedupe against "Migraine"
    final norm = raw.split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
    setState(() {
      _selectedConditions.add(norm);
      _conditionInputController.clear();
      _conditionQuery = '';
    });
  }

  //  STEP 8: Medications — each row becomes a real medications table row.
  Widget _step8Medications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add any medications you take regularly — skip if none',
          style: GoogleFonts.gaegu(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: CerebroTheme.text3,
          ),
        ),
        const SizedBox(height: 12),
        // Existing medication rows
        if (_medications.isNotEmpty) ...[
          ..._medications.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEFDFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CerebroTheme.text1, width: 2),
              ),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: CerebroTheme.pinkLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CerebroTheme.text1, width: 1.5),
                  ),
                  child: const Icon(Icons.medication_rounded, size: 18, color: CerebroTheme.text1),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: GoogleFonts.gaegu(
                      fontSize: 16, fontWeight: FontWeight.w700, color: CerebroTheme.text1)),
                    Text('${m.dosage.isEmpty ? 'Dosage not set' : m.dosage} • ${m.frequency}${m.frequency == 'daily' ? ' @ ${_formatTime24(m.time)}' : ''}',
                      style: GoogleFonts.nunito(
                        fontSize: 12, fontWeight: FontWeight.w600, color: CerebroTheme.text3)),
                  ],
                )),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: CerebroTheme.text3),
                  onPressed: () => setState(() => _medications.removeAt(i)),
                ),
              ]),
            );
          }),
          const SizedBox(height: 4),
        ],
        // + Add button
        GestureDetector(
          onTap: _showAddMedicationSheet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: CerebroTheme.creamWarm,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CerebroTheme.text1, width: 2, style: BorderStyle.solid),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.add_rounded, size: 20, color: CerebroTheme.text1),
              const SizedBox(width: 6),
              Text(_medications.isEmpty ? 'Add a medication' : 'Add another',
                style: const TextStyle(
                  fontFamily: 'Bitroad', fontSize: 16, color: CerebroTheme.text1)),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddMedicationSheet() async {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    String freq = 'daily';
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(
                top: BorderSide(color: CerebroTheme.text1, width: 3),
                left: BorderSide(color: CerebroTheme.text1, width: 3),
                right: BorderSide(color: CerebroTheme.text1, width: 3),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: CerebroTheme.text3.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
                const SizedBox(height: 14),
                const Text('Add Medication',
                  style: TextStyle(
                    fontFamily: 'Bitroad', fontSize: 22, color: CerebroTheme.text1)),
                const SizedBox(height: 12),
                _formLabel('Name'),
                const SizedBox(height: 6),
                _formInput(nameCtrl, 'e.g. Sertraline, Ibuprofen'),
                const SizedBox(height: 12),
                _formLabel('Dosage (optional)'),
                const SizedBox(height: 6),
                _formInput(doseCtrl, "e.g. 50mg — leave blank if you're not sure"),
                const SizedBox(height: 12),
                _formLabel('Frequency'),
                const SizedBox(height: 6),
                Row(children: [
                  for (final f in ['daily', 'weekly', 'as_needed']) ...[
                    Expanded(child: GestureDetector(
                      onTap: () => setSheet(() => freq = f),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: freq == f ? CerebroTheme.pinkLight : const Color(0xFFFEFDFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CerebroTheme.text1, width: 2),
                        ),
                        child: Text(
                          f == 'as_needed' ? 'As needed' : f[0].toUpperCase() + f.substring(1),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.gaegu(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: CerebroTheme.text1),
                        ),
                      ),
                    )),
                  ],
                ]),
                if (freq == 'daily') ...[
                  const SizedBox(height: 12),
                  _formLabel('Reminder time'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx, initialTime: time);
                      if (picked != null) setSheet(() => time = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEFDFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CerebroTheme.text1, width: 2),
                      ),
                      child: Row(children: [
                        const Icon(Icons.access_time_rounded, size: 18, color: CerebroTheme.text1),
                        const SizedBox(width: 10),
                        Text(_formatTime24(time),
                          style: const TextStyle(
                            fontFamily: 'Bitroad', fontSize: 18, color: CerebroTheme.text1)),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _GameBtn(
                    label: 'CANCEL',
                    color: Colors.white,
                    textColor: CerebroTheme.text1,
                    onTap: () => Navigator.pop(ctx),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _GameBtn(
                    label: 'SAVE',
                    color: CerebroTheme.olive,
                    onTap: () {
                      final n = nameCtrl.text.trim();
                      final d = doseCtrl.text.trim();
                      // Dosage is optional — many users take meds without
                      // remembering the exact mg. Only the name is required.
                      if (n.isEmpty) return;
                      setState(() => _medications.add(_MedicationEntry(
                        name: n,
                        dosage: d,
                        frequency: freq,
                        time: time,
                      )));
                      Navigator.pop(ctx);
                    },
                  )),
                ]),
              ],
            ),
          ),
        );
      }),
    );
  }

  //  STEP 9: Mood
  Widget _step9Mood() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _optionGrid(
          count: _moodItems.length,
          columns: 4,
          builder: (i) {
            final m = _moodItems[i];
            final sel = _selectedMood == i;
            return _moodCard(
              label: m.label,
              color: m.color,
              selected: sel,
              onTap: () => setState(() => _selectedMood = i),
            );
          },
        ),
        const SizedBox(height: 6),
        Text('Your companion will match your vibe~',
          style: GoogleFonts.gaegu(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: CerebroTheme.text3,
          ),
        ),
      ],
    );
  }

  //  SHARED FORM WIDGETS

  Widget _formLabel(String text) {
    return Text(text,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: CerebroTheme.text2,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _formInput(TextEditingController ctrl, String placeholder,
      {ValueChanged<String>? onSubmit, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      onSubmitted: onSubmit,
      onChanged: onChanged,
      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w500, color: CerebroTheme.text1),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: GoogleFonts.nunito(fontSize: 15, color: CerebroTheme.text3, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: const Color(0xFFFEFDFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CerebroTheme.text1, width: 2.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CerebroTheme.text1, width: 2.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CerebroTheme.pinkAccent, width: 2.5),
        ),
      ),
    );
  }

  Widget _optionGrid({required int count, required int columns, required Widget Function(int) builder}) {
    final rows = (count / columns).ceil();
    return Column(
      children: List.generate(rows, (r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: List.generate(columns, (c) {
              final i = r * columns + c;
              if (i >= count) return const Expanded(child: SizedBox());
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c < columns - 1 ? 10 : 0),
                  child: builder(i),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _optCard({required String label, required String icon, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? CerebroTheme.pinkLight : const Color(0xFFFEFDFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CerebroTheme.text1, width: 2.5),
          boxShadow: selected
              ? [const BoxShadow(color: CerebroTheme.text1, offset: Offset(4, 4), blurRadius: 0)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon,
              style: const TextStyle(
                fontFamily: 'Bitroad',
                fontSize: 20,
                color: CerebroTheme.text1,
              ),
            ),
            const SizedBox(height: 3),
            Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.gaegu(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CerebroTheme.text1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({required String label, required bool selected, Color? accentColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? CerebroTheme.pinkLight : const Color(0xFFFEFDFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CerebroTheme.text1, width: 2.5),
          boxShadow: selected
              ? [const BoxShadow(color: CerebroTheme.text1, offset: Offset(3, 3), blurRadius: 0)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accentColor != null) ...[
              Container(
                width: 4,
                height: 16,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            Text(label,
              style: GoogleFonts.gaegu(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: selected ? CerebroTheme.text1 : CerebroTheme.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moodCard({required String label, required Color color, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? CerebroTheme.greenPale : const Color(0xFFFEFDFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CerebroTheme.text1, width: 2.5),
          boxShadow: selected
              ? [const BoxShadow(color: CerebroTheme.text1, offset: Offset(4, 4), blurRadius: 0)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: CerebroTheme.text1, width: 2.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.gaegu(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CerebroTheme.text1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

//  CREAM DIAMOND PATTERN (matches setup.html body background)
class _CreamDiamondPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CreamDiamondPainter(),
      size: Size.infinite,
    );
  }
}

class _CreamDiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Matches CSS: linear-gradient(135deg, #e4bc8312 25%, transparent...)
    final paint = Paint()..color = const Color(0x12E4BC83);
    const s = 20.0;
    final half = s / 2;

    for (double y = -s; y < size.height + s; y += s) {
      for (double x = -s; x < size.width + s; x += s) {
        final p1 = Path()
          ..moveTo(x, y + s * 0.25)
          ..lineTo(x + s * 0.25, y)
          ..lineTo(x, y)
          ..close();
        final p2 = Path()
          ..moveTo(x + s * 0.75, y + s)
          ..lineTo(x + s, y + s * 0.75)
          ..lineTo(x + s, y + s)
          ..close();
        canvas.drawPath(p1, paint);
        canvas.drawPath(p2, paint);

        final ox = x + half;
        final oy = y + half;
        final q1 = Path()
          ..moveTo(ox, oy + s * 0.25)
          ..lineTo(ox + s * 0.25, oy)
          ..lineTo(ox, oy)
          ..close();
        final q2 = Path()
          ..moveTo(ox + s * 0.75, oy + s)
          ..lineTo(ox + s, oy + s * 0.75)
          ..lineTo(ox + s, oy + s)
          ..close();
        canvas.drawPath(q1, paint);
        canvas.drawPath(q2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//  GAME BUTTON (matches HTML .btn)
class _GameBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool iconFirst;
  final Color color;
  final Color textColor;
  final Color shadowColor;
  final VoidCallback? onTap;
  final bool isLoading;

  const _GameBtn({
    required this.label,
    this.icon,
    this.iconFirst = false,
    required this.color,
    this.textColor = Colors.white,
    this.shadowColor = CerebroTheme.text1,
    this.onTap,
    this.isLoading = false,
  });

  @override
  State<_GameBtn> createState() => _GameBtnState();
}

class _GameBtnState extends State<_GameBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        transform: Matrix4.translationValues(
            _p ? 2 : 0, _p ? 2 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CerebroTheme.text1, width: 2.5),
          boxShadow: [
            if (!_p)
              BoxShadow(
                color: widget.shadowColor,
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
          ],
        ),
        child: widget.isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.iconFirst && widget.icon != null) ...[
                    Icon(widget.icon, color: widget.textColor, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Text(widget.label,
                    style: TextStyle(
                      fontFamily: 'Bitroad',
                      fontSize: 14,
                      color: widget.textColor,
                    ),
                  ),
                  if (!widget.iconFirst && widget.icon != null) ...[
                    const SizedBox(width: 6),
                    Icon(widget.icon, color: widget.textColor, size: 16),
                  ],
                ],
              ),
      ),
    );
  }
}

//  DATA CLASSES
class _SubjectEntry {
  final String name;
  final String color;
  final String? code;
  _SubjectEntry({required this.name, required this.color, this.code});
}

class _SuggestedSubject {
  final String name;
  final String? code;
  final String color;
  _SuggestedSubject({required this.name, this.code, required this.color});
}

class _HabitDef {
  final String label;
  final Color color;
  const _HabitDef(this.label, this.color);
}

class _MoodDef {
  final String label;
  final Color color;
  const _MoodDef(this.label, this.color);
}

class _SubjectSearchResult {
  final String name;
  final String? code;
  _SubjectSearchResult({required this.name, this.code});
}

// Wizard-level medication draft. On submit we POST one of these per row to
// /health/medications, which converts it into a real Medication table row
// (days_of_week defaults to all 7, reminder_enabled stays on).
class _MedicationEntry {
  final String name;
  final String dosage;
  final String frequency; // daily, weekly, as_needed
  final TimeOfDay time;
  _MedicationEntry({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
  });
}
