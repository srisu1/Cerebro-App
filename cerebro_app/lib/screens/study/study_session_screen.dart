// Pomodoro study session screen with ambient audio, notes, and past sessions

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';
import 'package:cerebro_app/providers/study_session_provider.dart';
import 'package:cerebro_app/screens/study/study_tab.dart';

const _ombre1  = Color(0xFFFFFBF7);
const _ombre2  = Color(0xFFFFF8F3);
const _ombre3  = Color(0xFFFFF3EF);
const _ombre4  = Color(0xFFFEEDE9);
const _pawClr  = Color(0xFFF8BCD0);

const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);
const _cardFill = Color(0xFFFFF8F4);
const _panelBg  = Color(0xFFFFF6EE);

const _pinkHdr  = Color(0xFFE8B0A8);
const _pinkLt   = Color(0xFFF0C0B8);
const _greenHdr = Color(0xFFA8D5A3);
const _greenLt  = Color(0xFFC2E8BC);
const _greenDk  = Color(0xFF88B883);
const _goldHdr  = Color(0xFFF0D878);
const _goldLt   = Color(0xFFFFF0C0);
const _goldDk   = Color(0xFFD4B850);
const _coralHdr = Color(0xFFF0A898);
const _coralLt  = Color(0xFFF8C0B0);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _purpleDk = Color(0xFFAA88C0);
const _skyHdr   = Color(0xFF9DD4F0);
const _skyLt    = Color(0xFFC0E0F8);
const _skyDk    = Color(0xFF6BB8E0);

// Sage/olive — user's requested primary palette (matches study_tab _olive/_oliveDk)
const _olive    = Color(0xFF98A869);
const _oliveLt  = Color(0xFFB8C87A);
const _oliveDk  = Color(0xFF58772F);
const _oliveBg  = Color(0xFFF9FDEC); // soft cream-green tint

// Body softer ink — matches dashboard_tab
const _inkSoft  = Color(0xFF9A8070);

//    from the user's provided palette. The primary sage (#98A869)
//    and deep sage (#58772F) alias to `_olive` / `_oliveDk` above,
//    keeping existing call sites untouched while giving new layout
//    code intent-revealing names.
const _sagePale   = Color(0xFFF9FDEC); // soft pale green — card wash
const _pinkSoft   = Color(0xFFFFD5F5); // details card wash
const _pinkDeep   = Color(0xFFFEA9D3); // details accent
const _skySoft    = Color(0xFFDDF6FF); // ambience card wash
const _creamSoft  = Color(0xFFFDEFDB); // quote card wash + warm cream
const _coralSoft  = Color(0xFFF7AEAE); // focused session accent
const _tanWarm    = Color(0xFFE4BC83); // xp / gold pill
const _orangeWarm = Color(0xFFFFBC5C); // streak pill
// ignore: unused_element
const _redAccent  = Color(0xFFEF6262); // reserved — alerts / emphasis

enum _Phase { setup, running, paused, onBreak, completed }

const _quotes = [
  '"The secret of getting ahead is getting started." — Mark Twain',
  '"Small daily improvements lead to stunning results."',
  '"Focus on progress, not perfection."',
  '"Every study session is a step toward your goals."',
  '"You don\'t have to be great to start, but you have to start to be great."',
  '"Your brain is a muscle. Train it daily."',
  '"The beautiful thing about learning is no one can take it away."',
  '"It always seems impossible until it\'s done." — Nelson Mandela',
];

const _ambientAssets = <String, String>{
  'rain':  'assets/audio/rain.wav',
  'lofi':  'assets/audio/lofi.wav',
  'cafe':  'assets/audio/cafe.wav',
  'ocean': 'assets/audio/ocean.wav',
  'fire':  'assets/audio/fire.wav',
  'birds': 'assets/audio/birds.wav',
};

String _pdfSafe(String text) => text
    .replaceAll('\u2014', '--')   // em-dash
    .replaceAll('\u2013', '-')    // en-dash
    .replaceAll('\u2022', '*')    // bullet
    .replaceAll('\u2018', "'")    // left single quote
    .replaceAll('\u2019', "'")    // right single quote
    .replaceAll('\u201C', '"')    // left double quote
    .replaceAll('\u201D', '"')    // right double quote
    .replaceAll('\u2026', '...')  // ellipsis
    .replaceAll('\u00A0', ' ');   // non-breaking space

const _ambientUrls = <String, String>{
  'rain':  'https://www.orangefreesounds.com/wp-content/uploads/2020/07/Heavy-rain-white-noise-loop.mp3',
  'lofi':  'https://cdn.pixabay.com/audio/2024/11/02/audio_b932be5c36.mp3',
  'cafe':  'https://cdn.pixabay.com/audio/2022/02/07/audio_d1718ab41b.mp3',
  'ocean': 'https://cdn.pixabay.com/audio/2022/06/07/audio_b9bd4170e4.mp3',
  'fire':  'https://cdn.pixabay.com/audio/2022/12/20/audio_4add64cd01.mp3',
  'birds': 'https://cdn.pixabay.com/audio/2022/03/09/audio_c610232c26.mp3',
};

//  MAIN SCREEN
class StudySessionScreen extends ConsumerStatefulWidget {
  /// When true, the screen auto-opens the Past Sessions bottom sheet on
  /// first frame — used by the Study Hub's "History" entry point so users
  /// can reach their past sessions even when a live session is running
  /// (otherwise the sheet is only reachable via the setup phase, which is
  /// not rendered once a session has started).
  final bool showPastOnOpen;
  const StudySessionScreen({Key? key, this.showPastOnOpen = false})
      : super(key: key);
  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen>
    with TickerProviderStateMixin {

  String _sessionType = 'focused';
  int _durationMin = 25;
  bool _customDuration = false;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _selectedSubjectColor;
  final _titleCtrl = TextEditingController();

  List<Map<String, dynamic>> _subjects = [];
  bool _subjectsLoading = true;

  //    the Session Wrapped topic picker so users toggle chips instead of
  //    hand-typing the same tags every session).
  List<Map<String, dynamic>> _subjectTopics = [];
  bool _subjectTopicsLoading = false;
  String? _lastLoadedTopicsSubject; // cache key to avoid re-fetching

  _Phase _phase = _Phase.setup;
  Timer? _ticker;
  int _remainSec = 0;
  int _totalStudiedSec = 0;
  int _pomodoroCount = 0;
  bool _isBreakPhase = false;
  DateTime? _startTime;
  DateTime? _endTime;
  int _distractionCount = 0;

  final _notesCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  List<String> _topics = [];
  int _focusScore = 70;
  bool _bold = false;
  bool _italic = false;

  String _ambientSound = 'none';
  AudioPlayer? _audioPlayer;
  bool _audioLoading = false;

  List<Map<String, dynamic>> _pastSessions = [];
  bool _pastLoading = false;

  int _xpEarned = 0;
  bool _saving = false;
  bool _saved = false;

  int _streakCount = 0;
  String? _moodTag;

  late AnimationController _enterCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _breatheCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _xpCtrl;
  late String _quote;

  bool _showed5min = false;
  bool _showed15min = false;
  bool _showedHalfway = false;
  String? _milestoneMsg;
  Timer? _milestoneTimer;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _breatheCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4000))
      ..repeat(reverse: true);
    _particleCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
    _xpCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
    _quote = _quotes[math.Random().nextInt(_quotes.length)];
    _fetchSubjects();
    _fetchPastSessions();
    _loadStreak();
    // Adopt any existing live session from the global provider — if the user
    // started one from the dashboard hero, we want to land in that session's
    // running state immediately instead of the setup picker.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _adoptGlobalSession();
      // Auto-open the Past Sessions sheet if this screen was opened via the
      // Study Hub's "History" entry point. Critically, we AWAIT the fetch
      // before showing the sheet — `_PastSessionsSheet` captures the list
      // reference at construction time, so opening it before the fetch
      // completes would leave the sheet stuck on "No sessions yet" even
      // after the fetch populates our local state.
      if (widget.showPastOnOpen) {
        // The fetch was kicked off synchronously in initState above; wait
        // for it to settle before opening the sheet so the first render
        // shows the real data instead of the empty initial list.
        await _fetchPastSessions();
        if (!mounted) return;
        _showPastSessions();
      }
    });
  }

  /// If `studySessionProvider` reports a live session, skip the setup UI and
  /// jump straight into `_Phase.running` (or `_Phase.paused` if paused),
  /// seeding our local timer fields from the provider's server-computed
  /// elapsed time. This is what makes the "start a session on dashboard
  /// hero → land in full session screen already running" flow work.
  ///
  /// If the provider has `endRequested == true`, we jump straight to the
  /// Wrapped / completion phase instead — this is how the mini session bar
  /// and the Study tab hero's Stop button route users into the rating UI
  /// rather than quietly finalizing the row.
  void _adoptGlobalSession() {
    if (!mounted) return;
    final s = ref.read(studySessionProvider);
    if (!s.isLive) return;
    // Already past setup — don't clobber.
    if (_phase != _Phase.setup) return;

    // Seed local fields from the server-authoritative snapshot.
    _sessionType = s.sessionType;
    _durationMin = s.plannedDurationMinutes;
    _selectedSubjectId = s.subjectId;
    _selectedSubjectName = s.subjectName;
    if (s.title != null && _titleCtrl.text.isEmpty) {
      _titleCtrl.text = s.title!;
    }
    _startTime = s.startTime;
    _totalStudiedSec = s.elapsedSeconds;
    _distractionCount = s.distractions;
    _remainSec = (_durationMin * 60 - _totalStudiedSec)
        .clamp(0, _durationMin * 60);
    _isBreakPhase = false;
    _showed5min = _totalStudiedSec >= 300;
    _showed15min = _totalStudiedSec >= 900;
    _showedHalfway = _totalStudiedSec >= (_durationMin * 30);

    // "Stop" pressed from mini bar or hero → land directly on Wrapped.
    if (s.endRequested) {
      setState(() {
        _phase = _Phase.completed;
        _endTime = DateTime.now();
        // Seed the slider with the max allowed focus for this session's
        // distraction count so the default is not nonsensically high.
        _focusScore = _focusScore.clamp(1, _maxFocusForDistractions());
      });
      // Clear the flag so rebuilds don't re-trigger this branch.
      ref.read(studySessionProvider.notifier).consumeEndRequest();
      if (_selectedSubjectId != null && _subjectTopics.isEmpty) {
        _fetchSubjectTopics();
      }
      _enterCtrl.reset();
      _enterCtrl.forward();
      return;
    }

    setState(() {
      _phase = s.phase == SessionPhase.paused
          ? _Phase.paused
          : _Phase.running;
    });
    _enterCtrl.reset();
    _enterCtrl.forward();
    // Only resume the local tick when actually running; paused sessions
    // stay frozen until the user explicitly resumes.
    if (s.phase == SessionPhase.running) {
      _beginTick();
    }
  }

  /// Max focus score the user is allowed to claim given how many times
  /// attention drifted during this session.
  ///
  ///   0  distractions → 100
  ///   1              → 90
  ///   2              → 80
  ///   …
  ///   7+             → 30 (floor — we still let them log *something*)
  ///
  /// Per product decision: the session-recap slider is not a place to
  /// rewrite history. If you paused twice and wandered off to Daily once,
  /// you cannot claim "100% focused". Matches the backend's fallback
  /// derivation in /sessions/{id}/end when focus_score is omitted
  /// (max(30, 85 - distractions*10)), but with a slightly more generous
  /// no-distraction ceiling to reward clean runs.
  int _maxFocusForDistractions() {
    final d = (ref.read(studySessionProvider).distractions)
        .clamp(0, 100);
    // Grant a full 100 only when there are zero distractions. After that
    // every distraction shaves 10 points off, floored at 30.
    if (d == 0) return 100;
    return (100 - d * 10).clamp(30, 100);
  }

  /// Surface a brief, non-blocking explainer when the user tries to push
  /// the focus slider past the distraction-imposed cap. Uses a throttled
  /// SnackBar so rapid drags don't flood the screen with duplicates.
  ///
  /// Why a SnackBar (not a dialog): the completion screen is a chained
  /// series of taps — slider → notes → topics → save. A modal would break
  /// that flow. The SnackBar hints, auto-dismisses, and the slider
  /// physically snaps back so the cap is self-evident on the next drag.
  DateTime? _lastCapNudge;
  void _nudgeCapTooltip(int maxFocus, int distractions) {
    final now = DateTime.now();
    if (_lastCapNudge != null &&
        now.difference(_lastCapNudge!).inMilliseconds < 1200) {
      return; // throttle — avoid a snackbar spam during a single drag
    }
    _lastCapNudge = now;
    if (!mounted) return;
    final d = distractions;
    final plural = d == 1 ? 'distraction' : 'distractions';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          'Capped at $maxFocus% — $d $plural this session.',
          style: GoogleFonts.gaegu(
              fontSize: 14, fontWeight: FontWeight.w700, color: _brown),
        ),
        backgroundColor: const Color(0xFFFFE8C9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
  }

  String _todayKey() => DateTime.now().toIso8601String().substring(0, 10);
  String _yesterdayKey() => DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String().substring(0, 10);

  Future<void> _loadStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString('study_streak_last_date') ?? '';
      int streak = prefs.getInt('study_streak_count') ?? 0;
      if (lastDate.isNotEmpty &&
          lastDate != _todayKey() &&
          lastDate != _yesterdayKey()) {
        streak = 0;
      }
      if (mounted) setState(() => _streakCount = streak);
    } catch (_) {}
  }

  Future<void> _bumpStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString('study_streak_last_date') ?? '';
      final today = _todayKey();
      if (lastDate == today) return; // already counted today
      final yesterday = _yesterdayKey();
      final newStreak = lastDate == yesterday ? _streakCount + 1 : 1;
      await prefs.setInt('study_streak_count', newStreak);
      await prefs.setString('study_streak_last_date', today);
      if (mounted) setState(() => _streakCount = newStreak);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _milestoneTimer?.cancel();
    _audioPlayer?.dispose();
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    _breatheCtrl.dispose();
    _particleCtrl.dispose();
    _xpCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSubjects() async {
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get('/study/subjects');
      if (resp.statusCode == 200 && resp.data is List) {
        setState(() {
          _subjects = List<Map<String, dynamic>>.from(resp.data);
          _subjectsLoading = false;
        });
      }
    } catch (_) {
      setState(() => _subjectsLoading = false);
    }
  }

  //    Used by the Session Wrapped completion card to offer
  //    one-tap topic tagging instead of free-text entry.
  Future<void> _fetchSubjectTopics({bool force = false}) async {
    final sid = _selectedSubjectId;
    if (sid == null) {
      setState(() { _subjectTopics = []; _lastLoadedTopicsSubject = null; });
      return;
    }
    if (!force && sid == _lastLoadedTopicsSubject) return; // cached
    if (_subjectTopicsLoading) return;
    setState(() => _subjectTopicsLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get('/study/subjects/$sid/topics');
      if (resp.statusCode == 200 && resp.data is List) {
        if (mounted) {
          setState(() {
            _subjectTopics = List<Map<String, dynamic>>.from(resp.data);
            _lastLoadedTopicsSubject = sid;
          });
        }
      }
    } catch (_) {
      // Silently fail — UI will show a "no topics yet" hint.
    } finally {
      if (mounted) setState(() => _subjectTopicsLoading = false);
    }
  }

  // Historical NOTE: this used to `catch (_) {}` which silently buried any
  // backend error (401, 500, data-shape mismatch), making "past sessions
  // not loading" look like a UI bug. We now log to debugPrint so problems
  // are at least visible in the console. The sheet itself does its own
  // fetch with a visible error UI; this version stays quiet for the
  // background counts shown in the setup-phase rhythm card.
  Future<void> _fetchPastSessions() async {
    if (mounted) setState(() => _pastLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get(
          '/study/sessions', queryParams: {'limit': '50'});
      if (resp.statusCode == 200 && resp.data is List) {
        if (mounted) {
          setState(() =>
              _pastSessions = List<Map<String, dynamic>>.from(resp.data));
        }
      } else {
        debugPrint('[_fetchPastSessions] unexpected shape: '
            'status=${resp.statusCode} dataType=${resp.data.runtimeType}');
      }
    } catch (e, st) {
      debugPrint('[_fetchPastSessions] failed: $e\n$st');
    }
    if (mounted) setState(() => _pastLoading = false);
  }

  Future<void> _playAmbient(String sound) async {
    if (sound == 'none') {
      await _audioPlayer?.stop();
      setState(() => _ambientSound = 'none');
      return;
    }
    setState(() { _ambientSound = sound; _audioLoading = true; });
    try {
      _audioPlayer?.dispose();
      _audioPlayer = AudioPlayer();

      // Try local file first (from app bundle), then asset, then URL
      final assetPath = _ambientAssets[sound];
      bool loaded = false;

      // Try loading as a file from the app bundle directory
      if (assetPath != null) {
        try {
          // just_audio on macOS: use AudioSource.asset for Flutter assets
          await _audioPlayer!.setAudioSource(
            AudioSource.asset(assetPath),
          );
          loaded = true;
        } catch (e1) {
          debugPrint('Asset source failed: $assetPath ($e1)');
          // Try as plain asset path
          try {
            await _audioPlayer!.setAsset(assetPath);
            loaded = true;
          } catch (e2) {
            debugPrint('setAsset also failed: $assetPath ($e2)');
          }
        }
      }

      // Fallback to URL
      if (!loaded) {
        final url = _ambientUrls[sound];
        if (url != null) {
          try {
            await _audioPlayer!.setUrl(url);
            loaded = true;
          } catch (e3) {
            debugPrint('URL fallback also failed: $url ($e3)');
          }
        }
      }

      if (!loaded) {
        throw Exception('Could not load sound: $sound');
      }

      await _audioPlayer!.setLoopMode(LoopMode.one);
      await _audioPlayer!.setVolume(0.5);
      await _audioPlayer!.play();
    } catch (e) {
      debugPrint('Audio error: $e');
      if (mounted) {
        setState(() => _ambientSound = 'none');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load "$sound" sound. Run download_audio.sh to install sounds locally.',
            style: GoogleFonts.nunito(fontSize: 13)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
    if (mounted) setState(() => _audioLoading = false);
  }

  Future<void> _stopAmbient() async {
    await _audioPlayer?.stop();
    setState(() => _ambientSound = 'none');
  }

  //  PAST SESSIONS — with search + filter
  void _showPastSessions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PastSessionsSheet(
        sessions: _pastSessions,
        loading: _pastLoading,
        api: ref.read(apiServiceProvider),
        onRefresh: () async {
          await _fetchPastSessions();
        },
      ),
    );
  }

  //  TIMER LOGIC
  void _startTimer() {
    // If the global provider already has a live session (user started from
    // the hero), don't spin up a second one — adopt instead.
    final global = ref.read(studySessionProvider);
    if (global.isLive) {
      _adoptGlobalSession();
      return;
    }

    _startTime = DateTime.now();
    _remainSec = _durationMin * 60;
    _pomodoroCount = 0;
    _isBreakPhase = false;
    _totalStudiedSec = 0;
    _distractionCount = 0;
    _showed5min = false;
    _showed15min = false;
    _showedHalfway = false;
    setState(() => _phase = _Phase.running);
    _enterCtrl.reset();
    _enterCtrl.forward();
    _beginTick();

    // Persist the session on the backend so the global provider, mini
    // player, dashboard hero, and cross-tab guard all have a row to track.
    // Fire-and-forget: the local tick keeps working even if this fails,
    // and the provider will surface any error via state.error.
    // ignore: discarded_futures
    ref.read(studySessionProvider.notifier).start(
          subjectId: _selectedSubjectId,
          subjectName: _selectedSubjectName,
          title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
          sessionType: _sessionType,
          plannedDurationMinutes: _durationMin,
          topicsCovered: _topics,
        );

    // Start ambient if selected
    if (_ambientSound != 'none') {
      _playAmbient(_ambientSound);
    }
  }

  void _beginTick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainSec > 0) {
        setState(() {
          _remainSec--;
          if (!_isBreakPhase) _totalStudiedSec++;
        });
        // Milestone checks
        if (!_isBreakPhase) {
          if (!_showed5min && _totalStudiedSec == 300) {
            _showMilestone('5 minutes in! Keep going!');
            _showed5min = true;
          } else if (!_showed15min && _totalStudiedSec == 900) {
            _showMilestone('15 minutes! You\'re on fire!');
            _showed15min = true;
          } else if (!_showedHalfway && _totalStudiedSec == (_durationMin * 30)) {
            _showMilestone('Halfway there!');
            _showedHalfway = true;
          }
        }
      } else {
        _ticker?.cancel();
        if (!_isBreakPhase) {
          _pomodoroCount++;
          if (!_customDuration) {
            final breakMin = (_pomodoroCount % 4 == 0) ? 15 : 5;
            _showMilestone(_pomodoroCount % 4 == 0
                ? 'Great work! Long break time!'
                : 'Pomodoro #$_pomodoroCount done! Take a break.');
            setState(() {
              _isBreakPhase = true;
              _remainSec = breakMin * 60;
              _phase = _Phase.onBreak;
            });
            _beginTick();
          } else {
            _finishSession();
          }
        } else {
          setState(() {
            _isBreakPhase = false;
            _remainSec = _durationMin * 60;
            _phase = _Phase.running;
          });
          _showMilestone('Break\'s over! Let\'s go!');
          _beginTick();
        }
      }
    });
  }

  void _showMilestone(String msg) {
    _milestoneTimer?.cancel();
    setState(() => _milestoneMsg = msg);
    _milestoneTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _milestoneMsg = null);
    });
  }

  void _pauseTimer() {
    _ticker?.cancel();
    setState(() => _phase = _Phase.paused);
    // Mirror to global provider so the hero button swaps to Resume and the
    // distraction counter bumps. Fire-and-forget — local state is the
    // source of truth for the UI while the request is in flight.
    // ignore: discarded_futures
    ref.read(studySessionProvider.notifier).pause();
  }

  void _resumeTimer() {
    setState(() => _phase = _isBreakPhase ? _Phase.onBreak : _Phase.running);
    _beginTick();
    // ignore: discarded_futures
    ref.read(studySessionProvider.notifier).resume();
  }

  void _skipBreak() {
    _ticker?.cancel();
    setState(() {
      _isBreakPhase = false;
      _remainSec = _durationMin * 60;
      _phase = _Phase.running;
    });
    _beginTick();
  }

  void _stopTimer() {
    _ticker?.cancel();
    _finishSession();
  }

  void _finishSession() {
    _endTime = DateTime.now();
    _stopAmbient();
    _enterCtrl.reset();
    _enterCtrl.forward();
    setState(() => _phase = _Phase.completed);
    // Warm up the topic picker for the completion card — if the user
    //   already picked a subject we fetch its curated topics so the
    //   chip picker lands pre-populated.
    if (_selectedSubjectId != null && _subjectTopics.isEmpty) {
      _fetchSubjectTopics();
    }
  }

  //
  // Two paths depending on whether the global provider owns the session:
  //
  //  • Provider has a live row (normal case — `_startTimer` created it) →
  //    call `notifier.end()` which PUTs /sessions/{id}/end. The backend
  //    handles duration/focus-score/XP calculation there; we read the
  //    committed row back via /study/sessions for the Wrapped screen.
  //
  //  • No provider session (edge case — provider.start() failed silently
  //    or the screen was entered standalone somehow) → fall back to the
  //    original POST /study/sessions path so the user's effort is never
  //    lost even if Option B networking hiccupped.
  Future<void> _saveSession() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final mins = (_totalStudiedSec / 60).ceil().clamp(1, 720);
      final sessionState = ref.read(studySessionProvider);
      final hasLiveSession = sessionState.sessionId != null;

      if (hasLiveSession) {
        // Option B: finalize the backend row the provider is tracking.
        final ok = await ref.read(studySessionProvider.notifier).end(
              focusScore: _focusScore,
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
              topicsCovered: _topics,
            );
        if (ok) {
          // XP is computed server-side on /end — re-read the finalized row
          // so the Wrapped screen shows the real number. Swallow failures:
          // worst case the user sees 0 XP but their session is saved.
          int xp = 0;
          try {
            final r = await api.get('/study/sessions',
                queryParams: {'limit': '1'});
            if (r.data is List && (r.data as List).isNotEmpty) {
              final first = Map<String, dynamic>.from(r.data[0] as Map);
              xp = (first['xp_earned'] as num?)?.toInt() ?? 0;
            }
          } catch (_) {}
          if (mounted) {
            setState(() { _xpEarned = xp; _saved = true; });
            _xpCtrl.forward(from: 0);
          }
          await _bumpStreak();
          // Force dashboard to re-sync from /gamification/stats so the
          // newly-awarded XP/level/cash/streak appear immediately. Without
          // this, dashboard keeps showing the stale cached values until
          // the user happens to toggle a habit (which was the bug report).
          // ignore: discarded_futures
          ref.read(dashboardProvider.notifier).refresh();
          ref.read(dashboardProvider.notifier).checkAchievements();
          _fetchPastSessions();
        } else if (mounted) {
          // provider.end() sets state.error on failure; surface it.
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              ref.read(studySessionProvider).error
                  ?? 'Could not save session. Try again.',
              style: GoogleFonts.nunito(fontSize: 13),
            ),
            backgroundColor: _coralHdr,
          ));
        }
        return;
      }

      // Legacy fallback path — provider has no session, so create one
      // via the standard POST. Reaches this only on the pre-Option-B
      // edge case where /sessions/start never ran.
      final body = <String, dynamic>{
        'session_type': _sessionType,
        'duration_minutes': mins,
        'start_time': _startTime!.toUtc().toIso8601String(),
        'end_time': _endTime!.toUtc().toIso8601String(),
        'topics_covered': _topics,
        'focus_score': _focusScore,
      };
      if (_selectedSubjectId != null) body['subject_id'] = _selectedSubjectId;
      if (_titleCtrl.text.trim().isNotEmpty) body['title'] = _titleCtrl.text.trim();
      if (_notesCtrl.text.trim().isNotEmpty) body['notes'] = _notesCtrl.text.trim();
      if (_moodTag != null) body['mood_tag'] = _moodTag;

      final resp = await api.post('/study/sessions', data: body);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final xp = resp.data['xp_earned'] ?? 0;
        setState(() {
          _xpEarned = xp is int ? xp : (xp as num).toInt();
          _saved = true;
        });
        _xpCtrl.forward(from: 0);
        // Bump daily streak
        await _bumpStreak();
        // Re-sync the dashboard from /gamification/stats so XP + streak
        // update immediately — otherwise the pills show stale zeros until
        // the user toggles a quest. See dashboard_provider._syncFromApi.
        // ignore: discarded_futures
        ref.read(dashboardProvider.notifier).refresh();
        // Check for achievements
        ref.read(dashboardProvider.notifier).checkAchievements();
        // Refresh past sessions
        _fetchPastSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save session: $e',
            style: GoogleFonts.nunito(fontSize: 13)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportNotesPdf() async {
    final pdf = pw.Document();
    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim() : 'Study Session Notes';
    final mins = (_totalStudiedSec / 60).ceil();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        // Title
        pw.Header(level: 0, child: pw.Text(title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),

        // Session info row
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF8F4'),
            border: pw.Border.all(color: PdfColor.fromHex('#E0D0C0')),
            borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(children: [
            _pdfInfoChip('Type', _sessionType[0].toUpperCase() + _sessionType.substring(1)),
            pw.SizedBox(width: 16),
            _pdfInfoChip('Duration', '${mins} min'),
            pw.SizedBox(width: 16),
            _pdfInfoChip('Focus', '$_focusScore%'),
            pw.SizedBox(width: 16),
            _pdfInfoChip('Pomodoros', '$_pomodoroCount'),
            if (_distractionCount > 0) ...[
              pw.SizedBox(width: 16),
              _pdfInfoChip('Distractions', '$_distractionCount'),
            ],
          ]),
        ),
        pw.SizedBox(height: 12),

        if (_selectedSubjectName != null) ...[
          pw.Row(children: [
            pw.Text('Subject: ', style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#6E5848'))),
            pw.Text(_selectedSubjectName!, style: const pw.TextStyle(fontSize: 11)),
          ]),
          pw.SizedBox(height: 8),
        ],

        // Topics
        if (_topics.isNotEmpty) ...[
          pw.Text('Topics', style: pw.TextStyle(
            fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#6E5848'))),
          pw.SizedBox(height: 6),
          pw.Wrap(spacing: 6, runSpacing: 6, children: _topics.map((t) =>
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0E0F4'),
                borderRadius: pw.BorderRadius.circular(12)),
              child: pw.Text(t, style: const pw.TextStyle(fontSize: 10)),
            )).toList()),
          pw.SizedBox(height: 16),
        ],

        // Notes
        pw.Text('Notes', style: pw.TextStyle(
          fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#6E5848'))),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFFCF8'),
            border: pw.Border.all(color: PdfColor.fromHex('#E8E0D8')),
            borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Text(
            _notesCtrl.text.isNotEmpty ? _pdfSafe(_notesCtrl.text) : '(No notes recorded)',
            style: pw.TextStyle(fontSize: 11, lineSpacing: 4,
              color: _notesCtrl.text.isNotEmpty
                  ? PdfColors.black : PdfColor.fromHex('#999999'))),
        ),

        pw.SizedBox(height: 20),
        pw.Divider(color: PdfColor.fromHex('#E0D0C0')),
        pw.SizedBox(height: 8),
        pw.Text('Generated by CEREBRO Study Session',
          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#999999'),
            fontStyle: pw.FontStyle.italic)),
      ],
    ));

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = '${title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_')}_notes.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      // Open the PDF
      await Process.run('open', [file.path]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF saved to ${file.path}',
            style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _greenHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not export PDF: $e',
            style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  pw.Widget _pdfInfoChip(String label, String value) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 8,
        color: PdfColor.fromHex('#7A5840'))),
      pw.Text(value, style: pw.TextStyle(fontSize: 11,
        fontWeight: pw.FontWeight.bold)),
    ]);
  }

  String _fmtTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtMin(int sec) {
    final m = sec ~/ 60;
    if (m >= 60) return '${m ~/ 60}h ${m % 60}m';
    return '${m}m';
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'focused': return Icons.center_focus_strong_rounded;
      case 'review': return Icons.replay_rounded;
      case 'practice': return Icons.edit_note_rounded;
      case 'lecture': return Icons.headset_rounded;
      default: return Icons.timer_rounded;
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'focused': return _pinkHdr;
      case 'review': return _skyHdr;
      case 'practice': return _greenHdr;
      case 'lecture': return _purpleHdr;
      default: return _pinkHdr;
    }
  }

  Color _typeColorLight(String t) {
    switch (t) {
      case 'focused': return _pinkLt;
      case 'review': return _skyLt;
      case 'practice': return _greenLt;
      case 'lecture': return _purpleLt;
      default: return _pinkLt;
    }
  }

  Color? _parseColor(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
    try { return Color(int.parse('FF${hex.substring(1)}', radix: 16)); }
    catch (_) { return null; }
  }

  //  BUILD
  @override
  Widget build(BuildContext context) {
    // If the mini session bar or the hub hero flipped `endRequested` while
    // this screen is already open in running/paused phase, jump us to the
    // Wrapped rating view. Guard with `_phase != completed` so we don't
    // re-enter the branch on every rebuild.
    ref.listen<SessionState>(studySessionProvider, (prev, next) {
      if (!next.endRequested) return;
      if (_phase == _Phase.completed || _phase == _Phase.setup) return;
      _ticker?.cancel();
      _endTime = DateTime.now();
      setState(() {
        _phase = _Phase.completed;
        _focusScore = _focusScore.clamp(1, _maxFocusForDistractions());
      });
      ref.read(studySessionProvider.notifier).consumeEndRequest();
      if (_selectedSubjectId != null && _subjectTopics.isEmpty) {
        _fetchSubjectTopics();
      }
      _enterCtrl.reset();
      _enterCtrl.forward();
    });

    return Scaffold(
      backgroundColor: _ombre1,
      body: Stack(children: [
        // Ombré background
        Positioned.fill(child: Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_ombre1, _ombre2, _ombre3, _ombre4],
            stops: [0.0, 0.3, 0.6, 1.0])))),
        // Pawprints
        Positioned.fill(child: CustomPaint(painter: _PawPrintBg())),
        // Ambient glow
        Positioned(top: -100, left: 0, right: 0, child: Container(
          height: 280,
          decoration: BoxDecoration(gradient: RadialGradient(
            center: Alignment.topCenter, radius: 1.2,
            colors: [
              (_phase == _Phase.onBreak ? _greenHdr
                  : _phase == _Phase.completed ? _goldHdr
                  : _typeColor(_sessionType)).withOpacity(0.12),
              Colors.transparent])))),
        // Floating particles during timer
        if (_phase == _Phase.running || _phase == _Phase.paused || _phase == _Phase.onBreak)
          Positioned.fill(child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(
                progress: _particleCtrl.value,
                color: _isBreakPhase ? _greenHdr : _typeColor(_sessionType))))),
        // Main content — hero & body are wrapped in ONE shared
        // Center+ConstrainedBox(maxWidth:1240) with ONE shared hPad.
        // The previous layout had the hero at a different x-offset
        // than the setup cards (which had their own maxWidth +
        // center), which is what made the hero look "thrusted left
        // of the content" on wide displays.
        SafeArea(child: LayoutBuilder(builder: (outerCtx, outerC) {
          // MATCHES dashboard (study_tab.dart `_buildDesktopLayout`):
          //   hPad scales 40 → 60 → 80 by viewport; NO maxWidth so the
          //   content fills the whole desktop viewport the way the
          //   dashboard does. Desktop (>900) fills the viewport with
          //   zero scroll; narrow (<900) falls back to a scrollable
          //   stack.
          final bool isDesktop = outerC.maxWidth > 900;
          final double hPad = outerC.maxWidth > 1280 ? 80
              : outerC.maxWidth > 1024 ? 60
              : isDesktop ? 40
              : 22;
          final bodyBuilder = LayoutBuilder(builder: (ctx, c) {
            final centerY = _phase == _Phase.running ||
                _phase == _Phase.paused || _phase == _Phase.onBreak;
            if (isDesktop) {
              // Desktop — fills viewport, no scroll. Outer padding is
              //   intentionally small (6 top / 14 bottom) because the
              //   setup body uses weighted Spacers to distribute the
              //   viewport leftover internally (2:1 top:bottom), so
              //   content floats in the lower-middle of the page.
              return Padding(
                padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 14),
                child: _phase == _Phase.setup ? _buildSetup(desktop: true)
                    : _phase == _Phase.completed ? _buildCompletion(desktop: true)
                    : _buildTimer(),
              );
            }
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 6, hPad, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: centerY ? c.maxHeight - 42 : 0),
                child: Column(
                  mainAxisAlignment: centerY
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _phase == _Phase.setup ? _buildSetup()
                        : _phase == _Phase.completed ? _buildCompletion()
                        : _buildTimer(),
                  ],
                ),
              ),
            );
          });
          return Column(children: [
            _buildHero(hPad: hPad),
            Expanded(child: bodyBuilder),
          ]);
        })),
        // Milestone toast
        if (_milestoneMsg != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 30, right: 30,
            child: _MilestoneToast(msg: _milestoneMsg!)),
      ]),
    );
  }

  //    LEFT, colored stat pills on the RIGHT. Title left-edge sits
  //    at the same x as the body content below (because the back
  //    button is a small 34px chip, not a 44px circle), which kills
  //    the "hero thrusted left of content" misalignment.
  Widget _buildHero({double hPad = 24}) {
    final onTimer = _phase == _Phase.running ||
        _phase == _Phase.paused || _phase == _Phase.onBreak;
    final title = _phase == _Phase.setup ? 'Study Session'
        : _phase == _Phase.completed ? 'Session Wrapped'
        : _isBreakPhase ? 'On A Break'
        : 'In Focus';
    final kicker = _phase == _Phase.setup
        ? 'shape your focus ritual'
        : _phase == _Phase.completed
            ? 'here\'s how it went'
            : _isBreakPhase
                ? 'breathe, stretch, sip'
                : 'stay with the thread';
    final dash = ref.watch(dashboardProvider);
    final studiedMin = _totalStudiedSec ~/ 60;

    // Mini stat pill — coral / gold / yellow like dashboard _TopChip
    Widget pill(IconData icon, String label, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.38),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.2),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.16),
          offset: const Offset(1.5, 2), blurRadius: 0)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _brown),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(
          fontFamily: 'Bitroad', fontSize: 13, color: _brown, height: 1)),
      ]),
    );

    return Padding(
      // Bigger top breathing room — title sits noticeably below the
      //   viewport edge instead of hugging it.
      padding: EdgeInsets.fromLTRB(hPad, 56, hPad, 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Back — bumped to 46px to match the heavier title type scale
        //
        // With Option B session state, popping this route doesn't end the
        // session — the global provider keeps it running and the mini
        // session bar will show on any tab they navigate to. So back =
        // plain route pop, no confirm dialog. The cross-tab guard
        // (home_screen._handleTabTap) is the only thing that blocks
        // navigation during a live session, and only when leaving the
        // Study tab entirely.
        GestureDetector(
          onTap: () {
            _stopAmbient();
            Navigator.of(context).pop();
          },
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
              boxShadow: [BoxShadow(
                color: _outline.withOpacity(0.28),
                offset: const Offset(2, 3), blurRadius: 0)]),
            child: const Icon(Icons.chevron_left_rounded,
              size: 28, color: _outline),
          ),
        ),
        const SizedBox(width: 16),
        // Title — bigger Bitroad type for hero presence
        Flexible(child: Text(title, style: const TextStyle(
          fontFamily: 'Bitroad', fontSize: 36,
          color: _brown, height: 1.0),
          overflow: TextOverflow.ellipsis, maxLines: 1)),
        if (!onTimer) ...[
          const SizedBox(width: 14),
          Flexible(child: Text('· $kicker',
            style: GoogleFonts.gaegu(
              fontSize: 17, fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: _brownLt.withOpacity(0.78),
              letterSpacing: 0.2),
            overflow: TextOverflow.ellipsis, maxLines: 1)),
        ],
        const Spacer(),
        // Stat pills — completion phase only (XP / time / streak belong
        //   inside the Rhythm card during setup, not floating in the
        //   header gap). User feedback: "why is the random xp pill
        //   placed so randomly in the middle".
        if (_phase == _Phase.completed) ...[
          pill(Icons.timer_rounded,
            studiedMin > 0 ? '${studiedMin}m' : '—',
            const Color(0xFFF7AEAE)),
          const SizedBox(width: 6),
          pill(Icons.star_rounded, '${dash.totalXp}',
            const Color(0xFFE4BC83)),
          if (_streakCount > 0) ...[
            const SizedBox(width: 6),
            pill(Icons.bolt_rounded, '$_streakCount',
              const Color(0xFFFFBC5C)),
          ],
        ],
      ]),
    );
  }

  // _showExitConfirm() was the legacy "are you sure?" dialog that fired on
  // back-button while a local timer was running. Removed in the Option B
  // (global persistent session) refactor: popping this route no longer
  // ends anything — the global StudySessionNotifier keeps the session
  // alive and the MiniSessionBar surfaces it on every other tab. The only
  // remaining navigation guard lives in HomeScreen._handleTabTap and only
  // fires when the user tries to leave the Study tab entirely.

  //  1. SETUP PHASE
  Widget _buildSetup({bool desktop = false}) {
    return LayoutBuilder(builder: (ctx, c) {
      // ignore: unused_local_variable
      final _ignoredMax = c.maxWidth;

      //    (Bitroad 16px label + 16x16 olive-dk icon + 7px gap +
      //    13px bottom margin). Optional trailing "sub" sits on the
      //    right as a tiny Gaegu whisper, so every page speaks in
      //    the same warm voice without clutter.
      Widget labelled(String title, IconData icon, String sub, Widget body,
          {IconData? tagIcon}) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Icon(icon, size: 19, color: _oliveDk),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(
                fontFamily: 'Bitroad', fontSize: 19, color: _brown)),
              const SizedBox(width: 12),
              Expanded(child: Text(sub, style: GoogleFonts.gaegu(
                fontSize: 15, fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: _brownLt.withOpacity(0.85), letterSpacing: 0.2),
                overflow: TextOverflow.ellipsis)),
              if (tagIcon != null)
                Icon(tagIcon, size: 16, color: _brownLt.withOpacity(0.4)),
            ]),
          ),
          body,
        ]);
      }

      final typeSection = labelled('Session Type',
        Icons.category_rounded,
        'what kind of work today',
        _buildTypeChips(),
        tagIcon: Icons.auto_awesome_rounded);
      final detailsSection = labelled('Details',
        Icons.edit_note_rounded,
        'subject & title — optional',
        _buildDetailsCard());
      final durationSection = labelled('Focus Length',
        Icons.timer_outlined,
        'pick a preset or dial it in',
        _buildDurationCard());
      final ambientSection = labelled('Ambience',
        Icons.graphic_eq_rounded,
        'sound to settle into',
        _buildAmbientCard());

      //    hairline sage-dk border, soft diagonal drop so it still has
      //    the cozy chunky feel without the muddy 3-stop gradient.
      final startBtn = GestureDetector(
        onTap: _startTimer,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 23),
          decoration: BoxDecoration(
            color: _olive, // flat #98A869, no gradient
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _oliveDk.withOpacity(0.55), width: 1.6),
            boxShadow: [BoxShadow(
              color: _oliveDk.withOpacity(0.28),
              offset: const Offset(2, 3), blurRadius: 0)]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Begin Session', style: TextStyle(
              fontFamily: 'Bitroad', fontSize: 24,
              color: Colors.white, height: 1.0, letterSpacing: 0.4)),
            const SizedBox(width: 14),
            const Icon(Icons.arrow_forward_rounded,
              size: 24, color: Colors.white),
          ]),
        ),
      );

      // Past sessions — quiet text link, not a loud sticker
      final pastLink = GestureDetector(
        onTap: _showPastSessions,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.history_rounded, size: 15,
              color: _brownLt.withOpacity(0.75)),
            const SizedBox(width: 7),
            Text('Past sessions (${_pastSessions.length})',
              style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: _brownLt, letterSpacing: 0.2,
                decoration: TextDecoration.underline,
                decorationColor: _brownLt.withOpacity(0.3))),
          ]),
        ),
      );

      // Each section lives in its own `_sectionCard` (white/0.88,
      // outline 0.22, 18r, offset-0-3 hard shadow). The page reads
      // like a natural extension of the dashboard rather than a
      // long settings form. The HERO card at the top combines the
      // primary choices (Type + Focus Length + Begin Session) so
      // users can commit without scrolling.

      // Hero divider — a small sage leaf anchored between two faint
      //   sage hairlines. Carries the Rhythm card's eco motif into
      //   the hero so the page shares a quiet visual vocabulary.
      Widget heroDivider = Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Container(height: 1.3,
            color: _oliveDk.withOpacity(0.16))),
          const SizedBox(width: 13),
          Icon(Icons.eco_rounded, size: 14,
            color: _oliveDk.withOpacity(0.5)),
          const SizedBox(width: 13),
          Expanded(child: Container(height: 1.3,
            color: _oliveDk.withOpacity(0.16))),
        ]));

      // HERO card — sage wash marks it as the "commit" path. The
      // composition is INTENTIONALLY content-sized: every block
      // packs to its natural height with a fixed 22px breath before
      // the CTA. No spaceBetween — that was the source of the dead
      // cream zone when the cell stretched.
      final heroCard = Container(
        padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              _sagePale.withOpacity(0.95),
              _creamSoft.withOpacity(0.78),
            ]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _oliveDk.withOpacity(0.45), width: 2),
          boxShadow: [BoxShadow(
            color: _oliveDk.withOpacity(0.28),
            offset: const Offset(3, 4), blurRadius: 0)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            typeSection,
            heroDivider,
            durationSection,
            const SizedBox(height: 30),
            startBtn,
          ]));

      if (desktop) {
        // Layout: left column = hero card (session type, focus length, begin button)
        // right column = details card (top) + rhythm card (bottom)
        // quote text + past sessions link below

        // Right column — Details on top (compact), Rhythm below.
        //   Both shrink-wrap their content. No Expanded forcing
        //   them to fill the hero's height.
        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _sectionCard(
              tint: _pinkDeep, tintSoft: _pinkSoft,
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
              child: detailsSection),
            const SizedBox(height: 22),
            _rhythmCard(),
          ]);

        // Top block — hero (55%) + right column (45%). Row uses
        //   `start` so children stay at their natural heights; the
        //   row height is the taller of the two. No viewport stretch.
        final topBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 55, child: _stag(0.02, heroCard)),
            const SizedBox(width: 22),
            Expanded(flex: 45, child: _stag(0.05, rightColumn)),
          ]);

        //   band with the label inline and the tile row flowing
        //   beside it, hugging its content height.
        final ambienceStrip = _stag(0.09, Container(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 22),
          decoration: BoxDecoration(
            // Soft tint, hairline border — band-feeling, not card-heavy
            color: _skySoft.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _skyDk.withOpacity(0.28), width: 1.2),
            boxShadow: [BoxShadow(
              color: _skyDk.withOpacity(0.12),
              offset: const Offset(2, 2), blurRadius: 0)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Icon(Icons.graphic_eq_rounded, size: 19, color: _oliveDk),
                const SizedBox(width: 9),
                const Text('Ambience', style: TextStyle(
                  fontFamily: 'Bitroad', fontSize: 19, color: _brown)),
                const SizedBox(width: 12),
                Expanded(child: Text('sound to settle into',
                  style: GoogleFonts.gaegu(
                    fontSize: 15, fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: _brownLt.withOpacity(0.85), letterSpacing: 0.2),
                  overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 18),
              _buildAmbientCard(),
            ]),
        ));

        //   sessions chip. Lets the page exhale at the bottom.
        final footerRow = _stag(0.13, Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.format_quote_rounded, size: 18,
              color: _goldDk.withOpacity(0.7)),
            const SizedBox(width: 10),
            Expanded(child: Text(_quote, style: GoogleFonts.gaegu(
              fontSize: 15, fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: _brownLt, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _showPastSessions,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: _creamSoft.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _outline.withOpacity(0.28), width: 1.3),
                  boxShadow: [BoxShadow(
                    color: _outline.withOpacity(0.16),
                    offset: const Offset(2, 2), blurRadius: 0)]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history_rounded, size: 14, color: _brownLt),
                  const SizedBox(width: 6),
                  Text('Past sessions (${_pastSessions.length})',
                    style: const TextStyle(
                      fontFamily: 'Bitroad', fontSize: 12,
                      color: _brown, letterSpacing: 0.2)),
                ]),
              ),
            ),
          ]));

        // Body composition — weighted Spacers redistribute any
        //   leftover viewport height so the content floats in the
        //   lower-middle of the page. Top spacer (flex 2) gets
        //   twice the leftover as the bottom (flex 1), giving the
        //   content an intentional gap from the hero strip and a
        //   tight, settled feel at the bottom instead of the
        //   previous yawn of empty cream.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 2),
            topBlock,
            const SizedBox(height: 28),
            ambienceStrip,
            const SizedBox(height: 24),
            footerRow,
            const Spacer(flex: 1),
          ]);
      }

      // Uses the same palette tints as desktop so the visual
      // identity is consistent across breakpoints.
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _stag(0.02, heroCard),
        const SizedBox(height: 14),
        _stag(0.05, _sectionCard(
          tint: _pinkDeep, tintSoft: _pinkSoft, child: detailsSection)),
        const SizedBox(height: 14),
        _stag(0.08, _sectionCard(
          tint: _skyHdr, tintSoft: _skySoft, child: ambientSection)),
        const SizedBox(height: 14),
        _stag(0.11, _rhythmCard()),
        const SizedBox(height: 14),
        _stag(0.14, _setupQuoteCard()),
        const SizedBox(height: 6),
        _stag(0.17, pastLink),
        const SizedBox(height: 4),
      ]);
    });
  }

  Widget _rhythmCard() {
    final totalSessions = _pastSessions.length;
    int totalMin = 0;
    for (final s in _pastSessions) {
      final v = s['duration_min'] ?? s['durationMin'] ?? s['duration'];
      if (v is num) totalMin += v.toInt();
    }
    final totalHr = (totalMin / 60).toStringAsFixed(totalMin >= 60 ? 1 : 0);
    final totalXp = ref.watch(dashboardProvider).totalXp;

    Widget stat(String label, String value, String unit) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.nunito(
          fontSize: 9.5, fontWeight: FontWeight.w900,
          color: _inkSoft, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, style: const TextStyle(
            fontFamily: 'Bitroad', fontSize: 26, color: _brown, height: 1)),
          const SizedBox(width: 3),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(unit, style: GoogleFonts.nunito(
              fontSize: 11, fontWeight: FontWeight.w700, color: _brownLt))),
        ]),
      ]),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
      decoration: BoxDecoration(
        // Sage wash + chunkier outline & diagonal offset shadow so
        // the card sits alongside dashboard's other cards with the
        // same 3D sticker feel instead of a flat pastel panel.
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            _oliveBg.withOpacity(0.92),
            _cardFill.withOpacity(0.8),
          ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _oliveDk.withOpacity(0.4), width: 1.8),
        boxShadow: [BoxShadow(
          color: _oliveDk.withOpacity(0.26),
          offset: const Offset(3, 3), blurRadius: 0)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(Icons.favorite_rounded, size: 18, color: _oliveDk),
          const SizedBox(width: 8),
          Text('Your Rhythm', style: const TextStyle(
            fontFamily: 'Bitroad', fontSize: 18, color: _brown)),
          const SizedBox(width: 11),
          Expanded(child: Text('a quiet pulse check',
            style: GoogleFonts.gaegu(fontSize: 14,
              fontWeight: FontWeight.w500, fontStyle: FontStyle.italic,
              color: _brownLt.withOpacity(0.85), letterSpacing: 0.2),
            overflow: TextOverflow.ellipsis)),
          // XP pill — lives in the Rhythm card header now, not floating
          //   in the hero's empty right gap.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _tanWarm.withOpacity(0.38),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.22), width: 1.2),
              boxShadow: [BoxShadow(
                color: _outline.withOpacity(0.14),
                offset: const Offset(1.5, 2), blurRadius: 0)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_rounded, size: 13, color: _brown),
              const SizedBox(width: 4),
              Text('$totalXp', style: const TextStyle(
                fontFamily: 'Bitroad', fontSize: 13, color: _brown, height: 1)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          stat('STREAK', '$_streakCount', _streakCount == 1 ? 'day' : 'days'),
          stat('SESSIONS', '$totalSessions', totalSessions == 1 ? 'log' : 'logs'),
          stat('TIME', totalHr, totalMin >= 60 ? 'hrs' : 'min'),
        ]),
        const SizedBox(height: 16),
        Container(height: 1, color: _outline.withOpacity(0.1)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.eco_rounded, size: 14, color: _oliveDk),
          const SizedBox(width: 9),
          Expanded(child: Text(
            _streakCount > 0
              ? 'You\'ve shown up ${_streakCount == 1 ? "today" : "$_streakCount days in a row"}. Keep the thread.'
              : 'No streak yet. Let today be the first knot.',
            style: GoogleFonts.nunito(fontSize: 12,
              fontWeight: FontWeight.w600, color: _brownLt,
              height: 1.4))),
        ]),
      ]),
    );
  }

  //    User feedback: "why does a line to carry have 2 different fonts."
  //    Fix: drop the Bitroad microlabel; the whole card speaks in one
  //    handwritten whisper. A tiny gold quote glyph sits alongside as
  //    the sole non-text accent so it still reads as a card, not a
  //    blockquote in a void.
  Widget _setupQuoteCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFDEFDB).withOpacity(0.95),
            const Color(0xFFFFF6E4).withOpacity(0.78),
          ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _goldDk.withOpacity(0.42), width: 1.8),
        boxShadow: [BoxShadow(
          color: _goldDk.withOpacity(0.26),
          offset: const Offset(3, 3), blurRadius: 0)]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Gold bar + small quote glyph anchor the card without
        // introducing a second font voice.
        Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.format_quote_rounded, size: 20, color: _goldDk),
          const SizedBox(height: 6),
          Container(width: 3, height: 32, decoration: BoxDecoration(
            color: _goldDk.withOpacity(0.75),
            borderRadius: BorderRadius.circular(2))),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('a line to carry in',
              style: GoogleFonts.gaegu(
                fontSize: 13, fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: _goldDk, letterSpacing: 0.3)),
            const SizedBox(height: 8),
            Text(_quote, style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic, color: _brown, height: 1.45)),
          ])),
      ]),
    );
  }

  Widget _quoteStrip() {
    final c = _typeColor(_sessionType);
    final cLt = _typeColorLight(_sessionType);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [cLt.withOpacity(0.38), c.withOpacity(0.18)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: c.withOpacity(0.12),
          offset: const Offset(0, 2), blurRadius: 0)]),
      child: Row(children: [
        Icon(Icons.auto_awesome_rounded, size: 17, color: c),
        const SizedBox(width: 10),
        Expanded(child: Text(_quote, style: GoogleFonts.gaegu(
          fontSize: 13, fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic, color: _brown, height: 1.3))),
      ]),
    );
  }

  Widget _sectionHeader(String label, IconData icon, Color accent) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.28),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accent.withOpacity(0.5), width: 1.3),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.15),
            offset: const Offset(0, 1.5), blurRadius: 0)]),
        child: Icon(icon, size: 15, color: _brown)),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.gaegu(
        fontSize: 19, fontWeight: FontWeight.w700, color: _brown)),
    ]);
  }

  Widget _buildTypeChips() {
    const types = ['focused', 'review', 'practice', 'lecture'];
    const labels = ['Focused', 'Review', 'Practice', 'Lecture'];
    final icons = [
      Icons.center_focus_strong_rounded,
      Icons.replay_rounded,
      Icons.edit_note_rounded,
      Icons.headset_rounded,
    ];

    // Filled chip style matching dashboard game-buttons — soft cream
    // base, color-tinted fill when picked, chunky (3,3) diagonal
    // offset shadow in every state so they feel 3D-stickery and sit
    // on the olive hero card with real visual weight.
    return Row(children: List.generate(4, (i) {
      final sel = _sessionType == types[i];
      final color = _typeColor(types[i]);
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
        child: GestureDetector(
          onTap: () => setState(() => _sessionType = types[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
            decoration: BoxDecoration(
              color: sel ? color.withOpacity(0.42)
                  : const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel
                    ? color.withOpacity(0.7)
                    : _outline.withOpacity(0.28),
                width: 1.6),
              boxShadow: [BoxShadow(
                color: sel
                    ? color.withOpacity(0.38)
                    : _outline.withOpacity(0.18),
                offset: const Offset(2, 3), blurRadius: 0)]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icons[i], size: 16,
                color: sel ? _brown : _brownLt.withOpacity(0.78)),
              const SizedBox(width: 7),
              Flexible(child: Text(labels[i], style: TextStyle(
                fontFamily: 'Bitroad', fontSize: 13,
                color: sel ? _brown : _brownLt),
                overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      ));
    }));
  }

  //    _sectionCard in the new vertical card stack).
  Widget _buildDetailsCard() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SUBJECT', style: GoogleFonts.nunito(
          fontSize: 10, fontWeight: FontWeight.w900,
          color: _oliveDk, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showSubjectSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outline.withOpacity(0.28), width: 1.5),
              boxShadow: [BoxShadow(
                color: _outline.withOpacity(0.14),
                offset: const Offset(2, 2), blurRadius: 0)]),
            child: Row(children: [
              if (_selectedSubjectName != null) ...[
                Container(width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: _parseColor(_selectedSubjectColor) ?? _greenHdr,
                    shape: BoxShape.circle,
                    border: Border.all(color: _outline.withOpacity(0.3), width: 1))),
                const SizedBox(width: 10),
                Expanded(child: Text(_selectedSubjectName!,
                  style: GoogleFonts.nunito(fontSize: 14, color: _brown,
                    fontWeight: FontWeight.w600))),
              ] else ...[
                Icon(Icons.add_circle_outline_rounded, size: 16,
                  color: _brownLt.withOpacity(0.5)),
                const SizedBox(width: 10),
                Expanded(child: Text('Choose a subject (optional)',
                  style: GoogleFonts.nunito(fontSize: 13,
                    color: _brownLt.withOpacity(0.6)))),
              ],
              Icon(Icons.expand_more_rounded, size: 19,
                color: _brownLt.withOpacity(0.4)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        //    All six InputBorder slots are explicitly set to none so
        //    Flutter's default Material focus-border doesn't paint a
        //    hard dark line on top of the cream Container (which is
        //    what was happening before — visible as a thick outline).
        Text('TITLE', style: GoogleFonts.nunito(
          fontSize: 10, fontWeight: FontWeight.w900,
          color: _oliveDk, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline.withOpacity(0.28), width: 1.5),
            boxShadow: [BoxShadow(
              color: _outline.withOpacity(0.14),
              offset: const Offset(2, 2), blurRadius: 0)]),
          child: TextField(
            controller: _titleCtrl,
            cursorColor: _oliveDk,
            cursorWidth: 1.4,
            style: GoogleFonts.nunito(fontSize: 14, color: _brown,
              fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g. Chapter 5 Review',
              hintStyle: GoogleFonts.nunito(fontSize: 13,
                color: _brownLt.withOpacity(0.45)),
              prefixIcon: Icon(Icons.edit_rounded, size: 16,
                color: _brownLt.withOpacity(0.4)),
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12)),
          ),
        ),
      ]);
  }

  void _showSubjectSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _outline.withOpacity(0.12),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Text('Choose Subject', style: GoogleFonts.gaegu(
            fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(height: 14),
          _subjectTile(null, 'No subject', null, ctx),
          if (_subjectsLoading)
            Padding(padding: const EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _pinkHdr)))
          else
            ...(_subjects.map((s) => _subjectTile(
              s['id']?.toString(), s['name']?.toString() ?? 'Unknown',
              s['color']?.toString(), ctx))),
        ]),
      ),
    );
  }

  Widget _subjectTile(String? id, String name, String? colorHex, BuildContext ctx) {
    final sel = _selectedSubjectId == id;
    final dotColor = _parseColor(colorHex) ?? _greenHdr;
    return GestureDetector(
      onTap: () {
        final changed = _selectedSubjectId != id;
        setState(() {
          _selectedSubjectId = id;
          _selectedSubjectName = id != null ? name : null;
          _selectedSubjectColor = colorHex;
          if (changed) {
            _subjectTopics = [];
            _lastLoadedTopicsSubject = null;
          }
        });
        Navigator.pop(ctx);
        if (id != null) _fetchSubjectTopics();
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: sel ? _pinkHdr.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? _pinkHdr.withOpacity(0.35) : _outline.withOpacity(0.08),
            width: sel ? 2 : 1)),
        child: Row(children: [
          if (id != null) ...[
            Container(width: 10, height: 10,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 12),
          ] else
            ...[Icon(Icons.remove_circle_outline_rounded, size: 13,
              color: _brownLt.withOpacity(0.35)), const SizedBox(width: 12)],
          Expanded(child: Text(name, style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: _brown))),
          if (sel) Icon(Icons.check_rounded, size: 16, color: _greenDk),
        ]),
      ),
    );
  }

  //    in the new vertical card stack).
  Widget _buildDurationCard() {
    return Column(children: [
        Row(children: [
          _DurationChip(min: 25, label: '25m', desc: 'Pomodoro',
            selected: !_customDuration && _durationMin == 25,
            onTap: () => setState(() { _customDuration = false; _durationMin = 25; })),
          const SizedBox(width: 8),
          _DurationChip(min: 45, label: '45m', desc: 'Deep',
            selected: !_customDuration && _durationMin == 45,
            onTap: () => setState(() { _customDuration = false; _durationMin = 45; })),
          const SizedBox(width: 8),
          _DurationChip(min: 60, label: '60m', desc: 'Marathon',
            selected: !_customDuration && _durationMin == 60,
            onTap: () => setState(() { _customDuration = false; _durationMin = 60; })),
          const SizedBox(width: 8),
          _DurationChip(min: 0, label: 'Custom', desc: '${_durationMin}m',
            selected: _customDuration, isCustom: true,
            onTap: () => setState(() => _customDuration = true)),
        ]),
        if (_customDuration) ...[
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _purpleHdr,
              inactiveTrackColor: _outline.withOpacity(0.12),
              thumbColor: _purpleDk,
              overlayColor: _purpleHdr.withOpacity(0.15),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11)),
            child: Slider(
              value: _durationMin.toDouble(),
              min: 5, max: 180, divisions: 35,
              onChanged: (v) => setState(() => _durationMin = v.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('5 min', style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _purpleHdr.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _purpleHdr.withOpacity(0.4), width: 1)),
                child: Text('$_durationMin min', style: GoogleFonts.gaegu(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _brown)),
              ),
              Text('180 min', style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
            ]),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: _oliveBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _oliveDk.withOpacity(0.42), width: 1.5),
              boxShadow: [BoxShadow(
                color: _oliveDk.withOpacity(0.16),
                offset: const Offset(2, 2), blurRadius: 0)]),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _oliveDk),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_durationMin}m focus \u2192 5m break \u00B7 long break every 4 pomos',
                style: GoogleFonts.nunito(fontSize: 11.5,
                  fontWeight: FontWeight.w700, color: _brown, height: 1.3))),
            ]),
          ),
        ],
      ]);
  }

  Widget _buildAmbientCard() {
    const sounds = ['none', 'rain', 'lofi', 'cafe', 'ocean', 'fire', 'birds'];
    const labels = ['Off', 'Rain', 'Lo-fi', 'Café', 'Ocean', 'Fire', 'Birds'];
    const icons = [
      Icons.volume_off_rounded, Icons.water_drop_rounded,
      Icons.headphones_rounded, Icons.local_cafe_rounded,
      Icons.waves_rounded, Icons.local_fire_department_rounded,
      Icons.park_rounded,
    ];
    final colors = [
      _brownLt, _skyHdr, _purpleHdr, _coralHdr, _skyHdr, _coralHdr, _greenHdr];

    //    that match dashboard's chunky style — soft cream when off,
    //    color-tinted with a hard offset shadow when picked.
    return Row(children: List.generate(7, (i) {
        final sel = _ambientSound == sounds[i];
        final c = colors[i];
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: i < 6 ? 5 : 0),
          child: GestureDetector(
            onTap: () {
              if (sounds[i] == 'none') {
                _stopAmbient();
              } else {
                _playAmbient(sounds[i]);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: sel
                    ? c.withOpacity(0.36)
                    : const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: sel
                      ? c.withOpacity(0.68)
                      : _outline.withOpacity(0.25),
                  width: 1.5),
                boxShadow: sel
                    ? [BoxShadow(color: c.withOpacity(0.34),
                        offset: const Offset(2, 3), blurRadius: 0)]
                    : [BoxShadow(color: _outline.withOpacity(0.16),
                        offset: const Offset(2, 2), blurRadius: 0)]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_audioLoading && _ambientSound == sounds[i] && sounds[i] != 'none')
                  SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c))
                else
                  Icon(icons[i], size: 19,
                    color: sel ? _brown : _brownLt.withOpacity(0.7)),
                const SizedBox(height: 5),
                Text(labels[i], style: GoogleFonts.nunito(
                  fontSize: 10.5, fontWeight: sel ? FontWeight.w800 : FontWeight.w700,
                  color: sel ? _brown : _brownLt)),
              ]),
            ),
          ),
        ));
      }));
  }

  //  2. TIMER PHASE
  Widget _buildTimer() {
    final totalSec = _isBreakPhase
        ? ((_pomodoroCount % 4 == 0) ? 15 : 5) * 60
        : _durationMin * 60;
    final progress = totalSec > 0 ? 1.0 - (_remainSec / totalSec) : 0.0;
    final themeColor = _isBreakPhase ? _olive : _typeColor(_sessionType);
    final themeColorLt = _isBreakPhase ? _oliveLt : _typeColorLight(_sessionType);

    final xpEst = ((_totalStudiedSec / 1800) * 25).round();
    final level = 1 + (xpEst ~/ 100);
    final lvlFrac = ((xpEst % 100) / 100.0).clamp(0.0, 1.0);

    Widget sec(String label, IconData icon, {Color? accent, String? sub}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Icon(icon, size: 19, color: accent ?? _oliveDk),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(
            fontFamily: 'Bitroad', fontSize: 18, color: _brown)),
          if (sub != null) ...[
            const SizedBox(width: 12),
            Expanded(child: Text(sub, style: GoogleFonts.gaegu(
              fontSize: 14.5, fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: _brownLt.withOpacity(0.85)),
              overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
          ],
        ]),
      );
    }

    Widget timerRing(double size) {
      final inner = size * 0.82;
      return AnimatedBuilder(
        animation: _breatheCtrl,
        builder: (_, __) {
          final breathe = 1.0 + _breatheCtrl.value * 0.012;
          return Transform.scale(scale: breathe, child: SizedBox(
            width: size, height: size,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: themeColor.withOpacity(0.08 + _breatheCtrl.value * 0.05),
                    blurRadius: 30, spreadRadius: 6)])),
              SizedBox(width: size, height: size,
                child: CustomPaint(painter: _RingPainter(
                  progress: progress,
                  color1: themeColorLt,
                  color2: themeColor,
                  bgColor: _outline.withOpacity(0.08)))),
              Container(
                width: inner, height: inner,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cardFill,
                  border: Border.all(color: _outline.withOpacity(0.18), width: 1.5),
                  boxShadow: [BoxShadow(
                    color: _outline.withOpacity(0.1),
                    offset: const Offset(3, 3), blurRadius: 0)]),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_isBreakPhase ? 'BREAK' : 'FOCUS',
                    style: GoogleFonts.nunito(
                      fontSize: size < 280 ? 11 : 12,
                      fontWeight: FontWeight.w800,
                      color: themeColor, letterSpacing: 2.8)),
                  const SizedBox(height: 6),
                  Text(_fmtTime(_remainSec), style: TextStyle(
                    fontFamily: 'Bitroad',
                    fontSize: size < 280 ? 58 : (size < 340 ? 72 : 86),
                    color: _brown, height: 1.0)),
                  const SizedBox(height: 7),
                  Text(
                    _isBreakPhase ? 'relax & recharge'
                        : _remainSec > 60 ? '${(_remainSec / 60).ceil()} min left'
                        : '${_remainSec}s left',
                    style: GoogleFonts.nunito(fontSize: 12,
                      fontWeight: FontWeight.w700, color: _inkSoft)),
                ]),
              ),
            ]),
          ));
        },
      );
    }

    Widget phasePill() => AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final op = _phase == _Phase.paused ? 0.55 + _pulseCtrl.value * 0.45 : 1.0;
        final label = _isBreakPhase ? 'Break Time'
            : _phase == _Phase.paused ? 'Paused'
            : 'Focus Block #${_pomodoroCount + 1}';
        return Opacity(opacity: op, child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(width: 7, height: 7,
              decoration: BoxDecoration(
                color: themeColor, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: themeColor.withOpacity(0.35),
                  blurRadius: 7, spreadRadius: 1)])),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.nunito(
              fontSize: 13.5, fontWeight: FontWeight.w800,
              color: _brown, letterSpacing: 0.8)),
            if (_selectedSubjectName != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Text('·', style: GoogleFonts.nunito(
                  fontSize: 15, fontWeight: FontWeight.w900,
                  color: _outline.withOpacity(0.4)))),
              Flexible(child: Text(_selectedSubjectName!,
                style: GoogleFonts.nunito(
                  fontSize: 13.5, fontWeight: FontWeight.w600,
                  color: _brownLt, letterSpacing: 0.2),
                overflow: TextOverflow.ellipsis)),
            ],
          ]),
        );
      },
    );

    Widget controls() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (!_isBreakPhase)
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: _CircleBtn(
            gradTop: _purpleLt, gradBot: _purpleHdr,
            borderColor: _purpleDk, shadowColor: _purpleDk,
            icon: Icons.notifications_active_rounded, size: 48, iconSize: 20,
            onTap: () {
              setState(() => _distractionCount++);
              HapticFeedback.lightImpact();
              _showMilestone('Distraction #$_distractionCount noted');
            }),
        ),
      if (_phase == _Phase.paused)
        _CircleBtn(
          gradTop: _oliveLt, gradBot: _olive,
          borderColor: _oliveDk, shadowColor: _oliveDk,
          icon: Icons.play_arrow_rounded, size: 64, iconSize: 32,
          onTap: _resumeTimer)
      else if (_phase == _Phase.onBreak)
        _CircleBtn(
          gradTop: _oliveLt, gradBot: _olive,
          borderColor: _oliveDk, shadowColor: _oliveDk,
          icon: Icons.skip_next_rounded, size: 64, iconSize: 30,
          onTap: _skipBreak)
      else
        _CircleBtn(
          gradTop: const Color(0xFFFFE888), gradBot: _goldHdr,
          borderColor: _goldDk, shadowColor: _goldDk,
          icon: Icons.pause_rounded, size: 64, iconSize: 28,
          onTap: _pauseTimer),
      const SizedBox(width: 14),
      _CircleBtn(
        gradTop: _coralLt, gradBot: _coralHdr,
        borderColor: const Color(0xFFD08878),
        shadowColor: const Color(0xFFD08878),
        icon: Icons.stop_rounded, size: 64, iconSize: 28,
        onTap: _stopTimer),
    ]);

    Widget statCard({
      required IconData icon, required String value,
      required String label, required Color bg, required Color iconColor,
    }) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(0.15),
            offset: const Offset(0, 2.5), blurRadius: 0)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 7),
              Expanded(child: Text(label.toUpperCase(),
                style: GoogleFonts.nunito(
                  fontSize: 10, fontWeight: FontWeight.w900,
                  letterSpacing: 0.9, color: _inkSoft),
                overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 9),
            Text(value, style: const TextStyle(
              fontFamily: 'Bitroad', fontSize: 25, color: _brown, height: 1.0)),
          ]),
      );
    }

    Widget xpMeter() => Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(
          color: _outline.withOpacity(0.15),
          offset: const Offset(0, 2.5), blurRadius: 0)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('LVL $level', style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w900,
            color: _oliveDk, letterSpacing: 1.1)),
          const SizedBox(width: 9),
          Expanded(child: Text(
            '${((1 - lvlFrac) * 100).round()} XP to next',
            style: GoogleFonts.nunito(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _inkSoft, letterSpacing: 0.3))),
          Text('$xpEst', style: const TextStyle(
            fontFamily: 'Bitroad', fontSize: 17, color: _brown)),
          const SizedBox(width: 4),
          Text('xp', style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: _brownLt, letterSpacing: 0.4)),
        ]),
        const SizedBox(height: 10),
        Stack(children: [
          Container(height: 6,
            decoration: BoxDecoration(
              color: _outline.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3))),
          FractionallySizedBox(widthFactor: lvlFrac, child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: _olive,
              borderRadius: BorderRadius.circular(3)))),
        ]),
      ]),
    );

    Widget notesBtn() => GestureDetector(
      onTap: _openNotesModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              _skyLt.withOpacity(0.6),
              _cardFill.withOpacity(0.72),
            ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _skyHdr.withOpacity(0.32), width: 1.5),
          boxShadow: [BoxShadow(
            color: _skyHdr.withOpacity(0.16),
            offset: const Offset(0, 2.5), blurRadius: 0)]),
        child: Row(children: [
          Icon(Icons.edit_note_rounded, size: 19, color: _skyDk),
          const SizedBox(width: 10),
          Expanded(child: Text(
            _notesCtrl.text.trim().isEmpty ? 'Open notes' : 'Edit notes',
            style: const TextStyle(
              fontFamily: 'Bitroad', fontSize: 15,
              color: _brown, letterSpacing: 0.2))),
          if (_notesCtrl.text.trim().isNotEmpty)
            Text('${_notesCtrl.text.trim().length}',
              style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _inkSoft, letterSpacing: 0.3)),
          const SizedBox(width: 7),
          Icon(Icons.chevron_right_rounded, size: 16,
            color: _brownLt.withOpacity(0.5)),
        ]),
      ),
    );

    Widget ambientChip() => GestureDetector(
      onTap: _stopAmbient,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(0.14),
            offset: const Offset(0, 2.5), blurRadius: 0)]),
        child: Row(children: [
          Icon(_ambientIcon(_ambientSound), size: 16, color: _skyDk),
          const SizedBox(width: 9),
          Expanded(child: Text(_ambientLabel(_ambientSound),
            style: const TextStyle(
              fontFamily: 'Bitroad', fontSize: 15,
              color: _brown, letterSpacing: 0.2))),
          Icon(Icons.close_rounded, size: 15,
            color: _brownLt.withOpacity(0.55)),
        ]),
      ),
    );

    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth > 820;
      // On wide screens we constrain to 1280 for balance; center gets ~45%
      final cw = wide ? math.min(c.maxWidth, 1280.0) : c.maxWidth;
      final centerW = wide ? cw * 0.45 : cw;
      final ringSize = wide
          ? (centerW * 0.82).clamp(340.0, 460.0)
          : (cw * 0.68).clamp(240.0, 320.0);

      Widget subjectCard() {
        final title = (_titleCtrl.text.trim().isEmpty)
            ? 'Untitled thread'
            : _titleCtrl.text.trim();
        final sub = _selectedSubjectName ?? 'No subject';
        final dot = _parseColor(_selectedSubjectColor) ?? _olive;
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            // Purple wash — books / context vibe
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                _purpleLt.withOpacity(0.45),
                _cardFill.withOpacity(0.6),
              ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _purpleDk.withOpacity(0.22), width: 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.bookmark_rounded, size: 14, color: _purpleDk),
              const SizedBox(width: 7),
              Text('WORKING ON', style: GoogleFonts.nunito(
                fontSize: 10.5, fontWeight: FontWeight.w900,
                color: _purpleDk, letterSpacing: 1.4)),
            ]),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(
              fontFamily: 'Bitroad', fontSize: 17,
              color: _brown, height: 1.15),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 11),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: _selectedSubjectName == null
                  ? _outline.withOpacity(0.25) : dot,
                shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Flexible(child: Text(sub, style: GoogleFonts.gaegu(
                fontSize: 15, fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: _brownLt), overflow: TextOverflow.ellipsis)),
            ]),
          ]),
        );
      }

      Widget tempoCard() {
        final elapsedMin = _totalStudiedSec ~/ 60;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            // Coral pink wash — heartbeat / pulse vibe
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                _coralLt.withOpacity(0.55),
                _cardFill.withOpacity(0.6),
              ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _coralHdr.withOpacity(0.25), width: 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.favorite_rounded, size: 14, color: _coralHdr),
              const SizedBox(width: 7),
              Text('SESSION TEMPO', style: GoogleFonts.nunito(
                fontSize: 10.5, fontWeight: FontWeight.w900,
                color: _coralHdr, letterSpacing: 1.4)),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$elapsedMin', style: const TextStyle(
                fontFamily: 'Bitroad', fontSize: 38, color: _brown, height: 1)),
              const SizedBox(width: 5),
              Padding(padding: const EdgeInsets.only(bottom: 5),
                child: Text('min in', style: GoogleFonts.nunito(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt))),
              const Spacer(),
              if (_streakCount > 0) Padding(padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  Icon(Icons.local_fire_department_rounded,
                    size: 14, color: _coralHdr.withOpacity(0.85)),
                  const SizedBox(width: 4),
                  Text('day $_streakCount', style: GoogleFonts.nunito(
                    fontSize: 12, fontWeight: FontWeight.w800, color: _brown,
                    letterSpacing: 0.2)),
                ])),
            ]),
            const SizedBox(height: 6),
            Text(
              _isBreakPhase
                ? 'breath the thread loose for a moment'
                : _pomodoroCount >= 2
                  ? 'you\'ve crossed $_pomodoroCount pomos today'
                  : 'settle in — the page is listening',
              style: GoogleFonts.gaegu(fontSize: 14,
                fontWeight: FontWeight.w500, fontStyle: FontStyle.italic,
                color: _brownLt, height: 1.3)),
          ]),
        );
      }

      if (wide) {
        // Desktop: left stats column | center timer | right workspace column
        final body = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // LEFT — stats + meta
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              sec('Session Stats', Icons.insights_rounded,
                accent: _pinkHdr, sub: 'how it\'s going'),
              Row(children: [
                Expanded(child: statCard(
                  icon: Icons.timer_rounded,
                  value: _fmtMin(_totalStudiedSec), label: 'Studied',
                  bg: const Color(0xFFFFD5F5).withOpacity(0.45),
                  iconColor: _pinkHdr)),
                const SizedBox(width: 10),
                Expanded(child: statCard(
                  icon: Icons.repeat_rounded,
                  value: '$_pomodoroCount', label: 'Pomos',
                  bg: _oliveBg, iconColor: _oliveDk)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: statCard(
                  icon: Icons.bolt_rounded,
                  value: '$xpEst', label: 'XP Earned',
                  bg: const Color(0xFFFDEFDB).withOpacity(0.65),
                  iconColor: _goldDk)),
                const SizedBox(width: 10),
                Expanded(child: statCard(
                  icon: Icons.notifications_active_rounded,
                  value: '$_distractionCount', label: 'Flags',
                  bg: _purpleLt.withOpacity(0.4),
                  iconColor: _purpleDk)),
              ]),
              const SizedBox(height: 12),
              xpMeter(),
              const SizedBox(height: 18),
              sec('Context', Icons.menu_book_rounded,
                accent: _purpleDk, sub: 'what you\'re on'),
              subjectCard(),
            ]),
          ),
          const SizedBox(width: 32),
          // CENTER — ring + pill + controls
          Expanded(flex: 5, child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(height: 8),
              phasePill(),
              const SizedBox(height: 26),
              timerRing(ringSize),
              const SizedBox(height: 30),
              controls(),
              const SizedBox(height: 26),
              // Breathing caption under controls — keeps vertical balance
              Text(
                _isBreakPhase
                  ? 'Rest is part of the work.'
                  : _phase == _Phase.paused
                    ? 'Paused — resume when ready.'
                    : 'One thread. Gentle pressure.',
                style: GoogleFonts.gaegu(fontSize: 16,
                  fontWeight: FontWeight.w500, fontStyle: FontStyle.italic,
                  color: _inkSoft, letterSpacing: 0.2)),
            ]),
          ),
          const SizedBox(width: 32),
          // RIGHT — workspace + tempo + quiet nudge
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              sec('Workspace', Icons.workspaces_rounded,
                accent: _skyHdr, sub: 'your tools'),
              notesBtn(),
              if (_ambientSound != 'none') ...[
                const SizedBox(height: 10),
                ambientChip(),
              ],
              const SizedBox(height: 18),
              sec('Pulse', Icons.favorite_rounded,
                accent: _coralHdr, sub: 'the rhythm'),
              tempoCard(),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                child: Text(
                  _isBreakPhase
                      ? 'Stretch. Breathe. Rest your eyes —\nyou\'ve earned it.'
                      : _distractionCount > 2
                          ? 'Close the extra tabs.\nOne thread at a time.'
                          : 'Settle in. Your future self\nis rooting for you.',
                  style: GoogleFonts.gaegu(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: _brownLt, height: 1.5)),
              ),
            ]),
          ),
        ]);

        //   screen: leftover viewport space is redistributed above
        //   and below the body (2:1) so the columns float in the
        //   lower-middle of the page instead of hugging the hero.
        //   The Column owns the tight vertical constraints; Center
        //   wraps the Row so its horizontal max-width cap still works.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 2),
            Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: body,
            )),
            const Spacer(flex: 1),
          ],
        );
      }

      return Column(children: [
        const SizedBox(height: 4),
        phasePill(),
        const SizedBox(height: 14),
        timerRing(ringSize),
        const SizedBox(height: 16),
        controls(),
        const SizedBox(height: 14),
        // XP meter
        xpMeter(),
        const SizedBox(height: 10),
        // Stats 2x2
        Row(children: [
          Expanded(child: statCard(
            icon: Icons.timer_rounded,
            value: _fmtMin(_totalStudiedSec), label: 'Studied',
            bg: const Color(0xFFFFD5F5).withOpacity(0.45),
            iconColor: _pinkHdr)),
          const SizedBox(width: 8),
          Expanded(child: statCard(
            icon: Icons.repeat_rounded,
            value: '$_pomodoroCount', label: 'Pomos',
            bg: _oliveBg, iconColor: _oliveDk)),
          const SizedBox(width: 8),
          Expanded(child: statCard(
            icon: Icons.bolt_rounded,
            value: '$xpEst', label: 'XP',
            bg: const Color(0xFFFDEFDB).withOpacity(0.65),
            iconColor: _goldDk)),
          if (_distractionCount > 0) ...[
            const SizedBox(width: 8),
            Expanded(child: statCard(
              icon: Icons.notifications_active_rounded,
              value: '$_distractionCount', label: 'Flags',
              bg: _purpleLt.withOpacity(0.4),
              iconColor: _purpleDk)),
          ],
        ]),
        const SizedBox(height: 10),
        // Notes + ambient row
        Row(children: [
          Expanded(child: notesBtn()),
          if (_ambientSound != 'none') ...[
            const SizedBox(width: 8),
            Expanded(child: ambientChip()),
          ],
        ]),
        const SizedBox(height: 6),
      ]);
    });
  }

  IconData _ambientIcon(String s) {
    switch (s) {
      case 'rain': return Icons.water_drop_rounded;
      case 'lofi': return Icons.headphones_rounded;
      case 'cafe': return Icons.local_cafe_rounded;
      case 'ocean': return Icons.waves_rounded;
      case 'fire': return Icons.local_fire_department_rounded;
      case 'birds': return Icons.park_rounded;
      default: return Icons.volume_off_rounded;
    }
  }

  String _ambientLabel(String s) {
    switch (s) {
      case 'rain': return 'Rain';
      case 'lofi': return 'Lo-fi';
      case 'cafe': return 'Café';
      case 'ocean': return 'Ocean';
      case 'fire': return 'Fireplace';
      case 'birds': return 'Birds';
      default: return 'Off';
    }
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Expanded(child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(value, style: GoogleFonts.gaegu(
          fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
      ]),
      Text(label, style: GoogleFonts.nunito(
        fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt)),
    ]));
  }

  void _openNotesModal() {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: _outline.withOpacity(0.28),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, __) => FadeTransition(
        opacity: anim,
        child: _NotesEditorRoute(
          notesCtrl: _notesCtrl,
          topicCtrl: _topicCtrl,
          topics: _topics,
          bold: _bold,
          italic: _italic,
          onBoldChange: (v) => setState(() => _bold = v),
          onItalicChange: (v) => setState(() => _italic = v),
          onTopicsChange: () => setState(() {}),
          onExportPdf: _exportNotesPdf,
          onRefresh: () => setState(() {}),
          sessionTitle: _titleCtrl.text.trim().isEmpty
              ? 'Untitled Session' : _titleCtrl.text.trim(),
          subjectName: _selectedSubjectName,
          subjectColor: _parseColor(_selectedSubjectColor),
          studiedMin: _totalStudiedSec ~/ 60,
          sessionType: _sessionType,
        ),
      ),
    ));
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.1),
          offset: const Offset(0, 3), blurRadius: 0)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _goldHdr.withOpacity(0.3),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _goldDk.withOpacity(0.5), width: 1.3)),
            child: Icon(Icons.sticky_note_2_rounded, size: 15, color: _brown)),
          const SizedBox(width: 10),
          Text('Session Notes', style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w700, color: _brown)),
          const Spacer(),
          GestureDetector(
            onTap: _exportNotesPdf,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _coralLt.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _coralHdr, width: 1.2),
                boxShadow: [BoxShadow(color: _coralHdr.withOpacity(0.2),
                  offset: const Offset(0, 1.5), blurRadius: 0)]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.picture_as_pdf_rounded, size: 13, color: _coralHdr),
                const SizedBox(width: 4),
                Text('PDF', style: GoogleFonts.gaegu(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        Row(children: [
          Icon(Icons.tag_rounded, size: 13, color: _purpleDk),
          const SizedBox(width: 6),
          Text('Topics', style: GoogleFonts.gaegu(
            fontSize: 13, fontWeight: FontWeight.w700, color: _brownLt)),
        ]),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline.withOpacity(0.15), width: 1.2)),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            ..._topics.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _purpleLt.withOpacity(0.5), _purpleHdr.withOpacity(0.3)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _purpleHdr.withOpacity(0.4), width: 1)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t, style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _brown)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _topics.remove(t)),
                  child: Icon(Icons.close_rounded, size: 12,
                    color: _purpleDk.withOpacity(0.6))),
              ]),
            )),
            SizedBox(width: 120, height: 26, child: TextField(
              controller: _topicCtrl,
              style: GoogleFonts.nunito(fontSize: 11,
                color: _brown, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '+ add topic',
                hintStyle: GoogleFonts.nunito(fontSize: 11,
                  color: _brownLt.withOpacity(0.5)),
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  setState(() { _topics.add(v.trim()); _topicCtrl.clear(); });
                }
              },
            )),
          ]),
        ),
        const SizedBox(height: 14),

        Row(children: [
          Icon(Icons.edit_rounded, size: 13, color: _goldDk),
          const SizedBox(width: 6),
          Text('Notes', style: GoogleFonts.gaegu(
            fontSize: 13, fontWeight: FontWeight.w700, color: _brownLt)),
          const Spacer(),
          _fmtBtn(Icons.format_bold_rounded, _bold,
            () => setState(() => _bold = !_bold)),
          const SizedBox(width: 4),
          _fmtBtn(Icons.format_italic_rounded, _italic,
            () => setState(() => _italic = !_italic)),
          const SizedBox(width: 4),
          _fmtBtn(Icons.format_list_bulleted_rounded, false, () {
            final t = _notesCtrl.text;
            final ins = t.isEmpty || t.endsWith('\n') ? '• ' : '\n• ';
            _notesCtrl.text = t + ins;
            _notesCtrl.selection = TextSelection.collapsed(
              offset: _notesCtrl.text.length);
          }),
          const SizedBox(width: 4),
          _fmtBtn(Icons.format_list_numbered_rounded, false, () {
            final lines = _notesCtrl.text.split('\n');
            final n = lines.where((l) => RegExp(r'^\d+\.').hasMatch(l)).length + 1;
            final ins = _notesCtrl.text.isEmpty || _notesCtrl.text.endsWith('\n')
                ? '$n. ' : '\n$n. ';
            _notesCtrl.text = _notesCtrl.text + ins;
            _notesCtrl.selection = TextSelection.collapsed(
              offset: _notesCtrl.text.length);
          }),
          const SizedBox(width: 4),
          _fmtBtn(Icons.title_rounded, false, () {
            final ins = _notesCtrl.text.isEmpty || _notesCtrl.text.endsWith('\n')
                ? '## ' : '\n## ';
            _notesCtrl.text = _notesCtrl.text + ins;
            _notesCtrl.selection = TextSelection.collapsed(
              offset: _notesCtrl.text.length);
          }),
        ]),
        const SizedBox(height: 8),

        Container(
          constraints: const BoxConstraints(minHeight: 130, maxHeight: 240),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline.withOpacity(0.15), width: 1.2)),
          child: TextField(
            controller: _notesCtrl,
            style: GoogleFonts.nunito(
              fontSize: 14, color: _brown, height: 1.6,
              fontWeight: _bold ? FontWeight.w700 : FontWeight.w500,
              fontStyle: _italic ? FontStyle.italic : FontStyle.normal),
            maxLines: null, minLines: 5,
            decoration: InputDecoration(
              hintText: 'Key takeaways, formulas, ideas...',
              hintStyle: GoogleFonts.nunito(fontSize: 13,
                color: _brownLt.withOpacity(0.4), height: 1.6),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14)),
          ),
        ),
      ]),
    );
  }

  Widget _fmtBtn(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 28,
        decoration: BoxDecoration(
          color: active ? _pinkHdr.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active ? _pinkHdr.withOpacity(0.3) : _outline.withOpacity(0.08),
            width: 1)),
        child: Icon(icon, size: 14,
          color: active ? _pinkHdr : _brownLt.withOpacity(0.5)),
      ),
    );
  }

  //  3. COMPLETION PHASE
  Widget _buildCompletion({bool desktop = false}) {
    final mins = (_totalStudiedSec / 60).ceil();
    final baseXp = (mins / 30 * 25).floor();
    final bonusXp = _focusScore >= 80 ? (baseXp * 0.25).floor() : 0;

    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth > 720;

      final hero = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(
                color: _oliveDk, shape: BoxShape.circle)),
              const SizedBox(width: 11),
              Text('YOU STUDIED FOR', style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: _oliveDk, letterSpacing: 1.8)),
              const SizedBox(width: 12),
              Flexible(child: Text('what a session',
                style: GoogleFonts.gaegu(
                  fontSize: 17, fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic, color: _brownLt),
                overflow: TextOverflow.ellipsis)),
            ]),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$mins', style: const TextStyle(
              fontFamily: 'Bitroad', fontSize: 112, color: _brown, height: 0.92)),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('min', style: GoogleFonts.nunito(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: _brownLt, letterSpacing: 0.3)),
            ),
            const Spacer(),
            if (_streakCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_fire_department_rounded,
                    size: 20, color: _goldDk),
                  const SizedBox(width: 7),
                  Text('$_streakCount-day streak',
                    style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: _brownLt, letterSpacing: 0.3)),
                ]),
              ),
          ]),
          Row(children: [
            Icon(_typeIcon(_sessionType), size: 19,
              color: _typeColor(_sessionType)),
            const SizedBox(width: 9),
            Text(
              _sessionType[0].toUpperCase() + _sessionType.substring(1),
              style: GoogleFonts.nunito(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: _brown, letterSpacing: 0.3)),
            if (_titleCtrl.text.trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('·', style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w900,
                  color: _outline.withOpacity(0.4)))),
              Flexible(child: Text(_titleCtrl.text.trim(),
                style: GoogleFonts.nunito(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic, color: _inkSoft),
                overflow: TextOverflow.ellipsis, maxLines: 1)),
            ],
          ]),
        ]);

      final summary = Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              _pinkLt.withOpacity(0.4),
              _cardFill.withOpacity(0.7),
            ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _pinkHdr.withOpacity(0.32), width: 1.5),
          boxShadow: [BoxShadow(
            color: _pinkHdr.withOpacity(0.16),
            offset: const Offset(0, 3), blurRadius: 0)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(
                color: _pinkHdr, shape: BoxShape.circle)),
              const SizedBox(width: 11),
              Text('THE NUMBERS', style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: _pinkHdr, letterSpacing: 1.8)),
              const SizedBox(width: 12),
              Flexible(child: Text('tiny wins, written down',
                style: GoogleFonts.gaegu(
                  fontSize: 17, fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic, color: _brownLt),
                overflow: TextOverflow.ellipsis)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _summaryRow(Icons.timer_rounded, 'Time',
                  '$mins min', _pinkHdr),
                _summaryRow(Icons.repeat_rounded, 'Pomodoros',
                  '$_pomodoroCount', _greenHdr),
                if (_selectedSubjectName != null)
                  _summaryRow(Icons.menu_book_rounded, 'Subject',
                    _selectedSubjectName!, _purpleHdr),
                if (_topics.isNotEmpty)
                  _summaryRow(Icons.tag_rounded, 'Topics',
                    _topics.length == 1 ? _topics.first : '${_topics.length} tags',
                    _skyHdr),
                if (_distractionCount > 0)
                  _summaryRow(Icons.notifications_active_rounded, 'Distractions',
                    '$_distractionCount', _coralHdr),
              ]),
          ]),
      );

      final focusCard = Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              _skyLt.withOpacity(0.45),
              _cardFill.withOpacity(0.75),
            ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _skyHdr.withOpacity(0.32), width: 1.5),
          boxShadow: [BoxShadow(
            color: _skyHdr.withOpacity(0.16),
            offset: const Offset(0, 3), blurRadius: 0)]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(
                      color: _skyHdr, shape: BoxShape.circle)),
                    const SizedBox(width: 11),
                    Text('HOW FOCUSED', style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w900,
                      color: _skyHdr, letterSpacing: 1.8)),
                  ]),
                  const SizedBox(height: 6),
                  Text('be honest — no judgement',
                    style: GoogleFonts.gaegu(
                      fontSize: 16, fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic, color: _brownLt)),
                ])),
              Text('$_focusScore', style: TextStyle(
                fontFamily: 'Bitroad', fontSize: 44,
                color: _focusColor(_focusScore), height: 1.0)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('%', style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: _focusColor(_focusScore))),
              ),
            ]),
            // Distraction-based focus cap: the more times the user got
            // pulled away, the lower the ceiling they can claim. We compute
            // it once per build so every control agrees on the same cap.
            Builder(builder: (_) {
              final maxFocus = _maxFocusForDistractions();
              // If a previous build left `_focusScore` above the cap (e.g.
              // distractions just landed from the server), clip it silently.
              if (_focusScore > maxFocus) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _focusScore = maxFocus);
                });
              }
              final distractions = ref.watch(studySessionProvider).distractions;
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [20, 40, 60, 80, 100].map((v) {
                    final locked = v > maxFocus;
                    final sel = !locked && (_focusScore - v).abs() < 10;
                    return GestureDetector(
                      onTap: locked
                          ? () => _nudgeCapTooltip(maxFocus, distractions)
                          : () => setState(() => _focusScore = v),
                      child: Opacity(
                        opacity: locked ? 0.35 : 1.0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: sel ? 54 : 44, height: sel ? 54 : 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? _focusColor(v).withOpacity(0.18)
                                : Colors.transparent,
                            border: sel ? Border.all(
                              color: _focusColor(v), width: 1.8) : null),
                          child: CustomPaint(painter: _FacePainter(
                            score: v,
                            color: sel ? _focusColor(v)
                                : _brownLt.withOpacity(0.4),
                            size: sel ? 54 : 44)),
                        ),
                      ),
                    );
                  }).toList()),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _focusColor(_focusScore),
                    inactiveTrackColor: _outline.withOpacity(0.1),
                    thumbColor: _focusColor(_focusScore),
                    overlayColor: _focusColor(_focusScore).withOpacity(0.15),
                    trackHeight: 7,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 13)),
                  child: Slider(
                    value: _focusScore.toDouble().clamp(1.0,
                        maxFocus.toDouble()),
                    min: 1, max: 100,
                    // The slider's visual max is 100 so the track shows the
                    // cap as an off-limits region rather than hiding it —
                    // but any drag past the cap snaps back. We also fire a
                    // tooltip the first time the user hits the wall so it
                    // doesn't feel like a bug.
                    onChanged: (v) {
                      final rounded = v.round();
                      if (rounded > maxFocus) {
                        _nudgeCapTooltip(maxFocus, distractions);
                        setState(() => _focusScore = maxFocus);
                      } else {
                        setState(() => _focusScore = rounded);
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Distracted', style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: _brownLt)),
                      if (_focusScore >= 80)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.bolt_rounded, size: 16, color: _greenDk),
                          const SizedBox(width: 5),
                          Text('+25% XP bonus', style: GoogleFonts.nunito(
                            fontSize: 14, fontWeight: FontWeight.w800,
                            color: _greenDk)),
                        ])
                      else
                        Text('Laser focus', style: GoogleFonts.nunito(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _brownLt)),
                    ]),
                ),
                // Cap hint — only renders when distractions > 0 so it
                // doesn't clutter clean runs.
                if (distractions > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8C9).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _outline.withOpacity(0.22), width: 1),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 15,
                          color: _brownLt),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$distractions distraction'
                          '${distractions == 1 ? '' : 's'} — max focus '
                          'capped at $maxFocus%',
                          style: GoogleFonts.gaegu(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: _brown),
                        ),
                      ),
                    ]),
                  ),
                ],
              ]);
            }),
          ]),
      );

      final notesBtn = GestureDetector(
        onTap: _openNotesModal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
            boxShadow: [BoxShadow(
              color: _outline.withOpacity(0.16),
              offset: const Offset(0, 2.5), blurRadius: 0)]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.edit_note_rounded, size: 22, color: _oliveDk),
            const SizedBox(width: 11),
            Text(_notesCtrl.text.trim().isEmpty
                ? 'Add notes' : 'View notes',
              style: const TextStyle(
                fontFamily: 'Bitroad', fontSize: 18,
                color: _brown, letterSpacing: 0.2)),
          ]),
        ),
      );

      final xpBanner = _saved ? AnimatedBuilder(
        animation: _xpCtrl,
        builder: (_, __) {
          final t = Curves.easeOutBack.transform(_xpCtrl.value);
          return Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFDEFDB).withOpacity(0.92),
                    const Color(0xFFFFF6E4).withOpacity(0.7),
                  ]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _goldDk.withOpacity(0.28), width: 1.5),
                boxShadow: [BoxShadow(
                  color: _goldDk.withOpacity(0.18),
                  offset: const Offset(0, 3), blurRadius: 0)]),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                    Text('XP EARNED', style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w900,
                      color: _goldDk, letterSpacing: 1.4)),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('+${_xpEarned > 0 ? _xpEarned : baseXp + bonusXp}',
                        style: const TextStyle(
                          fontFamily: 'Bitroad', fontSize: 38,
                          color: _brown, height: 0.95)),
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text('xp', style: GoogleFonts.nunito(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: _brownLt)),
                      ),
                    ]),
                  ]),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min, children: [
                    Text('base $baseXp', style: GoogleFonts.nunito(
                      fontSize: 12.5, fontWeight: FontWeight.w700,
                      color: _inkSoft)),
                    if (bonusXp > 0) ...[
                      const SizedBox(height: 4),
                      Text('+$bonusXp focus bonus',
                        style: GoogleFonts.nunito(
                          fontSize: 12.5, fontWeight: FontWeight.w800,
                          color: _oliveDk)),
                    ],
                  ]),
              ]),
            ),
          ));
        },
      ) : const SizedBox.shrink();

      final primaryBtn = !_saved
          ? _GameButton(
              icon: Icons.save_rounded,
              label: _saving ? 'Saving...' : 'Save Session',
              gradTop: _oliveLt, gradBot: _olive,
              borderColor: _oliveDk, loading: _saving,
              onTap: _saveSession)
          : _GameButton(
              icon: Icons.check_rounded,
              label: 'Done',
              gradTop: _oliveLt, gradBot: _olive,
              borderColor: _oliveDk,
              onTap: () {
                ref.read(dashboardProvider.notifier).refresh();
                ref.read(studyProvider.notifier).refresh();
                Navigator.pop(context);
              });

      final discardBtn = !_saved ? GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
            boxShadow: [BoxShadow(
              color: _outline.withOpacity(0.14),
              offset: const Offset(0, 2.5), blurRadius: 0)]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Discard', style: const TextStyle(
              fontFamily: 'Bitroad', fontSize: 18,
              color: _brownLt, letterSpacing: 0.3)),
          ]),
        ),
      ) : const SizedBox.shrink();

      // Silence unused local (kept for legacy callers)
      // ignore: unused_local_variable
      final _ignoredWide = wide;

      final actionsRow = Row(children: [
        if (!_saved) ...[
          Expanded(flex: 3, child: discardBtn),
          const SizedBox(width: 10),
          Expanded(flex: 7, child: primaryBtn),
        ] else
          Expanded(child: primaryBtn),
      ]);

      if (desktop) {
        // DESKTOP — 3-row layout (was 2-column with spaceBetween).
        //
        // The old 2-column grid paired hero↕mood↕notes on the left with
        // summary↕focus↕actions on the right, then used spaceBetween
        // to stretch the gaps. Because the right column had much more
        // content than the left, the left column's gaps had to grow
        // enormous to balance — that's the "hollow card" feeling.
        //
        // New layout pairs cards HORIZONTALLY so each row's two cards
        // have similar natural heights (hero↔summary, mood↔focus):
        //   Row 1: hero (olive) | summary (pink)     — meta + numbers
        //   Row 2: mood (coral) | focus (sky)        — how it felt
        //   Row 3 (optional):  xp banner            — if saved
        //   Row 4: notes + discard + save            — inline actions
        // Weighted Spacer top/bottom centers the stack a little low.

        //   IntrinsicHeight gives the Row a definite cross-axis size
        //   (max of child intrinsic heights), so CrossAxisAlignment
        //   .stretch can actually stretch children. Without it the
        //   Row inherits the Column's unbounded vertical constraint
        //   (since the Column uses Spacer-based layout), and stretch
        //   fails with a `RenderBox was not laid out` assertion.
        final topRow = IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: _sectionCard(
              tint: _oliveDk,
              tintSoft: _oliveBg,
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 30),
              child: hero)),
            const SizedBox(width: 18),
            Expanded(flex: 5, child: summary),
          ]));

        final midRow = IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildMoodCard()),
            const SizedBox(width: 18),
            Expanded(child: focusCard),
          ]));

        final bottomStrip = !_saved
          ? Row(children: [
              Expanded(flex: 4, child: notesBtn),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: discardBtn),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: primaryBtn),
            ])
          : Row(children: [
              Expanded(flex: 4, child: notesBtn),
              const SizedBox(width: 10),
              Expanded(flex: 6, child: primaryBtn),
            ]);

        // Desktop layout strategy:
        //   Expanded SingleChildScrollView holds the cards — so if the
        //   viewport is short (laptop, zoomed UI) the content scrolls
        //   gracefully instead of producing a RenderFlex overflow. The
        //   action strip stays pinned at the bottom via a sibling slot,
        //   so "Save Session" is always reachable without scrolling past
        //   the stats cards.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tightened spacings (was 28 / 18) so the four cards +
                    //   topic picker fit a typical 13"–14" laptop viewport
                    //   without invoking the scroll bar at all.
                    const SizedBox(height: 18),
                    _stag(0.02, topRow),
                    const SizedBox(height: 14),
                    _stag(0.10, midRow),
                    // Topic picker card — only shown pre-save so users commit to
                    //   their tags before the session is persisted.
                    if (!_saved) ...[
                      const SizedBox(height: 14),
                      _stag(0.12, _buildCompletionTopicsCard()),
                    ],
                    if (_saved) ...[
                      const SizedBox(height: 14),
                      _stag(0.14, xpBanner),
                    ],
                    const SizedBox(height: 12),
                  ]),
              ),
            ),
            _stag(0.18, bottomStrip),
          ]);
      }

      // NARROW — vertical card stack
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _stag(0.00, _sectionCard(
          tint: _oliveDk,
          tintSoft: _oliveBg,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: hero)),
        const SizedBox(height: 14),
        _stag(0.05, summary),
        const SizedBox(height: 14),
        _stag(0.09, focusCard),
        const SizedBox(height: 14),
        _stag(0.13, _buildMoodCard()),
        // Topic picker — only while the session is still saveable; once
        //   saved, the tags are baked in and this card would be clutter.
        if (!_saved) ...[
          const SizedBox(height: 14),
          _stag(0.15, _buildCompletionTopicsCard()),
        ],
        const SizedBox(height: 14),
        _stag(0.16, notesBtn),
        if (_saved) ...[
          const SizedBox(height: 14),
          _stag(0.20, xpBanner),
        ],
        const SizedBox(height: 16),
        _stag(0.22, actionsRow),
        const SizedBox(height: 6),
      ]);
    });
  }

  Color _focusColor(int score) {
    if (score >= 80) return _greenHdr;
    if (score >= 60) return _goldHdr;
    if (score >= 40) return const Color(0xFFE8A870);
    return _coralHdr;
  }

  Widget _summaryRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.nunito(
          fontSize: 15, fontWeight: FontWeight.w800, color: _inkSoft,
          letterSpacing: 0.4)),
        const Spacer(),
        Flexible(child: Text(value, style: const TextStyle(
          fontFamily: 'Bitroad', fontSize: 20, color: _brown),
          textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  // Session Wrapped: offer one-tap topic tagging drawn from the
  // subject's curated topic list. If no subject is selected yet,
  // prompt the user to pick one. Free-form "+ add topic" entry
  // remains so users can coin new topics on the fly — these
  // auto-persist on the next session save (the backend's topic
  // auto-create handles the rest).
  Widget _buildCompletionTopicsCard() {
    final hasSubject = _selectedSubjectId != null;
    return Container(
      width: double.infinity,
      // Tighter padding than original (was 24/22) so the card doesn't
      //   dominate the Wrapped layout — every saved pixel here means
      //   the action strip stays comfortably visible without scroll.
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            _purpleLt.withOpacity(0.3),
            _cardFill.withOpacity(0.72),
          ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purpleHdr.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(
          color: _purpleHdr.withOpacity(0.16),
          offset: const Offset(0, 3), blurRadius: 0)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(
            color: _purpleDk, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text('WHAT YOU COVERED', style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w900,
            color: _purpleDk, letterSpacing: 1.6)),
          const SizedBox(width: 10),
          Flexible(child: Text('tag it — smarter quizzes later',
            style: GoogleFonts.gaegu(
              fontSize: 14, fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic, color: _brownLt),
            overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 10),

        GestureDetector(
          onTap: _showSubjectSheet,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _outline.withOpacity(hasSubject ? 0.24 : 0.34),
                width: 1.3)),
            child: Row(children: [
              if (hasSubject) ...[
                Container(width: 11, height: 11, decoration: BoxDecoration(
                  color: _parseColor(_selectedSubjectColor) ?? _greenHdr,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _outline.withOpacity(0.3), width: 1))),
                const SizedBox(width: 10),
                Expanded(child: Text(_selectedSubjectName!,
                  style: GoogleFonts.nunito(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _brown))),
                Text('change', style: GoogleFonts.gaegu(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: _purpleDk,
                  decoration: TextDecoration.underline,
                  decorationColor: _purpleDk.withOpacity(0.5))),
              ] else ...[
                Icon(Icons.folder_outlined, size: 16,
                  color: _brownLt.withOpacity(0.6)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Tag a subject — helps sort this session',
                  style: GoogleFonts.nunito(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _brownLt.withOpacity(0.75)))),
                Icon(Icons.add_circle_outline_rounded, size: 18,
                  color: _purpleDk),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 10),

        if (hasSubject) ...[
          if (_subjectTopicsLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 13, height: 13, child: CircularProgressIndicator(
                  strokeWidth: 2, color: _purpleDk)),
                const SizedBox(width: 9),
                Text('Loading topics...', style: GoogleFonts.nunito(
                  fontSize: 12, color: _brownLt,
                  fontWeight: FontWeight.w600)),
              ]))
          else if (_subjectTopics.isNotEmpty) ...[
            Text('PICK FROM', style: GoogleFonts.nunito(
              fontSize: 9.5, fontWeight: FontWeight.w900,
              color: _purpleDk.withOpacity(0.85), letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Wrap(spacing: 7, runSpacing: 7,
              children: _subjectTopics.map((t) {
                final name = t['name']?.toString() ?? '';
                if (name.isEmpty) return const SizedBox.shrink();
                final sel = _topics.contains(name);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (sel) {
                        _topics.remove(name);
                      } else {
                        _topics.add(name);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: sel
                        ? LinearGradient(colors: [
                            _purpleLt.withOpacity(0.85),
                            _purpleHdr.withOpacity(0.65),
                          ])
                        : null,
                      color: sel ? null : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                          ? _purpleDk.withOpacity(0.55)
                          : _outline.withOpacity(0.22),
                        width: sel ? 1.6 : 1.2),
                      boxShadow: sel ? [BoxShadow(
                        color: _purpleDk.withOpacity(0.22),
                        offset: const Offset(1.5, 1.5),
                        blurRadius: 0)] : null),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (sel) ...[
                        Icon(Icons.check_rounded, size: 14, color: _brown),
                        const SizedBox(width: 5),
                      ],
                      Text(name, style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        color: _brown)),
                    ]),
                  ),
                );
              }).toList()),
            const SizedBox(height: 10),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No topics yet for this subject — add some below and they\'ll save for next time.',
                style: GoogleFonts.gaegu(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic, color: _brownLt)),
            ),
            const SizedBox(height: 8),
          ],
        ],

        Text(_topics.isEmpty ? 'ADD YOUR OWN' : 'TAGGED',
          style: GoogleFonts.nunito(
            fontSize: 9.5, fontWeight: FontWeight.w900,
            color: _oliveDk, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline.withOpacity(0.18), width: 1.2)),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            ..._topics.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _oliveBg.withOpacity(0.9),
                  _oliveLt.withOpacity(0.55),
                ]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _oliveDk.withOpacity(0.35), width: 1)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t, style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _brown)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _topics.remove(t)),
                  child: Icon(Icons.close_rounded, size: 12,
                    color: _oliveDk.withOpacity(0.6))),
              ]),
            )),
            SizedBox(width: 140, height: 26, child: TextField(
              controller: _topicCtrl,
              style: GoogleFonts.nunito(fontSize: 11,
                color: _brown, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '+ add topic',
                hintStyle: GoogleFonts.nunito(fontSize: 11,
                  color: _brownLt.withOpacity(0.5)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero),
              onSubmitted: (v) {
                final value = v.trim();
                if (value.isNotEmpty && !_topics.contains(value)) {
                  setState(() { _topics.add(value); _topicCtrl.clear(); });
                } else {
                  _topicCtrl.clear();
                }
              },
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _xpChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.45), width: 1.2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label.toUpperCase(), style: GoogleFonts.nunito(
          fontSize: 9, fontWeight: FontWeight.w900,
          color: color, letterSpacing: 0.6)),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(
          fontFamily: 'Bitroad', fontSize: 13, color: _brown)),
      ]),
    );
  }

  // Stagger animation.
  // Passes `child` through AnimatedBuilder so the subtree isn't rebuilt every
  // frame, wraps in RepaintBoundary to isolate paints, and wraps in
  // IgnorePointer while animating so mouse hit-testing doesn't race with the
  // render update. This is the same pattern applied to subjects_screen,
  // take_quiz_screen, resource_screen, and study_calendar_screen — it fixes
  // the `_debugDuringDeviceUpdate` mouse-tracker assertion cascade on desktop.
  Widget _stag(double delay, Widget child) {
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
                  offset: Offset(0, 20 * (1 - t)), child: c),
            ),
          );
        },
      ),
    );
  }

  //    Colors.white.withOpacity(0.88), 18px radius, 1.5px outline @
  //    0.22 opacity, hard 3px-offset shadow with 0 blur. The whole
  //    setup becomes a vertical stack of these so it reads like a
  //    natural extension of the dashboard, not a settings form.
  //    and completion screens speak in the same tinted-card voice as
  //    the study dashboard (pink / sky / olive / gold / purple).
  //    `tint`      = the header/accent hue (pinkHdr, skyHdr, oliveDk, goldDk…)
  //    `tintSoft`  = the softer wash fed to the gradient top-left; falls
  //                  back to a lightened variant of `tint` when omitted.
  //    When no tint is given, the card stays plain cream like the
  //    dashboard's neutral surfaces.
  Widget _sectionCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
    Color? tint,
    Color? tintSoft,
  }) {
    final hasTint = tint != null;
    final softWash = tintSoft ?? (hasTint ? tint.withOpacity(0.35) : null);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        // Dashboard parity: cream base + diagonal (3,3) hard-offset
        // shadow + outline border stronger than before (1.8 / 0.32)
        // so cards read as chunky 3D surfaces, not pastel washes.
        color: hasTint ? null : _cardFill.withOpacity(0.94),
        gradient: hasTint
            ? LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  softWash!.withOpacity(0.6),
                  _cardFill.withOpacity(0.82),
                ])
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasTint
              ? tint.withOpacity(0.42)
              : _outline.withOpacity(0.32),
          width: 1.8),
        boxShadow: [BoxShadow(
          color: hasTint
              ? tint.withOpacity(0.26)
              : _outline.withOpacity(0.24),
          offset: const Offset(3, 3), blurRadius: 0)]),
      child: child,
    );
  }

  Widget _buildMoodCard() {
    final moods = <Map<String, dynamic>>[
      {'k': 'crushed', 'l': 'Crushed',
        'i': Icons.local_fire_department_rounded, 'c': _coralHdr},
      {'k': 'solid',   'l': 'Solid',
        'i': Icons.sentiment_very_satisfied_rounded, 'c': _greenHdr},
      {'k': 'ok',      'l': 'OK',
        'i': Icons.sentiment_satisfied_rounded, 'c': _goldHdr},
      {'k': 'tough',   'l': 'Tough',
        'i': Icons.sentiment_dissatisfied_rounded, 'c': _purpleHdr},
      {'k': 'rough',   'l': 'Rough',
        'i': Icons.sentiment_very_dissatisfied_rounded, 'c': _skyHdr},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            _coralLt.withOpacity(0.4),
            _cardFill.withOpacity(0.7),
          ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _coralHdr.withOpacity(0.26), width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(
              color: _coralHdr, shape: BoxShape.circle)),
            const SizedBox(width: 11),
            Text('HOW DID IT FEEL', style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w900,
              color: _coralHdr, letterSpacing: 1.6)),
            const SizedBox(width: 12),
            Flexible(child: Text('name the weather',
              style: GoogleFonts.gaegu(
                fontSize: 17, fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic, color: _brownLt),
              overflow: TextOverflow.ellipsis)),
          ]),
          Row(children: List.generate(moods.length, (i) {
            final m = moods[i];
            final sel = _moodTag == m['k'];
            final c = m['c'] as Color;
            return Expanded(child: Padding(
              padding: EdgeInsets.only(right: i < moods.length - 1 ? 10 : 0),
              child: GestureDetector(
                onTap: () => setState(() =>
                  _moodTag = sel ? null : m['k'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: sel ? c.withOpacity(0.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel ? c.withOpacity(0.7) : _outline.withOpacity(0.12),
                      width: sel ? 1.4 : 1)),
                  child: Column(children: [
                    Icon(m['i'] as IconData, size: 34,
                      color: sel ? c : _brownLt.withOpacity(0.5)),
                    const SizedBox(height: 10),
                    Text(m['l'] as String, style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                      color: sel ? _brown : _brownLt,
                      letterSpacing: 0.2)),
                  ]),
                ),
              ),
            ));
          })),
        ]),
    );
  }
}

//  PAST SESSIONS SHEET — search + filter + detail expand
class _PastSessionsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> sessions;
  final bool loading;
  final VoidCallback onRefresh;
  final dynamic api; // ApiService instance for update/delete
  const _PastSessionsSheet({required this.sessions, required this.loading,
    required this.onRefresh, required this.api});
  @override
  State<_PastSessionsSheet> createState() => _PastSessionsSheetState();
}

class _PastSessionsSheetState extends State<_PastSessionsSheet> {
  final _searchCtrl = TextEditingController();
  String _filterType = 'all';
  String _query = '';
  int? _expandedIndex;
  bool _selectMode = false;
  final Set<int> _selected = {};

  // Why: this sheet is shown via `showModalBottomSheet`, whose `builder`
  // captures the parent's state ONCE at the moment of show. Subsequent
  // updates to the parent's `_pastSessions` after the fetch completes (or
  // after an edit/delete) never reach the sheet, so it stays stuck on
  // "No sessions yet" forever. The fix: the sheet keeps its own copy of
  // the list and fetches it directly on initState. We still call
  // `widget.onRefresh()` after a fetch so the parent's rhythm-card counts
  // and downstream UI stay in sync with the same data.
  late List<Map<String, dynamic>> _sessions;
  late bool _loading;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    // Seed from whatever the parent had — so if the parent already
    // populated past sessions before opening the sheet, the user sees
    // them immediately rather than a flash of spinner.
    _sessions = List<Map<String, dynamic>>.from(widget.sessions);
    _loading = widget.loading || widget.sessions.isEmpty;
    // Always trigger a fresh fetch on open so the list reflects any
    // sessions completed since the parent last fetched (e.g. the user
    // just ended a session and immediately opened History).
    _refresh();
  }

  /// Fetch a fresh list straight from the backend into our own state, then
  /// nudge the parent so its session counters can update too.
  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _fetchError = null; });
    try {
      final resp = await widget.api.get(
          '/study/sessions', queryParams: {'limit': '50'});
      final data = resp?.data;
      if (data is List) {
        if (mounted) {
          setState(() {
            _sessions = List<Map<String, dynamic>>.from(data);
          });
        }
      } else {
        if (mounted) setState(() => _fetchError =
            'Unexpected response shape (${data.runtimeType})');
      }
    } catch (e) {
      if (mounted) setState(() => _fetchError = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
      // Best-effort parent sync — the parent's setState won't reach our
      // captured `widget.sessions`, but other parts of the parent UI
      // (e.g. the rhythm card's session tally) should still update.
      try { widget.onRefresh(); } catch (_) {}
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _sessions;
    if (_filterType != 'all') {
      list = list.where((s) => s['session_type'] == _filterType).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((s) {
        final title = (s['title'] ?? '').toString().toLowerCase();
        final notes = (s['notes'] ?? '').toString().toLowerCase();
        final topics = (s['topics_covered'] as List?)?.join(' ').toLowerCase() ?? '';
        final type = (s['session_type'] ?? '').toString().toLowerCase();
        return title.contains(q) || notes.contains(q) || topics.contains(q) || type.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateSession(String sessionId, {String? notes, String? title,
      List<String>? topics}) async {
    try {
      final body = <String, dynamic>{};
      if (notes != null) body['notes'] = notes;
      if (title != null) body['title'] = title;
      if (topics != null) body['topics_covered'] = topics;
      await widget.api.put('/study/sessions/$sessionId', data: body);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session updated!', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _greenHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Update failed: $e', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFFFF8F4),
        title: Text('Delete Session?', style: GoogleFonts.gaegu(
          fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
        content: Text('This will permanently delete this study session and revert the XP earned. This cannot be undone.',
          style: GoogleFonts.nunito(fontSize: 13, color: _brownLt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600, color: _brownLt)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _coralHdr,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Delete', style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.delete('/study/sessions/$sessionId');
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session deleted', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _greenHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e', style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  List<pw.Widget> _buildSessionPdfContent(Map<String, dynamic> s) {
    final type = s['session_type']?.toString() ?? 'focused';
    final mins = s['duration_minutes'] ?? 0;
    final xp = s['xp_earned'] ?? 0;
    final focus = s['focus_score'];
    final title = s['title']?.toString();
    final notes = s['notes']?.toString();
    final topics = (s['topics_covered'] as List?)?.cast<String>() ?? [];
    final created = s['created_at'] != null
        ? DateTime.tryParse(s['created_at'].toString()) : null;

    return [
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#E0D0C0')),
          borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(children: [
            pw.Text('${type[0].toUpperCase()}${type.substring(1)}',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            if (title != null && title.isNotEmpty) ...[
              pw.Text(' - ', style: const pw.TextStyle(fontSize: 11)),
              pw.Expanded(child: pw.Text(title, style: const pw.TextStyle(fontSize: 11))),
            ] else
              pw.Spacer(),
            if (created != null)
              pw.Text('${created.month}/${created.day}/${created.year}',
                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#7A5840'))),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Text('${mins}m', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 12),
            pw.Text('+${xp} XP', style: const pw.TextStyle(fontSize: 10)),
            if (focus != null) ...[
              pw.SizedBox(width: 12),
              pw.Text('Focus: ${focus}%', style: const pw.TextStyle(fontSize: 10)),
            ],
          ]),
          if (topics.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Topics: ${topics.join(', ')}',
              style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#7A5840'))),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFFCF8'),
                border: pw.Border.all(color: PdfColor.fromHex('#F0E8E0')),
                borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(_pdfSafe(notes), style: pw.TextStyle(fontSize: 10,
                color: PdfColor.fromHex('#4E3828'), lineSpacing: 3)),
            ),
          ],
        ]),
      ),
    ];
  }

  Future<void> _exportSessionsPdf(List<Map<String, dynamic>> sessions,
      {String? fileName}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('Study Sessions Report',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
        pw.Text('${sessions.length} session${sessions.length == 1 ? '' : 's'}',
          style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#7A5840'))),
        pw.SizedBox(height: 16),
        ...sessions.expand((s) => _buildSessionPdfContent(s)),
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColor.fromHex('#E0D0C0')),
        pw.SizedBox(height: 6),
        pw.Text('Generated by CEREBRO',
          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#999999'),
            fontStyle: pw.FontStyle.italic)),
      ],
    ));

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fName = fileName ?? 'cerebro_study_sessions.pdf';
      final file = File('${dir.path}/$fName');
      await file.writeAsBytes(await pdf.save());
      await Process.run('open', [file.path]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF saved to Documents/$fName',
            style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _greenHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not export PDF: $e',
            style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _exportEachSessionPdf(List<Map<String, dynamic>> sessions) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      int exported = 0;
      for (final s in sessions) {
        final pdf = pw.Document();
        final type = s['session_type']?.toString() ?? 'session';
        final title = s['title']?.toString();
        final created = s['created_at'] != null
            ? DateTime.tryParse(s['created_at'].toString()) : null;
        final dateStr = created != null
            ? '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}'
            : 'undated';
        final safeName = (title != null && title.isNotEmpty)
            ? title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')
            : type;
        final fName = 'cerebro_${safeName}_$dateStr.pdf';

        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Header(level: 0, child: pw.Text(
              title ?? '${type[0].toUpperCase()}${type.substring(1)} Session',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            if (created != null)
              pw.Text('$dateStr',
                style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#7A5840'))),
            pw.SizedBox(height: 16),
            ..._buildSessionPdfContent(s),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColor.fromHex('#E0D0C0')),
            pw.SizedBox(height: 6),
            pw.Text('Generated by CEREBRO',
              style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#999999'),
                fontStyle: pw.FontStyle.italic)),
          ],
        ));

        final file = File('${dir.path}/$fName');
        await file.writeAsBytes(await pdf.save());
        exported++;
      }
      // Open Documents folder to show all files
      await Process.run('open', [dir.path]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$exported PDF${exported == 1 ? '' : 's'} saved to Documents',
            style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _greenHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not export PDFs: $e',
            style: GoogleFonts.nunito(fontSize: 12)),
          backgroundColor: _coralHdr,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showFullScreenNotes(Map<String, dynamic> s) {
    final type = s['session_type']?.toString() ?? 'focused';
    final title = s['title']?.toString();
    final notes = s['notes']?.toString() ?? '';
    final topics = (s['topics_covered'] as List?)?.cast<String>() ?? [];
    final mins = s['duration_minutes'] ?? 0;
    final xp = s['xp_earned'] ?? 0;
    final focus = s['focus_score'];
    final sessionId = s['id']?.toString();
    final created = s['created_at'] != null
        ? DateTime.tryParse(s['created_at'].toString()) : null;

    Color typeColor;
    Color typeColorLt;
    switch (type) {
      case 'focused': typeColor = _pinkHdr; typeColorLt = _pinkLt; break;
      case 'review': typeColor = _skyHdr; typeColorLt = _skyLt; break;
      case 'practice': typeColor = _greenHdr; typeColorLt = _greenLt; break;
      case 'lecture': typeColor = _purpleHdr; typeColorLt = _purpleLt; break;
      default: typeColor = _pinkHdr; typeColorLt = _pinkLt;
    }

    final notesCtrl = TextEditingController(text: notes);
    final titleCtrl = TextEditingController(text: title ?? '');
    bool isEditing = false;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F4),
              borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    typeColorLt.withOpacity(0.35), typeColor.withOpacity(0.15)]),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                child: Row(children: [
                  Icon(Icons.article_rounded, size: 18, color: typeColor),
                  const SizedBox(width: 8),
                  Expanded(child: isEditing
                    ? TextField(
                        controller: titleCtrl,
                        style: GoogleFonts.gaegu(fontSize: 19,
                          fontWeight: FontWeight.w700, color: _brown),
                        decoration: InputDecoration(
                          hintText: 'Session title...',
                          hintStyle: GoogleFonts.gaegu(fontSize: 19,
                            color: _brownLt.withOpacity(0.4)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title ?? '${type[0].toUpperCase()}${type.substring(1)} Session',
                            style: GoogleFonts.gaegu(fontSize: 19,
                              fontWeight: FontWeight.w700, color: _brown),
                            overflow: TextOverflow.ellipsis),
                          if (created != null)
                            Text('${created.month}/${created.day}/${created.year}',
                              style: GoogleFonts.nunito(fontSize: 11, color: _brownLt)),
                        ],
                      )),
                  // Edit / Save toggle
                  if (sessionId != null) ...[
                    GestureDetector(
                      onTap: () async {
                        if (isEditing) {
                          // Save changes
                          await _updateSession(sessionId,
                            notes: notesCtrl.text,
                            title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : null);
                          setDialogState(() => isEditing = false);
                          // Update local data too
                          s['notes'] = notesCtrl.text;
                          s['title'] = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : null;
                          setState(() {}); // refresh parent list
                        } else {
                          setDialogState(() => isEditing = true);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEditing
                              ? _greenHdr.withOpacity(0.12) : _skyHdr.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isEditing
                              ? _greenHdr.withOpacity(0.25) : _skyHdr.withOpacity(0.2))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isEditing ? Icons.check_rounded : Icons.edit_rounded,
                            size: 12, color: isEditing ? _greenHdr : _skyHdr),
                          const SizedBox(width: 3),
                          Text(isEditing ? 'Save' : 'Edit', style: GoogleFonts.nunito(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: isEditing ? _greenHdr : _skyHdr)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Delete button
                    GestureDetector(
                      onTap: () async {
                        Navigator.of(dialogCtx).pop();
                        await _deleteSession(sessionId);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _coralHdr.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _coralHdr.withOpacity(0.2))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_outline_rounded, size: 12, color: _coralHdr),
                          const SizedBox(width: 3),
                          Text('Delete', style: GoogleFonts.nunito(
                            fontSize: 10, fontWeight: FontWeight.w700, color: _coralHdr)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  // PDF export
                  GestureDetector(
                    onTap: () => _exportSessionsPdf([s],
                      fileName: 'cerebro_${title ?? type}_session.pdf'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _coralHdr.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _coralHdr.withOpacity(0.2))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 12, color: _coralHdr),
                        const SizedBox(width: 3),
                        Text('PDF', style: GoogleFonts.nunito(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(dialogCtx).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _outline.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close_rounded, size: 16, color: _brownLt),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(children: [
                  _tinyPill(Icons.timer_rounded, '${mins}m', _pinkHdr),
                  const SizedBox(width: 6),
                  _tinyPill(Icons.star_rounded, '+${xp} XP', _goldHdr),
                  if (focus != null) ...[
                    const SizedBox(width: 6),
                    _tinyPill(Icons.speed_rounded, '${focus}%', _greenHdr),
                  ],
                ]),
              ),
              if (topics.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Wrap(spacing: 4, runSpacing: 4, children: topics.map((t) =>
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _purpleHdr.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(t, style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _purpleDk)),
                    )).toList()),
                ),
              Divider(height: 1, color: _outline.withOpacity(0.06)),
              Expanded(
                child: isEditing
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: notesCtrl,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.nunito(fontSize: 14, color: _brown, height: 1.6),
                        decoration: InputDecoration(
                          hintText: 'Write your notes here...',
                          hintStyle: GoogleFonts.nunito(fontSize: 14,
                            color: _brownLt.withOpacity(0.35)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _outline.withOpacity(0.08))),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _outline.withOpacity(0.08))),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: typeColor.withOpacity(0.3), width: 2)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(14)),
                      ),
                    )
                  : notes.isEmpty && notesCtrl.text.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.note_alt_outlined, size: 36,
                          color: _brownLt.withOpacity(0.25)),
                        const SizedBox(height: 8),
                        Text('No notes recorded', style: GoogleFonts.gaegu(
                          fontSize: 16, color: _brownLt.withOpacity(0.4))),
                        if (sessionId != null) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => setDialogState(() => isEditing = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _skyHdr.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _skyHdr.withOpacity(0.2))),
                              child: Text('Add Notes', style: GoogleFonts.nunito(
                                fontSize: 12, fontWeight: FontWeight.w700, color: _skyHdr)),
                            ),
                          ),
                        ],
                      ]))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: SelectableText(notesCtrl.text.isNotEmpty ? notesCtrl.text : notes,
                          style: GoogleFonts.nunito(fontSize: 14, color: _brown, height: 1.6)),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final selectedSessions = _selected
        .where((i) => i < filtered.length)
        .map((i) => filtered[i])
        .toList();
    final hasSelection = _selectMode && selectedSessions.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      // CRITICAL: previously the body was Column { header..., Expanded(ListView) }
      // wrapped in a LayoutBuilder. On desktop/web, DSS occasionally passes
      // unbounded constraints to its builder during initial layout, which made
      // SizedBox(height: constraints.maxHeight) infinite — collapsing the
      // Expanded child to zero height. Result: header read "50 of 50 in view"
      // but the list was invisible.
      //
      // The canonical fix is to give DSS a single scrollable to attach
      // scrollCtrl to. We use CustomScrollView with slivers — header / search /
      // chips become SliverToBoxAdapters and the list becomes a SliverList.
      // The selection action bar is overlayed as a Positioned widget so it
      // stays pinned to the bottom of the sheet without breaking the scroll
      // contract.
      //
      // IMPORTANT: the Stack's CustomScrollView is the *non-positioned* (anchor)
      // child. A Stack whose only child is Positioned collapses to 0×0 under
      // unbounded constraints (the failure mode DSS hits on first layout pass),
      // which is what made the list render offscreen. Keeping the scrollview
      // unpositioned lets it size the Stack.
      builder: (_, scrollCtrl) => Stack(
        fit: StackFit.expand,
        children: [
          CustomScrollView(
            controller: scrollCtrl,
            slivers: [
              // Handle + header
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(children: [
                  Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: _outline.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, children: [
                        Text('Past Sessions', style: const TextStyle(
                          fontFamily: 'Bitroad', fontSize: 24,
                          color: _brown, height: 1.05)),
                        const SizedBox(height: 3),
                        Text('${filtered.length} of ${_sessions.length} in view',
                          style: GoogleFonts.nunito(fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _inkSoft, letterSpacing: 0.3)),
                      ])),
                    // Select mode toggle — quiet
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectMode = !_selectMode;
                        if (!_selectMode) _selected.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _selectMode
                              ? _oliveBg : _cardFill.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectMode
                                ? _oliveDk.withOpacity(0.4) : _outline.withOpacity(0.16),
                            width: 1)),
                        child: Text(_selectMode ? 'Done' : 'Select',
                          style: GoogleFonts.nunito(fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _selectMode ? _oliveDk : _brownLt,
                            letterSpacing: 0.3)),
                      ),
                    ),
                    const SizedBox(width: 7),
                    // Export all as PDF — quiet
                    GestureDetector(
                      onTap: () => _exportSessionsPdf(filtered),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _cardFill.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _outline.withOpacity(0.16), width: 1)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.picture_as_pdf_rounded,
                            size: 12, color: _coralHdr.withOpacity(0.85)),
                          const SizedBox(width: 5),
                          Text('PDF', style: GoogleFonts.nunito(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: _brown, letterSpacing: 0.3)),
                        ]),
                      ),
                    ),
                  ]),
                ]),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // Search bar — soft pill, no heavy borders
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cardFill.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _outline.withOpacity(0.14), width: 1)),
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.nunito(fontSize: 13, color: _brown),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search by title, notes, topic...',
                      hintStyle: GoogleFonts.nunito(fontSize: 13,
                        color: _brownLt.withOpacity(0.4)),
                      prefixIcon: Icon(Icons.search_rounded, size: 17,
                        color: _brownLt.withOpacity(0.45)),
                      suffixIcon: _query.isNotEmpty ? GestureDetector(
                        onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
                        child: Icon(Icons.close_rounded, size: 15,
                          color: _brownLt.withOpacity(0.5)),
                      ) : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11)),
                  ),
                ),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // Filter chips
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _filterChip('all', 'All', Icons.list_rounded, _brownLt),
                    const SizedBox(width: 6),
                    _filterChip('focused', 'Focused', Icons.center_focus_strong_rounded, _pinkHdr),
                    const SizedBox(width: 6),
                    _filterChip('review', 'Review', Icons.replay_rounded, _skyHdr),
                    const SizedBox(width: 6),
                    _filterChip('practice', 'Practice', Icons.edit_note_rounded, _greenHdr),
                    const SizedBox(width: 6),
                    _filterChip('lecture', 'Lecture', Icons.headset_rounded, _purpleHdr),
                    // Select all / deselect all when in select mode
                    if (_selectMode) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => setState(() {
                          if (_selected.length == filtered.length) {
                            _selected.clear();
                          } else {
                            _selected.clear();
                            for (int i = 0; i < filtered.length; i++) _selected.add(i);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _skyHdr.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _skyHdr.withOpacity(0.25))),
                          child: Text(
                            _selected.length == filtered.length ? 'Deselect All' : 'Select All',
                            style: GoogleFonts.nunito(fontSize: 11,
                              fontWeight: FontWeight.w700, color: _skyHdr)),
                        ),
                      ),
                    ],
                  ]),
                ),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // Sessions list (or loading / empty state)
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: _pinkHdr)),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_fetchError != null
                            ? Icons.error_outline_rounded
                            : Icons.search_off_rounded,
                      size: 40,
                      color: (_fetchError != null ? _coralHdr : _brownLt)
                          .withOpacity(0.35)),
                    const SizedBox(height: 8),
                    Text(_fetchError != null
                            ? "Couldn't load sessions"
                            : (_query.isNotEmpty || _filterType != 'all'
                                ? 'No matching sessions' : 'No sessions yet'),
                      style: GoogleFonts.gaegu(fontSize: 18,
                        fontWeight: FontWeight.w700, color: _brownLt)),
                    if (_fetchError != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_fetchError!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 12, color: _brownLt.withOpacity(0.8))),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _refresh,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _skyHdr.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _skyHdr.withOpacity(0.3))),
                          child: Text('Try again', style: GoogleFonts.nunito(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: _skyHdr)),
                        ),
                      ),
                    ] else if (_query.isEmpty && _filterType == 'all')
                      Text('Complete your first session!', style: GoogleFonts.nunito(
                        fontSize: 13, color: _brownLt.withOpacity(0.6))),
                  ])),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, hasSelection ? 80 : 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _sessionTile(filtered[i], i),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),

          if (hasSelection)
            Positioned(
              left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _outline.withOpacity(0.08)))),
              child: Row(children: [
                Text('${selectedSessions.length} selected',
                  style: GoogleFonts.nunito(fontSize: 12,
                    fontWeight: FontWeight.w600, color: _brownLt)),
                const Spacer(),
                // Export combined
                GestureDetector(
                  onTap: () => _exportSessionsPdf(selectedSessions,
                    fileName: 'cerebro_selected_${selectedSessions.length}_sessions.pdf'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_coralHdr, _pinkHdr]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                        color: _coralHdr.withOpacity(0.2),
                        blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.merge_type_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('Combined PDF', style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // Export each separately
                GestureDetector(
                  onTap: () => _exportEachSessionPdf(selectedSessions),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_skyHdr, _purpleHdr]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                        color: _skyHdr.withOpacity(0.2),
                        blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.file_copy_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('Each as PDF', style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _filterChip(String type, String label, IconData icon, Color color) {
    final sel = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? color.withOpacity(0.45) : _outline.withOpacity(0.16),
            width: 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (sel) ...[
            Container(width: 5, height: 5,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
          ],
          Text(label, style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: sel ? _brown : _brownLt, letterSpacing: 0.3)),
        ]),
      ),
    );
  }

  Widget _sessionTile(Map<String, dynamic> s, int index) {
    final type = s['session_type']?.toString() ?? 'focused';
    final mins = s['duration_minutes'] ?? 0;
    final xp = s['xp_earned'] ?? 0;
    final focus = s['focus_score'];
    final title = s['title']?.toString();
    final notes = s['notes']?.toString();
    final topics = (s['topics_covered'] as List?)?.cast<String>() ?? [];
    final created = s['created_at'] != null
        ? DateTime.tryParse(s['created_at'].toString()) : null;
    final isExpanded = _expandedIndex == index;
    final isSelected = _selected.contains(index);

    Color typeColor;
    switch (type) {
      case 'focused': typeColor = _pinkHdr; break;
      case 'review': typeColor = _skyHdr; break;
      case 'practice': typeColor = _greenHdr; break;
      case 'lecture': typeColor = _purpleHdr; break;
      default: typeColor = _pinkHdr;
    }

    IconData typeIcon;
    switch (type) {
      case 'focused': typeIcon = Icons.center_focus_strong_rounded; break;
      case 'review': typeIcon = Icons.replay_rounded; break;
      case 'practice': typeIcon = Icons.edit_note_rounded; break;
      case 'lecture': typeIcon = Icons.headset_rounded; break;
      default: typeIcon = Icons.timer_rounded;
    }

    return GestureDetector(
      onTap: () {
        if (_selectMode) {
          setState(() {
            if (isSelected) _selected.remove(index);
            else _selected.add(index);
          });
        } else {
          setState(() => _expandedIndex = isExpanded ? null : index);
        }
      },
      child: Container(
        // Why uniform border + ClipRRect + Row(accent | content):
        // The previous version used Border(left: 3-4px, top/right/bottom: 1px)
        // combined with BorderRadius.circular(14). Flutter's Border.paint
        // asserts that borderRadius MUST be null when border sides have
        // different widths or colors. In debug this throws; in release the
        // paint pipeline falls through and child rendering becomes unreliable
        // — which is why every tile rendered as an empty white rectangle.
        // Now: uniform Border.all + a 4px colored left accent as a sibling
        // in a Row, all clipped to the rounded corners. Identical visual
        // intent, but legal under Flutter's painter contract.
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? _oliveBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: _outline.withOpacity(0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
          border: Border.all(
            color: isSelected
                ? _oliveDk.withOpacity(0.4)
                : _outline.withOpacity(0.22),
            width: 1)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored type accent (left strip)
              Container(
                width: isExpanded ? 4 : 3,
                color: typeColor.withOpacity(0.75)),
              // Content column
              Expanded(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_selectMode) ...[
                  Icon(
                    isSelected ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: isSelected ? _oliveDk : _brownLt.withOpacity(0.35)),
                  const SizedBox(width: 9),
                ],
                Icon(typeIcon, size: 13, color: typeColor),
                const SizedBox(width: 6),
                Text(type[0].toUpperCase() + type.substring(1),
                  style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w900,
                    color: _brown, letterSpacing: 0.6)),
                if (title != null && title.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Text('·', style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w900,
                      color: _outline.withOpacity(0.4)))),
                  Expanded(child: Text(title, style: GoogleFonts.nunito(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: _brown, letterSpacing: 0.2),
                    overflow: TextOverflow.ellipsis)),
                ] else
                  const Spacer(),
                if (created != null)
                  Text('${created.month}/${created.day}',
                    style: GoogleFonts.nunito(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _inkSoft, letterSpacing: 0.3)),
                if (!_selectMode) ...[
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, size: 16,
                      color: _brownLt.withOpacity(0.45))),
                ],
              ]),
          ),
          // Stats row — quiet inline stats
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Row(children: [
              _tinyPill(Icons.timer_rounded, '${mins}m', _pinkHdr),
              const SizedBox(width: 7),
              _tinyPill(Icons.bolt_rounded, '+$xp', _goldDk),
              if (focus != null) ...[
                const SizedBox(width: 7),
                _tinyPill(Icons.speed_rounded, '$focus%', _greenDk),
              ],
            ]),
          ),
          // Expanded detail
          if (isExpanded && !_selectMode) ...[
            Divider(height: 1, color: _outline.withOpacity(0.06)),
            Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topics.isNotEmpty) ...[
                  Wrap(spacing: 4, runSpacing: 4, children: topics.map((t) =>
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _purpleHdr.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(t, style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _purpleDk)),
                    )).toList()),
                  const SizedBox(height: 8),
                ],
                if (notes != null && notes.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _showFullScreenNotes(s),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _outline.withOpacity(0.04))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notes, style: GoogleFonts.nunito(
                            fontSize: 12, color: _brownLt, height: 1.4),
                            maxLines: 5, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Icon(Icons.open_in_full_rounded, size: 12,
                              color: _skyHdr.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text('View full notes', style: GoogleFonts.nunito(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: _skyHdr.withOpacity(0.7))),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
                if ((notes == null || notes.isEmpty) && topics.isEmpty)
                  Text('No notes or topics recorded', style: GoogleFonts.nunito(
                    fontSize: 12, fontStyle: FontStyle.italic,
                    color: _brownLt.withOpacity(0.4))),
                // Quick actions row
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  // Full screen view button
                  GestureDetector(
                    onTap: () => _showFullScreenNotes(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _skyHdr.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _skyHdr.withOpacity(0.15))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.fullscreen_rounded, size: 13, color: _skyHdr),
                        const SizedBox(width: 4),
                        Text('Full View', style: GoogleFonts.nunito(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _skyHdr)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Export single PDF
                  GestureDetector(
                    onTap: () => _exportSessionsPdf([s],
                      fileName: 'cerebro_${title ?? type}_session.pdf'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _coralHdr.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _coralHdr.withOpacity(0.15))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 13, color: _coralHdr),
                        const SizedBox(width: 4),
                        Text('Export PDF', style: GoogleFonts.nunito(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _coralHdr)),
                      ]),
                    ),
                  ),
                  // Delete session
                  if (s['id'] != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _deleteSession(s['id'].toString()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.12))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_outline_rounded, size: 13,
                            color: Colors.red.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text('Delete', style: GoogleFonts.nunito(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.red.withOpacity(0.6))),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ],
            )),
          ],
        ])),
              ])),
            ),
          ),
    );
  }

  Widget _tinyPill(IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color.withOpacity(0.85)),
      const SizedBox(width: 5),
      Text(text, style: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w800,
        color: _brown, letterSpacing: 0.2)),
    ]);
  }
}

//  CUSTOM FOCUS FACE PAINTER
class _FacePainter extends CustomPainter {
  final int score;
  final Color color;
  final double size;
  _FacePainter({required this.score, required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final r = size / 2 - 4;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0;

    canvas.drawCircle(Offset(cx, cy), r, paint);

    final eyeY = cy - r * 0.15;
    final eyeSpread = r * 0.35;
    if (score <= 20) {
      final s = r * 0.12;
      canvas.drawLine(Offset(cx - eyeSpread - s, eyeY - s), Offset(cx - eyeSpread + s, eyeY + s), paint);
      canvas.drawLine(Offset(cx - eyeSpread + s, eyeY - s), Offset(cx - eyeSpread - s, eyeY + s), paint);
      canvas.drawLine(Offset(cx + eyeSpread - s, eyeY - s), Offset(cx + eyeSpread + s, eyeY + s), paint);
      canvas.drawLine(Offset(cx + eyeSpread + s, eyeY - s), Offset(cx + eyeSpread - s, eyeY + s), paint);
    } else {
      final fill = Paint()..color = color..style = PaintingStyle.fill;
      final eyeR = score >= 80 ? r * 0.12 : r * 0.09;
      canvas.drawCircle(Offset(cx - eyeSpread, eyeY), eyeR, fill);
      canvas.drawCircle(Offset(cx + eyeSpread, eyeY), eyeR, fill);
      if (score >= 80) {
        final sparkle = Paint()..color = Colors.white..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx - eyeSpread + 1.5, eyeY - 1.5), r * 0.04, sparkle);
        canvas.drawCircle(Offset(cx + eyeSpread + 1.5, eyeY - 1.5), r * 0.04, sparkle);
      }
    }

    final mouthY = cy + r * 0.3;
    final mouthW = r * 0.4;
    if (score >= 80) {
      canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY - r * 0.1),
        width: mouthW * 2, height: r * 0.5), 0.2, math.pi - 0.4, false, paint);
    } else if (score >= 60) {
      canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY),
        width: mouthW * 1.5, height: r * 0.3), 0.3, math.pi - 0.6, false, paint);
    } else if (score >= 40) {
      canvas.drawLine(Offset(cx - mouthW * 0.7, mouthY),
        Offset(cx + mouthW * 0.7, mouthY), paint);
    } else {
      canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY + r * 0.2),
        width: mouthW * 1.5, height: r * 0.3), math.pi + 0.3, math.pi - 0.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) => old.score != score || old.color != color;
}

//  RING PAINTER
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color1, color2, bgColor;
  _RingPainter({required this.progress, required this.color1,
    required this.color2, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const bgStrokeW = 6.0;
    const fgStrokeW = 8.0;

    // Quiet background track — thinner, lower contrast
    canvas.drawCircle(center, radius,
      Paint()..style = PaintingStyle.stroke..strokeWidth = bgStrokeW
        ..color = bgColor);

    if (progress > 0) {
      final sweep = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweep, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = fgStrokeW
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(color1, color2, progress) ?? color2);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

//  PARTICLE PAINTER — ambient floating dots
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 18; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble() * 2 * math.pi;
      final r = 2.0 + rng.nextDouble() * 3;
      final x = baseX + math.sin(progress * 2 * math.pi * speed + phase) * 20;
      final y = baseY - progress * size.height * 0.1 * speed;
      final opacity = (0.06 + rng.nextDouble() * 0.08) *
          (1 - (y < 0 ? 1.0 : 0.0));
      if (y > -20 && y < size.height + 20) {
        paint.color = color.withOpacity(opacity.clamp(0.0, 0.15));
        canvas.drawCircle(Offset(x, y % size.height), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

//  CONFETTI PAINTER — completion celebration
class _ConfettiPainter extends CustomPainter {
  final double progress;
  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.1) return;
    final rng = math.Random(99);
    final colors = [_pinkHdr, _greenHdr, _goldHdr, _purpleHdr, _skyHdr, _coralHdr];
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 24; i++) {
      final cx = rng.nextDouble() * size.width;
      final startY = -10.0;
      final endY = size.height + 20;
      final t = (progress - rng.nextDouble() * 0.3).clamp(0.0, 1.0);
      final y = startY + (endY - startY) * Curves.easeOut.transform(t);
      final x = cx + math.sin(t * math.pi * 3 + i) * 15;
      final opacity = (1.0 - t).clamp(0.0, 0.6);
      paint.color = colors[i % colors.length].withOpacity(opacity);
      final w = 3.0 + rng.nextDouble() * 4;
      final h = 2.0 + rng.nextDouble() * 3;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi * 2 + i.toDouble());
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}

//  MILESTONE TOAST
class _MilestoneToast extends StatelessWidget {
  final String msg;
  const _MilestoneToast({required this.msg});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -20 * (1 - t)),
          child: child)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _cardFill.withOpacity(0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline.withOpacity(0.16), width: 1),
          boxShadow: [BoxShadow(color: _brown.withOpacity(0.06),
            offset: const Offset(0, 4), blurRadius: 14)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 3, height: 20, decoration: BoxDecoration(
            color: _goldDk, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Flexible(child: Text(msg, style: GoogleFonts.gaegu(
            fontSize: 15, fontWeight: FontWeight.w700, color: _brown))),
        ]),
      ),
    );
  }
}

//  DURATION CHIP
class _DurationChip extends StatelessWidget {
  final int min;
  final String label, desc;
  final bool selected, isCustom;
  final VoidCallback onTap;
  const _DurationChip({required this.min, required this.label,
    required this.desc, required this.selected, this.isCustom = false,
    required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = isCustom ? _purpleDk : _oliveDk;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(0.42)
              : const Color(0xFFFFF8F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withOpacity(0.75)
                : _outline.withOpacity(0.28),
            width: 1.6),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accent.withOpacity(0.32)
                  : _outline.withOpacity(0.18),
              offset: const Offset(2, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(
            fontFamily: 'Bitroad', fontSize: 16, color: _brown)),
          const SizedBox(height: 2),
          Text(desc, style: GoogleFonts.nunito(
            fontSize: 9.5, fontWeight: FontWeight.w800,
            color: selected ? _brown.withOpacity(0.75) : _inkSoft,
            letterSpacing: 0.6)),
        ]),
      ),
    ));
  }
}

//  CIRCLE BUTTON — timer controls
class _CircleBtn extends StatefulWidget {
  final Color gradTop, gradBot, borderColor, shadowColor;
  final IconData icon;
  final double size, iconSize;
  final VoidCallback onTap;
  const _CircleBtn({required this.gradTop, required this.gradBot,
    required this.borderColor, required this.shadowColor,
    required this.icon, this.size = 56, this.iconSize = 24,
    required this.onTap});
  @override State<_CircleBtn> createState() => _CircleBtnState();
}

class _CircleBtnState extends State<_CircleBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, _p ? 2 : 0, 0),
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [widget.gradTop, widget.gradBot]),
          shape: BoxShape.circle,
          border: Border.all(color: widget.borderColor.withOpacity(0.35), width: 1.4),
          boxShadow: _p ? [] : [BoxShadow(
            color: widget.shadowColor.withOpacity(0.18),
            offset: const Offset(0, 4), blurRadius: 12)]),
        child: Icon(widget.icon, size: widget.iconSize, color: Colors.white),
      ),
    );
  }
}

//  GAME BUTTON — big action button
class _GameButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color gradTop, gradBot, borderColor;
  final VoidCallback onTap;
  final bool loading;
  const _GameButton({required this.icon, required this.label,
    required this.gradTop, required this.gradBot, required this.borderColor,
    required this.onTap, this.loading = false});
  @override State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.loading ? null : (_) => setState(() => _p = true),
      onTapUp: widget.loading ? null : (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, _p ? 2 : 0, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [widget.gradTop, widget.gradBot]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.borderColor.withOpacity(0.35), width: 1.4),
          boxShadow: _p ? [] : [BoxShadow(
            color: widget.borderColor.withOpacity(0.22),
            offset: const Offset(0, 5), blurRadius: 14)]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (widget.loading)
            SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            Icon(widget.icon, size: 22, color: Colors.white),
          const SizedBox(width: 8),
          Text(widget.label, style: const TextStyle(
            fontFamily: 'Bitroad', fontSize: 18, color: Colors.white)),
        ]),
      ),
    );
  }
}

//  PAWPRINT BACKGROUND
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const sp = 90.0, rs = 45.0, r = 10.0;
    int idx = 0;
    for (double y = 30; y < size.height; y += sp) {
      final odd = ((y / sp).floor() % 2) == 1;
      for (double x = (odd ? rs : 0) + 30; x < size.width; x += sp) {
        paint.color = _pawClr.withOpacity(0.06 + (idx % 5) * 0.018);
        final a = (idx % 4) * 0.3 - 0.3;
        canvas.save(); canvas.translate(x, y); canvas.rotate(a);
        canvas.drawOval(Rect.fromCenter(
          center: Offset.zero, width: r * 2.2, height: r * 1.8), paint);
        final t = r * 0.52;
        canvas.drawCircle(Offset(-r, -r * 1.35), t, paint);
        canvas.drawCircle(Offset(-r * 0.38, -r * 1.65), t, paint);
        canvas.drawCircle(Offset(r * 0.38, -r * 1.65), t, paint);
        canvas.drawCircle(Offset(r, -r * 1.35), t, paint);
        canvas.restore(); idx++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

//   • thin horizontal hairlines every 32px — the "lines" on the page
//   • soft vertical margin line at x=52 — the classic notebook gutter
//   • both drawn in very low-opacity _outline so they recede behind text
class _RuledPaperBg extends CustomPainter {
  final Color line;
  final Color margin;
  final double lineSpacing;
  final double marginX;
  _RuledPaperBg({
    required this.line,
    required this.margin,
    this.lineSpacing = 32,
    this.marginX = 52,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // horizontal rules — start a bit below the top so the first line
    // sits under the first line of text, not flush with the container edge
    for (double y = lineSpacing + 4; y < size.height - 8; y += lineSpacing) {
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), linePaint);
    }
    // left-margin vertical gutter line — warm pink-ish accent, like a
    // real composition notebook
    final marginPaint = Paint()
      ..color = margin
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(marginX, 8),
      Offset(marginX, size.height - 8),
      marginPaint);
  }

  @override
  bool shouldRepaint(covariant _RuledPaperBg old) =>
      old.line != line || old.margin != margin ||
      old.lineSpacing != lineSpacing || old.marginX != marginX;
}

//  NOTES EDITOR — full-screen notes-app route
class _NotesEditorRoute extends StatefulWidget {
  final TextEditingController notesCtrl;
  final TextEditingController topicCtrl;
  final List<String> topics;
  final bool bold;
  final bool italic;
  final ValueChanged<bool> onBoldChange;
  final ValueChanged<bool> onItalicChange;
  final VoidCallback onTopicsChange;
  final VoidCallback onExportPdf;
  final VoidCallback onRefresh;
  final String sessionTitle;
  final String? subjectName;
  final Color? subjectColor;
  final int studiedMin;
  final String sessionType;

  const _NotesEditorRoute({
    required this.notesCtrl,
    required this.topicCtrl,
    required this.topics,
    required this.bold,
    required this.italic,
    required this.onBoldChange,
    required this.onItalicChange,
    required this.onTopicsChange,
    required this.onExportPdf,
    required this.onRefresh,
    required this.sessionTitle,
    required this.subjectName,
    required this.subjectColor,
    required this.studiedMin,
    required this.sessionType,
  });

  @override
  State<_NotesEditorRoute> createState() => _NotesEditorRouteState();
}

class _NotesEditorRouteState extends State<_NotesEditorRoute> {
  late bool _bold;
  late bool _italic;

  @override
  void initState() {
    super.initState();
    _bold = widget.bold;
    _italic = widget.italic;
  }

  int get _wordCount {
    final t = widget.notesCtrl.text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  int get _charCount => widget.notesCtrl.text.length;
  int get _lineCount => widget.notesCtrl.text.split('\n').length;

  void _insertAtCursor(String txt) {
    final t = widget.notesCtrl.text;
    final sel = widget.notesCtrl.selection;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final newT = t.replaceRange(start, end, txt);
    widget.notesCtrl.text = newT;
    widget.notesCtrl.selection = TextSelection.collapsed(offset: start + txt.length);
    setState(() {});
    widget.onRefresh();
  }

  void _addBullet() {
    final t = widget.notesCtrl.text;
    final ins = t.isEmpty || t.endsWith('\n') ? '\u2022 ' : '\n\u2022 ';
    _insertAtCursor(ins);
  }

  void _addNumbered() {
    final lines = widget.notesCtrl.text.split('\n');
    final n = lines.where((l) => RegExp(r'^\d+\.').hasMatch(l)).length + 1;
    final t = widget.notesCtrl.text;
    final ins = t.isEmpty || t.endsWith('\n') ? '$n. ' : '\n$n. ';
    _insertAtCursor(ins);
  }

  void _addHeading() {
    final t = widget.notesCtrl.text;
    final ins = t.isEmpty || t.endsWith('\n') ? '## ' : '\n## ';
    _insertAtCursor(ins);
  }

  void _addCheck() {
    final t = widget.notesCtrl.text;
    final ins = t.isEmpty || t.endsWith('\n') ? '\u25A1 ' : '\n\u25A1 ';
    _insertAtCursor(ins);
  }

  Widget _toolBtn(IconData icon, bool active, VoidCallback onTap, {String? tip}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: active ? _oliveBg.withOpacity(0.7) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? _oliveDk.withOpacity(0.45)
                : _outline.withOpacity(0.14), width: 1)),
        child: Icon(icon, size: 15,
          color: active ? _oliveDk : _brownLt.withOpacity(0.75)),
      ),
    );
  }

  // Matches dashboard _sectionTitle: olive 16×16 icon + Bitroad 16
  // label + 7px gap + 13px bottom margin. The optional Gaegu sub
  // becomes a right-aligned whisper so the header reads calm but
  // has a single tiny italic pop.
  Widget _sectionHdr(String label, IconData icon, {Color? accent, String? sub}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(icon, size: 19, color: accent ?? _oliveDk),
        const SizedBox(width: 9),
        Text(label, style: const TextStyle(
          fontFamily: 'Bitroad', fontSize: 19, color: _brown)),
        if (sub != null) ...[
          const SizedBox(width: 12),
          Expanded(child: Text(sub, style: GoogleFonts.gaegu(
            fontSize: 14.5, fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: _brownLt.withOpacity(0.85)),
            overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);

    Widget sectionDivider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Container(height: 1, color: _outline.withOpacity(0.1)),
    );

    Widget documentSection() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, children: [
        _sectionHdr('Document', Icons.description_rounded,
          accent: _oliveDk, sub: 'this session'),
        Text(widget.sessionTitle, style: const TextStyle(
          fontFamily: 'Bitroad', fontSize: 17, color: _brown,
          height: 1.2)),
        if (widget.subjectName != null) Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
              color: widget.subjectColor ?? _olive,
              shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.subjectName!,
              style: GoogleFonts.nunito(fontSize: 13,
                fontWeight: FontWeight.w700, color: _brownLt),
              overflow: TextOverflow.ellipsis)),
          ]),
        ),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('STUDIED', style: GoogleFonts.nunito(
                fontSize: 10.5, fontWeight: FontWeight.w900,
                color: _inkSoft, letterSpacing: 1.4)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${widget.studiedMin}', style: const TextStyle(
                  fontFamily: 'Bitroad', fontSize: 24, color: _brown, height: 1)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('min', style: GoogleFonts.nunito(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt))),
              ]),
            ])),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TYPE', style: GoogleFonts.nunito(
                fontSize: 10.5, fontWeight: FontWeight.w900,
                color: _inkSoft, letterSpacing: 1.4)),
              const SizedBox(height: 6),
              Text(widget.sessionType, style: GoogleFonts.nunito(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: _brown)),
            ])),
        ]),
      ]);

    Widget topicsSection() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, children: [
        _sectionHdr('Topics', Icons.tag_rounded,
          accent: _purpleDk, sub: 'tag the thinking'),
        if (widget.topics.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('no topics yet — tag your work below',
              style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: _brownLt.withOpacity(0.75))),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(spacing: 8, runSpacing: 8,
              children: widget.topics.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _purpleLt.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _purpleHdr.withOpacity(0.35), width: 1)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(t, style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _brown, letterSpacing: 0.2)),
                  const SizedBox(width: 7),
                  GestureDetector(
                    onTap: () {
                      setState(() => widget.topics.remove(t));
                      widget.onTopicsChange();
                    },
                    child: Icon(Icons.close_rounded, size: 13,
                      color: _purpleDk.withOpacity(0.6))),
                ]),
              )).toList()),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _outline.withOpacity(0.15), width: 1)),
          child: Row(children: [
            Icon(Icons.add_rounded, size: 16,
              color: _brownLt.withOpacity(0.8)),
            const SizedBox(width: 7),
            Expanded(child: TextField(
              controller: widget.topicCtrl,
              style: GoogleFonts.nunito(
                fontSize: 13.5, color: _brown, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Add topic & press enter',
                hintStyle: GoogleFonts.nunito(
                  fontSize: 13.5, color: _brownLt.withOpacity(0.45)),
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  setState(() {
                    widget.topics.add(v.trim());
                    widget.topicCtrl.clear();
                  });
                  widget.onTopicsChange();
                }
              },
            )),
          ]),
        ),
      ]);

    // NOTE: "Document Stats" sidebar section removed — word/char count
    // now lives in ONE place (bottom-right of the paper itself). The
    // sidebar was showing the same numbers a second time.

    Widget briefPanel() => Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.14), width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, children: [
          documentSection(),
          sectionDivider(),
          topicsSection(),
        ]),
    );

    //   ONE surface. No banner-bar / toolbar-bar / page / footer-bar
    //   stack. Just a single cream page with ruled lines, an inline
    //   italic prompt at the top, a tiny floating tool-pill in the
    //   corner, and a single quiet word counter at the bottom.
    //
    //   Everything else was redundant: the outer rounded rectangle
    //   was reading as "a white box AROUND a paper", the prompt
    //   banner doubled the page header, the toolbar ribbon competed
    //   with the page, and word/char count appeared three times.
    final promptText = widget.topics.isNotEmpty
      ? 'what stuck with you about ${widget.topics.first}?'
      : widget.subjectName != null
        ? 'what\'s one thing worth remembering from ${widget.subjectName}?'
        : 'what\'s one thing worth remembering from today?';

    Widget editor() => ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(fit: StackFit.expand, children: [
        Positioned.fill(child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFDF6E9),
              const Color(0xFFFFFAF2),
            ])))),
        Positioned.fill(child: IgnorePointer(child: CustomPaint(
          painter: _RuledPaperBg(
            line: _outline.withOpacity(0.07),
            margin: _coralHdr.withOpacity(0.30),
          )))),
        Positioned(left: 0, right: 0, bottom: 0, height: 26,
          child: IgnorePointer(child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                _brown.withOpacity(0.05),
              ]))))),
        //    the paper. Must be Positioned.fill so the Stack sizes
        //    properly; TextField wrapped in a transparent Material
        //    so it does NOT render an opaque white surface over the
        //    ruled background.
        Positioned.fill(child: Padding(
          padding: const EdgeInsets.fromLTRB(64, 26, 28, 60),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inline prompt — feels like a friend wrote a note at
              // the top of the page for you. Gaegu italic in olive.
              RichText(text: TextSpan(children: [
                TextSpan(text: 'today — ', style: GoogleFonts.gaegu(
                  fontSize: 17, fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700, color: _oliveDk)),
                TextSpan(text: promptText, style: GoogleFonts.gaegu(
                  fontSize: 17, fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: _brownLt.withOpacity(0.85))),
              ])),
              const SizedBox(height: 18),
              // The writing area — transparent Material so no white
              // surface is painted; TextField sits directly on the
              // ruled paper background.
              Expanded(child: Material(
                type: MaterialType.transparency,
                child: TextField(
                  controller: widget.notesCtrl,
                  cursorColor: _coralHdr,
                  cursorWidth: 1.6,
                  style: GoogleFonts.nunito(
                    fontSize: 16, color: _brown, height: 32 / 16,
                    fontWeight: _bold ? FontWeight.w800 : FontWeight.w500,
                    fontStyle: _italic ? FontStyle.italic : FontStyle.normal),
                  maxLines: null, expands: true,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'start writing…',
                    hintStyle: GoogleFonts.gaegu(
                      fontSize: 17, color: _brownLt.withOpacity(0.4),
                      fontStyle: FontStyle.italic, height: 32 / 17),
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero),
                  onChanged: (_) {
                    setState(() {});
                    widget.onRefresh();
                  },
                ),
              )),
            ]),
        )),
        //    over the paper like a clipped-on toolbar
        Positioned(
          top: 14, right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _outline.withOpacity(0.14), width: 1),
              boxShadow: [BoxShadow(
                color: _brown.withOpacity(0.06),
                blurRadius: 10, offset: const Offset(0, 2))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _toolBtn(Icons.format_bold_rounded, _bold, () {
                setState(() => _bold = !_bold);
                widget.onBoldChange(_bold);
              }),
              const SizedBox(width: 4),
              _toolBtn(Icons.format_italic_rounded, _italic, () {
                setState(() => _italic = !_italic);
                widget.onItalicChange(_italic);
              }),
              const SizedBox(width: 8),
              Container(width: 1, height: 18, color: _outline.withOpacity(0.18)),
              const SizedBox(width: 8),
              _toolBtn(Icons.title_rounded, false, _addHeading),
              const SizedBox(width: 4),
              _toolBtn(Icons.format_list_bulleted_rounded, false, _addBullet),
              const SizedBox(width: 4),
              _toolBtn(Icons.format_list_numbered_rounded, false, _addNumbered),
              const SizedBox(width: 4),
              _toolBtn(Icons.check_box_outline_blank_rounded, false, _addCheck),
            ]),
          ),
        ),
        //    Single source of truth for word count, no sidebar dup.
        Positioned(
          left: 64, right: 24, bottom: 20,
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(
              color: _oliveDk.withOpacity(0.6), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('autosaved', style: GoogleFonts.gaegu(
              fontSize: 14, fontStyle: FontStyle.italic,
              color: _brownLt.withOpacity(0.7))),
            const Spacer(),
            Text('$_wordCount words',
              style: GoogleFonts.gaegu(
                fontSize: 15, fontStyle: FontStyle.italic,
                color: _brownLt.withOpacity(0.75))),
          ]),
        ),
      ]),
    );

    return Material(
      color: Colors.transparent,
      child: Stack(children: [
        // Backdrop blur via gradient
        Container(decoration: BoxDecoration(gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_ombre1, _ombre3]))),
        // Paw print backdrop
        Positioned.fill(child: CustomPaint(painter: _PawPrintBg())),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _cardFill.withOpacity(0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _outline.withOpacity(0.22), width: 1.2)),
                  child: Icon(Icons.arrow_back_rounded,
                    size: 22, color: _brown))),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
                  const Text('Notebook', style: TextStyle(
                    fontFamily: 'Bitroad', fontSize: 30,
                    color: _brown, height: 1.05)),
                  const SizedBox(height: 4),
                  Text('capture your thinking',
                    style: GoogleFonts.nunito(fontSize: 13,
                      fontWeight: FontWeight.w700, color: _inkSoft,
                      letterSpacing: 0.3),
                    overflow: TextOverflow.ellipsis),
                ])),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: widget.onExportPdf,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(
                    color: _cardFill.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _outline.withOpacity(0.2), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf_rounded,
                      size: 14, color: _coralHdr.withOpacity(0.85)),
                    const SizedBox(width: 7),
                    Text('Export', style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: _brown, letterSpacing: 0.3)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Expanded(child: Padding(
              padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
              child: LayoutBuilder(builder: (ctx, c) {
                final wide = c.maxWidth > 720;
                if (wide) {
                  return Row(crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Unified sidebar — fills full height
                      SizedBox(
                        width: 320,
                        height: c.maxHeight,
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: c.maxHeight),
                            child: briefPanel(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Editor — fills remaining
                      Expanded(child: editor()),
                    ]);
                }
                // Narrow stacked
                return SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      briefPanel(),
                      const SizedBox(height: 14),
                      SizedBox(height: c.maxHeight * 0.62, child: editor()),
                    ]),
                );
              }),
            )),
          ]),
        )),
      ]),
    );
  }
}
