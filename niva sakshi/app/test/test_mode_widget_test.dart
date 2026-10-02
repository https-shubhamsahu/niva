import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niva/core/data/settings_repository.dart';
import 'package:niva/core/data/telemetry_repository.dart';
import 'package:niva/core/fitness/fit_india_protocol.dart';
import 'package:niva/core/fitness/fitness_trial.dart';
import 'package:niva/core/fitness/flamingo_session.dart';
import 'package:niva/core/models/gait_metrics.dart';
import 'package:niva/core/providers/app_providers.dart';
import 'package:niva/features/tests/test_run_controller.dart';
import 'package:niva/features/tests/test_run_screen.dart';
import 'package:niva/features/tests/tests_screen.dart';
import 'package:niva/features/tests/widgets/trial_summary.dart';
import 'package:niva/features/experience/home_screen.dart';
import 'package:niva/theme/app_theme.dart';
import 'package:niva/features/shell/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

const _watching = InsoleStatus(
    connected: true, valid: true, reportsEvents: true, contactMask: 0);

void main() {
  late FakeClock clock;
  late MemoryTrialStore store;
  late StreamController<TimedContactEvent> events;

  setUp(() {
    clock = FakeClock();
    store = MemoryTrialStore();
    events = StreamController<TimedContactEvent>.broadcast();
  });

  tearDown(() => events.close());

  Widget app(Widget home,
      {InsoleStatus insole = _watching, List<Override> extra = const []}) {
    return ProviderScope(
      overrides: [
        monotonicClockProvider.overrideWithValue(clock),
        trialStoreProvider.overrideWithValue(store),
        insoleStatusProvider.overrideWithValue(insole),
        insoleEventsProvider.overrideWithValue(events.stream),
        ...extra,
      ],
      child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!),
          home: home),
    );
  }

  TestRunScreen runScreen(FitnessTest test) => TestRunScreen(
        config: TestRunConfig(
          test: test,
          participantId: 'R-07',
          standingLeg: StandingLeg.left,
          sessionId: 'session-test',
        ),
      );

  /// Moves the fake clock and lets the 100 ms ticker run.
  Future<void> advance(WidgetTester tester, int ms) async {
    clock.nowMs += ms;
    await tester.pump(Duration(milliseconds: ms));
  }

  Future<void> footEdge(WidgetTester tester,
      {required bool on, required int atMs}) async {
    events.add(TimedContactEvent(
      ContactEvent(
          deviceMs: 900000 + atMs,
          sensor: null,
          isOn: on,
          first: on ? InsoleSensor.toe : null),
      atMs,
    ));
    // The event is delivered during this pump and schedules a frame; the
    // second pump draws it.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Flamingo run by the tester alone', (tester) async {
    await tester.pumpWidget(app(runScreen(FitnessTest.flamingo),
        insole: InsoleStatus.disconnected));
    expect(find.textContaining('The tester times and counts alone'),
        findsOneWidget);

    await tester.tap(find.text('Start clock'));
    await advance(tester, 5000);
    await tester.tap(find.text('Lost balance'));
    await tester.pump();
    expect(find.text('Resume clock'), findsOneWidget);

    await tester.tap(find.text('Resume clock'));
    await advance(tester, 55000);
    await tester.pump();

    final trial = store.recent().single;
    expect(trial.falls, 1);
    expect(trial.testerOnly, 1);
    expect(trial.balanceMs, FlamingoRules.balanceMs);
    expect(trial.insoleMode, InsoleMode.notConnected);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets(
      'Flamingo: the tester dismisses one insole flag and counts another',
      (tester) async {
    await tester.pumpWidget(app(runScreen(FitnessTest.flamingo)));
    await tester.tap(find.text('Start clock'));
    await advance(tester, 3000);

    await footEdge(tester, on: true, atMs: 2900);
    expect(find.text('Not a fall'), findsOneWidget);
    await tester.tap(find.text('Not a fall'));
    await tester.pump();

    await advance(tester, 2000);
    await footEdge(tester, on: true, atMs: 4950);
    await tester.tap(find.text('Count fall'));
    await tester.pump();
    expect(find.text('Resume clock'), findsOneWidget);

    await tester.tap(find.text('Resume clock'));
    await advance(tester, 60000);
    await tester.pump();

    final trial = store.recent().single;
    expect(trial.falls, 1);
    expect(trial.insoleConfirmed, 1);
    expect(trial.insoleDismissed, 1);
    expect(
        trial.losses
            .firstWhere((l) => l.source == LossSource.insoleConfirmed)
            .atMs,
        4950);
  });

  testWidgets(
      'Vrikshasana: the insole flags the end and the tester confirms it',
      (tester) async {
    await tester.pumpWidget(app(
      runScreen(FitnessTest.vrikshasana),
      insole: const InsoleStatus(
          connected: true, valid: true, reportsEvents: true, contactMask: 1),
    ));
    await tester.tap(find.text('Start hold'));
    await advance(tester, 12500);
    await footEdge(tester, on: false, atMs: 12000);

    expect(find.text('End hold at 12.0 s'), findsOneWidget);
    await tester.tap(find.text('End hold at 12.0 s'));
    await tester.pump();

    expect(store.recent().single.holdMs, 12000);
    expect(find.text('12.0'), findsOneWidget);
    expect(find.textContaining('Test the other side'), findsOneWidget);
  });

  testWidgets('a hold under 10 s offers the same side again first',
      (tester) async {
    await tester.pumpWidget(app(runScreen(FitnessTest.vrikshasana)));
    await tester.tap(find.text('Start hold'));
    await advance(tester, 6000);
    await tester.tap(find.text('Stop hold'));
    await tester.pump();

    expect(store.recent().single.holdBelowMinimum, isTrue);
    expect(find.text('Try again on the left leg'), findsOneWidget);
    expect(find.textContaining('Test the other side'), findsOneWidget);
  });

  testWidgets('leaving a running trial asks first', (tester) async {
    await tester.pumpWidget(app(runScreen(FitnessTest.vrikshasana)));
    await tester.tap(find.text('Start hold'));
    await advance(tester, 1000);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump();
    expect(find.text('Stop this trial?'), findsOneWidget);
    await tester.tap(find.text('Keep testing'));
    await tester.pump();
    expect(find.text('Stop hold'), findsOneWidget);
    expect(store.count, 0);
  });

  testWidgets('run screen fits a phone held sideways', (tester) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(runScreen(FitnessTest.flamingo)));
    await tester.tap(find.text('Start clock'));
    await advance(tester, 1000);
    await footEdge(tester, on: true, atMs: 900);
    expect(find.text('Count fall'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('fits a small phone at 200% text', () {
    Future<void> smallAndLarge(WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    testWidgets('run screen, every Flamingo step', (tester) async {
      await smallAndLarge(tester);
      await tester.pumpWidget(app(runScreen(FitnessTest.flamingo)));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Start clock'));
      await advance(tester, 2000);
      expect(tester.takeException(), isNull);

      await footEdge(tester, on: true, atMs: 1900);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Count fall'));
      await tester.tap(find.text('Count fall'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Resume clock'));
      await tester.tap(find.text('Resume clock'));
      await advance(tester, 60000);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(store.count, 1);
      expect(find.byType(TrialSummary), findsOneWidget);
    });

    testWidgets('Tests tab with saved trials, and the setup sheet',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository();
      await settings.init();
      await store.add(FitnessTrial(
        id: 'a',
        test: FitnessTest.vrikshasana,
        participantId: 'A very long participant name, roll 1234',
        sessionId: 's',
        standingLeg: StandingLeg.right,
        startedAt: DateTime(2026, 10, 1, 10),
        insoleMode: InsoleMode.watching,
        holdMs: 8200,
      ));

      await smallAndLarge(tester);
      await tester.pumpWidget(app(
        const Scaffold(body: TestsScreen()),
        extra: [settingsRepositoryProvider.overrideWithValue(settings)],
      ));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Saved trials'), 200,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
      await tester.tap(find.text('Saved trials'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.textContaining('8.2 s hold'), 200,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
      expect(find.textContaining('8.2 s hold'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Flamingo balance'), -200,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
      await tester.ensureVisible(find.text('Flamingo balance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flamingo balance'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Open the test'));
      await tester.pump();
      expect(find.textContaining('Enter an ID'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('participant-id')), 'R-21');
      await tester.ensureVisible(find.text('Open the test'));
      await tester.tap(find.text('Open the test'));
      await tester.pumpAndSettle();
      expect(find.text('Start clock'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('saved trial search finds older trials and combines test filters',
      (tester) async {
    for (var i = 0; i < 32; i++) {
      await store.add(FitnessTrial(
        id: 'trial-$i',
        test: i == 0 ? FitnessTest.flamingo : FitnessTest.vrikshasana,
        participantId: i == 0 ? 'OLDER-01' : 'RECENT-$i',
        sessionId: 's',
        standingLeg: StandingLeg.left,
        startedAt: DateTime(2026, 10, 1, 10, i),
        insoleMode: InsoleMode.notConnected,
        balanceMs: i == 0 ? 60000 : null,
        holdMs: i == 0 ? null : 12000,
      ));
    }
    await tester.pumpWidget(app(const SavedTrialsScreen()));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('trial-search')), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.enterText(
        find.byKey(const ValueKey('trial-search')), ' older-01 ');
    await tester.pump();
    await tester.scrollUntilVisible(find.text('OLDER-01'), 100,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('OLDER-01'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Tree pose'));
    await tester.tap(find.widgetWithText(FilterChip, 'Tree pose'));
    await tester.pump();
    expect(find.text('OLDER-01'), findsNothing);
    await tester.scrollUntilVisible(find.text('No matching trials'), 100,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.text('Reset filters'));
    await tester.tap(find.text('Reset filters'));
    await tester.pump();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('trial-search')))
            .controller!
            .text,
        isEmpty);
    expect(find.textContaining('latest 30 of 32'), findsOneWidget);
  });

  testWidgets('setup does not open the keyboard until input is needed',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository();
    await settings.init();
    await tester.pumpWidget(app(
      const Scaffold(body: TestsScreen()),
      extra: [settingsRepositoryProvider.overrideWithValue(settings)],
    ));
    await tester.tap(find.text('Flamingo balance'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('participant-id'));
    expect(tester.widget<TextField>(input).focusNode!.hasFocus, isFalse);
    await tester.tap(find.text('Open the test'));
    await tester.pump();
    expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
    expect(find.textContaining('Enter an ID'), findsOneWidget);
    await tester.tap(find.byTooltip('Close setup'));
    await tester.pumpAndSettle();
    expect(input, findsNothing);
  });

  testWidgets(
      'switching tabs finishes the outgoing fade and hides its semantics',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository();
    await settings.init();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(const AppShell(), extra: [
      settingsRepositoryProvider.overrideWithValue(settings),
      telemetryRepositoryProvider.overrideWithValue(TelemetryRepository()),
    ]));
    await tester.tap(find.widgetWithText(NavigationDestination, 'Tests'));
    await tester.pumpAndSettle();
    final dashboardFade = find.ancestor(
        of: find.byType(HomeScreen), matching: find.byType(FadeTransition));
    expect(tester.widget<FadeTransition>(dashboardFade.first).opacity.value, 0);
    expect(find.bySemanticsLabel('Niva NOT CONNECTED'), findsNothing);
    expect(find.text('Balance tests'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    semantics.dispose();
  });
}
