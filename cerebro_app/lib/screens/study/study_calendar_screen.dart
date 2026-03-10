import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/config/constants.dart';

// palette
const _ombre1   = Color(0xFFFFFBF7);
const _ombre2   = Color(0xFFFFF8F3);
const _ombre3   = Color(0xFFFFF3EF);
const _ombre4   = Color(0xFFFEEDE9);
const _cardFill = Color(0xFFFFF8F4);
const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);
const _coralHdr = Color(0xFFF0A898);
const _coralLt  = Color(0xFFF8C0B0);
const _greenHdr = Color(0xFFA8D5A3);
const _greenLt  = Color(0xFFC2E8BC);
const _greenDk  = Color(0xFF88B883);
const _goldHdr  = Color(0xFFF0D878);
const _goldLt   = Color(0xFFFFF0C0);
const _goldDk   = Color(0xFFD0B048);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _skyHdr   = Color(0xFF9DD4F0);
const _skyLt    = Color(0xFFB8E0F8);
const _skyDk    = Color(0xFF6BB8E0);
const _sageHdr  = Color(0xFF90C8A0);
const _pawClr   = Color(0xFFF8BCD0);

class StudyCalendarScreen extends ConsumerStatefulWidget {
  const StudyCalendarScreen({super.key});
  @override
  ConsumerState<StudyCalendarScreen> createState() => _StudyCalendarScreenState();
}

class _StudyCalendarScreenState extends ConsumerState<StudyCalendarScreen>
    with SingleTickerProviderStateMixin {
  // animation
  late AnimationController _enterCtrl;

  // calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // events
  List<Map<String, dynamic>> _events = [];
  Map<DateTime, List<Map<String, dynamic>>> _eventsByDay = {};
  bool _loading = true;
  String? _error;

  // google calendar
  bool _gcalConnected = false;
  bool _syncing = false;

  // ai schedule
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _loadEvents();
    _checkGcalStatus();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  //  API CALLS
  // ═══════════════════════════════════════════════

  Future<void> _loadEvents() async {
    setState(() { _loading = true; _error = null; });
    final api = ref.read(apiServiceProvider);
    try {
      final start = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
      final end = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);
      final res = await api.get('/study/calendar/events', queryParams: {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      });
      final list = (res.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _events = list;
        _eventsByDay = _groupByDay(list);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load events'; _loading = false; });
    }
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupByDay(List<Map<String, dynamic>> events) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final e in events) {
      final dt = DateTime.tryParse(e['start_time'] ?? '');
      if (dt == null) continue;
      final local = dt.toLocal();
      final dayKey = DateTime(local.year, local.month, local.day);
      map.putIfAbsent(dayKey, () => []).add(e);
    }
    return map;
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsByDay[key] ?? [];
  }

  Future<void> _checkGcalStatus() async {
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.get('/study/calendar/gcal/status');
      setState(() {
        _gcalConnected = res.data['connected'] == true;
      });
    } catch (_) {}
  }

  Future<void> _syncGcal() async {
    setState(() => _syncing = true);
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.post('/study/calendar/gcal/sync?direction=both');
      final pushed = res.data?['pushed'] ?? 0;
      final pulled = res.data?['pulled'] ?? 0;
      final errors = res.data?['errors'] as List? ?? [];
      await _loadEvents();
      if (mounted) {
        final errStr = errors.isNotEmpty ? errors.first.toString() : '';
        final msg = errStr.contains('not enabled')
            ? 'Enable Google Calendar API in Cloud Console first'
            : errors.isNotEmpty
                ? 'Sync error: $errStr'
                : 'Synced! Pushed $pushed, pulled $pulled';
        _snack(msg, ok: errors.isEmpty);
      }
    } catch (e) {
      if (mounted) _snack('Sync failed: $e', ok: false);
    }
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _connectGcal() async {
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
            '<h1 style="color:#6E5848;">✓ Calendar Connected</h1>'
            '<p style="color:#7A5840;">You can close this tab and return to CEREBRO.</p>'
            '</div></body></html>');
      await request.response.close();
      await server.close();
      server = null;

      if (error != null || code == null) {
        if (mounted) _snack('Calendar connection cancelled', ok: false);
        return;
      }

      final httpClient = HttpClient();
      try {
        final tokenReq = await httpClient.postUrl(
          Uri.parse('https://oauth2.googleapis.com/token'));
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

        setState(() => _gcalConnected = true);
        if (mounted) _snack('Google Calendar connected!', ok: true);
        _syncGcal();
      } finally {
        httpClient.close();
      }
    } catch (e) {
      if (server != null) await server.close();
      if (mounted) _snack('Connection failed: $e', ok: false);
    }
  }

  Future<void> _disconnectGcal() async {
    final api = ref.read(apiServiceProvider);
    try {
      await api.post('/study/calendar/gcal/disconnect');
      setState(() => _gcalConnected = false);
      _snack('Google Calendar disconnected', ok: true);
    } catch (_) {}
  }

  Future<void> _generateSchedule() async {
    setState(() => _generating = true);
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.post('/study/calendar/generate-schedule?days=7');
      final count = res.data['events_created'] ?? 0;
      await _loadEvents();
      if (mounted) _snack('Created $count study sessions!', ok: true);
    } catch (e) {
      if (mounted) _snack('Schedule failed: $e', ok: false);
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _createEvent(Map<String, dynamic> data) async {
    final api = ref.read(apiServiceProvider);
    try {
      await api.post('/study/calendar/events', data: data);
      await _loadEvents();
      _snack('Event created!', ok: true);
    } catch (e) {
      if (mounted) _snack('Failed: $e', ok: false);
    }
  }

  Future<void> _toggleComplete(Map<String, dynamic> event) async {
    final api = ref.read(apiServiceProvider);
    try {
      await api.put('/study/calendar/events/${event['id']}', data: {
        'completed': !(event['completed'] == true),
      });
      await _loadEvents();
    } catch (_) {}
  }

  Future<void> _deleteEvent(String id) async {
    final api = ref.read(apiServiceProvider);
    try {
      await api.delete('/study/calendar/events/$id');
      await _loadEvents();
    } catch (_) {}
  }

  void _snack(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
      backgroundColor: ok ? _greenDk : _coralHdr,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  // entrance animation helper
  Widget _stag(double delay, Widget child) {
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

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ombre1,
      body: Stack(children: [
        // Pawprint ombré background
        Positioned.fill(child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_ombre1, _ombre2, _ombre3, _ombre4],
            stops: [0.0, 0.3, 0.6, 1.0],
          )),
        )),
        Positioned.fill(child: CustomPaint(painter: _PawPrintBg())),
        // Warm glow at top
        Positioned(top: -100, left: 0, right: 0, child: Container(
          height: 260,
          decoration: BoxDecoration(gradient: RadialGradient(
            center: Alignment.topCenter, radius: 1.0,
            colors: [_coralHdr.withOpacity(0.08), Colors.transparent],
          )),
        )),
        // Content
        SafeArea(child: Column(children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? _buildLoadingSkeleton()
                : _error != null
                    ? _buildError()
                    : RefreshIndicator(
                        onRefresh: _loadEvents,
                        color: _outline, backgroundColor: _cardFill,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _stag(0.00, _buildCalendarCard()),
                              const SizedBox(height: 14),
                              _stag(0.10, _buildQuickStats()),
                              const SizedBox(height: 14),
                              _stag(0.18, _buildActionStrip()),
                              const SizedBox(height: 14),
                              _stag(0.24, _buildGcalCard()),
                              const SizedBox(height: 18),
                              _stag(0.30, _buildDayEvents()),
                            ],
                          ),
                        ),
                      ),
          ),
        ])),
      ]),
      floatingActionButton: _buildFab(),
    );
  }

  // ═══════════════════════════════════════════════
  //  HEADER — warm with back button + sync
  // ═══════════════════════════════════════════════

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 2),
      child: Row(children: [
        IconButton(
          icon: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline.withOpacity(0.3), width: 1.5)),
            child: const Icon(Icons.arrow_back_rounded, color: _brown, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 6),
        Text('Study Calendar',
          style: GoogleFonts.gaegu(
            fontSize: 26, fontWeight: FontWeight.w700, color: _brown)),
        const Spacer(),
        if (_gcalConnected) _syncButton(),
      ]),
    );
  }

  Widget _syncButton() {
    return GestureDetector(
      onTap: _syncing ? null : _syncGcal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_greenLt, _greenHdr.withOpacity(0.5)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _greenDk.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: _greenDk.withOpacity(0.15),
            offset: const Offset(0, 2), blurRadius: 0)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_syncing)
            const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            const Icon(Icons.sync_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text('Sync', style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  CALENDAR CARD — 3D Pocket Love box
  // ═══════════════════════════════════════════════

  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline, width: 2),
        boxShadow: const [
          BoxShadow(color: _outline, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(children: [
        // Calendar header gradient strip
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_coralLt, _coralHdr]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20)),
          ),
          child: Center(child: Text(
            DateFormat('MMMM yyyy').format(_focusedDay),
            style: GoogleFonts.gaegu(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          )),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: TableCalendar(
            firstDay: DateTime(2024, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            calendarFormat: _calendarFormat,
            onFormatChanged: (f) => setState(() => _calendarFormat = f),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              setState(() => _focusedDay = focused);
              _loadEvents();
            },
            eventLoader: _eventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.twoWeeks: '2w',
              CalendarFormat.week: 'Week',
            },
            headerVisible: false,
            daysOfWeekHeight: 28,
            rowHeight: 44,
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w800, color: _brownLt),
              weekendStyle: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w800, color: _coralHdr),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w700, color: _brown),
              weekendTextStyle: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w700, color: _coralHdr.withOpacity(0.7)),
              outsideTextStyle: GoogleFonts.nunito(
                fontSize: 13, color: _brownLt.withOpacity(0.25)),
              todayDecoration: BoxDecoration(
                color: _goldHdr.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _goldHdr, width: 2)),
              todayTextStyle: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w800, color: _goldDk),
              selectedDecoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_coralLt, _coralHdr]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _coralHdr.withOpacity(0.3),
                  offset: const Offset(0, 2), blurRadius: 4)]),
              selectedTextStyle: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
              markerDecoration: const BoxDecoration(
                color: _coralHdr, shape: BoxShape.circle),
              markerSize: 5,
              markersMaxCount: 3,
              markerMargin: const EdgeInsets.symmetric(horizontal: 0.8),
              cellMargin: const EdgeInsets.all(3),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (ctx, date, events) {
                if (events.isEmpty) return null;
                return Positioned(bottom: 2, child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    math.min(events.length, 3),
                    (i) {
                      final e = events[i] as Map<String, dynamic>;
                      final type = e['event_type'] ?? 'study';
                      return Container(
                        width: 5, height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          color: _typeColor(type),
                          shape: BoxShape.circle),
                      );
                    },
                  ),
                ));
              },
            ),
          ),
        ),
        // Format toggle row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: _brown, size: 22),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                });
                _loadEvents();
              },
            ),
            const Spacer(),
            for (final fmt in [CalendarFormat.week, CalendarFormat.twoWeeks, CalendarFormat.month])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => setState(() => _calendarFormat = fmt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _calendarFormat == fmt
                          ? _coralHdr.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _calendarFormat == fmt
                            ? _coralHdr : _outline.withOpacity(0.15),
                        width: 1.5)),
                    child: Text(
                      fmt == CalendarFormat.week ? 'W'
                          : fmt == CalendarFormat.twoWeeks ? '2W' : 'M',
                      style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: _calendarFormat == fmt ? _brown : _brownLt),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: _brown, size: 22),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                });
                _loadEvents();
              },
            ),
          ]),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  //  QUICK STATS — total events this month, today's count
  // ═══════════════════════════════════════════════

  Widget _buildQuickStats() {
    final todayCount = _eventsForDay(_selectedDay).length;
    final monthEvents = _events.where((e) {
      final dt = DateTime.tryParse(e['start_time'] ?? '');
      return dt != null && dt.month == _focusedDay.month && dt.year == _focusedDay.year;
    }).length;
    final completedCount = _events.where((e) => e['completed'] == true).length;

    return Row(children: [
      _statPill(Icons.today_rounded, '$todayCount today', _coralHdr, _brown),
      const SizedBox(width: 8),
      _statPill(Icons.calendar_month_rounded, '$monthEvents this month', _purpleHdr, const Color(0xFFAA88C0)),
      const SizedBox(width: 8),
      _statPill(Icons.check_circle_outline_rounded, '$completedCount done', _greenHdr, _greenDk),
    ]);
  }

  Widget _statPill(IconData icon, String text, Color bg, Color border) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [bg.withOpacity(0.3), bg.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withOpacity(0.25), width: 1.5)),
      child: Column(children: [
        Icon(icon, size: 16, color: border),
        const SizedBox(height: 2),
        Text(text, style: GoogleFonts.nunito(
          fontSize: 11, fontWeight: FontWeight.w700, color: _brown),
          textAlign: TextAlign.center),
      ]),
    ));
  }

  // ═══════════════════════════════════════════════
  //  ACTION STRIP — AI Schedule + GCal connect
  // ═══════════════════════════════════════════════

  Widget _buildActionStrip() {
    return Row(children: [
      Expanded(child: _GameBtn(
        icon: Icons.auto_awesome_rounded,
        label: _generating ? 'Working...' : 'AI Schedule',
        gradTop: _purpleLt, gradBot: _purpleHdr,
        border: const Color(0xFFAA88C0),
        onTap: _generating ? () {} : _generateSchedule,
      )),
      const SizedBox(width: 10),
      if (!_gcalConnected)
        Expanded(child: _GameBtn(
          icon: Icons.calendar_month_rounded,
          label: 'Connect GCal',
          gradTop: _coralLt, gradBot: _coralHdr,
          border: const Color(0xFFD08878),
          onTap: _connectGcal,
        ))
      else
        Expanded(child: _GameBtn(
          icon: Icons.event_note_rounded,
          label: 'Today',
          gradTop: _goldLt, gradBot: _goldHdr,
          border: _goldDk,
          onTap: () => setState(() {
            _selectedDay = DateTime.now();
            _focusedDay = DateTime.now();
          }),
        )),
    ]);
  }

  // ═══════════════════════════════════════════════
  //  GOOGLE CALENDAR CARD — connected status
  // ═══════════════════════════════════════════════

  Widget _buildGcalCard() {
    if (!_gcalConnected) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_greenLt.withOpacity(0.4), _greenLt.withOpacity(0.15)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _greenDk.withOpacity(0.2), width: 1.5)),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: _greenHdr.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.check_circle_rounded, size: 16, color: _greenDk),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Google Calendar Synced',
              style: GoogleFonts.gaegu(
                fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
            Text('Events push/pull automatically',
              style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt)),
          ],
        )),
        GestureDetector(
          onTap: _disconnectGcal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _coralLt.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8)),
            child: Text('Disconnect', style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w700, color: _coralHdr)),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  //  DAY EVENTS LIST
  // ═══════════════════════════════════════════════

  Widget _buildDayEvents() {
    final dayEvents = _eventsForDay(_selectedDay);
    final isToday = isSameDay(_selectedDay, DateTime.now());
    final dateStr = isToday
        ? 'Today, ${DateFormat('MMMM d').format(_selectedDay)}'
        : DateFormat('EEEE, MMMM d').format(_selectedDay);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(dateStr,
          style: GoogleFonts.gaegu(
            fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
        if (dayEvents.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _coralHdr.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
            child: Text('${dayEvents.length}',
              style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w800, color: _brown)),
          ),
        ],
      ]),
      const SizedBox(height: 10),
      if (dayEvents.isEmpty)
        _buildEmptyDay()
      else
        ...dayEvents.map(_buildEventCard),
    ]);
  }

  Widget _buildEmptyDay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.12), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.06),
          offset: const Offset(0, 2), blurRadius: 0)]),
      child: Column(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: _coralHdr.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.event_available_rounded, size: 26,
            color: _coralHdr.withOpacity(0.4)),
        ),
        const SizedBox(height: 10),
        Text('No events scheduled',
          style: GoogleFonts.gaegu(
            fontSize: 17, fontWeight: FontWeight.w700,
            color: _brownLt.withOpacity(0.45))),
        const SizedBox(height: 4),
        Text('Tap + to add or try AI Schedule',
          style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: _brownLt.withOpacity(0.35))),
      ]),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final type = event['event_type'] ?? 'study';
    final vis = _typeVisuals(type);
    final start = DateTime.tryParse(event['start_time'] ?? '');
    final end = DateTime.tryParse(event['end_time'] ?? '');
    final timeStr = start != null && end != null
        ? '${DateFormat.Hm().format(start.toLocal())} – ${DateFormat.Hm().format(end.toLocal())}'
        : '';
    final duration = event['duration_minutes'] ?? 0;
    final completed = event['completed'] == true;
    final gcalSynced = event['gcal_synced'] == true;
    final source = event['source'] ?? 'manual';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: completed ? _cardFill.withOpacity(0.7) : _cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline, width: 1.5),
        boxShadow: [
          BoxShadow(color: completed ? _outline.withOpacity(0.3) : _outline,
            offset: const Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: IntrinsicHeight(child: Row(children: [
        // Color strip with gradient
        Container(
          width: 7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [vis.color, vis.color.withOpacity(0.5)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title row
              Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: vis.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7)),
                  child: Icon(vis.icon, size: 14, color: vis.color),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  event['title'] ?? 'Untitled',
                  style: GoogleFonts.gaegu(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _brown,
                    decoration: completed ? TextDecoration.lineThrough : null),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                // Badges
                if (gcalSynced)
                  _badge(Icons.cloud_done_rounded, _greenDk),
                if (source == 'ai_schedule')
                  _badge(Icons.auto_awesome_rounded, _purpleHdr),
              ]),
              const SizedBox(height: 6),
              // Time row
              Row(children: [
                Icon(Icons.schedule_rounded, size: 12, color: _brownLt.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(timeStr,
                  style: GoogleFonts.nunito(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt)),
                if (duration > 0) ...[
                  Text('  ·  ${duration}min',
                    style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: _brownLt.withOpacity(0.5))),
                ],
                const Spacer(),
                if (event['subject_name'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _parseColor(event['subject_color']).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _parseColor(event['subject_color']).withOpacity(0.25))),
                    child: Text(event['subject_name'],
                      style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700, color: _brown),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ]),
              // Topic
              if (event['topic'] != null && (event['topic'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(event['topic'],
                  style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _brownLt.withOpacity(0.5)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
        ),
        // Action buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleComplete(event),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 24,
                  color: completed ? _greenDk : _brownLt.withOpacity(0.25)),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _confirmDelete(event),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 16,
                  color: _coralHdr.withOpacity(0.4)),
              ),
            ),
          ]),
        ),
      ])),
    );
  }

  Widget _badge(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 12, color: color.withOpacity(0.6)),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  FAB — 3D game button style
  // ═══════════════════════════════════════════════

  Widget _buildFab() {
    return GestureDetector(
      onTap: _showCreateDialog,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_coralLt, _coralHdr]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD08878).withOpacity(0.5), width: 2.5),
          boxShadow: [BoxShadow(color: const Color(0xFFD08878).withOpacity(0.35),
            offset: const Offset(0, 3), blurRadius: 0)]),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  CREATE EVENT DIALOG
  // ═══════════════════════════════════════════════

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String eventType = 'study';
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    DateTime eventDate = _selectedDay;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          backgroundColor: _cardFill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: _outline, width: 2)),
          title: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_coralLt, _coralHdr]),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('New Event',
              style: GoogleFonts.gaegu(
                fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
          ]),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: GoogleFonts.nunito(fontSize: 14, color: _brown),
                decoration: _inputDeco('Event title...', Icons.edit_rounded),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                style: GoogleFonts.nunito(fontSize: 14, color: _brown),
                decoration: _inputDeco('Description (optional)', Icons.notes_rounded),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // Type chips
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (final t in ['study', 'review', 'quiz', 'flashcard', 'break', 'exam'])
                  GestureDetector(
                    onTap: () => setDlg(() => eventType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: eventType == t
                            ? _typeColor(t).withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: eventType == t
                              ? _typeColor(t) : _outline.withOpacity(0.15),
                          width: eventType == t ? 1.5 : 1)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_typeVisuals(t).icon, size: 12,
                          color: eventType == t ? _typeColor(t) : _brownLt),
                        const SizedBox(width: 3),
                        Text(t[0].toUpperCase() + t.substring(1),
                          style: GoogleFonts.nunito(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: eventType == t ? _brown : _brownLt)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              // Date
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: eventDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030));
                  if (d != null) setDlg(() => eventDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _outline.withOpacity(0.15))),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 15, color: _brownLt),
                    const SizedBox(width: 8),
                    Text(DateFormat('EEE, MMM d, yyyy').format(eventDate),
                      style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _brown)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              // Time
              Row(children: [
                Expanded(child: _timePicker(
                  label: 'Start', time: startTime,
                  onPick: (t) => setDlg(() => startTime = t), ctx: ctx)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: GoogleFonts.gaegu(fontSize: 18, color: _brownLt))),
                Expanded(child: _timePicker(
                  label: 'End', time: endTime,
                  onPick: (t) => setDlg(() => endTime = t), ctx: ctx)),
              ]),
            ],
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600, color: _brownLt)),
            ),
            GestureDetector(
              onTap: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final startDt = DateTime(
                  eventDate.year, eventDate.month, eventDate.day,
                  startTime.hour, startTime.minute);
                final endDt = DateTime(
                  eventDate.year, eventDate.month, eventDate.day,
                  endTime.hour, endTime.minute);
                _createEvent({
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                  'event_type': eventType,
                  'start_time': startDt.toUtc().toIso8601String(),
                  'end_time': endDt.toUtc().toIso8601String(),
                });
                Navigator.pop(ctx);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_coralLt, _coralHdr]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD08878).withOpacity(0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: const Color(0xFFD08878).withOpacity(0.2),
                    offset: const Offset(0, 2), blurRadius: 0)]),
                child: Text('Create', style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _timePicker({
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onPick,
    required BuildContext ctx,
  }) {
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: ctx, initialTime: time);
        if (t != null) onPick(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _outline.withOpacity(0.15))),
        child: Row(children: [
          Icon(Icons.schedule_rounded, size: 13, color: _brownLt.withOpacity(0.5)),
          const SizedBox(width: 5),
          Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: _brown)),
        ]),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(fontSize: 13, color: _brownLt.withOpacity(0.4)),
      prefixIcon: Icon(icon, size: 16, color: _brownLt.withOpacity(0.35)),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _outline.withOpacity(0.15))),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _outline.withOpacity(0.15))),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _coralHdr, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }

  // ═══════════════════════════════════════════════
  //  DELETE CONFIRM
  // ═══════════════════════════════════════════════

  void _confirmDelete(Map<String, dynamic> event) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _outline, width: 2)),
      title: Text('Delete Event?', style: GoogleFonts.gaegu(
        fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
      content: Text(
        'Remove "${event['title']}"?${event['gcal_synced'] == true ? '\nAlso removes from Google Calendar.' : ''}',
        style: GoogleFonts.nunito(fontSize: 13, color: _brownLt)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.nunito(
            fontWeight: FontWeight.w600, color: _brownLt)),
        ),
        GestureDetector(
          onTap: () { _deleteEvent(event['id']); Navigator.pop(ctx); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_coralLt, _coralHdr]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _coralHdr.withOpacity(0.5), width: 1.5)),
            child: Text('Delete', style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    ));
  }

  // ═══════════════════════════════════════════════
  //  LOADING SKELETON
  // ═══════════════════════════════════════════════

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          height: 260, width: double.infinity,
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _outline.withOpacity(0.15))),
        ),
        const SizedBox(height: 14),
        Row(children: List.generate(3, (_) => Expanded(child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(12)),
        )))),
        const SizedBox(height: 14),
        ...List.generate(3, (_) => Container(
          height: 60, width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(16)),
        )),
      ]),
    );
  }

  // ═══════════════════════════════════════════════
  //  ERROR STATE
  // ═══════════════════════════════════════════════

  Widget _buildError() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: _coralLt.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18)),
          child: Icon(Icons.error_outline_rounded, size: 32,
            color: _coralHdr.withOpacity(0.6)),
        ),
        const SizedBox(height: 14),
        Text(_error ?? 'Something went wrong',
          style: GoogleFonts.gaegu(
            fontSize: 18, fontWeight: FontWeight.w600, color: _brownLt)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _loadEvents,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_coralLt, _coralHdr]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD08878).withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFFD08878).withOpacity(0.2),
                offset: const Offset(0, 2), blurRadius: 0)]),
            child: Text('Retry', style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    ));
  }

  // ═══════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════

  Color _parseColor(String? hex) {
    if (hex == null || hex.length < 7) return _skyHdr;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return _skyHdr;
    }
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'study': return _skyHdr;
      case 'review': return _sageHdr;
      case 'quiz': return _coralHdr;
      case 'flashcard': return _purpleHdr;
      case 'break': return _goldHdr;
      case 'exam': return const Color(0xFFE07070);
      case 'imported': return _brownLt;
      default: return _skyHdr;
    }
  }

  _TypeVisual _typeVisuals(String type) {
    switch (type.toLowerCase()) {
      case 'study': return _TypeVisual(Icons.menu_book_rounded, _skyHdr);
      case 'review': return _TypeVisual(Icons.replay_rounded, _sageHdr);
      case 'quiz': return _TypeVisual(Icons.quiz_rounded, _coralHdr);
      case 'flashcard': return _TypeVisual(Icons.style_rounded, _purpleHdr);
      case 'break': return _TypeVisual(Icons.coffee_rounded, _goldHdr);
      case 'exam': return _TypeVisual(Icons.school_rounded, const Color(0xFFE07070));
      case 'imported': return _TypeVisual(Icons.cloud_download_rounded, _brownLt);
      default: return _TypeVisual(Icons.event_rounded, _skyHdr);
    }
  }
}

class _TypeVisual {
  final IconData icon;
  final Color color;
  const _TypeVisual(this.icon, this.color);
}


//  GAME BUTTON — chunky 3D (matching study_tab exactly)

class _GameBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color gradTop, gradBot, border;
  final VoidCallback onTap;
  const _GameBtn({required this.icon, required this.label,
    required this.gradTop, required this.gradBot, required this.border,
    required this.onTap});
  @override State<_GameBtn> createState() => _GameBtnState();
}

class _GameBtnState extends State<_GameBtn> {
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [widget.gradTop, widget.gradBot]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.border.withOpacity(0.5), width: 2),
          boxShadow: _p ? [] : [BoxShadow(
            color: widget.border.withOpacity(0.35),
            offset: const Offset(0, 3), blurRadius: 0)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(widget.icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(child: Text(widget.label, style: GoogleFonts.gaegu(fontSize: 14,
            fontWeight: FontWeight.w700, color: Colors.white),
            overflow: TextOverflow.ellipsis)),
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
        paint.color = _pawClr.withOpacity(0.05 + (idx % 5) * 0.015);
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
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}
