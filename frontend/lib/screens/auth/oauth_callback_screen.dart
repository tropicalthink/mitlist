import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
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
      // Preserve a destination set before the OAuth round-trip (e.g. an invite
      // accept set '/join/<code>'); only default to onboarding when none.
      if (ref.read(pendingAuthNavigationProvider) == null) {
        ref.read(pendingAuthNavigationProvider.notifier).state = '/onboarding';
      }
      ref.read(authStateProvider.notifier).state = true;
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _error = friendlyErrorMessage(e, AppLocalizations.of(context)!));
    }
  }

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
              : AppAlert(type: AppAlertType.error, message: _error!),
        ),
      ),
    );
  }
}
