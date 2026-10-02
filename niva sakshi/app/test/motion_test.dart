import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niva/features/experience/launch_screen.dart';
import 'package:niva/shared/widgets/motion.dart';

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
    home: Builder(
        builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: Scaffold(body: child))));

double _opacityAbove(WidgetTester tester, Finder finder) {
  final opacities = tester.widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)));
  return opacities.fold(1.0, (value, o) => value * o.opacity);
}

class _Counted extends StatefulWidget {
  static int created = 0;
  const _Counted();
  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    _Counted.created++;
  }

  @override
  Widget build(BuildContext context) => const Text('App home');
}

void main() {
  testWidgets('entrance rises into place once, and is instant when reduced',
      (tester) async {
    await tester
        .pumpWidget(_app(const Entrance(index: 2, child: Text('Card'))));
    await tester.pump(const Duration(milliseconds: 120));
    expect(_opacityAbove(tester, find.text('Card')), lessThan(1));
    await tester.pumpAndSettle();
    expect(find.byType(Opacity), findsNothing);

    await tester.pumpWidget(_app(
        const Entrance(index: 2, child: Text('Still card')),
        reduced: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(_opacityAbove(tester, find.text('Still card')), 1);
  });

  testWidgets('entrance in a hidden tab waits until the tab is shown',
      (tester) async {
    Widget tab(bool visible) => _app(TickerMode(
        enabled: visible, child: const Entrance(child: Text('Hidden tab'))));
    await tester.pumpWidget(tab(false));
    await tester.pump(const Duration(seconds: 2));
    expect(_opacityAbove(tester, find.text('Hidden tab')), 0);
    await tester.pumpWidget(tab(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacityAbove(tester, find.text('Hidden tab')),
        allOf(greaterThan(0), lessThan(1)));
    await tester.pumpAndSettle();
    expect(_opacityAbove(tester, find.text('Hidden tab')), 1);
  });

  testWidgets('live pulse runs only while active and motion is allowed',
      (tester) async {
    await tester
        .pumpWidget(_app(const LivePulse(color: Colors.green, active: true)));
    expect(tester.hasRunningAnimations, isTrue);
    await tester
        .pumpWidget(_app(const LivePulse(color: Colors.green, active: false)));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(_app(
        const LivePulse(color: Colors.green, active: true),
        reduced: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('rolling values never show an in-between number', (tester) async {
    await tester.pumpWidget(_app(const RollingText('104')));
    await tester.pumpWidget(_app(const RollingText('108')));
    await tester.pump(const Duration(milliseconds: 150));
    // Only the old and new real values exist while rolling.
    final shown =
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toSet();
    expect(shown, {'104', '108'});
    await tester.pumpAndSettle();
    expect(find.text('104'), findsNothing);
    expect(find.text('108'), findsOneWidget);

    await tester.pumpWidget(_app(const RollingText('5'), reduced: true));
    await tester.pumpWidget(_app(const RollingText('6'), reduced: true));
    await tester.pump();
    expect(find.text('5'), findsNothing);
  });

  testWidgets('launch dissolves into the app without rebuilding it',
      (tester) async {
    _Counted.created = 0;
    await tester.pumpWidget(
        const MaterialApp(home: LaunchExperience(child: _Counted())));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('App home'), findsNothing);
    expect(find.text('SAKSHI'), findsOneWidget);
    // The app mounts under the launch layer as it starts to dissolve.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('App home'), findsOneWidget);
    expect(find.text('SAKSHI'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('SAKSHI'), findsNothing);
    expect(find.text('App home'), findsOneWidget);
    expect(_Counted.created, 1);
  });
}
