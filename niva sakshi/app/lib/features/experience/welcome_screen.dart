import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/experience/experience_preferences.dart';
import '../../core/experience/experience_provider.dart';
import '../../shared/widgets/health_layout.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/sakshi_brand.dart';
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
    if (isWideLayout(context)) return _wide(context);
    return Scaffold(
        body: HealthPage(children: [
      const HealthHeader(
          title: 'Niva Sakshi', subtitle: 'A little more balance. Every day.'),
      const SizedBox(height: 8),
      Container(
          padding: const EdgeInsets.only(left: 18),
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const SakshiMark(size: 60),
                  const SizedBox(height: 8),
                  Text('Find your\nbalance.', style: text.headlineMedium),
                ])),
            Image.asset('assets/photos/tree-pose.jpg',
                width: 118,
                height: 170,
                fit: BoxFit.cover,
                excludeFromSemantics: true),
          ])),
      const SizedBox(height: 12),
      Text('A focused assessment. A record you can keep.',
          style: text.bodyMedium, textAlign: TextAlign.center),
      const SizedBox(height: 22),
      Text('How are you joining?', style: text.titleMedium),
      const SizedBox(height: 4),
      Text('Choose your role. You can change it anytime.',
          style: text.bodySmall),
      const SizedBox(height: 12),
      _RoleButton(
          icon: Icons.timer_outlined,
          title: 'I’m a trainer',
          description: 'Guide tests and confirm results.',
          color: AppColors.brand,
          onTap: _saving ? null : () => _choose(AppRole.trainer)),
      const SizedBox(height: 10),
      _RoleButton(
          icon: Icons.person_outline_rounded,
          title: 'I’m a participant',
          description: 'Follow your trainer’s guidance.',
          color: AppColors.coral,
          onTap: _saving ? null : () => _choose(AppRole.participant)),
      if (_saving)
        const Padding(
            padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
    ]));
  }

  /// Desktop landing: a photographic hero beside what the station does and
  /// the role choice, so a first-time visitor understands it at a glance.
  Widget _wide(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hero = ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
            height: 580,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/photos/tree-pose.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -.2),
                  excludeFromSemantics: true),
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xCC0B2238)],
                          stops: [.45, 1]))),
              Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Find your\nbalance.',
                            style: text.displayLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 44,
                                height: 1.05)),
                        const SizedBox(height: 10),
                        Text('A focused assessment. A record you can keep.',
                            style: text.bodyLarge
                                ?.copyWith(color: Colors.white70)),
                      ])),
            ])));
    const steps = [
      (
        Icons.sensors_rounded,
        'Sensors flag',
        'The insole notices when the raised foot comes down. A balance beam '
            'that does the same is being built.'
      ),
      (
        Icons.how_to_reg_rounded,
        'The teacher decides',
        'Every flag is confirmed or dismissed. Nothing counts without the '
            'teacher.'
      ),
      (
        Icons.receipt_long_rounded,
        'The record keeps both',
        'Each saved trial lists what the sensors flagged and what the '
            'teacher decided.'
      ),
    ];
    final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const SakshiMark(size: 44),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Niva Sakshi',
                      style: text.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('A Flamingo balance-test station',
                      style: text.bodySmall),
                ])),
          ]),
          const SizedBox(height: 24),
          Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(22)),
              child: Column(children: [
                for (final (icon, title, body) in steps)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                    color:
                                        AppColors.brand.withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Icon(icon,
                                    size: 20, color: AppColors.brand)),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(title, style: text.titleSmall),
                                  const SizedBox(height: 2),
                                  Text(body, style: text.bodySmall),
                                ])),
                          ])),
              ])),
          const SizedBox(height: 26),
          Text('How are you joining?', style: text.titleMedium),
          const SizedBox(height: 4),
          Text('Choose your role. You can change it anytime.',
              style: text.bodySmall),
          const SizedBox(height: 12),
          _RoleButton(
              icon: Icons.timer_outlined,
              title: 'I’m a trainer',
              description: 'Guide tests and confirm results.',
              color: AppColors.brand,
              onTap: _saving ? null : () => _choose(AppRole.trainer)),
          const SizedBox(height: 10),
          _RoleButton(
              icon: Icons.person_outline_rounded,
              title: 'I’m a participant',
              description: 'Follow your trainer’s guidance.',
              color: AppColors.coral,
              onTap: _saving ? null : () => _choose(AppRole.participant)),
          if (_saving)
            const Padding(
                padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        ]);
    return Scaffold(
        body: SafeArea(
            child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1180),
                                child: Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Row(children: [
                                      Expanded(
                                          flex: 11,
                                          child: Entrance(child: hero)),
                                      const SizedBox(width: 48),
                                      Expanded(
                                          flex: 10,
                                          child: Entrance(
                                              index: 2, child: details)),
                                    ])))))))));
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: color)),
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
