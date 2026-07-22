import 'dart:math' as math;

import 'package:flutter/material.dart';

class RingMetric {
  final String label;
  final double value; // 0..1
  final Color color;

  const RingMetric({required this.label, required this.value, required this.color});
}

/// Apple Health / Fitness "Activity rings", redrawn from scratch with
/// [CustomPainter] (no chart library dependency). Concentric rings sweep
/// clockwise from 12 o'clock, each animating independently whenever its
/// underlying value changes so partial updates (e.g. only cadence moved)
/// don't restart the whole gauge.
///
/// The three inputs are:
///   - Stability index (outer ring, red) - the score the web app showed as
///     a single RadialBarChart.
///   - Cadence load (middle ring, green) - normalized steps-per-minute
///     against a healthy-range target.
///   - Impact safety (inner ring, cyan) - inverse of impact severity, so a
///     full ring means "gentle footfalls" not "high impact".
class HealthRings extends StatefulWidget {
  final List<RingMetric> rings;
  final double size;
  final double strokeWidth;
  final Widget? center;

  /// Whether a live/simulated stream is currently flowing. Gates the subtle
  /// idle "breathing" pulse below - a static (disconnected) gauge shouldn't
  /// breathe, since that would read as "still receiving data" when it isn't.
  final bool isLive;

  const HealthRings({
    super.key,
    required this.rings,
    this.size = 150,
    this.strokeWidth = 14,
    this.center,
    this.isLive = false,
  });

  @override
  State<HealthRings> createState() => _HealthRingsState();
}

class _HealthRingsState extends State<HealthRings> with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final Animation<double> _breatheScale;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _breatheScale = Tween(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeOutCubic),
    );
    if (widget.isLive) _breatheController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant HealthRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !_breatheController.isAnimating) {
      _breatheController.repeat(reverse: true);
    } else if (!widget.isLive && _breatheController.isAnimating) {
      _breatheController.stop();
      _breatheController.value = 0;
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaleTransition(
      scale: _breatheScale,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < widget.rings.length; i++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.rings[i].value.clamp(0, 1)),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, animatedValue, _) {
                  return CustomPaint(
                    size: Size.square(widget.size),
                    painter: _RingPainter(
                      progress: animatedValue,
                      color: widget.rings[i].color,
                      backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEDEDF2),
                      strokeWidth: widget.strokeWidth,
                      inset: i * (widget.strokeWidth + 6),
                    ),
                  );
                },
              ),
            if (widget.center != null) widget.center!,
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double inset;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.inset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      inset + strokeWidth / 2,
      inset + strokeWidth / 2,
      size.width - inset * 2 - strokeWidth,
      size.height - inset * 2 - strokeWidth,
    );

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, backgroundPaint);

    if (progress <= 0) return;

    final foregroundPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [color.withOpacity(0.55), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(rect, startAngle, sweepAngle, false, foregroundPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
