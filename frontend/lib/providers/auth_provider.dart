import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../exceptions.dart';
import 'list_provider.dart' show appDatabaseProvider;

/// Provider for the AuthService instance.
final authServiceProvider = Provider<AuthService>((ref) {
  throw const UnauthorizedException(
      'AuthService not initialized. Call await ref.read(authServiceProvider.future) first.');
});

final authServiceProviderAsync = FutureProvider<AuthService>((ref) async {
  final db = ref.read(appDatabaseProvider);
  return await AuthService.createWithWipe(
      ref: ref, wipeLocalData: db.clearAllUserData);
});

/// Provider for authentication state.
final authStateProvider = StateProvider<bool>((ref) {
  return false;
});

/// One-shot post-auth route (e.g. `/onboarding`) consumed by [routerProvider]
/// redirect on the next navigation refresh.
final pendingAuthNavigationProvider = StateProvider<String?>((ref) => null);

/// Whether the current session is a guest account.
final isGuestProvider = StateProvider<bool>((ref) => false);

/// Bootstraps auth state from persisted session data on app start.
final authBootstrapProvider = FutureProvider<bool>((ref) async {
  final authService = await ref.read(authServiceProviderAsync.future);
  return authService.bootstrapSession();
});

/// Applies bootstrap results to [authStateProvider] outside provider init.
final authBootstrapListenerProvider = Provider<void>((ref) {
  ref.listen(authBootstrapProvider, (_, next) {
    next.whenData((authenticated) async {
      ref.read(authStateProvider.notifier).state = authenticated;
      if (authenticated) {
        try {
          final authService = await ref.read(authServiceProviderAsync.future);
          final user = await authService.getMe();
          ref.read(isGuestProvider.notifier).state = user.isGuest;
        } catch (_) {}
      } else {
        ref.read(isGuestProvider.notifier).state = false;
      }
    });
  });
});
