import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/esp32_socket_service.dart';
import '../data/telemetry_repository.dart';
import '../data/settings_repository.dart';
import '../engine/biomechanics_engine.dart';
import '../engine/simulation_engine.dart';
import '../models/biomechanics_metrics.dart';
import '../models/telemetry_sample.dart';
import 'telemetry_state.dart';

const _simulationTickHz = 10; // matches simulationEngine.ts's 100ms/10Hz driver interval
const _copTrailLength = 12;

/// The single controller every screen reads from. It owns:
///   - the live ESP32 WebSocket link,
///   - the on-device disease simulator,
///   - the shared [BiomechanicsEngine] instance both feed into,
///   - and periodic flushing of samples into [TelemetryRepository].
///
/// Centralizing this (rather than letting each screen manage its own
/// subscription, like the original `MainDashboard.tsx` did inline) is the
/// main structural change from the web app - Dashboard/Trends/Insights can
/// now all watch the same provider instead of re-deriving state.
class TelemetryController extends StateNotifier<TelemetryState> {
  final Esp32SocketService socket;
  final SimulationEngine simulation;
  final BiomechanicsEngine engine;
  final TelemetryRepository repository;
  final SettingsRepository settings;

  StreamSubscription<Esp32ConnectionState>? _socketSub;
  Timer? _simulationTimer;
  Timer? _flushTimer;
  DateTime _simulationClock = DateTime.now();

  final List<TelemetrySample> _pendingSamples = [];

  TelemetryController({
    required this.socket,
    required this.simulation,
    required this.engine,
    required this.repository,
    required this.settings,
  }) : super(TelemetryState.initial()) {
    _socketSub = socket.stateStream.listen(_onSocketState);
    _flushTimer = Timer.periodic(const Duration(seconds: 1), (_) => _flush());
    state = state.copyWith(datasetCount: repository.sampleCount);
  }

  void connectLive() {
    // Mirrors stopSimulation()'s teardown - otherwise going live while a
    // simulation is running leaves its Timer.periodic still ticking in the
    // background, interleaving simulated and real samples.
    _simulationTimer?.cancel();
    _simulationTimer = null;
    state = state.copyWith(isSimulating: false, isDemoMode: false);
    engine.reset();
    socket.connect();
  }

  void disconnectLive() {
    socket.disconnect();
  }

  void startSimulation() {
    // A real connection (and its reconnect loop) left running in the
    // background while simulated data drives the UI is confusing and wastes
    // battery/network - only one of live/simulated should ever be active.
    socket.disconnect();
    _simulationTimer?.cancel();
    engine.reset();
    _simulationClock = DateTime.now();
    state = state.copyWith(isSimulating: true);

    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: 1000 ~/ _simulationTickHz),
      (_) => _tickSimulation(),
    );
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    state = state.copyWith(isSimulating: false, isDemoMode: false);
  }

  void setSimulationMode(GaitMode mode) {
    if (state.isDemoMode) return; // locked while auto-cycling demo runs
    state = state.copyWith(simMode: mode);
  }

  void toggleDemoMode() {
    state = state.copyWith(isDemoMode: !state.isDemoMode);
  }

  void _tickSimulation() {
    if (state.isDemoMode) {
      // Cycle through every mode every 8 seconds, matching MainDashboard.tsx's
      // demoTimer, so a clinician can watch the ring/heatmap react to each
      // condition hands-free.
      final modes = GaitMode.values;
      final index = (DateTime.now().millisecondsSinceEpoch ~/ 8000) % modes.length;
      if (modes[index] != state.simMode) {
        state = state.copyWith(simMode: modes[index]);
      }
    }

    final elapsedMs = DateTime.now().difference(_simulationClock).inMilliseconds;
    final frame = simulation.generateFrame(state.simMode, elapsedMs);
    final packet = simulation.frameToPacket(frame, DateTime.now().millisecondsSinceEpoch);
    final metrics = engine.process(packet);

    _pushMetrics(metrics);
    _enqueueSample(packet, TelemetrySource.sim, TelemetryMode.simulation);
  }

  void _onSocketState(Esp32ConnectionState socketState) {
    state = state.copyWith(
      isConnected: socketState.isConnected,
      isConnecting: socketState.isConnecting,
      connectionError: socketState.error,
      clearConnectionError: socketState.error == null,
      activeUrl: socketState.activeUrl,
      lastMessageAt: socketState.lastMessageAt,
    );

    final packetMap = socketState.latestPacket;
    if (packetMap == null || state.isSimulating) return;

    final packet = RawSensorPacket(
      heel: (packetMap['heel'] as num?)?.toDouble() ?? 0,
      inner: (packetMap['inner'] as num?)?.toDouble() ?? 0,
      outer: (packetMap['outer'] as num?)?.toDouble() ?? 0,
      toe: (packetMap['toe'] as num?)?.toDouble() ?? 0,
      impact: (packetMap['impact'] as num?)?.toDouble() ?? (packetMap['piezo'] as num?)?.toDouble() ?? 0,
      pitch: (packetMap['pitch'] as num?)?.toDouble() ?? 0,
      roll: (packetMap['roll'] as num?)?.toDouble() ?? 0,
      accZ: (packetMap['accZ'] as num?)?.toDouble() ?? 9.8,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    final metrics = engine.process(packet);
    _pushMetrics(metrics);
    _enqueueSample(packet, TelemetrySource.ws, TelemetryMode.live);
  }

  void _pushMetrics(ProcessedBiomechanicsMetrics metrics) {
    final nextTrail = [...state.copTrailSafe(_copTrailLength), metrics.cop];
    if (nextTrail.length > _copTrailLength) {
      nextTrail.removeAt(0);
    }
    state = state.copyWith(metrics: metrics, copTrail: nextTrail);
  }

  void _enqueueSample(RawSensorPacket packet, TelemetrySource source, TelemetryMode mode) {
    _pendingSamples.add(TelemetrySample(
      timestampMs: packet.timestampMs,
      source: source,
      sessionId: settings.sessionId,
      trialId: settings.trialId,
      diseaseLabel: _diseaseLabelFor(mode),
      mode: mode,
      heel: packet.heel,
      inner: packet.inner,
      outer: packet.outer,
      toe: packet.toe,
      impact: packet.impact,
      pitch: packet.pitch,
      roll: packet.roll,
      accZ: packet.accZ,
    ));
  }

  DiseaseLabel _diseaseLabelFor(TelemetryMode mode) {
    if (mode != TelemetryMode.simulation) return DiseaseLabel.unknown;
    for (final label in DiseaseLabel.values) {
      if (label.label == state.simMode.label) return label;
    }
    return DiseaseLabel.unknown;
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
      state = state.copyWith(datasetStatus: 'Dataset write failed - will retry');
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
    _simulationTimer?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}

extension on TelemetryState {
  List<CopPoint> copTrailSafe(int maxLength) {
    if (copTrail.length <= maxLength) return List.of(copTrail);
    return copTrail.sublist(copTrail.length - maxLength);
  }
}
