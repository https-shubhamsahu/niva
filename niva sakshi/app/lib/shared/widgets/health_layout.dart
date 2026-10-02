import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'motion.dart';

/// Width at which the app switches to its desktop layout: a sidebar instead
/// of the tab bar, and page sections in two columns.
const double kWideLayout = 900;
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideLayout;

/// A readable, bounded page. It scrolls only when its contents need the space,
/// including landscape and enlarged text; primary actions can live outside it.
/// Its sections rise into place in order the first time the page is seen.
///
/// On a wide screen, everything before the first [HealthSection] stays full
/// width and each section (its heading plus what follows) flows into the
/// shorter of two columns, like a desktop dashboard.
class HealthPage extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  const HealthPage(
      {super.key,
      required this.children,
      this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12)});

  @override
  Widget build(BuildContext context) =>
      SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final entered = [
          for (var i = 0; i < children.length; i++)
            Entrance(index: i, child: children[i])
        ];
        final firstSection = children.indexWhere((c) => c is HealthSection);
        final wide = constraints.maxWidth >= kWideLayout &&
            firstSection >= 0 &&
            children.skip(firstSection + 1).any((c) => c is HealthSection);
        if (!wide) {
          return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(padding: padding, children: entered)));
        }
        final groups = <List<Widget>>[];
        for (var i = firstSection; i < children.length; i++) {
          if (children[i] is HealthSection) groups.add([]);
          groups.last.add(entered[i]);
        }
        final columns = [<Widget>[], <Widget>[]];
        final weight = [0, 0];
        for (final group in groups) {
          final target = weight[0] <= weight[1] ? 0 : 1;
          columns[target].addAll(group);
          weight[target] += group.length;
        }
        return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(36, 28, 36, 36),
                    children: [
                      ...entered.take(firstSection),
                      const SizedBox(height: 8),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: columns[0])),
                            const SizedBox(width: 28),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: columns[1])),
                          ]),
                    ])));
      }));
}

class HealthHeader extends StatelessWidget {
  final String title, subtitle;
  final Widget? trailing;
  const HealthHeader(
      {super.key, required this.title, required this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
        ])),
        if (trailing != null) trailing!
      ]));
}

class HealthSection extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const HealthSection(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (trailing != null) trailing!
      ]));
}

/// Grouped navigation row with a full-size touch target.
class HealthRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;
  const HealthRow(
      {super.key,
      required this.title,
      this.subtitle,
      required this.icon,
      this.color = AppColors.brand,
      this.onTap,
      this.trailing});
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, .4)!
        : color;
    return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        minLeadingWidth: 32,
        leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accent, size: 20)),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        trailing: trailing ??
            (onTap == null
                ? null
                : const Icon(Icons.chevron_right_rounded, size: 20)),
        onTap: onTap);
  }
}

void openHealthDetails(BuildContext context, String title, Widget child) {
  showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85),
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          tooltip: 'Close details',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded))
                    ]),
                    const SizedBox(height: 8),
                    child,
                  ]))));
}
