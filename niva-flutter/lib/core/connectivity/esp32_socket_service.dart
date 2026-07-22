import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/settings_repository.dart';

/// Live connection state for the ESP32 WebSocket link. Kept as a plain
/// immutable value (not a widget-facing enum) so it round-trips cleanly
/// through Riverpod's StateNotifier.
class Esp32ConnectionState {
  final bool isConnected;
  final bool isConnecting;
  final String? error;
  final DateTime? lastMessageAt;
  final String activeUrl;
  final Map<String, dynamic>? latestPacket;

  const Esp32ConnectionState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.lastMessageAt,
    this.activeUrl = '',
    this.latestPacket,
  });

  Esp32ConnectionState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? error,
    bool clearError = false,
    DateTime? lastMessageAt,
    String? activeUrl,
    Map<String, dynamic>? latestPacket,
  }) {
    return Esp32ConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: clearError ? null : (error ?? this.error),
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      activeUrl: activeUrl ?? this.activeUrl,
      latestPacket: latestPacket ?? this.latestPacket,
    );
  }
}

/// Talks to the ESP32's WebSocket telemetry endpoint (`wsServer.begin()` /
/// `broadcastTXT` in the bundled firmware). This is the mobile-native
/// counterpart of `useSensorData.ts` - the USB Web Serial branch from the
/// web app has no mobile equivalent, so this service only implements the
/// WiFi path. See BETTERMENTS.md for the BLE roadmap.
///
/// Unlike a browser tab, a native app isn't blocked from opening plain
/// `ws://` sockets on its own TLS policy, so the mixed-content/relay dance
/// from the web app is optional here - the relay URL is still supported for
/// people who route through a `wss://` gateway (e.g. behind a firewall).
class Esp32SocketService {
  final SettingsRepository settings;

  Esp32SocketService(this.settings);

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _manuallyDisconnected = true;
  int _reconnectAttempt = 0;
  final _random = Random();

  final _stateController = StreamController<Esp32ConnectionState>.broadcast();
  Esp32ConnectionState _state = const Esp32ConnectionState();

  Stream<Esp32ConnectionState> get stateStream => _stateController.stream;
  Esp32ConnectionState get state => _state;

  void _emit(Esp32ConnectionState next) {
    _state = next;
    _stateController.add(_state);
  }

  String _resolveActiveUrl() {
    final wsUrl = settings.wsUrl;
    final relayUrl = settings.relayUrl;
    if (relayUrl.isEmpty) return wsUrl;

    final relay = Uri.parse(relayUrl);
    final withTarget = relay.replace(queryParameters: {
      ...relay.queryParameters,
      'target': wsUrl,
    });
    return withTarget.toString();
  }

  void connect() {
    _manuallyDisconnected = false;
    _reconnectTimer?.cancel();

    final activeUrl = _resolveActiveUrl();
    _emit(_state.copyWith(isConnecting: true, activeUrl: activeUrl, clearError: true));

    try {
      final channel = WebSocketChannel.connect(Uri.parse(activeUrl));
      _channel = channel;

      // web_socket_channel's `connect()` returns immediately and dials
      // lazily - a failure to establish the connection (e.g. host
      // unreachable) rejects `channel.ready` rather than reaching
      // `stream.listen`'s `onError`. Left unawaited, that rejection becomes
      // an unhandled exception instead of the "connection error" state below.
      channel.ready.then((_) {
        _reconnectAttempt = 0;
      }).catchError((error) {
        _emit(_state.copyWith(
          isConnected: false,
          isConnecting: false,
          error: 'WebSocket connection error. Check ESP32 IP, port, and network.',
        ));
        _scheduleReconnect();
      });

      _subscription = channel.stream.listen(
        (event) {
          try {
            final decoded = jsonDecode(event as String) as Map<String, dynamic>;
            _emit(_state.copyWith(
              isConnected: true,
              isConnecting: false,
              lastMessageAt: DateTime.now(),
              latestPacket: decoded,
              clearError: true,
            ));
          } catch (_) {
            // A single malformed frame on an otherwise-live link is a
            // transient parse blip, not a connection failure - don't leave a
            // stale error banner showing indefinitely if no more frames
            // arrive. Only surface it when the link isn't already known-good.
            if (_state.isConnected) {
              _emit(_state.copyWith(clearError: true));
            } else {
              _emit(_state.copyWith(error: 'Received malformed JSON from ESP32 WebSocket stream.'));
            }
          }
        },
        onError: (_) {
          _emit(_state.copyWith(
            isConnected: false,
            isConnecting: false,
            error: 'WebSocket connection error. Check ESP32 IP, port, and network.',
          ));
          _scheduleReconnect();
        },
        onDone: () {
          _emit(_state.copyWith(isConnected: false, isConnecting: false));
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _emit(_state.copyWith(
        isConnected: false,
        isConnecting: false,
        error: 'Invalid WebSocket URL: $activeUrl',
      ));
      _scheduleReconnect();
    }
  }

  // Capped exponential backoff with jitter: 1.5s, 3s, 6s, 12s, 24s, then a
  // 30s ceiling. No max-attempt give-up - a failure here could mean "ESP32
  // not powered on yet" (resolves in seconds) or "phone roamed off this
  // WiFi" (could be hours), and the Device screen's "Retry now" action
  // already gives the user a way to bypass the wait, so retrying forever at
  // a gentle ceiling is safer than ever leaving the app with no path forward.
  static const _baseReconnectDelayMs = 1500;
  static const _maxReconnectDelayMs = 30000;

  void _scheduleReconnect() {
    if (_manuallyDisconnected) return;
    _reconnectTimer?.cancel();
    final rawDelayMs = _baseReconnectDelayMs * (1 << _reconnectAttempt.clamp(0, 5));
    final cappedMs = min(rawDelayMs, _maxReconnectDelayMs);
    final jitteredMs = (cappedMs * (0.85 + _random.nextDouble() * 0.3)).round();
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(milliseconds: jitteredMs), connect);
  }

  Future<void> disconnect() async {
    _manuallyDisconnected = true;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _emit(_state.copyWith(isConnected: false, isConnecting: false));
  }

  void dispose() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _stateController.close();
  }
}
