import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/experience/experience_preferences.dart';
import '../../core/experience/experience_provider.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});
  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  bool _saving = false;
  Future<void> _save(ExperiencePreferences value) async {
    setState(() => _saving = true);
    try {
      await ref.read(experienceProvider.notifier).save(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(experienceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your experience')),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Your role', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          RadioGroup<AppRole>(
              groupValue: prefs.role,
              onChanged: (value) {
                if (!_saving) _save(prefs.copyWith(role: value));
              },
              child: Column(children: [
                for (final role in AppRole.values)
                  RadioListTile<AppRole>(
                    title: Text(role.label),
                    subtitle: Text(role == AppRole.trainer
                        ? 'Run assessments and confirm results.'
                        : 'Follow guidance on your own phone.'),
                    value: role,
                    enabled: !_saving,
                  ),
              ])),
          const SizedBox(height: 24),
          Text('Feedback & motion',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
              'Voice and sound preferences are saved. Playback is planned.'),
          SwitchListTile(
              title: const Text('Spoken guidance'),
              subtitle: const Text('Spoken prompts (planned).'),
              value: prefs.voice,
              onChanged:
                  _saving ? null : (v) => _save(prefs.copyWith(voice: v))),
          SwitchListTile(
              title: const Text('Sound effects'),
              subtitle: const Text('Start and completion chimes (planned).'),
              value: prefs.chimes,
              onChanged:
                  _saving ? null : (v) => _save(prefs.copyWith(chimes: v))),
          SwitchListTile(
              title: const Text('Vibrations'),
              subtitle: const Text('Taps and alerts on supported phones.'),
              value: prefs.haptics,
              onChanged:
                  _saving ? null : (v) => _save(prefs.copyWith(haptics: v))),
          SwitchListTile(
              title: const Text('Reduce motion'),
              subtitle: const Text(
                  'Simplify animations. Your device setting also applies.'),
              value: prefs.reduceMotion,
              onChanged: _saving
                  ? null
                  : (v) => _save(prefs.copyWith(reduceMotion: v))),
          if (_saving) const LinearProgressIndicator(),
        ]),
      ))),
    );
  }
}

void openPreferences(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const PreferencesScreen()));
