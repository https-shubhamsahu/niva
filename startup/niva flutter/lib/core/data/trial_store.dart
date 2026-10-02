import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../fitness/fitness_trial.dart';

/// Saved fitness-test trials. An interface so widget tests can swap in an
/// in-memory store.
abstract class TrialStore {
  /// Fires whenever a trial is added or deleted.
  Listenable get changes;

  /// Newest first.
  List<FitnessTrial> recent({int limit = 50});

  int get count;

  Future<void> add(FitnessTrial trial);

  Future<void> delete(String id);

  String exportCsv() {
    final buffer = StringBuffer(FitnessTrial.csvHeader);
    for (final trial in recent(limit: count).reversed) {
      buffer
        ..writeln()
        ..write(trial.toCsvRow());
    }
    return buffer.toString();
  }

  Future<File> exportCsvToFile() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/niva-fitness-trials-$stamp.csv');
    return file.writeAsString(exportCsv());
  }
}

/// Hive-backed store, the same storage the telemetry dataset uses. Trials
/// are kept as plain maps keyed by trial id, so no generated adapters.
class HiveTrialStore extends TrialStore {
  static const _boxName = 'niva_fitness_trials';

  Box? _box;

  /// Call after `Hive.initFlutter()` (done by `TelemetryRepository.init`).
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Box get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('HiveTrialStore.init() must be awaited before use.');
    }
    return box;
  }

  @override
  Listenable get changes => _requireBox.listenable();

  @override
  int get count => _box?.length ?? 0;

  @override
  List<FitnessTrial> recent({int limit = 50}) {
    final trials = <FitnessTrial>[];
    for (final raw in _requireBox.values) {
      if (raw is Map) trials.add(FitnessTrial.fromMap(raw));
    }
    trials.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return trials.take(limit).toList();
  }

  @override
  Future<void> add(FitnessTrial trial) => _requireBox.put(trial.id, trial.toMap());

  @override
  Future<void> delete(String id) => _requireBox.delete(id);
}
