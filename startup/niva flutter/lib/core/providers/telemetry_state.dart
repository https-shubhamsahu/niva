import '../models/gait_metrics.dart';

/// UI-facing snapshot combining live connection status and the latest
/// derived timing frame. One StateNotifier (see `telemetry_controller.dart`)
/// owns all of this so every screen reads from a single source of truth
/// instead of re-deriving it from raw packets.
class TelemetryState {
  final bool isConnected;
  final bool isConnecting;
  final String? connectionError;
  final String activeUrl;
  final DateTime? lastMessageAt;
  final String measurementValidity;
  final bool imuClipped;
  final GaitMetrics metrics;
  final int datasetCount;
  final String datasetStatus;

  const TelemetryState({
    this.isConnected = false,
    this.isConnecting = false,
    this.connectionError,
    this.activeUrl = '',
    this.lastMessageAt,
    this.measurementValidity = 'unknown',
    this.imuClipped = false,
    required this.metrics,
    this.datasetCount = 0,
    this.datasetStatus = 'Dataset idle',
  });

  factory TelemetryState.initial() => TelemetryState(metrics: GaitMetrics.idle());

  bool get isLive => isConnected;
  bool get isMeasurementValid => measurementValidity == 'valid';

  TelemetryState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? connectionError,
    bool clearConnectionError = false,
    String? activeUrl,
    DateTime? lastMessageAt,
    String? measurementValidity,
    bool? imuClipped,
    GaitMetrics? metrics,
    int? datasetCount,
    String? datasetStatus,
  }) {
    return TelemetryState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      connectionError: clearConnectionError
          ? null
          : (connectionError ?? this.connectionError),
      activeUrl: activeUrl ?? this.activeUrl,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      measurementValidity: measurementValidity ?? this.measurementValidity,
      imuClipped: imuClipped ?? this.imuClipped,
      metrics: metrics ?? this.metrics,
      datasetCount: datasetCount ?? this.datasetCount,
      datasetStatus: datasetStatus ?? this.datasetStatus,
    );
  }
}
