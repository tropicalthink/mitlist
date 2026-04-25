import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_SlideData> _slides = const [
    _SlideData(
      icon: Icons.home_outlined,
      title: 'Create your household',
      description: 'Name your household and invite the people you live with.',
    ),
    _SlideData(
      icon: Icons.list_alt,
      title: 'Drop in your chaos',
      description: 'Add lists, chores, bills, and everything in between.',
    ),
    _SlideData(
      icon: Icons.auto_awesome,
      title: 'Let mitlist drive',
      description: 'Rotations, reminders, and fairness—handled automatically.',
    ),
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: MitlistAnimations.medium,
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    context.goNamed('home');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: MitlistColors.neutral50,
      appBar: AppBar(
        backgroundColor: MitlistColors.neutral50,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: MitlistSpacing.md),
            child: AppButton(
              text: 'Skip',
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.primary,
              size: AppButtonSize.sm,
              onPressed: _finish,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppCard(
                        variant: AppCardVariant.elevated,
                        padding: AppCardPadding.xl,
                        child: Icon(
                          slide.icon,
                          size: MitlistSpacing.space12 + MitlistSpacing.space4,
                          color: MitlistColors.primary500,
                        ),
                      ),
                      const SizedBox(height: MitlistSpacing.space8),
                      Text(
                        slide.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: MitlistSpacing.space3),
                      Text(
                        slide.description,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          Padding(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: isLast ? 'Get started' : 'Next',
                    variant: AppButtonVariant.solid,
                    color: AppButtonColor.primary,
                    size: AppButtonSize.lg,
                    onPressed: _next,
                  ),
                ),
              ],
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
