/// The two Fit India balance items Niva instruments.
///
/// Rules come from the Fit India Mission's "Fitness Protocols and Guidelines
/// for 18+ to 65 Years" (Ministry of Youth Affairs & Sports with the Ministry
/// of Health & Family Welfare). Page numbers are the document's own.
library;

enum FitnessTest { flamingo, vrikshasana }

extension FitnessTestText on FitnessTest {
  String get title {
    switch (this) {
      case FitnessTest.flamingo:
        return 'Flamingo balance';
      case FitnessTest.vrikshasana:
        return 'Vrikshasana (tree pose)';
    }
  }

  /// What the protocol records, in one line.
  String get scoreRule {
    switch (this) {
      case FitnessTest.flamingo:
        return 'Falls during 60 s of balancing on one leg';
      case FitnessTest.vrikshasana:
        return 'Hold time, 10 to 60 s, on each side';
    }
  }

  String get protocolPage {
    switch (this) {
      case FitnessTest.flamingo:
        return 'Fit India protocol, p. 24';
      case FitnessTest.vrikshasana:
        return 'Fit India protocol, p. 23';
    }
  }

  /// Where the insole goes and what it watches for.
  String get insolePlacement {
    switch (this) {
      case FitnessTest.flamingo:
        return 'Put the insole on the raised foot, the one the participant holds. '
            'It flags a loss of balance when that foot touches the ground.';
      case FitnessTest.vrikshasana:
        return 'Put the insole on the raised foot. Its sole presses the inner thigh '
            'of the standing leg; the insole flags the end of the hold when it lets go.';
    }
  }

  /// Neither item has a published benchmark to rate a result against.
  String get benchmarkNote {
    switch (this) {
      case FitnessTest.flamingo:
        return 'The protocol publishes no benchmark table for this test, so no level is shown.';
      case FitnessTest.vrikshasana:
        return 'The protocol says Vrikshasana benchmarks will be developed once enough '
            'data exist (p. 39), so no level is shown.';
    }
  }

  String get wireValue => name;
}

enum StandingLeg { left, right }

extension StandingLegText on StandingLeg {
  String get label => this == StandingLeg.left ? 'Left' : 'Right';
  StandingLeg get other =>
      this == StandingLeg.left ? StandingLeg.right : StandingLeg.left;
}

abstract final class FlamingoRules {
  /// p. 24: count the falls in 60 seconds of balancing.
  static const balanceMs = 60000;

  /// p. 24: if there are more than 15 falls in the first 30 seconds, the
  /// test is terminated.
  static const earlyWindowMs = 30000;
  static const earlyFallLimit = 15;
}

abstract final class VrikshasanaRules {
  /// p. 23: record hold time in (10-60) seconds; the minimum hold is 10 s
  /// after attaining the final position.
  static const minHoldMs = 10000;
  static const maxHoldMs = 60000;
}
