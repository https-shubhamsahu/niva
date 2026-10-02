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
    final decoration = BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(radius),
    );
    if (onTap == null) {
      return AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }

    // Paint on the Material so its pressed and keyboard-focus ink remains
    // visible above the card background.
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(
          decoration: decoration,
          padding: padding,
          child: child,
        ),
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
