// Provider for live study session state, synced with backend

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

/// Session lifecycle states. Mirrors the backend's `status` column exactly
/// plus an `idle` sentinel for "no live session" so the UI can branch
/// cleanly between hero-with-timer and hero-with-start-button.
enum SessionPhase { idle, running, paused, completed }

SessionPhase _phaseFromString(String? s) {
  switch (s) {
    case 'running':
      return SessionPhase.running;
    case 'paused':
      return SessionPhase.paused;
    case 'completed':
      return SessionPhase.completed;
    default:
      return SessionPhase.idle;
  }
}

/// Immutable snapshot of the current session. Everything the hero,
/// mini-player, and session screen need lives on this record.
class SessionState {
  final SessionPhase phase;
  final String? sessionId;
  final String? subjectId;
  final String? subjectName;
  final String? title;
  final String sessionType; // focused | review | practice | lecture
  final int plannedDurationMinutes;
  final int elapsedSeconds;
  final int totalPausedSeconds;
  final int distractions;
  final DateTime? startTime;
  final DateTime? pausedAt;
  final List<String> topicsCovered;
  // Ephemeral flags the UI reads for loading/error banners. Not persisted —
  // they reflect transient network state only.
  final bool loading;
  final String? error;
  // Transient "user wants to wrap up this session" signal. Set by the mini
  // session bar's Stop button and the Study tab hero Stop button — both
  // of which should land the user on the full Wrapped rating screen rather
  // than instantly killing the session. The study_session_screen listens
  // for this flag flipping true, jumps to its completion phase, and calls
  // `notifier.consumeEndRequest()` so the flag resets.
  final bool endRequested;

  const SessionState({
    this.phase = SessionPhase.idle,
    this.sessionId,
    this.subjectId,
    this.subjectName,
    this.title,
    this.sessionType = 'focused',
    this.plannedDurationMinutes = 25,
    this.elapsedSeconds = 0,
    this.totalPausedSeconds = 0,
    this.distractions = 0,
    this.startTime,
    this.pausedAt,
    this.topicsCovered = const [],
    this.loading = false,
    this.error,
    this.endRequested = false,
  });

  /// True when there is a session the user has opened but not yet finalized.
  /// This is what the cross-tab guard checks — if this is true and the user
  /// tries to leave the Study tab, we show the "end session first" sheet.
  bool get isLive =>
      phase == SessionPhase.running || phase == SessionPhase.paused;

  /// Fraction of planned duration completed, clamped to [0, 1]. The hero's
  /// ring uses this; once a user overshoots their target the ring holds at
  /// 1.0 rather than spilling into a second revolution.
  double get progress {
    if (plannedDurationMinutes <= 0) return 0;
    final total = plannedDurationMinutes * 60;
    final p = elapsedSeconds / total;
    return p.clamp(0.0, 1.0);
  }

  SessionState copyWith({
    SessionPhase? phase,
    String? sessionId,
    String? subjectId,
    String? subjectName,
    String? title,
    String? sessionType,
    int? plannedDurationMinutes,
    int? elapsedSeconds,
    int? totalPausedSeconds,
    int? distractions,
    DateTime? startTime,
    DateTime? pausedAt,
    List<String>? topicsCovered,
    bool? loading,
    String? error,
    bool? endRequested,
    // Explicit "blow away this nullable" flags — Dart has no sentinel for
    // "set this to null", so callers use these when they need to clear.
    bool clearSessionId = false,
    bool clearSubjectId = false,
    bool clearSubjectName = false,
    bool clearTitle = false,
    bool clearPausedAt = false,
    bool clearError = false,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      subjectId: clearSubjectId ? null : (subjectId ?? this.subjectId),
      subjectName: clearSubjectName ? null : (subjectName ?? this.subjectName),
      title: clearTitle ? null : (title ?? this.title),
      sessionType: sessionType ?? this.sessionType,
      plannedDurationMinutes:
          plannedDurationMinutes ?? this.plannedDurationMinutes,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      totalPausedSeconds: totalPausedSeconds ?? this.totalPausedSeconds,
      distractions: distractions ?? this.distractions,
      startTime: startTime ?? this.startTime,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      topicsCovered: topicsCovered ?? this.topicsCovered,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      endRequested: endRequested ?? this.endRequested,
    );
  }
}

/// StateNotifier that mediates all live-session interactions.
///
/// Usage pattern:
///   final state = ref.watch(studySessionProvider);
///   ref.read(studySessionProvider.notifier).start(...);
class StudySessionNotifier extends StateNotifier<SessionState> {
  final ApiService _api;
  Timer? _ticker;

  StudySessionNotifier(this._api) : super(const SessionState()) {
    // Hydrate from backend on first read. We don't await — the constructor
    // returns synchronously and the UI renders `idle` until /active returns.
    // ignore: discarded_futures
    hydrate();
  }


  /// Rebuild `state` from a server /active or /start response body.
  void _applyServer(Map<String, dynamic> json) {
    final phase = _phaseFromString(json['status']?.toString());
    final topics = (json['topics_covered'] is List)
        ? List<String>.from(json['topics_covered'])
        : const <String>[];

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    state = state.copyWith(
      phase: phase == SessionPhase.completed ? SessionPhase.idle : phase,
      sessionId: json['id']?.toString(),
      subjectId: json['subject_id']?.toString(),
      title: json['title']?.toString(),
      sessionType: json['session_type']?.toString() ?? 'focused',
      plannedDurationMinutes:
          (json['duration_minutes'] as num?)?.toInt() ?? 25,
      elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
      totalPausedSeconds:
          (json['total_paused_seconds'] as num?)?.toInt() ?? 0,
      distractions: (json['distractions'] as num?)?.toInt() ?? 0,
      startTime: parseDt(json['start_time']),
      pausedAt: parseDt(json['paused_at']),
      clearPausedAt: json['paused_at'] == null,
      topicsCovered: topics,
      loading: false,
      clearError: true,
    );

    // Start or stop the UI ticker based on the new phase.
    if (phase == SessionPhase.running) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  /// Reset to a pristine idle state (no session). Stops the ticker too.
  /// `endRequested` is implicitly cleared because it defaults to false on
  /// the fresh SessionState.
  void _resetToIdle() {
    _stopTicker();
    state = const SessionState();
  }

  //
  // The server computes `elapsed_seconds` on every request, but we only
  // request on explicit user actions. Between those, we need the timer on
  // screen to advance, so we run a cheap 1 Hz tick that bumps
  // `elapsedSeconds` by 1 as long as the phase is `running`. When a server
  // response lands, `_applyServer` overwrites our local counter so drift
  // between client and server never gets worse than ~1 s per mutation.

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.phase != SessionPhase.running) return;
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }


  /// Pull the active session from the backend on app boot.
  ///
  /// 204 means no active session — we just stay idle. Any other error we
  /// surface via `state.error` but leave the phase at idle so the user
  /// isn't trapped in a stuck loading shell.
  Future<void> hydrate() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final resp = await _api.get('/study/sessions/active');
      if (resp.statusCode == 204 || resp.data == null) {
        _resetToIdle();
        return;
      }
      _applyServer(Map<String, dynamic>.from(resp.data as Map));
    } on DioException catch (e) {
      // Auth errors happen during logout/login transitions — silent reset.
      if (e.response?.statusCode == 401) {
        _resetToIdle();
        return;
      }
      state = state.copyWith(
        loading: false,
        error: 'Could not restore your session. Pull to refresh.',
      );
    } catch (_) {
      state = state.copyWith(loading: false, clearError: true);
    }
  }

  /// Open a fresh live session. Returns the new session id on success,
  /// null on failure (error is set on state).
  ///
  /// If a live session already exists, the backend rejects with 409 and we
  /// call `hydrate()` to adopt that session rather than surface a user-
  /// facing error — the UX invariant is "there's always at most one live
  /// session, and it's the one on screen".
  Future<String?> start({
    String? subjectId,
    String? subjectName,
    String? title,
    String sessionType = 'focused',
    int plannedDurationMinutes = 25,
    List<String> topicsCovered = const [],
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final body = <String, dynamic>{
        'session_type': sessionType,
        'planned_duration_minutes': plannedDurationMinutes,
        'topics_covered': topicsCovered,
      };
      if (subjectId != null) body['subject_id'] = subjectId;
      if (title != null && title.isNotEmpty) body['title'] = title;

      final resp = await _api.post('/study/sessions/start', data: body);
      _applyServer(Map<String, dynamic>.from(resp.data as Map));
      // Decorate with the subject name supplied by the caller — backend
      // doesn't include a subject_name in its response, and we don't want
      // the hero to flash "Loading…" for a subject the caller already knows.
      if (subjectName != null) {
        state = state.copyWith(subjectName: subjectName);
      }
      return state.sessionId;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Somebody else (or a previous app session) already owns the live
        // row. Adopt it silently.
        await hydrate();
        return state.sessionId;
      }
      state = state.copyWith(
        loading: false,
        error: 'Could not start session. Check your connection.',
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not start session.',
      );
      return null;
    }
  }

  /// Pause the running session. No-op if already paused or idle.
  Future<void> pause() async {
    final id = state.sessionId;
    if (id == null || state.phase != SessionPhase.running) return;
    // Optimistic: flip local state so the button swaps immediately.
    state = state.copyWith(phase: SessionPhase.paused, loading: true);
    try {
      final resp = await _api.put('/study/sessions/$id/pause');
      _applyServer(Map<String, dynamic>.from(resp.data as Map));
    } catch (_) {
      // Roll back the optimistic flip on failure so the UI doesn't lie.
      state = state.copyWith(
        phase: SessionPhase.running,
        loading: false,
        error: 'Pause failed. Try again.',
      );
    }
  }

  /// Resume the paused session. No-op if already running or idle.
  Future<void> resume() async {
    final id = state.sessionId;
    if (id == null || state.phase != SessionPhase.paused) return;
    state = state.copyWith(phase: SessionPhase.running, loading: true);
    try {
      final resp = await _api.put('/study/sessions/$id/resume');
      _applyServer(Map<String, dynamic>.from(resp.data as Map));
    } catch (_) {
      state = state.copyWith(
        phase: SessionPhase.paused,
        loading: false,
        error: 'Resume failed. Try again.',
      );
    }
  }

  /// Finalize the session with optional focus score, notes, and topics.
  /// After this resolves successfully, state returns to idle.
  ///
  /// `discard` signals "the user chose Discard on the confirm sheet" — we
  /// still call /end so the backend has a clean audit trail, but we pass
  /// focus_score=1 and notes="__discarded__" so Analytics can filter it
  /// out of focus averages. (The row isn't DELETE'd because we want the
  /// distraction count to still show up on the weekly heatmap as a
  /// signal.)
  Future<bool> end({
    int? focusScore,
    String? notes,
    List<String>? topicsCovered,
    bool discard = false,
  }) async {
    final id = state.sessionId;
    if (id == null) return false;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final body = <String, dynamic>{};
      if (discard) {
        body['focus_score'] = 1;
        body['notes'] = '__discarded__';
      } else {
        if (focusScore != null) body['focus_score'] = focusScore;
        if (notes != null) body['notes'] = notes;
        if (topicsCovered != null) body['topics_covered'] = topicsCovered;
      }
      await _api.put('/study/sessions/$id/end', data: body);
      _resetToIdle();
      return true;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not end session. Try again.',
      );
      return false;
    }
  }

  /// Ask the study_session_screen to move to its Wrapped/completion phase.
  ///
  /// Called by the mini session bar's Stop button and the Study tab hero
  /// Stop button — both of which now *navigate* the user into a full
  /// rating screen rather than quietly calling /end. When true, the
  /// session_screen observes the flag, jumps to completion phase, and
  /// immediately clears it via [consumeEndRequest] so the flag is truly
  /// ephemeral.
  ///
  /// Also pauses the underlying timer — once the user is rating, the clock
  /// shouldn't keep running and inflating their elapsed display. If the
  /// user backs out of the rating screen without saving, they can always
  /// resume from the mini player.
  Future<void> requestEnd() async {
    if (!state.isLive) return;
    state = state.copyWith(endRequested: true);
    // Best-effort pause so elapsed stops ticking on the Wrapped screen.
    // If the session was already paused this is a no-op inside pause().
    if (state.phase == SessionPhase.running) {
      await pause();
    }
  }

  /// Reset the endRequested flag after the study_session_screen has acted
  /// on it. Prevents the screen from re-entering completion phase on every
  /// rebuild.
  void consumeEndRequest() {
    if (state.endRequested) {
      state = state.copyWith(endRequested: false);
    }
  }

  /// Record a distraction event without pausing the timer. Used by the
  /// top-level tab guard: leaving the Study tab while a session is live
  /// counts as "attention drift" — session clock keeps ticking, but we
  /// bump the counter so the Wrapped screen's focus-score clamp (and the
  /// server's auto-derived focus score fallback) reflect it.
  ///
  /// Bumps local state optimistically and then best-effort sync to server.
  /// Failure is silent — the worst case is a +1 divergence between local
  /// and server distractions, which reconciles on the next /pause or /end.
  Future<void> addDistraction() async {
    final id = state.sessionId;
    if (id == null || !state.isLive) return;
    // Optimistic local bump so the slider clamp reacts immediately even
    // when the server request is slow.
    state = state.copyWith(distractions: state.distractions + 1);
    try {
      final resp = await _api.put('/study/sessions/$id/distract');
      if (resp.data is Map) {
        _applyServer(Map<String, dynamic>.from(resp.data as Map));
      }
    } catch (_) {
      // Swallow — the local bump is already applied; retry isn't critical.
    }
  }

  /// Clear the transient error banner (called by snackbar dismiss, etc).
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

/// Global provider. Created once at app scope so every screen shares
/// the same session state.
final studySessionProvider =
    StateNotifierProvider<StudySessionNotifier, SessionState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final notifier = StudySessionNotifier(api);

  // Reset + re-hydrate whenever the active account changes so we never
  // show Account A's live session to Account B (or vice versa).
  ref.listen<AuthState>(authProvider, (prev, next) {
    final becameAuthed = (prev?.status != AuthStatus.authenticated) &&
        (next.status == AuthStatus.authenticated);
    final becameUnauthed = (prev?.status == AuthStatus.authenticated) &&
        (next.status != AuthStatus.authenticated);
    if (becameAuthed) {
      // Immediately drop the in-memory session so the hero / mini-player
      // don't show the previous user's timer while /sessions/active is
      // in flight.
      notifier._resetToIdle();
      // ignore: discarded_futures
      notifier.hydrate();
    } else if (becameUnauthed) {
      notifier._resetToIdle();
    }
  });

  return notifier;
});

/// Convenience selector for the common "is there a live session right now?"
/// check — used by tab guards and the mini-player visibility.
final isSessionLiveProvider = Provider<bool>((ref) {
  return ref.watch(studySessionProvider).isLive;
});
