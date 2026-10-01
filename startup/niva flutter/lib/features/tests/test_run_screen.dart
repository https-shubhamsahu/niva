import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fitness/fit_india_protocol.dart';
import '../../core/fitness/fitness_trial.dart';
import '../../core/fitness/flamingo_session.dart';
import '../../core/fitness/vrikshasana_session.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../theme/app_theme.dart';
import 'test_run_controller.dart';
import 'widgets/trial_summary.dart';

/// Full-screen runner for one trial. The tester drives the protocol with
/// one large button at a time; the insole, when it is watching, stops the
/// clock at a flagged moment and asks the tester to decide.
class TestRunScreen extends ConsumerStatefulWidget {
  final TestRunConfig config;

  const TestRunScreen({super.key, required this.config});

  @override
  ConsumerState<TestRunScreen> createState() => _TestRunScreenState();
}

class _TestRunScreenState extends ConsumerState<TestRunScreen> {
  late final TestRunController _run;

  @override
  void initState() {
    super.initState();
    _run = TestRunController(
      config: widget.config,
      clock: ref.read(monotonicClockProvider),
      store: ref.read(trialStoreProvider),
      readInsole: () => ref.read(insoleStatusProvider),
      events: ref.read(insoleEventsProvider),
    );
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop this trial?'),
        content: const Text(
            'The trial is not finished, so nothing from it will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep testing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop and discard',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _deleteTrial() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this trial?'),
        content: const Text(
            'It will be removed from this phone and from future exports.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run.deleteSavedTrial();
    if (mounted) Navigator.pop(context);
  }

  void _otherSide() =>
      _restartWith(widget.config.withLeg(widget.config.standingLeg.other));

  /// The protocol says to start again when a hold is under 10 s (p. 23).
  void _again() => _restartWith(widget.config);

  void _restartWith(TestRunConfig config) {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => TestRunScreen(config: config),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final insole = ref.watch(insoleStatusProvider);
    final config = widget.config;

    return ListenableBuilder(
      listenable: _run,
      builder: (context, _) {
        return PopScope(
          canPop: !_run.inProgress,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await _confirmDiscard()) navigator.pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                config.test.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            body: SafeArea(
              child: _run.finished
                  ? _ResultView(
                      run: _run,
                      onAgain: _again,
                      onOtherSide: config.test == FitnessTest.vrikshasana
                          ? _otherSide
                          : null,
                      onDone: () => Navigator.pop(context),
                      onDelete: _deleteTrial,
                    )
                  : _RunView(run: _run, insole: insole),
            ),
          ),
        );
      },
    );
  }
}

class _RunView extends StatelessWidget {
  final TestRunController run;
  final InsoleStatus insole;

  const _RunView({required this.run, required this.insole});

  @override
  Widget build(BuildContext context) {
    // The controls are pinned to the bottom, within thumb reach, so the
    // tester never has to scroll to act. The information above them scrolls
    // when space is short (small phones, landscape, large text).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Participant ${run.config.participantId} · standing on the '
                  '${run.config.standingLeg.label.toLowerCase()} leg',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                _InsoleLine(run: run, insole: insole),
                const SizedBox(height: 20),
                _ClockDisplay(run: run),
                if (run.isFlamingo) ...[
                  const SizedBox(height: 16),
                  _FallCounter(run: run),
                ],
                const SizedBox(height: 16),
                _PhasePrompt(run: run),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border:
                Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: _Actions(run: run),
          ),
        ),
      ],
    );
  }
}

/// What the insole is doing for this trial, plus a warning when its live
/// reading means it cannot see the event it watches for.
class _InsoleLine extends StatelessWidget {
  final TestRunController run;
  final InsoleStatus insole;

  const _InsoleLine({required this.run, required this.insole});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = run.modeAtStart ?? insole.mode;
    final watching = mode == InsoleMode.watching;

    String? warning;
    if (watching && run.started && !run.checking) {
      if (run.isFlamingo &&
          run.flamingo.phase == FlamingoPhase.running &&
          insole.footLoaded) {
        warning =
            'The raised foot reads loaded, so the insole cannot see a touchdown '
            'until it reads unloaded again. Keep counting.';
      }
      if (!run.isFlamingo &&
          run.hold.phase == HoldPhase.holding &&
          !insole.footLoaded) {
        warning =
            'The raised foot reads unloaded, so the insole cannot see the sole leave '
            'the thigh. Stop the clock yourself when the pose breaks.';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                watching ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                size: 18,
                color: watching
                    ? AppColors.brand
                    : theme.textTheme.labelSmall?.color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mode.now,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (warning != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: RoundedCard(
              radius: 14,
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.warning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(warning, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ClockDisplay extends StatelessWidget {
  final TestRunController run;

  const _ClockDisplay({required this.run});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ms = run.clockMs;
    final limitS = run.clockLimitMs ~/ 1000;
    final caption = run.isFlamingo
        ? 'of $limitS s balancing'
        : 'held, of $limitS s maximum';
    final seconds = formatSeconds(ms);

    return Semantics(
      label: run.isFlamingo
          ? 'Balancing time ${ms ~/ 1000} seconds of $limitS'
          : 'Hold time ${ms ~/ 1000} seconds',
      excludeSemantics: true,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  seconds,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 88,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Text('s', style: theme.textTheme.headlineMedium),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(caption, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (ms / run.clockLimitMs).clamp(0.0, 1.0),
              minHeight: 8,
              color: AppColors.brand,
              backgroundColor: theme.dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _FallCounter extends StatelessWidget {
  final TestRunController run;

  const _FallCounter({required this.run});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = run.flamingo;
    final watching = run.modeAtStart == InsoleMode.watching;
    return RoundedCard(
      radius: 20,
      child: Row(
        children: [
          Semantics(
            label: '${f.falls} ${f.falls == 1 ? 'fall' : 'falls'} counted',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FALLS', style: theme.textTheme.labelSmall),
                Text(
                  '${f.falls}',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              watching
                  ? 'Insole flagged and counted: ${f.insoleConfirmed}\n'
                      'Counted by the tester only: ${f.testerOnly}\n'
                      'Insole flags dismissed: ${f.insoleDismissed}'
                  : 'All falls are counted by the tester.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// One instruction for the tester, matching the protocol step in progress.
/// A live region, so a screen reader announces each change of step.
class _PhasePrompt extends StatelessWidget {
  final TestRunController run;

  const _PhasePrompt({required this.run});

  String _text() {
    final leg = run.config.standingLeg.label.toLowerCase();
    final raised = run.config.standingLeg.other.label.toLowerCase();
    final flagged = run.flaggedAtMs;
    if (run.isFlamingo) {
      switch (run.flamingo.phase) {
        case FlamingoPhase.ready:
          return 'The participant stands on the beam on the $leg leg and holds the $raised '
              'foot close to the buttocks. Start the clock as the instructor lets go.';
        case FlamingoPhase.running:
          return 'Tap Lost balance if they fall off the beam or let go of the held foot.';
        case FlamingoPhase.checking:
          return 'The insole flagged a touchdown of the raised foot at '
              '${formatSeconds(flagged ?? 0)} s. Was it a fall?';
        case FlamingoPhase.paused:
          return 'Fall counted and clock paused. Help the participant back into position, '
              'then resume as the instructor lets go.';
        case FlamingoPhase.finished:
          return 'Test finished.';
      }
    }
    switch (run.hold.phase) {
      case HoldPhase.ready:
        return 'The participant stands on the $leg leg with the $raised sole pressed on the '
            'inner thigh. Start when the arms are overhead in namaskar mudra.';
      case HoldPhase.holding:
        return 'Stop the hold when the pose breaks. The clock stops by itself at 60 s.';
      case HoldPhase.checking:
        return 'The insole says the raised foot left the thigh at '
            '${formatSeconds(flagged ?? 0)} s. Did the hold end there? The clock keeps '
            'running until you decide.';
      case HoldPhase.finished:
        return 'Test finished.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checking = run.checking;
    return Semantics(
      liveRegion: true,
      child: RoundedCard(
        radius: 20,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                checking
                    ? Icons.help_outline_rounded
                    : Icons.directions_rounded,
                color: checking ? AppColors.warning : AppColors.brand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_text(), style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// The controls for the current step: one primary action, or a pair when
/// the tester must decide on an insole flag.
class _Actions extends StatelessWidget {
  final TestRunController run;

  const _Actions({required this.run});

  @override
  Widget build(BuildContext context) {
    final flagged = formatSeconds(run.flaggedAtMs ?? 0);

    if (run.isFlamingo) {
      switch (run.flamingo.phase) {
        case FlamingoPhase.ready:
          return _BigButton(
              label: 'Start clock',
              icon: Icons.play_arrow_rounded,
              onPressed: run.start);
        case FlamingoPhase.running:
          return _BigButton(
            label: 'Lost balance',
            icon: Icons.front_hand_rounded,
            color: AppColors.danger,
            onPressed: run.testerLoss,
          );
        case FlamingoPhase.checking:
          return _DecisionButtons(
            confirmLabel: 'Count fall',
            dismissLabel: 'Not a fall',
            onConfirm: run.confirmFlag,
            onDismiss: run.dismissFlag,
          );
        case FlamingoPhase.paused:
          return _BigButton(
              label: 'Resume clock',
              icon: Icons.play_arrow_rounded,
              onPressed: run.resume);
        case FlamingoPhase.finished:
          return const SizedBox.shrink();
      }
    }
    switch (run.hold.phase) {
      case HoldPhase.ready:
        return _BigButton(
            label: 'Start hold',
            icon: Icons.play_arrow_rounded,
            onPressed: run.start);
      case HoldPhase.holding:
        return _BigButton(
            label: 'Stop hold',
            icon: Icons.stop_rounded,
            onPressed: run.stopHold);
      case HoldPhase.checking:
        return _DecisionButtons(
          confirmLabel: 'End hold at $flagged s',
          dismissLabel: 'Still holding',
          onConfirm: run.confirmFlag,
          onDismiss: run.dismissFlag,
        );
      case HoldPhase.finished:
        return const SizedBox.shrink();
    }
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(72),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      icon: Icon(icon, size: 28),
      label: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _DecisionButtons extends StatelessWidget {
  final String confirmLabel;
  final String dismissLabel;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _DecisionButtons({
    required this.confirmLabel,
    required this.dismissLabel,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    const textStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            onConfirm();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(64),
            shape: shape,
            textStyle: textStyle,
          ),
          child: Text(confirmLabel, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onDismiss();
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            shape: shape,
            textStyle: textStyle,
          ),
          child: Text(dismissLabel, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  final TestRunController run;
  final VoidCallback onAgain;
  final VoidCallback? onOtherSide;
  final VoidCallback onDone;
  final VoidCallback onDelete;

  const _ResultView({
    required this.run,
    required this.onAgain,
    required this.onOtherSide,
    required this.onDone,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trial = run.savedTrial;
    if (trial == null) return const SizedBox.shrink();
    final leg = run.config.standingLeg.label.toLowerCase();
    final otherLeg = run.config.standingLeg.other.label.toLowerCase();
    // Under the 10 s minimum the protocol says to start again, so that
    // becomes the main action and the other side drops to second.
    final retry = trial.holdBelowMinimum;
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    const buttonText = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        RoundedCard(radius: 24, child: TrialSummary(trial: trial)),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  run.saveFailed
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: run.saveFailed ? AppColors.danger : AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  run.saveFailed
                      ? 'Could not save this trial on the phone. Note the result by hand.'
                      : 'Saved on this phone. Export it from the Tests tab.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (retry) ...[
          FilledButton(
            onPressed: onAgain,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(64),
              shape: buttonShape,
              textStyle: buttonText,
            ),
            child:
                Text('Try again on the $leg leg', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
        ],
        if (onOtherSide != null) ...[
          if (retry)
            OutlinedButton(
              onPressed: onOtherSide,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: buttonShape,
              ),
              child: Text('Test the other side (stand on $otherLeg)',
                  textAlign: TextAlign.center),
            )
          else
            FilledButton(
              onPressed: onOtherSide,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(64),
                shape: buttonShape,
                textStyle: buttonText,
              ),
              child: Text('Test the other side (stand on $otherLeg)',
                  textAlign: TextAlign.center),
            ),
          const SizedBox(height: 8),
          Text(
            'Move the insole to the new raised foot first.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton(
          onPressed: onDone,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Done'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onDelete,
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Delete this trial',
              style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }
}
