import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_models.dart';
import '../providers/auth_provider.dart';
import '../theme/spacing.dart';
import '../widgets/alert.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

/// Integration test screen to verify API connection.
class IntegrationTestScreen extends ConsumerStatefulWidget {
  const IntegrationTestScreen({super.key});

  @override
  ConsumerState<IntegrationTestScreen> createState() =>
      _IntegrationTestScreenState();
}

class _IntegrationTestScreenState extends ConsumerState<IntegrationTestScreen> {
  final _emailController = TextEditingController(text: kReleaseMode ? '' : 'test@example.com');
  final _passwordController = TextEditingController(text: kReleaseMode ? '' : 'password123');
  final _nameController = TextEditingController(text: kReleaseMode ? '' : 'Test User');

  bool _isLoading = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final request = LoginRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final tokenPair = await authService.login(request);
      setState(() {
        _result = 'Login successful! Token: ${tokenPair.accessToken.substring(0, 20)}...';
      });
    } catch (e) {
      setState(() {
        _error = 'Login failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testRegister() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final request = RegisterRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: 'Test',
        lastName: 'User',
      );
      final tokenPair = await authService.register(request);
      setState(() {
        _result = 'Registration successful! Token: ${tokenPair.accessToken.substring(0, 20)}...';
      });
    } catch (e) {
      setState(() {
        _error = 'Registration failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testGetMe() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final user = await authService.getMe();
      setState(() {
        _result = 'GetMe successful! User: ${user.fullName} (${user.email})';
      });
    } catch (e) {
      setState(() {
        _error = 'GetMe failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testLogout() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.logout();
      setState(() {
        _result = 'Logout successful!';
      });
    } catch (e) {
      setState(() {
        _error = 'Logout failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integration Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'API Integration Test',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: MitlistSpacing.space4),
            AppInput(
              label: 'Email',
              controller: _emailController,
            ),
            const SizedBox(height: MitlistSpacing.space3),
            AppInput(
              label: 'Password',
              controller: _passwordController,
              obscureText: true,
            ),
            const SizedBox(height: MitlistSpacing.space3),
            AppInput(
              label: 'Name',
              controller: _nameController,
            ),
            const SizedBox(height: MitlistSpacing.space4),
            Wrap(
              spacing: MitlistSpacing.space3,
              runSpacing: MitlistSpacing.space3,
              children: [
                AppButton(
                  text: 'Test Login',
                  isLoading: _isLoading,
                  onPressed: _testLogin,
                ),
                AppButton(
                  text: 'Test Register',
                  isLoading: _isLoading,
                  onPressed: _testRegister,
                ),
                AppButton(
                  text: 'Test GetMe',
                  isLoading: _isLoading,
                  onPressed: _testGetMe,
                ),
                AppButton(
                  text: 'Test Logout',
                  isLoading: _isLoading,
                  onPressed: _testLogout,
                ),
              ],
            ),
            const SizedBox(height: MitlistSpacing.space4),
            if (_result != null)
              AppAlert(
                type: AppAlertType.success,
                message: _result!,
              ),
            if (_error != null)
              AppAlert(
                type: AppAlertType.error,
                message: _error!,
              ),
            const Spacer(),
            if (kReleaseMode)
              Padding(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                child: AppAlert(
                  type: AppAlertType.error,
                  message: 'Not available in production',
                ),
              ),
            if (!kReleaseMode) ...[
              Text(
                'Backend URL: http://localhost:8000/api/v1',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.space2),
              Text(
                'Make sure the Go backend is running before testing!',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
