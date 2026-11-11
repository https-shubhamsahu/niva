import 'package:flutter/material.dart';

import '../../../core/models/gait_metrics.dart';

/// Live view of the one connected insole, drawn on the FSR reference diagram
/// (`assets/images/feet.png`). Four zones (toe, inner forefoot, outer
/// forefoot, heel) map onto the firmware's toe/inner/outer/heel channels.
///
/// The glow size is each sensor's share of the current reading. The sensors
/// saturate under walking load, so it is a relative picture, not force or
/// pressure. A solid ring marks a sensor the firmware reports in contact.
///
/// Only one insole exists, so only the left outline is driven. The right
/// outline is veiled rather than mirrored, so it never shows a reading that
/// was not measured.
class FootLoadView extends StatelessWidget {
  final SensorLoads shares; // 0..1 per sensor
  final int contactMask;
  final bool isConnected;

  const FootLoadView({
    super.key,
    required this.shares,
    required this.contactMask,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final veil = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.72);

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/feet.png', fit: BoxFit.cover),
            // `feet.png` has a baked-in white canvas, not a transparent one -
            // in dark mode that reads as a broken white rectangle. A radial
            // vignette lets the photo's background blend into the dark card.
            if (isDark)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.85,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1C1C1E).withValues(alpha: 0.9),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
              ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: isConnected ? 1 : 0.25,
              child: CustomPaint(
                painter: _LoadPainter(shares: shares, contactMask: contactMask),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: FractionallySizedBox(
                alignment: Alignment.centerRight,
                widthFactor: 0.5,
                child: Container(
                  color: veil,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Second insole not connected',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                ),
              ),
            ),
            if (!isConnected)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: veil,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Connect the insole on the Device tab to see live readings',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Zone {
  final InsoleSensor sensor;
  final double dx;
  final double dy;
  final double baseSize; // fraction of the view's shortest side
  final Color color;
  const _Zone(this.sensor, this.dx, this.dy, this.baseSize, this.color);
}

/// Zone positions on the left outline of `feet.png`, unchanged from the
/// earlier calibrated layout.
const _zones = [
  _Zone(InsoleSensor.toe, 0.34, 0.11, 0.20, Color(0xFF7C6FF0)),
  _Zone(InsoleSensor.inner, 0.34, 0.33, 0.16, Color(0xFF6E5AE6)),
  _Zone(InsoleSensor.outer, 0.14, 0.37, 0.16, Color(0xFF8B7CF0)),
  _Zone(InsoleSensor.heel, 0.34, 0.80, 0.22, Color(0xFF22D3EE)),
];

class _LoadPainter extends CustomPainter {
  final SensorLoads shares;
  final int contactMask;

  _LoadPainter({required this.shares, required this.contactMask});

  @override
  void paint(Canvas canvas, Size size) {
    for (final zone in _zones) {
      final value = shares.of(zone.sensor).clamp(0.0, 1.0);
      final center = Offset(zone.dx * size.width, zone.dy * size.height);
      final radius = size.shortestSide * zone.baseSize * (0.7 + value * 0.5);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            zone.color.withValues(alpha: 0.22 + value * 0.6),
            zone.color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, glow);

      if ((contactMask & zone.sensor.bit) != 0) {
        final ring = Paint()
          ..color = zone.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(center, size.shortestSide * zone.baseSize * 0.45, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LoadPainter oldDelegate) {
    return oldDelegate.contactMask != contactMask ||
        oldDelegate.shares.heel != shares.heel ||
        oldDelegate.shares.inner != shares.inner ||
        oldDelegate.shares.outer != shares.outer ||
        oldDelegate.shares.toe != shares.toe;
  }
}
