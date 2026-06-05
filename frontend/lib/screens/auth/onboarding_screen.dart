import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../providers/group_provider.dart';
import '../../sheets/create_household_sheet.dart';
import '../../sheets/join_household_sheet.dart';
import '../../theme/animations.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_card.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const int _itemCount = 4;

  late final AnimationController _controller;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;
  bool _didStart = false;
  bool _checking = true;

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

    Future.microtask(_checkExistingGroups);
  }

  Future<void> _checkExistingGroups() async {
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 1);
      if (!mounted) return;
      if (groups.isNotEmpty) {
        context.goNamed('home');
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _checking = false);
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (_didStart) return;
    _didStart = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onCreateHousehold() async {
    await Haptics.light();
    if (!mounted) return;
    final created = await CreateHouseholdSheet.show(context);
    if (created == true && mounted) {
      context.goNamed('home');
    }
  }

  Future<void> _onJoinHousehold() async {
    await Haptics.light();
    if (!mounted) return;
    final joined = await JoinHouseholdSheet.show(context);
    if (joined == true && mounted) {
      context.goNamed('home');
    }
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    if (_checking) return child;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) return child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fades[index],
          child: SlideTransition(
            position: _slides[index],
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;

    final createCard = AppCard(
      variant: AppCardVariant.elevated,
      padding: AppCardPadding.lg,
      interactive: true,
      onTap: _onCreateHousehold,
      semanticLabel: 'Create a household',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a household',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  'Start fresh: name it, invite flatmates, share everything in one place.',
                  style: bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Icon(
            Icons.add_home_outlined,
            color: colorScheme.primary,
          ),
        ],
      ),
    );

    final joinCard = AppCard(
      variant: AppCardVariant.elevated,
      padding: AppCardPadding.lg,
      interactive: true,
      onTap: _onJoinHousehold,
      semanticLabel: 'Join a household with invite code',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join with invite code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  'Already got an invite? Enter the code to jump right in.',
                  style: bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Icon(
            Icons.vpn_key_outlined,
            color: colorScheme.primary,
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: MitlistSpacing.space4),
              _buildAnimatedItem(
                0,
                Semantics(
                  label: 'Welcome animation of household coordination',
                  child: Lottie.asset(
                    'assets/animations/lottie/House.lottie',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: MitlistSpacing.space4),
              _buildAnimatedItem(
                1,
                Text(
                  'mitlist',
                  style: MitlistTypography.logo(),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: MitlistSpacing.space8),
              _buildAnimatedItem(2, createCard),
              const SizedBox(height: MitlistSpacing.md),
              _buildAnimatedItem(3, joinCard),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
