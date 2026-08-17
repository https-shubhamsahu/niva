import 'package:flutter/material.dart';

/// The single reusable "card" shape used everywhere - Apple Health leans
/// heavily on one consistent grouped-card language rather than a different
/// shadow/radius per screen, so this is intentionally the only card widget
/// in the app.
class RoundedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const RoundedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Small uppercase micro-label used above every metric value, e.g.
/// "STABILITY INDEX" or "CADENCE".
class MetricLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const MetricLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    if (trailing == null) {
      return Text(text, style: style);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: style),
        const Spacer(),
        trailing!,
      ],
    );
  }
}
