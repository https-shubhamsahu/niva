import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/simulation_engine.dart';
import '../../core/models/biomechanics_metrics.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/telemetry_state.dart';
import '../../shared/widgets/connection_badge.dart';
import '../../shared/widgets/metric_tile.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../shared/widgets/segmented_toggle.dart';
import '../../theme/app_theme.dart';
import 'widgets/disease_selector.dart';
import 'widgets/foot_pressure_view.dart';
import 'widgets/health_rings.dart';

enum _LinkMode { live, simulation }

/// "Today" screen - the Apple Health-styled replacement for
/// `MainDashboard.tsx`. Everything here reads from [telemetryControllerProvider]
/// so it never touches a socket or timer directly.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(telemetryControllerProvider);
    final controller = ref.read(telemetryControllerProvider.notifier);
    final metrics = state.metrics;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _Header(state: state),
          const SizedBox(height: 20),
          if (state.connectionError != null && !state.isSimulating) ...[
            _StatusBanner(
              icon: Icons.wifi_off_rounded,
              color: AppColors.warning,
              title: 'Connection status',
              message: state.connectionError!,
            ),
            const SizedBox(height: 16),
          ],
          SegmentedToggle<_LinkMode>(
            value: state.isSimulating ? _LinkMode.simulation : _LinkMode.live,
            activeColor: AppColors.brand,
            onChanged: (mode) {
              if (mode == _LinkMode.live) {
                controller.stopSimulation();
                controller.connectLive();
              } else {
                controller.disconnectLive();
                controller.startSimulation();
              }
            },
            options: const [
              SegmentedOption(value: _LinkMode.live, label: 'LIVE SENSOR', icon: Icons.sensors_rounded),
              SegmentedOption(value: _LinkMode.simulation, label: 'SIMULATION', icon: Icons.science_rounded),
            ],
          ),
          const SizedBox(height: 20),
          if (state.isSimulating) ...[
            _ExplanationCard(state: state),
            const SizedBox(height: 16),
          ],
          _RingsCard(metrics: metrics, isLive: state.isLive),
          const SizedBox(height: 16),
          _MetricsGrid(metrics: metrics),
          const SizedBox(height: 16),
          RoundedCard(
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MetricLabel('PLANTAR PRESSURE MAP', trailing: _CopLegend()),
                const SizedBox(height: 14),
                FootPressureView(
                  pressure: metrics.normalizedPressure,
                  cop: metrics.cop,
                  copTrail: state.copTrail,
                  isConnected: state.isLive,
                ),
              ],
            ),
          ),
          if (metrics.anomalyFlags.isNotEmpty) ...[
            const SizedBox(height: 16),
            _AnomalyCard(flags: metrics.anomalyFlags),
          ],
          const SizedBox(height: 16),
          if (state.isSimulating)
            DiseaseSelector(
              selected: state.simMode,
              onSelect: controller.setSimulationMode,
              isDemoMode: state.isDemoMode,
              onDemoToggle: controller.toggleDemoMode,
            ),
          const SizedBox(height: 16),
          _DatasetStrip(state: state),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TelemetryState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GaitGuard Nexus', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              ConnectionBadge(
                isLive: state.isLive,
                label: state.isSimulating
                    ? 'SIMULATION RUNNING'
                    : (state.isConnected ? 'LIVE TELEMETRY' : 'NOT CONNECTED'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoundedCard(
      radius: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final TelemetryState state;
  const _ExplanationCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoundedCard(
      radius: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology_rounded, color: AppColors.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.simMode.label.toUpperCase()} GAIT DETECTED',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.brand),
                ),
                const SizedBox(height: 6),
                Text(state.simMode.explanation, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsCard extends StatelessWidget {
  final ProcessedBiomechanicsMetrics metrics;
  final bool isLive;

  const _RingsCard({required this.metrics, required this.isLive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stability = isLive ? metrics.stabilityScore / 100 : 0.0;
    final cadence = isLive ? (metrics.cadenceSpm / 140).clamp(0.0, 1.0) : 0.0;
    final safety = isLive ? (1 - metrics.impactLevel).clamp(0.0, 1.0) : 0.0;

    return RoundedCard(
      radius: 32,
      child: Row(
        children: [
          HealthRings(
            size: 148,
            rings: [
              RingMetric(label: 'Stability', value: stability, color: AppColors.stability),
              RingMetric(label: 'Cadence', value: cadence, color: AppColors.cadence),
              RingMetric(label: 'Safety', value: safety, color: AppColors.safety),
            ],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLive ? '${metrics.stabilityScore}' : '--',
                  style: theme.textTheme.displayLarge,
                ),
                Text('STABILITY', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RingLegend(color: AppColors.stability, label: 'Stability', value: isLive ? '${metrics.stabilityScore}' : '--'),
                const SizedBox(height: 10),
                _RingLegend(
                  color: AppColors.cadence,
                  label: 'Cadence',
                  value: isLive ? '${metrics.cadenceSpm.toStringAsFixed(0)} spm' : '--',
                ),
                const SizedBox(height: 10),
                _RingLegend(
                  color: AppColors.safety,
                  label: 'Impact safety',
                  value: isLive ? '${(safety * 100).round()}%' : '--',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingLegend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _RingLegend({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final ProcessedBiomechanicsMetrics metrics;
  const _MetricsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        MetricTile(label: 'GAIT PHASE', value: metrics.gaitPhase.label),
        MetricTile(label: 'STEPS', value: '${metrics.stepCount}'),
        MetricTile(label: 'STANCE / SWING', value: '${metrics.stancePct}:${metrics.swingPct}'),
        MetricTile(
          label: 'STABILITY BAND',
          value: metrics.stabilityBand.label,
          valueColor: metrics.stabilityBand == StabilityBand.unstable
              ? AppColors.danger
              : metrics.stabilityBand == StabilityBand.moderate
                  ? AppColors.warning
                  : AppColors.success,
        ),
        MetricTile(label: 'MLPI', value: metrics.mlpi.toStringAsFixed(1)),
        MetricTile(label: 'IMPACT', value: '${(metrics.impactLevel * 100).round()}%'),
      ],
    );
  }
}

class _CopLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('COP', style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  final List<String> flags;
  const _AnomalyCard({required this.flags});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoundedCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ANOMALY FLAGS', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.danger)),
          const SizedBox(height: 8),
          for (final flag in flags)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('•  $flag', style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class _DatasetStrip extends StatelessWidget {
  final TelemetryState state;
  const _DatasetStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoundedCard(
      radius: 20,
      child: Row(
        children: [
          Icon(Icons.storage_rounded, size: 18, color: theme.textTheme.labelSmall?.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${state.datasetCount} samples logged · ${state.datasetStatus}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
