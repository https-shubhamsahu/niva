import 'package:flutter/foundation.dart';
import 'package:niva/core/data/trial_store.dart';
import 'package:niva/core/fitness/fitness_trial.dart';
import 'package:niva/core/time/clock.dart';

/// A clock the test moves by hand.
class FakeClock implements MonotonicClock {
  @override
  int nowMs = 0;
}

/// Trials kept in memory instead of Hive.
class MemoryTrialStore extends TrialStore {
  final Map<String, FitnessTrial> _trials = {};
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  @override
  Listenable get changes => _revision;

  @override
  int get count => _trials.length;

  @override
  List<FitnessTrial> recent({int limit = 50}) {
    final list = _trials.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list.take(limit).toList();
  }

  @override
  Future<void> add(FitnessTrial trial) async {
    _trials[trial.id] = trial;
    _revision.value++;
  }

  @override
  Future<void> delete(String id) async {
    _trials.remove(id);
    _revision.value++;
  }
}
