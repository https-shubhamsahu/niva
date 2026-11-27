import '../engine/simulation_engine.dart';
import '../models/biomechanics_metrics.dart';

/// No packet for longer than this while connected means the readings on
/// screen are stale (the firmware streams at 20 Hz, so 2 s is 40 frames).
const telemetryStaleAfter = Duration(seconds: 2);

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

  /// Connected, but no packet for over [telemetryStaleAfter].
  final bool isStale;
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
    this.isStale = false,
    required this.metrics,
    this.copTrail = const [],
    this.datasetCount = 0,
    this.datasetStatus = 'Dataset idle',
  });

  factory TelemetryState.initial() =>
      TelemetryState(metrics: ProcessedBiomechanicsMetrics.idle());

  /// True whenever fresh packets are arriving OR the on-device simulator is
  /// running - this is the single flag most cards use to decide whether to
  /// show real numbers or a dimmed placeholder. A connected but silent link
  /// ([isStale]) is not live.
  bool get isLive => (isConnected && !isStale) || isSimulating;

  /// One status line for every screen, so simulated and stale data are
  /// always labelled as such.
  String get linkLabel {
    if (isSimulating) return 'SIMULATED DATA';
    if (isConnected && !isStale) return 'LIVE TELEMETRY';
    if (isConnected) return 'STALE: NO DATA FOR OVER 2 S';
    if (isConnecting) return 'CONNECTING';
    return 'DISCONNECTED';
  }

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
    bool? isStale,
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
      connectionError: clearConnectionError
          ? null
          : (connectionError ?? this.connectionError),
      activeUrl: activeUrl ?? this.activeUrl,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isStale: isStale ?? this.isStale,
      metrics: metrics ?? this.metrics,
      copTrail: copTrail ?? this.copTrail,
      datasetCount: datasetCount ?? this.datasetCount,
      datasetStatus: datasetStatus ?? this.datasetStatus,
    );
  }
}
