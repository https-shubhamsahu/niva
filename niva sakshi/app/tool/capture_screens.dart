// Renders the real Test-mode run screen to PNG files for the SIH deck.
//
// This is the real app code drawn by the Flutter test renderer with a
// scripted contact event. It is NOT a screenshot of a live trial on a phone
// with the insole. The deck labels it exactly that way.
//
// Run from the app folder:
//   flutter test tool/capture_screens.dart
// Output: build/captures/*.png
// ignore_for_file: prefer_const_constructors
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niva/core/fitness/fit_india_protocol.dart';
import 'package:niva/core/fitness/fitness_trial.dart';
import 'package:niva/core/models/gait_metrics.dart';
import 'package:niva/core/providers/app_providers.dart';
import 'package:niva/features/tests/test_run_controller.dart';
import 'package:niva/features/tests/test_run_screen.dart';
import 'package:niva/theme/app_theme.dart';

import '../test/support/fakes.dart';

void main() {
  testWidgets('capture the run screen with a flag awaiting the teacher',
      (tester) async {
    final font = FontLoader('NivaSans')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await font.load();
    // Buttons and icons use other families in the test engine; map them to
    // the bundled Inter and the SDK's Material Icons so nothing renders as
    // placeholder blocks.
    final roboto = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await roboto.load();
    // Button labels carry no family; the test engine falls back to its Ahem
    // placeholder font, so draw Inter in its place.
    final ahem = FontLoader('Ahem')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await ahem.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File(
              'C:/Users/shubh/AppData/Local/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytesSync())));
    await icons.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final clock = FakeClock();
    final store = MemoryTrialStore();
    final events = StreamController<TimedContactEvent>.broadcast();
    addTearDown(events.close);
    final key = GlobalKey();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        monotonicClockProvider.overrideWithValue(clock),
        trialStoreProvider.overrideWithValue(store),
        insoleStatusProvider.overrideWithValue(const InsoleStatus(
            connected: true, valid: true, reportsEvents: true, contactMask: 0)),
        insoleEventsProvider.overrideWithValue(events.stream),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!),
          home: TestRunScreen(
            config: const TestRunConfig(
              test: FitnessTest.flamingo,
              participantId: 'R-07',
              standingLeg: StandingLeg.left,
              sessionId: 'capture',
            ),
          ),
        ),
      ),
    ));

    Future<void> save(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/captures')..createSync(recursive: true);
        File('${dir.path}/$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await tester.pump();
    await save('run-ready');

    await tester.tap(find.text('Start clock'));
    clock.nowMs += 41000;
    await tester.pump(const Duration(milliseconds: 41000));
    events.add(TimedContactEvent(
      ContactEvent(
          deviceMs: 941000, sensor: null, isOn: true, first: InsoleSensor.toe),
      40900,
    ));
    await tester.pump();
    await tester.pump();
    await save('run-flag');
  });
}
