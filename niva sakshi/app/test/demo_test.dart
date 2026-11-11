import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niva/core/data/settings_repository.dart';
import 'package:niva/core/data/telemetry_repository.dart';
import 'package:niva/core/demo/demo_walk.dart';
import 'package:niva/core/engine/gait_timing_engine.dart';
import 'package:niva/core/models/gait_metrics.dart';
import 'package:niva/core/providers/app_providers.dart';
import 'package:niva/features/dashboard/dashboard_screen.dart';
import 'package:niva/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fakes.dart';

void main() {
  test('the demo walk is well-formed firmware telemetry', () {
    final walk = DemoWalk();
    final engine = GaitTimingEngine();
    GaitMetrics? metrics;
    var lastMs = 0;
    for (var i = 0; i < 60 * 20; i++) {
      final frame = walk.next();
      final ms = frame['deviceTimestampMs'] as int;
      expect(ms - lastMs, DemoWalk.frameMs);
      lastMs = ms;
      for (final raw in frame['events'] as List) {
        final event = ContactEvent.parse(raw);
        expect(event, isNotNull, reason: '$raw');
        expect(event!.deviceMs % 10, 0, reason: 'on the 10 ms grid');
      }
      metrics = engine.process(frame);
    }
    // A minute of walking through the real engine gives ordinary values.
    expect(metrics!.isGateOpen, isTrue);
    expect(metrics.cadenceStepsPerMin, inInclusiveRange(95, 118));
    expect(metrics.contactTimeMs, inInclusiveRange(550, 800));
    expect(metrics.heelFirstShare, inInclusiveRange(.6, .95));
    expect(metrics.frameGaps, 0);
  });

  testWidgets(
      'demo shows labelled readings, but never saves them or feeds a test',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await (FontLoader('NivaSans')
          ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf')))
        .load();
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository();
    await settings.init();
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      // Never initialised: any write to the dataset would fail visibly.
      telemetryRepositoryProvider.overrideWithValue(TelemetryRepository()),
      trialStoreProvider.overrideWithValue(MemoryTrialStore()),
      monotonicClockProvider.overrideWithValue(FakeClock()),
    ]);
    final published = <Object>[];
    final events = container
        .read(telemetryControllerProvider.notifier)
        .contactEvents
        .listen(published.add);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
            home: const Scaffold(body: DashboardScreen()))));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('try-demo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('try-demo')));
    await tester.pump();
    // Long enough for the engine's 12-contact gate and several flushes.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    final state = container.read(telemetryControllerProvider);
    expect(state.isDemo, isTrue);
    expect(state.metrics.isGateOpen, isTrue);
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('Simulated walk'), findsOneWidget);
    expect(find.text('Demo data · nothing is saved'), findsOneWidget);
    expect(find.text('Live · instrument valid'), findsNothing);
    expect(find.text('${state.metrics.cadenceStepsPerMin!.round()}'),
        findsOneWidget);

    // Not saved, not published to assessments, not an insole to the tests.
    expect(state.datasetCount, 0);
    expect(state.datasetStatus, isNot(contains('failed')));
    expect(published, isEmpty);
    expect(container.read(insoleStatusProvider).connected, isFalse);

    await tester.tap(find.byKey(const Key('stop-demo')));
    await tester.pump();
    final stopped = container.read(telemetryControllerProvider);
    expect(stopped.isDemo, isFalse);
    expect(stopped.isConnected, isFalse);
    expect(find.text('DEMO'), findsNothing);
    expect(find.byKey(const Key('try-demo')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    unawaited(events.cancel());
    container.dispose();
  });
}
