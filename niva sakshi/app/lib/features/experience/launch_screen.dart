import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../shared/widgets/sakshi_brand.dart';

/// Continues the native splash: the mark starts where Android left it, the
/// witness blinks, a halo ripples out, the mark rises as the wordmark arrives,
/// then the whole screen dissolves into the app beneath it.
/// Finite, independent of connectivity, and skipped with reduced motion.
class LaunchExperience extends StatefulWidget {
  final Widget child;
  const LaunchExperience({super.key, required this.child});

  /// Matches the mark on the native splash (128 of a 192 viewport at 0.9,
  /// inside Android 12's 240dp icon), so the hand-off does not jump.
  static const markSize = 144.0;

  @override
  State<LaunchExperience> createState() => _LaunchExperienceState();
}

class _LaunchExperienceState extends State<LaunchExperience>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..addListener(() {
      if (!_showChild && _animation.value >= _dissolveAt && mounted) {
        setState(() => _showChild = true);
      }
    })
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
  static const _dissolveAt = .72;
  bool _done = false, _started = false, _showChild = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _done = _showChild = true;
    } else if (!_started) {
      _started = true;
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  /// Progress of [t] through the window [from]..[to], eased.
  static double _phase(double t, double from, double to,
          [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    // The app keeps one position in this stack so it is not rebuilt when the
    // launch layer leaves.
    return Stack(fit: StackFit.expand, children: [
      if (_showChild)
        IgnorePointer(
            ignoring: !_done,
            child: KeyedSubtree(
                key: const ValueKey('launched-app'), child: widget.child)),
      if (!_done) _launchLayer(context),
    ]);
  }

  Widget _launchLayer(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFEAF3FF) : const Color(0xFF173B59);
    final accent = dark ? const Color(0xFFA9D4FF) : const Color(0xFF0066CC);
    return Semantics(
        label: 'Niva Sakshi is opening',
        child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final t = _animation.value;
              // A quick blink: closes over 90 ms and reopens over 150 ms.
              final blink = t < .1
                  ? 1.0
                  : t < .16
                      ? 1 - _phase(t, .1, .16, Curves.easeIn)
                      : _phase(t, .16, .26, Curves.easeOutBack);
              final halo = _phase(t, .2, .62, Curves.easeOut);
              final rise = _phase(t, .24, .6, Curves.easeInOutCubic);
              final word = _phase(t, .34, .62);
              final spread = _phase(t, .4, .7);
              final tagline = _phase(t, .48, .72);
              final out = _phase(t, _dissolveAt, 1, Curves.easeInCubic);
              return Opacity(
                  opacity: 1 - out,
                  child: Transform.scale(
                      scale: 1 + .06 * out,
                      child: Material(
                          color: theme.scaffoldBackgroundColor,
                          child: Stack(alignment: Alignment.center, children: [
                            if (halo > 0 && halo < 1)
                              Transform.translate(
                                  offset: Offset(0, -70 * rise - 8),
                                  child: Container(
                                      width: LaunchExperience.markSize *
                                          (1 + 1.1 * halo),
                                      height: LaunchExperience.markSize *
                                          (1 + 1.1 * halo),
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: accent.withValues(
                                                  alpha: .55 * (1 - halo)),
                                              width: 2.5)))),
                            Transform.translate(
                                offset: Offset(0, -70 * rise),
                                child: Transform.scale(
                                    scale: 1 - .14 * rise,
                                    child: SakshiMark(
                                        size: LaunchExperience.markSize,
                                        openness: math.max(blink, .08)))),
                            Transform.translate(
                                offset: Offset(0, 96 + 24 * (1 - word)),
                                child: Opacity(
                                    opacity: word,
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('niva',
                                              style: theme
                                                  .textTheme.displayLarge
                                                  ?.copyWith(
                                                      fontSize: 56,
                                                      letterSpacing: -3,
                                                      color: ink)),
                                          const SizedBox(height: 5),
                                          Text('SAKSHI',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                      letterSpacing:
                                                          2 + 4 * spread,
                                                      color: accent)),
                                          const SizedBox(height: 26),
                                          Opacity(
                                              opacity: tagline,
                                              child: Text('Balance. Witnessed.',
                                                  style: theme
                                                      .textTheme.bodyMedium)),
                                        ]))),
                          ]))));
            }));
  }
}
