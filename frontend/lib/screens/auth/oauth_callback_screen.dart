import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/mitlist_app_bar.dart';

class OAuthCallbackScreen extends ConsumerStatefulWidget {
  const OAuthCallbackScreen({
    super.key,
    required this.queryParameters,
  });

  final Map<String, String> queryParameters;

  @override
  ConsumerState<OAuthCallbackScreen> createState() => _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends ConsumerState<OAuthCallbackScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  Future<void> _complete() async {
    final provider = widget.queryParameters['provider'];
    final code = widget.queryParameters['code'];
    final state = widget.queryParameters['state'];
    final idToken = widget.queryParameters['id_token'];
    final accessToken = widget.queryParameters['access_token'];
    final refreshToken = widget.queryParameters['refresh_token'];
    final oauthError = widget.queryParameters['error'];

    if (oauthError != null && oauthError.isNotEmpty) {
      setState(() => _error = oauthError);
      return;
    }

    if (provider == null || code == null || state == null) {
      if (accessToken == null || refreshToken == null) {
        setState(() => _error = 'Missing OAuth callback parameters.');
        return;
      }
    }

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final rememberMe = await authService.consumePendingOAuthRememberMe();
      if (accessToken != null && refreshToken != null) {
        await authService.saveTokenPair(
          TokenPair(
            accessToken: accessToken,
            refreshToken: refreshToken,
          ),
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
      ref.read(authStateProvider.notifier).state = true;
      if (!mounted) return;
      context.goNamed('home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'Signing you in',
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
