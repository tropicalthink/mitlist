import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/oauth_provider.dart';
import '../../theme/spacing.dart';
import '../../utils/oauth_flow.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/guest_continue_button.dart';
import 'tour_screen.dart';

/// The last tour page: the account choice. Every door leads to household
/// setup; the guest door is the "later" that the tour's references all keep,
/// and it is the same guest account the rest of the app already knows how to
/// upgrade.
class TourFinishPage extends ConsumerStatefulWidget {
  const TourFinishPage({super.key});

  @override
  ConsumerState<TourFinishPage> createState() => _TourFinishPageState();
}

class _TourFinishPageState extends ConsumerState<TourFinishPage>
    with WidgetsBindingObserver, OAuthLaunchHandler {
  String? _error;

  @override
  void showOAuthError(String? message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final providers = ref.watch(oauthProvidersProvider).valueOrNull;
    final google = providers?.google ?? false;
    final apple = providers?.apple ?? false;
    // Sign-up is an email + password form; without passwords a new account is
    // made by Google or Apple on the login screen, so "email" goes there.
    final passwordAuth = providers?.password ?? true;
    final createRoute = passwordAuth ? 'signup' : 'login';
    final oauthBusy = oauthProvider != null;

    return TourPageSheet(
      eyebrow: l10n.tourFinishEyebrow,
      headline: l10n.tourFinishHeadline,
      body: l10n.tourFinishBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.space3),
          ],
          if (google) ...[
            AppButton(
              text: l10n.authLoginGoogle,
              icon: const AppIcon(name: 'login', size: 20),
              variant: AppButtonVariant.outline,
              color: AppButtonColor.neutral,
              size: AppButtonSize.lg,
              isLoading: oauthProvider == 'google',
              onPressed: oauthBusy ? null : () => startOAuth('google'),
            ),
            const SizedBox(height: MitlistSpacing.space3),
          ],
          if (apple) ...[
            AppButton(
              text: l10n.authLoginApple,
              icon: const AppIcon(name: 'apple', size: 20),
              variant: AppButtonVariant.outline,
              color: AppButtonColor.neutral,
              size: AppButtonSize.lg,
              isLoading: oauthProvider == 'apple',
              onPressed: oauthBusy ? null : () => startOAuth('apple'),
            ),
            const SizedBox(height: MitlistSpacing.space3),
          ],
          // Email is the quiet option under the provider buttons: plain
          // text, no outline, so Google and Apple stay the headline.
          AppButton(
            text: l10n.tourFinishEmail,
            variant: AppButtonVariant.ghost,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            onPressed: oauthBusy ? null : () => context.goNamed(createRoute),
          ),
          const SizedBox(height: MitlistSpacing.space3),
          const GuestContinueButton(),
          const SizedBox(height: MitlistSpacing.space3),
          AppButton(
            text: l10n.tourFinishSignIn,
            variant: AppButtonVariant.ghost,
            color: AppButtonColor.primary,
            size: AppButtonSize.md,
            onPressed: oauthBusy ? null : () => context.goNamed('login'),
          ),
        ],
      ),
    );
  }
}
