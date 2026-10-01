import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/data/trial_store.dart';
import '../../core/fitness/fit_india_protocol.dart';
import '../../core/fitness/fitness_trial.dart';
import '../../core/fitness/flamingo_session.dart';
import '../../core/fitness/vrikshasana_session.dart';
import '../../core/models/gait_metrics.dart';
import '../../core/time/clock.dart';

class TestRunConfig {
  final FitnessTest test;
  final String participantId;
  final StandingLeg standingLeg;
  final String sessionId;

  const TestRunConfig({
    required this.test,
    required this.participantId,
    required this.standingLeg,
    required this.sessionId,
  });

  TestRunConfig withLeg(StandingLeg leg) => TestRunConfig(
        test: test,
        participantId: participantId,
        standingLeg: leg,
        sessionId: sessionId,
      );
}

/// Drives one trial: owns the protocol session, ticks the clock for the
/// screen, hands it the insole's foot events, and saves the trial once it
/// finishes.
///
/// The insole only flags; the tester decides. A flagged moment stops for a
/// tester decision, and both the flag and the decision are saved, so every
/// trial also records how far the insole agreed with the tester.
class TestRunController extends ChangeNotifier {
  final TestRunConfig config;
  final MonotonicClock clock;
  final TrialStore store;
  final InsoleStatus Function() readInsole;

  final FlamingoSession flamingo = FlamingoSession();
  final VrikshasanaSession hold = VrikshasanaSession();

  StreamSubscription<TimedContactEvent>? _events;
  Timer? _ticker;
  DateTime? _startedAt;
  InsoleMode? _modeAtStart;
  FitnessTrial? _saved;
  bool _saveFailed = false;
  bool _disposed = false;

  TestRunController({
    required this.config,
    required this.clock,
    required this.store,
    required this.readInsole,
    required Stream<TimedContactEvent> events,
  }) {
    _events = events.listen(_onEvent);
  }

  bool get isFlamingo => config.test == FitnessTest.flamingo;
  bool get started => _startedAt != null;
  bool get finished => isFlamingo
      ? flamingo.phase == FlamingoPhase.finished
      : hold.phase == HoldPhase.finished;
  bool get inProgress => started && !finished;
  bool get checking => isFlamingo
      ? flamingo.phase == FlamingoPhase.checking
      : hold.phase == HoldPhase.checking;

  /// Fixed when the trial starts, so the record says how it was run.
  InsoleMode? get modeAtStart => _modeAtStart;
  FitnessTrial? get savedTrial => _saved;
  bool get saveFailed => _saveFailed;

  /// The test clock: balancing time, or hold time.
  int get clockMs =>
      isFlamingo ? flamingo.balanceMs(clock.nowMs) : hold.holdMs(clock.nowMs);
  int get clockLimitMs =>
      isFlamingo ? FlamingoRules.balanceMs : VrikshasanaRules.maxHoldMs;

  /// When the flag being checked happened, on the test clock.
  int? get flaggedAtMs => isFlamingo ? flamingo.flaggedAtMs : hold.flaggedAtMs;

  void start() {
    if (started) return;
    _startedAt = DateTime.now();
    _modeAtStart = readInsole().mode;
    if (isFlamingo) {
      flamingo.start(clock.nowMs);
    } else {
      hold.start(clock.nowMs);
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    _changed();
  }

  void testerLoss() {
    flamingo.testerLoss(clock.nowMs);
    _changed();
  }

  void resume() {
    flamingo.resume(clock.nowMs);
    _changed();
  }

  void stopHold() {
    hold.testerStop(clock.nowMs);
    _changed();
  }

  void confirmFlag() {
    if (isFlamingo) {
      flamingo.confirmFlag();
    } else {
      hold.confirmFlag();
    }
    _changed();
  }

  void dismissFlag() {
    if (isFlamingo) {
      flamingo.dismissFlag(clock.nowMs);
    } else {
      hold.dismissFlag(clock.nowMs);
    }
    _changed();
  }

  Future<void> deleteSavedTrial() async {
    final trial = _saved;
    if (trial != null) await store.delete(trial.id);
  }

  void _tick() {
    if (isFlamingo) {
      flamingo.tick(clock.nowMs);
    } else {
      hold.tick(clock.nowMs);
    }
    _changed();
  }

  void _onEvent(TimedContactEvent timed) {
    if (_modeAtStart != InsoleMode.watching || !timed.event.isFoot) return;
    final event = timed.event;
    // Flamingo: the held foot touching the ground. Vrikshasana: the raised
    // foot's sole letting go of the thigh.
    final flagged = isFlamingo
        ? event.isOn &&
            flamingo.insoleLoss(
                eventMs: timed.phoneMs,
                deviceMs: event.deviceMs,
                nowMs: clock.nowMs)
        : !event.isOn &&
            hold.insoleEnd(
                eventMs: timed.phoneMs,
                deviceMs: event.deviceMs,
                nowMs: clock.nowMs);
    if (flagged) {
      HapticFeedback.heavyImpact();
      _changed();
    }
  }

  void _changed() {
    if (_disposed) return;
    if (finished && _saved == null) _save();
    notifyListeners();
  }

  void _save() {
    _ticker?.cancel();
    final startedAt = _startedAt ?? DateTime.now();
    final trial = FitnessTrial(
      id: '${startedAt.microsecondsSinceEpoch}-${config.test.wireValue}',
      test: config.test,
      participantId: config.participantId,
      sessionId: config.sessionId,
      standingLeg: config.standingLeg,
      startedAt: startedAt,
      insoleMode: _modeAtStart ?? InsoleMode.notConnected,
      losses: isFlamingo ? flamingo.losses : const [],
      balanceMs: isFlamingo ? flamingo.balanceMs(clock.nowMs) : null,
      terminatedEarly: isFlamingo && flamingo.terminatedEarly,
      holdMs: isFlamingo ? null : hold.holdMs(clock.nowMs),
      holdEnd: isFlamingo ? null : hold.end,
      holdEndDeviceMs: isFlamingo ? null : hold.endDeviceMs,
      dismissedEndsAtMs: isFlamingo ? const [] : hold.dismissedAtMs,
    );
    _saved = trial;
    store.add(trial).catchError((Object _) {
      _saveFailed = true;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _events?.cancel();
    super.dispose();
  }
}
