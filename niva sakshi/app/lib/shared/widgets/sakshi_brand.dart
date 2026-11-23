import 'package:flutter/material.dart';

/// The witness eye, warm observation dot and stable beam form one identity.
/// Geometry matches tool/build_brand.mjs and the native launcher resources.
class SakshiMark extends StatelessWidget {
  /// [openness] squashes the eye and dot vertically for a blink (1 = open).
  final double size, progress, openness;
  const SakshiMark(
      {super.key, this.size = 64, this.progress = 1, this.openness = 1});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
              painter: SakshiMarkPainter(
                  progress: progress,
                  openness: openness,
                  dark: Theme.of(context).brightness == Brightness.dark))));
}

class SakshiMarkPainter extends CustomPainter {
  final double progress, openness;
  final bool dark;
  const SakshiMarkPainter(
      {this.progress = 1, this.openness = 1, this.dark = false});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 128, size.height / 128);
    final eyeColor = dark ? const Color(0xFFA9D4FF) : const Color(0xFF0066CC);
    final beamColor = dark ? const Color(0xFFEAF3FF) : const Color(0xFF173B59);
    final eye = Path()
      ..moveTo(16, 56)
      ..cubicTo(40, 22, 88, 22, 112, 56)
      ..cubicTo(88, 90, 40, 90, 16, 56)
      ..close();
    final reveal = ((progress - .12) / .64).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(0, 56);
    canvas.scale(1, openness.clamp(.08, 1));
    canvas.translate(0, -56);
    final eyePaint = Paint()
      ..color = eyeColor
      ..strokeWidth = 12
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    // An extracted segment is open even at full length, which leaves a notch
    // where its ends meet; the finished eye is drawn as the closed path.
    if (reveal >= 1) {
      canvas.drawPath(eye, eyePaint);
    } else {
      for (final metric in eye.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * reveal),
            eyePaint..strokeCap = StrokeCap.round);
      }
    }
    final witness = ((progress - .5) / .35).clamp(0.0, 1.0);
    canvas.drawCircle(
        Offset(64, 56 + 8 * (1 - witness)),
        12 * Curves.easeOutCubic.transform(witness),
        Paint()
          ..color = dark ? const Color(0xFFFF9577) : const Color(0xFFF47758));
    canvas.restore();
    final beam = (progress / .4).clamp(0.0, 1.0);
    canvas.drawLine(
        Offset(64 - 28 * beam, 106),
        Offset(64 + 28 * beam, 106),
        Paint()
          ..color = beamColor.withValues(alpha: beam)
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SakshiMarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.openness != openness ||
      oldDelegate.dark != dark;
}
