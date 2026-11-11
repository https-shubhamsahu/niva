import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/experience/experience_provider.dart';

import '../../theme/app_theme.dart';
import '../experience/home_screen.dart';
import '../device/device_screen.dart';
import '../tests/tests_screen.dart';
import '../trends/trends_screen.dart';

/// Keeps each tab mounted and preserves its scroll position. Hidden tabs
/// cannot receive keyboard focus or appear in the accessibility tree.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = [
    _TabSpec(
        label: 'Home', icon: Icons.grid_view_rounded, screen: HomeScreen()),
    _TabSpec(label: 'Tests', icon: Icons.timer_rounded, screen: TestsScreen()),
    _TabSpec(
        label: 'Trends',
        icon: Icons.trending_up_rounded,
        screen: TrendsScreen()),
    _TabSpec(
        label: 'Device', icon: Icons.settings_rounded, screen: DeviceScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final labelHeight = MediaQuery.textScalerOf(context).scale(12);

    return Scaffold(
      body: Stack(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Positioned.fill(
              child: ExcludeFocus(
                excluding: _index != i,
                child: ExcludeSemantics(
                  excluding: _index != i,
                  child: IgnorePointer(
                    ignoring: _index != i,
                    child: AnimatedOpacity(
                      opacity: _index == i ? 1 : 0,
                      duration: reduceMotion ? Duration.zero : AppMotion.fast,
                      curve: AppMotion.springCurve,
                      child: TickerMode(
                        enabled: _index == i,
                        child: i == 0
                            ? HomeScreen(
                                onAssessments: () => setState(() => _index = 1))
                            : _tabs[i].screen,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
          height: 56 + labelHeight * 2,
          selectedIndex: _index,
          animationDuration: reduceMotion ? Duration.zero : AppMotion.fast,
          onDestinationSelected: (index) {
            if (_index == index) return;
            if (ref.read(experienceProvider).haptics) {
              HapticFeedback.selectionClick();
            }
            setState(() => _index = index);
          },
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

class _TabSpec {
  final String label;
  final IconData icon;
  final Widget screen;

  const _TabSpec(
      {required this.label, required this.icon, required this.screen});
}
