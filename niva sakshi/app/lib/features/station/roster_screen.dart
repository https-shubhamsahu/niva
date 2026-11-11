import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fitness/fit_india_protocol.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../tests/test_run_controller.dart';
import '../tests/test_run_screen.dart';
import 'station_providers.dart';

/// A class queue for the Flamingo station. Roll IDs only: no names, no
/// photos. The teacher pastes the IDs once; the next child is one tap away.
class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key});

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  final _controller = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runNext(String id) async {
    final sessionId = ref.read(settingsRepositoryProvider).sessionId;
    final before = ref.read(trialStoreProvider).count;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TestRunScreen(
        config: TestRunConfig(
          test: FitnessTest.flamingo,
          participantId: id,
          standingLeg: StandingLeg.left,
          sessionId: sessionId,
        ),
      ),
    ));
    if (!mounted) return;
    // A trial was saved while the run screen was open: this child is done.
    if (ref.read(trialStoreProvider).count > before) {
      ref.read(rosterProvider.notifier).markDone(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roster = ref.watch(rosterProvider);
    final next = roster.next;

    return Scaffold(
      appBar: AppBar(title: const Text('Class roster'), actions: [
        if (roster.total > 0)
          IconButton(
              tooltip: 'Edit class',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = !_editing)),
      ]),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (roster.total == 0 || _editing) ...[
                  Text('Roll IDs only · one per line, or separated by commas.',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Roll IDs',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ref
                              .read(rosterProvider.notifier)
                              .replaceWith(_controller.text);
                          _controller.clear();
                          setState(() => _editing = false);
                          FocusScope.of(context).unfocus();
                        },
                        child: const Text('Set class'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: roster.total == 0
                          ? null
                          : () => ref.read(rosterProvider.notifier).clear(),
                      child: const Text('Clear'),
                    ),
                  ]),
                  const SizedBox(height: 20),
                ],
                if (roster.total == 0)
                  Text('No class set yet.', style: theme.textTheme.bodyMedium)
                else ...[
                  RoundedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${roster.doneCount} of ${roster.total} tested',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 10),
                        if (next != null)
                          FilledButton(
                            onPressed: () => _runNext(next),
                            child: Text('Flamingo test for $next'),
                          )
                        else
                          Text('Everyone in this class has a saved trial.',
                              style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final id in roster.all)
                    ListTile(
                      dense: true,
                      leading: Icon(roster.isDone(id)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked),
                      title: Text(id),
                      trailing: roster.isDone(id)
                          ? TextButton(
                              onPressed: () =>
                                  ref.read(rosterProvider.notifier).reopen(id),
                              child: const Text('Test again'),
                            )
                          : TextButton(
                              onPressed: () => _runNext(id),
                              child: const Text('Test now'),
                            ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
