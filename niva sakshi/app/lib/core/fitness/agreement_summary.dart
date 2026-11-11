import 'fit_india_protocol.dart';
import 'fitness_trial.dart';

/// How the witnesses and the tester lined up across saved Flamingo trials.
///
/// Counts only. There is no accuracy percentage: agreement with a trained
/// tester and with slow-motion video is measured in the study (checks F1,
/// F6), not computed from tester decisions alone.
class AgreementSummary {
  final int trials;

  /// A witness flagged it and the tester counted it.
  final int flaggedAndCounted;

  /// A witness flagged it and the tester said it was not a fall.
  final int flaggedAndDismissed;

  /// The tester counted a loss no witness flagged.
  final int testerOnly;

  final int insoleFlags;
  final int beamFlags;

  const AgreementSummary({
    required this.trials,
    required this.flaggedAndCounted,
    required this.flaggedAndDismissed,
    required this.testerOnly,
    required this.insoleFlags,
    required this.beamFlags,
  });

  int get witnessFlags => flaggedAndCounted + flaggedAndDismissed;
  int get countedFalls => flaggedAndCounted + testerOnly;

  static AgreementSummary of(Iterable<FitnessTrial> all) {
    var trials = 0, counted = 0, dismissed = 0, tester = 0;
    var insole = 0, beam = 0;
    for (final t in all) {
      if (t.test != FitnessTest.flamingo) continue;
      trials++;
      counted += t.insoleConfirmed + t.beamConfirmed;
      dismissed += t.insoleDismissed + t.beamDismissed;
      tester += t.testerOnly;
      insole += t.insoleConfirmed + t.insoleDismissed;
      beam += t.beamConfirmed + t.beamDismissed;
    }
    return AgreementSummary(
      trials: trials,
      flaggedAndCounted: counted,
      flaggedAndDismissed: dismissed,
      testerOnly: tester,
      insoleFlags: insole,
      beamFlags: beam,
    );
  }
}
