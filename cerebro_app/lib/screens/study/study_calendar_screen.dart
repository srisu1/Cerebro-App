/// Study Tab look & feel: ombre background + paw prints, Bitroad for
/// headings/day-numbers, Gaegu for body, hard-offset shadows, pill chips.
/// Add-event modal mirrors the Health Tab modal (gradient header + close).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/config/constants.dart';

const _ombre1 = Color(0xFFFFFBF7);
const _ombre2 = Color(0xFFFFF8F3);
const _ombre3 = Color(0xFFFFF3EF);
const _ombre4 = Color(0xFFFEEDE9);
const _pawClr = Color(0xFFF8BCD0);

const _outline   = Color(0xFF6E5848);
const _brown     = Color(0xFF4E3828);
const _brownLt   = Color(0xFF7A5840);
const _brownSoft = Color(0xFF9A8070);

const _cream    = Color(0xFFFDEFDB);
const _olive    = Color(0xFF98A869);
const _oliveDk  = Color(0xFF58772F);
const _pinkLt   = Color(0xFFFFD5F5);
const _pink     = Color(0xFFFEA9D3);
const _pinkDk   = Color(0xFFE890B8);
const _coral    = Color(0xFFF7AEAE);
const _gold     = Color(0xFFE4BC83);
const _orange   = Color(0xFFFFBC5C);
const _red      = Color(0xFFEF6262);
const _blueLt   = Color(0xFFDDF6FF);
const _greenLt  = Color(0xFFC2E8BC);
const _skyHdr   = Color(0xFF9DD4F0);
const _purpleHdr = Color(0xFFCDA8D8);

TextStyle _gaegu({double size = 14, FontWeight weight = FontWeight.w600, Color color = _brown, double? h}) =>
    GoogleFonts.gaegu(fontSize: size, fontWeight: weight, color: color, height: h);
const _bitroad = 'Bitroad';

enum _EventType { study, exam, quiz, reminder }

class _CalEvent {
  final DateTime date;
  final String title;
  final String subject;
  final _EventType type;
  final String timeLabel;
  _CalEvent({
    required this.date,
    required this.title,
    required this.subject,
    required this.type,
    required this.timeLabel,
  });
}

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

/// Demo events seeded around today.
List<_CalEvent> _seedEvents() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    _CalEvent(date: today,                       title: 'Biology — Photosynthesis',  subject: 'Biology',     type: _EventType.study,    timeLabel: '09:00 — 10:30'),
    _CalEvent(date: today,                       title: 'Math practice set',         subject: 'Math',        type: _EventType.quiz,     timeLabel: '14:00 — 14:30'),
    _CalEvent(date: today.add(const Duration(days: 1)),  title: 'Physics lecture review', subject: 'Physics',     type: _EventType.study,    timeLabel: '10:00 — 11:00'),
    _CalEvent(date: today.add(const Duration(days: 2)),  title: 'Chemistry Midterm',      subject: 'Chemistry',   type: _EventType.exam,     timeLabel: '09:30'),
    _CalEvent(date: today.add(const Duration(days: 3)),  title: 'Submit English essay',   subject: 'English Lit', type: _EventType.reminder, timeLabel: '23:59'),
    _CalEvent(date: today.add(const Duration(days: 5)),  title: 'Computer Sci project',   subject: 'CS',          type: _EventType.study,    timeLabel: '13:00 — 15:00'),
    _CalEvent(date: today.add(const Duration(days: 7)),  title: 'Physics Quiz',           subject: 'Physics',     type: _EventType.quiz,     timeLabel: '11:00'),
    _CalEvent(date: today.subtract(const Duration(days: 2)), title: 'Biology chapter 4',  subject: 'Biology',     type: _EventType.study,    timeLabel: '16:00 — 17:00'),
  ];
}

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
  late final List<_CalEvent> _events;
  late final AnimationController _enter;

  bool _gcalConnected = false;
  bool _syncing = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
    _selected  = DateTime(now.year, now.month, now.day);
    _events    = _seedEvents();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _checkGcalStatus();
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
      builder: (_) => _AddEventModal(initialDate: _selected, onCreate: (evt) {
        setState(() => _events.add(evt));
      }),
    );
  }

  void _showEventDetail(_CalEvent e) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _EventDetailModal(event: e),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final contentW = (screenW * 0.92).clamp(360.0, 1200.0);
    final isWide = contentW >= 900;

    return Material(
      type: MaterialType.transparency,
      child: Container(
      decoration: const BoxDecoration(
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
                  const SizedBox(height: 64),
                  _stagger(0.00, _header()),
                  const SizedBox(height: 28),
                  _stagger(0.06, _summaryStrip()),
                  const SizedBox(height: 34),
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
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _header() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline.withOpacity(0.22), width: 1.5),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.18),
                offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: _brown),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Study Calendar',
            style: TextStyle(fontFamily: _bitroad, fontSize: 26, color: _brown, height: 1.15)),
          const SizedBox(height: 2),
          Text('Plan your week, keep the streak going~',
            style: _gaegu(size: 15, color: _brownSoft, h: 1.3)),
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
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
            offset: const Offset(4, 4), blurRadius: 0)],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(children: [
          Row(children: [
            _MonthNavBtn(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
            const SizedBox(width: 12),
            Expanded(child: Center(
              child: Text(_monthLabel(_viewMonth),
                style: const TextStyle(fontFamily: _bitroad, fontSize: 24, color: _brown)),
            )),
            const SizedBox(width: 12),
            _MonthNavBtn(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
          ]),
          const SizedBox(height: 14),
          _weekdayHeader(),
          const SizedBox(height: 10),
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
          style: _gaegu(size: 12, weight: FontWeight.w700, color: _brownSoft)
              .copyWith(letterSpacing: 0.7))),
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
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSel
              ? _olive
              : (isToday ? _cream : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
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
              fontFamily: _bitroad, fontSize: 20,
              color: isSel ? Colors.white : _brown,
            )),
            const SizedBox(height: 3),
            if (evts.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (final e in evts.take(3))
                  Container(
                    width: 7, height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
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
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
            offset: const Offset(4, 4), blurRadius: 0)],
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1.3),
            ),
            child: Icon(Icons.event_rounded, size: 19, color: _brownLt),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dateLabel,
                style: const TextStyle(fontFamily: _bitroad, fontSize: 21, color: _brown)),
              Text('${evts.length} events scheduled',
                style: _gaegu(size: 13, weight: FontWeight.w700, color: _brownSoft)),
            ]),
          ),
          GestureDetector(
            onTap: _showAddEvent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _coral,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _outline.withOpacity(0.35), width: 1.3),
                boxShadow: [BoxShadow(color: _outline.withOpacity(0.22),
                    offset: const Offset(2, 2), blurRadius: 0)],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 15, color: _outline),
                SizedBox(width: 4),
                Text('Event',
                  style: TextStyle(fontFamily: _bitroad, fontSize: 14, color: _brown)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        if (evts.isEmpty)
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
              const Text('Nothing scheduled',
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: c.withOpacity(0.22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline.withOpacity(0.18), width: 1.3),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.12),
              offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: c.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1.3),
            ),
            child: Icon(_typeIcon(e.type), size: 24, color: _brown),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title,
                style: const TextStyle(fontFamily: _bitroad, fontSize: 18, color: _brown),
                overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 2),
              Text('${e.subject}  •  ${e.timeLabel}',
                style: _gaegu(size: 14, weight: FontWeight.w700, color: _brownLt)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _outline.withOpacity(0.25), width: 1),
            ),
            child: Text(_typeLabel(e.type),
              style: const TextStyle(fontFamily: _bitroad, fontSize: 12, color: _brown)),
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
class _AddEventModal extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<_CalEvent> onCreate;
  const _AddEventModal({required this.initialDate, required this.onCreate});
  @override
  State<_AddEventModal> createState() => _AddEventModalState();
}

class _AddEventModalState extends State<_AddEventModal> {
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  _EventType _type = _EventType.study;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end   = const TimeOfDay(hour: 10, minute: 0);

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
          colorScheme: const ColorScheme.light(primary: _olive, onPrimary: Colors.white, onSurface: _brown),
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _outline, width: 1.5),
                      ),
                      child: const Icon(Icons.close_rounded, size: 17, color: _brown),
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
                      const Text('Add an Event',
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
                  Expanded(flex: 2, child: _SoftButton(label: 'cancel', fill: _cream,
                      onTap: () => Navigator.of(context).pop())),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: _SoftButton(
                    label: 'save event', fill: _olive, textColor: Colors.white,
                    onTap: () {
                      if (_titleCtrl.text.trim().isEmpty) return;
                      widget.onCreate(_CalEvent(
                        date: DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day),
                        title: _titleCtrl.text.trim(),
                        subject: _subjectCtrl.text.trim().isEmpty ? 'General' : _subjectCtrl.text.trim(),
                        type: _type,
                        timeLabel: '${_fmt(_start)} — ${_fmt(_end)}',
                      ));
                      Navigator.of(context).pop();
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
      color: Colors.white,
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
        color: Colors.white,
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
              style: const TextStyle(fontFamily: _bitroad, fontSize: 17, color: _brown)),
          ],
        )),
      ]),
    ),
  );
}

//  EVENT DETAIL MODAL
class _EventDetailModal extends StatelessWidget {
  final _CalEvent event;
  const _EventDetailModal({required this.event});
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _outline, width: 1.5),
                      ),
                      child: const Icon(Icons.close_rounded, size: 17, color: _brown),
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
                        style: const TextStyle(fontFamily: _bitroad, fontSize: 22, color: _brown, height: 1.15),
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
                  Expanded(flex: 2, child: _SoftButton(label: 'close', fill: _cream,
                      onTap: () => Navigator.of(context).pop())),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: _SoftButton(
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
      color: Colors.white,
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
            style: const TextStyle(fontFamily: _bitroad, fontSize: 15, color: _brown)),
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
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.3), width: 1.4),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.22),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Icon(icon, size: 22, color: _brown),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.28),
            offset: const Offset(2, 2), blurRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: ic),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontFamily: _bitroad, fontSize: 13, color: txt)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                width: 13, height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_oliveDk),
                ),
              )
            : Icon(connected ? Icons.sync_rounded : Icons.link_rounded,
                size: 13, color: _outline),
        const SizedBox(width: 5),
        Text(label,
          style: const TextStyle(fontFamily: _bitroad, fontSize: 13, color: _brown)),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withOpacity(0.15), width: 1.2),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.12),
            offset: const Offset(3, 3), blurRadius: 0)],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconBorder, width: 1),
          ),
          child: Icon(icon, size: 19, color: isHighlight ? Colors.white : _brownLt),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
              style: TextStyle(fontFamily: _bitroad, fontSize: 22, color: textColor),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            Text(label.toUpperCase(),
              style: _gaegu(size: 12, weight: FontWeight.w700, color: labelColor).copyWith(letterSpacing: 0.6)),
          ],
        )),
      ]),
    );
  }
}

class _SoftButton extends StatelessWidget {
  final String label;
  final Color fill;
  final Color textColor;
  final VoidCallback onTap;
  const _SoftButton({required this.label, required this.fill, required this.onTap,
      this.textColor = _brown});
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
