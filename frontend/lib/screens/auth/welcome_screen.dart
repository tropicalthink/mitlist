import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
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
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;
    final invite = _inviteCode;
    final invited = invite != null && invite.isNotEmpty;

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
              if (invited)
                _InvitePinnedNote(code: invite)
              else
                _welcomeCard(context, l10n),
              const Spacer(),
              if (invited) ...[
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: l10n.authJoinCreateToJoin,
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
                    text: l10n.authJoinSignInToJoin,
                    variant: AppButtonVariant.outline,
                    color: AppButtonColor.primary,
                    size: AppButtonSize.lg,
                    onPressed: () => _goToAuth('login'),
                  ),
                ),
                const SizedBox(height: MitlistSpacing.md),
              ] else ...[
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomeCard(BuildContext context, AppLocalizations l10n) {
    return Container(
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
    );
  }
}

/// The invite "moment": the invitation arrives as a sticky note pinned to the
/// welcome screen, in mitlist's own pinwall idiom. It drops in and settles into
/// a slight tilt; under reduced-motion it simply appears, already tilted.
class _InvitePinnedNote extends StatelessWidget {
  const _InvitePinnedNote({required this.code});

  final String code;

  static const double _tilt = -0.045; // ~ -2.6°, like a note tacked to a board

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduce = MediaQuery.of(context).disableAnimations;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noteColor =
        isDark ? MitlistColors.notePeachDark : MitlistColors.notePeach;
    final ink = isDark ? MitlistColors.neutral50 : MitlistColors.textPrimary;
    final parts = code.trim().toUpperCase().split('-');

    final note = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: MitlistSpacing.space2),
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.lg,
            MitlistSpacing.space7,
            MitlistSpacing.lg,
            MitlistSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: noteColor,
            border: Border.all(color: MitlistColors.borderPrimary, width: 2),
            boxShadow: MitlistShadows.shadowStrong,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.welcomeInviteHeadline.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
              ),
              const SizedBox(height: MitlistSpacing.space3),
              Text(
                l10n.welcomeInviteSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ink,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: MitlistSpacing.space5),
              Wrap(
                spacing: MitlistSpacing.space2,
                runSpacing: MitlistSpacing.space2,
                children: [
                  for (final part in parts)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.space3,
                        vertical: MitlistSpacing.space2,
                      ),
                      decoration: BoxDecoration(
                        color: MitlistColors.surfacePrimary,
                        border: Border.all(
                          color: MitlistColors.borderPrimary,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        part,
                        style: MitlistTypography.monoBody(
                          color: MitlistColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // The pushpin holding the note to the board.
        Positioned(
          top: 0,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: MitlistColors.primary500,
              border: Border.fromBorderSide(
                BorderSide(color: MitlistColors.borderPrimary, width: 2),
              ),
              boxShadow: MitlistShadows.shadowSoft,
            ),
          ),
        ),
      ],
    );

    final semantic = Semantics(
      label: l10n.authJoinInviteCodeSemantic(code.trim().toUpperCase()),
      child: note,
    );

    if (reduce) {
      return Transform.rotate(angle: _tilt, child: semantic);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
      child: semantic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -26),
          child: Transform.rotate(angle: _tilt * t, child: child),
        ),
      ),
    );
  }
}
