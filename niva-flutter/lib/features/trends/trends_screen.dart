import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../theme/app_theme.dart';

/// "Trends" tab - Apple Health style sparkline cards, built directly from
/// the shared [BiomechanicsEngine]'s rolling history buffer instead of a
/// separate trend-tracking data structure. Direct analog of
/// `TrendAnalytics.tsx`, condensed into fewer, denser cards.
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the controller (rather than the engine Provider directly)
    // is what actually triggers a rebuild on every processed packet - the
    // engine object itself mutates in place and isn't observable on its own.
    ref.watch(telemetryControllerProvider);
    final history = ref.read(biomechanicsEngineProvider).history;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Trends', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Last ${history.length} processed samples this session',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (history.isEmpty)
            _EmptyState()
          else ...[
            _TrendCard(
              title: 'STABILITY INDEX',
              color: AppColors.stability,
              values: history.map((m) => m.stabilityScore.toDouble()).toList(),
              currentLabel: '${history.last.stabilityScore}',
              minY: 0,
              maxY: 100,
            ),
            const SizedBox(height: 16),
            _TrendCard(
              title: 'CADENCE (SPM)',
              color: AppColors.cadence,
              values: history.map((m) => m.cadenceSpm).toList(),
              currentLabel: history.last.cadenceSpm.toStringAsFixed(0),
              minY: 0,
              maxY: 160,
            ),
            const SizedBox(height: 16),
            _TrendCard(
              title: 'IMPACT SEVERITY',
              color: AppColors.warning,
              values: history.map((m) => m.impactLevel * 100).toList(),
              currentLabel: '${(history.last.impactLevel * 100).round()}%',
              minY: 0,
              maxY: 100,
            ),
            const SizedBox(height: 16),
            _TrendCard(
              title: 'ISCHEMIC PRESSURE INTEGRAL',
              color: AppColors.danger,
              values: history.map((m) => m.ischemicIntegralPct).toList(),
              currentLabel: '${history.last.ischemicIntegralPct.round()}%',
              minY: 0,
              maxY: 100,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.show_chart_rounded, color: Theme.of(context).textTheme.labelSmall?.color),
          const SizedBox(height: 10),
          Text(
            'No telemetry yet. Connect the insole or start a simulation from the Today tab to build a trend history.',
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
  final double minY;
  final double maxY;

  const _TrendCard({
    required this.title,
    required this.color,
    required this.values,
    required this.currentLabel,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return RoundedCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.labelSmall)),
              Text(currentLabel, style: theme.textTheme.titleMedium?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: values.length < 2
                ? const SizedBox.shrink()
                : LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: color,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
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
