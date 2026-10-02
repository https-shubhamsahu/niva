import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niva/core/data/settings_repository.dart';
import 'package:niva/core/fitness/beam_event.dart';
import 'package:niva/core/fitness/fit_india_protocol.dart';
import 'package:niva/core/fitness/fitness_trial.dart';
import 'package:niva/core/fitness/flamingo_session.dart';
import 'package:niva/core/models/gait_metrics.dart';
import 'package:niva/core/providers/app_providers.dart';
import 'package:niva/features/station/agreement_screen.dart';
import 'package:niva/features/station/practice_screen.dart';
import 'package:niva/features/station/roster_screen.dart';
import 'package:niva/features/tests/test_run_controller.dart';
import 'package:niva/features/tests/test_run_screen.dart';
import 'package:niva/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void main() {
  late FakeClock clock;
  late MemoryTrialStore store;
  late SettingsRepository settings;
  late StreamController<TimedBeamEvent> beam;
  late StreamController<TimedContactEvent> events;

  setUp(() async {
    clock = FakeClock();
    store = MemoryTrialStore();
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository();
    await settings.init();
    beam = StreamController<TimedBeamEvent>.broadcast();
    events = StreamController<TimedContactEvent>.broadcast();
  });

  tearDown(() {
    beam.close();
    events.close();
  });

  Widget app(Widget home) => ProviderScope(
        overrides: [
          monotonicClockProvider.overrideWithValue(clock),
          trialStoreProvider.overrideWithValue(store),
          settingsRepositoryProvider.overrideWithValue(settings),
          insoleStatusProvider.overrideWithValue(InsoleStatus.disconnected),
          insoleEventsProvider.overrideWithValue(events.stream),
          beamEventsProvider.overrideWithValue(beam.stream),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!),
          home: home,
        ),
      );

  testWidgets('a beam flag stops the clock and the teacher counts it',
      (tester) async {
    await tester.pumpWidget(app(const TestRunScreen(
      config: TestRunConfig(
        test: FitnessTest.flamingo,
        participantId: 'R-07',
        standingLeg: StandingLeg.left,
        sessionId: 's',
      ),
    )));
    await tester.tap(find.text('Start clock'));
    clock.nowMs += 8000;
    await tester.pump(const Duration(seconds: 8));

    beam.add(const TimedBeamEvent(deviceMs: 700, phoneMs: 7900));
    await tester.pump();
    await tester.pump();
    expect(find.text('Count fall'), findsOneWidget);
    await tester.tap(find.text('Count fall'));
    await tester.pump();
    await tester.tap(find.text('Resume clock'));
    clock.nowMs += 60000;
    await tester.pump(const Duration(seconds: 60));

    final trial = store.recent().single;
    expect(trial.beamConfirmed, 1);
    expect(trial.falls, 1);
    expect(trial.losses.single.source, LossSource.beamConfirmed);
  });

  testWidgets('roster: set a class, run the next child, mark them done',
      (tester) async {
    await tester.pumpWidget(app(const RosterScreen()));
    expect(find.text('No class set yet.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12, 7');
    await tester.tap(find.text('Set class'));
    await tester.pump();
    expect(find.text('0 of 2 tested'), findsOneWidget);
    expect(find.text('Flamingo test for 12'), findsOneWidget);
    expect(settings.stationRoster, isNotNull);

    await tester.tap(find.text('Flamingo test for 12'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start clock'));
    clock.nowMs += 60000;
    await tester.pump(const Duration(seconds: 60));
    expect(store.count, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 tested'), findsOneWidget);
    expect(find.text('Flamingo test for 7'), findsOneWidget);
  });

  testWidgets('witness record shows counts and no percentage', (tester) async {
    await store.add(FitnessTrial(
      id: 'a',
      test: FitnessTest.flamingo,
      participantId: '1',
      sessionId: 's',
      standingLeg: StandingLeg.left,
      startedAt: DateTime(2026, 10, 2),
      insoleMode: InsoleMode.watching,
      losses: const [
        BalanceLoss(atMs: 1000, source: LossSource.beamConfirmed),
        BalanceLoss(atMs: 2000, source: LossSource.insoleDismissed),
        BalanceLoss(atMs: 3000, source: LossSource.tester),
      ],
      balanceMs: 60000,
    ));
    await tester.pumpWidget(app(const AgreementScreen()));
    expect(
        find.textContaining('Across 1 saved Flamingo trial'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('not an accuracy figure'), findsOneWidget);
  });

  testWidgets('One-Leg Minute: a round adds to the class total, no ranking',
      (tester) async {
    await tester.pumpWidget(app(const PracticeScreen()));
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Start the minute'));
    clock.nowMs += 10000;
    await tester.pump(const Duration(seconds: 10));
    await tester.tap(find.text('Foot touched down'));
    await tester.pump();
    await tester.tap(find.text('Back on one leg'));
    clock.nowMs += 50000;
    await tester.pump(const Duration(seconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Another round'), findsOneWidget);
    expect(find.textContaining('1 child'), findsOneWidget);
    expect(find.textContaining('Your own longest hold'), findsOneWidget);
  });
}
