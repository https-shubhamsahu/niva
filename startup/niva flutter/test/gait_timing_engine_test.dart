import 'package:flutter_test/flutter_test.dart';
import 'package:niva/core/engine/gait_timing_engine.dart';
import 'package:niva/core/models/gait_metrics.dart';

/// The event streams below are synthetic, built to exercise the arithmetic.
/// They say nothing about real gait; checks F1-F4 of the SIH26213 plan do.
void main() {
  /// One 20 Hz frame every 50 ms, each carrying the events whose time falls
  /// in its window, the way the firmware packs them.
  List<Map<String, dynamic>> stream(
    List<String> events, {
    int from = 1000,
    required int to,
    Set<int> dropFramesAt = const {},
  }) {
    final frames = <Map<String, dynamic>>[];
    for (var t = from; t <= to; t += 50) {
      if (dropFramesAt.contains(t)) continue;
      final inWindow = events.where((e) {
        final ms = int.parse(e.split('@')[1]);
        return ms > t - 50 && ms <= t;
      }).toList();
      frames.add({
        'deviceTimestampMs': t,
        'heel': 0,
        'inner': 0,
        'outer': 0,
        'toe': 0,
        'validity': 'valid',
        'contact': 0,
        'events': inWindow,
        'eventsDropped': 0,
      });
    }
    return frames;
  }

  /// [contacts] foot contacts of one foot, [strideMs] apart, each
  /// [contactMs] long. [first] is the firmware code of the first sensor, or
  /// '*' for a same-sample tie.
  List<String> walk({
    required int contacts,
    int start = 1100,
    int strideMs = 1000,
    int contactMs = 600,
    String first = 'h',
  }) {
    final events = <String>[];
    for (var k = 0; k < contacts; k++) {
      final on = start + k * strideMs;
      final off = on + contactMs;
      if (first == '*') {
        events.addAll(['h+@$on', 't+@$on']);
      } else {
        events.add('$first+@$on');
      }
      events.addAll(['F+$first@$on', 'h-@$off', 't-@$off', 'F-@$off']);
    }
    return events;
  }

  GaitMetrics run(GaitTimingEngine engine, List<Map<String, dynamic>> frames) {
    var last = GaitMetrics.idle();
    for (final frame in frames) {
      last = engine.process(frame);
    }
    return last;
  }

  group('ContactEvent.parse', () {
    test('reads every code the firmware emits', () {
      final heelOn = ContactEvent.parse('h+@100')!;
      expect(heelOn.sensor, InsoleSensor.heel);
      expect(heelOn.isOn, isTrue);
      expect(heelOn.deviceMs, 100);

      expect(ContactEvent.parse('o-@5')!.sensor, InsoleSensor.outer);
      expect(ContactEvent.parse('o-@5')!.isOn, isFalse);

      final footOn = ContactEvent.parse('F+t@7')!;
      expect(footOn.isFoot, isTrue);
      expect(footOn.first, InsoleSensor.toe);
      expect(footOn.isTie, isFalse);

      expect(ContactEvent.parse('F+*@9')!.isTie, isTrue);

      final footOff = ContactEvent.parse('F-@11')!;
      expect(footOff.isFoot, isTrue);
      expect(footOff.isOn, isFalse);
    });

    test('rejects malformed codes instead of guessing', () {
      for (final bad in [
        'x+@1',
        'h@1',
        'F+@1',
        'F-h@1',
        'h+@abc',
        'h+',
        '',
        'hh+@1'
      ]) {
        expect(ContactEvent.parse(bad), isNull, reason: bad);
      }
      expect(ContactEvent.parse(42), isNull);
    });
  });

  group('GaitTimingEngine', () {
    test('frames without an events field mean old firmware, not zero steps',
        () {
      final engine = GaitTimingEngine();
      final metrics = engine.process(
          {'deviceTimestampMs': 1000, 'heel': 10, 'validity': 'valid'});
      expect(metrics.firmwareReportsEvents, isFalse);
      expect(metrics.cadenceStepsPerMin, isNull);
    });

    test('timing stays hidden until the step gate opens', () {
      final under = GaitTimingEngine();
      final eleven = run(under, stream(walk(contacts: 11), to: 13000));
      expect(eleven.footContacts, 11);
      expect(eleven.cadenceStepsPerMin, isNull);
      expect(eleven.contactTimeMs, isNull);
      expect(eleven.heelFirstShare, isNull);

      final at = GaitTimingEngine();
      final twelve = run(at, stream(walk(contacts: 12), to: 14000));
      expect(twelve.footContacts, GaitMetrics.minFootContacts);
      expect(twelve.cadenceStepsPerMin, isNotNull);
    });

    test('cadence counts two steps per stride of the one insole', () {
      final engine = GaitTimingEngine();
      final metrics =
          run(engine, stream(walk(contacts: 13, strideMs: 1000), to: 15000));
      expect(metrics.cadenceStepsPerMin, 120); // 2 x 60 000 / 1000 ms
      expect(engine.cadenceHistory, everyElement(120));
    });

    test('contact time is the median foot-on to foot-off duration', () {
      final engine = GaitTimingEngine();
      final metrics =
          run(engine, stream(walk(contacts: 13, contactMs: 600), to: 15000));
      expect(metrics.contactTimeMs, 600);
      expect(engine.history.map((c) => c.durationMs), everyElement(600));
    });

    test('heel-first share leaves same-sample ties out and counts them', () {
      final events = [
        ...walk(contacts: 9, start: 1100, first: 'h'),
        ...walk(contacts: 3, start: 10100, first: 't'),
        ...walk(contacts: 1, start: 13100, first: '*'),
      ];
      final metrics = run(GaitTimingEngine(), stream(events, to: 15000));
      expect(metrics.footContacts, 13);
      expect(metrics.tiedContacts, 1);
      expect(metrics.heelFirstShare, 9 / 12);
    });

    test('a telemetry gap is counted and no stride is timed across it', () {
      final engine = GaitTimingEngine();
      // Contact 5 starts at 6100 and ends at 6700. Frames 6750-6850 never
      // arrive, so the next frame (6900) follows a 200 ms silence.
      final metrics = run(
        engine,
        stream(walk(contacts: 14), to: 16000, dropFramesAt: {6750, 6800, 6850}),
      );
      expect(metrics.frameGaps, 1);
      expect(engine.cadenceHistory.length, 12); // 13 strides, one discarded
    });

    test('a pause longer than a stride is not counted as one', () {
      final events = [
        ...walk(contacts: 7, start: 1100),
        ...walk(contacts: 7, start: 12100), // 4.4 s after the last contact
      ];
      final engine = GaitTimingEngine();
      run(engine, stream(events, to: 20000));
      expect(engine.cadenceHistory.length, 12); // 6 + 6, the pause excluded
    });

    test('an insole clock that goes backwards means a restart', () {
      final engine = GaitTimingEngine();
      run(engine, stream(walk(contacts: 5), to: 7000));
      final metrics =
          engine.process({'deviceTimestampMs': 100, 'events': <String>[]});
      expect(metrics.footContacts, 0);
      expect(engine.history, isEmpty);
    });

    test('reset() clears every counter and the history', () {
      final engine = GaitTimingEngine();
      run(engine, stream(walk(contacts: 13), to: 15000));
      engine.reset();
      final metrics =
          engine.process({'deviceTimestampMs': 1000, 'events': <String>[]});
      expect(metrics.footContacts, 0);
      expect(engine.history, isEmpty);
      expect(engine.cadenceHistory, isEmpty);
    });
  });

  group('SensorLoads.shares', () {
    test('clamps signed drift at display time and sums to one', () {
      const loads = SensorLoads(heel: 300, inner: 100, outer: -20, toe: 0);
      final shares = loads.shares();
      expect(shares.heel, 0.75);
      expect(shares.inner, 0.25);
      expect(shares.outer, 0);
      expect(shares.toe, 0);
    });

    test('an unloaded insole has no shares rather than dividing by zero', () {
      final shares = const SensorLoads().shares();
      expect(shares.total, 0);
    });
  });
}
