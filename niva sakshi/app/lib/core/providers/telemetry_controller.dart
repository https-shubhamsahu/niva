import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/esp32_socket_service.dart';
import '../connectivity/esp32_ble_service.dart';
import '../demo/demo_walk.dart';
import '../data/telemetry_repository.dart';
import '../data/settings_repository.dart';
import '../engine/gait_timing_engine.dart';
import '../models/gait_metrics.dart';
import '../models/telemetry_sample.dart';
import '../time/clock.dart';
import 'telemetry_state.dart';

/// The single controller every screen reads from. It owns:
///   - the live ESP32 links (Wi-Fi WebSocket and BLE),
///   - the shared [GaitTimingEngine] both feed into,
///   - and periodic flushing of samples into [TelemetryRepository].
///
/// Measurements only ever come from the insole. The one exception is the
/// opt-in demo walk ([startDemo]) for presentations: it is flagged in
/// [TelemetryState.isDemo] and labelled on screen, and its frames are never
/// saved to the dataset or published to assessments.
class TelemetryController extends StateNotifier<TelemetryState> {
  final Esp32SocketService socket;
  final Esp32BleService ble;
  final GaitTimingEngine engine;
  final TelemetryRepository repository;
  final SettingsRepository settings;
  final MonotonicClock clock;

  StreamSubscription<Esp32ConnectionState>? _socketSub;
  StreamSubscription<Esp32ConnectionState>? _bleSub;
  Timer? _flushTimer;
  Timer? _demoTimer;

  final List<TelemetrySample> _pendingSamples = [];
  Map<String, dynamic>? _lastSocketPacket;
  Map<String, dynamic>? _lastBlePacket;

  final ClockSync _clockSync = ClockSync();
  final StreamController<TimedContactEvent> _contactEvents =
      StreamController<TimedContactEvent>.broadcast();

  /// Contact events from valid frames, placed on [clock]. The fitness tests
  /// listen here.
  Stream<TimedContactEvent> get contactEvents => _contactEvents.stream;

  TelemetryController({
    required this.socket,
    required this.ble,
    required this.engine,
    required this.repository,
    required this.settings,
    required this.clock,
  }) : super(TelemetryState.initial()) {
    _socketSub = socket.stateStream.listen(_onSocketState);
    _bleSub = ble.stateStream.listen(_onBleState);
    _flushTimer = Timer.periodic(const Duration(seconds: 1), (_) => _flush());
    state = state.copyWith(datasetCount: repository.sampleCount);
  }

  bool get isDemoRunning => _demoTimer != null;

  /// Plays the scripted [DemoWalk] through the real timing engine.
  Future<void> startDemo() async {
    if (_demoTimer != null) return;
    await socket.disconnect();
    await ble.disconnect();
    engine.reset();
    final walk = DemoWalk();
    // Walk the first 15 s straight through the engine so the timing values
    // are past their 12-contact gate when the demo first appears.
    var metrics = GaitMetrics.idle();
    for (var i = 0; i < 15000 ~/ DemoWalk.frameMs; i++) {
      metrics = engine.process(walk.next());
    }
    state = state.copyWith(
        isDemo: true,
        isConnected: true,
        isConnecting: false,
        clearConnectionError: true,
        measurementValidity: 'valid',
        imuClipped: false,
        metrics: metrics);
    _demoTimer = Timer.periodic(
        const Duration(milliseconds: DemoWalk.frameMs),
        (_) => state = state.copyWith(
            metrics: engine.process(walk.next()),
            lastMessageAt: DateTime.now()));
  }

  void stopDemo() {
    if (_demoTimer == null) return;
    _demoTimer?.cancel();
    _demoTimer = null;
    engine.reset();
    state = state.copyWith(
        isDemo: false,
        isConnected: false,
        measurementValidity: 'unknown',
        metrics: GaitMetrics.idle());
  }

  Future<void> connectLive() async {
    stopDemo();
    engine.reset();
    await ble.disconnect();
    socket.connect();
  }

  Future<void> connectBle() async {
    stopDemo();
    engine.reset();
    await socket.disconnect();
    await ble.connect();
  }

  void disconnectLive() {
    unawaited(socket.disconnect());
    unawaited(ble.disconnect());
  }

  Future<void> tareLive() async {
    if (ble.state.isConnected) {
      await ble.tare();
    } else {
      socket.tare();
    }
  }

  void _onSocketState(Esp32ConnectionState socketState) {
    _onTransportState(socketState, TelemetrySource.ws);
  }

  void _onBleState(Esp32ConnectionState bleState) {
    _onTransportState(bleState, TelemetrySource.ble);
  }

  void _onTransportState(
      Esp32ConnectionState connectionState, TelemetrySource source) {
    // While the demo plays, idle transport updates must not overwrite it.
    if (_demoTimer != null) return;
    state = state.copyWith(
      isConnected: connectionState.isConnected,
      isConnecting: connectionState.isConnecting,
      connectionError: connectionState.error,
      clearConnectionError: connectionState.error == null,
      activeUrl: connectionState.activeUrl,
      lastMessageAt: connectionState.lastMessageAt,
    );

    final packetMap = connectionState.latestPacket;
    if (packetMap == null) return;

    // Connection-state updates retain the latest packet for UI display. Only
    // a newly decoded map is a new observation; otherwise a reconnect/error
    // update would enqueue the same sample again.
    if (source == TelemetrySource.ws) {
      if (identical(_lastSocketPacket, packetMap)) return;
      _lastSocketPacket = packetMap;
    } else {
      if (identical(_lastBlePacket, packetMap)) return;
      _lastBlePacket = packetMap;
    }

    final arrivedMs = clock.nowMs;
    final deviceMs = (packetMap['deviceTimestampMs'] as num?)?.toInt();
    if (deviceMs != null) {
      _clockSync.observe(deviceMs: deviceMs, phoneMs: arrivedMs);
    }

    final validity = packetMap['validity'] as String? ?? 'unknown';
    state = state.copyWith(
      measurementValidity: validity,
      imuClipped: packetMap['imuClipped'] == true,
    );

    // The ESP32 owns calibration. An uncalibrated or in-progress frame is a
    // status frame, not evidence, and must not reach the timing engine or
    // the persisted research dataset. A new tare also restarts the firmware's
    // contact detector, so the engine starts over with it.
    if (validity != 'valid') {
      engine.reset();
      state = state.copyWith(metrics: GaitMetrics.idle());
      return;
    }

    state = state.copyWith(metrics: engine.process(packetMap));
    _enqueueSample(packetMap, source);
    _publishContactEvents(packetMap['events'], arrivedMs);
  }

  void _publishContactEvents(Object? rawEvents, int arrivedMs) {
    if (rawEvents is! List || !_contactEvents.hasListener) return;
    for (final raw in rawEvents) {
      final event = ContactEvent.parse(raw);
      if (event == null) continue;
      final phoneMs = _clockSync.toPhone(event.deviceMs) ?? arrivedMs;
      _contactEvents.add(
          TimedContactEvent(event, phoneMs > arrivedMs ? arrivedMs : phoneMs));
    }
  }

  void _enqueueSample(Map<String, dynamic> packet, TelemetrySource source) {
    double reading(String key) => (packet[key] as num?)?.toDouble() ?? 0;
    final events = packet['events'];
    _pendingSamples.add(TelemetrySample(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      source: source,
      sessionId: settings.sessionId,
      trialId: settings.trialId,
      mode: TelemetryMode.live,
      heel: reading('heel'),
      inner: reading('inner'),
      outer: reading('outer'),
      toe: reading('toe'),
      impact: (packet['impact'] as num?)?.toDouble() ?? reading('piezo'),
      pitch: reading('pitch'),
      roll: reading('roll'),
      accZ: (packet['accZ'] as num?)?.toDouble() ?? 9.8,
      deviceTimestampMs: (packet['deviceTimestampMs'] as num?)?.toInt(),
      contact: (packet['contact'] as num?)?.toInt() ?? 0,
      events: events is List ? events.whereType<String>().join(' ') : '',
    ));
  }

  Future<void> _flush() async {
    if (_pendingSamples.isEmpty) return;
    final batch = List<TelemetrySample>.from(_pendingSamples);
    _pendingSamples.clear();
    try {
      await repository.insertSamples(batch);
      state = state.copyWith(
        datasetCount: repository.sampleCount,
        datasetStatus: 'Saved ${batch.length} samples',
      );
    } catch (_) {
      state =
          state.copyWith(datasetStatus: 'Dataset write failed - will retry');
      _pendingSamples.insertAll(0, batch);
    }
  }

  Future<void> clearDataset() async {
    await repository.clear();
    state = state.copyWith(datasetCount: 0, datasetStatus: 'Dataset cleared');
  }

  @override
  void dispose() {
    // Note: `socket` itself is disposed by `esp32SocketServiceProvider`'s own
    // `ref.onDispose`, not here - it is a separately-provided singleton this
    // controller merely listens to.
    _socketSub?.cancel();
    _bleSub?.cancel();
    _flushTimer?.cancel();
    _demoTimer?.cancel();
    _contactEvents.close();
    super.dispose();
  }
}
