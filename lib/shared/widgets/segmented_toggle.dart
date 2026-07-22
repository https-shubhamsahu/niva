import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SegmentedOption<T> {
  final T value;
  final String label;
  final IconData icon;

  const SegmentedOption({required this.value, required this.label, required this.icon});
}

/// Pill-shaped, animated segmented control - the Live Sensor / Simulation
/// switch on the web dashboard, redrawn as a sliding Apple-style toggle
/// instead of two independently-colored buttons.
class SegmentedToggle<T> extends StatelessWidget {
  final List<SegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color activeColor;

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: options.map((option) {
          final isActive = option.value == value;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isActive) HapticFeedback.selectionClick();
                onChanged(option.value);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                // Vertical padding tuned so the full tappable segment clears
                // the 44pt minimum touch-target guideline (16px icon + 2×14
                // padding = 44).
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor
                      : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      option.icon,
                      size: 16,
                      color: isActive ? Colors.white : theme.textTheme.labelSmall?.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      option.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isActive ? Colors.white : theme.textTheme.labelSmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
