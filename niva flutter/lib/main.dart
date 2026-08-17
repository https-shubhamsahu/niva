import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/settings_repository.dart';
import 'core/data/telemetry_repository.dart';
import 'core/providers/app_providers.dart';
import 'features/shell/app_shell.dart';
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

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        telemetryRepositoryProvider.overrideWithValue(telemetryRepository),
      ],
      child: const NivaApp(),
    ),
  );
}

class NivaApp extends StatelessWidget {
  const NivaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GaitGuard Nexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
