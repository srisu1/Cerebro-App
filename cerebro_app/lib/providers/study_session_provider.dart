// Live study session provider — syncs with backend, ticks locally.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

/// Session lifecycle — mirrors backend `status` plus `idle`.
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

/// Current session snapshot.
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
  // When true, the session screen should show the rating/wrap-up flow.
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

  /// True when there's an active (running or paused) session.
  bool get isLive =>
      phase == SessionPhase.running || phase == SessionPhase.paused;

  /// Fraction of planned duration completed, clamped to [0, 1].
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

/// Manages live study session state and server sync.
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

  /// Reset to idle (no active session).
  void _resetToIdle() {
    _stopTicker();
    state = const SessionState();
  }

  // 1 Hz local tick — server overwrites on each mutation.

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


  /// Restore active session from backend on app boot.
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

  /// Start a new session. Returns session id or null on failure.
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

  /// End the session. Pass `discard: true` to mark it as discarded.
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

  /// Signal the session screen to show the completion/rating flow.
  Future<void> requestEnd() async {
    if (!state.isLive) return;
    state = state.copyWith(endRequested: true);
    // Best-effort pause so elapsed stops ticking on the Wrapped screen.
    // If the session was already paused this is a no-op inside pause().
    if (state.phase == SessionPhase.running) {
      await pause();
    }
  }

  /// Clear the endRequested flag after the screen acts on it.
  void consumeEndRequest() {
    if (state.endRequested) {
      state = state.copyWith(endRequested: false);
    }
  }

  /// Bump the distraction counter without pausing.
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

  // Reset on auth transitions so sessions don't leak across accounts.
  ref.listen<AuthState>(authProvider, (prev, next) {
    final becameAuthed = (prev?.status != AuthStatus.authenticated) &&
        (next.status == AuthStatus.authenticated);
    final becameUnauthed = (prev?.status == AuthStatus.authenticated) &&
        (next.status != AuthStatus.authenticated);
    if (becameAuthed) {
      notifier._resetToIdle();
      // ignore: discarded_futures
      notifier.hydrate();
    } else if (becameUnauthed) {
      notifier._resetToIdle();
    }
  });

  return notifier;
});

/// Whether a live session is active right now.
final isSessionLiveProvider = Provider<bool>((ref) {
  return ref.watch(studySessionProvider).isLive;
});
