import '../models/gait_metrics.dart';

/// Turns the firmware's contact edges into timing metrics.
///
/// The insole finds edges at its 100 Hz acquisition rate and stamps them
/// with its own clock. This engine never times anything from the 20 Hz
/// telemetry frames themselves, and never uses the phone's clock.
///
/// With one insole every foot contact belongs to the same foot, so the gap
/// between two foot contacts is a stride, which is two steps. Cadence in
/// steps per minute is therefore 2 x 60 000 / stride time.
///
/// Pure Dart with no Flutter imports, so it can be unit tested directly.
class GaitTimingEngine {
  /// Contacts in each rolling median.
  static const windowSize = 10;

  /// A longer gap between foot contacts is a pause, not a stride. Starting
  /// value; revise it with check F4 of the SIH26213 plan.
  static const maxStrideMs = 2500;

  /// A shorter gap is a detection artefact, not a stride. Starting value.
  static const minStrideMs = 300;

  /// Frames arrive every 50 ms. A longer silence means frames, and the
  /// events inside them, may have been lost.
  static const frameGapMs = 150;

  /// Contacts kept for the Trends screen.
  static const historyLength = 60;

  int? _lastFrameMs;
  int? _lastFootOnMs;
  ContactEvent? _openContact;
  int _footContacts = 0;
  int _resolvedFirst = 0;
  int _heelFirst = 0;
  int _ties = 0;
  int _frameGaps = 0;
  final List<int> _strideMs = [];
  final List<int> _contactMs = [];
  final List<FootContact> _history = [];
  final List<double> _cadenceHistory = [];

  /// Completed foot contacts, oldest first.
  List<FootContact> get history => List.unmodifiable(_history);

  /// Steps per minute for each stride, oldest first.
  List<double> get cadenceHistory => List.unmodifiable(_cadenceHistory);

  void reset() {
    _lastFrameMs = null;
    _lastFootOnMs = null;
    _openContact = null;
    _footContacts = 0;
    _resolvedFirst = 0;
    _heelFirst = 0;
    _ties = 0;
    _frameGaps = 0;
    _strideMs.clear();
    _contactMs.clear();
    _history.clear();
    _cadenceHistory.clear();
  }

  /// Process one decoded telemetry frame that the firmware marked valid.
  GaitMetrics process(Map<String, dynamic> frame) {
    final frameMs = (frame['deviceTimestampMs'] as num?)?.toInt();
    if (frameMs != null) {
      final last = _lastFrameMs;
      if (last != null && frameMs < last) {
        // The insole restarted: its clock went backwards.
        reset();
      } else if (last != null && frameMs - last > frameGapMs) {
        _frameGaps++;
        _breakChain();
      }
      _lastFrameMs = frameMs;
    }

    final rawEvents = frame['events'];
    final reportsEvents = rawEvents is List;
    if (rawEvents is List) {
      for (final raw in rawEvents) {
        final event = ContactEvent.parse(raw);
        if (event != null && event.isFoot) _onFootEdge(event);
      }
    }

    double reading(String key) => (frame[key] as num?)?.toDouble() ?? 0;
    final loads = SensorLoads(
      heel: reading('heel'),
      inner: reading('inner'),
      outer: reading('outer'),
      toe: reading('toe'),
    );

    final gateOpen = _footContacts >= GaitMetrics.minFootContacts;
    final strideMs = _median(_strideMs);
    final contactMs = _median(_contactMs);

    return GaitMetrics(
      loadShares: loads.shares(),
      contactMask: (frame['contact'] as num?)?.toInt() ?? 0,
      footContacts: _footContacts,
      cadenceStepsPerMin:
          gateOpen && strideMs != null ? 2 * 60000 / strideMs : null,
      contactTimeMs: gateOpen ? contactMs?.round() : null,
      heelFirstShare:
          gateOpen && _resolvedFirst > 0 ? _heelFirst / _resolvedFirst : null,
      tiedContacts: _ties,
      eventsDropped: (frame['eventsDropped'] as num?)?.toInt() ?? 0,
      frameGaps: _frameGaps,
      firmwareReportsEvents: reportsEvents,
    );
  }

  void _onFootEdge(ContactEvent event) {
    if (event.isOn) {
      final lastOn = _lastFootOnMs;
      if (lastOn != null) {
        final stride = event.deviceMs - lastOn;
        if (stride >= minStrideMs && stride <= maxStrideMs) {
          _push(_strideMs, stride);
          _cadenceHistory.add(2 * 60000 / stride);
          if (_cadenceHistory.length > historyLength) {
            _cadenceHistory.removeAt(0);
          }
        }
      }
      _lastFootOnMs = event.deviceMs;
      _openContact = event;
      _footContacts++;
      if (event.isTie) {
        _ties++;
      } else {
        _resolvedFirst++;
        if (event.first == InsoleSensor.heel) _heelFirst++;
      }
      return;
    }

    final open = _openContact;
    _openContact = null;
    if (open == null) return;
    final contact = FootContact(
        onMs: open.deviceMs, offMs: event.deviceMs, first: open.first);
    if (contact.durationMs <= 0) return;
    _push(_contactMs, contact.durationMs);
    _history.add(contact);
    if (_history.length > historyLength) _history.removeAt(0);
  }

  /// After a gap, the next foot contact may not follow the previous one, and
  /// an open contact may have lost its end.
  void _breakChain() {
    _lastFootOnMs = null;
    _openContact = null;
  }

  static void _push(List<int> window, int value) {
    window.add(value);
    if (window.length > windowSize) window.removeAt(0);
  }

  static double? _median(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
