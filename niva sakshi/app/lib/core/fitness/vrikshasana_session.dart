import 'dart:math' as math;

import 'fit_india_protocol.dart';

/// `ready` until the participant reaches the final position; `holding`
/// while the hold is timed; `checking` while the tester decides on an end
/// the insole flagged (the clock keeps running, because the hold may not
/// have ended); `finished` once the hold time is fixed.
enum HoldPhase { ready, holding, checking, finished }

enum HoldEnd { tester, insole, timeLimit }

extension HoldEndText on HoldEnd {
  String get label {
    switch (this) {
      case HoldEnd.tester:
        return 'Stopped by the tester';
      case HoldEnd.insole:
        return 'Ended when the raised foot left the thigh (insole, tester confirmed)';
      case HoldEnd.timeLimit:
        return 'Reached the 60 s maximum';
    }
  }

  String get wireValue => name;
}

/// The Vrikshasana hold clock, following p. 23: timing starts once the
/// final position is reached and the hold is recorded between 10 and 60 s.
///
/// Pure Dart with an injected clock, so every rule can be unit tested.
class VrikshasanaSession {
  HoldPhase _phase = HoldPhase.ready;
  int? _startMs;
  int? _holdMs;
  HoldEnd? _end;
  int? _endDeviceMs;
  final List<int> _dismissedAtMs = [];

  int? _flagAtMs;
  int? _flagDeviceMs;

  HoldPhase get phase => _phase;
  HoldEnd? get end => _end;
  int? get endDeviceMs => _endDeviceMs;

  /// Hold times at which the insole flagged an end the tester rejected.
  List<int> get dismissedAtMs => List.unmodifiable(_dismissedAtMs);

  /// Hold time of the flag being checked.
  int? get flaggedAtMs => _flagAtMs;

  /// Under the protocol's 10 s minimum: the protocol says to start again.
  bool get belowMinimum =>
      _holdMs != null && _holdMs! < VrikshasanaRules.minHoldMs;

  int holdMs(int nowMs) {
    final fixed = _holdMs;
    if (fixed != null) return fixed;
    final start = _startMs;
    if (start == null) return 0;
    return math.min(math.max(0, nowMs - start), VrikshasanaRules.maxHoldMs);
  }

  /// The participant has reached the final position.
  void start(int nowMs) {
    if (_phase != HoldPhase.ready) return;
    _startMs = nowMs;
    _phase = HoldPhase.holding;
  }

  /// Ends the hold at the 60 s maximum.
  void tick(int nowMs) {
    if (_phase != HoldPhase.holding) return;
    if (nowMs - _startMs! >= VrikshasanaRules.maxHoldMs) {
      _finish(VrikshasanaRules.maxHoldMs, HoldEnd.timeLimit, null);
    }
  }

  /// The tester saw the pose end.
  void testerStop(int nowMs) {
    tick(nowMs);
    if (_phase != HoldPhase.holding) return;
    _finish(holdMs(nowMs), HoldEnd.tester, null);
  }

  /// The insole saw the raised foot unload at [eventMs] on the phone clock.
  /// Returns whether the tester should now check it.
  bool insoleEnd(
      {required int eventMs, required int deviceMs, required int nowMs}) {
    if (_phase != HoldPhase.holding) return false;
    final start = _startMs!;
    if (eventMs < start) return false;
    final at = math.min(eventMs, nowMs) - start;
    if (at >= VrikshasanaRules.maxHoldMs) {
      tick(nowMs);
      return false;
    }
    _flagAtMs = at;
    _flagDeviceMs = deviceMs;
    _phase = HoldPhase.checking;
    return true;
  }

  /// The tester agrees the hold ended where the insole flagged it.
  void confirmFlag() {
    if (_phase != HoldPhase.checking) return;
    _finish(_flagAtMs!, HoldEnd.insole, _flagDeviceMs);
  }

  /// The participant is still in the pose: keep timing.
  void dismissFlag(int nowMs) {
    if (_phase != HoldPhase.checking) return;
    _dismissedAtMs.add(_flagAtMs!);
    _flagAtMs = null;
    _flagDeviceMs = null;
    _phase = HoldPhase.holding;
    tick(nowMs);
  }

  void _finish(int holdMs, HoldEnd end, int? deviceMs) {
    _holdMs = holdMs;
    _end = end;
    _endDeviceMs = deviceMs;
    _flagAtMs = null;
    _flagDeviceMs = null;
    _phase = HoldPhase.finished;
  }
}
