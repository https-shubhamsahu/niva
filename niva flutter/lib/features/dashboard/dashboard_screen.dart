import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/simulation_engine.dart';
import '../../core/models/biomechanics_metrics.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/telemetry_state.dart';
import '../../shared/widgets/connection_badge.dart';
import '../../shared/widgets/metric_tile.dart';
import '../../shared/widgets/readings_notice.dart';
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
          if (state.isConnected && state.isStale && !state.isSimulating) ...[
            const _StatusBanner(
              icon: Icons.portable_wifi_off_rounded,
              color: AppColors.warning,
              title: 'Stale data',
              message:
                  'No data from the insole for over 2 seconds. The values '
                  'below are frozen and greyed out until packets resume.',
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
              SegmentedOption(
                value: _LinkMode.live,
                label: 'LIVE SENSOR',
                icon: Icons.sensors_rounded,
              ),
              SegmentedOption(
                value: _LinkMode.simulation,
                label: 'SIMULATION',
                icon: Icons.science_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (state.isSimulating) ...[
            _ExplanationCard(state: state),
            const SizedBox(height: 16),
          ],
          _RingsCard(metrics: metrics, isLive: state.isLive),
          const SizedBox(height: 16),
          _MetricsGrid(metrics: metrics, isLive: state.isLive),
          const SizedBox(height: 16),
          RoundedCard(
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MetricLabel(
                  'SENSOR LOAD MAP',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _AdcBadge(),
                      const SizedBox(width: 10),
                      _CopLegend(),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FootPressureView(
                  pressure: metrics.normalizedPressure,
                  cop: metrics.cop,
                  copTrail: state.copTrail,
                  isConnected: state.isLive,
                ),
                const SizedBox(height: 14),
                _ChannelReadings(
                  metrics: metrics,
                  isLive: state.isLive,
                  isSimulated: state.isSimulating,
                ),
                const SizedBox(height: 10),
                const ReadingsNotice(),
              ],
            ),
          ),
          if (state.isLive && metrics.anomalyFlags.isNotEmpty) ...[
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
              ConnectionBadge(isLive: state.isLive, label: state.linkLabel),
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
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
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
          const Icon(Icons.science_rounded, color: AppColors.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIMULATED PATTERN: ${state.simMode.label.toUpperCase()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${state.simMode.explanation} Not patient data and not a '
                  'detection.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Raw readings only: mean load across the four FSRs (percent of ADC full
/// scale), the cadence estimate and the piezo impact level. The former
/// "stability" score and "impact safety" ring were invented indices.
class _RingsCard extends StatelessWidget {
  final ProcessedBiomechanicsMetrics metrics;
  final bool isLive;

  const _RingsCard({required this.metrics, required this.isLive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meanLoadPct = metrics.totalPressure / 4;
    final load = isLive ? (meanLoadPct / 100).clamp(0.0, 1.0) : 0.0;
    final cadence = isLive ? (metrics.cadenceSpm / 140).clamp(0.0, 1.0) : 0.0;
    final impact = isLive ? metrics.impactLevel.clamp(0.0, 1.0) : 0.0;

    return RoundedCard(
      radius: 32,
      child: Row(
        children: [
          HealthRings(
            size: 148,
            isLive: isLive,
            rings: [
              RingMetric(
                label: 'Mean load',
                value: load,
                color: AppColors.stability,
              ),
              RingMetric(
                label: 'Cadence (est.)',
                value: cadence,
                color: AppColors.cadence,
              ),
              RingMetric(
                label: 'Impact',
                value: impact,
                color: AppColors.safety,
              ),
            ],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLive ? '${meanLoadPct.round()}%' : '--',
                  style: theme.textTheme.displayLarge,
                ),
                Text('MEAN LOAD', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RingLegend(
                  color: AppColors.stability,
                  label: 'Mean load',
                  value: isLive ? '${meanLoadPct.round()}%' : '--',
                ),
                const SizedBox(height: 10),
                _RingLegend(
                  color: AppColors.cadence,
                  label: 'Cadence (est.)',
                  value: isLive
                      ? '${metrics.cadenceSpm.toStringAsFixed(0)}/min'
                      : '--',
                ),
                const SizedBox(height: 10),
                _RingLegend(
                  color: AppColors.safety,
                  label: 'Impact (piezo)',
                  value: isLive ? '${(impact * 100).round()}%' : '--',
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

  const _RingLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final ProcessedBiomechanicsMetrics metrics;
  final bool isLive;
  const _MetricsGrid({required this.metrics, required this.isLive});

  @override
  Widget build(BuildContext context) {
    // No fresh data (disconnected or stale): show placeholders instead of the
    // last frame's numbers.
    String show(String value) => isLive ? value : '--';
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        MetricTile(label: 'GAIT PHASE', value: show(metrics.gaitPhase.label)),
        MetricTile(label: 'STEPS (EST.)', value: show('${metrics.stepCount}')),
        MetricTile(
          label: 'STANCE / SWING (EST.)',
          value: show('${metrics.stancePct}:${metrics.swingPct}'),
        ),
        MetricTile(
          label: 'IMU TILT',
          value: show('${metrics.stabilityMagnitude.toStringAsFixed(1)}°'),
        ),
        MetricTile(
          label: 'MLPI (% FS)',
          value: show(metrics.mlpi.toStringAsFixed(1)),
        ),
        MetricTile(
          label: 'IMPACT (PIEZO)',
          value: show('${(metrics.impactLevel * 100).round()}%'),
        ),
      ],
    );
  }
}

/// The four FSR channels as percent of ADC full scale after tare. These are
/// relative readings; nothing converts them to force or pressure yet.
class _ChannelReadings extends StatelessWidget {
  final ProcessedBiomechanicsMetrics metrics;
  final bool isLive;
  final bool isSimulated;
  const _ChannelReadings({
    required this.metrics,
    required this.isLive,
    required this.isSimulated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = metrics.filteredPressure;
    final channels = {
      'Heel': p.heel,
      'Inner': p.inner,
      'Outer': p.outer,
      'Toe': p.toe,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final entry in channels.entries)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLive ? '${entry.value.round()}%' : '--',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Percent of ADC full scale (0-4095 counts), after tare.',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
        ),
        if (isLive &&
            !isSimulated &&
            metrics.isCalibrated &&
            !metrics.tareApplied) ...[
          const SizedBox(height: 4),
          Text(
            'App tare skipped: the insole was loaded or moving while '
            'connecting, so values use the device\'s own zero.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: AppColors.warning,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small badge next to the pressure map label. "12-bit" is not decorative -
/// it's the real resolution of the ESP32's ADC (0-4095), matching the
/// `/ 4095` normalization in `biomechanics_engine.dart`.
class _AdcBadge extends StatelessWidget {
  const _AdcBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D375C) : const Color(0xFFEDECFE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '12-BIT ADC',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: isDark ? const Color(0xFFB3A9FA) : const Color(0xFF6E5AE6),
        ),
      ),
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
          decoration: const BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('COP', style: theme.textTheme.labelSmall),
      ],
    );
  }
}

const _anomalyCollapsedLimit = 2;

class _AnomalyCard extends StatefulWidget {
  final List<String> flags;
  const _AnomalyCard({required this.flags});

  @override
  State<_AnomalyCard> createState() => _AnomalyCardState();
}

class _AnomalyCardState extends State<_AnomalyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flags = widget.flags;
    final isTruncated = !_expanded && flags.length > _anomalyCollapsedLimit;
    final visibleFlags = isTruncated
        ? flags.take(_anomalyCollapsedLimit).toList()
        : flags;

    return RoundedCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OBSERVATIONS', style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          for (final flag in visibleFlags)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('•  $flag', style: theme.textTheme.bodyMedium),
            ),
          if (isTruncated)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _expanded = true);
                },
                child: Text(
                  'Show all ${flags.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
          Icon(
            Icons.storage_rounded,
            size: 18,
            color: theme.textTheme.labelSmall?.color,
          ),
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
