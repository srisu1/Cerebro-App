// Study calendar — monthly grid with event management.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/config/constants.dart';


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
Color get _cream => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFDEFDB);
Color get _cardFill => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF8F4);
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
Color get _greenLt => _darkMode ? const Color(0xFF143125) : const Color(0xFFC2E8BC);
Color get _skyHdr => const Color(0xFF9DD4F0);
Color get _purpleHdr => const Color(0xFFCDA8D8);
// Nullable + in-body fallback — `_brown` is now a mode-aware getter.
TextStyle _gaegu({double size = 14, FontWeight weight = FontWeight.w600, Color? color, double? h}) =>
    GoogleFonts.gaegu(fontSize: size, fontWeight: weight, color: color ?? _brown, height: h);
const _bitroad = 'Bitroad';

enum _EventType { study, exam, quiz, reminder }

/// In-memory representation of one row from `GET /study/calendar/events`.
/// `id` is the backend UUID (nullable only for transient drafts).
class _CalEvent {
  final String? id;
  final DateTime date;        // y/m/d of the start_time, used for grid bucketing
  final String title;
  final String subject;
  final _EventType type;
  final String timeLabel;     // "09:00 — 10:30" or "All day"
  final DateTime? startTime;  // raw datetimes preserved for round-tripping
  final DateTime? endTime;
  final String? description;
  _CalEvent({
    this.id,
    required this.date,
    required this.title,
    required this.subject,
    required this.type,
    required this.timeLabel,
    this.startTime,
    this.endTime,
    this.description,
  });

  factory _CalEvent.fromJson(Map<String, dynamic> j) {
    final start = _parseDt(j['start_time']);
    final end   = _parseDt(j['end_time']);
    final allDay = j['all_day'] == true;
    final d = (start ?? DateTime.now()).toLocal();
    return _CalEvent(
      id: j['id']?.toString(),
      date: DateTime(d.year, d.month, d.day),
      title: (j['title'] ?? '').toString(),
      subject: (j['subject_name'] ?? '').toString().isEmpty
          ? 'General'
          : j['subject_name'].toString(),
      type: _typeFromString(j['event_type']?.toString()),
      timeLabel: _formatTimeLabel(start?.toLocal(), end?.toLocal(), allDay),
      startTime: start,
      endTime: end,
      description: j['description']?.toString(),
    );
  }
}

DateTime? _parseDt(dynamic v) {
  if (v == null) return null;
  try { return DateTime.parse(v.toString()); } catch (_) { return null; }
}

String _formatTimeLabel(DateTime? start, DateTime? end, bool allDay) {
  if (allDay) return 'All day';
  if (start == null) return '';
  final s = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  if (end == null || end == start) return s;
  final e = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  return '$s — $e';
}

_EventType _typeFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'exam':                    return _EventType.exam;
    case 'quiz':                    return _EventType.quiz;
    case 'reminder':
    case 'break':
    case 'imported':                return _EventType.reminder;
    case 'study':
    case 'review':
    case 'flashcard':
    default:                        return _EventType.study;
  }
}

String _typeToString(_EventType t) => switch (t) {
      _EventType.study    => 'study',
      _EventType.exam     => 'exam',
      _EventType.quiz     => 'quiz',
      _EventType.reminder => 'reminder',
    };

Color _typeColor(_EventType t) => switch (t) {
      _EventType.study    => _skyHdr,
      _EventType.exam     => _coral,
      _EventType.quiz     => _gold,
      _EventType.reminder => _purpleHdr,
    };

IconData _typeIcon(_EventType t) => switch (t) {
      _EventType.study    => Icons.menu_book_rounded,
      _EventType.exam     => Icons.assignment_late_rounded,
      _EventType.quiz     => Icons.quiz_rounded,
      _EventType.reminder => Icons.notifications_active_rounded,
    };

String _typeLabel(_EventType t) => switch (t) {
      _EventType.study    => 'Study',
      _EventType.exam     => 'Exam',
      _EventType.quiz     => 'Quiz',
      _EventType.reminder => 'Reminder',
    };

//  STUDY CALENDAR SCREEN
class StudyCalendarScreen extends ConsumerStatefulWidget {
  const StudyCalendarScreen({super.key});
  @override
  ConsumerState<StudyCalendarScreen> createState() => _StudyCalendarScreenState();
}

class _StudyCalendarScreenState extends ConsumerState<StudyCalendarScreen>
    with TickerProviderStateMixin {
  late DateTime _viewMonth;
  late DateTime _selected;
  // Real events from /study/calendar/events. Starts empty and is populated
  // by _fetchEvents() on init. Mutated (not reassigned) by add/delete flows.
  List<_CalEvent> _events = [];
  bool _loadingEvents = true;
  String? _eventsError;
  late final AnimationController _enter;

  // The scheduler used to live inside Quiz Hub, but its output lands as
  // StudyEvent rows (which this screen already shows), so it belongs here
  // alongside the grid. Tab 0 = calendar, Tab 1 = smart scheduler.
  late final TabController _tabCtrl;

  bool _gcalConnected = false;
  bool _syncing = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
    _selected  = DateTime(now.year, now.month, now.day);
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchEvents();
    _checkGcalStatus();
  }

  //  Real-data wiring (replaces the old _seedEvents demo)
  Future<void> _fetchEvents() async {
    if (!mounted) return;
    setState(() { _loadingEvents = true; _eventsError = null; });
    try {
      final api = ref.read(apiServiceProvider);
      // Pull a wide window: 90 days back → 180 days forward. The calendar
      // grid lets users page months in either direction; this covers the
      // realistic working range without needing a re-fetch on every nav.
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 90)).toUtc().toIso8601String();
      final end   = now.add(const Duration(days: 180)).toUtc().toIso8601String();
      final res = await api.get('/study/calendar/events',
          queryParams: {'start': start, 'end': end});
      if (!mounted) return;
      final raw = (res.data as List?) ?? [];
      setState(() {
        _events = raw
            .whereType<Map>()
            .map((m) => _CalEvent.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        _loadingEvents = false;
      });
    } catch (e) {
      debugPrint('[CALENDAR] fetch error: $e');
      if (!mounted) return;
      setState(() {
        _events = [];
        _loadingEvents = false;
        _eventsError = 'Could not load events. Pull-to-refresh or try again.';
      });
    }
  }

  /// POST a new event and append to local state on success.
  Future<bool> _createEvent({
    required String title,
    required String subject,
    required _EventType type,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post('/study/calendar/events', data: {
        'title': title,
        'subject_name': subject,
        'event_type': _typeToString(type),
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time':   endTime.toUtc().toIso8601String(),
        'all_day': false,
      });
      if (!mounted) return false;
      final created = _CalEvent.fromJson(Map<String, dynamic>.from(res.data));
      setState(() => _events.add(created));
      _snack('Event saved');
      return true;
    } catch (e) {
      debugPrint('[CALENDAR] create error: $e');
      _snack('Could not save event', ok: false);
      return false;
    }
  }

  /// DELETE an event and remove from local state on success.
  Future<void> _deleteEvent(_CalEvent e) async {
    if (e.id == null) return;
    try {
      final api = ref.read(apiServiceProvider);
      await api.delete('/study/calendar/events/${e.id}');
      if (!mounted) return;
      setState(() => _events.removeWhere((x) => x.id == e.id));
      _snack('Event deleted');
    } catch (err) {
      debugPrint('[CALENDAR] delete error: $err');
      _snack('Could not delete event', ok: false);
    }
  }

  Future<void> _checkGcalStatus() async {
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/study/calendar/gcal/status');
      if (!mounted) return;
      setState(() => _gcalConnected = res.data['connected'] == true);
    } catch (_) {/* stay disconnected */}
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _gaegu(size: 14, weight: FontWeight.w700, color: Colors.white)),
      backgroundColor: ok ? _oliveDk : _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  Future<void> _syncGcal() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post('/study/calendar/gcal/sync?direction=both');
      final pushed = res.data?['pushed'] ?? 0;
      final pulled = res.data?['pulled'] ?? 0;
      final errors = res.data?['errors'] as List? ?? [];
      final errStr = errors.isNotEmpty ? errors.first.toString() : '';
      final msg = errStr.contains('not enabled')
          ? 'Enable Google Calendar API in Cloud Console first'
          : errors.isNotEmpty
              ? 'Sync error: $errStr'
              : 'Synced! Pushed $pushed, pulled $pulled';
      _snack(msg, ok: errors.isEmpty);
    } catch (e) {
      _snack('Sync failed: $e', ok: false);
    }
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _connectGcal() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://localhost:$port';

      final authUrl = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth').replace(
        queryParameters: {
          'client_id': AppConstants.googleClientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': 'https://www.googleapis.com/auth/calendar',
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );
      await Process.run('open', [authUrl.toString()]);

      final request = await server.first.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('Google Calendar auth timed out'),
      );
      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('<html><body style="font-family:-apple-system,sans-serif;display:flex;'
            'justify-content:center;align-items:center;height:100vh;margin:0;'
            'background:linear-gradient(135deg,#FFF8F3,#FEEDE9);">'
            '<div style="text-align:center;">'
            '<h1 style="color:#6E5848;">Calendar Connected</h1>'
            '<p style="color:#7A5840;">You can close this tab and return to CEREBRO.</p>'
            '</div></body></html>');
      await request.response.close();
      await server.close();
      server = null;

      if (error != null || code == null) {
        _snack('Calendar connection cancelled', ok: false);
        if (mounted) setState(() => _connecting = false);
        return;
      }

      final httpClient = HttpClient();
      try {
        final tokenReq = await httpClient.postUrl(Uri.parse('https://oauth2.googleapis.com/token'));
        tokenReq.headers.set('Content-Type', 'application/x-www-form-urlencoded');
        tokenReq.write(Uri(queryParameters: {
          'code': code,
          'client_id': AppConstants.googleClientId,
          'client_secret': AppConstants.googleClientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        }).query);
        final tokenResp = await tokenReq.close();
        final body = await tokenResp.transform(utf8.decoder).join();
        final tokenData = json.decode(body) as Map<String, dynamic>;
        if (!tokenData.containsKey('access_token')) {
          throw Exception(tokenData['error_description'] ?? 'No access token');
        }
        final api = ref.read(apiServiceProvider);
        await api.post('/study/calendar/gcal/connect', data: {
          'access_token': tokenData['access_token'],
          'refresh_token': tokenData['refresh_token'],
          'expires_in': tokenData['expires_in'] ?? 3600,
        });
        if (mounted) setState(() => _gcalConnected = true);
        _snack('Google Calendar connected!', ok: true);
        _syncGcal();
      } finally {
        httpClient.close();
      }
    } catch (e) {
      if (server != null) { try { await server.close(); } catch (_) {} }
      _snack('Connection failed: $e', ok: false);
    }
    if (mounted) setState(() => _connecting = false);
  }

  @override
  void dispose() {
    _enter.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _prevMonth() {
    setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1));
  }
  void _nextMonth() {
    setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1));
  }
  void _toToday() {
    final now = DateTime.now();
    setState(() {
      _viewMonth = DateTime(now.year, now.month);
      _selected  = DateTime(now.year, now.month, now.day);
    });
  }

  List<_CalEvent> _eventsOn(DateTime d) =>
      _events.where((e) => e.date.year == d.year && e.date.month == d.month && e.date.day == d.day).toList();

  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

  String _monthLabel(DateTime m) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[m.month - 1]} ${m.year}';
  }

  void _showAddEvent() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _AddEventModal(
        initialDate: _selected,
        onSubmit: ({
          required String title,
          required String subject,
          required _EventType type,
          required DateTime startTime,
          required DateTime endTime,
        }) => _createEvent(
          title: title, subject: subject, type: type,
          startTime: startTime, endTime: endTime,
        ),
      ),
    );
  }

  void _showEventDetail(_CalEvent e) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _EventDetailModal(
        event: e,
        onDelete: e.id == null ? null : () async {
          Navigator.of(context).pop();
          await _deleteEvent(e);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // Narrower side spacing to match Quiz Hub / Subjects / Flashcards /
    // Analytics — was 0.92 × 1200 before, which left the calendar feeling
    // boxed-in compared to the rest of the study hub.
    final contentW = (screenW * 0.94).clamp(360.0, 1500.0);
    final isWide = contentW >= 900;

    return Material(
      type: MaterialType.transparency,
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                  const SizedBox(height: 40),
                  _stagger(0.00, _header()),
                  const SizedBox(height: 14),
                  _stagger(0.04, _tabBar()),
                  const SizedBox(height: 14),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        Column(children: [
                          _stagger(0.06, _summaryStrip()),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 60),
                              child: isWide
                                  ? IntrinsicHeight(
                                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Expanded(flex: 6, child: _stagger(0.12, _calendarCard())),
                                        const SizedBox(width: 22),
                                        Expanded(flex: 5, child: _stagger(0.16, _eventsPanel())),
                                      ]),
                                    )
                                  : Column(children: [
                                      _stagger(0.12, _calendarCard()),
                                      const SizedBox(height: 20),
                                      _stagger(0.16, _eventsPanel()),
                                    ]),
                            ),
                          ),
                        ]),
                        _stagger(0.06, _SmartScheduleView(onCommitted: _fetchEvents)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// Pill-style TabBar that matches the Quiz Hub look.
  Widget _tabBar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.14),
            offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelStyle: _gaegu(size: 12, weight: FontWeight.w800),
        unselectedLabelStyle: _gaegu(size: 12, weight: FontWeight.w600),
        labelColor: _brown,
        unselectedLabelColor: _brownSoft,
        indicator: BoxDecoration(
          color: _olive.withOpacity(0.55),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _outline.withOpacity(0.3), width: 1.2),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        tabs: const [
          Tab(icon: Icon(Icons.calendar_month_rounded, size: 13), text: 'Calendar'),
          Tab(icon: Icon(Icons.auto_awesome_rounded, size: 13), text: 'Smart Scheduler'),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _cardFill.withOpacity(0.88),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: Icon(Icons.arrow_back_rounded, size: 16, color: _brown),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Study Calendar',
            style: TextStyle(fontFamily: _bitroad, fontSize: 21, color: _brown, height: 1.15)),
          const SizedBox(height: 1),
          Text('Plan your week, keep the streak going~',
            style: _gaegu(size: 12, color: _brownSoft, h: 1.3)),
        ]),
      ),
      Wrap(spacing: 7, runSpacing: 7, children: [
        GestureDetector(onTap: _toToday,
          child: _Pill(icon: Icons.today_rounded, label: 'Today', color: _purpleHdr.withOpacity(0.55))),
        _Pill(icon: Icons.event_note_rounded,
            label: '${_events.length} events', color: _skyHdr.withOpacity(0.55)),
        GestureDetector(
          onTap: (_syncing || _connecting)
              ? null
              : (_gcalConnected ? _syncGcal : _connectGcal),
          child: _SyncPill(
            connected: _gcalConnected,
            busy: _syncing || _connecting,
          ),
        ),
        GestureDetector(onTap: _showAddEvent,
          child: _Pill(icon: Icons.add_rounded, label: 'Add', color: _coral)),
      ]),
    ]);
  }

  Widget _summaryStrip() {
    final todayEvts = _eventsOn(DateTime.now());
    final weekEnd = DateTime.now().add(const Duration(days: 7));
    final upcoming = _events.where((e) =>
        !e.date.isBefore(DateTime.now()) && e.date.isBefore(weekEnd)).length;
    final exams = _events.where((e) => e.type == _EventType.exam &&
        !e.date.isBefore(DateTime.now())).length;
    final studyBlocks = _events.where((e) => e.type == _EventType.study).length;

    return Row(children: [
      Expanded(child: _StatTile(icon: Icons.wb_sunny_rounded, label: 'Today',
          value: '${todayEvts.length}', bgColor: _blueLt.withOpacity(0.38))),
      const SizedBox(width: 10),
      Expanded(child: _StatTile(icon: Icons.upcoming_rounded, label: 'This Week',
          value: '$upcoming', bgColor: _olive.withOpacity(0.65), isHighlight: true)),
      const SizedBox(width: 10),
      Expanded(child: _StatTile(icon: Icons.assignment_late_rounded, label: 'Exams',
          value: '$exams', bgColor: _coral.withOpacity(0.3))),
      const SizedBox(width: 10),
      Expanded(child: _StatTile(icon: Icons.menu_book_rounded, label: 'Study Blocks',
          value: '$studyBlocks', bgColor: _gold.withOpacity(0.26))),
    ]);
  }

  Widget _calendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
            offset: const Offset(4, 4), blurRadius: 0)],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(children: [
          Row(children: [
            _MonthNavBtn(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
            const SizedBox(width: 10),
            Expanded(child: Center(
              child: Text(_monthLabel(_viewMonth),
                style: TextStyle(fontFamily: _bitroad, fontSize: 19, color: _brown)),
            )),
            const SizedBox(width: 10),
            _MonthNavBtn(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
          ]),
          const SizedBox(height: 10),
          _weekdayHeader(),
          const SizedBox(height: 6),
          _daysGrid(),
        ]),
      ),
    );
  }

  Widget _weekdayHeader() {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Row(
      children: days.map((d) => Expanded(
        child: Center(child: Text(d,
          style: _gaegu(size: 10, weight: FontWeight.w700, color: _brownSoft)
              .copyWith(letterSpacing: 0.5))),
      )).toList(),
    );
  }

  Widget _daysGrid() {
    final first = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final firstWeekday = first.weekday; // 1..7 (Mon..Sun)
    final leading = firstWeekday - 1;
    final dayCount = _daysInMonth(_viewMonth);
    final cells = <Widget>[];
    final today = DateTime.now();

    // leading empties
    for (int i = 0; i < leading; i++) cells.add(const SizedBox.shrink());
    for (int d = 1; d <= dayCount; d++) {
      final date = DateTime(_viewMonth.year, _viewMonth.month, d);
      final evts = _eventsOn(date);
      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
      final isSel   = date.year == _selected.year && date.month == _selected.month && date.day == _selected.day;

      cells.add(GestureDetector(
        onTap: () => setState(() => _selected = date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: isSel
              ? _olive
              : (isToday ? _cream : Colors.transparent),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSel
                ? _oliveDk
                : (isToday ? _outline.withOpacity(0.45) : _outline.withOpacity(0.08)),
              width: isSel || isToday ? 2 : 1,
            ),
            boxShadow: isSel
              ? [BoxShadow(color: _oliveDk.withOpacity(0.35),
                  offset: const Offset(2, 2), blurRadius: 0)]
              : (isToday
                  ? [BoxShadow(color: _outline.withOpacity(0.18),
                      offset: const Offset(2, 2), blurRadius: 0)]
                  : []),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$d', style: TextStyle(
              fontFamily: _bitroad, fontSize: 15,
              color: isSel ? Colors.white : _brown,
            )),
            const SizedBox(height: 2),
            if (evts.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (final e in evts.take(3))
                  Container(
                    width: 5, height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isSel ? Colors.white : _typeColor(e.type),
                      shape: BoxShape.circle,
                    ),
                  ),
              ]),
          ]),
        ),
      ));
    }
    // fill trailing to make a full week
    while (cells.length % 7 != 0) cells.add(const SizedBox.shrink());

    // Build rows of 7
    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(Row(
        children: cells.sublist(i, i + 7).map((w) => Expanded(
          child: AspectRatio(aspectRatio: 1, child: w),
        )).toList(),
      ));
    }
    return Column(children: rows);
  }

  Widget _eventsPanel() {
    final evts = _eventsOn(_selected)..sort((a, b) => a.timeLabel.compareTo(b.timeLabel));
    final dateLabel = '${_selected.day} ${_monthShort(_selected.month)} ${_selected.year}';
    return Container(
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
            offset: const Offset(4, 4), blurRadius: 0)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1.3),
            ),
            child: Icon(Icons.event_rounded, size: 15, color: _brownLt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dateLabel,
                style: TextStyle(fontFamily: _bitroad, fontSize: 16, color: _brown)),
              Text('${evts.length} events scheduled',
                style: _gaegu(size: 11, weight: FontWeight.w700, color: _brownSoft)),
            ]),
          ),
          GestureDetector(
            onTap: _showAddEvent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _coral,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _outline.withOpacity(0.35), width: 1.3),
                boxShadow: [BoxShadow(color: _outline.withOpacity(0.22),
                    offset: const Offset(2, 2), blurRadius: 0)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 13, color: _outline),
                SizedBox(width: 3),
                Text('Event',
                  style: TextStyle(fontFamily: _bitroad, fontSize: 12, color: _brown)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        if (_loadingEvents)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(child: CircularProgressIndicator(
                color: _olive, strokeWidth: 3)),
          )
        else if (_eventsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Column(children: [
              Icon(Icons.cloud_off_rounded, size: 36, color: _brownSoft),
              const SizedBox(height: 10),
              Text(_eventsError!,
                textAlign: TextAlign.center,
                style: _gaegu(size: 14, color: _brownSoft, weight: FontWeight.w700)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _fetchEvents,
                child: _Pill(icon: Icons.refresh_rounded, label: 'Retry', color: _greenLt),
              ),
            ])),
          )
        else if (evts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 56),
            child: Center(child: Column(children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  color: _pinkLt.withOpacity(0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: _outline.withOpacity(0.3), width: 2),
                ),
                child: Icon(Icons.event_available_rounded, size: 30, color: _pinkDk),
              ),
              const SizedBox(height: 14),
              Text('Nothing scheduled',
                style: TextStyle(fontFamily: _bitroad, fontSize: 20, color: _brown)),
              const SizedBox(height: 4),
              Text('Tap "+ Event" to plan something fun',
                style: _gaegu(size: 15, color: _brownSoft, weight: FontWeight.w700)),
            ])),
          )
        else
          ...evts.map(_eventRow),
      ]),
    );
  }

  Widget _eventRow(_CalEvent e) {
    final c = _typeColor(e.type);
    return GestureDetector(
      onTap: () => _showEventDetail(e),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: c.withOpacity(0.22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outline.withOpacity(0.18), width: 1.3),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.12),
              offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: c.withOpacity(0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1.3),
            ),
            child: Icon(_typeIcon(e.type), size: 17, color: _brown),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title,
                style: TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown),
                overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 1),
              Text('${e.subject}  •  ${e.timeLabel}',
                style: _gaegu(size: 11, weight: FontWeight.w700, color: _brownLt)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _outline.withOpacity(0.25), width: 1),
            ),
            child: Text(_typeLabel(e.type),
              style: TextStyle(fontFamily: _bitroad, fontSize: 10, color: _brown)),
          ),
        ]),
      ),
    );
  }

  String _monthShort(int m) => const ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  // Stagger animation. Passes `child` through AnimatedBuilder (so the subtree
  // isn't rebuilt every frame) and ignores pointer events while animating —
  // prevents the desktop `_debugDuringDeviceUpdate` mouse-tracker assertion
  // that fires when hit-test regions change mid-update.
  Widget _stagger(double delay, Widget child) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _enter,
        child: child,
        builder: (_, c) {
          final t = Curves.easeOutCubic.transform(((_enter.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
          return IgnorePointer(
            ignoring: t < 1.0,
            child: Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c),
            ),
          );
        },
      ),
    );
  }
}

//  ADD EVENT MODAL (Health-tab style)
/// Callback signature for posting a new event. Returns `true` on success so
/// the modal knows whether to close; `false` keeps the user in the form.
typedef _EventSubmit = Future<bool> Function({
  required String title,
  required String subject,
  required _EventType type,
  required DateTime startTime,
  required DateTime endTime,
});

class _AddEventModal extends StatefulWidget {
  final DateTime initialDate;
  final _EventSubmit onSubmit;
  const _AddEventModal({required this.initialDate, required this.onSubmit});
  @override
  State<_AddEventModal> createState() => _AddEventModalState();
}

class _AddEventModalState extends State<_AddEventModal> {
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  _EventType _type = _EventType.study;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end   = const TimeOfDay(hour: 10, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool start) async {
    final r = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _olive, onPrimary: Colors.white, onSurface: _brown),
        ),
        child: child!,
      ),
    );
    if (r != null) setState(() {
      if (start) _start = r; else _end = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 560,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F4), // cream card
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _outline, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(6, 6), blurRadius: 0),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // Top row: tag + circular close
                Row(children: [
                  Expanded(child: Text('CALENDAR',
                    style: TextStyle(
                      fontFamily: _bitroad, fontSize: 13,
                      color: _oliveDk, letterSpacing: 1.8))),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: _cardFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: _outline, width: 1.5),
                      ),
                      child: Icon(Icons.close_rounded, size: 17, color: _brown),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // Icon chip + heading + subtitle
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _olive,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _outline, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                      ],
                    ),
                    child: const Icon(Icons.event_note_rounded, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Add an Event',
                        style: TextStyle(fontFamily: _bitroad, fontSize: 24, color: _brown, height: 1.1)),
                      const SizedBox(height: 6),
                      Text('plan your study blocks, exams & reminders.',
                        style: _gaegu(size: 14, color: _brownLt)),
                    ]),
                  )),
                ]),
                const SizedBox(height: 22),

                _medInput(
                  ctrl: _titleCtrl,
                  hint: 'what are you doing?',
                  icon: Icons.edit_rounded,
                ),
                const SizedBox(height: 14),
                _medInput(
                  ctrl: _subjectCtrl,
                  hint: 'subject (e.g. Physics)',
                  icon: Icons.menu_book_rounded,
                ),
                const SizedBox(height: 22),

                Text('what kind?',
                  style: _gaegu(size: 16, weight: FontWeight.w700, color: _oliveDk)),
                const SizedBox(height: 10),
                Row(children: [
                  for (int i = 0; i < _EventType.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _typeCard(_EventType.values[i])),
                  ],
                ]),
                const SizedBox(height: 22),

                Text('when?',
                  style: _gaegu(size: 16, weight: FontWeight.w700, color: _oliveDk)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _timeBtn('Start', _start, () => _pickTime(true))),
                  const SizedBox(width: 10),
                  Expanded(child: _timeBtn('End',   _end,   () => _pickTime(false))),
                ]),
                const SizedBox(height: 22),

                Row(children: [
                  Expanded(flex: 2, child: _SoftButton(
                    label: 'cancel', fill: _cream,
                    onTap: _saving ? () {} : () => Navigator.of(context).pop())),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: _SoftButton(
                    label: _saving ? 'saving…' : 'save event',
                    fill: _olive, textColor: Colors.white,
                    onTap: _saving ? () {} : () async {
                      if (_titleCtrl.text.trim().isEmpty) return;
                      setState(() => _saving = true);
                      final d = widget.initialDate;
                      DateTime start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute);
                      DateTime end   = DateTime(d.year, d.month, d.day, _end.hour,   _end.minute);
                      // If user picked end-before-start, treat end as next-day
                      // rather than sending an invalid duration to the backend.
                      if (!end.isAfter(start)) {
                        end = end.add(const Duration(days: 1));
                      }
                      final ok = await widget.onSubmit(
                        title: _titleCtrl.text.trim(),
                        subject: _subjectCtrl.text.trim().isEmpty ? 'General' : _subjectCtrl.text.trim(),
                        type: _type,
                        startTime: start,
                        endTime: end,
                      );
                      if (!mounted) return;
                      if (ok) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _saving = false);
                      }
                    },
                  )),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // Large rounded-pill input field with leading olive icon chip (medication-modal style).
  Widget _medInput({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
  }) => Container(
    decoration: BoxDecoration(
      color: _cardFill,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _outline, width: 2),
      boxShadow: const [
        BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _olive,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outline, width: 1.5),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Expanded(child: TextField(
        controller: ctrl,
        style: _gaegu(size: 16, weight: FontWeight.w600, color: _brown),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _gaegu(size: 16, color: _brownSoft),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      )),
    ]),
  );

  // Large option card for the enum type picker (selected = olive fill + white text).
  Widget _typeCard(_EventType t) {
    final selected = _type == t;
    final bg = selected ? _olive : Colors.white;
    final fg = selected ? Colors.white : _brown;
    final sub = selected ? Colors.white.withOpacity(0.85) : _brownLt;
    return GestureDetector(
      onTap: () => setState(() => _type = t),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline, width: 2),
          boxShadow: selected
              ? const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)]
              : [],
        ),
        child: Column(children: [
          Icon(_typeIcon(t), size: 22, color: fg),
          const SizedBox(height: 6),
          Text(_typeLabel(t),
            style: TextStyle(fontFamily: _bitroad, fontSize: 13, color: fg)),
          const SizedBox(height: 2),
          Text(_typeSubtitle(t),
            style: _gaegu(size: 11, color: sub), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  String _typeSubtitle(_EventType t) => switch (t) {
        _EventType.study    => 'read & review',
        _EventType.exam     => 'big test',
        _EventType.quiz     => 'quick check',
        _EventType.reminder => 'just a nudge',
      };

  Widget _timeBtn(String label, TimeOfDay t, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _olive,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline, width: 1.5),
          ),
          child: const Icon(Icons.schedule_rounded, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
              style: _gaegu(size: 11, weight: FontWeight.w700, color: _oliveDk)
                  .copyWith(letterSpacing: 0.7)),
            Text(_fmt(t),
              style: TextStyle(fontFamily: _bitroad, fontSize: 17, color: _brown)),
          ],
        )),
      ]),
    ),
  );
}

//  EVENT DETAIL MODAL
class _EventDetailModal extends StatelessWidget {
  final _CalEvent event;
  /// Non-null when the event has a backend id, so it can be deleted.
  final VoidCallback? onDelete;
  const _EventDetailModal({required this.event, this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _outline, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(6, 6), blurRadius: 0),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // Top row: type tag + circular close
                Row(children: [
                  Expanded(child: Text(_typeLabel(event.type).toUpperCase(),
                    style: TextStyle(
                      fontFamily: _bitroad, fontSize: 13,
                      color: _oliveDk, letterSpacing: 1.8))),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: _cardFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: _outline, width: 1.5),
                      ),
                      child: Icon(Icons.close_rounded, size: 17, color: _brown),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // Icon chip + title + subject subtitle
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _olive,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _outline, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                      ],
                    ),
                    child: Icon(_typeIcon(event.type), size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(event.title,
                        style: TextStyle(fontFamily: _bitroad, fontSize: 22, color: _brown, height: 1.15),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(event.subject,
                        style: _gaegu(size: 14, weight: FontWeight.w700, color: _brownLt)),
                    ]),
                  )),
                ]),
                const SizedBox(height: 22),

                // Detail rows as pill cards
                _detailRow(Icons.schedule_rounded, 'Time', event.timeLabel),
                const SizedBox(height: 10),
                _detailRow(Icons.event_rounded, 'Date',
                    '${event.date.day} ${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][event.date.month - 1]} ${event.date.year}'),
                const SizedBox(height: 10),
                _detailRow(Icons.category_rounded, 'Type', _typeLabel(event.type)),
                const SizedBox(height: 22),

                Row(children: [
                  Expanded(child: _SoftButton(label: 'close', fill: _cream,
                      onTap: () => Navigator.of(context).pop())),
                  if (onDelete != null) ...[
                    const SizedBox(width: 10),
                    Expanded(child: _SoftButton(
                      label: 'delete', fill: _coral, textColor: _brown,
                      onTap: onDelete!)),
                  ],
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _SoftButton(
                    label: 'start session', fill: _olive, textColor: Colors.white,
                    onTap: () => Navigator.of(context).pop())),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
    decoration: BoxDecoration(
      color: _cardFill,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _outline, width: 2),
      boxShadow: const [
        BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
      ],
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _olive,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outline, width: 1.5),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
            style: _gaegu(size: 11, weight: FontWeight.w700, color: _oliveDk)
                .copyWith(letterSpacing: 0.7)),
          Text(value,
            style: TextStyle(fontFamily: _bitroad, fontSize: 15, color: _brown)),
        ],
      )),
    ]),
  );
}

//  SHARED WIDGETS
class _MonthNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MonthNavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _outline.withOpacity(0.3), width: 1.4),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.22),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Icon(icon, size: 17, color: _brown),
    ),
  );
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool highlight;
  const _Pill({required this.icon, required this.label, required this.color, this.highlight = false});
  @override
  Widget build(BuildContext context) {
    final txt = highlight ? Colors.white : _brown;
    final ic = highlight ? Colors.white : _outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.28),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: ic),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontFamily: _bitroad, fontSize: 11, color: txt)),
      ]),
    );
  }
}

/// Sync-to-Google-Calendar pill. Shows a spinner while syncing/connecting,
/// a "Sync" pill when connected, and a "Link GCal" pill when disconnected.
class _SyncPill extends StatelessWidget {
  final bool connected;
  final bool busy;
  const _SyncPill({required this.connected, required this.busy});
  @override
  Widget build(BuildContext context) {
    final bg = connected ? _greenLt : _cream;
    final label = busy
        ? (connected ? 'Syncing…' : 'Linking…')
        : (connected ? 'Sync' : 'Link GCal');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.28),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        busy
            ? SizedBox(
                width: 11, height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_oliveDk),
                ),
              )
            : Icon(connected ? Icons.sync_rounded : Icons.link_rounded,
                size: 11, color: _outline),
        const SizedBox(width: 4),
        Text(label,
          style: TextStyle(fontFamily: _bitroad, fontSize: 11, color: _brown)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color bgColor;
  final bool isHighlight;
  const _StatTile({required this.icon, required this.label, required this.value,
    required this.bgColor, this.isHighlight = false});
  @override
  Widget build(BuildContext context) {
    final textColor  = isHighlight ? Colors.white : _brown;
    final labelColor = isHighlight ? Colors.white.withOpacity(0.85) : _brownSoft;
    final iconBg     = isHighlight ? Colors.white.withOpacity(0.2) : Colors.white;
    final iconBorder = isHighlight ? Colors.white.withOpacity(0.25) : _outline.withOpacity(0.1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _outline.withOpacity(0.15), width: 1.2),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.12),
            offset: const Offset(3, 3), blurRadius: 0)],
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
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
              style: TextStyle(fontFamily: _bitroad, fontSize: 17, color: textColor),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            Text(label.toUpperCase(),
              style: _gaegu(size: 10, weight: FontWeight.w700, color: labelColor).copyWith(letterSpacing: 0.5)),
          ],
        )),
      ]),
    );
  }
}

class _SoftButton extends StatelessWidget {
  final String label;
  final Color fill;
  // Nullable + in-body fallback because `_brown` is now a runtime getter.
  final Color? textColor;
  final VoidCallback onTap;
  _SoftButton({required this.label, required this.fill, required this.onTap,
      this.textColor});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Text(label,
        style: _gaegu(size: 18, weight: FontWeight.w700, color: textColor)),
    ),
  );
}

//  SMART SCHEDULER VIEW (moved out of Quiz Hub)
//  Plans a 1-week mix of focus sessions, flashcard reviews, quizzes,
//  and light review — slotted around the user's Google Calendar and
//  weighted by their historical peak-focus hours. Output lands as
//  StudyEvent rows (source='ai_schedule'), which is why it lives
//  alongside the calendar grid.
class _SmartScheduleView extends ConsumerStatefulWidget {
  /// Fires after a successful /commit so the parent calendar can refetch
  /// events and show the freshly-scheduled blocks on the grid.
  final VoidCallback onCommitted;
  const _SmartScheduleView({required this.onCommitted});

  @override
  ConsumerState<_SmartScheduleView> createState() => _SmartScheduleViewState();
}

class _SmartScheduleViewState extends ConsumerState<_SmartScheduleView>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  bool _enabled          = true;
  bool _enableFocus      = true;
  bool _enableFlashcards = true;
  bool _enableQuizzes    = true;
  bool _enableLightReview = true;

  int _focusPerWeek = 4;
  int _focusMinutes = 45;
  int _flashPerWeek = 3;
  int _quizPerWeek  = 1;
  int _lightPerWeek = 2;

  int _startHour = 9;
  int _endHour   = 22;
  bool _avoidWeekends = false;
  bool _respectGCal   = true;

  bool _loadingCfg = true;
  bool _previewing = false;
  bool _committing = false;

  // Preview payload from /study/smart-schedule/preview
  Map<String, dynamic>? _preview;
  // Per-block accept toggle (id → bool); defaults to true on new previews
  final Map<String, bool> _accepted = {};

  // We fetch it alongside our own config so the Quizzes activity row can
  // surface a small sub-label like "Quiz Hub: Weekly on Mon (10q)" instead
  // of treating the two schedulers as if they don't know about each other.
  Map<String, dynamic>? _quizCfg;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadQuizCfg();
  }

  Future<void> _loadQuizCfg() async {
    try {
      final api = ref.read(apiServiceProvider);
      final r = await api.get('/study/quiz-schedule');
      if (!mounted) return;
      final d = r.data;
      if (d is Map) {
        setState(() => _quizCfg = Map<String, dynamic>.from(d));
      } else {
        setState(() => _quizCfg = null);
      }
    } catch (_) {
      // Non-fatal — the quizzes row just won't surface a sub-label.
    }
  }

  bool get _quizScheduleActive =>
      _quizCfg != null && (_quizCfg!['enabled'] ?? false) == true;

  String get _quizScheduleLabel {
    if (!_quizScheduleActive) return '';
    final cfg = _quizCfg!;
    final freq = (cfg['frequency'] ?? 'weekly').toString();
    final day  = (cfg['day_of_week'] is int) ? cfg['day_of_week'] as int : 0;
    final cnt  = (cfg['question_count'] is int) ? cfg['question_count'] : 10;
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final freqLabel = freq == 'biweekly' ? 'Biweekly' : freq == 'monthly' ? 'Monthly' : 'Weekly';
    return '$freqLabel on ${days[day.clamp(0, 6)]} · ${cnt}q';
  }

  Future<void> _loadConfig() async {
    setState(() => _loadingCfg = true);
    try {
      final api = ref.read(apiServiceProvider);
      final r = await api.get('/study/smart-schedule/config');
      final c = r.data is Map ? Map<String, dynamic>.from(r.data) : <String, dynamic>{};
      _enabled            = c['enabled'] ?? true;
      _enableFocus        = c['enable_focus_sessions'] ?? true;
      _enableFlashcards   = c['enable_flashcards'] ?? true;
      _enableQuizzes      = c['enable_quizzes'] ?? true;
      _enableLightReview  = c['enable_light_review'] ?? true;
      _focusPerWeek       = c['focus_sessions_per_week'] ?? 4;
      _focusMinutes       = c['focus_session_minutes'] ?? 45;
      _flashPerWeek       = c['flashcard_blocks_per_week'] ?? 3;
      _quizPerWeek        = c['quiz_blocks_per_week'] ?? 1;
      _lightPerWeek       = c['light_review_blocks_per_week'] ?? 2;
      _startHour          = c['preferred_start_hour'] ?? 9;
      _endHour            = c['preferred_end_hour'] ?? 22;
      _avoidWeekends      = c['avoid_weekends'] ?? false;
      _respectGCal        = c['respect_google_calendar'] ?? true;
    } catch (e) {
      debugPrint('Smart schedule config load error: $e');
    }
    if (mounted) setState(() => _loadingCfg = false);
  }

  Future<void> _saveConfig({bool silent = false}) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/study/smart-schedule/config', data: {
        'enabled': _enabled,
        'enable_focus_sessions': _enableFocus,
        'enable_flashcards': _enableFlashcards,
        'enable_quizzes': _enableQuizzes,
        'enable_light_review': _enableLightReview,
        'focus_sessions_per_week': _focusPerWeek,
        'focus_session_minutes': _focusMinutes,
        'flashcard_blocks_per_week': _flashPerWeek,
        'quiz_blocks_per_week': _quizPerWeek,
        'light_review_blocks_per_week': _lightPerWeek,
        'preferred_start_hour': _startHour,
        'preferred_end_hour': _endHour,
        'avoid_weekends': _avoidWeekends,
        'respect_google_calendar': _respectGCal,
      });
      if (!silent && mounted) _snack('Preferences saved');
    } catch (e) {
      debugPrint('Smart schedule config save error: $e');
    }
  }

  Future<void> _runPreview() async {
    await _saveConfig(silent: true);
    setState(() => _previewing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final r = await api.get('/study/smart-schedule/preview?days=7');
      final data = r.data is Map ? Map<String, dynamic>.from(r.data) : <String, dynamic>{};
      _preview = data;
      _accepted.clear();
      final blocks = (data['blocks'] as List?) ?? [];
      for (final b in blocks) {
        if (b is Map && b['id'] != null) _accepted[b['id'].toString()] = true;
      }
    } catch (e) {
      debugPrint('Smart schedule preview error: $e');
      if (mounted) _snack('Couldn\'t generate plan — try again', ok: false);
    }
    if (mounted) setState(() => _previewing = false);
  }

  Future<void> _commitPreview() async {
    if (_preview == null) return;
    final blocks = (_preview!['blocks'] as List?) ?? [];
    final approved = blocks.where((b) =>
      b is Map && _accepted[b['id'].toString()] == true).map((b) {
      final m = Map<String, dynamic>.from(b);
      return {
        'title': m['title'],
        'activity_type': m['activity_type'],
        'start_time': m['start_time'],
        'end_time': m['end_time'],
        'subject_id': m['subject_id'],
        'subject_name': m['subject_name'],
        'subject_color': m['subject_color'],
        'topic': m['topic'],
        'reason': m['reason'],
      };
    }).toList();

    if (approved.isEmpty) {
      _snack('Pick at least one block to schedule', ok: false);
      return;
    }

    setState(() => _committing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final r = await api.post('/study/smart-schedule/commit', data: {
        'blocks': approved,
        'push_to_gcal': _respectGCal,
      });
      final committed = (r.data is Map ? r.data['committed'] : 0) ?? 0;
      if (mounted) {
        setState(() {
          _preview = null;
          _accepted.clear();
        });
        _snack('Scheduled $committed block${committed == 1 ? '' : 's'} → Calendar');
      }
      widget.onCommitted();
    } catch (e) {
      debugPrint('Smart schedule commit error: $e');
      if (mounted) _snack('Couldn\'t save — try again', ok: false);
    }
    if (mounted) setState(() => _committing = false);
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _gaegu(size: 14, weight: FontWeight.w700, color: Colors.white)),
      backgroundColor: ok ? _oliveDk : _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loadingCfg) {
      return Center(child: CircularProgressIndicator(color: _olive));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 60),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _hero(),
        const SizedBox(height: 14),
        _whatToScheduleCard(),
        const SizedBox(height: 12),
        _whenAndConflictCard(),
        const SizedBox(height: 14),
        _previewButton(),
        if (_preview != null) ...[
          const SizedBox(height: 14),
          _planSummary(),
          const SizedBox(height: 8),
          _planList(),
          const SizedBox(height: 14),
          _commitButton(),
        ],
        const SizedBox(height: 18),
        _footnote(),
      ]),
    );
  }

  // Styled to mirror the Calendar tab's card language: same 22-radius,
  // same 1.5 outline, same retro sharp shadow (offset 4,4, blur 0), and
  // same inner breathing (20,18,20,20). The subtle purple→coral gradient
  // gives the hero a distinct identity while sitting in the same frame.
  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_purpleHdr.withOpacity(0.42), _coral.withOpacity(0.28)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
            offset: const Offset(4, 4), blurRadius: 0)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardFill.withOpacity(0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _outline.withOpacity(0.25))),
          child: Icon(Icons.auto_awesome_rounded, size: 22, color: _purpleHdr),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Smart Scheduler',
            style: TextStyle(fontFamily: _bitroad, fontSize: 22, color: _brown)),
          const SizedBox(height: 2),
          Text(
            'Plans your week using your peak-focus hours, due flashcards, '
            'and weakest subjects — and works around what\'s already on your calendar.',
            style: _gaegu(size: 13, color: _brownLt, h: 1.35)),
        ])),
        const SizedBox(width: 8),
        Switch(
          value: _enabled, activeColor: _oliveDk,
          onChanged: (v) {
            setState(() => _enabled = v);
            _saveConfig(silent: true);
          },
        ),
      ]),
    );
  }

  // Matches _calendarCard() styling so the scheduler feels like it's
  // in the same card system as the rest of the page.
  Widget _whatToScheduleCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
            offset: const Offset(4, 4), blurRadius: 0)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tune_rounded, size: 18, color: _oliveDk),
          const SizedBox(width: 8),
          Text('What to schedule',
            style: TextStyle(fontFamily: _bitroad, fontSize: 18, color: _brown)),
        ]),
        const SizedBox(height: 4),
        Text('Toggle activity types and pick how many per week',
          style: _gaegu(size: 12, color: _brownSoft)),
        const SizedBox(height: 10),
        _activityRow(
          color: _oliveDk, icon: Icons.school_rounded, label: 'Focus sessions',
          subtitle: '$_focusMinutes-min deep-work blocks',
          enabled: _enableFocus, count: _focusPerWeek,
          onToggle: (v) { setState(() => _enableFocus = v); _saveConfig(silent: true); },
          onCount: (n) { setState(() => _focusPerWeek = n); _saveConfig(silent: true); },
          maxCount: 10,
        ),
        _activityRow(
          color: _coral, icon: Icons.layers_rounded, label: 'Flashcard reviews',
          subtitle: '15-min SM-2 review blocks',
          enabled: _enableFlashcards, count: _flashPerWeek,
          onToggle: (v) { setState(() => _enableFlashcards = v); _saveConfig(silent: true); },
          onCount: (n) { setState(() => _flashPerWeek = n); _saveConfig(silent: true); },
          maxCount: 7,
        ),
        _activityRow(
          color: _gold, icon: Icons.quiz_rounded, label: 'Quizzes',
          subtitle: 'Tests recall on weak topics',
          enabled: _enableQuizzes, count: _quizPerWeek,
          onToggle: (v) { setState(() => _enableQuizzes = v); _saveConfig(silent: true); },
          onCount: (n) { setState(() => _quizPerWeek = n); _saveConfig(silent: true); },
          maxCount: 5,
          crossScheduleNote: _quizScheduleActive
              ? 'Quiz Hub cadence · $_quizScheduleLabel'
              : null,
        ),
        _activityRow(
          color: _purpleHdr, icon: Icons.menu_book_rounded, label: 'Light review',
          subtitle: 'Short reinforcement of recent topics',
          enabled: _enableLightReview, count: _lightPerWeek,
          onToggle: (v) { setState(() => _enableLightReview = v); _saveConfig(silent: true); },
          onCount: (n) { setState(() => _lightPerWeek = n); _saveConfig(silent: true); },
          maxCount: 7,
        ),
      ]),
    );
  }

  Widget _activityRow({
    required Color color, required IconData icon,
    required String label, required String subtitle,
    required bool enabled, required int count,
    required ValueChanged<bool> onToggle,
    required ValueChanged<int> onCount,
    int maxCount = 7,
    String? crossScheduleNote,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: enabled ? color.withOpacity(0.3) : Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: enabled ? color.withOpacity(0.65) : _outline.withOpacity(0.2))),
            child: Icon(icon, size: 19,
              color: enabled ? color : _brownSoft.withOpacity(0.45)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: _gaegu(
              size: 14, weight: FontWeight.w800,
              color: enabled ? _brown : _brownSoft.withOpacity(0.6))),
            Text(subtitle, style: _gaegu(
              size: 11.5, color: _brownSoft.withOpacity(enabled ? 0.85 : 0.5))),
          ])),
          // Stepper
          if (enabled) Row(children: [
            _stepBtn(Icons.remove_rounded, () {
              if (count > 0) onCount(count - 1);
            }),
            SizedBox(width: 34, child: Text('$count/wk',
              textAlign: TextAlign.center,
              style: _gaegu(size: 12, weight: FontWeight.w800, color: _brown))),
            _stepBtn(Icons.add_rounded, () {
              if (count < maxCount) onCount(count + 1);
            }),
          ]),
          const SizedBox(width: 6),
          Switch(value: enabled, activeColor: color, onChanged: onToggle),
        ]),
        // Cross-scheduler awareness chip — e.g. the Quizzes row surfaces
        // the Quiz Hub cadence so the two planners don't feel disjointed.
        if (enabled && crossScheduleNote != null) Padding(
          padding: const EdgeInsets.fromLTRB(46, 4, 0, 2),
          child: Row(children: [
            Icon(Icons.sync_rounded, size: 11, color: color.withOpacity(0.85)),
            const SizedBox(width: 5),
            Flexible(child: Text(crossScheduleNote, style: _gaegu(
              size: 11, weight: FontWeight.w700,
              color: _brownSoft.withOpacity(0.85)),
              overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _outline.withOpacity(0.25))),
        child: Icon(icon, size: 14, color: _brown),
      ),
    );
  }

  Widget _whenAndConflictCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: _cardFill.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
            offset: const Offset(4, 4), blurRadius: 0)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.access_time_rounded, size: 18, color: _skyHdr),
          const SizedBox(width: 8),
          Text('When + conflicts',
            style: TextStyle(fontFamily: _bitroad, fontSize: 18, color: _brown)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _hourPicker('Earliest', _startHour, (h) {
            if (h < _endHour) {
              setState(() => _startHour = h);
              _saveConfig(silent: true);
            }
          })),
          const SizedBox(width: 10),
          Expanded(child: _hourPicker('Latest', _endHour, (h) {
            if (h > _startHour) {
              setState(() => _endHour = h);
              _saveConfig(silent: true);
            }
          })),
        ]),
        const SizedBox(height: 12),
        _toggleRow(
          icon: Icons.weekend_rounded,
          label: 'Avoid weekends',
          value: _avoidWeekends,
          onChanged: (v) { setState(() => _avoidWeekends = v); _saveConfig(silent: true); },
        ),
        _toggleRow(
          icon: Icons.event_available_rounded,
          label: 'Work around Google Calendar',
          subtitle: 'Skip slots where you have other events',
          value: _respectGCal,
          onChanged: (v) { setState(() => _respectGCal = v); _saveConfig(silent: true); },
        ),
      ]),
    );
  }

  Widget _hourPicker(String label, int hour, ValueChanged<int> onChange) {
    String fmt(int h) {
      final hr = h % 12 == 0 ? 12 : h % 12;
      return '$hr ${h < 12 ? 'am' : 'pm'}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _cream.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.2))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _gaegu(
            size: 11, weight: FontWeight.w700, color: _brownSoft)),
          Text(fmt(hour), style: TextStyle(
            fontFamily: _bitroad, fontSize: 20, color: _brown)),
        ])),
        Column(children: [
          GestureDetector(
            onTap: () => onChange(hour + 1 > 23 ? 23 : hour + 1),
            child: Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: _brown)),
          GestureDetector(
            onTap: () => onChange(hour - 1 < 0 ? 0 : hour - 1),
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: _brown)),
        ]),
      ]),
    );
  }

  Widget _toggleRow({
    required IconData icon, required String label, String? subtitle,
    required bool value, required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 19, color: _brownLt),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _gaegu(
            size: 14, weight: FontWeight.w700, color: _brown)),
          if (subtitle != null) Text(subtitle, style: _gaegu(
            size: 11.5, color: _brownSoft)),
        ])),
        Switch(value: value, activeColor: _oliveDk, onChanged: onChanged),
      ]),
    );
  }

  Widget _previewButton() {
    final canRun = _enabled && (_enableFocus || _enableFlashcards
        || _enableQuizzes || _enableLightReview);
    return GestureDetector(
      onTap: (canRun && !_previewing) ? _runPreview : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canRun
                ? [_olive, _oliveDk]
                : [Colors.grey.shade300, Colors.grey.shade400]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: canRun ? _outline : Colors.grey.shade500,
            width: 2),
          boxShadow: canRun
              ? const [BoxShadow(color: Colors.black,
                  offset: Offset(3, 3), blurRadius: 0)]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_previewing)
            const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(_preview == null
              ? 'Generate next week\'s plan'
              : 'Regenerate plan',
            style: _gaegu(size: 19, weight: FontWeight.w800, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _planSummary() {
    final s = _preview!['summary'] as Map? ?? {};
    final byType = (s['by_type'] as Map?) ?? {};
    final total = s['total_blocks'] ?? 0;
    final mins = s['total_minutes'] ?? 0;
    final peak = s['peak_focus_hour'];
    String peakLabel = '';
    if (peak is num) {
      final h = peak.toInt();
      final hr = h % 12 == 0 ? 12 : h % 12;
      peakLabel = '$hr ${h < 12 ? 'am' : 'pm'}';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withOpacity(0.65), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
            offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insights_rounded, size: 17, color: _brownLt),
          const SizedBox(width: 6),
          Text('$total blocks · ${(mins / 60).toStringAsFixed(1)} hrs',
            style: TextStyle(fontFamily: _bitroad, fontSize: 17, color: _brown)),
          const Spacer(),
          if (peakLabel.isNotEmpty) Text('Peak: $peakLabel',
            style: _gaegu(size: 12, weight: FontWeight.w700, color: _brownLt)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if ((byType['focus'] ?? 0) > 0)
            _summaryPill(_oliveDk, Icons.school_rounded, 'Focus × ${byType['focus']}'),
          if ((byType['flashcard'] ?? 0) > 0)
            _summaryPill(_coral, Icons.layers_rounded, 'Flash × ${byType['flashcard']}'),
          if ((byType['quiz'] ?? 0) > 0)
            _summaryPill(_gold, Icons.quiz_rounded, 'Quiz × ${byType['quiz']}'),
          if ((byType['light_review'] ?? 0) > 0)
            _summaryPill(_purpleHdr, Icons.menu_book_rounded,
              'Light × ${byType['light_review']}'),
        ]),
      ]),
    );
  }

  Widget _summaryPill(Color c, IconData ic, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.65))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 12, color: c),
        const SizedBox(width: 4),
        Text(label, style: _gaegu(
          size: 11.5, weight: FontWeight.w800, color: _brown)),
      ]),
    );
  }

  Widget _planList() {
    final blocks = (_preview!['blocks'] as List?) ?? [];
    if (blocks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _cardFill.withOpacity(0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
              offset: const Offset(4, 4), blurRadius: 0)],
        ),
        child: Column(children: [
          Icon(Icons.event_busy_rounded, size: 34, color: _brownSoft),
          const SizedBox(height: 8),
          Text('No free slots in your window',
            style: TextStyle(fontFamily: _bitroad, fontSize: 17, color: _brown)),
          const SizedBox(height: 2),
          Text('Try widening Earliest / Latest, or turning off "Avoid weekends".',
            textAlign: TextAlign.center,
            style: _gaegu(size: 13, color: _brownSoft)),
        ]),
      );
    }

    final fmtHead = DateFormat('EEE, MMM d');
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final raw in blocks) {
      if (raw is! Map) continue;
      final b = Map<String, dynamic>.from(raw);
      DateTime? dt;
      try { dt = DateTime.parse(b['start_time']).toLocal(); } catch (_) {}
      final key = dt == null ? '?' : fmtHead.format(dt);
      groups.putIfAbsent(key, () => []).add(b);
    }

    return Column(children: groups.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Text(entry.key, style: TextStyle(
              fontFamily: _bitroad, fontSize: 16, color: _brown)),
          ),
          ...entry.value.map(_blockCard),
        ]),
      );
    }).toList());
  }

  Widget _blockCard(Map<String, dynamic> b) {
    final id = b['id'].toString();
    final accepted = _accepted[id] ?? true;
    DateTime? start;
    DateTime? end;
    try { start = DateTime.parse(b['start_time']).toLocal(); } catch (_) {}
    try { end   = DateTime.parse(b['end_time']).toLocal();   } catch (_) {}
    final timeFmt = DateFormat('h:mm a');
    final timeRange = (start != null && end != null)
        ? '${timeFmt.format(start)} – ${timeFmt.format(end)}' : '';

    final atype = (b['activity_type'] ?? 'focus').toString();
    final color = _blockTypeColor(atype);
    final icon  = _blockTypeIcon(atype);
    final focus = b['focus_score_at_slot'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _accepted[id] = !accepted),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: accepted ? Colors.white : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accepted ? color.withOpacity(0.75) : _outline.withOpacity(0.18),
              width: accepted ? 1.8 : 1.2),
            boxShadow: accepted ? [BoxShadow(
              color: _outline.withOpacity(0.15),
              offset: const Offset(3, 3), blurRadius: 0)] : null,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(accepted ? 0.28 : 0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: color.withOpacity(0.6))),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b['title'] ?? '',
                  style: _gaegu(
                    size: 15, weight: FontWeight.w800,
                    color: accepted ? _brown : _brownSoft)),
                const SizedBox(height: 1),
                Row(children: [
                  if (timeRange.isNotEmpty) Text(timeRange,
                    style: _gaegu(
                      size: 12, weight: FontWeight.w700, color: _brownLt)),
                  if (focus is num) ...[
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: BoxDecoration(
                      color: _brownSoft.withOpacity(0.4),
                      shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Icon(Icons.bolt_rounded, size: 11,
                      color: focus >= 70 ? _oliveDk : _red),
                    Text(' focus ${focus.toStringAsFixed(0)}',
                      style: _gaegu(
                        size: 11, weight: FontWeight.w700,
                        color: focus >= 70 ? _oliveDk : _red)),
                  ],
                ]),
                if ((b['reason'] ?? '').toString().isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(b['reason'],
                    style: _gaegu(
                      size: 11.5, color: _brownSoft, h: 1.3)),
                ),
              ],
            )),
            const SizedBox(width: 8),
            Icon(
              accepted ? Icons.check_circle_rounded
                       : Icons.radio_button_unchecked_rounded,
              size: 24,
              color: accepted ? _oliveDk : _outline.withOpacity(0.35),
            ),
          ]),
        ),
      ),
    );
  }

  Color _blockTypeColor(String t) {
    switch (t) {
      case 'flashcard':    return _coral;
      case 'quiz':         return _gold;
      case 'light_review': return _purpleHdr;
      default:             return _oliveDk;
    }
  }

  IconData _blockTypeIcon(String t) {
    switch (t) {
      case 'flashcard':    return Icons.layers_rounded;
      case 'quiz':         return Icons.quiz_rounded;
      case 'light_review': return Icons.menu_book_rounded;
      default:             return Icons.school_rounded;
    }
  }

  Widget _commitButton() {
    final approvedCount = _accepted.values.where((v) => v).length;
    final allCount = _accepted.length;
    return Column(children: [
      GestureDetector(
        onTap: (_committing || approvedCount == 0) ? null : _commitPreview,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: approvedCount == 0
                ? [Colors.grey.shade300, Colors.grey.shade400]
                : [_coral, _pinkDk]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: approvedCount == 0 ? Colors.grey.shade500 : _outline,
              width: 2),
            boxShadow: approvedCount == 0 ? null : const [BoxShadow(
              color: Colors.black,
              offset: Offset(3, 3), blurRadius: 0)],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_committing) const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else const Icon(Icons.event_available_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Confirm $approvedCount of $allCount',
              style: _gaegu(size: 18, weight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _respectGCal
          ? 'Confirmed blocks land in Study Calendar + Google Calendar.'
          : 'Confirmed blocks land in Study Calendar (Google Calendar sync off).',
        style: _gaegu(size: 11.5, color: _brownSoft),
        textAlign: TextAlign.center),
    ]);
  }

  Widget _footnote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'The scheduler reads the past 30 days of your study sessions to find when '
        'your focus is highest, then assigns the heaviest activities (focus + quiz) '
        'to those hours and the lighter ones (flashcards + light review) to the rest.',
        style: _gaegu(size: 12, color: _brownSoft.withOpacity(0.75), h: 1.4),
        textAlign: TextAlign.center),
    );
  }
}

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
    c.save(); c.translate(cx, cy); c.rotate(a);
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
