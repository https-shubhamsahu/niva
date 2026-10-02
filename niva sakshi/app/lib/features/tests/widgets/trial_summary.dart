import 'package:flutter/material.dart';

import '../../../core/fitness/fit_india_protocol.dart';
import '../../../core/fitness/fitness_trial.dart';
import '../../../core/fitness/vrikshasana_session.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/widgets/health_layout.dart';

/// A finished trial: the protocol score first, then what the insole and the
/// tester each contributed, then what the result cannot be compared with.
/// Used on the result screen and in the saved-results list.
class TrialSummary extends StatelessWidget {
  final FitnessTrial trial;
  final bool compact;

  const TrialSummary({super.key, required this.trial, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flamingo = trial.test == FitnessTest.flamingo;
    final bigNumber =
        flamingo ? '${trial.falls}' : formatSeconds(trial.holdMs ?? 0);
    final unit = flamingo ? (trial.falls == 1 ? 'fall' : 'falls') : 's hold';

    final facts = <_Fact>[
      if (flamingo && trial.terminatedEarly)
        const _Fact(Icons.stop_circle_outlined,
            'Stopped early: more than 15 falls in the first 30 s of balancing (p. 24).')
      else if (flamingo)
        _Fact(Icons.timer_outlined,
            'Timed ${formatSeconds(trial.balanceMs ?? 0)} s of balancing.'),
      if (!flamingo && trial.holdEnd != null)
        _Fact(Icons.flag_outlined, trial.holdEnd!.label),
      if (!flamingo && trial.holdBelowMinimum)
        const _Fact(Icons.replay_rounded,
            "Under the protocol's 10 s minimum hold. The protocol says to start again (p. 23).",
            emphasis: true),
      if (trial.insoleMode == InsoleMode.watching && flamingo)
        _Fact(
          Icons.sensors_rounded,
          'Insole flagged ${trial.insoleConfirmed + trial.insoleDismissed}: the tester counted '
          '${trial.insoleConfirmed} and dismissed ${trial.insoleDismissed}. The tester counted '
          '${trial.testerOnly} the insole did not flag.',
        ),
      if (trial.insoleMode == InsoleMode.watching && !flamingo)
        _Fact(
          Icons.sensors_rounded,
          trial.dismissedEndsAtMs.isEmpty
              ? 'The insole flagged no ends the tester rejected.'
              : 'The insole flagged ${trial.dismissedEndsAtMs.length} earlier '
                  '${trial.dismissedEndsAtMs.length == 1 ? 'end' : 'ends'} the tester rejected.',
        ),
      if (trial.insoleMode != InsoleMode.watching)
        _Fact(Icons.sensors_off_rounded, trial.insoleMode.label),
      _Fact(Icons.info_outline_rounded, trial.test.benchmarkNote),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '${trial.test.title} result: $bigNumber $unit',
          excludeSemantics: true,
          // Scales down rather than overflowing on a narrow screen with a
          // large text size.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  bigNumber,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 56,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Text(unit, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${trial.test.title} · standing on the ${trial.standingLeg.label.toLowerCase()} leg'
          ' · participant ${trial.participantId}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        for (final fact in (compact
            ? facts.take(trial.holdBelowMinimum ? 2 : 1)
            : facts)) ...[
          fact,
          const SizedBox(height: 10),
        ],
        if (compact)
          TextButton.icon(
              onPressed: () => openHealthDetails(
                  context, 'Trial details', TrialSummary(trial: trial)),
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('View full record')),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool emphasis;

  const _Fact(this.icon, this.text, {this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(icon,
              size: 20,
              color: emphasis
                  ? AppColors.warning
                  : theme.textTheme.labelSmall?.color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
