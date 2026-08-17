/// Ported from `telemetryDatasetStore.ts`. Represents one stored row in the
/// on-device research dataset (the Flutter equivalent of the web app's
/// IndexedDB `esp32_samples` store, now backed by Hive - see
/// `core/data/telemetry_repository.dart`).
library;

enum TelemetrySource { usb, ws, sim }

enum TelemetryMode { live, simulation }

enum DiseaseLabel { unknown, normal, parkinson, stroke, neuropathy, footDrop, ataxia }

extension DiseaseLabelText on DiseaseLabel {
  String get label {
    switch (this) {
      case DiseaseLabel.unknown:
        return 'Unknown';
      case DiseaseLabel.normal:
        return 'Normal';
      case DiseaseLabel.parkinson:
        return 'Parkinson';
      case DiseaseLabel.stroke:
        return 'Stroke';
      case DiseaseLabel.neuropathy:
        return 'Neuropathy';
      case DiseaseLabel.footDrop:
        return 'Foot Drop';
      case DiseaseLabel.ataxia:
        return 'Ataxia';
    }
  }
}

extension TelemetrySourceText on TelemetrySource {
  String get wireValue {
    switch (this) {
      case TelemetrySource.usb:
        return 'usb';
      case TelemetrySource.ws:
        return 'ws';
      case TelemetrySource.sim:
        return 'sim';
    }
  }
}

extension TelemetryModeText on TelemetryMode {
  String get wireValue => this == TelemetryMode.live ? 'live' : 'simulation';
}

class TelemetrySample {
  final int timestampMs;
  final TelemetrySource source;
  final String sessionId;
  final String trialId;
  final DiseaseLabel diseaseLabel;
  final TelemetryMode mode;
  final double heel;
  final double inner;
  final double outer;
  final double toe;
  final double impact;
  final double pitch;
  final double roll;
  final double accZ;

  const TelemetrySample({
    required this.timestampMs,
    required this.source,
    required this.sessionId,
    required this.trialId,
    required this.diseaseLabel,
    required this.mode,
    required this.heel,
    required this.inner,
    required this.outer,
    required this.toe,
    required this.impact,
    required this.pitch,
    required this.roll,
    required this.accZ,
  });

  /// Hive stores schema-less `Map` entries directly, so no generated
  /// TypeAdapter is required - this keeps the project buildable without
  /// running build_runner first.
  Map<String, dynamic> toMap() => {
        'timestampMs': timestampMs,
        'source': source.wireValue,
        'sessionId': sessionId.trim().isEmpty ? 'session-unassigned' : sessionId.trim(),
        'trialId': trialId.trim().isEmpty ? 'trial-001' : trialId.trim(),
        'diseaseLabel': diseaseLabel.label,
        'mode': mode.wireValue,
        'heel': heel,
        'inner': inner,
        'outer': outer,
        'toe': toe,
        'impact': impact,
        'pitch': pitch,
        'roll': roll,
        'accZ': accZ,
      };

  static TelemetrySample fromMap(Map<dynamic, dynamic> map) {
    DiseaseLabel parseDisease(String value) {
      for (final label in DiseaseLabel.values) {
        if (label.label == value) return label;
      }
      return DiseaseLabel.unknown;
    }

    return TelemetrySample(
      timestampMs: map['timestampMs'] as int,
      source: TelemetrySource.values.firstWhere(
        (s) => s.wireValue == map['source'],
        orElse: () => TelemetrySource.ws,
      ),
      sessionId: map['sessionId'] as String? ?? 'session-unassigned',
      trialId: map['trialId'] as String? ?? 'trial-001',
      diseaseLabel: parseDisease(map['diseaseLabel'] as String? ?? 'Unknown'),
      mode: (map['mode'] as String? ?? 'live') == 'live' ? TelemetryMode.live : TelemetryMode.simulation,
      heel: (map['heel'] as num?)?.toDouble() ?? 0,
      inner: (map['inner'] as num?)?.toDouble() ?? 0,
      outer: (map['outer'] as num?)?.toDouble() ?? 0,
      toe: (map['toe'] as num?)?.toDouble() ?? 0,
      impact: (map['impact'] as num?)?.toDouble() ?? 0,
      pitch: (map['pitch'] as num?)?.toDouble() ?? 0,
      roll: (map['roll'] as num?)?.toDouble() ?? 0,
      accZ: (map['accZ'] as num?)?.toDouble() ?? 0,
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
      'timestampMs,source,sessionId,trialId,diseaseLabel,mode,heel,inner,outer,toe,impact,pitch,roll,accZ';

  String toCsvRow() {
    final map = toMap();
    return [
      _escapeCsv(map['timestampMs']),
      _escapeCsv(map['source']),
      _escapeCsv(map['sessionId']),
      _escapeCsv(map['trialId']),
      _escapeCsv(map['diseaseLabel']),
      _escapeCsv(map['mode']),
      _escapeCsv(map['heel']),
      _escapeCsv(map['inner']),
      _escapeCsv(map['outer']),
      _escapeCsv(map['toe']),
      _escapeCsv(map['impact']),
      _escapeCsv(map['pitch']),
      _escapeCsv(map['roll']),
      _escapeCsv(map['accZ']),
    ].join(',');
  }
}
