import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/experience/experience_preferences.dart';
import '../../core/experience/experience_provider.dart';
import '../../shared/widgets/sneaker_mascot.dart';
import '../../theme/app_theme.dart';
import 'home_screen.dart';
import '../shell/app_shell.dart';

class ExperienceEntry extends ConsumerWidget {
  const ExperienceEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(experienceProvider).role) {
        AppRole.trainer => const AppShell(),
        AppRole.participant => const Scaffold(body: HomeScreen()),
        null => const WelcomeScreen(),
      };
}

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _saving = false;
  Future<void> _choose(AppRole role) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(experienceProvider.notifier)
          .save(ref.read(experienceProvider).copyWith(role: role));
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not remember your role. Try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Align(
            alignment: Alignment.centerLeft,
            child: Image.asset('assets/brand/niva-lockup.png',
                width: 130,
                height: 70,
                semanticLabel: 'Niva',
                fit: BoxFit.contain)),
        const SizedBox(height: 20),
        WelcomeReveal(
            child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: AppColors.mint, borderRadius: BorderRadius.circular(32)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: SneakerMascot(size: 200)),
            Text('Small steps.\nStrong beginnings.',
                style: text.headlineMedium?.copyWith(fontSize: 32)),
            const SizedBox(height: 12),
            const Text(
                'Meet your fitness teammate. Let’s make your next balance assessment feel a little brighter.'),
          ]),
        )),
        const SizedBox(height: 28),
        Text('How are you joining?', style: text.headlineMedium),
        const SizedBox(height: 8),
        const Text('Choose your role. You can change it anytime.'),
        const SizedBox(height: 16),
        _RoleButton(
            icon: Icons.directions_run_rounded,
            title: 'I’m a participant',
            description: 'Follow your trainer’s guidance on your own phone.',
            color: AppColors.lime,
            onTap: _saving ? null : () => _choose(AppRole.participant)),
        const SizedBox(height: 12),
        _RoleButton(
            icon: Icons.timer_rounded,
            title: 'I’m a trainer',
            description: 'Guide assessments, run the clock and record results.',
            color: AppColors.coral,
            onTap: _saving ? null : () => _choose(AppRole.trainer)),
        if (_saving)
          const Padding(
              padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        const SizedBox(height: 16),
      ]),
    ))));
  }
}

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final Color color;
  final VoidCallback? onTap;
  const _RoleButton(
      {required this.icon,
      required this.title,
      required this.description,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: AppColors.ink)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(description),
                    ])),
              ]),
            )),
      );
}
