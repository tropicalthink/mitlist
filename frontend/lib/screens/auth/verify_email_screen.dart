import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/open_in_app.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/board/cork_board.dart';

/// Landing screen for the verification link in the sign-up email
/// (`/verify?token=<code>`).
///
/// In the installed app, or in a desktop browser, the code is consumed as
/// soon as the screen appears: the person clicked a button that said
/// "verify", so verify. In a phone browser the screen first offers to hand
/// over to the installed app, because the code is single-use and consuming
/// it in the browser would leave the app with nothing to verify. Verifying
/// saves a session exactly like a login does, then heads into onboarding (a
/// brand-new account) or home (a guest who just proved their address).
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.token});

  /// Code from the link. Null or empty when someone reached the route by
  /// hand, in which case a field asks for it.
  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

enum _Phase { choosing, needsCode, verifying, success, error }

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late _Phase _phase;
  final _codeController = TextEditingController();
  String? _error;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String get _token => (widget.token ?? '').trim();

  @override
  void initState() {
    super.initState();
    _codeController.text = _token;
    if (_token.isEmpty) {
      _phase = _Phase.needsCode;
    } else if (isMobileBrowser) {
      _phase = _Phase.choosing;
    } else {
      _phase = _Phase.verifying;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Hops from the web page into the installed app. When the app is missing
  /// Android stays on this page rather than showing an error; see
  /// open_in_app.dart for the URL shapes.
  Future<void> _openInApp() => launchUrl(
        openInAppUri(
          '/verify?token=${Uri.encodeQueryComponent(_token)}',
          isAndroid: isAndroidBrowser,
          fallbackUrl: Uri.base,
        ),
        webOnlyWindowName: '_self',
      );

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _phase = _Phase.needsCode;
        _error = l10n.authVerifyCodeRequired;
      });
      return;
    }
    setState(() {
      _phase = _Phase.verifying;
      _error = null;
    });
    // Read before the tokens land: a guest proving their address is signed
    // in already, and where they go next depends on that.
    final wasGuest = ref.read(isGuestProvider);
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.verifyEmail(code);
      if (!mounted) return;
      setState(() => _phase = _Phase.success);
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      ref.read(isGuestProvider.notifier).state = false;
      ref.read(pendingAuthNavigationProvider.notifier).state =
          wasGuest ? '/home' : '/onboarding';
      ref.read(authStateProvider.notifier).state = true;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = l10n.authVerifyInvalid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CorkBoardBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'mitlist',
                        style: MitlistTypography.logo(color: scheme.onSurface),
                      ),
                      const SizedBox(height: MitlistSpacing.space8),
                      TapedPanel(
                        padding: const EdgeInsets.all(MitlistSpacing.space6),
                        child: _buildBody(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.authVerifyTitle,
          style: theme.textTheme.headlineSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: MitlistSpacing.space3),
        ..._phaseContent(theme),
      ],
    );
  }

  List<Widget> _phaseContent(ThemeData theme) {
    switch (_phase) {
      case _Phase.choosing:
        return [
          Text(l10n.authVerifyLinkBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: MitlistSpacing.lg),
          AppButton(
            text: l10n.authLinkOpenInApp,
            size: AppButtonSize.lg,
            onPressed: _openInApp,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppButton(
            text: l10n.authLinkContinueInBrowser,
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            onPressed: _verify,
          ),
        ];
      case _Phase.needsCode:
        return [
          if (_error != null) ...[
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.md),
          ] else ...[
            Text(l10n.authVerifyLinkMissing, style: theme.textTheme.bodyMedium),
            const SizedBox(height: MitlistSpacing.md),
          ],
          AppInput(
            label: l10n.authVerifyCodeLabel,
            hint: l10n.authVerifyCodeHint,
            controller: _codeController,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: MitlistSpacing.lg),
          AppButton(
            text: l10n.authVerifyButton,
            size: AppButtonSize.lg,
            onPressed: _verify,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          _backToLogin(),
        ];
      case _Phase.verifying:
        return [
          Text(l10n.authVerifyLinkVerifying, style: theme.textTheme.bodyMedium),
          const SizedBox(height: MitlistSpacing.lg),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: MitlistSpacing.sm),
        ];
      case _Phase.success:
        return [
          AppAlert(
              type: AppAlertType.success, message: l10n.authVerifyLinkSuccess),
          const SizedBox(height: MitlistSpacing.md),
          AppButton(
            text: l10n.authVerifyButton,
            size: AppButtonSize.lg,
            isSuccess: true,
          ),
        ];
      case _Phase.error:
        return [
          AppAlert(type: AppAlertType.error, message: _error ?? ''),
          const SizedBox(height: MitlistSpacing.md),
          AppInput(
            label: l10n.authVerifyCodeLabel,
            hint: l10n.authVerifyCodeHint,
            controller: _codeController,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: MitlistSpacing.lg),
          AppButton(
            text: l10n.authVerifyButton,
            size: AppButtonSize.lg,
            onPressed: _verify,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          _backToLogin(),
        ];
    }
  }

  Widget _backToLogin() => AppButton(
        text: l10n.authLinkBackToLogin,
        variant: AppButtonVariant.ghost,
        color: AppButtonColor.neutral,
        onPressed: () => context.goNamed('login'),
      );
}
