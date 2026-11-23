import 'dart:math' as math;

/// One-Leg Minute: a short, daily practice round on the same station as the
/// Flamingo test. It is practice, not a test: nothing here is a score, a
/// ranking or a claim that practice improves balance. The Fit India protocol
/// itself advises practising one-foot balance (5-18 p.21; 18-65 p.24).
///
/// Pure Dart with an injected clock. Each touch-down ends the current hold;
/// the child steps back up and the next hold starts when [resume] is called.
abstract final class OneLegMinuteRules {
  static const roundMs = 60000;
}

enum OneLegPhase { ready, holding, down, finished }

class OneLegMinuteRound {
  OneLegPhase _phase = OneLegPhase.ready;
  int _roundStartMs = 0;
  int? _holdStartMs;
  int _longestMs = 0;
  int _heldMs = 0;
  int _touchDowns = 0;

  OneLegPhase get phase => _phase;
  int get touchDowns => _touchDowns;
  int get longestHoldMs => _longestMs;

  /// Total time on one leg this round.
  int get heldMs => _heldMs;

  /// The round runs for 60 s from the first hold, including time spent back
  /// on two feet.
  int elapsedMs(int nowMs) => _phase == OneLegPhase.ready
      ? 0
      : math.min(nowMs - _roundStartMs, OneLegMinuteRules.roundMs);

  void start(int nowMs) {
    if (_phase != OneLegPhase.ready) return;
    _roundStartMs = nowMs;
    _holdStartMs = nowMs;
    _phase = OneLegPhase.holding;
  }

  /// The raised foot touched down (a chime on the station).
  void touchDown(int nowMs) {
    tick(nowMs);
    if (_phase != OneLegPhase.holding) return;
    _closeHold(nowMs);
    _touchDowns++;
    _phase = OneLegPhase.down;
  }

  /// Back on one leg.
  void resume(int nowMs) {
    tick(nowMs);
    if (_phase != OneLegPhase.down) return;
    _holdStartMs = nowMs;
    _phase = OneLegPhase.holding;
  }

  void tick(int nowMs) {
    if (_phase == OneLegPhase.ready || _phase == OneLegPhase.finished) return;
    if (nowMs - _roundStartMs >= OneLegMinuteRules.roundMs) {
      if (_phase == OneLegPhase.holding) {
        _closeHold(_roundStartMs + OneLegMinuteRules.roundMs);
      }
      _phase = OneLegPhase.finished;
    }
  }

  void _closeHold(int endMs) {
    final start = _holdStartMs;
    if (start == null) return;
    final length = math.max(0, endMs - start);
    _heldMs += length;
    _longestMs = math.max(_longestMs, length);
    _holdStartMs = null;
  }
}

/// The class's total one-leg time this session. There is deliberately no
/// per-child ranking: only a total and each child's own longest hold.
class ClassPractice {
  final Map<String, int> _longestByChild = {};
  int _totalMs = 0;

  ClassPractice copy() => ClassPractice()
    .._longestByChild.addAll(_longestByChild)
    .._totalMs = _totalMs;

  int get totalPracticeMs => _totalMs;
  int get children => _longestByChild.length;

  /// A child's own best hold this session.
  int? longestHoldMs(String rollId) => _longestByChild[rollId];

  void add(String rollId, OneLegMinuteRound finishedRound) {
    if (finishedRound.phase != OneLegPhase.finished) return;
    _totalMs += finishedRound.heldMs;
    _longestByChild[rollId] =
        math.max(_longestByChild[rollId] ?? 0, finishedRound.longestHoldMs);
  }
}
