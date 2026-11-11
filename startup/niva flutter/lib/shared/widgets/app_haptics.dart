import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HapticPreferences extends InheritedWidget {
  final bool enabled;
  const HapticPreferences(
      {super.key, required this.enabled, required super.child});
  @override
  bool updateShouldNotify(HapticPreferences oldWidget) =>
      enabled != oldWidget.enabled;
}

class AppHaptics {
  AppHaptics._();
  static bool enabled(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HapticPreferences>()
          ?.enabled ??
      true;
  static void selectionClick(BuildContext context) {
    if (enabled(context)) HapticFeedback.selectionClick();
  }

  static void mediumImpact(BuildContext context) {
    if (enabled(context)) HapticFeedback.mediumImpact();
  }
}
