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
import 'package:cerebro_app/providers/auth_provider.dart';

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

  const StudySessionScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen>
    with TickerProviderStateMixin {

  //  Setup state 
  String _sessionType = 'focused';
  int _durationMin = 25;
  bool _customDuration = false;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _selectedSubjectColor;
  final _titleCtrl = TextEditingController();

  //  Subject list from API 
  List<Map<String, dynamic>> _subjects = [];
  bool _subjectsLoading = true;

  //  Timer state 
  _Phase _phase = _Phase.setup;
  Timer? _ticker;
  int _remainSec = 0;
  int _totalStudiedSec = 0;
  int _pomodoroCount = 0;
  bool _isBreakPhase = false;
  DateTime? _startTime;
  DateTime? _endTime;
  int _distractionCount = 0;

  //  Notes state 
  final _notesCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  List<String> _topics = [];
  int _focusScore = 70;
  bool _bold = false;
  bool _italic = false;

  //  Ambient audio 
  String _ambientSound = 'none';
  AudioPlayer? _audioPlayer;
  bool _audioLoading = false;

  //  Past sessions 
  List<Map<String, dynamic>> _pastSessions = [];
  bool _pastLoading = false;

  //  Completion state 
  int _xpEarned = 0;
  bool _saving = false;
  bool _saved = false;

  //  Animations 
  late AnimationController _enterCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _breatheCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _xpCtrl;
  late String _quote;

  //  Milestone tracking 
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

  //  Fetch subjects from API 
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

  //  Fetch past sessions 
  Future<void> _fetchPastSessions() async {
    setState(() => _pastLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get('/study/sessions', queryParams: {'limit': '50'});
      if (resp.statusCode == 200 && resp.data is List) {
        setState(() => _pastSessions = List<Map<String, dynamic>>.from(resp.data));
      }
    } catch (_) {}
    if (mounted) setState(() => _pastLoading = false);
  }

  //  Audio control 
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

  // 
  //  PAST SESSIONS — with search + filter
  // 
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

  // 
  //  TIMER LOGIC
  // 
  void _startTimer() {
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
  }

  void _resumeTimer() {
    setState(() => _phase = _isBreakPhase ? _Phase.onBreak : _Phase.running);
    _beginTick();
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
  }

  //  Save to API 
  Future<void> _saveSession() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final mins = (_totalStudiedSec / 60).ceil().clamp(1, 720);
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

      final resp = await api.post('/study/sessions', data: body);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final xp = resp.data['xp_earned'] ?? 0;
        setState(() {
          _xpEarned = xp is int ? xp : (xp as num).toInt();
          _saved = true;
        });
        _xpCtrl.forward(from: 0);
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

  //  Helpers 
  //  PDF Export 
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

  // 
  //  BUILD
  // 
  @override
  Widget build(BuildContext context) {
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
                  : _typeColor(_sessionType)).withOpacity(0.1),
              Colors.transparent])))),
        // Floating particles during timer
        if (_phase == _Phase.running || _phase == _Phase.paused || _phase == _Phase.onBreak)
          Positioned.fill(child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(
                progress: _particleCtrl.value,
                color: _isBreakPhase ? _greenHdr : _typeColor(_sessionType))))),
        // Main content
        SafeArea(child: Column(children: [
          _buildAppBar(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: _phase == _Phase.setup ? _buildSetup()
                : _phase == _Phase.completed ? _buildCompletion()
                : _buildTimer(),
          )),
        ])),
        // Milestone toast
        if (_milestoneMsg != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 30, right: 30,
            child: _MilestoneToast(msg: _milestoneMsg!)),
      ]),
    );
  }

  //  App bar 
  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8, right: 16, bottom: 8),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _brown, size: 22),
          onPressed: () {
            if (_phase == _Phase.running || _phase == _Phase.paused ||
                _phase == _Phase.onBreak) {
              _showExitConfirm();
            } else {
              _stopAmbient();
              Navigator.of(context).pop();
            }
          }),
        Expanded(child: Text('Study Session', textAlign: TextAlign.center,
          style: GoogleFonts.gaegu(
            fontSize: 24, fontWeight: FontWeight.w700, color: _brown))),
        // Live study time badge (during timer)
        if (_phase != _Phase.setup && _phase != _Phase.completed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_goldLt, _goldHdr]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _goldDk.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: _goldDk.withOpacity(0.15),
                offset: const Offset(0, 2), blurRadius: 0)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 3),
              Text(_fmtMin(_totalStudiedSec), style: GoogleFonts.gaegu(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          )
        else
          const SizedBox(width: 40),
      ]),
    );
  }

  void _showExitConfirm() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('End Session?', style: GoogleFonts.gaegu(
        fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
      content: Text(
        'You\'ve studied for ${_fmtMin(_totalStudiedSec)}. Save progress?',
        style: GoogleFonts.nunito(fontSize: 14, color: _brownLt)),
      actions: [
        TextButton(
          onPressed: () { Navigator.pop(ctx); _stopAmbient(); Navigator.pop(context); },
          child: Text('Discard', style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700, color: _coralHdr))),
        TextButton(
          onPressed: () { Navigator.pop(ctx); _stopTimer(); },
          child: Text('Save & Finish', style: GoogleFonts.gaegu(
            fontSize: 16, fontWeight: FontWeight.w700, color: _greenDk))),
      ],
    ));
  }

  // 
  //  1. SETUP PHASE
  // 
  Widget _buildSetup() {
    return Column(children: [
      //  Compact motivational + quote 
      _stag(0.0, Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_typeColorLight(_sessionType).withOpacity(0.3),
                     _typeColor(_sessionType).withOpacity(0.1)]),
          borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: _typeColor(_sessionType)),
          const SizedBox(width: 10),
          Expanded(child: Text(_quote, style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic,
            color: _brownLt))),
        ]),
      )),
      const SizedBox(height: 14),

      //  Session Type — compact row 
      _stag(0.03, _buildTypeChips()),
      const SizedBox(height: 14),

      //  Subject & Title card 
      _stag(0.06, _buildDetailsCard()),
      const SizedBox(height: 14),

      //  Duration picker 
      _stag(0.09, _buildDurationCard()),
      const SizedBox(height: 14),

      //  Ambient Sound picker 
      _stag(0.12, _buildAmbientCard()),
      const SizedBox(height: 20),

      //  Start button 
      _stag(0.15, _GameButton(
        icon: Icons.play_arrow_rounded,
        label: 'Start Studying',
        gradTop: _greenLt, gradBot: _greenHdr,
        borderColor: _greenDk,
        onTap: _startTimer)),
      const SizedBox(height: 14),

      //  Bottom row: Past Sessions + XP Tip 
      _stag(0.18, Row(children: [
        // Past sessions button
        Expanded(child: GestureDetector(
          onTap: _showPastSessions,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outline.withOpacity(0.1), width: 1.5)),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _purpleHdr.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.history_rounded, size: 14, color: _purpleHdr)),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Past Sessions', style: GoogleFonts.gaegu(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _brown)),
                  Text('${_pastSessions.length} recorded', style: GoogleFonts.nunito(
                    fontSize: 10, color: _brownLt)),
                ])),
              Icon(Icons.chevron_right_rounded, size: 16,
                color: _brownLt.withOpacity(0.3)),
            ]),
          ),
        )),
        const SizedBox(width: 10),
        // XP tip
        Expanded(child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFFF8E0), const Color(0xFFFFFAEE)]),
            borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.star_rounded, size: 14, color: _goldDk)),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('25 XP / 30min', style: GoogleFonts.gaegu(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _brown)),
                Text('+25% focus bonus', style: GoogleFonts.nunito(
                  fontSize: 10, color: _brownLt)),
              ])),
          ]),
        )),
      ])),
    ]);
  }

  //  Session type — compact horizontal chips 
  Widget _buildTypeChips() {
    const types = ['focused', 'review', 'practice', 'lecture'];
    const labels = ['Focused', 'Review', 'Practice', 'Lecture'];
    final icons = [
      Icons.center_focus_strong_rounded,
      Icons.replay_rounded,
      Icons.edit_note_rounded,
      Icons.headset_rounded,
    ];

    return Row(children: List.generate(4, (i) {
      final sel = _sessionType == types[i];
      final color = _typeColor(types[i]);
      final colorLt = _typeColorLight(types[i]);
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
        child: GestureDetector(
          onTap: () => setState(() => _sessionType = types[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: sel ? LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [colorLt, color]) : null,
              color: sel ? null : _cardFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? color.withOpacity(0.5) : _outline.withOpacity(0.12),
                width: sel ? 2 : 1.5),
              boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.2),
                offset: const Offset(0, 2), blurRadius: 0)] : []),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icons[i], size: 18, color: sel ? Colors.white : color),
              const SizedBox(height: 4),
              Text(labels[i], style: GoogleFonts.gaegu(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: sel ? Colors.white : _brown)),
            ]),
          ),
        ),
      ));
    }));
  }

  //  Subject & Title card 
  Widget _buildDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.12), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.04),
          offset: const Offset(0, 3), blurRadius: 10)]),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_purpleLt.withOpacity(0.5), _purpleHdr.withOpacity(0.3)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16))),
          child: Row(children: [
            Icon(Icons.tune_rounded, size: 14, color: _purpleDk),
            const SizedBox(width: 8),
            Text('Session Details', style: GoogleFonts.gaegu(
              fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject', style: GoogleFonts.gaegu(
              fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _showSubjectSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outline.withOpacity(0.1), width: 1.5)),
                child: Row(children: [
                  if (_selectedSubjectName != null) ...[
                    Container(width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: _parseColor(_selectedSubjectColor) ?? _greenHdr,
                        shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_selectedSubjectName!,
                      style: GoogleFonts.nunito(fontSize: 13, color: _brown,
                        fontWeight: FontWeight.w600))),
                  ] else ...[
                    Icon(Icons.add_circle_outline_rounded, size: 15,
                      color: _brownLt.withOpacity(0.4)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Choose a subject (optional)',
                      style: GoogleFonts.nunito(fontSize: 13,
                        color: _brownLt.withOpacity(0.5)))),
                  ],
                  Icon(Icons.expand_more_rounded, size: 18,
                    color: _brownLt.withOpacity(0.3)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Text('Session Title', style: GoogleFonts.gaegu(
              fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _outline.withOpacity(0.1), width: 1.5)),
              child: TextField(
                controller: _titleCtrl,
                style: GoogleFonts.nunito(fontSize: 13, color: _brown),
                decoration: InputDecoration(
                  hintText: 'e.g. Chapter 5 Review, Midterm Prep...',
                  hintStyle: GoogleFonts.nunito(fontSize: 13,
                    color: _brownLt.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.edit_rounded, size: 16,
                    color: _brownLt.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10)),
              ),
            ),
          ],
        )),
      ]),
    );
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
        setState(() {
          _selectedSubjectId = id;
          _selectedSubjectName = id != null ? name : null;
          _selectedSubjectColor = colorHex;
        });
        Navigator.pop(ctx);
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

  //  Duration card 
  Widget _buildDurationCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.12), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.04),
          offset: const Offset(0, 3), blurRadius: 10)]),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_greenLt.withOpacity(0.5), _greenHdr.withOpacity(0.3)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16))),
          child: Row(children: [
            Icon(Icons.timer_rounded, size: 14, color: _greenDk),
            const SizedBox(width: 8),
            Text('Duration', style: GoogleFonts.gaegu(
              fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8)),
              child: Text('$_durationMin min', style: GoogleFonts.gaegu(
                fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
            ),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          Row(children: [
            _DurationChip(min: 25, label: '25m', desc: 'Pomodoro',
              selected: !_customDuration && _durationMin == 25,
              onTap: () => setState(() { _customDuration = false; _durationMin = 25; })),
            const SizedBox(width: 8),
            _DurationChip(min: 45, label: '45m', desc: 'Deep focus',
              selected: !_customDuration && _durationMin == 45,
              onTap: () => setState(() { _customDuration = false; _durationMin = 45; })),
            const SizedBox(width: 8),
            _DurationChip(min: 60, label: '60m', desc: 'Marathon',
              selected: !_customDuration && _durationMin == 60,
              onTap: () => setState(() { _customDuration = false; _durationMin = 60; })),
            const SizedBox(width: 8),
            _DurationChip(min: 0, label: 'Custom', desc: '$_durationMin min',
              selected: _customDuration, isCustom: true,
              onTap: () => setState(() => _customDuration = true)),
          ]),
          if (_customDuration) ...[
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _purpleHdr,
                inactiveTrackColor: _outline.withOpacity(0.08),
                thumbColor: _purpleHdr,
                overlayColor: _purpleHdr.withOpacity(0.12),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10)),
              child: Slider(
                value: _durationMin.toDouble(),
                min: 5, max: 180, divisions: 35,
                onChanged: (v) => setState(() => _durationMin = v.round()),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('5 min', style: GoogleFonts.nunito(fontSize: 10, color: _brownLt)),
              Text('180 min', style: GoogleFonts.nunito(fontSize: 10, color: _brownLt)),
            ]),
          ],
          if (!_customDuration) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _greenHdr.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 12, color: _greenDk.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Pomodoro: ${_durationMin}min focus → 5min break. Long break every 4.',
                  style: GoogleFonts.nunito(fontSize: 11, color: _brownLt, height: 1.3))),
              ]),
            ),
          ],
        ])),
      ]),
    );
  }

  //  Ambient sounds picker with REAL audio 
  Widget _buildAmbientCard() {
    const sounds = ['none', 'rain', 'lofi', 'cafe', 'ocean', 'fire', 'birds'];
    const labels = ['Off', 'Rain', 'Lo-fi', 'Café', 'Ocean', 'Fire', 'Birds'];
    const icons = [
      Icons.volume_off_rounded, Icons.water_drop_rounded,
      Icons.headphones_rounded, Icons.local_cafe_rounded,
      Icons.waves_rounded, Icons.local_fire_department_rounded,
      Icons.park_rounded,
    ];
    final colors = [_brownLt, _skyHdr, _purpleHdr, _coralHdr, _skyHdr, _coralHdr, _greenHdr];

    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.12), width: 1.5)),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_skyLt.withOpacity(0.4), _skyHdr.withOpacity(0.2)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16))),
          child: Row(children: [
            Icon(Icons.music_note_rounded, size: 14, color: _skyHdr),
            const SizedBox(width: 8),
            Text('Ambient Sound', style: GoogleFonts.gaegu(
              fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
            const Spacer(),
            if (_audioLoading)
              SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: _skyHdr))
            else if (_ambientSound != 'none')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _greenHdr.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.volume_up_rounded, size: 9, color: _greenDk),
                  const SizedBox(width: 3),
                  Text('PLAYING', style: GoogleFonts.nunito(
                    fontSize: 8, fontWeight: FontWeight.w700, color: _greenDk)),
                ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Row(children: List.generate(7, (i) {
            final sel = _ambientSound == sounds[i];
            return Expanded(child: Padding(
              padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? colors[i].withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: sel ? Border.all(color: colors[i].withOpacity(0.3), width: 1.5) : null),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icons[i], size: 16,
                      color: sel ? colors[i] : _brownLt.withOpacity(0.4)),
                    const SizedBox(height: 3),
                    Text(labels[i], style: GoogleFonts.nunito(
                      fontSize: 9, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? _brown : _brownLt.withOpacity(0.5))),
                  ]),
                ),
              ),
            ));
          })),
        ),
      ]),
    );
  }

  // 
  //  2. TIMER PHASE
  // 
  Widget _buildTimer() {
    final totalSec = _isBreakPhase
        ? ((_pomodoroCount % 4 == 0) ? 15 : 5) * 60
        : _durationMin * 60;
    final progress = totalSec > 0 ? 1.0 - (_remainSec / totalSec) : 0.0;
    final themeColor = _isBreakPhase ? _greenHdr : _typeColor(_sessionType);
    final themeColorLt = _isBreakPhase ? _greenLt : _typeColorLight(_sessionType);

    return Column(children: [
      const SizedBox(height: 8),

      //  Phase pill 
      AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) {
          final op = _phase == _Phase.paused ? 0.4 + _pulseCtrl.value * 0.6 : 1.0;
          return Opacity(opacity: op, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [themeColorLt.withOpacity(0.3), themeColor.withOpacity(0.15)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isBreakPhase ? Icons.coffee_rounded : _typeIcon(_sessionType),
                size: 14, color: themeColor),
              const SizedBox(width: 6),
              Text(
                _isBreakPhase ? 'Break Time'
                    : _phase == _Phase.paused ? 'Paused'
                    : 'Focus ${_pomodoroCount + 1}${!_customDuration ? '/∞' : ''}',
                style: GoogleFonts.gaegu(fontSize: 15, fontWeight: FontWeight.w700,
                  color: _brown)),
              if (_selectedSubjectName != null) ...[
                Container(width: 1, height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: _outline.withOpacity(0.15)),
                Text(_selectedSubjectName!, style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt),
                  overflow: TextOverflow.ellipsis),
              ],
            ]),
          ));
        },
      ),
      const SizedBox(height: 20),

      //  Timer circle with breathing ring 
      AnimatedBuilder(
        animation: _breatheCtrl,
        builder: (_, __) {
          final breathe = 1.0 + _breatheCtrl.value * 0.015;
          return Transform.scale(scale: breathe, child: SizedBox(
            width: 240, height: 240,
            child: Stack(alignment: Alignment.center, children: [
              // Outer glow
              Container(
                width: 240, height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: themeColor.withOpacity(0.08 + _breatheCtrl.value * 0.04),
                    blurRadius: 30, spreadRadius: 5)])),
              // Progress ring
              SizedBox(width: 240, height: 240,
                child: CustomPaint(painter: _RingPainter(
                  progress: progress,
                  color1: themeColorLt,
                  color2: themeColor,
                  bgColor: _outline.withOpacity(0.06)))),
              // Inner circle
              Container(
                width: 195, height: 195,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withOpacity(0.9),
                    _cardFill]),
                  border: Border.all(color: _outline.withOpacity(0.08), width: 2),
                  boxShadow: [BoxShadow(
                    color: _outline.withOpacity(0.03),
                    offset: const Offset(0, 4), blurRadius: 12)]),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_isBreakPhase ? 'BREAK' : 'FOCUS',
                    style: GoogleFonts.nunito(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: themeColor, letterSpacing: 2)),
                  const SizedBox(height: 2),
                  Text(_fmtTime(_remainSec), style: GoogleFonts.gaegu(
                    fontSize: 54, fontWeight: FontWeight.w700,
                    color: _brown, height: 1.0)),
                  const SizedBox(height: 4),
                  Text(
                    _isBreakPhase ? 'relax & recharge'
                        : _remainSec > 60 ? '${(_remainSec / 60).ceil()} min left'
                        : '${_remainSec}s left',
                    style: GoogleFonts.nunito(fontSize: 11,
                      fontWeight: FontWeight.w600, color: _brownLt)),
                ]),
              ),
            ]),
          ));
        },
      ),
      const SizedBox(height: 24),

      //  Control buttons row 
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Distraction counter (only during focus)
        if (!_isBreakPhase)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _CircleBtn(
              gradTop: _purpleLt, gradBot: _purpleHdr,
              borderColor: _purpleDk, shadowColor: _purpleDk,
              icon: Icons.notifications_active_rounded, size: 44, iconSize: 18,
              onTap: () {
                setState(() => _distractionCount++);
                HapticFeedback.lightImpact();
                _showMilestone('Distraction #$_distractionCount noted');
              }),
          ),

        if (_phase == _Phase.paused) ...[
          _CircleBtn(
            gradTop: _greenLt, gradBot: _greenHdr,
            borderColor: _greenDk, shadowColor: _greenDk,
            icon: Icons.play_arrow_rounded, size: 60, iconSize: 30,
            onTap: _resumeTimer),
        ] else if (_phase == _Phase.onBreak) ...[
          _CircleBtn(
            gradTop: _greenLt, gradBot: _greenHdr,
            borderColor: _greenDk, shadowColor: _greenDk,
            icon: Icons.skip_next_rounded, size: 60, iconSize: 28,
            onTap: _skipBreak),
        ] else ...[
          _CircleBtn(
            gradTop: const Color(0xFFFFE888), gradBot: _goldHdr,
            borderColor: _goldDk, shadowColor: _goldDk,
            icon: Icons.pause_rounded, size: 60, iconSize: 26,
            onTap: _pauseTimer),
        ],
        const SizedBox(width: 16),
        _CircleBtn(
          gradTop: _coralLt, gradBot: _coralHdr,
          borderColor: const Color(0xFFD08878),
          shadowColor: const Color(0xFFD08878),
          icon: Icons.stop_rounded, size: 60, iconSize: 26,
          onTap: _stopTimer),
      ]),
      const SizedBox(height: 18),

      //  Live stats strip 
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline.withOpacity(0.1), width: 1.5)),
        child: Row(children: [
          _miniStat(Icons.timer_rounded, _fmtMin(_totalStudiedSec), 'studied', _pinkHdr),
          Container(width: 1, height: 24, color: _outline.withOpacity(0.08)),
          _miniStat(Icons.repeat_rounded, '$_pomodoroCount', 'pomodoros', _greenHdr),
          Container(width: 1, height: 24, color: _outline.withOpacity(0.08)),
          _miniStat(Icons.star_rounded, '~${((_totalStudiedSec / 1800) * 25).round()}',
            'XP est.', _goldHdr),
          if (_distractionCount > 0) ...[
            Container(width: 1, height: 24, color: _outline.withOpacity(0.08)),
            _miniStat(Icons.notifications_active_rounded, '$_distractionCount',
              'distractions', _purpleHdr),
          ],
        ]),
      ),
      const SizedBox(height: 12),

      //  Ambient sound indicator 
      if (_ambientSound != 'none')
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _skyHdr.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _skyHdr.withOpacity(0.15), width: 1)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_ambientIcon(_ambientSound), size: 14, color: _skyHdr),
            const SizedBox(width: 6),
            Text('${_ambientLabel(_ambientSound)} playing',
              style: GoogleFonts.nunito(fontSize: 11,
                fontWeight: FontWeight.w600, color: _brownLt)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _stopAmbient,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _coralHdr.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
                child: Text('Stop', style: GoogleFonts.nunito(
                  fontSize: 9, fontWeight: FontWeight.w700, color: _coralHdr)),
              ),
            ),
          ]),
        ),

      //  NOTES SECTION — clean, always visible 
      _buildNotesSection(),
    ]);
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

  //  NOTES SECTION — Notion-style clean editor with rich text 
  Widget _buildNotesSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.12), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.04),
          offset: const Offset(0, 3), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        //  Header with gradient 
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _goldLt.withOpacity(0.4), _goldHdr.withOpacity(0.2)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16))),
          child: Row(children: [
            Icon(Icons.sticky_note_2_rounded, size: 15, color: _goldDk),
            const SizedBox(width: 8),
            Text('Session Notes', style: GoogleFonts.gaegu(
              fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
            const Spacer(),
            // PDF export button
            GestureDetector(
              onTap: _exportNotesPdf,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _goldDk.withOpacity(0.2), width: 1)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.picture_as_pdf_rounded, size: 12, color: _coralHdr),
                  const SizedBox(width: 4),
                  Text('Export PDF', style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w700, color: _brown)),
                ]),
              ),
            ),
          ]),
        ),

        Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //  Topics as pill chips 
            Row(children: [
              Icon(Icons.tag_rounded, size: 13, color: _purpleHdr),
              const SizedBox(width: 6),
              Text('Topics', style: GoogleFonts.gaegu(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
            ]),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _outline.withOpacity(0.06), width: 1)),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                ..._topics.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _purpleLt.withOpacity(0.3), _purpleHdr.withOpacity(0.15)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _purpleHdr.withOpacity(0.2), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t, style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w600, color: _brown)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _topics.remove(t)),
                      child: Icon(Icons.close_rounded, size: 11,
                        color: _purpleHdr.withOpacity(0.5))),
                  ]),
                )),
                // Inline add
                SizedBox(width: 120, height: 26, child: TextField(
                  controller: _topicCtrl,
                  style: GoogleFonts.nunito(fontSize: 11, color: _brown),
                  decoration: InputDecoration(
                    hintText: '+ add topic',
                    hintStyle: GoogleFonts.nunito(fontSize: 11,
                      color: _brownLt.withOpacity(0.3)),
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

            //  Formatting toolbar 
            Row(children: [
              Icon(Icons.edit_rounded, size: 13, color: _goldDk),
              const SizedBox(width: 6),
              Text('Notes', style: GoogleFonts.gaegu(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
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

            //  Text editor 
            Container(
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _outline.withOpacity(0.06), width: 1),
                boxShadow: [BoxShadow(color: _outline.withOpacity(0.02),
                  offset: const Offset(0, 1), blurRadius: 4)]),
              child: TextField(
                controller: _notesCtrl,
                style: GoogleFonts.nunito(
                  fontSize: 13, color: _brown, height: 1.6,
                  fontWeight: _bold ? FontWeight.w700 : FontWeight.w400,
                  fontStyle: _italic ? FontStyle.italic : FontStyle.normal),
                maxLines: null, minLines: 5,
                decoration: InputDecoration(
                  hintText: 'Key takeaways, formulas, ideas, things to review...\n\nUse the toolbar above for formatting.',
                  hintStyle: GoogleFonts.nunito(fontSize: 12,
                    color: _brownLt.withOpacity(0.25), height: 1.6),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14)),
              ),
            ),
            const SizedBox(height: 8),

            //  Info strip 
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _purpleHdr.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 11,
                  color: _purpleDk.withOpacity(0.4)),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Notes save with your session. Export as PDF anytime.',
                  style: GoogleFonts.nunito(fontSize: 10,
                    color: _brownLt, height: 1.3))),
              ]),
            ),
          ],
        )),
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

  // 
  //  3. COMPLETION PHASE
  // 
  Widget _buildCompletion() {
    final mins = (_totalStudiedSec / 60).ceil();
    final baseXp = (mins / 30 * 25).floor();
    final bonusXp = _focusScore >= 80 ? (baseXp * 0.25).floor() : 0;

    return Column(children: [
      const SizedBox(height: 8),

      //  Trophy + celebration 
      _stag(0.0, Column(children: [
        SizedBox(height: 80, child: CustomPaint(
          painter: _ConfettiPainter(progress: _enterCtrl.value),
          size: const Size(double.infinity, 80))),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFFFFE888), Color(0xFFE8C840)]),
            shape: BoxShape.circle,
            border: Border.all(color: _goldDk.withOpacity(0.4), width: 3),
            boxShadow: [
              BoxShadow(color: _goldDk.withOpacity(0.25),
                offset: const Offset(0, 4), blurRadius: 0),
              BoxShadow(color: _goldHdr.withOpacity(0.15),
                blurRadius: 20, spreadRadius: 5)]),
          child: const Icon(Icons.emoji_events_rounded, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text('Session Complete!', style: GoogleFonts.gaegu(
          fontSize: 30, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 4),
        if (_titleCtrl.text.trim().isNotEmpty)
          Text(_titleCtrl.text.trim(), style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt)),
      ])),
      const SizedBox(height: 20),

      //  Detailed stats card 
      _stag(0.1, Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline.withOpacity(0.12), width: 1.5),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.04),
            offset: const Offset(0, 4), blurRadius: 12)]),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_pinkLt.withOpacity(0.4), _pinkHdr.withOpacity(0.25)]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18))),
            child: Text('Session Summary', style: GoogleFonts.gaegu(
              fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _summaryRow(Icons.timer_rounded, 'Time Studied', '${mins} min', _pinkHdr),
            _summaryRow(Icons.repeat_rounded, 'Pomodoros', '$_pomodoroCount completed', _greenHdr),
            _summaryRow(_typeIcon(_sessionType), 'Session Type',
              _sessionType[0].toUpperCase() + _sessionType.substring(1), _typeColor(_sessionType)),
            if (_selectedSubjectName != null)
              _summaryRow(Icons.menu_book_rounded, 'Subject', _selectedSubjectName!, _purpleHdr),
            if (_topics.isNotEmpty)
              _summaryRow(Icons.tag_rounded, 'Topics', _topics.join(', '), _skyHdr),
            if (_distractionCount > 0)
              _summaryRow(Icons.notifications_active_rounded, 'Distractions',
                '$_distractionCount noted', _coralHdr),
          ])),
        ]),
      )),
      const SizedBox(height: 16),

      //  Focus score card with custom faces 
      _stag(0.15, Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline.withOpacity(0.12), width: 1.5)),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_purpleLt.withOpacity(0.4), _purpleHdr.withOpacity(0.25)]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18))),
            child: Row(children: [
              Text('Focus Score', style: GoogleFonts.gaegu(
                fontSize: 16, fontWeight: FontWeight.w700, color: _brown)),
              const Spacer(),
              Text('$_focusScore%', style: GoogleFonts.gaegu(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: _focusColor(_focusScore))),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [20, 40, 60, 80, 100].map((v) {
                final sel = (_focusScore - v).abs() < 10;
                return GestureDetector(
                  onTap: () => setState(() => _focusScore = v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: sel ? 44 : 36, height: sel ? 44 : 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? _focusColor(v).withOpacity(0.15) : Colors.transparent,
                      border: sel ? Border.all(color: _focusColor(v).withOpacity(0.3), width: 2) : null),
                    child: CustomPaint(painter: _FacePainter(
                      score: v,
                      color: sel ? _focusColor(v) : _brownLt.withOpacity(0.4),
                      size: sel ? 44 : 36)),
                  ),
                );
              }).toList()),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _focusColor(_focusScore),
                inactiveTrackColor: _outline.withOpacity(0.06),
                thumbColor: _focusColor(_focusScore),
                overlayColor: _focusColor(_focusScore).withOpacity(0.12),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10)),
              child: Slider(
                value: _focusScore.toDouble(),
                min: 1, max: 100,
                onChanged: (v) => setState(() => _focusScore = v.round()),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Distracted', style: GoogleFonts.nunito(fontSize: 10, color: _brownLt)),
              Text('Laser focus', style: GoogleFonts.nunito(fontSize: 10, color: _brownLt)),
            ]),
            if (_focusScore >= 80) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _greenHdr.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _greenHdr.withOpacity(0.2), width: 1)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, size: 14, color: _greenDk),
                  const SizedBox(width: 4),
                  Text('+25% XP focus bonus!', style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _greenDk)),
                ]),
              ),
            ],
          ])),
        ]),
      )),
      const SizedBox(height: 16),

      //  Notes section on completion (editable) 
      if (!_saved) ...[
        _buildNotesSection(),
        const SizedBox(height: 16),
      ],

      //  XP Breakdown card 
      if (_saved) ...[
        _stag(0.2, AnimatedBuilder(
          animation: _xpCtrl,
          builder: (_, __) {
            final t = Curves.easeOutBack.transform(_xpCtrl.value);
            return Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.scale(
              scale: 0.8 + 0.2 * t,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF8E0), Color(0xFFFFF0C0)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _goldDk.withOpacity(0.3), width: 2),
                  boxShadow: [BoxShadow(color: _goldDk.withOpacity(0.15),
                    offset: const Offset(0, 4), blurRadius: 0)]),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.star_rounded, size: 28, color: Color(0xFFE8C840)),
                    const SizedBox(width: 8),
                    Text('+$_xpEarned XP', style: GoogleFonts.gaegu(
                      fontSize: 32, fontWeight: FontWeight.w700, color: _brown)),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _xpChip('Base', '$baseXp XP', _goldHdr),
                    if (bonusXp > 0) ...[
                      const SizedBox(width: 8),
                      Text('+', style: GoogleFonts.gaegu(fontSize: 16, color: _brownLt)),
                      const SizedBox(width: 8),
                      _xpChip('Focus Bonus', '+$bonusXp XP', _greenHdr),
                    ],
                  ]),
                ]),
              ),
            ));
          },
        )),
        const SizedBox(height: 16),
      ],

      //  Action buttons 
      if (!_saved) ...[
        _GameButton(
          icon: Icons.save_rounded,
          label: _saving ? 'Saving...' : 'Save Session',
          gradTop: _greenLt, gradBot: _greenHdr,
          borderColor: _greenDk, loading: _saving,
          onTap: _saveSession),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Discard', style: GoogleFonts.gaegu(
              fontSize: 16, fontWeight: FontWeight.w700, color: _brownLt)))),
      ] else ...[
        _GameButton(
          icon: Icons.check_rounded,
          label: 'Done',
          gradTop: _pinkLt, gradBot: _pinkHdr,
          borderColor: _pinkHdr,
          onTap: () => Navigator.pop(context)),
      ],
      const SizedBox(height: 16),
    ]);
  }

  Color _focusColor(int score) {
    if (score >= 80) return _greenHdr;
    if (score >= 60) return _goldHdr;
    if (score >= 40) return const Color(0xFFE8A870);
    return _coralHdr;
  }

  Widget _summaryRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt)),
        const Spacer(),
        Flexible(child: Text(value, style: GoogleFonts.gaegu(
          fontSize: 15, fontWeight: FontWeight.w700, color: _brown),
          textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _xpChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25), width: 1)),
      child: Column(children: [
        Text(value, style: GoogleFonts.gaegu(
          fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
        Text(label, style: GoogleFonts.nunito(
          fontSize: 9, fontWeight: FontWeight.w600, color: _brownLt)),
      ]),
    );
  }

  Widget _stag(double delay, Widget child) {
    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(
          ((_enterCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
        return Opacity(opacity: t, child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)), child: child));
      },
    );
  }
}

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

  List<Map<String, dynamic>> get _filtered {
    var list = widget.sessions;
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

  //  Update session notes/title 
  Future<void> _updateSession(String sessionId, {String? notes, String? title,
      List<String>? topics}) async {
    try {
      final body = <String, dynamic>{};
      if (notes != null) body['notes'] = notes;
      if (title != null) body['title'] = title;
      if (topics != null) body['topics_covered'] = topics;
      await widget.api.put('/study/sessions/$sessionId', data: body);
      widget.onRefresh();
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

  //  Delete a session 
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
      widget.onRefresh();
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

  //  Build a single session PDF page content 
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

  //  Export multiple sessions as one combined PDF 
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

  //  Export each selected session as its own PDF file 
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

  //  Full-screen note viewer dialog 
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
              //  Header with gradient 
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
              //  Stats pills 
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
              //  Topics 
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
              //  Scrollable notes body (editable or read-only) 
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
      builder: (_, scrollCtrl) => Column(children: [
        // Handle + header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: _outline.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(children: [
              Text('Past Sessions', style: GoogleFonts.gaegu(
                fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
              const Spacer(),
              Text('${filtered.length} of ${widget.sessions.length}',
                style: GoogleFonts.nunito(fontSize: 12, color: _brownLt)),
              const SizedBox(width: 8),
              // Select mode toggle
              GestureDetector(
                onTap: () => setState(() {
                  _selectMode = !_selectMode;
                  if (!_selectMode) _selected.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selectMode
                        ? _skyHdr.withOpacity(0.15) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectMode
                          ? _skyHdr.withOpacity(0.35) : _outline.withOpacity(0.1),
                      width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_selectMode ? Icons.check_box_rounded : Icons.checklist_rounded,
                      size: 13,
                      color: _selectMode ? _skyHdr : _brownLt.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(_selectMode ? 'Done' : 'Select',
                      style: GoogleFonts.nunito(fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _selectMode ? _skyHdr : _brownLt)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              // Export all as PDF
              GestureDetector(
                onTap: () => _exportSessionsPdf(filtered),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _coralHdr.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _coralHdr.withOpacity(0.2), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 13, color: _coralHdr),
                    const SizedBox(width: 4),
                    Text('PDF', style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _brown)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 10),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outline.withOpacity(0.08), width: 1.5)),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.nunito(fontSize: 13, color: _brown),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search sessions...',
                hintStyle: GoogleFonts.nunito(fontSize: 13,
                  color: _brownLt.withOpacity(0.35)),
                prefixIcon: Icon(Icons.search_rounded, size: 18,
                  color: _brownLt.withOpacity(0.35)),
                suffixIcon: _query.isNotEmpty ? GestureDetector(
                  onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
                  child: Icon(Icons.close_rounded, size: 16,
                    color: _brownLt.withOpacity(0.4)),
                ) : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter chips
        Padding(
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
        ),
        const SizedBox(height: 10),

        // Sessions list
        Expanded(child: widget.loading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: _pinkHdr))
          : filtered.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded, size: 40,
                  color: _brownLt.withOpacity(0.3)),
                const SizedBox(height: 8),
                Text(_query.isNotEmpty || _filterType != 'all'
                    ? 'No matching sessions' : 'No sessions yet',
                  style: GoogleFonts.gaegu(fontSize: 18,
                    fontWeight: FontWeight.w700, color: _brownLt)),
                if (_query.isEmpty && _filterType == 'all')
                  Text('Complete your first session!', style: GoogleFonts.nunito(
                    fontSize: 13, color: _brownLt.withOpacity(0.6))),
              ]))
            : ListView.builder(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(16, 0, 16,
                  hasSelection ? 70 : 16),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _sessionTile(filtered[i], i))),

        //  Selection action bar 
        if (hasSelection)
          Container(
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
      ]),
    );
  }

  Widget _filterChip(String type, String label, IconData icon, Color color) {
    final sel = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? color.withOpacity(0.35) : _outline.withOpacity(0.08),
            width: sel ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: sel ? color : _brownLt.withOpacity(0.4)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? _brown : _brownLt)),
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
    Color typeColorLt;
    switch (type) {
      case 'focused': typeColor = _pinkHdr; typeColorLt = _pinkLt; break;
      case 'review': typeColor = _skyHdr; typeColorLt = _skyLt; break;
      case 'practice': typeColor = _greenHdr; typeColorLt = _greenLt; break;
      case 'lecture': typeColor = _purpleHdr; typeColorLt = _purpleLt; break;
      default: typeColor = _pinkHdr; typeColorLt = _pinkLt;
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? _skyHdr.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? _skyHdr.withOpacity(0.35)
                : isExpanded ? typeColor.withOpacity(0.25) : _outline.withOpacity(0.08),
            width: isSelected || isExpanded ? 2 : 1.5)),
        child: Column(children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                typeColorLt.withOpacity(0.3), typeColor.withOpacity(0.15)]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12), topRight: Radius.circular(12))),
            child: Row(children: [
              // Checkbox in select mode
              if (_selectMode) ...[
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: isSelected ? _skyHdr : _brownLt.withOpacity(0.3)),
                const SizedBox(width: 6),
              ],
              Icon(typeIcon, size: 14, color: typeColor),
              const SizedBox(width: 6),
              Text(type[0].toUpperCase() + type.substring(1),
                style: GoogleFonts.gaegu(fontSize: 14,
                  fontWeight: FontWeight.w700, color: _brown)),
              if (title != null && title.isNotEmpty) ...[
                Text(' — ', style: GoogleFonts.nunito(fontSize: 11, color: _brownLt)),
                Expanded(child: Text(title, style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _brown),
                  overflow: TextOverflow.ellipsis)),
              ] else
                const Spacer(),
              if (created != null)
                Text('${created.month}/${created.day}', style: GoogleFonts.nunito(
                  fontSize: 11, color: _brownLt)),
              if (!_selectMode) ...[
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, size: 16,
                    color: _brownLt.withOpacity(0.4))),
              ],
            ]),
          ),
          // Stats row always visible
          Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), child: Row(children: [
            _tinyPill(Icons.timer_rounded, '${mins}m', _pinkHdr),
            const SizedBox(width: 6),
            _tinyPill(Icons.star_rounded, '+${xp} XP', _goldHdr),
            if (focus != null) ...[
              const SizedBox(width: 6),
              _tinyPill(Icons.speed_rounded, '${focus}%', _greenHdr),
            ],
          ])),
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
        ]),
      ),
    );
  }

  Widget _tinyPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(text, style: GoogleFonts.gaegu(
          fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

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

  final double progress;
  final Color color1, color2, bgColor;
  _RingPainter({required this.progress, required this.color1,
    required this.color2, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeW = 10.0;

    canvas.drawCircle(center, radius,
      Paint()..style = PaintingStyle.stroke..strokeWidth = strokeW..color = bgColor);

    if (progress > 0) {
      final sweep = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweep, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(color1, color2, progress) ?? color2);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFF8E0), Color(0xFFFFF0C0)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _goldDk.withOpacity(0.3), width: 2),
          boxShadow: [BoxShadow(color: _goldDk.withOpacity(0.15),
            offset: const Offset(0, 3), blurRadius: 0)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.celebration_rounded, size: 16, color: _goldDk),
          const SizedBox(width: 8),
          Flexible(child: Text(msg, style: GoogleFonts.gaegu(
            fontSize: 15, fontWeight: FontWeight.w700, color: _brown))),
        ]),
      ),
    );
  }
}

  final int min;
  final String label, desc;
  final bool selected, isCustom;
  final VoidCallback onTap;
  const _DurationChip({required this.min, required this.label,
    required this.desc, required this.selected, this.isCustom = false,
    required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: isCustom ? [_purpleLt, _purpleHdr] : [_greenLt, _greenHdr]) : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? (isCustom ? _purpleDk : _greenDk).withOpacity(0.4)
                : _outline.withOpacity(0.1),
            width: selected ? 2 : 1.5),
          boxShadow: selected ? [BoxShadow(
            color: (isCustom ? _purpleDk : _greenDk).withOpacity(0.15),
            offset: const Offset(0, 2), blurRadius: 0)] : []),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: GoogleFonts.gaegu(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _brown)),
          Text(desc, style: GoogleFonts.nunito(
            fontSize: 9, fontWeight: FontWeight.w500,
            color: selected ? Colors.white.withOpacity(0.8) : _brownLt)),
        ]),
      ),
    ));
  }
}

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
        transform: Matrix4.translationValues(0, _p ? 3 : 0, 0),
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [widget.gradTop, widget.gradBot]),
          shape: BoxShape.circle,
          border: Border.all(color: widget.borderColor.withOpacity(0.5), width: 2.5),
          boxShadow: _p ? [] : [BoxShadow(
            color: widget.shadowColor.withOpacity(0.35),
            offset: const Offset(0, 3), blurRadius: 0)]),
        child: Icon(widget.icon, size: widget.iconSize, color: Colors.white),
      ),
    );
  }
}

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
        transform: Matrix4.translationValues(0, _p ? 4 : 0, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [widget.gradTop, widget.gradBot]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.borderColor.withOpacity(0.5), width: 2.5),
          boxShadow: _p ? [] : [BoxShadow(
            color: widget.borderColor.withOpacity(0.35),
            offset: const Offset(0, 4), blurRadius: 0)]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (widget.loading)
            SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            Icon(widget.icon, size: 22, color: Colors.white),
          const SizedBox(width: 8),
          Text(widget.label, style: GoogleFonts.gaegu(
            fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }
}

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
