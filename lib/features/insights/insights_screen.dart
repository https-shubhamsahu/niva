import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/biomechanics_metrics.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/telemetry_state.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../theme/app_theme.dart';

/// "Health" tab - the plain-English read of what the engine is currently
/// seeing. Consolidates `ClinicalInsightsUpdated.tsx` and its several
/// alternate-layout siblings (3D view, heatmap legend, anatomy legend) from
/// the web app into one card-based screen; see BETTERMENTS.md for why
/// those variants weren't all ported 1:1.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(telemetryControllerProvider);
    final metrics = state.metrics;
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Health Insights', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 20),
          RoundedCard(
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CLINICAL SUMMARY', style: theme.textTheme.labelSmall),
                const SizedBox(height: 10),
                Text(_summarySentence(state), style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: RoundedCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MLPI', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 6),
                      Text(metrics.mlpi.toStringAsFixed(1), style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Medial-lateral pressure index', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RoundedCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ISCHEMIC RISK', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 6),
                      Text('${metrics.ischemicIntegralPct.round()}%', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Sustained pressure integral', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RoundedCard(
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AUTOMATED OBSERVATIONS', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                if (metrics.anomalyFlags.isEmpty)
                  Text(
                    'No anomalies in the current rolling buffer (last ${metrics.bufferLength} samples).',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  for (final flag in metrics.anomalyFlags)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                          const SizedBox(width: 8),
                          Expanded(child: Text(flag, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RoundedCard(
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WHY THESE ALERTS FIRE', style: theme.textTheme.labelSmall),
                const SizedBox(height: 10),
                Text(
                  'Every flag above comes from an explicit, published threshold - not a model prediction. '
                  'Ankle instability requires >8° corrected roll with lateral-dominant pressure; heel-dominant '
                  'trend requires 5 consecutive frames >70% heel load; ischemic risk requires a sustained '
                  'medial/lateral pressure integral above 50%. This mirrors the "deterministic, explainable" '
                  'design goal from the original dashboard.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _summarySentence(TelemetryState state) {
    final metrics = state.metrics;
    if (!state.isLive) {
      return 'No active stream. Connect the insole or start a simulation to generate a live clinical read.';
    }
    if (!metrics.isCalibrated) {
      return 'Calibrating baseline - keep the foot unloaded for a few seconds to suppress idle drift.';
    }
    if (metrics.anomalyFlags.isNotEmpty) {
      return 'Elevated risk detected: ${metrics.anomalyFlags.length} active flag(s). Review Automated Observations below.';
    }
    switch (metrics.stabilityBand) {
      case StabilityBand.stable:
        return 'Gait pattern is within the stable band. Pressure progression and temporal parameters look balanced.';
      case StabilityBand.moderate:
        return 'Moderate sway detected. Not yet flagged as an anomaly, but worth watching over the next session.';
      case StabilityBand.unstable:
        return 'Unstable sway detected in the current buffer.';
    }
  }
}
