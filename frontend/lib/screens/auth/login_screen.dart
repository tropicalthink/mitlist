import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/oauth_provider.dart';
import '../../services/api_client.dart';
import '../../services/api_error_mapper.dart';
import '../../sheets/email_verification_sheet.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/oauth_flow.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/animated_check_toggle.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/board/cork_board.dart';
import '../../utils/password_policy.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver, OAuthLaunchHandler {
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

  /// Whether the email + password form is unfolded. It starts folded behind
  /// a button whenever OAuth is on offer, so the buttons stay the headline.
  bool _showEmailForm = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  /// Both doors honour the checkbox: the mixin passes it to the provider
  /// round-trip, `_submit` passes it to the password login.
  @override
  bool get oauthRememberMe => _rememberMe;

  @override
  void showOAuthError(String? message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  void initState() {
    super.initState();
    // A build without a baked-in server (self-compiled, no dart-define) can't
    // do anything until the user picks one — open the picker for them.
    if (!ApiConfig.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showServerSheet();
      });
    }
  }

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
      await _completeSignIn();
      return;
    } catch (e) {
      if (e is ApiException && e.isEmailUnverified) {
        // Right password, address never proven: someone who closed the app
        // before entering the sign-up code. Finish that here rather than
        // sending them back to sign up. A fresh code is requested because
        // the old one has most likely expired.
        if (!mounted) return;
        setState(() => _isLoading = false);
        final verified = await showEmailVerificationSheet(
          context: context,
          ref: ref,
          email: email,
          rememberMe: _rememberMe,
          sendCodeOnOpen: true,
        );
        if (!mounted) return;
        if (verified) {
          await _completeSignIn();
        } else {
          setState(() => _errorMessage = l10n.authLoginUnverified);
        }
        return;
      }
      setState(() {
        _errorMessage = l10n.authLoginGenericError;
      });
    } finally {
      if (mounted && !_isSuccess) setState(() => _isLoading = false);
    }
  }

  /// Flips auth state after the success animation, so the redirect does not
  /// dispose this screen before the checkmark is visible.
  Future<void> _completeSignIn() async {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSuccess = true;
    });
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    final invite = inviteCode;
    if (invite != null && invite.isNotEmpty) {
      ref.read(pendingAuthNavigationProvider.notifier).state =
          '/join/${Uri.encodeComponent(invite)}';
    }
    ref.read(authStateProvider.notifier).state = true;
  }

  void _showPasswordResetSheet() {
    final emailController =
        TextEditingController(text: _emailController.text.trim());
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
              final authService =
                  await ref.read(authServiceProviderAsync.future);
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

            if (token.isEmpty ||
                newPassword.isEmpty ||
                confirmPassword.isEmpty) {
              setSheetState(() => error = l10n.authLoginResetFillAllFields);
              return;
            }
            if (!PasswordPolicy.isSatisfied(newPassword)) {
              setSheetState(
                () => error = PasswordPolicy.hasMinLength(newPassword)
                    ? l10n.authSignupPasswordRequirementsNotMet
                    : l10n.authSignupPasswordMinLength,
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
              final authService =
                  await ref.read(authServiceProviderAsync.future);
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

  void _showServerSheet() {
    final urlController =
        TextEditingController(text: ApiConfig.runtimeBaseUrl ?? '');
    var isChecking = false;
    String? error;

    showAppBottomSheet(
      context: context,
      title: l10n.authServerSheetTitle,
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> apply(String? url) async {
            final navigator = Navigator.of(context);
            final authService = await ref.read(authServiceProviderAsync.future);
            await authService.clearLocalSession();
            ref.read(authStateProvider.notifier).state = false;
            final prefs = await SharedPreferences.getInstance();
            if (url == null) {
              await prefs.remove(ApiConfig.serverUrlKey);
            } else {
              await prefs.setString(ApiConfig.serverUrlKey, url);
            }
            ApiConfig.setRuntimeBaseUrl(url);
            // New base URL → new Dio; auth service caches a Dio, oauth
            // availability follows dioProvider by itself.
            ref.invalidate(dioProvider);
            ref.invalidate(authServiceProviderAsync);
            if (mounted) navigator.pop();
          }

          Future<void> save() async {
            final raw = urlController.text.trim().replaceAll(
                  RegExp(r'/+$'),
                  '',
                );
            if (raw.isEmpty) {
              if (ApiConfig.defaultBaseUrl.isEmpty) {
                setSheetState(() => error = l10n.authServerUrlInvalid);
                return;
              }
              await apply(null);
              return;
            }

            final uri = Uri.tryParse(raw);
            if (uri == null ||
                !(uri.scheme == 'http' || uri.scheme == 'https') ||
                uri.host.isEmpty) {
              setSheetState(() => error = l10n.authServerUrlInvalid);
              return;
            }
            if (uri.scheme != 'https' &&
                !(kDebugMode &&
                    (uri.host == 'localhost' ||
                        uri.host == '127.0.0.1' ||
                        uri.host == '10.0.2.2'))) {
              setSheetState(() => error = l10n.authServerUrlInvalid);
              return;
            }

            setSheetState(() {
              isChecking = true;
              error = null;
            });
            try {
              final dio = Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ));
              await dio.getUri(Uri.parse('$raw/healthz'));
              dio.close();
              await apply(raw);
            } catch (_) {
              setSheetState(() {
                isChecking = false;
                error = l10n.authServerUnreachable;
              });
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!ApiConfig.isConfigured) ...[
                AppAlert(
                  type: AppAlertType.info,
                  message: l10n.authServerNoDefault,
                ),
                const SizedBox(height: MitlistSpacing.md),
              ],
              Text(
                l10n.authServerSheetBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: MitlistSpacing.lg),
              if (error != null) ...[
                AppAlert(type: AppAlertType.error, message: error!),
                const SizedBox(height: MitlistSpacing.md),
              ],
              AppInput(
                label: l10n.authServerUrlLabel,
                hint: l10n.authServerUrlHint,
                controller: urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => save(),
              ),
              const SizedBox(height: MitlistSpacing.lg),
              AppButton(
                text: l10n.authServerSave,
                onPressed: isChecking ? null : save,
                isLoading: isChecking,
              ),
              if (ApiConfig.runtimeBaseUrl != null &&
                  ApiConfig.defaultBaseUrl.isNotEmpty) ...[
                const SizedBox(height: MitlistSpacing.sm),
                AppButton(
                  text: l10n.authServerReset,
                  variant: AppButtonVariant.ghost,
                  color: AppButtonColor.neutral,
                  onPressed: isChecking ? null : () => apply(null),
                ),
              ],
            ],
          );
        },
      ),
    ).whenComplete(urlController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Null until the server has said which doors it has. Rendering a form
    // that then vanishes is worse than a beat of spinner.
    final providers = ref.watch(oauthProvidersProvider).valueOrNull;

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
                        child: providers == null
                            ? const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: MitlistSpacing.xl,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _buildSignInMethods(l10n, providers),
                      ),
                      const SizedBox(height: MitlistSpacing.space4),
                      AppButton(
                        variant: AppButtonVariant.ghost,
                        color: AppButtonColor.neutral,
                        size: AppButtonSize.sm,
                        text: l10n.authServerLink,
                        onPressed: (_isLoading || _isSuccess)
                            ? null
                            : _showServerSheet,
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

  /// OAuth first, email + password last. On the hosted service the buttons
  /// are the headline and the form waits behind a button at the bottom; a
  /// self-host with nothing but passwords sees the form straight away.
  /// Nothing here is shown for a method the server did not claim to offer.
  Widget _buildSignInMethods(
    AppLocalizations l10n,
    OAuthProviderAvailability providers,
  ) {
    final busy = _isLoading || _isSuccess;
    final hasOAuth = providers.google || providers.apple;

    if (!hasOAuth && !providers.password) {
      return AppAlert(
        type: AppAlertType.info,
        message: l10n.authLoginNoMethods,
      );
    }

    final showForm = providers.password && (!hasOAuth || _showEmailForm);
    final scheme = Theme.of(context).colorScheme;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            AppAlert(type: AppAlertType.error, message: _errorMessage!),
            const SizedBox(height: MitlistSpacing.space3),
          ],
          if (providers.google) ...[
            AppButton(
              text: l10n.authLoginGoogle,
              icon: const AppIcon(name: 'login', size: 20),
              variant: AppButtonVariant.outline,
              color: AppButtonColor.neutral,
              isLoading: oauthProvider == 'google',
              onPressed: (busy || oauthProvider != null)
                  ? null
                  : () => startOAuth('google'),
            ),
            const SizedBox(height: MitlistSpacing.space3),
          ],
          if (providers.apple) ...[
            AppButton(
              text: l10n.authLoginApple,
              icon: const AppIcon(name: 'apple', size: 20),
              variant: AppButtonVariant.outline,
              color: AppButtonColor.neutral,
              isLoading: oauthProvider == 'apple',
              onPressed: (busy || oauthProvider != null)
                  ? null
                  : () => startOAuth('apple'),
            ),
            const SizedBox(height: MitlistSpacing.space3),
          ],
          // Remember me applies to whichever door is used; it sits under the
          // buttons when there are any, under the form otherwise.
          if (hasOAuth) _buildRememberMe(l10n, busy),
          if (providers.password && hasOAuth) ...[
            const SizedBox(height: MitlistSpacing.space3),
            Divider(color: scheme.outlineVariant, thickness: 2, height: 2),
            const SizedBox(height: MitlistSpacing.space3),
          ],
          if (providers.password && hasOAuth && !_showEmailForm)
            AppButton(
              text: l10n.authLoginWithEmailButton,
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.neutral,
              onPressed: busy ? null : _unfoldEmailForm,
            ),
          if (showForm) ...[
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
            AppButton(
              text: l10n.welcomeSignIn,
              variant: AppButtonVariant.solid,
              color: AppButtonColor.primary,
              size: AppButtonSize.lg,
              isLoading: _isLoading,
              isSuccess: _isSuccess,
              onPressed: busy ? null : _submit,
            ),
            const SizedBox(height: MitlistSpacing.space3),
            if (!hasOAuth) _buildRememberMe(l10n, busy),
            const SizedBox(height: MitlistSpacing.space2),
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
        ],
      ),
    );
  }

  void _unfoldEmailForm() {
    setState(() => _showEmailForm = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });
  }

  Widget _buildRememberMe(AppLocalizations l10n, bool busy) {
    return InkWell(
      onTap: busy ? null : () => setState(() => _rememberMe = !_rememberMe),
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
        child: Row(
          children: [
            AnimatedCheckToggle(
              value: _rememberMe,
              onChanged:
                  busy ? null : (value) => setState(() => _rememberMe = value),
              semanticLabelOn: l10n.authLoginRememberMeOn,
              semanticLabelOff: l10n.authLoginRememberMeOff,
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Text(l10n.authLoginRememberMe),
          ],
        ),
      ),
    );
  }
}
