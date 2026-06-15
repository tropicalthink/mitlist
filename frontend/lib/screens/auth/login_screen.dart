import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/api_config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/browser_redirect.dart';
import '../../utils/friendly_error.dart';
import '../../utils/native_oauth_launcher.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/animated_check_toggle.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _isSuccess = false;
  bool _rememberMe = true;
  String? _errorMessage;
  String? _emailError;
  String? _passwordError;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = l10n.authLoginFillAllFields;
        if (email.isEmpty) _emailError = l10n.authLoginEmailRequired;
        if (password.isEmpty) _passwordError = l10n.authLoginPasswordRequired;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the auth service
      final authService = await ref.read(authServiceProviderAsync.future);
      
      // Make actual API call
      final request = LoginRequest(email: email, password: password);
      await authService.login(request, rememberMe: _rememberMe);
      
      // Update auth state after the success animation so redirect does not
      // dispose this screen before the checkmark is visible.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 650));
        if (mounted) ref.read(authStateProvider.notifier).state = true;
      }
      return;
    } catch (e) {
      setState(() {
        _errorMessage = l10n.authLoginGenericError;
      });
    } finally {
      if (mounted && !_isSuccess) setState(() => _isLoading = false);
    }
  }

  void _showPasswordResetSheet() {
    final emailController = TextEditingController(text: _emailController.text.trim());
    final tokenController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var isSubmitting = false;
    var isResetting = false;
    String? error;
    String? successMessage;

    showAppBottomSheet(
      context: context,
      title: l10n.authLoginResetPasswordTitle,
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            final email = emailController.text.trim();
            if (email.isEmpty) {
              setSheetState(() => error = l10n.authLoginEmailRequired);
              return;
            }

            setSheetState(() {
              isSubmitting = true;
              error = null;
              successMessage = null;
            });

            try {
              final authService = await ref.read(authServiceProviderAsync.future);
              await authService.requestPasswordReset(email);
              if (!mounted) return;
              setSheetState(() {
                isSubmitting = false;
                successMessage = l10n.authLoginResetCodeSent;
              });
            } catch (e) {
              setSheetState(() {
                isSubmitting = false;
                error = l10n.authLoginGenericError;
              });
            }
          }

          Future<void> confirmReset() async {
            final token = tokenController.text.trim();
            final newPassword = newPasswordController.text.trim();
            final confirmPassword = confirmPasswordController.text.trim();

            if (token.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
              setSheetState(() => error = l10n.authLoginResetFillAllFields);
              return;
            }
            if (newPassword.length < 6) {
              setSheetState(
                () => error = l10n.authSignupPasswordMinLength,
              );
              return;
            }
            if (newPassword != confirmPassword) {
              setSheetState(() => error = l10n.accountPasswordsMismatch);
              return;
            }

            setSheetState(() {
              isResetting = true;
              error = null;
              successMessage = null;
            });

            try {
              final authService = await ref.read(authServiceProviderAsync.future);
              await authService.confirmPasswordReset(token, newPassword);
              if (!mounted) return;
              setSheetState(() {
                isResetting = false;
                successMessage = l10n.authLoginResetSuccess;
              });
            } catch (e) {
              setSheetState(() {
                isResetting = false;
                error = l10n.authLoginGenericError;
              });
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                AppAlert(type: AppAlertType.error, message: error!),
                const SizedBox(height: MitlistSpacing.md),
              ],
              if (successMessage != null) ...[
                AppAlert(type: AppAlertType.info, message: successMessage!),
                const SizedBox(height: MitlistSpacing.md),
              ],
              AppInput(
                label: l10n.authLoginEmail,
                hint: l10n.authLoginYouExample,
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: MitlistSpacing.lg),
              AppButton(
                text: l10n.authLoginSendResetCode,
                onPressed: isSubmitting ? null : submit,
                isLoading: isSubmitting,
              ),
              const SizedBox(height: MitlistSpacing.lg),
              AppInput(
                label: l10n.authLoginResetCodeLabel,
                hint: l10n.authLoginResetCodeHint,
                controller: tokenController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: MitlistSpacing.space3),
              AppInput(
                label: l10n.accountNewPassword,
                hint: '........',
                controller: newPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: MitlistSpacing.space3),
              AppInput(
                label: l10n.accountConfirmPassword,
                hint: '........',
                controller: confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => confirmReset(),
              ),
              const SizedBox(height: MitlistSpacing.lg),
              AppButton(
                text: l10n.authLoginResetPasswordButton,
                onPressed: isResetting ? null : confirmReset,
                isLoading: isResetting,
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      emailController.dispose();
      tokenController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  Future<void> _startOAuth(String provider) async {
    if (!supportsBrowserRedirect && !supportsNativeOAuthLaunch) {
      setState(() {
        _errorMessage = l10n.authLoginOAuthUnsupported(provider);
      });
      return;
    }

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final redirectUri = supportsBrowserRedirect
        ? Uri(
            scheme: browserCurrentUri().scheme,
            host: browserCurrentUri().host,
            port: browserCurrentUri().hasPort ? browserCurrentUri().port : null,
            path: '/auth/callback',
          ).toString()
        : ApiConfig.nativeOAuthCallbackUri;

    final authService = await ref.read(authServiceProviderAsync.future);
    try {
      await authService.setPendingOAuthRememberMe(_rememberMe);

      final authUrl = Uri(
        scheme: baseUri.scheme,
        host: baseUri.host,
        port: baseUri.hasPort ? baseUri.port : null,
        path: '${ApiConfig.apiPrefix}/v1/oauth/$provider',
        queryParameters: {'redirect_uri': redirectUri},
      ).toString();

      if (supportsBrowserRedirect) {
        redirectBrowser(authUrl);
      } else {
        await launchNativeOAuthUrl(authUrl);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
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
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: MitlistSpacing.space1 / 2,
                      ),
                      borderRadius: BorderRadius.zero,
                      boxShadow: MitlistShadows.shadowMedium,
                    ),
                    padding: const EdgeInsets.all(MitlistSpacing.space6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppInput(
                          label: l10n.authLoginEmail,
                          hint: l10n.authLoginYouExample,
                          controller: _emailController,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          errorText: _emailError,
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        AppInput(
                          label: l10n.authLoginPassword,
                          hint: '••••••••',
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          errorText: _passwordError,
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
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
                            text: l10n.welcomeSignIn,
                            variant: AppButtonVariant.solid,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            isLoading: _isLoading,
                            isSuccess: _isSuccess,
                            onPressed: (_isLoading || _isSuccess) ? null : _submit,
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        InkWell(
                          onTap: (_isLoading || _isSuccess)
                              ? null
                              : () => setState(() => _rememberMe = !_rememberMe),
                          borderRadius: BorderRadius.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
                            child: Row(
                              children: [
                                AnimatedCheckToggle(
                                  value: _rememberMe,
                                  onChanged: (_isLoading || _isSuccess)
                                      ? null
                                      : (value) {
                                          setState(() => _rememberMe = value);
                                        },
                                  semanticLabelOn: l10n.authLoginRememberMeOn,
                                  semanticLabelOff: l10n.authLoginRememberMeOff,
                                ),
                                const SizedBox(width: MitlistSpacing.sm),
                                Text(l10n.authLoginRememberMe),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space4),
                        AppButton(
                          text: l10n.authLoginGoogle,
                          icon: const AppIcon(name: 'login', size: 20),
                          variant: AppButtonVariant.outline,
                          color: AppButtonColor.neutral,
                          onPressed: (_isLoading || _isSuccess) ? null : () => _startOAuth('google'),
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        AppButton(
                          text: l10n.authLoginApple,
                          icon: const AppIcon(name: 'apple', size: 20),
                          variant: AppButtonVariant.outline,
                          color: AppButtonColor.neutral,
                          onPressed: (_isLoading || _isSuccess) ? null : () => _startOAuth('apple'),
                        ),
                        const SizedBox(height: MitlistSpacing.space4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppButton(
                              variant: AppButtonVariant.ghost,
                              color: AppButtonColor.primary,
                              text: l10n.authSignupCreateAccount,
                              onPressed: () => context.goNamed('signup'),
                            ),
                          ],
                        ),
                        const SizedBox(height: MitlistSpacing.space2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppButton(
                              variant: AppButtonVariant.ghost,
                              color: AppButtonColor.neutral,
                              text: l10n.authLoginForgotPassword,
                              onPressed: _showPasswordResetSheet,
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
    );
  }
}
