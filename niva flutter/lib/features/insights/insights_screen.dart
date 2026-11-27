import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/telemetry_state.dart';
import '../../shared/widgets/connection_badge.dart';
import '../../shared/widgets/readings_notice.dart';
import '../../shared/widgets/rounded_card.dart';

/// "Details" tab - a plain-English read of what the engine is currently
/// computing from the raw sensor stream. Consolidates
/// `ClinicalInsightsUpdated.tsx` and its alternate-layout siblings from the
/// web app into one card-based screen. Until the FSRs are characterised it
/// only describes raw relative readings; it makes no health claims.
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
          Text('Sensor Details', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          ConnectionBadge(isLive: state.isLive, label: state.linkLabel),
          const SizedBox(height: 10),
          const ReadingsNotice(),
          const SizedBox(height: 20),
          RoundedCard(
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SUMMARY', style: theme.textTheme.labelSmall),
                const SizedBox(height: 10),
                Text(
                  _summarySentence(state),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!state.isLive)
            const _EmptyState()
          else ...[
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
                        Text(
                          metrics.mlpi.toStringAsFixed(1),
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inner minus outer forefoot, % of full scale',
                          style: theme.textTheme.bodyMedium,
                        ),
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
                        Text('IMU TILT', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 6),
                        Text(
                          '${metrics.stabilityMagnitude.toStringAsFixed(1)}°',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pitch and roll change since tare',
                          style: theme.textTheme.bodyMedium,
                        ),
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
                  Text('OBSERVATIONS', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 12),
                  if (metrics.anomalyFlags.isEmpty)
                    Text(
                      'Nothing to note in the last ${metrics.bufferLength} samples.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    for (final flag in metrics.anomalyFlags)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: theme.textTheme.labelSmall?.color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                flag,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
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
                  Text(
                    'HOW THESE VALUES ARE COMPUTED',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Each FSR value is ADC counts above tare divided by 4095, '
                    'so it is a percent of the ADC range, not a force or a '
                    'pressure. MLPI is the gap between the inner and outer '
                    'forefoot readings. Steps and cadence assume one heel '
                    'strike per stride from this one insole, so they are '
                    'estimates. The heel note appears when the heel sensor '
                    'carries over 70% of the measured load for 5 frames in a '
                    'row. None of these thresholds are clinically validated.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _summarySentence(TelemetryState state) {
    final metrics = state.metrics;
    if (state.isConnected && state.isStale && !state.isSimulating) {
      return 'No data from the insole for over 2 seconds. Readings are hidden '
          'until packets resume.';
    }
    if (!state.isLive) {
      return 'No device data yet. Connect the insole or start a simulation '
          'on the Today tab.';
    }
    final source = state.isSimulating ? 'Simulated data' : 'Live data';
    if (!metrics.isCalibrated) {
      return '$source: taring. Keep the foot off the ground for a few '
          'seconds.';
    }
    if (!state.isSimulating && !metrics.tareApplied) {
      return 'Live data. The app tare was skipped because the insole was '
          'loaded or moving, so values use the device\'s own zero.';
    }
    return '$source. Values are relative sensor readings, not calibrated '
        'force or pressure.';
  }
}

/// Mirrors `TrendsScreen`'s empty state - the cards above are meaningless
/// zeros with no fresh stream, so they're replaced with this instead of
/// showing misleading numbers.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sensors_off_rounded,
            color: Theme.of(context).textTheme.labelSmall?.color,
          ),
          const SizedBox(height: 10),
          Text(
            'No device data yet. Connect the insole or start a simulation '
            'from the Today tab to see the per-sensor details here.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
