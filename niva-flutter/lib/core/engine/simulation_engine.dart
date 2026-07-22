import 'dart:math' as math;

import '../models/biomechanics_metrics.dart';

/// The six demo/training gait modes. Ported from `simulationEngine.ts`.
enum GaitMode { normal, parkinson, stroke, neuropathy, footDrop, ataxia }

extension GaitModeLabel on GaitMode {
  String get label {
    switch (this) {
      case GaitMode.normal:
        return 'Normal';
      case GaitMode.parkinson:
        return 'Parkinson';
      case GaitMode.stroke:
        return 'Stroke';
      case GaitMode.neuropathy:
        return 'Neuropathy';
      case GaitMode.footDrop:
        return 'Foot Drop';
      case GaitMode.ataxia:
        return 'Ataxia';
    }
  }

  /// One-line, doctor-readable rationale for why this mode looks the way it
  /// does - keeps the "explainable, not black-box" promise even in demo mode.
  String get explanation {
    switch (this) {
      case GaitMode.parkinson:
        return 'Low heel impact combined with increased stance duration suggests Parkinsonian shuffling gait.';
      case GaitMode.stroke:
        return 'Medial-lateral pressure asymmetry detected indicating hemiplegic gait imbalance.';
      case GaitMode.neuropathy:
        return 'Sustained forefoot pressure may increase risk of diabetic plantar ulceration.';
      case GaitMode.footDrop:
        return 'Absent heel strike and forefoot slap characteristic of dorsiflexion weakness.';
      case GaitMode.ataxia:
        return 'Unstable gait and high IMU roll variance indicative of cerebellar ataxia.';
      case GaitMode.normal:
        return 'Balanced pressure progression and stable temporal parameters detected.';
    }
  }
}

/// One synthetic sensor frame for a given [GaitMode] at simulated time
/// [timeMs]. Used both for the on-screen demo mode and for generating
/// labeled training data without hardware in the loop.
class GaitFrame {
  final double heel;
  final double mt1;
  final double mt5;
  final double toe;
  final double impact;
  final double stanceRatio;
  final double imuRollVariance;
  final String explanation;

  const GaitFrame({
    required this.heel,
    required this.mt1,
    required this.mt5,
    required this.toe,
    required this.impact,
    required this.stanceRatio,
    required this.imuRollVariance,
    required this.explanation,
  });
}

class SimulationEngine {
  final math.Random _random;

  SimulationEngine({math.Random? random}) : _random = random ?? math.Random();

  double _clamp01to100(double value) => value.clamp(0, 100).toDouble();

  double _applyNoise(double value, [double amp = 3]) {
    return value + (_random.nextDouble() - 0.5) * amp;
  }

  /// Generates one synthetic frame using a sine-wave walking cycle so the
  /// simulated pressure trace still looks like a real footstep sequence
  /// rather than random noise.
  GaitFrame generateFrame(GaitMode mode, int timeMs) {
    final cycleTime = mode == GaitMode.parkinson
        ? 1200
        : mode == GaitMode.ataxia
            ? 1300
            : mode == GaitMode.footDrop
                ? 1100
                : 1000;
    final phase = (timeMs % cycleTime) / cycleTime;

    double baseHeel = 80;
    double baseMt1 = 60;
    double baseMt5 = 55;
    double baseToe = 70;
    double impact = 80;
    double stanceRatio = 0.60;
    double imuRollVariance = 0.5;

    switch (mode) {
      case GaitMode.parkinson:
        baseHeel = 30;
        baseMt1 = 50;
        baseMt5 = 48;
        baseToe = 40;
        impact = 20;
        stanceRatio = 0.75;
        imuRollVariance = 0.3;
        break;
      case GaitMode.stroke:
        baseHeel = 60;
        baseMt1 = 90;
        baseMt5 = 20;
        baseToe = 75;
        impact = 60;
        stanceRatio = 0.65;
        imuRollVariance = 1.2;
        break;
      case GaitMode.neuropathy:
        baseHeel = 35;
        baseMt1 = 95;
        baseMt5 = 85;
        baseToe = 50;
        impact = 50;
        stanceRatio = 0.60;
        imuRollVariance = 0.6;
        break;
      case GaitMode.footDrop:
        baseHeel = 5;
        baseMt1 = 70;
        baseMt5 = 60;
        baseToe = 80;
        impact = 90;
        stanceRatio = 0.55;
        imuRollVariance = 0.8;
        break;
      case GaitMode.ataxia:
        baseHeel = 40 + _random.nextDouble() * 40;
        baseMt1 = 30 + _random.nextDouble() * 60;
        baseMt5 = 20 + _random.nextDouble() * 50;
        baseToe = 30 + _random.nextDouble() * 50;
        impact = 40 + _random.nextDouble() * 50;
        stanceRatio = 0.50 + _random.nextDouble() * 0.30;
        imuRollVariance = 2.0 + _random.nextDouble() * 3.0;
        break;
      case GaitMode.normal:
        break;
    }

    final heelScale = mode == GaitMode.footDrop ? 0.2 : math.max(0.0, math.sin(phase * math.pi));
    final toeScale = math.max(0.0, math.sin((phase - 0.5) * math.pi));
    final mtScale = mode == GaitMode.footDrop ? heelScale : toeScale;

    final heel = _applyNoise(baseHeel * (0.3 + 0.7 * heelScale));
    final mt1 = _applyNoise(baseMt1 * (0.3 + 0.7 * mtScale));
    final mt5 = _applyNoise(baseMt5 * (0.3 + 0.7 * mtScale));
    final toe = _applyNoise(baseToe * (0.3 + 0.7 * toeScale));

    return GaitFrame(
      heel: _clamp01to100(heel),
      mt1: _clamp01to100(mt1),
      mt5: _clamp01to100(mt5),
      toe: _clamp01to100(toe),
      impact: _applyNoise(impact, 5),
      stanceRatio: _applyNoise(stanceRatio, 0.02),
      imuRollVariance: _applyNoise(imuRollVariance, 0.1),
      explanation: mode.explanation,
    );
  }

  /// Converts a [GaitFrame] into the same [RawSensorPacket] shape live
  /// hardware produces, so the exact same [BiomechanicsEngine] can process
  /// both live and simulated data with zero branching in the UI layer.
  RawSensorPacket frameToPacket(GaitFrame frame, int timestampMs) {
    return RawSensorPacket(
      heel: frame.heel,
      inner: frame.mt1,
      outer: frame.mt5,
      toe: frame.toe,
      impact: frame.impact,
      // Randomized (not just scaled) each frame, matching
      // simulationEngine.ts's MainDashboard driver - this is what gives
      // Ataxia mode its signature erratic sway; a deterministic formula
      // flattens that out.
      pitch: (_random.nextDouble() - 0.5) * frame.imuRollVariance * 10,
      roll: (_random.nextDouble() - 0.5) * frame.imuRollVariance * 20,
      accZ: 9.8,
      timestampMs: timestampMs,
    );
  }
}
