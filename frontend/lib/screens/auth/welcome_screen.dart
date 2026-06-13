import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
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

  String? get _inviteCode =>
      GoRouterState.of(context).uri.queryParameters['invite'];

  void _goToAuth(String routeName) {
    final invite = _inviteCode;
    if (invite != null && invite.isNotEmpty) {
      context.goNamed(routeName, queryParameters: {'invite': invite});
    } else {
      context.goNamed(routeName);
    }
  }

  Future<void> _onGuestContinue() async {
    unawaited(HapticFeedback.lightImpact());
    if (_isGuestLoading) return;
    setState(() => _isGuestLoading = true);
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.createGuest();
      final invite = _inviteCode;
      if (invite != null && invite.isNotEmpty) {
        ref.read(pendingAuthNavigationProvider.notifier).state =
            '/join/${Uri.encodeComponent(invite)}';
      } else {
        ref.read(pendingAuthNavigationProvider.notifier).state = '/onboarding';
      }
      ref.read(authStateProvider.notifier).state = true;
      ref.read(isGuestProvider.notifier).state = true;
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;

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
                style: MitlistTypography.logo(color: onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.space3),
              Text(
                l10n.welcomeTagline,
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
                      l10n.welcomeCardTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: MitlistSpacing.sm),
                    Text(
                      l10n.welcomeCardBody,
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
                  text: l10n.welcomeCreateHousehold,
                  variant: AppButtonVariant.solid,
                  color: AppButtonColor.primary,
                  size: AppButtonSize.lg,
                  onPressed: () => _goToAuth('signup'),
                ),
              ),
              const SizedBox(height: MitlistSpacing.space3),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: l10n.welcomeSignIn,
                  variant: AppButtonVariant.outline,
                  color: AppButtonColor.primary,
                  size: AppButtonSize.lg,
                  onPressed: () => _goToAuth('login'),
                ),
              ),
              const SizedBox(height: MitlistSpacing.space3),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: _isGuestLoading ? l10n.welcomeGuestLoading : l10n.welcomeContinueAsGuest,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.lg,
                  onPressed: _isGuestLoading ? null : _onGuestContinue,
                ),
              ),
              const SizedBox(height: MitlistSpacing.md),
              Text(
                l10n.welcomeGuestFootnote,
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
