import 'package:flutter/material.dart';

/// Signals when the splash bubble transition has finished and the shell is stable.
class AppLaunchScope extends InheritedWidget {
  const AppLaunchScope({
    super.key,
    required this.splashComplete,
    required super.child,
  });

  final bool splashComplete;

  static AppLaunchScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLaunchScope>();
    assert(scope != null, 'AppLaunchScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppLaunchScope oldWidget) =>
      oldWidget.splashComplete != splashComplete;
}
