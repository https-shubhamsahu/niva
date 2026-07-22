/// Core data types shared by the biomechanics engine and the UI layer.
///
/// This is a direct port of `src/utils/biomechanicsEngine.ts` from the
/// original React app - see BETTERMENTS.md for what changed along the way.
library;

enum ContactState { stance, swing }

enum GaitPhase { heelStrike, midStance, toeOff, swing }

enum StabilityBand { stable, moderate, unstable }

extension GaitPhaseLabel on GaitPhase {
  /// Human readable label, e.g. "Heel Strike".
  String get label {
    switch (this) {
      case GaitPhase.heelStrike:
        return 'Heel Strike';
      case GaitPhase.midStance:
        return 'Mid Stance';
      case GaitPhase.toeOff:
        return 'Toe Off';
      case GaitPhase.swing:
        return 'Swing';
    }
  }
}

extension StabilityBandLabel on StabilityBand {
  String get label {
    switch (this) {
      case StabilityBand.stable:
        return 'Stable';
      case StabilityBand.moderate:
        return 'Moderate';
      case StabilityBand.unstable:
        return 'Unstable';
    }
  }
}

/// A single raw packet as it arrives from the ESP32 (WebSocket JSON or the
/// on-device simulator). Pressure fields are already 0-100 or raw ADC counts
/// depending on source; the engine normalizes either.
class RawSensorPacket {
  final double heel;
  final double inner;
  final double outer;
  final double toe;
  final double impact;
  final double pitch;
  final double roll;
  final double accZ;
  final int timestampMs;

  const RawSensorPacket({
    required this.heel,
    required this.inner,
    required this.outer,
    required this.toe,
    required this.impact,
    required this.pitch,
    required this.roll,
    required this.accZ,
    required this.timestampMs,
  });
}

class FootPressure {
  final double heel;
  final double inner;
  final double outer;
  final double toe;

  const FootPressure({
    this.heel = 0,
    this.inner = 0,
    this.outer = 0,
    this.toe = 0,
  });

  double get total => heel + inner + outer + toe;
}

class CopPoint {
  final double x;
  final double y;

  const CopPoint({this.x = 0.5, this.y = 0});
}

/// Output of [BiomechanicsEngine.process] for a single packet - one frame of
/// derived, explainable metrics that the dashboard renders directly.
class ProcessedBiomechanicsMetrics {
  final int timestampMs;
  final bool isCalibrated;
  final FootPressure filteredPressure;
  final FootPressure normalizedPressure;
  final double totalPressure;
  final ContactState contactState;
  final bool heelStrikeDetected;
  final GaitPhase gaitPhase;
  final CopPoint cop;
  final double mlpi;
  final int stepCount;
  final double cadenceSpm;
  final int stancePct;
  final int swingPct;
  final double stabilityMagnitude;
  final StabilityBand stabilityBand;
  final int stabilityScore;
  final double impactLevel;
  final double ischemicIntegralPct;
  final List<String> anomalyFlags;
  final int bufferLength;

  const ProcessedBiomechanicsMetrics({
    required this.timestampMs,
    required this.isCalibrated,
    required this.filteredPressure,
    required this.normalizedPressure,
    required this.totalPressure,
    required this.contactState,
    required this.heelStrikeDetected,
    required this.gaitPhase,
    required this.cop,
    required this.mlpi,
    required this.stepCount,
    required this.cadenceSpm,
    required this.stancePct,
    required this.swingPct,
    required this.stabilityMagnitude,
    required this.stabilityBand,
    required this.stabilityScore,
    required this.impactLevel,
    required this.ischemicIntegralPct,
    required this.anomalyFlags,
    required this.bufferLength,
  });

  /// A safe "nothing connected yet" placeholder so widgets never have to
  /// null-check the initial frame.
  factory ProcessedBiomechanicsMetrics.idle() {
    return ProcessedBiomechanicsMetrics(
      timestampMs: 0,
      isCalibrated: false,
      filteredPressure: const FootPressure(),
      normalizedPressure: const FootPressure(),
      totalPressure: 0,
      contactState: ContactState.swing,
      heelStrikeDetected: false,
      gaitPhase: GaitPhase.swing,
      cop: const CopPoint(),
      mlpi: 0,
      stepCount: 0,
      cadenceSpm: 0,
      stancePct: 60,
      swingPct: 40,
      stabilityMagnitude: 0,
      stabilityBand: StabilityBand.stable,
      stabilityScore: 92,
      impactLevel: 0,
      ischemicIntegralPct: 0,
      anomalyFlags: const [],
      bufferLength: 0,
    );
  }
}
