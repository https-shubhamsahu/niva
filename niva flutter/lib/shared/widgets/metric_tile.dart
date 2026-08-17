import 'package:flutter/material.dart';

import 'rounded_card.dart';

/// A single labeled metric inside the "Biomechanics Engine" grid - gait
/// phase, cadence, steps, stability band, etc. Deliberately plain so the
/// grid reads calmly; the rings and foot map are where the visual energy
/// goes, following Apple Health's own restraint on secondary stat tiles.
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const MetricTile({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoundedCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}
