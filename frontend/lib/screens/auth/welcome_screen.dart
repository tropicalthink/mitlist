import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Spacer(),
              Text(
                'mitlist',
                style: MitlistTypography.logo(),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: MitlistSpacing.space3),
              Text(
                'Your household, organized.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: MitlistSpacing.space8),
              Container(
                padding: const EdgeInsets.all(MitlistSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 2,
                  ),
                  boxShadow: MitlistShadows.shadowMedium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lists, chores, money —\nall in one place.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: MitlistSpacing.sm),
                    Text(
                      'Built for flatmates who want less friction and more clarity.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
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
    );
  }
}
