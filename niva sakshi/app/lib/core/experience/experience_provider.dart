import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_repository.dart';
import '../providers/app_providers.dart';
import 'experience_preferences.dart';

final experienceProvider =
    StateNotifierProvider<ExperienceController, ExperiencePreferences>(
        (ref) => ExperienceController(ref.watch(settingsRepositoryProvider)));

class ExperienceController extends StateNotifier<ExperiencePreferences> {
  final SettingsRepository _settings;
  ExperienceController(this._settings) : super(_settings.experience);

  Future<void> save(ExperiencePreferences value) async {
    await _settings.setExperience(value);
    if (mounted) state = value;
  }
}
