import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../device/device_screen.dart';
import '../insights/insights_screen.dart';
import '../trends/trends_screen.dart';

/// Root tab shell. All four screens stay permanently mounted (rather than
/// named routes) so every tab keeps its scroll position and the telemetry
/// stream underneath never gets torn down when switching tabs - direct
/// analog of the always-mounted `<BottomNav />` in `App.tsx`, minus the
/// router. Cross-fades between tabs (via stacked + opacity-animated
/// `Positioned.fill`s, not `IndexedStack`) so a tab switch reads as a
/// transition instead of an instant cut, while keeping the exact same
/// "nothing ever unmounts" guarantee `IndexedStack` gave.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    _TabSpec(label: 'Today', icon: Icons.grid_view_rounded, screen: DashboardScreen()),
    _TabSpec(label: 'Trends', icon: Icons.trending_up_rounded, screen: TrendsScreen()),
    _TabSpec(label: 'Health', icon: Icons.favorite_rounded, screen: InsightsScreen()),
    _TabSpec(label: 'Device', icon: Icons.settings_rounded, screen: DeviceScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _index != i,
                child: AnimatedOpacity(
                  opacity: _index == i ? 1 : 0,
                  duration: AppMotion.fast,
                  curve: AppMotion.springCurve,
                  child: _tabs[i].screen,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.92),
          border: Border(top: BorderSide(color: theme.dividerColor, width: 0.6)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavButton(
                      spec: _tabs[i],
                      isActive: _index == i,
                      onTap: () {
                        if (_index != i) {
                          HapticFeedback.selectionClick();
                          setState(() => _index = i);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final Widget screen;

  const _TabSpec({required this.label, required this.icon, required this.screen});
}

class _NavButton extends StatelessWidget {
  final _TabSpec spec;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({required this.spec, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? AppColors.brand : theme.textTheme.labelSmall?.color;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(spec.icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            spec.label,
            style: theme.textTheme.labelSmall?.copyWith(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
