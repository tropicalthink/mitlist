import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../utils/friendly_error.dart';
import '../../l10n/app_localizations.dart';

class OAuthCallbackScreen extends ConsumerStatefulWidget {
  const OAuthCallbackScreen({
    super.key,
    required this.uri,
  });

  final Uri uri;

  @override
  ConsumerState<OAuthCallbackScreen> createState() =>
      _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends ConsumerState<OAuthCallbackScreen> {
  String? _error;

  /// True when this round-trip upgraded a guest rather than signing someone
  /// in: the backend marks it with `link=1`. The person is already signed in
  /// and belongs back on their account page, not in onboarding.
  bool get _isLink => _callbackParams(widget.uri)['link'] == '1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context)!;
    final params = _callbackParams(widget.uri);
    final provider = params['provider'];
    final code = params['code'];
    final state = params['state'];
    final idToken = params['id_token'];
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];
    final handoff = params['handoff'];
    final oauthError = params['error'];

    if (oauthError != null && oauthError.isNotEmpty) {
      setState(() => _error = oauthError);
      return;
    }

    if (accessToken != null || refreshToken != null) {
      setState(() => _error = l10n.oauthMissingParams);
      return;
    }
    if (provider == null || code == null || state == null) {
      if (handoff == null || handoff.isEmpty) {
        setState(() => _error = l10n.oauthMissingParams);
        return;
      }
    }

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final rememberMe = await authService.consumePendingOAuthRememberMe();
      final parkedNavigation =
          await authService.consumePendingOAuthNavigation();
      if (handoff != null && handoff.isNotEmpty) {
        await authService.exchangeOAuthHandoff(
          handoff,
          rememberMe: rememberMe,
        );
      } else {
        final redirectUri = Uri(
          scheme: Uri.base.scheme,
          host: Uri.base.host,
          port: Uri.base.hasPort ? Uri.base.port : null,
          path: '/auth/callback',
          queryParameters: {'provider': provider},
        ).toString();
        await authService.completeOAuthCallback(
          provider: provider!,
          code: code!,
          redirectUri: redirectUri,
          state: state!,
          idToken: idToken,
          rememberMe: rememberMe,
        );
      }
      if (_isLink) {
        // The handoff already saved the upgraded account's tokens. Auth state
        // is unchanged (a guest was signed in all along), so navigate by hand.
        ref.read(isGuestProvider.notifier).state = false;
        if (!mounted) return;
        AppToast.success(context, l10n.accountCreatedWelcome);
        context.go('/you');
        return;
      }
      // Preserve a destination set before the OAuth round-trip (e.g. an invite
      // accept set '/join/<code>'). In memory when the app survived the trip,
      // otherwise the copy parked in preferences; onboarding only when neither.
      if (ref.read(pendingAuthNavigationProvider) == null) {
        ref.read(pendingAuthNavigationProvider.notifier).state =
            _isLocalPath(parkedNavigation) ? parkedNavigation : '/onboarding';
      }
      ref.read(authStateProvider.notifier).state = true;
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _error = friendlyErrorMessage(e, AppLocalizations.of(context)!));
    }
  }

  /// Only an in-app path may be restored from storage; anything else falls
  /// back to onboarding rather than navigating somewhere unexpected.
  static bool _isLocalPath(String? path) =>
      path != null && path.startsWith('/') && !path.startsWith('//');

  /// Merges query params with URL fragment params. The backend used to put
  /// mobile tokens in the fragment; Android deep links only surface queries.
  Map<String, String> _callbackParams(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    if (params.containsKey('handoff') ||
        params.containsKey('access_token') ||
        params.containsKey('code') ||
        params.containsKey('error')) {
      return params;
    }
    if (uri.fragment.isNotEmpty) {
      params.addAll(Uri.splitQueryString(uri.fragment));
    }
    return params;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.oauthSigningYouIn,
        showStandardActions: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppAlert(type: AppAlertType.error, message: _error!),
                    if (_isLink) ...[
                      const SizedBox(height: MitlistSpacing.md),
                      AppButton(
                        text: l10n.oauthBackToAccount,
                        variant: AppButtonVariant.outline,
                        color: AppButtonColor.neutral,
                        onPressed: () => context.go('/you'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
