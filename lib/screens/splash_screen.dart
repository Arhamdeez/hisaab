import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/theme/app_colors.dart';
import '../widgets/app_logo_mark.dart';
import '../widgets/glass_container.dart';

/// Premium launch splash: the brand mark scales in over a soft red glow with a
/// light sweep across it, then the wordmark and tagline reveal in sequence.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _glow;
  late final Animation<double> _shine;
  late final Animation<double> _wordOpacity;
  late final Animation<double> _wordSlide;
  late final Animation<double> _tagOpacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    _logoOpacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.64, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.52, curve: Curves.easeOutCubic),
      ),
    );
    _glow = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _shine = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.42, 0.94, curve: Curves.easeInOut),
    );
    _wordOpacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.34, 0.66, curve: Curves.easeOut),
    );
    _wordSlide = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.34, 0.70, curve: Curves.easeOutCubic),
      ),
    );
    _tagOpacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.50, 0.82, curve: Curves.easeOut),
    );

    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        const AppBackground(),
        Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: (_glow.value * 0.9).clamp(0.0, 1.0),
                          child: Container(
                            width: 168,
                            height: 168,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.38),
                                  AppColors.primary.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: _logoOpacity.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: SizedBox(
                              width: 118,
                              height: 118,
                              child: Stack(
                                children: [
                                  const AppLogoMark(
                                    size: 118,
                                    color: AppColors.textPrimary,
                                  ),
                                  Opacity(
                                    opacity: (1 - (_shine.value - 0.5).abs() * 2)
                                        .clamp(0.0, 1.0),
                                    child: ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (rect) {
                                        final p = _shine.value;
                                        return LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: const [
                                            Colors.transparent,
                                            AppColors.linen,
                                            Colors.transparent,
                                          ],
                                          stops: [
                                            (p - 0.22).clamp(0.0, 1.0),
                                            p.clamp(0.0, 1.0),
                                            (p + 0.22).clamp(0.0, 1.0),
                                          ],
                                        ).createShader(rect);
                                      },
                                      child: const AppLogoMark(
                                        size: 118,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Opacity(
                    opacity: _wordOpacity.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, _wordSlide.value),
                      child: Text(
                        AppBrand.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: _tagOpacity.value.clamp(0.0, 1.0),
                    child: Text(
                      'CASH FLOW',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textDim,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
