import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shared motion vocabulary: content rises into place, touched cards give
/// way, changed values roll and live state breathes. Every effect respects
/// the system or in-app reduced-motion choice and stops in hidden tabs.
bool motionReduced(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Fades and lifts its child into place once, staggered by [index].
/// Waits until its tab is visible so each page animates when first seen.
class Entrance extends StatefulWidget {
  final int index;
  final Widget child;
  const Entrance({super.key, this.index = 0, required this.child});
  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  static const _step = 45, _length = 520, _maxSteps = 8;
  late final int _delay = widget.index.clamp(0, _maxSteps) * _step;
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: Duration(milliseconds: _delay + _length));
  late final Animation<double> _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(_delay / (_delay + _length), 1,
          curve: AppMotion.springCurve));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionReduced(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed &&
        TickerMode.valuesOf(context).enabled) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) {
        final t = _progress.value;
        if (t == 1) return child!;
        return Opacity(
            opacity: t,
            child: Transform.translate(
                offset: Offset(0, 18 * (1 - t)),
                child: Transform.scale(scale: .98 + .02 * t, child: child)));
      });
}

/// Gently shrinks while pressed, like a grouped card giving way under a finger.
class Pressable extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const Pressable({super.key, required this.child, this.enabled = true});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || motionReduced(context)) return widget.child;
    return Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
            scale: _down ? .97 : 1,
            duration: Duration(milliseconds: _down ? 110 : 260),
            curve: _down ? Curves.easeOut : Curves.easeOutBack,
            child: widget.child));
  }
}

/// A value that rolls upward when it changes. Shows only real values: the
/// old text leaves while the new one arrives, with no interpolated numbers.
class RollingText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const RollingText(this.text, {super.key, this.style});
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
      duration: motionReduced(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      switchInCurve: AppMotion.springCurve,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.centerStart,
          clipBehavior: Clip.none,
          children: [...previous, if (current != null) current]),
      transitionBuilder: (child, animation) {
        final entering = child.key == ValueKey(text);
        return ClipRect(
            child: SlideTransition(
                position: Tween(
                        begin: Offset(0, entering ? .45 : -.45),
                        end: Offset.zero)
                    .animate(animation),
                child: FadeTransition(opacity: animation, child: child)));
      },
      child: Text(text, key: ValueKey(text), style: style));
}

/// A dot that radiates a soft ring while [active], like a live heart reading.
class LivePulse extends StatefulWidget {
  final Color color;
  final bool active;
  final double size;
  const LivePulse(
      {super.key, required this.color, required this.active, this.size = 10});
  @override
  State<LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  void _sync() {
    final run = widget.active &&
        !motionReduced(context) &&
        TickerMode.valuesOf(context).enabled;
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LivePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox.square(
          dimension: widget.size * 2.4,
          child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_controller.value);
                return Stack(alignment: Alignment.center, children: [
                  if (_controller.isAnimating)
                    Container(
                        width: widget.size * (1 + 1.4 * t),
                        height: widget.size * (1 + 1.4 * t),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                widget.color.withValues(alpha: .35 * (1 - t)))),
                  AnimatedContainer(
                      duration: motionReduced(context)
                          ? Duration.zero
                          : AppMotion.fast,
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.active
                              ? widget.color
                              : widget.color.withValues(alpha: .35))),
                ]);
              })));
}

/// Pops its child in with a little overshoot, for a completed moment.
class PopIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  @override
  Widget build(BuildContext context) {
    if (motionReduced(context)) return child;
    final total = delay + const Duration(milliseconds: 560);
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: total,
        child: child,
        builder: (context, t, child) {
          final local = ((t - start) / (1 - start)).clamp(0.0, 1.0);
          return Opacity(
              opacity: local.clamp(0, 1),
              child: Transform.scale(
                  scale: Curves.elasticOut.transform(local) * .6 + .4 * local,
                  child: child));
        });
  }
}
