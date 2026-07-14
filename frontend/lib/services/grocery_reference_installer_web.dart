import 'package:flutter/services.dart';

import '../storage/app_database.dart';
import '../storage/grocery_reference_database.dart';
import 'grocery_seed_loader.dart';

/// Web cannot open the native FFI reference database. Load the equivalent
/// bundled JSON datasets into Drift's SQLite/WASM database instead.
class GroceryReferenceInstaller {
  final AppDatabase _db;
  final AssetBundle _bundle;

  GroceryReferenceInstaller(this._db, {AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  Future<GroceryReferenceDatabase> installAndOpen() async {
    await GrocerySeedLoader(_db, bundle: _bundle).loadIfNeeded();
    return GroceryReferenceDatabase.empty();
  }
}
