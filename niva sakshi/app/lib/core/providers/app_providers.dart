import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/esp32_socket_service.dart';
import '../connectivity/esp32_ble_service.dart';
import '../data/research_upload_service.dart';
import '../data/settings_repository.dart';
import '../data/telemetry_repository.dart';
import '../data/trial_store.dart';
import '../engine/gait_timing_engine.dart';
import '../fitness/beam_event.dart';
import '../fitness/fitness_trial.dart';
import '../models/gait_metrics.dart';
import '../time/clock.dart';
import 'telemetry_controller.dart';
import 'telemetry_state.dart';

/// These two are asynchronously initialized in `main.dart` (Hive/
/// SharedPreferences both need an `await` before first use) and injected
/// via `ProviderScope(overrides: [...])`. Referencing them before that
/// override is wired up is a programming error, hence the throw.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError(
      'settingsRepositoryProvider must be overridden in main.dart');
});

final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  throw UnimplementedError(
      'telemetryRepositoryProvider must be overridden in main.dart');
});

final esp32SocketServiceProvider = Provider<Esp32SocketService>((ref) {
  final service = Esp32SocketService(ref.watch(settingsRepositoryProvider));
  ref.onDispose(service.dispose);
  return service;
});

final esp32BleServiceProvider = Provider<Esp32BleService>((ref) {
  final service = Esp32BleService();
  ref.onDispose(service.dispose);
  return service;
});

final trialStoreProvider = Provider<TrialStore>((ref) {
  throw UnimplementedError(
      'trialStoreProvider must be overridden in main.dart');
});

/// One monotonic clock shared by the telemetry link and the fitness tests,
/// so insole events and the test clock are placed on the same timeline.
final monotonicClockProvider =
    Provider<MonotonicClock>((ref) => MonotonicClock());

final gaitTimingEngineProvider =
    Provider<GaitTimingEngine>((ref) => GaitTimingEngine());

final researchUploadServiceProvider = Provider<ResearchUploadService>((ref) {
  return ResearchUploadService(ref.watch(settingsRepositoryProvider));
});

final telemetryControllerProvider =
    StateNotifierProvider<TelemetryController, TelemetryState>((ref) {
  final controller = TelemetryController(
    socket: ref.watch(esp32SocketServiceProvider),
    ble: ref.watch(esp32BleServiceProvider),
    engine: ref.watch(gaitTimingEngineProvider),
    repository: ref.watch(telemetryRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(monotonicClockProvider),
  );
  // StateNotifierProvider owns and disposes its notifier automatically.
  return controller;
});

/// The insole as the Tests screens see it. Separate from the telemetry
/// state so the test screens can be exercised with a fake insole.
final insoleStatusProvider = Provider<InsoleStatus>((ref) {
  final state = ref.watch(telemetryControllerProvider);
  // Demo readings never reach an assessment: the tests see no insole.
  return InsoleStatus(
    connected: state.isConnected && !state.isDemo,
    valid: state.isMeasurementValid,
    reportsEvents: state.metrics.firmwareReportsEvents,
    contactMask: state.metrics.contactMask,
  );
});

/// Step-off events from the Sakshi beam. No beam transport exists yet (finale
/// build), so this is an empty stream until the beam hub is connected.
final beamEventsProvider = Provider<Stream<TimedBeamEvent>>((ref) {
  return const Stream<TimedBeamEvent>.empty();
});

final insoleEventsProvider = Provider<Stream<TimedContactEvent>>((ref) {
  return ref.watch(telemetryControllerProvider.notifier).contactEvents;
});
