import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-nav tab indices for [StatefulShellRoute.indexedStack].
const homeShellTabIndex = 0;
const choresShellTabIndex = 1;
const kitchenShellTabIndex = 2;
const moneyShellTabIndex = 3;
const listsShellTabIndex = 4;

/// Tabs the user has opened at least once this session.
final shellVisitedTabsProvider = StateProvider<Set<int>>(
  (ref) => {homeShellTabIndex},
);

void markShellTabVisited(WidgetRef ref, int index) {
  ref.read(shellVisitedTabsProvider.notifier).update((tabs) => {...tabs, index});
}

/// Returns true when [tabIndex] has been visited and [onActivate] should run.
bool shouldActivateShellTab(WidgetRef ref, int tabIndex) {
  return ref.read(shellVisitedTabsProvider).contains(tabIndex);
}
