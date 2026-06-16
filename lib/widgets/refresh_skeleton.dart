import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart' show AppRadius, AppSpacing;
import 'glass_bottom_nav_bar.dart';

/// Drives a shared shimmer phase for descendant [SkeletonBone] widgets.
class ShimmerScope extends StatefulWidget {
  const ShimmerScope({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _ShimmerScope(
          phase: _controller.value,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.phase, required super.child});

  final double phase;

  static double of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ShimmerScope>()
        ?.phase ?? 0;
  }

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.phase != phase;
}

class SkeletonBone extends StatelessWidget {
  const SkeletonBone({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.md,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final phase = _ShimmerScope.of(context);
    final slide = (phase * 2 - 1).clamp(-1.0, 1.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.45)),
        gradient: LinearGradient(
          begin: Alignment(slide - 1.0, 0),
          end: Alignment(slide + 1.0, 0),
          colors: const [
            Color(0x14FFFFFF),
            Color(0x33FFFFFF),
            Color(0x14FFFFFF),
          ],
        ),
      ),
    );
  }
}

class HomeRefreshSkeleton extends StatelessWidget {
  const HomeRefreshSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = GlassBottomNavBar.reservedHeight(context);

    return ShimmerScope(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SkeletonBone(height: 14, width: 72, radius: 6),
                ),
                const SkeletonBone(height: 44, width: 44, radius: 22),
                const SizedBox(width: 10),
                const SkeletonBone(height: 44, width: 44, radius: 22),
              ],
            ),
            const SizedBox(height: 28),
            const SkeletonBone(height: 50, radius: AppRadius.lg),
            const SizedBox(height: 20),
            const SkeletonBone(height: 220, radius: AppRadius.xl),
            const SizedBox(height: 28),
            const SkeletonBone(height: 18, width: 140, radius: 8),
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBone(height: 64, radius: AppRadius.lg),
              if (i < 2) const SizedBox(height: 10),
            ],
            SizedBox(height: bottom),
          ],
        ),
      ),
    );
  }
}

class TransactionsRefreshSkeleton extends StatelessWidget {
  const TransactionsRefreshSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          12,
          AppSpacing.pageH,
          AppSpacing.navBottom,
        ),
        children: [
          const SkeletonBone(height: 88, radius: AppRadius.lg),
          const SizedBox(height: 12),
          const SkeletonBone(height: 280, radius: AppRadius.lg),
        ],
      ),
    );
  }
}

class ReportRefreshSkeleton extends StatelessWidget {
  const ReportRefreshSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          16,
          AppSpacing.pageH,
          AppSpacing.navBottom,
        ),
        children: [
          const SkeletonBone(height: 32, width: 200, radius: 10),
          const SizedBox(height: 8),
          const SkeletonBone(height: 16, width: 120, radius: 6),
          const SizedBox(height: 20),
          const SkeletonBone(height: 180, radius: AppRadius.xl),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: SkeletonBone(height: 72, radius: AppRadius.lg)),
              const SizedBox(width: 12),
              const Expanded(child: SkeletonBone(height: 72, radius: AppRadius.lg)),
            ],
          ),
          const SizedBox(height: 24),
          const SkeletonBone(height: 200, radius: AppRadius.lg),
          const SizedBox(height: 24),
          const SkeletonBone(height: 240, radius: AppRadius.lg),
        ],
      ),
    );
  }
}

class InboxRefreshSkeleton extends StatelessWidget {
  const InboxRefreshSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.page,
        children: [
          const SkeletonBone(height: 32, width: 160, radius: 10),
          const SizedBox(height: 8),
          const SkeletonBone(height: 16, width: 260, radius: 6),
          const SizedBox(height: 20),
          for (var i = 0; i < 2; i++) ...[
            const SkeletonBone(height: 168, radius: AppRadius.lg),
            if (i < 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
