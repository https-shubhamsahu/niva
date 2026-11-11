import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/gait_metrics.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../shared/widgets/health_layout.dart';
import '../../shared/widgets/demo_badge.dart';
import '../../shared/widgets/motion.dart';
import '../../theme/app_theme.dart';
import '../trends/trends_screen.dart';
import 'widgets/foot_load_view.dart';

/// Summary values retain the firmware validity and minimum-contact gates.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(telemetryControllerProvider);
    final m = state.metrics;
    final active = state.isConnected && state.isMeasurementValid;
    final ready = active && m.firmwareReportsEvents && m.isGateOpen;
    final engine = ref.read(gaitTimingEngineProvider);
    final offerDemo =
        !state.isConnected && !state.isDemo && !isWideLayout(context);
    final status = state.isDemo
        ? (m.isGateOpen
            ? 'Simulated walk'
            : 'Demo · collecting contacts · ${m.footContacts} of ${GaitMetrics.minFootContacts}')
        : !state.isConnected
            ? 'No insole connected'
            : !state.isMeasurementValid
                ? 'Tare needed · readings held back'
                : !m.firmwareReportsEvents
                    ? 'Update firmware for contact timing'
                    : !m.isGateOpen
                        ? 'Collecting contacts · ${m.footContacts} of ${GaitMetrics.minFootContacts}'
                        : 'Live · instrument valid';
    return HealthPage(children: [
      HealthHeader(
          title: 'Live readings',
          subtitle: state.isDemo
              ? 'Demo data · nothing is saved'
              : 'One insole · this session',
          trailing: IconButton(
              tooltip: 'Telemetry details',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => openHealthDetails(
                  context,
                  'About these readings',
                  const Text(
                      'Timing uses contact edges stamped by the insole at 100 Hz. Values appear after 12 contacts and use the latest contact window. With one insole, cadence counts two steps per stride. Sensor shares are relative readings, never force or pressure.')))),
      // With no insole on a phone, the status card itself starts the demo,
      // so offering it adds no height to the page.
      RoundedCard(
          key: offerDemo ? const Key('try-demo') : null,
          onTap: offerDemo
              ? () => ref.read(telemetryControllerProvider.notifier).startDemo()
              : null,
          radius: 18,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ready
                ? LivePulse(
                    color: state.isDemo ? AppColors.warning : AppColors.success,
                    active: true)
                : const Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.brand),
            const SizedBox(width: 10),
            Expanded(
                child:
                    Text(status, style: Theme.of(context).textTheme.bodySmall)),
            if (offerDemo)
              Text('Try demo',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700)),
            if (state.isDemo) ...[
              const DemoBadge(text: 'DEMO'),
              TextButton(
                  key: const Key('stop-demo'),
                  onPressed: () =>
                      ref.read(telemetryControllerProvider.notifier).stopDemo(),
                  child: const Text('Stop')),
            ],
          ])),
      if (!state.isConnected && !state.isDemo && isWideLayout(context))
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: RoundedCard(
                key: const Key('start-demo'),
                radius: 18,
                padding: EdgeInsets.zero,
                child: HealthRow(
                    title: 'No insole? Watch a demo',
                    subtitle: 'A simulated walk, clearly marked, never saved',
                    icon: Icons.play_circle_outline_rounded,
                    color: AppColors.warning,
                    onTap: () => ref
                        .read(telemetryControllerProvider.notifier)
                        .startDemo()))),
      if (state.connectionError != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(state.connectionError!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.danger))),
      const HealthSection('Contact timing'),
      SignalCard(
          title: 'Cadence',
          icon: Icons.directions_walk_rounded,
          color: AppColors.coral,
          value: ready && m.cadenceStepsPerMin != null
              ? '${m.cadenceStepsPerMin!.round()}'
              : '—',
          unit: 'steps/min',
          values: ready ? engine.cadenceHistory : const [],
          onTap: () => _trends(context)),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, constraints) {
        final cards = [
          SignalCard(
              title: 'Contact time',
              showIcon: false,
              icon: Icons.timer_outlined,
              color: AppColors.brand,
              value:
                  ready && m.contactTimeMs != null ? '${m.contactTimeMs}' : '—',
              unit: 'ms',
              onTap: () => _trends(context)),
          SignalCard(
              title: 'Heel first',
              showIcon: false,
              icon: Icons.compare_arrows_rounded,
              color: AppColors.success,
              value: ready && m.heelFirstShare != null
                  ? '${(m.heelFirstShare! * 100).round()}'
                  : '—',
              unit: '% of contacts',
              onTap: () => openHealthDetails(
                  context,
                  'Heel-first contacts',
                  const Text(
                      'Share of contacts where the heel loads first. Contacts tied within the same 10 ms sample are excluded. This describes contact order, not walking quality.'))),
        ];
        if (MediaQuery.textScalerOf(context).scale(15) > 22 ||
            constraints.maxWidth < 320) {
          return Column(
              children: [cards[0], const SizedBox(height: 10), cards[1]]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 10),
          Expanded(child: cards[1])
        ]);
      }),
      const HealthSection('Sensor view'),
      RoundedCard(
          key: const Key('foot-map-card'),
          onTap: () => openHealthDetails(
              context, 'Live foot map', const _LiveFootMapDetails()),
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FootLoadView(
                shares: m.loadShares,
                contactMask: m.contactMask,
                isConnected: active,
                expanded: isWideLayout(context)),
            const SizedBox(height: 6),
            Text('Relative load · tap to explore',
                style: Theme.of(context).textTheme.bodySmall),
          ])),
      const SizedBox(height: 10),
      RoundedCard(
          padding: EdgeInsets.zero,
          radius: 18,
          child: HealthRow(
              title: 'Session details',
              icon: Icons.list_alt_rounded,
              onTap: () => openHealthDetails(
                  context,
                  'Session details',
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.isDemo)
                          const Text(
                              'Source: demo walk. Simulated frames run through '
                              'the real timing engine. Not saved, exported or '
                              'used in assessments.'),
                        Text('Instrument state: ${state.measurementValidity}'),
                        Text(
                            'Accepted contacts: ${active ? m.footContacts : '—'}'),
                        Text(
                            'Firmware reports contact events: ${m.firmwareReportsEvents ? 'yes' : 'no'}'),
                        Text('Same-sample starts: ${m.tiedContacts}'),
                        Text(
                            'Dropped events: ${m.eventsDropped} · frame gaps: ${m.frameGaps}'),
                        Text(
                            'IMU clipping: ${state.imuClipped ? 'flagged' : 'not flagged'}'),
                        Text(
                            '${state.datasetCount} samples · ${state.datasetStatus}'),
                        const SizedBox(height: 12),
                        const Text(
                            'Same-sample starts cannot resolve which sensor loaded first. Timing is never computed across a data gap.'),
                      ])))),
    ]);
  }

  void _trends(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: TrendsScreen())));
}

class _LiveFootMapDetails extends ConsumerWidget {
  const _LiveFootMapDetails();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(telemetryControllerProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(
                state.isDemo
                    ? 'Demo · four simulated sensor zones'
                    : state.isConnected && state.isMeasurementValid
                        ? 'Live · four sensor zones'
                        : 'Waiting for a valid insole stream',
                style: Theme.of(context).textTheme.titleSmall)),
        if (state.isDemo) const DemoBadge(),
      ]),
      const SizedBox(height: 16),
      FootLoadView(
          shares: state.metrics.loadShares,
          contactMask: state.metrics.contactMask,
          isConnected: state.isConnected && state.isMeasurementValid,
          expanded: true),
      const SizedBox(height: 20),
      const Text('Colour shows each sensor’s share of the current reading. '
          'A ring marks contact reported by the insole. The four zones are '
          'relative sensor readings, not force, calibrated pressure or a '
          'measurement of the area between sensors.'),
    ]);
  }
}

class SignalCard extends StatelessWidget {
  final String title, value, unit;
  final IconData icon;
  final Color color;
  final List<double> values;
  final VoidCallback? onTap;
  final bool showIcon;
  const SignalCard(
      {super.key,
      required this.title,
      required this.value,
      required this.unit,
      required this.icon,
      required this.color,
      this.values = const [],
      this.showIcon = true,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, .4)!
        : color;
    return RoundedCard(
        radius: 20,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (showIcon) ...[
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 6)
            ],
            Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: accent))),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 17,
                  color: Theme.of(context).textTheme.labelSmall?.color)
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  RollingText(value,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 30,
                          height: 1.05,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(height: 3),
                  Text(unit, style: Theme.of(context).textTheme.bodySmall),
                ])),
            if (values.length > 1)
              SizedBox(
                  width: 105,
                  height: 44,
                  child: CustomPaint(painter: _Sparkline(values, color))),
          ]),
        ]));
  }
}

class _Sparkline extends CustomPainter {
  final List<double> values;
  final Color color;
  _Sparkline(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final data = values.where((v) => v.isFinite).toList();
    if (data.length < 2) return;
    final lo = data.reduce((a, b) => a < b ? a : b);
    final hi = data.reduce((a, b) => a > b ? a : b);
    final range = hi == lo ? 1.0 : hi - lo;
    final line = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = hi == lo
          ? size.height / 2
          : size.height - 4 - (data[i] - lo) / range * (size.height - 8);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: .18),
                color.withValues(alpha: 0)
              ]).createShader(Offset.zero & size));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_Sparkline oldDelegate) =>
      true; // the engine updates its history in place
}
