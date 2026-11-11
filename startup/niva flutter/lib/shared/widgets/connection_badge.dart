import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Pulsing dot + label used in the dashboard header - green/pulsing when a
/// live or simulated stream is flowing, gray otherwise.
class ConnectionBadge extends StatefulWidget {
  final bool isLive;
  final String label;

  const ConnectionBadge({super.key, required this.isLive, required this.label});

  @override
  State<ConnectionBadge> createState() => _ConnectionBadgeState();
}

class _ConnectionBadgeState extends State<ConnectionBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Built eagerly here (not as a lazy `late final` initializer) - the
    // AnimatedBuilder that reads `_controller` is only present in the build
    // tree when `widget.isLive` is true, so a lazy initializer would defer
    // construction until the first access. If that first access ends up
    // being in dispose() (e.g. this badge is never built live before it's
    // removed), creating the AnimationController there does an
    // InheritedWidget lookup on an already-deactivated element and throws.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isLive ? AppColors.success : theme.textTheme.labelSmall?.color ?? Colors.grey;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 10,
          height: 10,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isLive)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final scale = 1 + _controller.value * 1.4;
                    final opacity = (1 - _controller.value).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity * 0.6,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(widget.label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
