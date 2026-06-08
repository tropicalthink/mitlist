import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
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
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

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
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 650));
        if (mounted) context.goNamed('onboarding');
      }
      return;
    } catch (e) {
      setState(() {
        _errorMessage = 'Couldn\u2019t create account. Check your connection and try again.';
      });
    } finally {
      if (mounted && !_isSuccess) setState(() => _isLoading = false);
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
                        PasswordStrengthBar(
                          password: _passwordController.text,
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
                            isSuccess: _isSuccess,
                            onPressed: (_isLoading || _isSuccess) ? null : _submit,
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space4),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            AppButton(
                              variant: AppButtonVariant.ghost,
                              color: AppButtonColor.primary,
                              text: 'Sign in',
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
                              'By creating an account, you agree to our ',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            AppButton(
                              variant: AppButtonVariant.ghost,
                              color: AppButtonColor.neutral,
                              text: 'Terms of Service',
                              onPressed: () => _showLegalSheet(
                                title: 'Terms of Service',
                                paragraphs: const [
                                  'Use mitlist responsibly. Shared household content is visible to the members of that household.',
                                  'Do not upload unlawful content, impersonate others, or abuse the service. Accounts and shared data may be removed for misuse.',
                                  'The app is provided as-is while the product is still evolving. Keep your own backups for anything critical.',
                                ],
                              ),
                            ),
                            Text(
                              ' and ',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            AppButton(
                              variant: AppButtonVariant.ghost,
                              color: AppButtonColor.neutral,
                              text: 'Privacy Policy',
                              onPressed: () => _showLegalSheet(
                                title: 'Privacy Policy',
                                paragraphs: const [
                                  'mitlist stores the account details and household content needed to operate the app.',
                                  'Shared data such as lists, chores, expenses, and recipes is visible to other members of the same household.',
                                  'Only provide information you are comfortable keeping in a shared household workspace.',
                                ],
                              ),
                            ),
                            Text(
                              '.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
