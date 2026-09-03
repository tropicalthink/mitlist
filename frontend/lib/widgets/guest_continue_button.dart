import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../theme/spacing.dart';
import '../utils/friendly_error.dart';
import 'app_button.dart';
import 'app_toast.dart';

/// "Continue as guest": creates a guest account and queues the post-auth hop
/// to household setup (or to an invite, when one is being carried). The one
/// implementation every first-run surface shares, so the guest door behaves
/// the same wherever it is offered.
class GuestContinueButton extends ConsumerStatefulWidget {
  const GuestContinueButton({
    super.key,
    this.inviteCode,
    this.showFootnote = true,
    this.footnoteColor,
  });

  /// An invite code to honour after the guest session exists.
  final String? inviteCode;

  /// Whether to print the "no sign-up needed" line under the button.
  final bool showFootnote;

  /// Footnote ink; defaults to the surface foreground so it reads on both
  /// paper and cork.
  final Color? footnoteColor;

  @override
  ConsumerState<GuestContinueButton> createState() =>
      _GuestContinueButtonState();
}

class _GuestContinueButtonState extends ConsumerState<GuestContinueButton> {
  bool _loading = false;

  Future<void> _continue() async {
    unawaited(HapticFeedback.lightImpact());
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.createGuest();
      final invite = widget.inviteCode;
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
      setState(() => _loading = false);
      AppToast.error(
          context, friendlyErrorMessage(e, AppLocalizations.of(context)!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          text:
              _loading ? l10n.welcomeGuestLoading : l10n.welcomeContinueAsGuest,
          variant: AppButtonVariant.ghost,
          // Neutral ink, not the orange accent: mid-tone orange on mid-tone
          // cork fails contrast.
          color: AppButtonColor.neutral,
          size: AppButtonSize.lg,
          onPressed: _loading ? null : _continue,
        ),
        if (widget.showFootnote) ...[
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            l10n.welcomeGuestFootnote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: widget.footnoteColor ??
                      Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
