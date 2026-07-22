import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/telemetry_sample.dart';

/// On-device dataset store for research/export, backed by Hive.
///
/// This is the Flutter equivalent of `telemetryDatasetStore.ts`'s IndexedDB
/// object store. Samples are appended as plain maps (see
/// [TelemetrySample.toMap]) so there is no generated adapter to keep in
/// sync - trade a little type safety for a project that builds without
/// running build_runner.
class TelemetryRepository {
  static const _boxName = 'gaitguard_nexus_samples';

  Box? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  Box get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('TelemetryRepository.init() must be awaited before use.');
    }
    return box;
  }

  Future<void> insertSamples(List<TelemetrySample> samples) async {
    if (samples.isEmpty) return;
    final box = _requireBox;
    // Hive's addAll auto-increments integer keys, mirroring the
    // autoIncrement keyPath used by the original IndexedDB store.
    await box.addAll(samples.map((s) => s.toMap()));
  }

  int get sampleCount => _box?.length ?? 0;

  /// Most recent [limit] samples, oldest-first (matches the web app's
  /// cursor-reversed IndexedDB query).
  List<TelemetrySample> latestSamples(int limit) {
    final box = _requireBox;
    final total = box.length;
    final start = total > limit ? total - limit : 0;
    final result = <TelemetrySample>[];
    for (var i = start; i < total; i++) {
      final raw = box.getAt(i);
      if (raw is Map) {
        result.add(TelemetrySample.fromMap(raw));
      }
    }
    return result;
  }

  Future<void> clear() async {
    await _requireBox.clear();
  }

  String exportCsv() {
    final all = latestSamples(_requireBox.length);
    final buffer = StringBuffer(TelemetrySample.csvHeader);
    for (final sample in all) {
      buffer.writeln();
      buffer.write(sample.toCsvRow());
    }
    return buffer.toString();
  }

  /// Writes the current dataset to a temp CSV file and returns its path,
  /// ready to hand to `share_plus` (see device_screen.dart).
  Future<File> exportCsvToFile() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/gaitguard-nexus-dataset-$stamp.csv');
    return file.writeAsString(exportCsv());
  }
}
