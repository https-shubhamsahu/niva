import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/gait_timing_engine.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../theme/app_theme.dart';

/// "Trends" tab: one point per stride or per foot contact this session,
/// straight from the [GaitTimingEngine]'s history. These are individual
/// observations; the Today tab's medians are the summary.
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the controller (rather than the engine Provider directly)
    // is what triggers a rebuild on every processed frame - the engine
    // object mutates in place and isn't observable on its own.
    ref.watch(telemetryControllerProvider);
    final engine = ref.read(gaitTimingEngineProvider);
    final cadence = engine.cadenceHistory;
    final contactMs =
        engine.history.map((c) => c.durationMs.toDouble()).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Trends', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Up to the last ${GaitTimingEngine.historyLength} contacts this session. '
            'Each point is one stride or one contact.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (cadence.isEmpty && contactMs.isEmpty)
            const _EmptyState()
          else ...[
            _TrendCard(
              title: 'CADENCE PER STRIDE (STEPS/MIN)',
              color: AppColors.cadence,
              values: cadence,
              currentLabel:
                  cadence.isEmpty ? '--' : cadence.last.round().toString(),
            ),
            const SizedBox(height: 16),
            _TrendCard(
              title: 'CONTACT TIME (MS)',
              color: AppColors.brand,
              values: contactMs,
              currentLabel:
                  contactMs.isEmpty ? '--' : contactMs.last.round().toString(),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.show_chart_rounded,
              color: Theme.of(context).textTheme.labelSmall?.color),
          const SizedBox(height: 10),
          Text(
            'No foot contacts yet. Connect the insole on the Device tab, tare it '
            'unloaded, then walk.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<double> values;
  final String currentLabel;

  const _TrendCard({
    required this.title,
    required this.color,
    required this.values,
    required this.currentLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    // The axis follows the data instead of a fixed "healthy" range: there
    // is no validated target for these numbers.
    final low = values.isEmpty ? 0.0 : values.reduce(math.min);
    final high = values.isEmpty ? 1.0 : values.reduce(math.max);
    final pad = math.max((high - low) * 0.15, 1.0);

    return RoundedCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.labelSmall)),
              Text(currentLabel,
                  style: theme.textTheme.titleMedium?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: values.length < 2
                ? const SizedBox.shrink()
                : LineChart(
                    LineChartData(
                      minY: math.max(0, low - pad),
                      maxY: high + pad,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: false,
                          color: color,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.2),
                                color.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
