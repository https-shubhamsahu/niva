import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niva/core/data/settings_repository.dart';
import 'package:niva/core/data/telemetry_repository.dart';
import 'package:niva/core/experience/experience_preferences.dart';
import 'package:niva/core/fitness/fit_india_protocol.dart';
import 'package:niva/core/models/gait_metrics.dart';
import 'package:niva/core/providers/app_providers.dart';
import 'package:niva/core/providers/telemetry_controller.dart';
import 'package:niva/core/providers/telemetry_state.dart';
import 'package:niva/features/experience/launch_screen.dart';
import 'package:niva/features/experience/welcome_screen.dart';
import 'package:niva/features/shell/app_shell.dart';
import 'package:niva/features/station/practice_screen.dart';
import 'package:niva/features/station/agreement_screen.dart';
import 'package:niva/features/tests/test_run_screen.dart';
import 'package:niva/features/tests/test_run_controller.dart';
import 'package:niva/features/dashboard/dashboard_screen.dart';
import 'package:niva/theme/app_theme.dart';
import 'support/fakes.dart';

class SnapshotController extends TelemetryController {
  SnapshotController(
      {required super.socket,
      required super.ble,
      required super.engine,
      required super.repository,
      required super.settings,
      required super.clock});
  void show(TelemetryState snapshot) => state = snapshot;
}

void main() {
  Future<ProviderContainer> mount(WidgetTester tester, Widget screen,
      {Size size = const Size(390, 844),
      double scale = 1,
      TelemetryState? snapshot}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final font = FontLoader('NivaSans')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await font.load();
    final fallback = FontLoader('Ahem')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await fallback.load();
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository();
    await settings.init();
    await settings.setExperience(
        const ExperiencePreferences(role: AppRole.trainer, reduceMotion: true));
    final events = StreamController<TimedContactEvent>.broadcast();
    addTearDown(events.close);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          telemetryRepositoryProvider.overrideWithValue(TelemetryRepository()),
          trialStoreProvider.overrideWithValue(MemoryTrialStore()),
          monotonicClockProvider.overrideWithValue(FakeClock()),
          insoleEventsProvider.overrideWithValue(events.stream),
          telemetryControllerProvider.overrideWith((ref) {
            final controller = SnapshotController(
                socket: ref.watch(esp32SocketServiceProvider),
                ble: ref.watch(esp32BleServiceProvider),
                engine: ref.watch(gaitTimingEngineProvider),
                repository: ref.watch(telemetryRepositoryProvider),
                settings: settings,
                clock: ref.watch(monotonicClockProvider));
            if (snapshot != null) controller.show(snapshot);
            return controller;
          }),
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scale)),
                child: child!),
            home: screen)));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
        tester.element(find.byType(screen.runtimeType).first));
  }

  void expectFits(WidgetTester tester, String page) {
    expect(tester.takeException(), isNull, reason: page);
    final activeScrolls = find.byType(Scrollable).evaluate().where((e) {
      final widget = e.widget as Scrollable;
      return widget.axisDirection == AxisDirection.down &&
          !(e.findAncestorWidgetOfExactType<IgnorePointer>()?.ignoring ??
              false);
    });
    for (final element in activeScrolls) {
      final state = (element as StatefulElement).state as ScrollableState;
      expect(state.position.maxScrollExtent, lessThanOrEqualTo(1),
          reason: '$page requires scrolling');
    }
  }

  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    testWidgets('main screens fit $size without scrolling', (tester) async {
      await mount(tester, const AppShell(), size: size);
      expectFits(tester, 'Summary');
      for (final name in ['Tests', 'Live', 'Device']) {
        await tester.tap(find.widgetWithText(NavigationDestination, name));
        await tester.pumpAndSettle();
        expectFits(tester, name);
      }
      await tester.tap(find.text('Wi-Fi'));
      await tester.pumpAndSettle();
      expectFits(tester, 'Wi-Fi connection');
      expect(find.text('Connect').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('first launch and station features fit a phone', (tester) async {
    for (final screen in [
      const WelcomeScreen(),
      const PracticeScreen(),
      const AgreementScreen(),
      const TestRunScreen(
          config: TestRunConfig(
              test: FitnessTest.flamingo,
              participantId: 'R-07',
              standingLeg: StandingLeg.left,
              sessionId: 'layout'))
    ]) {
      await mount(tester, screen);
      expect(tester.takeException(), isNull);
      for (final element in find.byType(Scrollable).evaluate()) {
        final state = (element as StatefulElement).state as ScrollableState;
        if (state.position.axis == Axis.vertical) {
          expect(state.position.maxScrollExtent, lessThanOrEqualTo(1),
              reason: '${screen.runtimeType} requires scrolling');
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  testWidgets('timing values stay hidden until valid with enough contacts',
      (tester) async {
    const metrics = GaitMetrics(
        loadShares: SensorLoads(heel: .5, inner: .2, outer: .2, toe: .1),
        contactMask: 1,
        footContacts: 12,
        cadenceStepsPerMin: 104,
        contactTimeMs: 620,
        heelFirstShare: .75,
        tiedContacts: 1,
        eventsDropped: 0,
        frameGaps: 0,
        firmwareReportsEvents: true);
    final container = await mount(
        tester, const Scaffold(body: DashboardScreen()),
        snapshot: const TelemetryState(
            isConnected: true,
            measurementValidity: 'taring',
            metrics: metrics));
    expect(find.text('104'), findsNothing);
    expect(find.text('620'), findsNothing);
    expect(find.text('50%'), findsNothing);
    final controller = container.read(telemetryControllerProvider.notifier)
        as SnapshotController;
    controller.show(const TelemetryState(
        isConnected: true, measurementValidity: 'valid', metrics: metrics));
    await tester.pumpAndSettle();
    expect(find.text('104'), findsOneWidget);
    expect(find.text('620'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('foot-map-card')));
    await tester.pumpAndSettle();
    expect(find.text('Live foot map'), findsOneWidget);
    expect(find.text('Live · four sensor zones'), findsOneWidget);
    controller.show(TelemetryState.initial());
    await tester.pumpAndSettle();
    expect(find.text('104'), findsNothing);
    expect(find.text('620'), findsNothing);
    expect(find.text('50%'), findsNothing);
    expect(find.text('Waiting for a valid insole stream'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('launch animation finishes, and reduced motion skips it',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: LaunchExperience(
            child: Scaffold(body: Text('Ready for testing')))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('SAKSHI'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Ready for testing'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: LaunchExperience(
                child: Scaffold(body: Text('Motion reduced'))))));
    await tester.pump();
    expect(find.text('Motion reduced'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
