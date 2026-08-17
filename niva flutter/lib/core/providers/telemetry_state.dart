import '../engine/simulation_engine.dart';
import '../models/biomechanics_metrics.dart';

/// UI-facing snapshot combining live connection status, simulation mode and
/// the latest derived biomechanics frame. One StateNotifier (see
/// `telemetry_controller.dart`) owns all of this so every screen reads from
/// a single source of truth instead of re-deriving it from raw packets.
class TelemetryState {
  final bool isSimulating;
  final GaitMode simMode;
  final bool isDemoMode;
  final bool isConnected;
  final bool isConnecting;
  final String? connectionError;
  final String activeUrl;
  final DateTime? lastMessageAt;
  final ProcessedBiomechanicsMetrics metrics;
  final List<CopPoint> copTrail;
  final int datasetCount;
  final String datasetStatus;

  const TelemetryState({
    this.isSimulating = false,
    this.simMode = GaitMode.normal,
    this.isDemoMode = false,
    this.isConnected = false,
    this.isConnecting = false,
    this.connectionError,
    this.activeUrl = '',
    this.lastMessageAt,
    required this.metrics,
    this.copTrail = const [],
    this.datasetCount = 0,
    this.datasetStatus = 'Dataset idle',
  });

  factory TelemetryState.initial() => TelemetryState(metrics: ProcessedBiomechanicsMetrics.idle());

  /// True whenever there is a live link OR the on-device simulator is
  /// running - this is the single flag most cards use to decide whether to
  /// show real numbers or a dimmed placeholder.
  bool get isLive => isConnected || isSimulating;

  TelemetryState copyWith({
    bool? isSimulating,
    GaitMode? simMode,
    bool? isDemoMode,
    bool? isConnected,
    bool? isConnecting,
    String? connectionError,
    bool clearConnectionError = false,
    String? activeUrl,
    DateTime? lastMessageAt,
    ProcessedBiomechanicsMetrics? metrics,
    List<CopPoint>? copTrail,
    int? datasetCount,
    String? datasetStatus,
  }) {
    return TelemetryState(
      isSimulating: isSimulating ?? this.isSimulating,
      simMode: simMode ?? this.simMode,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      connectionError: clearConnectionError ? null : (connectionError ?? this.connectionError),
      activeUrl: activeUrl ?? this.activeUrl,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      metrics: metrics ?? this.metrics,
      copTrail: copTrail ?? this.copTrail,
      datasetCount: datasetCount ?? this.datasetCount,
      datasetStatus: datasetStatus ?? this.datasetStatus,
    );
  }
}
