import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Marks readings that come from the scripted demo walk, not an insole.
/// Shown wherever demo values appear so they cannot pass as measurements.
class DemoBadge extends StatelessWidget {
  final String text;
  const DemoBadge({super.key, this.text = 'DEMO · SIMULATED'});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colour = dark ? const Color(0xFFFFB340) : const Color(0xFF9A5B00);
    return Semantics(
        label: 'Demo data, simulated, not a real insole',
        excludeSemantics: true,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: dark ? .22 : .16),
                borderRadius: BorderRadius.circular(8)),
            child: Text(text,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colour,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                    fontSize: 10.5))));
  }
}
