import 'package:flutter/material.dart';
import '../../../core/models/gait_metrics.dart';
import '../../../shared/widgets/motion.dart';

/// Original Niva reference image, cropped in the UI to one measured foot.
/// Glows represent four relative FSR shares, not an interpolated pressure field.
class FootLoadView extends StatelessWidget {
  final SensorLoads shares;
  final int contactMask;
  final bool isConnected, expanded;
  const FootLoadView(
      {super.key,
      required this.shares,
      required this.contactMask,
      required this.isConnected,
      this.expanded = false});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<SensorLoads>(
      // Bars and heat glide between readings; the percentages stay exact.
      tween: _LoadsTween(end: isConnected ? shares : const SensorLoads()),
      duration: motionReduced(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => _build(context, shown));

  Widget _build(BuildContext context, SensorLoads shown) {
    final text = Theme.of(context).textTheme;
    final image = ExcludeSemantics(
        child: FootImageMap(
            shares: shown,
            contactMask: contactMask,
            active: isConnected,
            width: expanded ? 166 : 82,
            height: expanded ? 304 : 140));
    final values = Column(mainAxisSize: MainAxisSize.min, children: [
      for (final sensor in [
        InsoleSensor.toe,
        InsoleSensor.inner,
        InsoleSensor.outer,
        InsoleSensor.heel
      ])
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(sensor.label, style: text.bodySmall)),
                Text(
                    isConnected
                        ? '${(safeShare(shares.of(sensor)) * 100).round()}%'
                        : '—',
                    style:
                        text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 3),
              ExcludeSemantics(
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: isConnected ? safeShare(shown.of(sensor)) : 0,
                          minHeight: 4,
                          color: heatColour(safeShare(shares.of(sensor))),
                          backgroundColor: Theme.of(context).dividerColor))),
            ])),
      const SizedBox(height: 6),
      ExcludeSemantics(
          child: Row(children: [
        Text('Low', style: text.labelSmall?.copyWith(fontSize: 10)),
        const SizedBox(width: 7),
        Expanded(
            child: Container(
                height: 4,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(colors: [
                      Color(0xFF007AFF),
                      Color(0xFF18B7C5),
                      Color(0xFFF5BE42),
                      Color(0xFFEC593D)
                    ])))),
        const SizedBox(width: 7),
        Text('High', style: text.labelSmall?.copyWith(fontSize: 10)),
      ])),
    ]);
    if (expanded && MediaQuery.textScalerOf(context).scale(15) > 22) {
      return Column(children: [image, const SizedBox(height: 20), values]);
    }
    return Row(
        children: [image, const SizedBox(width: 16), Expanded(child: values)]);
  }
}

class _LoadsTween extends Tween<SensorLoads> {
  _LoadsTween({super.end});
  @override
  SensorLoads lerp(double t) {
    final a = begin ?? const SensorLoads(), b = end ?? const SensorLoads();
    double mix(double x, double y) => x + (y - x) * t;
    return SensorLoads(
        heel: mix(a.heel, b.heel),
        inner: mix(a.inner, b.inner),
        outer: mix(a.outer, b.outer),
        toe: mix(a.toe, b.toe));
  }
}

double safeShare(double value) => value.isFinite ? value.clamp(0, 1) : 0;
Color heatColour(double value) {
  const colours = [
    Color(0xFF007AFF),
    Color(0xFF18B7C5),
    Color(0xFFF5BE42),
    Color(0xFFEC593D)
  ];
  final position = safeShare(value) * 3;
  final index = position.floor().clamp(0, 2);
  return Color.lerp(colours[index], colours[index + 1], position - index)!;
}

class FootImageMap extends StatelessWidget {
  final SensorLoads shares;
  final int contactMask;
  final bool active;
  final double width, height;
  const FootImageMap(
      {super.key,
      required this.shares,
      required this.contactMask,
      required this.active,
      this.width = 92,
      this.height = 164});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
              color: const Color(0xFFFBFCFF),
              child: ClipRect(
                  child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: width * 2,
                      maxWidth: width * 2,
                      minHeight: height,
                      maxHeight: height,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.asset('assets/images/feet.png',
                            fit: BoxFit.fill, excludeFromSemantics: true),
                        CustomPaint(
                            painter: _HeatPainter(shares, contactMask, active)),
                      ]))))));
}

class _HeatPainter extends CustomPainter {
  final SensorLoads shares;
  final int mask;
  final bool active;
  _HeatPainter(this.shares, this.mask, this.active);
  // Original normalized coordinates on the source image before cropping.
  static const zones = {
    InsoleSensor.toe: Offset(.34, .11),
    InsoleSensor.inner: Offset(.34, .33),
    InsoleSensor.outer: Offset(.14, .37),
    InsoleSensor.heel: Offset(.34, .80),
  };
  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    for (final zone in zones.entries) {
      final value = safeShare(shares.of(zone.key));
      final center =
          Offset(zone.value.dx * size.width, zone.value.dy * size.height);
      final colour = heatColour(value);
      final radius = size.shortestSide * (.075 + value * .16);
      if (value > 0) {
        canvas.drawCircle(
            center,
            radius,
            Paint()
              ..shader = RadialGradient(colors: [
                colour.withValues(alpha: .4 + value * .5),
                colour.withValues(alpha: .15 + value * .3),
                colour.withValues(alpha: 0)
              ], stops: const [
                0,
                .45,
                1
              ]).createShader(Rect.fromCircle(center: center, radius: radius)));
      }
      // The source image prints a label bubble at each zone, so the contact
      // ring encloses that bubble instead of covering its text.
      if (mask & zone.key.bit != 0) {
        canvas.drawCircle(
            center,
            size.shortestSide * .095,
            Paint()
              ..color = const Color(0xFF173B59)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8);
        canvas.drawCircle(
            center,
            size.shortestSide * .095 + 2,
            Paint()
              ..color = Colors.white.withValues(alpha: .9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter oldDelegate) =>
      shares != oldDelegate.shares ||
      mask != oldDelegate.mask ||
      active != oldDelegate.active;
}
