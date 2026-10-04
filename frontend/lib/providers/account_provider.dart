import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/account_repository.dart';
import 'auth_provider.dart';
import 'list_provider.dart';

/// Offline-first account writes (the UI language for server email).
final accountRepositoryProvider =
    FutureProvider<AccountRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final authService = await ref.read(authServiceProviderAsync.future);
  return AccountRepository(
    db: db,
    updateMe: authService.updateMe,
    onLocalWrite: ref.watch(syncSchedulerProvider).noteLocalWrite,
  );
});
