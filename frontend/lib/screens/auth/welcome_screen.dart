import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_button.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isGuestLoading = false;

  Future<void> _onGuestContinue() async {
    HapticFeedback.lightImpact();
    if (_isGuestLoading) return;
    setState(() => _isGuestLoading = true);
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.createGuest();
      ref.read(authStateProvider.notifier).state = true;
      ref.read(isGuestProvider.notifier).state = true;
      if (mounted) context.goNamed('onboarding');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGuestLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

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
              const Spacer(),
              Text(
                'mitlist',
                style: MitlistTypography.logo(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.space3),
              Text(
                'Your household, organized.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.space8),
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
                      'Lists, chores, money.\nAll in one place.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: MitlistSpacing.sm),
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
              const SizedBox(height: MitlistSpacing.space3),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: _isGuestLoading ? 'Setting up...' : 'Continue as guest',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.lg,
                  onPressed: _isGuestLoading ? null : _onGuestContinue,
                ),
              ),
              const SizedBox(height: MitlistSpacing.md),
              Text(
                'No account needed. Try everything free for 30 days.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
