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

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
        _errorMessage = 'Please fill in all fields.';
        if (name.isEmpty) _nameError = 'Name is required.';
        if (email.isEmpty) _emailError = 'Email is required.';
        if (password.isEmpty) _passwordError = 'Password is required.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the auth service
      final authService = await ref.read(authServiceProviderAsync.future);
      
      // Split name into first and last name
      final nameParts = name.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : name;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
      // Make actual API call
      final request = RegisterRequest(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      await authService.register(request);
      
      // Update auth state
      ref.read(authStateProvider.notifier).state = true;
      
      if (mounted) {
        context.goNamed('onboarding');
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
                          label: 'Name',
                          hint: 'Your name',
                          controller: _nameController,
                          focusNode: _nameFocus,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          onSubmitted: (_) => _emailFocus.requestFocus(),
                          errorText: _nameError,
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
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
                          autofillHints: const [AutofillHints.newPassword],
                          onSubmitted: (_) => _submit(),
                          errorText: _passwordError,
                        ),
                        const SizedBox(height: MitlistSpacing.space2),
                        Text(
                          'Use 8+ characters with a mix of letters and numbers.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: MitlistColors.textTertiary,
                                  ),
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
                            text: 'Create account',
                            variant: AppButtonVariant.solid,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : _submit,
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            TextButton(
                              onPressed: () => context.goNamed('login'),
                              child: Text(
                                'Sign in',
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
                        Text(
                          'By creating an account, you agree to our Terms and Privacy Policy.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: MitlistColors.textTertiary,
                                  ),
                          textAlign: TextAlign.center,
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
