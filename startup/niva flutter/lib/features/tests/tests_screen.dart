import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/fitness/fit_india_protocol.dart';
import '../../core/fitness/fitness_trial.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../theme/app_theme.dart';
import 'test_run_controller.dart';
import 'test_run_screen.dart';
import 'widgets/trial_summary.dart';

/// "Tests" tab: the two Fit India balance items Niva instruments, the
/// insole's readiness, and the trials saved on this phone.
class TestsScreen extends ConsumerWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insole = ref.watch(insoleStatusProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Tests', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Fit India fitness protocol, ages 18 to 65',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          _InsoleReadiness(status: insole),
          const SizedBox(height: 16),
          for (final test in FitnessTest.values) ...[
            _TestCard(test: test, onTap: () => _openSetup(context, ref, test)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          const _SavedTrials(),
        ],
      ),
    );
  }

  Future<void> _openSetup(
      BuildContext context, WidgetRef ref, FitnessTest test) async {
    HapticFeedback.selectionClick();
    final config = await showModalBottomSheet<TestRunConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SetupSheet(
        test: test,
        sessionId: ref.read(settingsRepositoryProvider).sessionId,
      ),
    );
    if (config == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TestRunScreen(config: config),
    ));
  }
}

class _InsoleReadiness extends StatelessWidget {
  final InsoleStatus status;

  const _InsoleReadiness({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watching = status.mode == InsoleMode.watching;
    return RoundedCard(
      radius: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              watching ? Icons.sensors_rounded : Icons.sensors_off_rounded,
              color: watching ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(watching ? 'INSOLE READY' : 'TESTER ONLY',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(
                  watching
                      ? 'The insole will flag events on the raised foot. You confirm or '
                          'dismiss each flag.'
                      : '${status.mode.now} To add the insole, connect and tare it on the '
                          'Device tab.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final FitnessTest test;
  final VoidCallback onTap;

  const _TestCard({required this.test, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${test.title}. ${test.scoreRule}. Set up a trial.',
      excludeSemantics: true,
      child: RoundedCard(
        radius: 24,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                test == FitnessTest.flamingo
                    ? Icons.accessibility_new_rounded
                    : Icons.self_improvement_rounded,
                color: AppColors.brand,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(test.scoreRule, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(test.protocolPage, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.textTheme.labelSmall?.color),
          ],
        ),
      ),
    );
  }
}

class _SetupSheet extends ConsumerStatefulWidget {
  final FitnessTest test;
  final String sessionId;

  const _SetupSheet({required this.test, required this.sessionId});

  @override
  ConsumerState<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends ConsumerState<_SetupSheet> {
  final _participant = TextEditingController();
  StandingLeg _leg = StandingLeg.left;
  String? _participantError;

  @override
  void dispose() {
    _participant.dispose();
    super.dispose();
  }

  void _submit() {
    final id = _participant.text.trim();
    if (id.isEmpty) {
      setState(() => _participantError =
          'Enter an ID or roll number so the result can be found later');
      return;
    }
    Navigator.pop(
      context,
      TestRunConfig(
        test: widget.test,
        participantId: id,
        standingLeg: _leg,
        sessionId: widget.sessionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insole = ref.watch(insoleStatusProvider);
    final raised = _leg.other.label.toLowerCase();

    // The fields scroll when space is short; the button stays pinned above
    // the keyboard, so the ID can be typed and the test opened in one go.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.test.title,
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('${widget.test.scoreRule} · ${widget.test.protocolPage}',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _participant,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_participantError != null) {
                        setState(() => _participantError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Participant ID or roll number',
                      errorText: _participantError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('STANDING LEG', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<StandingLeg>(
                    segments: const [
                      ButtonSegment(
                          value: StandingLeg.left, label: Text('Left')),
                      ButtonSegment(
                          value: StandingLeg.right, label: Text('Right')),
                    ],
                    selected: {_leg},
                    showSelectedIcon: true,
                    onSelectionChanged: (selection) =>
                        setState(() => _leg = selection.first),
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InsoleCheck(
                      test: widget.test, status: insole, raisedFoot: raised),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              child: const Text('Open the test'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the insole goes, and whether its live reading is what this test
/// needs before it starts.
class _InsoleCheck extends StatelessWidget {
  final FitnessTest test;
  final InsoleStatus status;
  final String raisedFoot;

  const _InsoleCheck(
      {required this.test, required this.status, required this.raisedFoot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watching = status.mode == InsoleMode.watching;

    String reading;
    bool ok;
    if (!watching) {
      reading = status.mode.now;
      ok = false;
    } else if (test == FitnessTest.flamingo) {
      ok = !status.footLoaded;
      reading = ok
          ? 'The raised foot reads unloaded, as it should while held.'
          : 'The raised foot reads loaded. The insole sees a touchdown only after it reads unloaded.';
    } else {
      ok = status.footLoaded;
      reading = ok
          ? 'The raised foot reads loaded: the sole is pressing the thigh.'
          : 'The raised foot reads unloaded. It should read loaded once the sole presses the thigh.';
    }

    // Tinted rather than a card: inside the sheet a card would be the same
    // colour as the sheet itself and lose its edges.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INSOLE ON THE ${raisedFoot.toUpperCase()} FOOT',
              style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(test.insolePlacement, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    ok
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: ok ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(reading, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedTrials extends ConsumerWidget {
  const _SavedTrials();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final store = ref.watch(trialStoreProvider);

    return ListenableBuilder(
      listenable: store.changes,
      builder: (context, _) {
        final trials = store.recent(limit: 30);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('SAVED ON THIS PHONE',
                        style: theme.textTheme.labelSmall)),
                if (trials.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      final file = await store.exportCsvToFile();
                      await Share.shareXFiles([XFile(file.path)],
                          text: 'Niva fitness trials');
                    },
                    style:
                        TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text('Export ${store.count}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (trials.isEmpty)
              RoundedCard(
                radius: 20,
                child: Text(
                  'No trials yet. Finished trials are saved here and can be exported as CSV.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              for (final trial in trials) ...[
                _TrialRow(trial: trial),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }
}

class _TrialRow extends StatelessWidget {
  final FitnessTrial trial;

  const _TrialRow({required this.trial});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = MaterialLocalizations.of(context);
    final time = '${when.formatShortDate(trial.startedAt)}, '
        '${when.formatTimeOfDay(TimeOfDay.fromDateTime(trial.startedAt))}';
    return Semantics(
      button: true,
      label: '${trial.participantId}, ${trial.test.title}, standing on the '
          '${trial.standingLeg.label.toLowerCase()} leg, ${trial.scoreLabel}, $time',
      excludeSemantics: true,
      child: RoundedCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: TrialSummary(trial: trial),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trial.participantId, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${trial.test.title} · ${trial.standingLeg.label} leg · $time',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Flexible, so a large text size wraps the score instead of
            // pushing the row off the screen.
            Flexible(
              flex: 2,
              child: Text(
                trial.scoreLabel,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
