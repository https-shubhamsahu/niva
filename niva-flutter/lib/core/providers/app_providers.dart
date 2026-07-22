import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/esp32_socket_service.dart';
import '../data/research_upload_service.dart';
import '../data/settings_repository.dart';
import '../data/telemetry_repository.dart';
import '../engine/biomechanics_engine.dart';
import '../engine/simulation_engine.dart';
import 'telemetry_controller.dart';
import 'telemetry_state.dart';

/// These two are asynchronously initialized in `main.dart` (Hive/
/// SharedPreferences both need an `await` before first use) and injected
/// via `ProviderScope(overrides: [...])`. Referencing them before that
/// override is wired up is a programming error, hence the throw.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('settingsRepositoryProvider must be overridden in main.dart');
});

final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  throw UnimplementedError('telemetryRepositoryProvider must be overridden in main.dart');
});

final esp32SocketServiceProvider = Provider<Esp32SocketService>((ref) {
  final service = Esp32SocketService(ref.watch(settingsRepositoryProvider));
  ref.onDispose(service.dispose);
  return service;
});

final simulationEngineProvider = Provider<SimulationEngine>((ref) => SimulationEngine());

final biomechanicsEngineProvider = Provider<BiomechanicsEngine>((ref) => BiomechanicsEngine());

final researchUploadServiceProvider = Provider<ResearchUploadService>((ref) {
  return ResearchUploadService(ref.watch(settingsRepositoryProvider));
});

final telemetryControllerProvider = StateNotifierProvider<TelemetryController, TelemetryState>((ref) {
  final controller = TelemetryController(
    socket: ref.watch(esp32SocketServiceProvider),
    simulation: ref.watch(simulationEngineProvider),
    engine: ref.watch(biomechanicsEngineProvider),
    repository: ref.watch(telemetryRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
