import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart' show AppRadius;
import '../features/ingest/ingest_service.dart';
import '../widgets/glass_container.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackground(),
          SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _OnboardPage(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Track Cash Flow',
                    body:
                        'Automatically capture spending from bank alerts, JazzCash, SMS, and Gmail — all in PKR.',
                  ),
                  _OnboardPage(
                    icon: Icons.notifications_active_outlined,
                    title: 'Connect Sources',
                    body:
                        'Grant notification and SMS access on Android. Connect Gmail to sync email alerts.',
                  ),
                  _OnboardPage(
                    icon: Icons.pie_chart_rounded,
                    title: 'Month-end Reports',
                    body:
                        'See totals, category breakdowns, and export CSV at month end.',
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _page == i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? AppColors.primary
                          : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_page == 1) ...[
                    _PermissionButton(
                      label: 'Enable Notification Access',
                      onPressed: _requestNotificationAccess,
                    ),
                    const SizedBox(height: 10),
                    if (Platform.isAndroid)
                      _PermissionButton(
                        label: 'Allow SMS Access',
                        onPressed: _requestSmsAccess,
                      ),
                    const SizedBox(height: 10),
                    _PermissionButton(
                      label: 'Connect Gmail',
                      onPressed: _connectGmail,
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(_page == 2 ? 'Get started' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Future<void> _next() async {
    if (_page < 2) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    await widget.onComplete();
  }

  Future<void> _requestNotificationAccess() async {
    final ingest = context.read<IngestService>();
    final enabled = await ingest.hasNotificationAccess();
    if (!enabled) await ingest.openNotificationSettings();
  }

  Future<void> _requestSmsAccess() async {
    await Permission.sms.request();
  }

  Future<void> _connectGmail() async {
    await context.read<IngestService>().connectGmail();
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _PermissionButton extends StatelessWidget {
  const _PermissionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: AppColors.borderLight),
        foregroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Text(label),
    );
  }
}
