import 'package:flutter/material.dart';

import '../screens/inbox_screen.dart';
import '../screens/settings_screen.dart';

/// Lets nested screens switch the main bottom-nav tab.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  final ValueChanged<int> selectTab;

  static ShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>();
  }

  static void goToTab(BuildContext context, int index) {
    maybeOf(context)?.selectTab(index);
  }

  static void goToTransactions(BuildContext context) => goToTab(context, 1);

  static Future<void> goToSettings(BuildContext context) =>
      SettingsScreen.open(context);

  static Future<void> goToInbox(BuildContext context) =>
      InboxScreen.open(context);

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      oldWidget.selectTab != selectTab;
}
