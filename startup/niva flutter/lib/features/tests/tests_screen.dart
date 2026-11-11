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
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text('FIT INDIA · AGES 18–65', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Text('Balance tests', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('Choose a test. You run the clock and confirm every event.',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              _InsoleReadiness(status: insole),
              const SizedBox(height: 16),
              for (final test in FitnessTest.values) ...[
                _TestCard(
                    test: test, onTap: () => openSetup(context, ref, test)),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              const _SavedTrials(),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> openSetup(
      BuildContext context, WidgetRef ref, FitnessTest test) async {
    if (ref.read(settingsRepositoryProvider).experience.haptics) {
      HapticFeedback.selectionClick();
    }
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
                Text(watching ? 'Insole assistance ready' : 'Tester-only mode',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  watching
                      ? 'The insole will flag events on the raised foot. You confirm or '
                          'dismiss each flag.'
                      : 'You can time and count without an insole. '
                          'For assistance, connect and tare on the Device tab.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (!watching && status.mode != InsoleMode.notConnected) ...[
                  const SizedBox(height: 6),
                  Text(status.mode.now, style: theme.textTheme.bodySmall),
                ],
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
      onTap: onTap,
      excludeSemantics: true,
      child: RoundedCard(
        radius: 24,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    test == FitnessTest.flamingo
                        ? Icons.accessibility_new_rounded
                        : Icons.self_improvement_rounded,
                    color: theme.colorScheme.primary,
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
                      Text(test.protocolPage,
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: theme.textTheme.labelSmall?.color),
              ],
            ),
            const SizedBox(height: 16),
            Text(test.scoreRule, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              test == FitnessTest.flamingo
                  ? 'Stand on a beam and hold the raised foot. Count each loss of balance.'
                  : 'Hold the tree pose. Record how long the final position lasts.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.play_circle_outline_rounded,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Set up a trial',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: theme.colorScheme.primary))),
              ],
            ),
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
  final _participantFocus = FocusNode();
  StandingLeg _leg = StandingLeg.left;
  String? _participantError;

  @override
  void dispose() {
    _participant.dispose();
    _participantFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final id = _participant.text.trim();
    if (id.isEmpty) {
      setState(() => _participantError =
          'Enter an ID or roll number so the result can be found later');
      _participantFocus.requestFocus();
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Text(widget.test.title,
                              style: theme.textTheme.headlineMedium)),
                      IconButton(
                        tooltip: 'Close setup',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${widget.test.scoreRule} · ${widget.test.protocolPage}',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey('participant-id'),
                    controller: _participant,
                    focusNode: _participantFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_participantError != null) {
                        setState(() => _participantError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Participant ID or roll number',
                      helperText:
                          'Use an ID you can recognise in saved trials.',
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                      errorText: _participantError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Which leg will they stand on?',
                      style: theme.textTheme.titleMedium),
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
                  const SizedBox(height: 8),
                  Text(
                      'Stand on the ${_leg.label.toLowerCase()} leg. '
                      'Place the insole on the $raised foot.',
                      style: theme.textTheme.bodySmall),
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

class _SavedTrials extends ConsumerStatefulWidget {
  const _SavedTrials();

  @override
  ConsumerState<_SavedTrials> createState() => _SavedTrialsState();
}

class _SavedTrialsState extends ConsumerState<_SavedTrials> {
  final _search = TextEditingController();
  FitnessTest? _filter;
  bool _exporting = false;
  String? _exportError;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      final file = await ref.read(trialStoreProvider).exportCsvToFile();
      await Share.shareXFiles([XFile(file.path)], text: 'Niva fitness trials');
    } catch (_) {
      if (mounted) {
        setState(() => _exportError =
            'Could not export trials. Your results are still saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ref.watch(trialStoreProvider);

    return ListenableBuilder(
      listenable: store.changes,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final matches = store
            .recent(limit: store.count)
            .where((trial) =>
                (_filter == null || trial.test == _filter) &&
                trial.participantId.toLowerCase().contains(query))
            .toList();
        final trials = matches.take(30).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text('Saved trials', style: theme.textTheme.titleMedium),
                if (store.count > 0)
                  TextButton.icon(
                    onPressed: _exporting ? null : _export,
                    style:
                        TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    icon: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(_exporting
                        ? 'Exporting…'
                        : 'Export all (${store.count})'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_exportError != null) ...[
              Semantics(
                  liveRegion: true,
                  child: Text(_exportError!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error))),
              const SizedBox(height: 12),
            ],
            if (store.count > 0) ...[
              TextField(
                key: const ValueKey('trial-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Find a participant',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear participant search',
                          onPressed: () => setState(() => _search.clear()),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final test in <FitnessTest?>[null, ...FitnessTest.values])
                  FilterChip(
                    label: Text(test == null
                        ? 'All tests'
                        : test == FitnessTest.flamingo
                            ? 'Flamingo'
                            : 'Tree pose'),
                    selected: _filter == test,
                    onSelected: (_) => setState(() => _filter = test),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ]),
              const SizedBox(height: 8),
              Text(
                  matches.length > 30
                      ? 'Showing the latest 30 of ${matches.length} matching trials. '
                          'Export all to view every result.'
                      : '${matches.length} ${matches.length == 1 ? 'trial' : 'trials'} '
                          'saved on this phone',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
            ],
            if (store.count == 0)
              RoundedCard(
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 28, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Your first trial starts above',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                        'Choose a balance test. Finished trials appear here, '
                        'ready to review or export.',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              )
            else if (trials.isEmpty)
              RoundedCard(
                  radius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No matching trials',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Try another participant ID or show all tests.',
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: () => setState(() {
                                _search.clear();
                                _filter = null;
                              }),
                          child: const Text('Reset filters')),
                    ],
                  ))
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
      onTap: () => _openTrial(context),
      excludeSemantics: true,
      child: RoundedCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () => _openTrial(context),
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

  void _openTrial(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: TrialSummary(trial: trial),
        ),
      );
}
