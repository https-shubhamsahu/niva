import 'package:flutter_test/flutter_test.dart';
import 'package:niva/core/engine/biomechanics_engine.dart';
import 'package:niva/core/models/biomechanics_metrics.dart';

/// These tests pin down the same behaviors the original
/// `biomechanicsEngine.ts` relies on so a future refactor here can't
/// silently drift from the web app's thresholds.
///
/// NOTE: this repo's sandbox has no Dart/Flutter SDK available to actually
/// execute `flutter test` - these were written and reasoned through by hand
/// against the ported source, but have not been run. Run `flutter test`
/// after `flutter pub get` as your first sanity check.
void main() {
  group('BiomechanicsEngine', () {
    RawSensorPacket packet({
      double heel = 0,
      double inner = 0,
      double outer = 0,
      double toe = 0,
      double impact = 0,
      double pitch = 0,
      double roll = 0,
      int t = 0,
    }) {
      return RawSensorPacket(
        heel: heel,
        inner: inner,
        outer: outer,
        toe: toe,
        impact: impact,
        pitch: pitch,
        roll: roll,
        accZ: 9.8,
        timestampMs: t,
      );
    }

    test('starts uncalibrated and calibrates after a stable no-load window', () {
      final engine = BiomechanicsEngine();
      expect(engine.isCalibrated, isFalse);

      // 30 near-zero, stable frames should trigger calibration (matches
      // `calibrationSamples: 30` + the no-load stability checks).
      for (var i = 0; i < 30; i++) {
        engine.process(packet(heel: 2, inner: 1, outer: 1, toe: 1, impact: 5, t: i * 20));
      }

      expect(engine.isCalibrated, isTrue);
    });

    test('idle/no-load input never registers a heel strike', () {
      final engine = BiomechanicsEngine();
      ProcessedBiomechanicsMetrics? last;
      for (var i = 0; i < 40; i++) {
        last = engine.process(packet(t: i * 20));
      }
      expect(last!.heelStrikeDetected, isFalse);
      expect(last.stepCount, 0);
      expect(last.contactState, ContactState.swing);
    });

    test('a strong heel impact after calibration is detected as a heel strike', () {
      final engine = BiomechanicsEngine();

      // Calibrate on a quiet baseline first.
      for (var i = 0; i < 30; i++) {
        engine.process(packet(heel: 1, inner: 1, outer: 1, toe: 1, impact: 5, t: i * 20));
      }
      expect(engine.isCalibrated, isTrue);

      // Ramp heel pressure up sharply with a high-impact packet - mirrors a
      // real heel-strike transient (impact > 200, heel > 80, rising fast).
      ProcessedBiomechanicsMetrics? last;
      for (var i = 0; i < 6; i++) {
        last = engine.process(packet(
          heel: 95,
          inner: 20,
          outer: 20,
          toe: 5,
          impact: 400,
          t: 600 + i * 20,
        ));
      }

      expect(last!.stepCount, greaterThan(0));
    });

    test('stability score degrades as sway/impact increase', () {
      final calm = BiomechanicsEngine();
      final calmMetrics = calm.process(packet(heel: 50, inner: 40, outer: 40, toe: 30, impact: 50, pitch: 0.5, roll: 0.5));

      final rough = BiomechanicsEngine();
      final roughMetrics = rough.process(packet(heel: 50, inner: 40, outer: 40, toe: 30, impact: 700, pitch: 12, roll: 12));

      expect(roughMetrics.stabilityScore, lessThan(calmMetrics.stabilityScore));
      expect(roughMetrics.stabilityBand, StabilityBand.unstable);
    });

    test('reset() returns the engine to its initial uncalibrated state', () {
      final engine = BiomechanicsEngine();
      for (var i = 0; i < 30; i++) {
        engine.process(packet(heel: 1, inner: 1, outer: 1, toe: 1, impact: 5, t: i * 20));
      }
      expect(engine.isCalibrated, isTrue);

      engine.reset();

      expect(engine.isCalibrated, isFalse);
      expect(engine.history, isEmpty);
    });
  });
}
