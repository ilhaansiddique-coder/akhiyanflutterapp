import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:akhiyan_admin/src/core/api/api_config.dart';
import 'package:akhiyan_admin/src/core/api/secure_token_storage.dart';

/// Live-sync channel name → version number.
///
/// The backend emits `bumpVersion(channel)` from every admin write route,
/// pushed over Server-Sent Events at `/api/v1/m/sync/stream`. This map is
/// the local mirror — UI screens watch it via [syncVersionProvider] and
/// invalidate their data providers when their channel's version changes.
@immutable
class SyncState {

  const SyncState({
    this.versions = const {},
    this.connected = false,
    this.lastEvent,
  });
  final Map<String, int> versions;
  final bool connected;
  /// The most recent event received from the stream. Distinct from
  /// [versions] (which is a fold of all events) because consumers like
  /// the NotificationStore care about each individual event, not the
  /// running aggregate. `null` until the first bump arrives.
  final SyncEvent? lastEvent;

  SyncState copyWith({
    Map<String, int>? versions,
    bool? connected,
    SyncEvent? lastEvent,
  }) =>
      SyncState(
        versions: versions ?? this.versions,
        connected: connected ?? this.connected,
        lastEvent: lastEvent ?? this.lastEvent,
      );

  int versionOf(String channel) => versions[channel] ?? 0;
}

/// User-facing notification metadata attached to a bump. Mirrors the
/// `SyncNotify` interface in `src/lib/sync.ts` on the backend
/// (severity is one of: info, warn, alert).
@immutable
class SyncNotify { // "info" | "warn" | "alert"

  const SyncNotify({
    required this.kind,
    required this.title,
    required this.body,
    this.href,
    this.icon,
    this.severity,
  });

  factory SyncNotify.fromJson(Map<String, dynamic> json) => SyncNotify(
        kind: json['kind'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        href: json['href'] as String?,
        icon: json['icon'] as String?,
        severity: json['severity'] as String?,
      );
  final String kind;
  final String title;
  final String body;
  final String? href;
  final String? icon;
  final String? severity;
}

/// SSE event payload from the server. Backend wire shape:
///   `{ "channel": "...", "version": N, "ts": <ms>, "notify"?: {...} }`
/// The `ts` falls back to local clock if the server snapshot omits it
/// (older snapshots before the notify protocol shipped).
@immutable
class SyncEvent {

  const SyncEvent({
    required this.channel,
    required this.version,
    required this.ts,
    this.notify,
  });

  factory SyncEvent.fromJson(Map<String, dynamic> json) => SyncEvent(
        channel: json['channel'] as String,
        version: (json['version'] as num).toInt(),
        ts: (json['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        notify: json['notify'] is Map<String, dynamic>
            ? SyncNotify.fromJson(json['notify'] as Map<String, dynamic>)
            : null,
      );
  final String channel;
  final int version;
  final int ts;
  final SyncNotify? notify;
}

/// Long-lived SSE consumer.
///
/// Maintains a single connection to `/api/v1/m/sync/stream` for the lifetime
/// of the app. On any disconnect (network blip, backend restart, proxy idle
/// kill) it self-heals via exponential backoff capped at 30s. Heartbeats from
/// the server (`: ping\n\n` every 25s) keep the link warm; if we go more than
/// 60s without ANY bytes (heartbeat or event), we proactively reconnect.
///
/// Why hand-rolled instead of an `eventsource` package: the protocol is
/// trivial (line-delimited UTF-8 with `data:` prefixes), and we already have
/// `http` in pubspec. Avoiding another dep keeps the supply chain tight.
class SyncClient extends Notifier<SyncState> {
  http.Client? _http;
  StreamSubscription<String>? _sub;
  Timer? _watchdog;
  Timer? _reconnect;
  int _attempt = 0;
  final bool _disposed = false;

  @override
  SyncState build() {
    ref.onDispose(_close);
    // Defer the first connect to the next tick so providers that listen to
    // sync state mount before we start emitting events.
    Future.microtask(_connect);
    return const SyncState();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    _close(keepWatchdog: false);

    final url = '${ApiConfig.baseUrl}/sync/stream';
    // Only `Accept` here — adding `Cache-Control` would push the request out
    // of the CORS "simple" set on web, triggering a preflight that the
    // backend's allowed-headers list rejects. Browsers don't cache
    // `text/event-stream` anyway, so the header buys us nothing.
    final req = http.Request('GET', Uri.parse(url))
      ..headers['Accept'] = 'text/event-stream';

    // Authenticate the SSE connection — withAdmin is on the Next.js stream
    // route via getSessionUser(), which reads either the cookie OR the
    // Authorization: Bearer header. Mobile uses the bearer header.
    final token = await SecureTokenStorage().getAccessToken();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    final client = http.Client();
    _http = client;
    try {
      final res = await client.send(req);
      if (res.statusCode != 200) {
        debugPrint('[sync] connect failed status=${res.statusCode}');
        _scheduleReconnect();
        return;
      }
      state = state.copyWith(connected: true);
      _attempt = 0;
      _armWatchdog();

      // SSE frames are blank-line delimited. We split on \n and accumulate
      // `data:` lines until we see an empty line, then JSON-parse the buffer.
      var buffer = '';
      _sub = res.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              _armWatchdog(); // any byte resets the silence timer
              if (line.isEmpty) {
                if (buffer.isNotEmpty) {
                  _handleEvent(buffer);
                  buffer = '';
                }
              } else if (line.startsWith('data:')) {
                buffer += line.substring(5).trimLeft();
              }
              // Comments (`: ping`) and field lines we don't care about
              // (`event:`, `id:`, `retry:`) are ignored — fine for our protocol.
            },
            onError: (_) {
              state = state.copyWith(connected: false);
              _scheduleReconnect();
            },
            onDone: () {
              state = state.copyWith(connected: false);
              _scheduleReconnect();
            },
            cancelOnError: true,
          );
    } catch (e) {
      debugPrint('[sync] connect error: $e');
      state = state.copyWith(connected: false);
      _scheduleReconnect();
    }
  }

  void _handleEvent(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final evt = SyncEvent.fromJson(data);
      // Replace instead of mutating so Riverpod listeners notice the change.
      final next = Map<String, int>.from(state.versions);
      next[evt.channel] = evt.version;
      state = state.copyWith(versions: next, lastEvent: evt);
    } catch (e) {
      debugPrint('[sync] bad event payload: $json - $e');
    }
  }

  /// 60-second silence watchdog. Server sends a heartbeat every 25s, so
  /// going past 60s without bytes means the connection is dead even though
  /// our socket hasn't realised it yet (common on flaky carrier networks).
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 60), () {
      debugPrint('[sync] watchdog timeout — reconnecting');
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    _close(keepWatchdog: false);
    if (_disposed) return;
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s, 30s, …
    final delaySec = (1 << _attempt).clamp(1, 30);
    _attempt = (_attempt + 1).clamp(0, 5);
    _reconnect = Timer(Duration(seconds: delaySec), _connect);
  }

  void _close({bool keepWatchdog = true}) {
    _sub?.cancel();
    _sub = null;
    _http?.close();
    _http = null;
    _reconnect?.cancel();
    _reconnect = null;
    if (!keepWatchdog) {
      _watchdog?.cancel();
      _watchdog = null;
    }
  }
}

/// App-wide live-sync provider. Mount once at the root of the widget tree
/// so the SSE connection lives for the app's lifetime.
final syncClientProvider = NotifierProvider<SyncClient, SyncState>(SyncClient.new);

/// Convenience: watch a single channel's version. UI providers can chain
/// `ref.watch(syncVersionProvider("orders"))` and refetch when the int
/// changes — the simplest live-cache invalidation idiom available.
final syncVersionProvider = Provider.autoDispose.family<int, String>((ref, channel) {
  return ref.watch(syncClientProvider.select((s) => s.versions[channel] ?? 0));
});
