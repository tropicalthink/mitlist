import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/board/cork_board.dart';
import '../../widgets/password_strength_bar.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _verificationController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _verificationFocus = FocusNode();

  bool _isLoading = false;
  bool _isSuccess = false;
  bool _awaitingVerification = false;
  String? _errorMessage;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String? get _inviteCode =>
      GoRouterState.of(context).uri.queryParameters['invite'];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _verificationController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _verificationFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_awaitingVerification) {
      await _verifyEmail();
      return;
    }
    setState(() {
      _errorMessage = null;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = l10n.authSignupFillAllFields;
        if (name.isEmpty) _nameError = l10n.authSignupNameRequired;
        if (email.isEmpty) _emailError = l10n.authSignupEmailRequired;
        if (password.isEmpty) _passwordError = l10n.authSignupPasswordRequired;
      });
      return;
    }

    if (password.length < 12) {
      setState(() => _passwordError = 'Use at least 12 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the auth service
      final authService = await ref.read(authServiceProviderAsync.future);

      // Split name into first and last name
      final nameParts = name.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : name;
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // Make actual API call
      final request = RegisterRequest(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      await authService.register(request);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _awaitingVerification = true;
          _errorMessage = null;
        });
        _verificationFocus.requestFocus();
      }
      return;
    } catch (e) {
      setState(() {
        _errorMessage = l10n.authSignupGenericError;
      });
    } finally {
      if (mounted && !_isSuccess) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyEmail() async {
    final code = _verificationController.text.trim();
    if (code.isEmpty) {
      setState(
          () => _errorMessage = 'Enter the verification code from your email.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.verifyEmail(code);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      final invite = _inviteCode;
      ref.read(pendingAuthNavigationProvider.notifier).state =
          (invite != null && invite.isNotEmpty)
              ? '/join/${Uri.encodeComponent(invite)}'
              : '/onboarding';
      ref.read(authStateProvider.notifier).state = true;
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'That verification code is invalid or expired.');
      }
    } finally {
      if (mounted && !_isSuccess) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _errorMessage = null);
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.resendEmailVerification(_emailController.text.trim());
      if (mounted) {
        setState(() => _errorMessage = 'A new verification code was sent.');
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.authSignupGenericError);
    }
  }

  void _showLegalSheet({
    required String title,
    required List<String> paragraphs,
  }) {
    showAppBottomSheet(
      context: context,
      title: title,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < paragraphs.length; i++) ...[
            Text(paragraphs[i]),
            if (i < paragraphs.length - 1)
              const SizedBox(height: MitlistSpacing.md),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                  constraints: BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'mitlist',
                        style: MitlistTypography.logo(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: MitlistSpacing.space8),
                      TapedPanel(
                        padding: const EdgeInsets.all(MitlistSpacing.space6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_awaitingVerification) ...[
                              AppInput(
                                label: l10n.commonName,
                                hint: l10n.authSignupNameHint,
                                controller: _nameController,
                                focusNode: _nameFocus,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                onSubmitted: (_) => _emailFocus.requestFocus(),
                                errorText: _nameError,
                              ),
                              const SizedBox(height: MitlistSpacing.space3),
                              AppInput(
                                label: l10n.authSignupEmail,
                                hint: l10n.authSignupEmailHint,
                                controller: _emailController,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                onSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                                errorText: _emailError,
                              ),
                              const SizedBox(height: MitlistSpacing.space3),
                              AppInput(
                                label: l10n.authSignupPassword,
                                hint: '••••••••',
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword
                                ],
                                onSubmitted: (_) => _submit(),
                                errorText: _passwordError,
                              ),
                              const SizedBox(height: MitlistSpacing.space2),
                              PasswordStrengthBar(
                                password: _passwordController.text,
                              ),
                              const SizedBox(height: MitlistSpacing.space3),
                            ] else ...[
                              Text(
                                'Check ${_emailController.text.trim()} for your verification code.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: MitlistSpacing.space3),
                              AppInput(
                                label: 'Verification code',
                                hint: 'Paste the code from your email',
                                controller: _verificationController,
                                focusNode: _verificationFocus,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode
                                ],
                                onSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: MitlistSpacing.space2),
                              AppButton(
                                text: 'Send a new code',
                                variant: AppButtonVariant.ghost,
                                color: AppButtonColor.primary,
                                onPressed:
                                    _isLoading ? null : _resendVerification,
                              ),
                              const SizedBox(height: MitlistSpacing.space3),
                            ],
                            if (_errorMessage != null) ...[
                              AppAlert(
                                type: AppAlertType.error,
                                message: _errorMessage!,
                              ),
                              const SizedBox(height: MitlistSpacing.space3),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                text: _awaitingVerification
                                    ? 'Verify email'
                                    : l10n.authSignupCreateAccount,
                                variant: AppButtonVariant.solid,
                                color: AppButtonColor.primary,
                                size: AppButtonSize.lg,
                                isLoading: _isLoading,
                                isSuccess: _isSuccess,
                                onPressed:
                                    (_isLoading || _isSuccess) ? null : _submit,
                              ),
                            ),
                            const SizedBox(height: MitlistSpacing.space4),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  l10n.authSignupHaveAccount,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                AppButton(
                                  variant: AppButtonVariant.ghost,
                                  color: AppButtonColor.primary,
                                  text: l10n.authSignupSignInLink,
                                  onPressed: () => context.goNamed('login'),
                                ),
                              ],
                            ),
                            const SizedBox(height: MitlistSpacing.space2),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  l10n.authSignupTermsPrefix,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                AppButton(
                                  variant: AppButtonVariant.ghost,
                                  color: AppButtonColor.neutral,
                                  text: l10n.accountTermsTitle,
                                  onPressed: () => _showLegalSheet(
                                    title: l10n.accountTermsTitle,
                                    paragraphs: [
                                      l10n.authSignupTermsP1,
                                      l10n.authSignupTermsP2,
                                      l10n.authSignupTermsP3,
                                    ],
                                  ),
                                ),
                                Text(
                                  l10n.authSignupAnd,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                AppButton(
                                  variant: AppButtonVariant.ghost,
                                  color: AppButtonColor.neutral,
                                  text: l10n.authSignupPrivacyPolicy,
                                  onPressed: () => _showLegalSheet(
                                    title: l10n.authSignupPrivacyPolicy,
                                    paragraphs: [
                                      l10n.authSignupPrivacyP1,
                                      l10n.authSignupPrivacyP2,
                                      l10n.authSignupPrivacyP3,
                                    ],
                                  ),
                                ),
                                Text(
                                  l10n.authSignupPeriod,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}
