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
