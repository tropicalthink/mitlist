import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_error_mapper.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/open_in_app.dart';
import '../../utils/password_policy.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/board/cork_board.dart';
import '../../widgets/password_requirements.dart';
import '../../widgets/password_strength_bar.dart';

/// Landing screen for the link in the password reset email
/// (`/reset-password?token=<code>`).
///
/// The code from the link is carried silently; the person only chooses a
/// new password. Saving it signs them in — the emailed code proved the
/// address, and typing the password they just picked into the login form
/// would be a pointless extra step. In a phone browser the screen also offers
/// to hand over to the installed app, so the session lands where they will
/// actually use it.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.token});

  /// Code from the link. Null or empty when someone reached the route by
  /// hand, in which case a field asks for it.
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _error;
  String? _passwordError;
  String? _confirmError;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String get _linkToken => (widget.token ?? '').trim();

  /// The code field only shows when the link did not carry one.
  bool get _asksForCode => _linkToken.isEmpty;

  @override
  void initState() {
    super.initState();
    _codeController.text = _linkToken;
    _passwordController.addListener(_onPasswordChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_asksForCode) _passwordFocus.requestFocus();
    });
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _openInApp() => launchUrl(
        openInAppUri(
          '/reset-password?token=${Uri.encodeQueryComponent(_linkToken)}',
          isAndroid: isAndroidBrowser,
          fallbackUrl: Uri.base,
        ),
        webOnlyWindowName: '_self',
      );

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    // Never trim a password: leading and trailing spaces are legitimate
    // characters, and silently stripping them here would store something
    // different from what the user typed.
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _error = null;
      _passwordError = null;
      _confirmError = null;
    });

    if (code.isEmpty) {
      setState(() => _error = l10n.authLoginResetFillAllFields);
      return;
    }
    if (!PasswordPolicy.isSatisfied(password)) {
      setState(() => _passwordError = PasswordPolicy.hasMinLength(password)
          ? l10n.authSignupPasswordRequirementsNotMet
          : l10n.authSignupPasswordMinLength);
      return;
    }
    if (password != confirm) {
      setState(() => _confirmError = l10n.accountPasswordsMismatch);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.confirmPasswordReset(code, password);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      // The tokens are saved; flipping auth state (or, when a session was
      // already live on this device, the parked destination alone) moves the
      // router on.
      ref.read(pendingAuthNavigationProvider.notifier).state = '/home';
      ref.read(authStateProvider.notifier).state = true;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = e is ApiException && e.cause?.response?.statusCode == 400
            ? l10n.authResetInvalidCode
            : friendlyErrorMessage(e, l10n);
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
                        child: _buildForm(),
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

  Widget _buildForm() {
    final theme = Theme.of(context);
    final busy = _isSubmitting || _isSuccess;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.authResetTitle,
            style: theme.textTheme.headlineSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.space3),
          Text(l10n.authResetBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: MitlistSpacing.lg),
          if (_error != null) ...[
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.md),
          ],
          if (isMobileBrowser && !_asksForCode) ...[
            AppButton(
              text: l10n.authLinkOpenInApp,
              variant: AppButtonVariant.outline,
              color: AppButtonColor.primary,
              onPressed: busy ? null : _openInApp,
            ),
            const SizedBox(height: MitlistSpacing.lg),
          ],
          if (_asksForCode) ...[
            AppInput(
              label: l10n.authLoginResetCodeLabel,
              hint: l10n.authLoginResetCodeHint,
              controller: _codeController,
              enabled: !busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.oneTimeCode],
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: MitlistSpacing.space3),
          ],
          AppInput(
            label: l10n.accountNewPassword,
            hint: '••••••••',
            controller: _passwordController,
            focusNode: _passwordFocus,
            enabled: !busy,
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _confirmFocus.requestFocus(),
            errorText: _passwordError,
          ),
          const SizedBox(height: MitlistSpacing.space2),
          PasswordStrengthBar(password: _passwordController.text),
          const SizedBox(height: MitlistSpacing.space2),
          PasswordRequirements(password: _passwordController.text),
          const SizedBox(height: MitlistSpacing.space3),
          AppInput(
            label: l10n.accountConfirmPassword,
            hint: '••••••••',
            controller: _confirmController,
            focusNode: _confirmFocus,
            enabled: !busy,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
            errorText: _confirmError,
          ),
          const SizedBox(height: MitlistSpacing.lg),
          AppButton(
            text: l10n.authResetSubmit,
            size: AppButtonSize.lg,
            isLoading: _isSubmitting,
            isSuccess: _isSuccess,
            onPressed: busy ? null : _submit,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppButton(
            text: l10n.authLinkBackToLogin,
            variant: AppButtonVariant.ghost,
            color: AppButtonColor.neutral,
            onPressed: busy ? null : () => context.goNamed('login'),
          ),
        ],
      ),
    );
  }
}
