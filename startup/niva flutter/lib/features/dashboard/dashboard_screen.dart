import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/gait_timing_engine.dart';
import '../../core/models/gait_metrics.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/telemetry_state.dart';
import '../../shared/widgets/connection_badge.dart';
import '../../shared/widgets/metric_tile.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../theme/app_theme.dart';
import 'widgets/foot_load_view.dart';

/// "Today" screen: instrument status, contact-timing metrics and the live
/// relative-load view. Everything reads from [telemetryControllerProvider],
/// so this screen never touches a socket or timer directly.
///
/// It shows only what the insole measures. There are no scores, risk flags
/// or ratings: timing values appear after the step gate opens, and every
/// value says what it is.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(telemetryControllerProvider);
    final metrics = state.metrics;
    final showTiming = state.isConnected && state.isMeasurementValid;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _Header(state: state),
          const SizedBox(height: 20),
          if (state.connectionError != null) ...[
            _NoticeCard(
              icon: Icons.wifi_off_rounded,
              color: AppColors.warning,
              title: 'Connection status',
              message: state.connectionError!,
            ),
            const SizedBox(height: 16),
          ],
          if (!state.isConnected) ...[
            const _NoticeCard(
              icon: Icons.sensors_rounded,
              color: AppColors.brand,
              title: 'Connect the insole',
              message: 'Open the Device tab and connect over Bluetooth or Wi-Fi. '
                  'Then tare the insole while nothing is pressing on it.',
            ),
            const SizedBox(height: 16),
          ] else ...[
            _ValidityCard(state: state),
            const SizedBox(height: 16),
          ],
          if (showTiming && !metrics.firmwareReportsEvents) ...[
            const _NoticeCard(
              icon: Icons.system_update_alt_rounded,
              color: AppColors.warning,
              title: 'Update the insole firmware',
              message: 'This firmware does not report contact events, so timing '
                  'metrics are unavailable. Flash the current niva_hardware sketch.',
            ),
            const SizedBox(height: 16),
          ],
          _TimingCard(metrics: metrics, active: showTiming),
          const SizedBox(height: 16),
          RoundedCard(
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MetricLabel('RELATIVE LOAD · ONE INSOLE'),
                const SizedBox(height: 14),
                FootLoadView(
                  shares: metrics.loadShares,
                  contactMask: metrics.contactMask,
                  isConnected: showTiming,
                ),
                const SizedBox(height: 10),
                Text(
                  "Glow size is each sensor's share of the current reading, not force "
                  'or pressure. A ring marks a sensor in contact.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Niva', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        ConnectionBadge(
          isLive: state.isConnected,
          label: state.isConnected ? 'LIVE TELEMETRY' : 'NOT CONNECTED',
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _NoticeCard({
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
                Text(title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: color)),
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

/// The firmware's own validity verdict. Metrics are only computed from
/// frames it marks valid; everything else is a status frame.
class _ValidityCard extends StatelessWidget {
  final TelemetryState state;
  const _ValidityCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final valid = state.isMeasurementValid;
    final message = valid
        ? (state.imuClipped
            ? 'Metrics reported. The accelerometer clipped in this frame; '
                'impact comes from the piezo, not the IMU.'
            : 'Metrics reported from frames the insole marks valid.')
        : 'Insole state: ${state.measurementValidity}. Metrics are held back '
            'until you tare the unloaded insole on the Device tab.';
    return _NoticeCard(
      icon: valid ? Icons.verified_rounded : Icons.pause_circle_outline_rounded,
      color: valid ? AppColors.success : AppColors.warning,
      title: valid ? 'Valid' : 'Not valid',
      message: message,
    );
  }
}

class _TimingCard extends StatelessWidget {
  final GaitMetrics metrics;
  final bool active;

  const _TimingCard({required this.metrics, required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String shown(String? value) => active && value != null ? value : '--';

    final cadence = metrics.cadenceStepsPerMin;
    final contactMs = metrics.contactTimeMs;
    final heelFirst = metrics.heelFirstShare;
    final lost = metrics.eventsDropped + metrics.frameGaps;

    final gateText = !active
        ? 'Timing appears once the insole is connected, tared and valid.'
        : metrics.isGateOpen
            ? 'Medians of the last ${GaitTimingEngine.windowSize} contacts.'
            : 'Collecting foot contacts: ${metrics.footContacts} of '
                '${GaitMetrics.minFootContacts} before timing is shown.';

    return RoundedCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetricLabel('CONTACT TIMING'),
          const SizedBox(height: 6),
          Text(gateText, style: theme.textTheme.bodySmall),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.1,
            children: [
              MetricTile(
                label: 'CADENCE',
                value: shown(cadence == null ? null : '${cadence.round()} steps/min'),
              ),
              MetricTile(
                label: 'CONTACT TIME',
                value: shown(contactMs == null ? null : '$contactMs ms'),
              ),
              MetricTile(
                label: 'HEEL FIRST',
                value: shown(heelFirst == null ? null : '${(heelFirst * 100).round()}% of contacts'),
              ),
              MetricTile(
                label: 'FOOT CONTACTS',
                value: shown('${metrics.footContacts}'),
              ),
              MetricTile(
                label: 'SAME-SAMPLE STARTS',
                value: shown('${metrics.tiedContacts}'),
              ),
              MetricTile(
                label: 'DATA LOSS',
                value: shown(lost == 0
                    ? 'none'
                    : '${metrics.eventsDropped} events, ${metrics.frameGaps} gaps'),
                valueColor: active && lost > 0 ? AppColors.warning : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Edges are timed by the insole at 100 Hz. With one insole, cadence '
            'counts two steps per stride of that foot. Same-sample starts are '
            'contacts where two sensors loaded within one 10 ms sample, so '
            'which came first cannot be told.',
            style: theme.textTheme.bodySmall,
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
          Icon(Icons.storage_rounded,
              size: 18, color: theme.textTheme.labelSmall?.color),
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
