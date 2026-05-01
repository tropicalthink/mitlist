import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import '../services/outbox_coordinator.dart';
import 'chore_provider.dart';
import 'finance_provider.dart';
import 'list_provider.dart';
import 'pinwall_provider.dart';
import 'recipe_provider.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final svc = ConnectivityService();
  ref.onDispose(svc.dispose);
  return svc;
});

final outboxCoordinatorProvider = FutureProvider<OutboxCoordinator>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final connectivity = ref.read(connectivityServiceProvider);
  final listRepo = await ref.watch(listRepositoryProvider.future);
  final financeRepo = await ref.watch(financeRepositoryProvider.future);
  final recipeRepo = await ref.watch(recipeRepositoryProvider.future);
  final choreRepo = await ref.watch(choreRepositoryProvider.future);
  final pinwallRepo = await ref.watch(pinwallRepositoryProvider.future);

  final coordinator = OutboxCoordinator(
    db: db,
    connectivity: connectivity,
    listRepo: listRepo,
    financeRepo: financeRepo,
    recipeRepo: recipeRepo,
    choreRepo: choreRepo,
    pinwallRepo: pinwallRepo,
  );

  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
