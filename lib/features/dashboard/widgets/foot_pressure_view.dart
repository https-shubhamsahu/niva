import 'package:flutter/material.dart';

import '../../../core/models/biomechanics_metrics.dart';

/// Live plantar-pressure map, redesigned around the FSR spatial-distribution
/// reference diagram (`assets/images/feet.png`) instead of a procedurally
/// drawn outline. Four glow zones per foot - toe, 1st MT (medial forefoot),
/// 5th MT (lateral forefoot), heel - map directly onto the engine's
/// toe/inner/outer/heel readings, matching exact screen-space coordinates
/// calibrated against this asset (see CONNECTIVITY_PLAN.md history / Figma
/// design file for how these were measured).
///
/// The insole is a single physical sensor, so both feet render the same
/// live reading mirrored left/right - this is a visual completeness choice
/// (matching the reference diagram's two-foot layout), not a claim of
/// bilateral instrumentation. The live center-of-pressure marker and its
/// fading trail are only ever shown on the left foot, since that's the one
/// actually wired to real x/y data; the right foot gets the same static "+"
/// reference crosshair both feet share.
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
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/feet.png', fit: BoxFit.cover),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: isConnected ? 1 : 0.25,
              child: CustomPaint(painter: _PressureGlowPainter(pressure: pressure)),
            ),
            const _Crosshair(dx: _leftHalfCenter),
            const _Crosshair(dx: _rightHalfCenter),
            for (var i = 0; i < copTrail.length; i++)
              _CopDot(
                point: _mapCopToLeftFoot(copTrail[i]),
                opacity: (i + 1) / copTrail.length * 0.35,
                size: 6,
                color: AppColorsRef.trail,
              ),
            if (isConnected)
              _CopDot(
                point: _mapCopToLeftFoot(cop),
                opacity: 1,
                size: 12,
                color: AppColorsRef.copMarker,
                animate: true,
              ),
          ],
        ),
      ),
    );
  }
}

const _leftHalfCenter = 0.34;
const _rightHalfCenter = 0.66;
const _crosshairY = 0.57;

/// Reuses the same single-foot mapping the original web/Flutter COP marker
/// used, just rescaled into the left foot's half of the two-foot canvas.
CopPoint _mapCopToLeftFoot(CopPoint point) {
  final localX = 0.5 + (point.x - 0.5) * 0.7;
  final localY = 1 - point.y * 0.86 - 0.05;
  return CopPoint(x: localX * 0.5, y: localY);
}

class AppColorsRef {
  AppColorsRef._();
  static const copMarker = Color(0xFF415AEE);
  static const trail = Color(0xFF9AA7F5);
}

class _Zone {
  final double dx;
  final double dy;
  final double baseSize; // fraction of the view's shortest side
  final Color color;
  const _Zone(this.dx, this.dy, this.baseSize, this.color);
}

const _toeColor = Color(0xFF7C6FF0);
const _mt1Color = Color(0xFF6E5AE6);
const _mt5Color = Color(0xFF8B7CF0);
const _heelColor = Color(0xFF22D3EE);

/// Zone screen-space coordinates, calibrated against `feet.png` (see the
/// Figma "GaitGuard Nexus - Apple Health Redesign" file's Today screen for
/// the grid-verified source of these values).
const _leftFootZones = {
  'toe': _Zone(0.34, 0.11, 0.20, _toeColor),
  'mt1': _Zone(0.34, 0.33, 0.16, _mt1Color),
  'mt5': _Zone(0.14, 0.37, 0.16, _mt5Color),
  'heel': _Zone(0.34, 0.80, 0.22, _heelColor),
};
const _rightFootZones = {
  'toe': _Zone(0.66, 0.11, 0.20, _toeColor),
  'mt1': _Zone(0.66, 0.33, 0.16, _mt1Color),
  'mt5': _Zone(0.86, 0.37, 0.16, _mt5Color),
  'heel': _Zone(0.66, 0.80, 0.22, _heelColor),
};

class _PressureGlowPainter extends CustomPainter {
  final FootPressure pressure;

  _PressureGlowPainter({required this.pressure});

  @override
  void paint(Canvas canvas, Size size) {
    final values = {
      'toe': pressure.toe.clamp(0.0, 1.0),
      'mt1': pressure.inner.clamp(0.0, 1.0),
      'mt5': pressure.outer.clamp(0.0, 1.0),
      'heel': pressure.heel.clamp(0.0, 1.0),
    };

    for (final zones in [_leftFootZones, _rightFootZones]) {
      for (final entry in zones.entries) {
        _drawGlow(canvas, size, entry.value, values[entry.key]!);
      }
    }
  }

  void _drawGlow(Canvas canvas, Size size, _Zone zone, double value) {
    final center = Offset(zone.dx * size.width, zone.dy * size.height);
    final radius = size.shortestSide * zone.baseSize * (0.7 + value * 0.5);
    final opacity = 0.22 + value * 0.6;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [zone.color.withOpacity(opacity), zone.color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _PressureGlowPainter oldDelegate) {
    return oldDelegate.pressure.heel != pressure.heel ||
        oldDelegate.pressure.inner != pressure.inner ||
        oldDelegate.pressure.outer != pressure.outer ||
        oldDelegate.pressure.toe != pressure.toe;
  }
}

/// Static "+" reference mark shared by both feet - purely decorative,
/// matching the FSR reference diagram's target mark.
class _Crosshair extends StatelessWidget {
  final double dx;
  const _Crosshair({required this.dx});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment((dx * 2) - 1, (_crosshairY * 2) - 1),
      child: CustomPaint(size: const Size(16, 16), painter: _CrosshairPainter()),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawShadow(
      Path()
        ..moveTo(0, size.height / 2)
        ..lineTo(size.width, size.height / 2)
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width / 2, size.height),
      Colors.black,
      3,
      false,
    );
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) => false;
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
      left: point.x,
      top: point.y,
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
