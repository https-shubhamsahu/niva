// UI previews rendered from production widgets; not real-phone/insole evidence.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niva/core/data/settings_repository.dart';
import 'package:niva/core/data/telemetry_repository.dart';
import 'package:niva/core/experience/experience_preferences.dart';
import 'package:niva/core/fitness/fit_india_protocol.dart';
import 'package:niva/core/providers/app_providers.dart';
import 'package:niva/core/providers/telemetry_state.dart';
import 'package:niva/core/models/gait_metrics.dart';
import 'package:niva/features/experience/welcome_screen.dart';
import 'package:niva/features/experience/launch_screen.dart';
import 'package:niva/features/shell/app_shell.dart';
import 'package:niva/features/tests/test_run_controller.dart';
import 'package:niva/features/tests/test_run_screen.dart';
import 'package:niva/theme/app_theme.dart';
import '../test/support/fakes.dart';
import '../test/compact_layout_test.dart' as fixtures show SnapshotController;

void main() {
  testWidgets('capture the compact redesign', (tester) async {
    for (final name in ['NivaSans', 'Ahem', 'Roboto']) {
      await (FontLoader(name)
            ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(File(
                  'C:/Users/shubh/AppData/Local/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
              .readAsBytesSync()))))
        .load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // This file runs only under flutter test, with a separate mock store.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository();
    await settings.init();
    await settings.setExperience(
        const ExperiencePreferences(role: AppRole.trainer, reduceMotion: true));
    final boundaryKey = GlobalKey();
    Widget app(Widget screen,
            {bool reduced = true,
            bool dark = false,
            TelemetryState? snapshot}) =>
        ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settings),
              telemetryRepositoryProvider
                  .overrideWithValue(TelemetryRepository()),
              trialStoreProvider.overrideWithValue(MemoryTrialStore()),
              monotonicClockProvider.overrideWithValue(FakeClock()),
              telemetryControllerProvider.overrideWith((ref) {
                final controller = fixtures.SnapshotController(
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
            child: RepaintBoundary(
                key: boundaryKey,
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: dark ? AppTheme.dark : AppTheme.light,
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            padding: const EdgeInsets.only(top: 24, bottom: 24),
                            disableAnimations: reduced),
                        child: Stack(children: [
                          child!,
                          if (snapshot != null)
                            const Positioned(
                                top: 2,
                                left: 0,
                                right: 0,
                                // Outside any Material, so give the label a
                                // real style instead of the red fallback.
                                child: Center(
                                    child: Text(
                                        'UI PREVIEW · SCRIPTED SENSOR DATA',
                                        style: TextStyle(
                                            fontFamily: 'NivaSans',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: .6,
                                            color: Color(0xFF8E8E93),
                                            decoration: TextDecoration.none)))),
                        ])),
                    home: screen)));
    Future<void> save(String name) async {
      await tester.runAsync(() async {
        for (final asset in [
          'assets/images/feet.png',
          'assets/photos/tree-pose.jpg',
          'assets/photos/balance-park.jpg'
        ]) {
          await precacheImage(AssetImage(asset), boundaryKey.currentContext!);
        }
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final folder = Directory('build/captures/redesign')
          ..createSync(recursive: true);
        File('${folder.path}/$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(app(const AppShell()));
    await tester.pumpAndSettle();
    await save('summary');
    for (final name in ['Tests', 'Live', 'Device']) {
      await tester.tap(find.widgetWithText(NavigationDestination, name));
      await tester.pumpAndSettle();
      await save(name.toLowerCase());
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(const TestRunScreen(
        config: TestRunConfig(
            test: FitnessTest.flamingo,
            participantId: 'R-07',
            standingLeg: StandingLeg.left,
            sessionId: 'ui-preview'))));
    await tester.pumpAndSettle();
    await save('test-ready');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(
        app(const LaunchExperience(child: Scaffold()), reduced: false));
    await tester.pump(const Duration(milliseconds: 950));
    await save('launch');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(const WelcomeScreen()));
    await tester.pumpAndSettle();
    await save('welcome');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(const LaunchExperience(child: Scaffold()),
        reduced: false, dark: true));
    await tester.pump(const Duration(milliseconds: 950));
    await save('launch-dark');
    for (final dark in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(app(const AppShell(),
          dark: dark,
          snapshot: const TelemetryState(
              isConnected: true,
              measurementValidity: 'valid',
              metrics: GaitMetrics(
                  loadShares:
                      SensorLoads(heel: .62, inner: .23, outer: .1, toe: .05),
                  contactMask: 3,
                  footContacts: 24,
                  firmwareReportsEvents: true,
                  cadenceStepsPerMin: 104,
                  contactTimeMs: 620,
                  heelFirstShare: .75,
                  tiedContacts: 0,
                  eventsDropped: 0,
                  frameGaps: 0))));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Live'));
      await tester.pumpAndSettle();
      await save(dark ? 'heatmap-dark-scripted' : 'heatmap-scripted');
      if (!dark) {
        await tester.tap(find.byKey(const Key('foot-map-card')));
        await tester.pumpAndSettle();
        await save('heatmap-expanded-scripted');
      }
    }

    // Demo mode: the scripted walk through the real engine, on a phone and
    // on a desktop. These frames are simulated and labelled as such on screen.
    Future<void> demo(String name, Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(app(const AppShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Live').first);
      await tester.pumpAndSettle();
      final container =
          ProviderScope.containerOf(tester.element(find.byType(AppShell)));
      await container.read(telemetryControllerProvider.notifier).startDemo();
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await save(name);
      container.read(telemetryControllerProvider.notifier).stopDemo();
      await tester.pump();
    }

    await demo('demo-live', const Size(390, 844));
    await demo('desktop-demo-live', const Size(1440, 900));

    // Desktop / web layout: sidebar and two-column pages at 1440 x 900.
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(const WelcomeScreen()));
    await tester.pumpAndSettle();
    await save('desktop-welcome');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(const AppShell()));
    await tester.pumpAndSettle();
    await save('desktop-summary');
    for (final name in ['Tests', 'Device']) {
      await tester.tap(find.text(name).first);
      await tester.pumpAndSettle();
      await save('desktop-${name.toLowerCase()}');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(const AppShell(),
        snapshot: const TelemetryState(
            isConnected: true,
            measurementValidity: 'valid',
            metrics: GaitMetrics(
                loadShares:
                    SensorLoads(heel: .62, inner: .23, outer: .1, toe: .05),
                contactMask: 3,
                footContacts: 24,
                firmwareReportsEvents: true,
                cadenceStepsPerMin: 104,
                contactTimeMs: 620,
                heelFirstShare: .75,
                tiedContacts: 0,
                eventsDropped: 0,
                frameGaps: 0))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live').first);
    await tester.pumpAndSettle();
    await save('desktop-live-scripted');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(app(const TestRunScreen(
        config: TestRunConfig(
            test: FitnessTest.flamingo,
            participantId: 'R-07',
            standingLeg: StandingLeg.left,
            sessionId: 'ui-preview'))));
    await tester.pumpAndSettle();
    await save('desktop-test-ready');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
