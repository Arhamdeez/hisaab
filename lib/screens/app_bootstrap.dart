import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/data/local_data_persistence.dart';
import '../widgets/glass_container.dart';
import '../core/app_launch_scope.dart';
import '../providers/transaction_provider.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import 'splash_screen.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool? _onboardingComplete;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onboardingComplete =
          prefs.getBool(LocalDataPersistence.onboardingCompleteKey) ?? false;
    });
  }

  Widget _appContent() {
    if (!_onboardingComplete!) {
      return OnboardingScreen(
        key: const ValueKey('onboarding'),
        onComplete: () async {
          final provider = context.read<TransactionProvider>();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(LocalDataPersistence.onboardingCompleteKey, true);
          if (!mounted) return;
          setState(() => _onboardingComplete = true);
          await provider.reload();
        },
      );
    }
    return const MainShell(key: ValueKey('shell'));
  }

  @override
  Widget build(BuildContext context) {
    final content = _onboardingComplete == null
        ? const SizedBox.shrink()
        : _appContent();

    if (!_splashDone) {
      return AppLaunchScope(
        splashComplete: false,
        child: SplashGate(
          ready: _onboardingComplete != null,
          onFinished: () {
            if (mounted) setState(() => _splashDone = true);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              const AppBackground(),
              content,
            ],
          ),
        ),
      );
    }

    return AppLaunchScope(
      splashComplete: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          _appContent(),
        ],
      ),
    );
  }
}
