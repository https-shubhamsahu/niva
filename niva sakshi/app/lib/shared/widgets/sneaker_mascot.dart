import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decorative teammate; this animation never represents exercise technique.
/// OS/app reduced motion and hidden tabs stop the ticker completely.
class SneakerMascot extends StatefulWidget {
  final double size;
  const SneakerMascot({super.key, this.size = 180});
  @override
  State<SneakerMascot> createState() => _SneakerMascotState();
}

class _SneakerMascotState extends State<SneakerMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _float.stop();
      _float.value = 0;
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _float,
            child: Image.asset('assets/mascot/sneaker-wave.png',
                width: widget.size, height: widget.size, fit: BoxFit.contain),
            builder: (_, child) {
              final wave = math.sin(_float.value * math.pi * 2);
              return Transform.translate(
                  offset: Offset(0, wave * 5),
                  child: Transform.rotate(angle: wave * 0.035, child: child));
            },
          ),
        ),
      );
}

/// One-time reveal; a settled frame is used when motion is reduced.
class WelcomeReveal extends StatelessWidget {
  final Widget child;
  const WelcomeReveal({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(
            begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, (1 - value) * 18), child: child)),
      );
}
