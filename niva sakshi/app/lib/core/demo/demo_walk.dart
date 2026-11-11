import 'dart:math' as math;

import '../models/gait_metrics.dart';

/// A scripted walk for demo mode, written as the insole firmware's own
/// telemetry frames: one every 50 ms, contact edges on a 10 ms grid, four
/// relative sensor readings and a contact mask.
///
/// These frames are SIMULATED. They exist so a presentation can show the
/// real timing engine and screens at work without hardware. They are never
/// saved, exported or passed to an assessment, and every screen that shows
/// them says "Demo". Seeded, so a demo plays the same way every time.
class DemoWalk {
  static const frameMs = 50;

  final math.Random _random;
  int _t = 0;
  int _nextOn = 400;
  int? _onAt, _offAt;
  InsoleSensor? _first;

  DemoWalk({int seed = 7}) : _random = math.Random(seed);

  /// Device time of the most recent frame.
  int get deviceMs => _t;

  /// The next 50 ms telemetry frame.
  Map<String, dynamic> next() {
    _t += frameMs;
    final events = <String>[];
    while (true) {
      final onAt = _onAt, offAt = _offAt;
      if (onAt == null && _nextOn <= _t) {
        final stride = _strideMs(_nextOn);
        final stance = .58 + _random.nextDouble() * .05;
        _onAt = _nextOn;
        _offAt = _nextOn + _grid(stride * stance);
        _first = _pickFirst();
        events.add('F+${_code(_first)}@$_onAt');
        _nextOn += stride;
        continue;
      }
      if (onAt != null && offAt != null && offAt <= _t) {
        events.add('F-@$offAt');
        _onAt = _offAt = null;
        continue;
      }
      break;
    }

    final loads = _loadsAt(_t);
    var contact = 0;
    loads.forEach((sensor, value) {
      if (value > 150) contact |= sensor.bit;
    });
    return {
      'deviceTimestampMs': _t,
      'validity': 'valid',
      'heel': loads[InsoleSensor.heel],
      'inner': loads[InsoleSensor.inner],
      'outer': loads[InsoleSensor.outer],
      'toe': loads[InsoleSensor.toe],
      'contact': contact,
      'events': events,
      'eventsDropped': 0,
    };
  }

  /// Cadence drifts gently between about 100 and 112 steps a minute so the
  /// values and sparkline visibly move; strides land on the 10 ms grid.
  int _strideMs(int atMs) {
    final cadence = 106 +
        6 * math.sin(atMs / 40000 * 2 * math.pi) +
        (_random.nextDouble() - .5) * 4;
    return _grid(2 * 60000 / cadence);
  }

  InsoleSensor? _pickFirst() {
    final roll = _random.nextDouble();
    if (roll < .78) return InsoleSensor.heel;
    if (roll < .90) return InsoleSensor.outer;
    if (roll < .96) return InsoleSensor.inner;
    return null; // two sensors in the same 10 ms sample
  }

  static String _code(InsoleSensor? first) => switch (first) {
        InsoleSensor.heel => 'h',
        InsoleSensor.inner => 'i',
        InsoleSensor.outer => 'o',
        InsoleSensor.toe => 't',
        null => '*',
      };

  static int _grid(double ms) => (ms / 10).round() * 10;

  /// Heel, then the forefoot, then the toe load across each contact.
  Map<InsoleSensor, double> _loadsAt(int t) {
    double noise() => _random.nextDouble() * 12;
    final onAt = _onAt, offAt = _offAt;
    // A foot in the air reads nothing, so its shares show as zero rather
    // than percentages of noise.
    if (onAt == null || offAt == null) {
      return {for (final s in InsoleSensor.values) s: 0.0};
    }
    final p = (t - onAt) / (offAt - onAt);
    double bell(double centre, double width) =>
        math.exp(-math.pow((p - centre) / width, 2));
    final heelLead = _first != InsoleSensor.outer;
    return {
      InsoleSensor.heel: 900 * bell(heelLead ? .2 : .32, .2) + noise(),
      InsoleSensor.outer: 520 * bell(heelLead ? .45 : .18, .22) + noise(),
      InsoleSensor.inner: 700 * bell(.6, .2) + noise(),
      InsoleSensor.toe: 640 * bell(.86, .12) + noise(),
    };
  }
}
