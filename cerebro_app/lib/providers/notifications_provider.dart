// Notification bell provider — fetch, read, dismiss.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cerebro_app/services/api_service.dart';
import 'package:cerebro_app/providers/auth_provider.dart' show apiServiceProvider;


class AppNotification {
  final String id;
  final String kind;        // event_created | event_reminder | ai_schedule | system
  final String title;
  final String body;
  final String? eventId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.eventId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        kind: (j['kind'] as String?) ?? 'system',
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        eventId: j['event_id'] as String?,
        read: (j['read'] as bool?) ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')
            ?? DateTime.now(),
      );

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        eventId: eventId,
        read: read ?? this.read,
        createdAt: createdAt,
      );
}


@immutable
class NotificationsState {
  final List<AppNotification> items;
  final bool loading;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  int get unreadCount => items.where((n) => !n.read).length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    bool? loading,
    Object? error = _sentinel,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );
}

const _sentinel = Object();


class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final ApiService _api;
  NotificationsNotifier(this._api) : super(const NotificationsState());

  /// Fetch notifications from the server.
  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final r = await _api.get('/notifications');
      if (r.statusCode == 200 && r.data is List) {
        final list = (r.data as List)
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .toList();
        state = NotificationsState(items: list, loading: false);
      } else {
        state = state.copyWith(loading: false, error: 'Unexpected response');
      }
    } catch (e) {
      // Most common failure here is "user not logged in yet" during the
      // auth bootstrap — surface it via state.error but don't blow up the
      // dashboard. The bell just silently renders with count 0.
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> markRead(String id) async {
    // Optimistic — flip local state immediately, reconcile on failure.
    final before = state.items;
    state = state.copyWith(
      items: [for (final n in before) if (n.id == id) n.copyWith(read: true) else n],
    );
    try {
      await _api.post('/notifications/$id/read');
    } catch (_) {
      state = state.copyWith(items: before);
    }
  }

  Future<void> markAllRead() async {
    final before = state.items;
    state = state.copyWith(
      items: [for (final n in before) n.copyWith(read: true)],
    );
    try {
      await _api.post('/notifications/mark-all-read');
    } catch (_) {
      state = state.copyWith(items: before);
    }
  }

  Future<void> dismiss(String id) async {
    final before = state.items;
    state = state.copyWith(items: [for (final n in before) if (n.id != id) n]);
    try {
      await _api.delete('/notifications/$id');
    } catch (_) {
      state = state.copyWith(items: before);
    }
  }
}


final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.watch(apiServiceProvider));
});
