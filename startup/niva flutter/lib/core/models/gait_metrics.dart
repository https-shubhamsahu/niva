/// Types shared by the gait timing engine and the UI.
///
/// Every timing number here comes from contact edges the insole stamps with
/// its own clock (`niva_signal.h`, section 9). The FSR readings are relative
/// load indices, not force or pressure, so nothing in this file is in newtons.
library;

enum InsoleSensor { heel, inner, outer, toe }

extension InsoleSensorText on InsoleSensor {
  String get label {
    switch (this) {
      case InsoleSensor.heel:
        return 'Heel';
      case InsoleSensor.inner:
        return 'Inner forefoot';
      case InsoleSensor.outer:
        return 'Outer forefoot';
      case InsoleSensor.toe:
        return 'Toe';
    }
  }

  /// Bit in the firmware's `contact` mask.
  int get bit => 1 << index;
}

/// Relative load on each sensor. Display only: the sensors saturate under
/// walking load, so these are not comparable to force.
class SensorLoads {
  final double heel;
  final double inner;
  final double outer;
  final double toe;

  const SensorLoads({
    this.heel = 0,
    this.inner = 0,
    this.outer = 0,
    this.toe = 0,
  });

  double get total => heel + inner + outer + toe;

  /// Each sensor's share of the summed reading (0..1), all zero when nothing
  /// is loaded. Negative readings are baseline drift, which the firmware keeps
  /// signed on purpose; they are clamped here, at the display layer.
  SensorLoads shares() {
    double positive(double v) => v > 0 ? v : 0;
    final h = positive(heel), i = positive(inner), o = positive(outer), t = positive(toe);
    final total = h + i + o + t;
    if (total <= 0) return const SensorLoads();
    return SensorLoads(heel: h / total, inner: i / total, outer: o / total, toe: t / total);
  }

  double of(InsoleSensor sensor) {
    switch (sensor) {
      case InsoleSensor.heel:
        return heel;
      case InsoleSensor.inner:
        return inner;
      case InsoleSensor.outer:
        return outer;
      case InsoleSensor.toe:
        return toe;
    }
  }
}

/// One edge from the firmware's `events` array, e.g. `h+@12345` (heel loads),
/// `F+h@12345` (the foot loads, heel first), `F+*@12345` (the foot loads, two
/// sensors on the same sample) or `F-@12400` (the foot unloads).
class ContactEvent {
  final int deviceMs;

  /// The sensor for a single-sensor edge; null for a whole-foot edge.
  final InsoleSensor? sensor;
  final bool isOn;

  /// Foot ON only: the sensor that loaded first, or null when tied.
  final InsoleSensor? first;

  const ContactEvent({
    required this.deviceMs,
    required this.sensor,
    required this.isOn,
    this.first,
  });

  bool get isFoot => sensor == null;
  bool get isTie => isFoot && isOn && first == null;

  static const _codes = {
    'h': InsoleSensor.heel,
    'i': InsoleSensor.inner,
    'o': InsoleSensor.outer,
    't': InsoleSensor.toe,
  };

  /// Returns null for anything that is not a well-formed event code, so one
  /// corrupted entry cannot take down a whole frame.
  static ContactEvent? parse(Object? raw) {
    if (raw is! String) return null;
    final at = raw.indexOf('@');
    if (at < 2) return null;
    final code = raw.substring(0, at);
    final deviceMs = int.tryParse(raw.substring(at + 1));
    if (deviceMs == null) return null;

    final sign = code[1];
    if (sign != '+' && sign != '-') return null;
    final isOn = sign == '+';

    if (code[0] == 'F') {
      if (!isOn) return code.length == 2 ? ContactEvent(deviceMs: deviceMs, sensor: null, isOn: false) : null;
      if (code.length != 3) return null;
      if (code[2] == '*') return ContactEvent(deviceMs: deviceMs, sensor: null, isOn: true);
      final first = _codes[code[2]];
      if (first == null) return null;
      return ContactEvent(deviceMs: deviceMs, sensor: null, isOn: true, first: first);
    }

    final sensor = _codes[code[0]];
    if (sensor == null || code.length != 2) return null;
    return ContactEvent(deviceMs: deviceMs, sensor: sensor, isOn: isOn);
  }
}

/// A contact event with its time on the phone's monotonic clock, so a test
/// clock running on the phone can place it.
class TimedContactEvent {
  final ContactEvent event;
  final int phoneMs;

  const TimedContactEvent(this.event, this.phoneMs);
}

/// One completed foot contact, from the foot loading to the foot unloading.
class FootContact {
  final int onMs;
  final int offMs;
  final InsoleSensor? first;

  const FootContact({required this.onMs, required this.offMs, this.first});

  int get durationMs => offMs - onMs;
}

/// The derived frame the dashboard renders. Timing values stay null until
/// the step gate opens, so the UI shows "collecting" instead of a number
/// computed from too few contacts.
class GaitMetrics {
  /// Same minimum as `NIVA_MIN_STEPS_PRESSURE` in `niva_signal.h`.
  static const minFootContacts = 12;

  final SensorLoads loadShares;
  final int contactMask;
  final int footContacts;
  final double? cadenceStepsPerMin;
  final int? contactTimeMs;

  /// Share of foot contacts where the heel loaded first, among contacts
  /// whose first sensor could be resolved (ties are excluded and counted).
  final double? heelFirstShare;
  final int tiedContacts;

  /// Events the firmware could not queue, cumulative since its last tare.
  final int eventsDropped;

  /// Telemetry gaps long enough that events in them may be missing. Timing
  /// is never computed across a gap.
  final int frameGaps;

  /// False when the connected firmware predates contact events.
  final bool firmwareReportsEvents;

  const GaitMetrics({
    required this.loadShares,
    required this.contactMask,
    required this.footContacts,
    required this.cadenceStepsPerMin,
    required this.contactTimeMs,
    required this.heelFirstShare,
    required this.tiedContacts,
    required this.eventsDropped,
    required this.frameGaps,
    required this.firmwareReportsEvents,
  });

  factory GaitMetrics.idle() => const GaitMetrics(
        loadShares: SensorLoads(),
        contactMask: 0,
        footContacts: 0,
        cadenceStepsPerMin: null,
        contactTimeMs: null,
        heelFirstShare: null,
        tiedContacts: 0,
        eventsDropped: 0,
        frameGaps: 0,
        firmwareReportsEvents: true,
      );

  bool get isGateOpen => footContacts >= minFootContacts;
  bool inContact(InsoleSensor sensor) => (contactMask & sensor.bit) != 0;
}
