import 'package:flutter/material.dart';

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

  static void goToSettings(BuildContext context) => goToTab(context, 2);

  static void goToInbox(BuildContext context) => goToTab(context, 3);

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      oldWidget.selectTab != selectTab;
}
