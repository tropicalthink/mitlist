import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storeAislesAsset = 'assets/grocery/store_aisles.json';
const _selectedStoreKey = 'selected_store_id';

/// A store the household can choose to shop at. Layouts ship globally; picking
/// one is a personal/household choice that drives shopping-path aisle sorting.
class StoreOption {
  final String id;
  final String name;
  final String country;
  final String chainType;

  const StoreOption({
    required this.id,
    required this.name,
    required this.country,
    required this.chainType,
  });

  String get label => '$name · $country';
}

/// The catalog of stores we have aisle layouts for, read from the bundled
/// asset (no DB round-trip needed — it's a small list).
final storeCatalogProvider = FutureProvider<List<StoreOption>>((ref) async {
  final raw = await rootBundle.loadString(_storeAislesAsset);
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final stores = (json['stores'] as List).cast<Map<String, dynamic>>();
  return [
    for (final s in stores)
      StoreOption(
        id: s['id'] as String,
        name: s['name'] as String? ?? '',
        country: s['country'] as String? ?? '',
        chainType: s['chain_type'] as String? ?? '',
      ),
  ];
});

/// The currently selected store id, persisted on-device. Null means "no store
/// chosen" — the pipeline then falls back to category-level aisles.
final selectedStoreIdProvider =
    StateNotifierProvider<SelectedStoreNotifier, String?>((ref) {
  final notifier = SelectedStoreNotifier();
  notifier.load();
  return notifier;
});

class SelectedStoreNotifier extends StateNotifier<String?> {
  SelectedStoreNotifier() : super(null);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_selectedStoreKey);
  }

  Future<void> select(String? storeId) async {
    state = storeId;
    final prefs = await SharedPreferences.getInstance();
    if (storeId == null) {
      await prefs.remove(_selectedStoreKey);
    } else {
      await prefs.setString(_selectedStoreKey, storeId);
    }
  }
}
