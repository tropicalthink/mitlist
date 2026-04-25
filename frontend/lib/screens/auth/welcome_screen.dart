import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<_SlideData> _slides = const [
    _SlideData(
      icon: Icons.list_alt,
      title: 'Share lists',
      description: 'Create and share shopping lists, to-dos, and more.',
    ),
    _SlideData(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Split bills fairly',
      description: 'Track expenses and settle up with your household.',
    ),
    _SlideData(
      icon: Icons.check_box_outlined,
      title: 'Never forget a chore',
      description: 'Assign and rotate chores so nothing falls through.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: MitlistAnimations.medium,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MitlistColors.neutral50,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: MitlistSpacing.space8),
                  Text(
                    'mitlist',
                    style: MitlistTypography.logo(),
                  ),
                  const SizedBox(height: MitlistSpacing.space2),
                  Text(
                    'Your household, organized.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: MitlistColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: MitlistSpacing.space3),
                  Text(
                    'Lists · Chores · Money · Vault',
                    style: MitlistTypography.labelXSmall(
                      color: MitlistColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: MitlistSpacing.space8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.md,
                      ),
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: _slides.length,
                        itemBuilder: (context, index) {
                          final slide = _slides[index];
                          return AppCard(
                            variant: AppCardVariant.elevated,
                            padding: AppCardPadding.lg,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  slide.icon,
                                  size: MitlistSpacing.space12,
                                  color: MitlistColors.primary500,
                                ),
                                const SizedBox(height: MitlistSpacing.space4),
                                Text(
                                  slide.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: MitlistSpacing.space3),
                                Text(
                                  slide.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: MitlistColors.textSecondary,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: MitlistSpacing.space4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      return AnimatedContainer(
                        duration: MitlistAnimations.micro,
                        margin: const EdgeInsets.symmetric(
                          horizontal: MitlistSpacing.space1,
                        ),
                        width: _currentPage == index
                            ? MitlistSpacing.space6
                            : MitlistSpacing.space2,
                        height: MitlistSpacing.space2,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? MitlistColors.primary500
                              : MitlistColors.neutral300,
                          borderRadius: BorderRadius.circular(
                            MitlistTheme.radiusFull,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: MitlistSpacing.space6),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: MitlistColors.surfacePrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MitlistTheme.radiusLg),
              ),
              boxShadow: MitlistShadows.shadowMedium,
            ),
            padding: const EdgeInsets.all(MitlistSpacing.space6),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Create free household',
                      variant: AppButtonVariant.solid,
                      color: AppButtonColor.primary,
                      size: AppButtonSize.lg,
                      onPressed: () => context.goNamed('signup'),
                    ),
                  ),
                  const SizedBox(height: MitlistSpacing.space3),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Sign in',
                      variant: AppButtonVariant.outline,
                      color: AppButtonColor.primary,
                      size: AppButtonSize.lg,
                      onPressed: () => context.goNamed('login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final String title;
  final String description;

  const _SlideData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
