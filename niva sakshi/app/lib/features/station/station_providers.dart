import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fitness/one_leg_minute.dart';
import '../../core/fitness/roster.dart';
import '../../core/providers/app_providers.dart';

/// The class queue for the station. Kept on the phone as roll IDs only.
class RosterNotifier extends StateNotifier<Roster> {
  final Future<void> Function(String? json) _save;

  RosterNotifier(super.initial, this._save);

  static Roster decode(String? json) {
    if (json == null || json.isEmpty) return Roster(const []);
    try {
      return Roster.fromMap(jsonDecode(json) as Map);
    } catch (_) {
      return Roster(const []);
    }
  }

  Roster _copy() => Roster.fromMap(state.toMap());

  void _commit(Roster next) {
    state = next;
    _save(next.total == 0 ? null : jsonEncode(next.toMap()));
  }

  void replaceWith(String pasted) => _commit(Roster.parse(pasted));
  void markDone(String id) => _commit(_copy()..markDone(id));
  void reopen(String id) => _commit(_copy()..reopen(id));
  void clear() => _commit(Roster(const []));
}

final rosterProvider = StateNotifierProvider<RosterNotifier, Roster>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return RosterNotifier(
      RosterNotifier.decode(settings.stationRoster), settings.setStationRoster);
});

/// This session's One-Leg Minute totals. Not saved: practice is not a record.
class ClassPracticeNotifier extends StateNotifier<ClassPractice> {
  ClassPracticeNotifier() : super(ClassPractice());

  void add(String rollId, OneLegMinuteRound round) {
    state = state.copy()..add(rollId, round);
  }
}

final classPracticeProvider =
    StateNotifierProvider<ClassPracticeNotifier, ClassPractice>(
        (ref) => ClassPracticeNotifier());
