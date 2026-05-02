import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const int _itemCount = 4;

  late final AnimationController _controller;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MitlistAnimations.entrance,
    );

    _fades = List.generate(_itemCount, (i) {
      final start = (i * MitlistAnimations.staggerOffset.inMilliseconds) /
          MitlistAnimations.entrance.inMilliseconds;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: MitlistAnimations.easeEnter),
      );
    });

    _slides = List.generate(_itemCount, (i) {
      final start = (i * MitlistAnimations.staggerOffset.inMilliseconds) /
          MitlistAnimations.entrance.inMilliseconds;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: MitlistAnimations.easeEnter),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didStart) {
      _didStart = true;
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    Widget house = Lottie.asset(
      'assets/animations/lottie/House.lottie',
      width: 120,
      height: 120,
      fit: BoxFit.contain,
    );

    Widget logo = Text(
      'mitlist',
      style: MitlistTypography.logo(),
      textAlign: TextAlign.center,
    );

    Widget card = Container(
      padding: const EdgeInsets.all(MitlistSpacing.lg),
      decoration: BoxDecoration(
        color: MitlistColors.surfacePrimary,
        border: Border.all(
          color: MitlistColors.borderPrimary,
          width: 2,
        ),
        boxShadow: MitlistShadows.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create your household',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            'Name it, invite your flatmates, and start adding lists, chores, and shared expenses. Everything stays in one place — no more "did you get the milk?" texts at midnight.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MitlistColors.textSecondary,
                ),
          ),
        ],
      ),
    );

    Widget button = SizedBox(
      width: double.infinity,
      child: AppButton(
        text: 'Get started',
        variant: AppButtonVariant.solid,
        color: AppButtonColor.primary,
        size: AppButtonSize.lg,
        onPressed: () => context.goNamed('home'),
      ),
    );

    if (!disableAnimations && _controller.isAnimating) {
      return Scaffold(
        backgroundColor: MitlistColors.neutral50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: MitlistSpacing.space4),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fades[0],
                      child: SlideTransition(
                        position: _slides[0],
                        child: house,
                      ),
                    );
                  },
                ),
                const SizedBox(height: MitlistSpacing.space4),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fades[1],
                      child: SlideTransition(
                        position: _slides[1],
                        child: logo,
                      ),
                    );
                  },
                ),
                const SizedBox(height: MitlistSpacing.space8),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fades[2],
                      child: SlideTransition(
                        position: _slides[2],
                        child: card,
                      ),
                    );
                  },
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fades[3],
                      child: SlideTransition(
                        position: _slides[3],
                        child: button,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MitlistColors.neutral50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const SizedBox(height: MitlistSpacing.space4),
              house,
              const SizedBox(height: MitlistSpacing.space4),
              logo,
              const SizedBox(height: MitlistSpacing.space8),
              card,
              const Spacer(),
              button,
            ],
          ),
        ),
      ),
    );
  }
}
