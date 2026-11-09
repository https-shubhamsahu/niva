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
      // real heel-strike transient (impact > 200, heel > 80% of full scale,
      // rising fast). Inputs are ADC counts, like the firmware sends.
      ProcessedBiomechanicsMetrics? last;
      for (var i = 0; i < 6; i++) {
        last = engine.process(packet(
          heel: 3900,
          inner: 820,
          outer: 820,
          toe: 205,
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

    test('pressure conversion is one linear mapping: 100 and 101 counts are adjacent', () {
      // Regression for the old rule that read <=100 as percent and >100 as
      // counts (100 -> 100%, 101 -> 2.5%). Deadband off so the filtered value
      // shows the conversion itself.
      double settledHeel(double counts) {
        final engine = BiomechanicsEngine(
          options: const BiomechanicsEngineOptions(pressureDeadband: 0),
        );
        var t = 0;
        for (var i = 0; i < 30; i++) {
          engine.process(packet(t: t));
          t += 50;
        }
        late ProcessedBiomechanicsMetrics m;
        for (var i = 0; i < 200; i++) {
          m = engine.process(packet(heel: counts, t: t));
          t += 50;
        }
        return m.filteredPressure.heel;
      }

      final at100 = settledHeel(100);
      final at101 = settledHeel(101);
      expect(at100, closeTo(100 / 4095 * 100, 0.01));
      expect(at101 - at100, closeTo(1 / 4095 * 100, 0.01));
      expect(settledHeel(4095), closeTo(100, 0.01));
    });

    test('a loaded foot during tare is not zeroed and is reported as untared', () {
      final engine = BiomechanicsEngine();
      ProcessedBiomechanicsMetrics? last;
      for (var i = 0; i < 80; i++) {
        last = engine.process(packet(heel: 1200, inner: 900, t: i * 50));
      }
      expect(last!.isCalibrated, isTrue);
      expect(last.tareApplied, isFalse);
      expect(last.filteredPressure.heel, greaterThan(20));
    });

    test('one insole: steps are 2 per heel strike and cadence uses the stride', () {
      final engine = BiomechanicsEngine();
      var t = 0;
      for (var i = 0; i < 30; i++) {
        engine.process(packet(t: t));
        t += 50;
      }
      ProcessedBiomechanicsMetrics? last;
      // 20 strides of 1000 ms each = 120 steps/min.
      for (var stride = 0; stride < 20; stride++) {
        for (var phase = 0; phase < 1000; phase += 50) {
          final loaded = phase < 600;
          last = engine.process(packet(
            heel: loaded && phase < 200 ? 4095 : 0,
            toe: loaded && phase >= 200 ? 3000 : 0,
            impact: phase < 50 ? 600 : 0,
            t: t,
          ));
          t += 50;
        }
      }
      expect(last!.stepCount, 40);
      expect(last.cadenceSpm, closeTo(120, 0.5));
    });

    test('normal walking pitch raises no instability flag', () {
      final engine = BiomechanicsEngine();
      for (var i = 0; i < 30; i++) {
        engine.process(packet(t: i * 50));
      }
      final m = engine.process(packet(heel: 2000, pitch: 15, roll: 2, t: 2000));
      expect(m.anomalyFlags, isEmpty);
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
