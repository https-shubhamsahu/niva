import 'dart:math' as math;

import '../models/biomechanics_metrics.dart';

/// Deterministic, rule-based gait analysis engine.
///
/// This is a line-for-line behavioral port of `biomechanicsEngine.ts` from
/// the original web app. Every threshold below is intentionally kept
/// identical so a device that was "calibrated" against the web dashboard
/// behaves the same way here. If you tune these, tune both apps together.
///
/// Deliberately dependency-free (pure Dart, no Flutter imports) so it can be
/// unit tested and, later, moved into an Isolate without dragging UI code
/// along with it.
class BiomechanicsEngineOptions {
  final double alpha;
  final double contactThreshold;
  final double impactThreshold;
  final double heelThreshold;
  final double maxImpact;
  final int bufferSize;
  final double staticSwayThreshold;
  final double pressureDeadband;
  final double angleDeadband;
  final int calibrationSamples;
  final int calibrationMaxSamples;
  final double calibrationRange;
  final double calibrationTotalCeiling;
  final double calibrationMotionCeiling;
  final double calibrationImpactCeiling;

  const BiomechanicsEngineOptions({
    this.alpha = 0.1,
    this.contactThreshold = 45,
    this.impactThreshold = 200,
    this.heelThreshold = 80,
    this.maxImpact = 800,
    this.bufferSize = 50,
    this.staticSwayThreshold = 6,
    this.pressureDeadband = 2.5,
    this.angleDeadband = 0.8,
    this.calibrationSamples = 30,
    this.calibrationMaxSamples = 60,
    this.calibrationRange = 8,
    this.calibrationTotalCeiling = 55,
    this.calibrationMotionCeiling = 7,
    this.calibrationImpactCeiling = 60,
  });
}

class _SensorCoord {
  final double x;
  final double y;
  const _SensorCoord(this.x, this.y);
}

const _sensorCoords = {
  'heel': _SensorCoord(0, 0),
  'inner': _SensorCoord(0.3, 0.5),
  'outer': _SensorCoord(0.7, 0.5),
  'toe': _SensorCoord(0.5, 1),
};

double _clamp(double value, double min, double max) => math.min(max, math.max(min, value));

double _normalizeRawPressureInput(double value) {
  if (value.isNaN || value.isInfinite) return 0;
  final clamped = math.max(0.0, value);
  if (clamped > 100) {
    return _clamp((clamped / 4095) * 100, 0, 100);
  }
  return _clamp(clamped, 0, 100);
}

double _ema(double current, double previous, double alpha) {
  return alpha * current + (1 - alpha) * previous;
}

double _deadband(double value, double threshold) {
  return value.abs() < threshold ? 0 : value;
}

class _Accum {
  double heel = 0;
  double inner = 0;
  double outer = 0;
  double toe = 0;
  double total = 0;
  double impact = 0;
  double pitch = 0;
  double roll = 0;
}

class BiomechanicsEngine {
  final BiomechanicsEngineOptions options;

  BiomechanicsEngine({this.options = const BiomechanicsEngineOptions()});

  FootPressure _filtered = const FootPressure();
  FootPressure _baselinePressure = const FootPressure();
  double _baselinePitch = 0;
  double _baselineRoll = 0;

  bool _isCalibrated = false;
  int _calibrationCount = 0;
  final _Accum _calibrationAccum = _Accum();
  double _calibrationTotalMin = double.infinity;
  double _calibrationTotalMax = 0;
  double _calibrationMotionMax = 0;

  bool _lastContact = false;
  double _lastHeel = 0;
  int? _lastHeelStrikeAtMs;
  int _stepCount = 0;
  double _cadenceSpm = 0;
  int _stanceStartMs = 0;
  int _swingStartMs = 0;
  int _lastStanceMs = 600;
  int _lastSwingMs = 400;
  int _heelDominantStreak = 0;
  double _ischemicIntegralPct = 0;

  final List<ProcessedBiomechanicsMetrics> _history = [];

  bool get isCalibrated => _isCalibrated;
  List<ProcessedBiomechanicsMetrics> get history => List.unmodifiable(_history);

  void reset() {
    _filtered = const FootPressure();
    _baselinePressure = const FootPressure();
    _baselinePitch = 0;
    _baselineRoll = 0;
    _isCalibrated = false;
    _calibrationCount = 0;
    _calibrationAccum.heel = 0;
    _calibrationAccum.inner = 0;
    _calibrationAccum.outer = 0;
    _calibrationAccum.toe = 0;
    _calibrationAccum.total = 0;
    _calibrationAccum.impact = 0;
    _calibrationAccum.pitch = 0;
    _calibrationAccum.roll = 0;
    _calibrationTotalMin = double.infinity;
    _calibrationTotalMax = 0;
    _calibrationMotionMax = 0;
    _lastContact = false;
    _lastHeel = 0;
    _lastHeelStrikeAtMs = null;
    _stepCount = 0;
    _cadenceSpm = 0;
    _stanceStartMs = 0;
    _swingStartMs = 0;
    _lastStanceMs = 600;
    _lastSwingMs = 400;
    _heelDominantStreak = 0;
    _ischemicIntegralPct = 0;
    _history.clear();
  }

  GaitPhase _detectPhase(FootPressure filtered, double totalPressure) {
    if (totalPressure < 20) return GaitPhase.swing;
    if (filtered.heel > 80 && filtered.toe < 40) return GaitPhase.heelStrike;
    if (filtered.heel > 50 && filtered.inner > 50 && filtered.outer > 50) {
      return GaitPhase.midStance;
    }
    if (filtered.toe > 80 && filtered.heel < 30) return GaitPhase.toeOff;
    return totalPressure >= options.contactThreshold ? GaitPhase.midStance : GaitPhase.swing;
  }

  CopPoint _computeCop(FootPressure filtered, double totalPressure) {
    if (totalPressure <= 0) return const CopPoint(x: 0.5, y: 0);

    final copX = (filtered.heel * _sensorCoords['heel']!.x +
            filtered.inner * _sensorCoords['inner']!.x +
            filtered.outer * _sensorCoords['outer']!.x +
            filtered.toe * _sensorCoords['toe']!.x) /
        totalPressure;

    final copY = (filtered.heel * _sensorCoords['heel']!.y +
            filtered.inner * _sensorCoords['inner']!.y +
            filtered.outer * _sensorCoords['outer']!.y +
            filtered.toe * _sensorCoords['toe']!.y) /
        totalPressure;

    return CopPoint(x: _clamp(copX, 0, 1), y: _clamp(copY, 0, 1));
  }

  /// Feed one raw packet through calibration, filtering, phase/COP detection,
  /// gait timing, stability scoring and anomaly rules. Returns the derived
  /// frame and also appends it to the rolling [history] buffer.
  ProcessedBiomechanicsMetrics process(RawSensorPacket packet) {
    final rawInput = FootPressure(
      heel: _normalizeRawPressureInput(packet.heel),
      inner: _normalizeRawPressureInput(packet.inner),
      outer: _normalizeRawPressureInput(packet.outer),
      toe: _normalizeRawPressureInput(packet.toe),
    );

    if (!_isCalibrated) {
      final rawTotal = rawInput.heel + rawInput.inner + rawInput.outer + rawInput.toe;
      final rawMotion = math.sqrt(packet.pitch * packet.pitch + packet.roll * packet.roll);

      _calibrationCount += 1;
      _calibrationAccum.heel += rawInput.heel;
      _calibrationAccum.inner += rawInput.inner;
      _calibrationAccum.outer += rawInput.outer;
      _calibrationAccum.toe += rawInput.toe;
      _calibrationAccum.total += rawTotal;
      _calibrationAccum.impact += packet.impact;
      _calibrationAccum.pitch += packet.pitch;
      _calibrationAccum.roll += packet.roll;
      _calibrationTotalMin = math.min(_calibrationTotalMin, rawTotal);
      _calibrationTotalMax = math.max(_calibrationTotalMax, rawTotal);
      _calibrationMotionMax = math.max(_calibrationMotionMax, rawMotion);

      if (_calibrationCount >= options.calibrationSamples) {
        final meanTotal = _calibrationAccum.total / _calibrationCount;
        final meanImpact = _calibrationAccum.impact / _calibrationCount;
        final stableRange = _calibrationTotalMax - _calibrationTotalMin;

        final noLoadStable = stableRange <= options.calibrationRange &&
            meanTotal <= options.calibrationTotalCeiling &&
            _calibrationMotionMax <= options.calibrationMotionCeiling &&
            meanImpact <= options.calibrationImpactCeiling;

        if (noLoadStable) {
          _baselinePressure = FootPressure(
            heel: _calibrationAccum.heel / _calibrationCount,
            inner: _calibrationAccum.inner / _calibrationCount,
            outer: _calibrationAccum.outer / _calibrationCount,
            toe: _calibrationAccum.toe / _calibrationCount,
          );
          _baselinePitch = _calibrationAccum.pitch / _calibrationCount;
          _baselineRoll = _calibrationAccum.roll / _calibrationCount;
          _isCalibrated = true;
        } else if (_calibrationCount >= options.calibrationMaxSamples) {
          // Fallback: keep processing without baseline subtraction if a
          // clean no-load window never appears (e.g. device strapped on
          // and immediately walked on).
          _isCalibrated = true;
        }
      }
    }

    final input = _isCalibrated
        ? FootPressure(
            heel: _deadband(math.max(0.0, rawInput.heel - _baselinePressure.heel), options.pressureDeadband),
            inner: _deadband(math.max(0.0, rawInput.inner - _baselinePressure.inner), options.pressureDeadband),
            outer: _deadband(math.max(0.0, rawInput.outer - _baselinePressure.outer), options.pressureDeadband),
            toe: _deadband(math.max(0.0, rawInput.toe - _baselinePressure.toe), options.pressureDeadband),
          )
        : const FootPressure();

    final correctedPitch = _deadband(packet.pitch - _baselinePitch, options.angleDeadband);
    final correctedRoll = _deadband(packet.roll - _baselineRoll, options.angleDeadband);

    _filtered = FootPressure(
      heel: _ema(input.heel, _filtered.heel, options.alpha),
      inner: _ema(input.inner, _filtered.inner, options.alpha),
      outer: _ema(input.outer, _filtered.outer, options.alpha),
      toe: _ema(input.toe, _filtered.toe, options.alpha),
    );

    final totalPressure = _filtered.heel + _filtered.inner + _filtered.outer + _filtered.toe;

    final normalizedPressure = totalPressure > 0
        ? FootPressure(
            heel: _filtered.heel / totalPressure,
            inner: _filtered.inner / totalPressure,
            outer: _filtered.outer / totalPressure,
            toe: _filtered.toe / totalPressure,
          )
        : const FootPressure();

    final contactState = totalPressure > options.contactThreshold ? ContactState.stance : ContactState.swing;

    // Heel strike is an impact transient, so it's gated on the raw
    // (deadbanded, unsmoothed) reading rather than `_filtered.heel` - the EMA
    // filter exists for slow-changing gait-phase/COP context and would delay
    // a real spike past the point where `_lastContact` has already flipped,
    // making this condition unreachable.
    final heelRise = input.heel - _lastHeel;
    final heelStrikeDetected = packet.impact > options.impactThreshold &&
        input.heel > options.heelThreshold &&
        heelRise > 8 &&
        !_lastContact;

    if (heelStrikeDetected) {
      _stepCount += 1;
      if (_lastHeelStrikeAtMs != null) {
        final stepIntervalSec = (packet.timestampMs - _lastHeelStrikeAtMs!) / 1000;
        if (stepIntervalSec > 0.2 && stepIntervalSec < 3) {
          _cadenceSpm = 60 / stepIntervalSec;
        }
      }
      _lastHeelStrikeAtMs = packet.timestampMs;
    }

    if (contactState == ContactState.stance && !_lastContact) {
      if (_swingStartMs > 0) _lastSwingMs = packet.timestampMs - _swingStartMs;
      _stanceStartMs = packet.timestampMs;
    }

    if (contactState == ContactState.swing && _lastContact) {
      if (_stanceStartMs > 0) _lastStanceMs = packet.timestampMs - _stanceStartMs;
      _swingStartMs = packet.timestampMs;
    }

    _lastContact = contactState == ContactState.stance;

    final cycleMs = _lastStanceMs + _lastSwingMs;
    final stancePct = cycleMs > 0 ? ((_lastStanceMs / cycleMs) * 100).round() : 60;
    final swingPct = 100 - stancePct;

    final gaitPhase = _detectPhase(_filtered, totalPressure);
    final cop = _computeCop(_filtered, totalPressure);

    final stabilityMagnitude = math.sqrt(correctedPitch * correctedPitch + correctedRoll * correctedRoll);
    final stabilityBand = stabilityMagnitude < 3
        ? StabilityBand.stable
        : stabilityMagnitude < 6
            ? StabilityBand.moderate
            : StabilityBand.unstable;

    final impactLevel = _clamp(packet.impact / options.maxImpact, 0, 1);
    final stabilityScore = _clamp(100 - stabilityMagnitude * 9 - impactLevel * 30, 0, 100).round();
    final mlpi = (_filtered.inner - _filtered.outer).abs();

    if (normalizedPressure.heel > 0.7) {
      _heelDominantStreak += 1;
    } else {
      _heelDominantStreak = 0;
    }

    final staticMode = correctedRoll.abs() < options.staticSwayThreshold && correctedPitch.abs() < options.staticSwayThreshold;
    final highMedialLateral = math.max(_filtered.inner, _filtered.outer) > 50;

    if (highMedialLateral && staticMode) {
      _ischemicIntegralPct = _clamp(_ischemicIntegralPct + 0.35, 0, 100);
    } else {
      _ischemicIntegralPct = _clamp(_ischemicIntegralPct - 0.08, 0, 100);
    }

    final anomalyFlags = <String>[];

    if (correctedRoll.abs() > 8 && _filtered.outer > _filtered.inner) {
      anomalyFlags.add('Ankle instability / supination risk');
    }

    if (_heelDominantStreak >= 5) {
      anomalyFlags.add('Heel-dominant gait trend');
    }

    if (stabilityBand == StabilityBand.unstable) {
      anomalyFlags.add('High sway instability');
    }

    if (_ischemicIntegralPct > 50) {
      anomalyFlags.add('Ischemic pressure risk');
    }

    _lastHeel = input.heel;

    final metrics = ProcessedBiomechanicsMetrics(
      timestampMs: packet.timestampMs,
      isCalibrated: _isCalibrated,
      filteredPressure: _filtered,
      normalizedPressure: normalizedPressure,
      totalPressure: totalPressure,
      contactState: contactState,
      heelStrikeDetected: heelStrikeDetected,
      gaitPhase: gaitPhase,
      cop: cop,
      mlpi: mlpi,
      stepCount: _stepCount,
      cadenceSpm: _cadenceSpm,
      stancePct: stancePct,
      swingPct: swingPct,
      stabilityMagnitude: stabilityMagnitude,
      stabilityBand: stabilityBand,
      stabilityScore: stabilityScore,
      impactLevel: impactLevel,
      ischemicIntegralPct: _ischemicIntegralPct,
      anomalyFlags: anomalyFlags,
      bufferLength: _history.length + 1,
    );

    _history.add(metrics);
    if (_history.length > options.bufferSize) {
      _history.removeAt(0);
    }

    return metrics;
  }
}
