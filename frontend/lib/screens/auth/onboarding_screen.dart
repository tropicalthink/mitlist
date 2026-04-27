import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MitlistColors.neutral50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'mitlist',
                style: MitlistTypography.logo(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.space8),
              Container(
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
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Get started',
                  variant: AppButtonVariant.solid,
                  color: AppButtonColor.primary,
                  size: AppButtonSize.lg,
                  onPressed: () => context.goNamed('home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
