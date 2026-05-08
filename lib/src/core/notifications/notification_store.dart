import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:akhiyan_admin/src/core/sync/sync_client.dart';

/// Visual emphasis level emitted by the backend.
enum NotifySeverity { info, warn, alert }

NotifySeverity _parseSeverity(String? raw) {
  switch (raw) {
    case 'warn':
      return NotifySeverity.warn;
    case 'alert':
      return NotifySeverity.alert;
    default:
      return NotifySeverity.info;
  }
}

/// One row in the in-app notification panel. Created from a [SyncEvent]
/// whose backend payload included a `notify` object.
@immutable
class NotificationEntry {

  const NotificationEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.href,
    this.icon,
    this.severity = NotifySeverity.info,
    required this.receivedAt,
    this.read = false,
  });
  final String id; // synthesised from kind + channel + version (dedupe key)
  final String kind;
  final String title;
  final String body;
  final String? href;
  final String? icon;
  final NotifySeverity severity;
  final DateTime receivedAt;
  final bool read;

  NotificationEntry copyWith({bool? read}) => NotificationEntry(
        id: id,
        kind: kind,
        title: title,
        body: body,
        href: href,
        icon: icon,
        severity: severity,
        receivedAt: receivedAt,
        read: read ?? this.read,
      );

  /// Map a `notify.icon` string from the backend (Material icon name without
  /// the `Icons.` prefix) to a concrete [IconData], with a fallback per kind
  /// for events the server didn't tag with one.
  IconData get iconData {
    final byName = _iconByName(icon);
    if (byName != null) return byName;
    return _iconForKind(kind);
  }
}

IconData? _iconByName(String? name) {
  switch (name) {
    case 'shopping_bag':
      return Icons.shopping_bag_outlined;
    case 'local_shipping':
      return Icons.local_shipping_outlined;
    case 'inventory_2':
      return Icons.inventory_2_outlined;
    case 'warning_amber':
      return Icons.warning_amber_outlined;
    case 'report':
      return Icons.report_outlined;
    case 'payments':
      return Icons.payments_outlined;
    case 'local_offer':
      return Icons.local_offer_outlined;
    case 'campaign':
      return Icons.campaign_outlined;
    default:
      return null;
  }
}

IconData _iconForKind(String kind) {
  if (kind.startsWith('order.')) return Icons.shopping_bag_outlined;
  if (kind.startsWith('product.')) return Icons.inventory_2_outlined;
  if (kind.startsWith('payment.')) return Icons.payments_outlined;
  if (kind.startsWith('coupon.')) return Icons.local_offer_outlined;
  if (kind.startsWith('banner.')) return Icons.campaign_outlined;
  if (kind.startsWith('fraud.')) return Icons.report_outlined;
  if (kind.contains('low_stock')) return Icons.warning_amber_outlined;
  return Icons.notifications_outlined;
}

@immutable
class NotificationState {

  const NotificationState({this.entries = const []});
  /// Newest-first list of notifications received during this app session.
  /// Capped at [_maxEntries] so a long-running session can't bloat memory.
  final List<NotificationEntry> entries;

  int get unreadCount => entries.where((e) => !e.read).length;

  NotificationState copyWith({List<NotificationEntry>? entries}) =>
      NotificationState(entries: entries ?? this.entries);
}

/// In-memory store that listens to [syncClientProvider] and turns each
/// `notify`-bearing [SyncEvent] into a [NotificationEntry] in [entries].
///
/// Why in-memory only: persistent storage would require Hive + a per-user
/// box + dedupe across reconnects; for this iteration the goal is "live
/// alerts during an active session". Restarting the app clears the panel.
/// If we need history later, swap the [List] for a Hive-backed
/// `Box<NotificationEntry>` — the public API stays the same.
class NotificationStore extends Notifier<NotificationState> {
  /// Max entries kept in memory. Old entries fall off the bottom.
  static const int _maxEntries = 200;

  /// Last `(channel, version)` we processed per channel. SSE reconnect
  /// resends a snapshot of current versions; without this guard the same
  /// event would land twice.
  final Map<String, int> _seenVersionByChannel = {};

  @override
  NotificationState build() {
    // Subscribe to the sync client. Riverpod will keep this provider alive
    // for the lifetime of the app (no autoDispose) so we don't miss events
    // when no screen is currently watching the notification panel.
    ref.listen<SyncState>(syncClientProvider, (prev, next) {
      _ingest(prev?.versions, next.versions, next.lastEvent);
    }, fireImmediately: true);

    return const NotificationState();
  }

  /// Called whenever [syncClientProvider] state changes. We only act on the
  /// most recent event (`lastEvent`); the snapshot of versions is for cache
  /// invalidation elsewhere.
  void _ingest(
    Map<String, int>? prevVersions,
    Map<String, int> nextVersions,
    SyncEvent? lastEvent,
  ) {
    if (lastEvent == null) return;
    if (lastEvent.notify == null) return;

    // Dedupe: ignore events whose (channel, version) we've already
    // surfaced. Initial-snapshot pushes from SSE reconnect all share
    // version numbers we've already seen, so this is the bouncer.
    final seen = _seenVersionByChannel[lastEvent.channel];
    if (seen != null && lastEvent.version <= seen) return;
    _seenVersionByChannel[lastEvent.channel] = lastEvent.version;

    final n = lastEvent.notify!;
    final id = '${n.kind}:${lastEvent.channel}:${lastEvent.version}';

    // O(n) prepend with cap. List<>.length is bounded by _maxEntries so the
    // copy cost stays tiny — no need for a deque.
    final entry = NotificationEntry(
      id: id,
      kind: n.kind,
      title: n.title,
      body: n.body,
      href: n.href,
      icon: n.icon,
      severity: _parseSeverity(n.severity),
      receivedAt: DateTime.fromMillisecondsSinceEpoch(lastEvent.ts),
    );

    final next = [entry, ...state.entries];
    if (next.length > _maxEntries) next.removeRange(_maxEntries, next.length);
    state = state.copyWith(entries: next);

    if (kDebugMode) {
      debugPrint('[notif] +${entry.kind} "${entry.title}"  (unread=${state.unreadCount})');
    }
  }

  /// Mark a single notification as read. UI binds this to "tap to open".
  void markRead(String id) {
    var changed = false;
    final next = state.entries.map((e) {
      if (e.id == id && !e.read) {
        changed = true;
        return e.copyWith(read: true);
      }
      return e;
    }).toList(growable: false);
    if (changed) state = state.copyWith(entries: next);
  }

  /// Clear unread state on every entry — called from the "Mark all read"
  /// button on the notifications screen.
  void markAllRead() {
    final next = state.entries.map((e) => e.copyWith(read: true)).toList(growable: false);
    state = state.copyWith(entries: next);
  }

  /// Clear the entire notification list. Not currently exposed in UI but
  /// useful for QA / settings "clear all".
  void clear() => state = const NotificationState();
}

final notificationStoreProvider =
    NotifierProvider<NotificationStore, NotificationState>(NotificationStore.new);

/// Convenience selector — bell-icon badge watches just the int and rebuilds
/// only on count changes, not on every entry.read toggle.
final unreadNotificationsProvider = Provider<int>((ref) {
  return ref.watch(notificationStoreProvider.select((s) => s.unreadCount));
});
