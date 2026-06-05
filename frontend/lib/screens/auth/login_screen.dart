import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/api_config.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/browser_redirect.dart';
import '../../utils/native_oauth_launcher.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
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
  bool _rememberMe = true;
  String? _errorMessage;
  String? _emailError;
  String? _passwordError;

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
        _errorMessage = 'Please enter both email and password.';
        if (email.isEmpty) _emailError = 'Email is required.';
        if (password.isEmpty) _passwordError = 'Password is required.';
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
      
      // Update auth state
      ref.read(authStateProvider.notifier).state = true;
      
      if (mounted) {
        context.goNamed('home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Couldn\u2019t sign in. Check your connection and try again.';
      });
    } finally {
      setState(() => _isLoading = false);
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
      title: 'Reset Password',
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            final email = emailController.text.trim();
            if (email.isEmpty) {
              setSheetState(() => error = 'Email is required.');
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
                successMessage =
                    'If that email exists, a reset code has been sent.';
              });
            } catch (e) {
              setSheetState(() {
                isSubmitting = false;
                error = 'Couldn\u2019t sign in. Check your connection and try again.';
              });
            }
          }

          Future<void> confirmReset() async {
            final token = tokenController.text.trim();
            final newPassword = newPasswordController.text.trim();
            final confirmPassword = confirmPasswordController.text.trim();

            if (token.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
              setSheetState(() => error = 'Fill out the reset code and both password fields.');
              return;
            }
            if (newPassword.length < 6) {
              setSheetState(
                () => error = 'New password must be at least 6 characters.',
              );
              return;
            }
            if (newPassword != confirmPassword) {
              setSheetState(() => error = 'New passwords do not match.');
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
                successMessage = 'Password reset successful. You can sign in now.';
              });
            } catch (e) {
              setSheetState(() {
                isResetting = false;
                error = 'Couldn\u2019t sign in. Check your connection and try again.';
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
                label: 'Email',
                hint: 'you@example.com',
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: MitlistSpacing.lg),
              AppButton(
                text: 'Send reset code',
                onPressed: isSubmitting ? null : submit,
                isLoading: isSubmitting,
              ),
              const SizedBox(height: MitlistSpacing.lg),
              AppInput(
                label: 'Reset code',
                hint: 'Paste the code from your email',
                controller: tokenController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: MitlistSpacing.space3),
              AppInput(
                label: 'New password',
                hint: '........',
                controller: newPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: MitlistSpacing.space3),
              AppInput(
                label: 'Confirm new password',
                hint: '........',
                controller: confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => confirmReset(),
              ),
              SizedBox(height: MitlistSpacing.lg),
              AppButton(
                text: 'Reset password',
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
        _errorMessage =
            '$provider sign-in is only available on web, Android, and iOS right now.';
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
        _errorMessage = 'Something went wrong.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    style: MitlistTypography.logo(),
                  ),
                  SizedBox(height: MitlistSpacing.space8),
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
                          label: 'Email',
                          hint: 'you@example.com',
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
                          label: 'Password',
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
                            text: 'Sign in',
                            variant: AppButtonVariant.solid,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : _submit,
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        InkWell(
                          onTap: _isLoading
                              ? null
                              : () => setState(() => _rememberMe = !_rememberMe),
                          borderRadius: BorderRadius.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
                            child: Row(
                              children: [
                                Semantics(
                                  label: 'Remember me',
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: _isLoading
                                        ? null
                                        : (value) {
                                            setState(() => _rememberMe = value ?? true);
                                          },
                                  ),
                                ),
                                const SizedBox(width: MitlistSpacing.sm),
                                const Text('Remember me'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space4),
                        AppButton(
                          text: 'Continue with Google',
                          icon: const Icon(Icons.login, size: 20),
                          variant: AppButtonVariant.outline,
                          color: AppButtonColor.neutral,
                          onPressed: _isLoading ? null : () => _startOAuth('google'),
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        AppButton(
                          text: 'Continue with Apple',
                          icon: const Icon(Icons.apple, size: 20),
                          variant: AppButtonVariant.outline,
                          color: AppButtonColor.neutral,
                          onPressed: _isLoading ? null : () => _startOAuth('apple'),
                        ),
                        SizedBox(height: MitlistSpacing.space4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => context.goNamed('signup'),
                              child: Text(
                                'Create account',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: MitlistSpacing.space2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _showPasswordResetSheet,
                              child: Text(
                                'Forgot password?',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
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
    );
  }
}
