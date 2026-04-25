import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
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
      await authService.login(request);
      
      // Update auth state
      ref.read(authStateProvider.notifier).state = true;
      
      if (mounted) {
        context.goNamed('home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MitlistColors.neutral50,
      body: SafeArea(
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
                    style: MitlistTypography.logo(),
                  ),
                  const SizedBox(height: MitlistSpacing.space8),
                  Container(
                    decoration: BoxDecoration(
                      color: MitlistColors.surfacePrimary,
                      border: Border.all(
                        color: MitlistColors.borderPrimary,
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
                        const SizedBox(height: MitlistSpacing.space4),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.login, size: 20),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.apple, size: 20),
                          label: const Text('Continue with Apple'),
                        ),
                        const SizedBox(height: MitlistSpacing.space4),
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
                                      color: MitlistColors.primary600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MitlistSpacing.space2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Forgot password? Coming soon',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: MitlistColors.textSecondary,
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
