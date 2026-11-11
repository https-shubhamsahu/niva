import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/settings_repository.dart';
import 'core/data/telemetry_repository.dart';
import 'core/data/trial_store.dart';
import 'core/providers/app_providers.dart';
import 'features/experience/welcome_screen.dart';
import 'features/experience/launch_screen.dart';
import 'core/experience/experience_provider.dart';
import 'shared/widgets/app_haptics.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Both repositories do real async I/O on first use (SharedPreferences /
  // Hive box open) - doing it once here means every provider downstream can
  // stay synchronous instead of every screen needing a FutureBuilder.
  final settings = SettingsRepository();
  await settings.init();

  final telemetryRepository = TelemetryRepository();
  await telemetryRepository.init();

  // Opens its box in the Hive instance TelemetryRepository just initialized.
  final trialStore = HiveTrialStore();
  await trialStore.init();

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        telemetryRepositoryProvider.overrideWithValue(telemetryRepository),
        trialStoreProvider.overrideWithValue(trialStore),
      ],
      child: const NivaApp(),
    ),
  );
}

class NivaApp extends ConsumerWidget {
  const NivaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(experienceProvider);
    return MaterialApp(
      title: 'Niva Sakshi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            disableAnimations:
                MediaQuery.disableAnimationsOf(context) || prefs.reduceMotion),
        child: HapticPreferences(enabled: prefs.haptics, child: child!),
      ),
      home: const LaunchExperience(child: ExperienceEntry()),
    );
  }
}
