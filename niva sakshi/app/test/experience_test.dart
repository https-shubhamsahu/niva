import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niva/core/data/settings_repository.dart';
import 'package:niva/core/data/telemetry_repository.dart';
import 'package:niva/core/experience/experience_preferences.dart';
import 'package:niva/core/fitness/fitness_trial.dart';
import 'package:niva/core/models/gait_metrics.dart';
import 'package:niva/core/providers/app_providers.dart';
import 'package:niva/main.dart';
import 'package:niva/shared/widgets/app_haptics.dart';
import 'package:niva/shared/widgets/sneaker_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fakes.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  test(
      'role and independent preferences persist without changing device settings',
      () async {
    SharedPreferences.setMockInitialValues(
        {'gaitguard.ws_endpoint': 'ws://test:81'});
    final settings = SettingsRepository();
    await settings.init();
    await settings.setExperience(const ExperiencePreferences(
        role: AppRole.participant,
        voice: false,
        chimes: true,
        haptics: false,
        reduceMotion: true));
    final reopened = SettingsRepository();
    await reopened.init();
    expect(reopened.experience.role, AppRole.participant);
    expect(reopened.experience.voice, isFalse);
    expect(reopened.experience.chimes, isTrue);
    expect(reopened.experience.haptics, isFalse);
    expect(reopened.experience.reduceMotion, isTrue);
    expect(reopened.wsUrl, 'ws://test:81');
    expect(ExperiencePreferences.decode('not json').role, isNull);
    expect(ExperiencePreferences.decode('{"role":"unknown","voice":0}').voice,
        isTrue);
  });

  Future<
          ({
            SettingsRepository settings,
            FakeClock clock,
            MemoryTrialStore store
          })>
      mount(WidgetTester tester, {AppRole? role, bool large = false}) async {
    SharedPreferences.setMockInitialValues({
      'niva.experience.v1':
          ExperiencePreferences(role: role, reduceMotion: true).encode()
    });
    final settings = SettingsRepository();
    await settings.init();
    final store = MemoryTrialStore();
    final clock = FakeClock();
    final events = StreamController<TimedContactEvent>.broadcast();
    addTearDown(events.close);
    if (large) {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.pumpWidget(ProviderScope(overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      trialStoreProvider.overrideWithValue(store),
      telemetryRepositoryProvider.overrideWithValue(TelemetryRepository()),
      monotonicClockProvider.overrideWithValue(clock),
      insoleStatusProvider.overrideWithValue(InsoleStatus.disconnected),
      insoleEventsProvider.overrideWithValue(events.stream),
    ], child: const NivaApp()));
    await tester.pumpAndSettle();
    return (settings: settings, clock: clock, store: store);
  }

  testWidgets(
      'first launch chooses participant and explains pairing availability',
      (tester) async {
    final env = await mount(tester, large: true);
    await tester.scrollUntilVisible(find.text('I’m a participant'), 200);
    await tapVisible(tester, find.text('I’m a participant'));
    await tester.pumpAndSettle();
    expect(env.settings.experience.role, AppRole.participant);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.scrollUntilVisible(find.text('Join trainer'), 200);
    await tapVisible(tester, find.text('Join trainer'));
    await tester.pumpAndSettle();
    expect(find.text('Pairing is coming next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trainer completes a real hold from home and sees saved result',
      (tester) async {
    final env = await mount(tester, role: AppRole.trainer);
    await tester.scrollUntilVisible(find.text('Tree pose'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Tree pose').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('participant-id')), 'P-42');
    await tester.ensureVisible(find.text('Open the test'));
    await tester.tap(find.text('Open the test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start hold'));
    env.clock.nowMs += 12000;
    await tester.pump(const Duration(seconds: 12));
    await tester.tap(find.text('Stop hold'));
    await tester.pumpAndSettle();
    expect(env.store.recent().single.holdMs, 12000);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('12.0 s hold'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('12.0 s hold'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preferences switch roles and independently disable feedback',
      (tester) async {
    final env = await mount(tester, role: AppRole.participant, large: true);
    await tester.tap(find.byTooltip('Your experience and role'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Spoken guidance'), 200);
    await tapVisible(tester, find.text('Spoken guidance'));
    await tester.pumpAndSettle();
    expect(env.settings.experience.voice, isFalse);
    expect(env.settings.experience.chimes, isTrue);
    await tester.scrollUntilVisible(find.text('Sound effects'), 200);
    await tapVisible(tester, find.text('Sound effects'));
    await tester.pumpAndSettle();
    expect(env.settings.experience.chimes, isFalse);
    await tester.scrollUntilVisible(find.text('Vibrations'), 200);
    await tapVisible(tester, find.text('Vibrations'));
    await tester.pumpAndSettle();
    expect(env.settings.experience.haptics, isFalse);
    await tester.scrollUntilVisible(find.text('Trainer'), -200);
    await tapVisible(tester, find.text('Trainer'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(env.settings.experience.role, AppRole.trainer);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trainer home fits 320px at 200 percent text', (tester) async {
    await mount(tester, role: AppRole.trainer, large: true);
    await tester.scrollUntilVisible(find.text('Start assessment'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    await tapVisible(tester, find.text('Start assessment'));
    await tester.pumpAndSettle();
    expect(find.text('Balance tests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decorative motion stops for reduced motion and hidden tabs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SneakerMascot()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const MaterialApp(
        home: TickerMode(enabled: false, child: SneakerMascot())));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SneakerMascot())));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('muted haptics emit no platform vibration call', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
        home: HapticPreferences(
            enabled: false,
            child: Builder(
                builder: (context) => TextButton(
                    onPressed: () {
                      AppHaptics.selectionClick(context);
                      AppHaptics.mediumImpact(context);
                    },
                    child: const Text('Tap'))))));
    await tester.tap(find.text('Tap'));
    expect(calls.where((call) => call.method == 'HapticFeedback.vibrate'),
        isEmpty);
  });
}
