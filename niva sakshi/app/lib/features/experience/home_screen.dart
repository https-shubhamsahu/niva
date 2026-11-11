import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/experience/experience_preferences.dart';
import '../../core/experience/experience_provider.dart';
import '../../core/fitness/fit_india_protocol.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../shared/widgets/health_layout.dart';
import '../../shared/widgets/motion.dart';
import '../station/practice_screen.dart';
import '../station/roster_screen.dart';
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
    final status = ref.watch(telemetryControllerProvider);
    final wide = isWideLayout(context);
    final startButton = FilledButton.icon(
        onPressed: trainer
            ? (onAssessments ??
                () => TestsScreen.openSetup(context, ref, FitnessTest.flamingo))
            : () => _joinPreview(context),
        icon: Icon(trainer ? Icons.play_arrow_rounded : Icons.link_rounded),
        label: Text(trainer ? 'Start assessment' : 'Join trainer'));
    return HealthPage(children: [
      HealthHeader(
          title: 'Summary',
          subtitle: 'Niva Sakshi · ${role.label}',
          trailing: IconButton.filledTonal(
              tooltip: 'Your experience and role',
              onPressed: () => openPreferences(context),
              icon: const Icon(Icons.person_outline_rounded))),
      RoundedCard(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: DashboardScreen()))),
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            status.isConnected
                ? LivePulse(
                    color: status.isMeasurementValid && !status.isDemo
                        ? AppColors.success
                        : AppColors.warning,
                    active: status.isMeasurementValid,
                    size: 8)
                : const Icon(Icons.sensors_off_rounded,
                    color: AppColors.lightLabelSecondary, size: 18),
            const SizedBox(width: 9),
            Expanded(
                child: Text(
                    status.isDemo
                        ? 'Demo insole · simulated readings'
                        : status.isConnected
                            ? (status.isMeasurementValid
                                ? 'Insole connected · valid'
                                : 'Insole connected · tare needed')
                            : 'Insole offline · tester-only available',
                    style: text.bodySmall)),
          ])),
      const SizedBox(height: 12),
      if (wide)
        _WideHero(trainer: trainer, button: startButton)
      else
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(22)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              trainer
                                  ? 'A moment of balance.'
                                  : 'Find your balance.',
                              style: text.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                              trainer
                                  ? 'Guide the test.\nKeep every decision.'
                                  : 'Your trainer guides the assessment.',
                              style: text.bodySmall),
                        ])),
                    const SizedBox(width: 12),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset('assets/photos/balance-park.jpg',
                            width: 68,
                            height: 60,
                            fit: BoxFit.cover,
                            alignment: const Alignment(-.25, 0),
                            excludeFromSemantics: true)),
                  ]),
                  const SizedBox(height: 14),
                  startButton,
                ])),
      HealthSection(trainer ? 'Assessments' : 'Your assessments'),
      RoundedCard(
          padding: EdgeInsets.zero,
          radius: 20,
          child: Column(children: [
            for (final test in FitnessTest.values) ...[
              HealthRow(
                  title: test == FitnessTest.flamingo
                      ? 'Flamingo balance'
                      : 'Tree pose',
                  subtitle: test == FitnessTest.flamingo
                      ? '60 seconds · count balance breaks'
                      : 'Vrikshasana · time the hold',
                  icon: test == FitnessTest.flamingo
                      ? Icons.accessibility_new_rounded
                      : Icons.self_improvement_rounded,
                  color: test == FitnessTest.flamingo
                      ? AppColors.coral
                      : AppColors.brand,
                  onTap: trainer
                      ? () => TestsScreen.openSetup(context, ref, test)
                      : null),
              if (test == FitnessTest.flamingo)
                const Divider(height: 1, indent: 62),
            ],
          ])),
      if (trainer) ...[
        const HealthSection('Your station'),
        RoundedCard(
            padding: EdgeInsets.zero,
            radius: 20,
            child: Row(children: [
              Expanded(
                  child: HealthRow(
                      title: 'Practice',
                      icon: Icons.self_improvement_rounded,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const PracticeScreen())))),
              Expanded(
                  child: HealthRow(
                      title: 'Class roster',
                      icon: Icons.people_outline_rounded,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const RosterScreen())))),
            ])),
        const HealthSection('Latest assessment'),
        _RecentTrials(onAssessments: onAssessments),
      ] else ...[
        const SizedBox(height: 16),
        Text(
            'Shared sessions will appear here when trainer pairing is available.',
            style: text.bodySmall),
      ],
    ]);
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

/// Desktop hero: the message and action on the left, the photograph given
/// real room on the right, instead of a full-width stretched button.
class _WideHero extends StatelessWidget {
  final bool trainer;
  final Widget button;
  const _WideHero({required this.trainer, required this.button});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
            height: 230,
            color: AppColors.brand.withValues(alpha: .08),
            child: Row(children: [
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 28, 24, 28),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                trainer
                                    ? 'A moment of balance.'
                                    : 'Find your balance.',
                                style: text.headlineMedium),
                            const SizedBox(height: 8),
                            Text(
                                trainer
                                    ? 'Guide the test. Keep every decision.'
                                    : 'Your trainer guides the assessment.',
                                style: text.bodyMedium),
                            const SizedBox(height: 22),
                            SizedBox(width: 260, child: button),
                          ]))),
              SizedBox(
                  width: 380,
                  child: Image.asset('assets/photos/balance-park.jpg',
                      fit: BoxFit.cover,
                      alignment: const Alignment(-.2, 0),
                      excludeFromSemantics: true)),
            ])));
  }
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
          final trials = store.recent(limit: 1);
          if (trials.isEmpty) {
            return RoundedCard(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.flag_outlined, color: AppColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('Your first assessment starts here.',
                          style: Theme.of(context).textTheme.bodySmall))
                ]));
          }
          final trial = trials.first;
          return RoundedCard(
              padding: EdgeInsets.zero,
              radius: 18,
              child: HealthRow(
                  title:
                      '${trial.participantId} · ${trial.test == FitnessTest.flamingo ? 'Flamingo' : 'Tree pose'}',
                  subtitle: trial.scoreLabel,
                  icon: Icons.check_circle_outline_rounded,
                  onTap: onAssessments));
        });
  }
}
