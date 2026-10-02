import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fitness/agreement_summary.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';

/// How the witnesses and the tester lined up across the Flamingo trials saved
/// on this phone. Counts only: agreement with a trained tester and with
/// slow-motion video is measured in the study, not computed here.
class AgreementScreen extends ConsumerWidget {
  const AgreementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final store = ref.watch(trialStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Witness record')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListenableBuilder(
              listenable: store.changes,
              builder: (context, _) {
                final s = AgreementSummary.of(store.recent(limit: store.count));
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Text(
                        'Across ${s.trials} saved Flamingo ${s.trials == 1 ? 'trial' : 'trials'} on this phone.',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _Row('Flagged, then counted by the teacher',
                        s.flaggedAndCounted),
                    _Row('Flagged, then dismissed by the teacher',
                        s.flaggedAndDismissed),
                    _Row('Counted by the teacher, never flagged', s.testerOnly),
                    const Divider(height: 28),
                    _Row('Insole flags', s.insoleFlags),
                    _Row('Beam flags', s.beamFlags),
                    _Row('Falls counted in total', s.countedFalls),
                    const SizedBox(height: 16),
                    Text(
                        'These are counts of what the teacher decided. They are not an accuracy figure. How closely the station agrees with a trained tester and with slow-motion video is measured separately.',
                        style: theme.textTheme.bodySmall),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final int value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoundedCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text('$value', style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}
