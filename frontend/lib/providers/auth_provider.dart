import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// Provider for the AuthService instance.
final authServiceProvider = Provider<AuthService>((ref) {
  throw Exception('AuthService not initialized. Call await ref.read(authServiceProvider.future) first.');
});

final authServiceProviderAsync = FutureProvider<AuthService>((ref) async {
  return await AuthService.create(ref);
});

/// Provider for authentication state.
final authStateProvider = StateProvider<bool>((ref) {
  return false;
});

/// Bootstraps auth state from persisted session data on app start.
final authBootstrapProvider = FutureProvider<bool>((ref) async {
  final authService = await ref.read(authServiceProviderAsync.future);
  final authenticated = await authService.bootstrapSession();
  ref.read(authStateProvider.notifier).state = authenticated;
  return authenticated;
});
