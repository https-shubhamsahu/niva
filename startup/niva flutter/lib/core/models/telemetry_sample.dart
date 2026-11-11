/// Ported from `telemetryDatasetStore.ts`. Represents one stored row in the
/// on-device research dataset (the Flutter equivalent of the web app's
/// IndexedDB `esp32_samples` store, now backed by Hive - see
/// `core/data/telemetry_repository.dart`).
library;

/// `sim` and `simulation` are no longer produced: the synthetic gait
/// simulator was removed. They stay so rows recorded by older builds still
/// load and keep saying they were simulated, instead of passing as live data.
enum TelemetrySource { usb, ws, ble, sim }

enum TelemetryMode { live, simulation }

extension TelemetrySourceText on TelemetrySource {
  String get wireValue {
    switch (this) {
      case TelemetrySource.usb:
        return 'usb';
      case TelemetrySource.ws:
        return 'ws';
      case TelemetrySource.ble:
        return 'ble';
      case TelemetrySource.sim:
        return 'sim';
    }
  }
}

extension TelemetryModeText on TelemetryMode {
  String get wireValue => this == TelemetryMode.live ? 'live' : 'simulation';
}

class TelemetrySample {
  /// Phone clock when the frame arrived.
  final int timestampMs;
  final TelemetrySource source;
  final String sessionId;
  final String trialId;
  final TelemetryMode mode;
  final double heel;
  final double inner;
  final double outer;
  final double toe;
  final double impact;
  final double pitch;
  final double roll;
  final double accZ;

  /// Insole clock (ms since boot). Contact event times use the same clock.
  /// Null for rows recorded before the firmware reported it.
  final int? deviceTimestampMs;

  /// Firmware contact mask: bit 0 heel, 1 inner, 2 outer, 3 toe.
  final int contact;

  /// The frame's contact events, space-separated (e.g. `h+@1100 F+h@1100`).
  final String events;

  const TelemetrySample({
    required this.timestampMs,
    required this.source,
    required this.sessionId,
    required this.trialId,
    required this.mode,
    required this.heel,
    required this.inner,
    required this.outer,
    required this.toe,
    required this.impact,
    required this.pitch,
    required this.roll,
    required this.accZ,
    this.deviceTimestampMs,
    this.contact = 0,
    this.events = '',
  });

  /// Hive stores schema-less `Map` entries directly, so no generated
  /// TypeAdapter is required - this keeps the project buildable without
  /// running build_runner first.
  Map<String, dynamic> toMap() => {
        'timestampMs': timestampMs,
        'source': source.wireValue,
        'sessionId':
            sessionId.trim().isEmpty ? 'session-unassigned' : sessionId.trim(),
        'trialId': trialId.trim().isEmpty ? 'trial-001' : trialId.trim(),
        'mode': mode.wireValue,
        'heel': heel,
        'inner': inner,
        'outer': outer,
        'toe': toe,
        'impact': impact,
        'pitch': pitch,
        'roll': roll,
        'accZ': accZ,
        'deviceTimestampMs': deviceTimestampMs,
        'contact': contact,
        'events': events,
      };

  /// Rows written by older builds may carry a `diseaseLabel` key. It only
  /// ever held a simulator label, so it is ignored; `mode` still marks those
  /// rows as simulated.
  static TelemetrySample fromMap(Map<dynamic, dynamic> map) {
    return TelemetrySample(
      timestampMs: map['timestampMs'] as int,
      source: TelemetrySource.values.firstWhere(
        (s) => s.wireValue == map['source'],
        orElse: () => TelemetrySource.ws,
      ),
      sessionId: map['sessionId'] as String? ?? 'session-unassigned',
      trialId: map['trialId'] as String? ?? 'trial-001',
      mode: (map['mode'] as String? ?? 'live') == 'live'
          ? TelemetryMode.live
          : TelemetryMode.simulation,
      heel: (map['heel'] as num?)?.toDouble() ?? 0,
      inner: (map['inner'] as num?)?.toDouble() ?? 0,
      outer: (map['outer'] as num?)?.toDouble() ?? 0,
      toe: (map['toe'] as num?)?.toDouble() ?? 0,
      impact: (map['impact'] as num?)?.toDouble() ?? 0,
      pitch: (map['pitch'] as num?)?.toDouble() ?? 0,
      roll: (map['roll'] as num?)?.toDouble() ?? 0,
      accZ: (map['accZ'] as num?)?.toDouble() ?? 0,
      deviceTimestampMs: (map['deviceTimestampMs'] as num?)?.toInt(),
      contact: (map['contact'] as num?)?.toInt() ?? 0,
      events: map['events'] as String? ?? '',
    );
  }

  static String _escapeCsv(Object value) {
    final text = value.toString();
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static const csvHeader =
      'timestampMs,source,sessionId,trialId,mode,heel,inner,outer,toe,impact,pitch,roll,accZ,deviceTimestampMs,contact,events';

  String toCsvRow() {
    final map = toMap();
    return [
      _escapeCsv(map['timestampMs']),
      _escapeCsv(map['source']),
      _escapeCsv(map['sessionId']),
      _escapeCsv(map['trialId']),
      _escapeCsv(map['mode']),
      _escapeCsv(map['heel']),
      _escapeCsv(map['inner']),
      _escapeCsv(map['outer']),
      _escapeCsv(map['toe']),
      _escapeCsv(map['impact']),
      _escapeCsv(map['pitch']),
      _escapeCsv(map['roll']),
      _escapeCsv(map['accZ']),
      _escapeCsv(map['deviceTimestampMs'] ?? ''),
      _escapeCsv(map['contact']),
      _escapeCsv(map['events']),
    ].join(',');
  }
}
