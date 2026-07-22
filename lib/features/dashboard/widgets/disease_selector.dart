import 'package:flutter/material.dart';

import '../../../core/engine/simulation_engine.dart';
import '../../../theme/app_theme.dart';

/// Chip row for picking which condition the on-device simulator plays back,
/// plus the "Run Clinical Demo" auto-cycle toggle. Direct port of
/// `DiseaseSelector.tsx`.
class DiseaseSelector extends StatelessWidget {
  final GaitMode selected;
  final ValueChanged<GaitMode> onSelect;
  final bool isDemoMode;
  final VoidCallback onDemoToggle;

  const DiseaseSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.isDemoMode,
    required this.onDemoToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'DISEASE SIMULATION ENGINE',
                style: theme.textTheme.labelSmall,
              ),
            ),
            GestureDetector(
              onTap: onDemoToggle,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDemoMode ? AppColors.danger : theme.dividerColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDemoMode ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                      size: 14,
                      color: isDemoMode ? Colors.white : theme.textTheme.labelSmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDemoMode ? 'STOP DEMO' : 'RUN DEMO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDemoMode ? Colors.white : theme.textTheme.labelSmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GaitMode.values.map((mode) {
            final isActive = mode == selected;
            final isLocked = isDemoMode && !isActive;
            return GestureDetector(
              onTap: isDemoMode ? null : () => onSelect(mode),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.brand
                      : (theme.brightness == Brightness.dark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFE8EBFD)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Opacity(
                  opacity: isLocked ? 0.4 : 1,
                  child: Text(
                    mode.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isActive ? Colors.white : AppColors.brand,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
