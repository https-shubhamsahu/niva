import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/experience/experience_preferences.dart';
import '../../core/experience/experience_provider.dart';
import '../../core/fitness/fit_india_protocol.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../shared/widgets/sneaker_mascot.dart';
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../tests/tests_screen.dart';
import 'preferences_screen.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onAssessments;
  const HomeScreen({super.key, this.onAssessments});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(experienceProvider).role ?? AppRole.trainer;
    final trainer = role == AppRole.trainer;
    final text = Theme.of(context).textTheme;
    return SafeArea(
        child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(children: [
                Image.asset('assets/brand/niva-lockup.png',
                    width: 112,
                    height: 60,
                    fit: BoxFit.contain,
                    semanticLabel: 'Niva'),
                const Spacer(),
                IconButton.filledTonal(
                    tooltip: 'Your experience and role',
                    onPressed: () => openPreferences(context),
                    icon: const Icon(Icons.person_outline_rounded)),
              ]),
              const SizedBox(height: 18),
              Text('${role.label.toUpperCase()} SPACE', style: text.labelSmall),
              const SizedBox(height: 8),
              Text(trainer ? 'Ready, set, balance.' : 'Find your balance.',
                  style: text.headlineMedium
                      ?.copyWith(fontSize: 32, letterSpacing: -1)),
              const SizedBox(height: 20),
              WelcomeReveal(
                  child: Container(
                decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(32)),
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                                child: Text('One step\nat a time.',
                                    style: text.headlineMedium)),
                            const SneakerMascot(size: 115),
                          ]),
                      const SizedBox(height: 8),
                      Text(trainer
                          ? 'A clear start. A focused assessment. A result you can keep.'
                          : 'Your trainer guides the test. You bring the focus. I’ll bring the energy.'),
                      const SizedBox(height: 20),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: trainer
                                ? onAssessments
                                : () => _joinPreview(context),
                            icon: Icon(trainer
                                ? Icons.play_arrow_rounded
                                : Icons.link_rounded),
                            label: Text(
                                trainer ? 'Start assessment' : 'Join trainer'),
                          )),
                    ]),
              )),
              const SizedBox(height: 28),
              Text(trainer ? 'Choose your focus' : 'Know your assessment',
                  style: text.titleMedium),
              const SizedBox(height: 12),
              for (final test in FitnessTest.values) ...[
                RoundedCard(
                    onTap: trainer
                        ? () => TestsScreen.openSetup(context, ref, test)
                        : null,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: test == FitnessTest.flamingo
                                      ? AppColors.coral
                                      : AppColors.lime,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Icon(
                                  test == FitnessTest.flamingo
                                      ? Icons.accessibility_new_rounded
                                      : Icons.self_improvement_rounded,
                                  color: AppColors.ink)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    test == FitnessTest.flamingo
                                        ? 'Flamingo balance'
                                        : 'Tree pose',
                                    style: text.titleMedium),
                                const SizedBox(height: 6),
                                Text(test == FitnessTest.flamingo
                                    ? 'Balance for 60 seconds. Trainer counts each fall.'
                                    : 'Hold Vrikshasana. Trainer records your time.'),
                              ])),
                        ])),
                const SizedBox(height: 12),
              ],
              if (trainer) ...[
                const SizedBox(height: 12),
                Text('Recent on this phone', style: text.titleMedium),
                const SizedBox(height: 12),
                _RecentTrials(onAssessments: onAssessments),
                const SizedBox(height: 12),
                TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                const Scaffold(body: DashboardScreen()))),
                    icon: const Icon(Icons.sensors_rounded),
                    label: const Text('Live insole readings')),
              ] else ...[
                const SizedBox(height: 12),
                const RoundedCard(
                    child: Text(
                        'Your trainer runs the clock and confirms the result. Shared sessions will appear here once pairing is available.')),
              ],
            ]),
      ),
    ));
  }

  void _joinPreview(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pairing is coming next',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                const Text(
                    'This preview has the new participant home. Joining a trainer over Wi-Fi or the internet is still being built. For now, your trainer can run and save assessments on their phone.'),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'))),
              ]),
        )),
      );
}

class _RecentTrials extends ConsumerWidget {
  final VoidCallback? onAssessments;
  const _RecentTrials({this.onAssessments});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(trialStoreProvider);
    return ListenableBuilder(
        listenable: store.changes,
        builder: (context, _) {
          final trials = store.recent(limit: 2);
          if (trials.isEmpty) {
            return const RoundedCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.flag_outlined, color: AppColors.brand),
                  SizedBox(height: 12),
                  Text('Your first assessment starts here.'),
                  SizedBox(height: 6),
                  Text(
                      'Completed trials will appear here. Every starting point counts.'),
                ]));
          }
          return Column(children: [
            for (final trial in trials)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RoundedCard(
                      onTap: onAssessments,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${trial.participantId} · ${trial.test == FitnessTest.flamingo ? 'Flamingo' : 'Tree pose'}',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(trial.scoreLabel),
                            Text(
                                '${trial.standingLeg.name} leg · ${trial.startedAt.toLocal().toString().substring(0, 16)}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]))),
          ]);
        });
  }
}
