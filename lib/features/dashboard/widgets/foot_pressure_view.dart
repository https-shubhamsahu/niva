import 'package:flutter/material.dart';

import '../../../core/models/biomechanics_metrics.dart';

/// Live plantar-pressure map: a procedurally drawn foot outline with four
/// glowing pressure zones (heel / inner / outer / toe) and an animated
/// center-of-pressure marker.
///
/// The original web app overlaid a heatmap canvas on top of an uploaded
/// foot photo (`FootHeatmap.tsx` + `public/feet.png`). This version draws
/// the foot procedurally instead, so the widget has zero image assets to
/// ship or go stale, and the outline can be recolored per theme for free.
class FootPressureView extends StatelessWidget {
  final FootPressure pressure; // normalized 0..1 per zone
  final CopPoint cop;
  final List<CopPoint> copTrail;
  final bool isConnected;

  const FootPressureView({
    super.key,
    required this.pressure,
    required this.cop,
    this.copTrail = const [],
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: isDark ? const Color(0xFF15161A) : const Color(0xFFF7F8FB),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: isConnected ? 1 : 0.35,
                child: CustomPaint(
                  painter: _FootPainter(pressure: pressure, isDark: isDark),
                ),
              ),
              // Fading center-of-pressure trail.
              for (var i = 0; i < copTrail.length; i++)
                _CopDot(
                  point: copTrail[i],
                  opacity: (i + 1) / copTrail.length * 0.35,
                  size: 6,
                  color: AppColorsRef.trail,
                ),
              if (isConnected)
                _CopDot(
                  point: cop,
                  opacity: 1,
                  size: 12,
                  color: AppColorsRef.copMarker,
                  animate: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppColorsRef {
  AppColorsRef._();
  static const copMarker = Color(0xFF415AEE);
  static const trail = Color(0xFF9AA7F5);
}

class _CopDot extends StatelessWidget {
  final CopPoint point;
  final double opacity;
  final double size;
  final Color color;
  final bool animate;

  const _CopDot({
    required this.point,
    required this.opacity,
    required this.size,
    required this.color,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, spreadRadius: 1),
        ],
      ),
    );

    return AnimatedFractionalPositioned(
      duration: animate ? const Duration(milliseconds: 260) : Duration.zero,
      curve: Curves.easeOutCubic,
      // x/y are normalized 0..1 within the foot's bounding box; flip y so
      // 0 = heel (bottom) and 1 = toe (top) as in the biomechanics engine.
      left: 0.5 + (point.x - 0.5) * 0.7,
      top: 1 - point.y * 0.86 - 0.05,
      child: Opacity(opacity: opacity, child: dot),
    );
  }
}

/// Minimal drop-in replacement for a fractional positioning helper -
/// Flutter has no built-in `FractionallyPositioned` with implicit
/// animation, so this wraps [AnimatedAlign] scaled to the parent [Stack].
class AnimatedFractionalPositioned extends StatelessWidget {
  final double left;
  final double top;
  final Duration duration;
  final Curve curve;
  final Widget child;

  const AnimatedFractionalPositioned({
    super.key,
    required this.left,
    required this.top,
    required this.duration,
    required this.curve,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      duration: duration,
      curve: curve,
      alignment: Alignment(
        (left.clamp(0.0, 1.0) * 2) - 1,
        (top.clamp(0.0, 1.0) * 2) - 1,
      ),
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: child,
      ),
    );
  }
}

class _FootPainter extends CustomPainter {
  final FootPressure pressure;
  final bool isDark;

  _FootPainter({required this.pressure, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = _footOutlinePath(size);
    canvas.drawPath(path, outlinePaint);

    _drawZone(canvas, size, dx: 0.5, dy: 0.86, value: pressure.heel, label: 'heel');
    _drawZone(canvas, size, dx: 0.30, dy: 0.46, value: pressure.inner, label: 'inner');
    _drawZone(canvas, size, dx: 0.70, dy: 0.46, value: pressure.outer, label: 'outer');
    _drawZone(canvas, size, dx: 0.5, dy: 0.12, value: pressure.toe, label: 'toe');
  }

  /// A simplified, single-foot silhouette traced with cubic beziers -
  /// stylized on purpose rather than anatomically exact, matching the
  /// "abstract clinical iconography" look of Apple Health's own body maps.
  Path _footOutlinePath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.5, h * 0.04);
    path.cubicTo(w * 0.68, h * 0.05, w * 0.74, h * 0.22, w * 0.7, h * 0.38);
    path.cubicTo(w * 0.66, h * 0.5, w * 0.82, h * 0.55, w * 0.82, h * 0.72);
    path.cubicTo(w * 0.82, h * 0.9, w * 0.68, h * 0.97, w * 0.5, h * 0.97);
    path.cubicTo(w * 0.32, h * 0.97, w * 0.18, h * 0.9, w * 0.18, h * 0.72);
    path.cubicTo(w * 0.18, h * 0.55, w * 0.34, h * 0.5, w * 0.3, h * 0.38);
    path.cubicTo(w * 0.26, h * 0.22, w * 0.32, h * 0.05, w * 0.5, h * 0.04);
    path.close();
    return path;
  }

  void _drawZone(
    Canvas canvas,
    Size size, {
    required double dx,
    required double dy,
    required double value,
    required String label,
  }) {
    final center = Offset(size.width * dx, size.height * dy);
    final clamped = value.clamp(0.0, 1.0);
    final radius = size.shortestSide * (0.11 + clamped * 0.10);

    final color = Color.lerp(
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE6E9F5),
      const Color(0xFFFF453A),
      clamped,
    )!;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(0.9), color.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _FootPainter oldDelegate) {
    return oldDelegate.pressure.heel != pressure.heel ||
        oldDelegate.pressure.inner != pressure.inner ||
        oldDelegate.pressure.outer != pressure.outer ||
        oldDelegate.pressure.toe != pressure.toe ||
        oldDelegate.isDark != isDark;
  }
}
