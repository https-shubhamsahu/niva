import 'dart:math' as math;

import 'fit_india_protocol.dart';

/// `ready` before the instructor first lets go; `running` while the clock
/// counts balancing time; `checking` while the tester decides on a loss the
/// insole flagged; `paused` after a counted fall, until the participant is
/// back in position; `finished` at 60 s of balancing or early termination.
enum FlamingoPhase { ready, running, checking, paused, finished }

/// Who saw a loss of balance, and what the tester decided.
enum LossSource {
  /// The insole flagged it and the tester counted it.
  insoleConfirmed,

  /// The insole flagged it and the tester said it was not a fall. Kept for
  /// the agreement record; not counted.
  insoleDismissed,

  /// The tester counted it and the insole had not flagged it.
  tester,
}

extension LossSourceWire on LossSource {
  String get code {
    switch (this) {
      case LossSource.insoleConfirmed:
        return 'C';
      case LossSource.insoleDismissed:
        return 'D';
      case LossSource.tester:
        return 'T';
    }
  }

  static LossSource? fromCode(String code) {
    for (final source in LossSource.values) {
      if (source.code == code) return source;
    }
    return null;
  }
}

class BalanceLoss {
  /// Balancing time on the test clock when it happened.
  final int atMs;

  /// The insole's own timestamp, when the insole flagged it.
  final int? deviceMs;
  final LossSource source;

  const BalanceLoss({required this.atMs, required this.source, this.deviceMs});

  bool get counted => source != LossSource.insoleDismissed;
}

/// The Flamingo test clock and fall count, following p. 24: the watch runs
/// while the participant balances, pauses at each loss of balance, resumes
/// when the instructor lets go again, and stops at 60 s of balancing.
///
/// Pure Dart with an injected clock, so every rule can be unit tested.
class FlamingoSession {
  FlamingoPhase _phase = FlamingoPhase.ready;
  int _bankedMs = 0;
  int? _segmentStartMs;
  bool _terminatedEarly = false;
  final List<BalanceLoss> _losses = [];

  // While checking: the flag, and the clock state to restore if dismissed.
  int? _flagAtMs;
  int? _flagDeviceMs;
  int? _restoreSegmentStartMs;
  int _restoreBankedMs = 0;

  FlamingoPhase get phase => _phase;
  List<BalanceLoss> get losses => List.unmodifiable(_losses);
  bool get terminatedEarly => _terminatedEarly;
  int get falls => _losses.where((l) => l.counted).length;
  int get insoleConfirmed => _count(LossSource.insoleConfirmed);
  int get insoleDismissed => _count(LossSource.insoleDismissed);
  int get testerOnly => _count(LossSource.tester);

  /// Balancing time of the flag being checked.
  int? get flaggedAtMs => _flagAtMs;

  int balanceMs(int nowMs) {
    final start = _segmentStartMs;
    final running = start == null ? 0 : math.max(0, nowMs - start);
    return math.min(_bankedMs + running, FlamingoRules.balanceMs);
  }

  /// The instructor lets go for the first time.
  void start(int nowMs) {
    if (_phase != FlamingoPhase.ready) return;
    _segmentStartMs = nowMs;
    _phase = FlamingoPhase.running;
  }

  /// The participant is back in position and the instructor lets go.
  void resume(int nowMs) {
    if (_phase != FlamingoPhase.paused) return;
    _segmentStartMs = nowMs;
    _phase = FlamingoPhase.running;
  }

  /// Ends the test once 60 s of balancing have been timed.
  void tick(int nowMs) {
    if (_phase != FlamingoPhase.running) return;
    if (balanceMs(nowMs) >= FlamingoRules.balanceMs) {
      _bankedMs = FlamingoRules.balanceMs;
      _segmentStartMs = null;
      _phase = FlamingoPhase.finished;
    }
  }

  /// The tester saw a loss of balance the insole did not flag.
  void testerLoss(int nowMs) {
    tick(nowMs);
    if (_phase != FlamingoPhase.running) return;
    _stopClock(nowMs);
    _record(BalanceLoss(atMs: _bankedMs, source: LossSource.tester));
  }

  /// The insole saw the raised foot touch the ground at [eventMs] on the
  /// phone clock. Returns whether the clock stopped for the tester to check.
  ///
  /// A touchdown from before the current balancing segment is ignored: the
  /// foot was still down when the instructor let go, and the event only
  /// arrived afterwards.
  bool insoleLoss(
      {required int eventMs, required int deviceMs, required int nowMs}) {
    if (_phase != FlamingoPhase.running) return false;
    final start = _segmentStartMs!;
    if (eventMs < start) return false;
    final at = math.min(eventMs, nowMs);
    if (balanceMs(at) >= FlamingoRules.balanceMs) {
      tick(nowMs);
      return false;
    }
    _restoreSegmentStartMs = start;
    _restoreBankedMs = _bankedMs;
    _stopClock(at);
    _flagAtMs = _bankedMs;
    _flagDeviceMs = deviceMs;
    _phase = FlamingoPhase.checking;
    return true;
  }

  /// The tester agrees the flagged moment was a fall.
  void confirmFlag() {
    if (_phase != FlamingoPhase.checking) return;
    final loss = BalanceLoss(
      atMs: _flagAtMs!,
      deviceMs: _flagDeviceMs,
      source: LossSource.insoleConfirmed,
    );
    _clearFlag();
    _record(loss);
  }

  /// The tester saw no fall. The dismissal is kept for the agreement record,
  /// and the clock carries on as if it never stopped, because the
  /// participant kept balancing the whole time.
  void dismissFlag(int nowMs) {
    if (_phase != FlamingoPhase.checking) return;
    _losses.add(BalanceLoss(
      atMs: _flagAtMs!,
      deviceMs: _flagDeviceMs,
      source: LossSource.insoleDismissed,
    ));
    _bankedMs = _restoreBankedMs;
    _segmentStartMs = _restoreSegmentStartMs;
    _clearFlag();
    _phase = FlamingoPhase.running;
    tick(nowMs);
  }

  void _stopClock(int atMs) {
    _bankedMs = balanceMs(atMs);
    _segmentStartMs = null;
  }

  void _record(BalanceLoss loss) {
    _losses.add(loss);
    final early = _losses
        .where((l) => l.counted && l.atMs <= FlamingoRules.earlyWindowMs)
        .length;
    if (early > FlamingoRules.earlyFallLimit) {
      _terminatedEarly = true;
      _phase = FlamingoPhase.finished;
      return;
    }
    _phase = FlamingoPhase.paused;
  }

  void _clearFlag() {
    _flagAtMs = null;
    _flagDeviceMs = null;
    _restoreSegmentStartMs = null;
    _restoreBankedMs = 0;
  }

  int _count(LossSource source) =>
      _losses.where((l) => l.source == source).length;
}
