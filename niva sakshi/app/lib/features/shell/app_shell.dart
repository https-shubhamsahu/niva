import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/experience/experience_preferences.dart';
import '../../core/experience/experience_provider.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/health_layout.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/sakshi_brand.dart';

import '../../theme/app_theme.dart';
import '../experience/home_screen.dart';
import '../device/device_screen.dart';
import '../tests/tests_screen.dart';
import '../dashboard/dashboard_screen.dart';

/// Keeps each tab mounted and preserves its scroll position. Hidden tabs
/// cannot receive keyboard focus or appear in the accessibility tree.
/// Phones get a bottom tab bar; wide screens get a sidebar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = [
    _TabSpec(
        label: 'Summary', icon: Icons.favorite_rounded, screen: HomeScreen()),
    _TabSpec(label: 'Tests', icon: Icons.timer_rounded, screen: TestsScreen()),
    _TabSpec(
        label: 'Live',
        icon: Icons.show_chart_rounded,
        screen: DashboardScreen()),
    _TabSpec(
        label: 'Device', icon: Icons.settings_rounded, screen: DeviceScreen()),
  ];

  void _select(int index) {
    if (_index == index) return;
    if (ref.read(experienceProvider).haptics) {
      HapticFeedback.selectionClick();
    }
    setState(() => _index = index);
  }

  Widget _pages(bool reduceMotion) => Stack(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Positioned.fill(
              child: ExcludeFocus(
                excluding: _index != i,
                child: ExcludeSemantics(
                  excluding: _index != i,
                  child: IgnorePointer(
                    ignoring: _index != i,
                    // Incoming tab fades up from slightly smaller, as on iOS.
                    child: AnimatedOpacity(
                      opacity: _index == i ? 1 : 0,
                      duration: reduceMotion ? Duration.zero : AppMotion.fast,
                      curve: AppMotion.springCurve,
                      child: AnimatedScale(
                        scale: _index == i ? 1 : .985,
                        duration:
                            reduceMotion ? Duration.zero : AppMotion.medium,
                        curve: AppMotion.springCurve,
                        child: TickerMode(
                          enabled: _index == i,
                          child: i == 0
                              ? HomeScreen(onAssessments: () => _select(1))
                              : _tabs[i].screen,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final labelHeight = MediaQuery.textScalerOf(context).scale(12);

    if (isWideLayout(context)) {
      return Scaffold(
        body: Row(children: [
          _Sidebar(tabs: _tabs, index: _index, onSelect: _select),
          VerticalDivider(width: 1, thickness: .6, color: theme.dividerColor),
          Expanded(child: _pages(reduceMotion)),
        ]),
      );
    }

    return Scaffold(
      body: _pages(reduceMotion),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          border:
              Border(top: BorderSide(color: theme.dividerColor, width: 0.6)),
        ),
        child: NavigationBar(
          backgroundColor: theme.cardColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 48 + labelHeight * 1.5,
          selectedIndex: _index,
          animationDuration: reduceMotion ? Duration.zero : AppMotion.fast,
          onDestinationSelected: _select,
          destinations: [
            for (var i = 0; i < _tabs.length; i++)
              NavigationDestination(
                icon: Icon(_tabs[i].icon),
                label: _tabs[i].label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Desktop navigation in the manner of Health on iPad and Mac: brand at the
/// top, destinations as rows, live insole state at the foot.
class _Sidebar extends ConsumerWidget {
  final List<_TabSpec> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  const _Sidebar(
      {required this.tabs, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFA9D4FF) : AppColors.brand;
    final status = ref.watch(telemetryControllerProvider);
    final role = ref.watch(experienceProvider).role;
    return Container(
      width: 256,
      color: theme.cardColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                const SakshiMark(size: 38),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Niva Sakshi',
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(role == null ? 'Balance. Witnessed.' : role.label,
                          style: text.bodySmall),
                    ])),
              ]),
            ),
            const SizedBox(height: 28),
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: Material(
                    color: i == index
                        ? accent.withValues(alpha: dark ? .16 : .1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        child: Row(children: [
                          Icon(tabs[i].icon,
                              size: 20,
                              color:
                                  i == index ? accent : text.bodySmall?.color),
                          const SizedBox(width: 12),
                          Text(tabs[i].label,
                              style: text.titleSmall?.copyWith(
                                  color: i == index ? accent : null,
                                  fontWeight: i == index
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                status.isConnected
                    ? LivePulse(
                        color: status.isMeasurementValid && !status.isDemo
                            ? AppColors.success
                            : AppColors.warning,
                        active: status.isMeasurementValid,
                        size: 8)
                    : Icon(Icons.sensors_off_rounded,
                        size: 18, color: text.bodySmall?.color),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        status.isDemo
                            ? 'Demo insole · simulated'
                            : status.isConnected
                                ? (status.isMeasurementValid
                                    ? 'Insole connected'
                                    : 'Insole · tare needed')
                                : 'Insole offline',
                        style: text.bodySmall)),
              ]),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 10),
              Text(
                  'Web version. Tester-only assessments work in any browser. '
                  'Insole sessions are run in the Android app.',
                  style: text.bodySmall?.copyWith(fontSize: 11.5)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final Widget screen;

  const _TabSpec(
      {required this.label, required this.icon, required this.screen});
}
