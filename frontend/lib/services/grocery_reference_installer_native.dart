import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/app_database.dart';
import '../storage/grocery_reference_database.dart';

/// Installs the prebuilt global grocery reference DB from the bundled,
/// gzipped asset and opens it read-only on native platforms.
class GroceryReferenceInstaller {
  final AppDatabase _db;
  final AssetBundle _bundle;

  GroceryReferenceInstaller(this._db, {AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  static const _asset = 'assets/grocery/grocery_ref.sqlite.gz';
  static const _versionAsset = 'assets/grocery/grocery_ref.version.json';
  static const _installedFileName = 'grocery_ref.sqlite';
  static const _versionKey = '__grocery_ref__';

  /// Ensures the bundled reference DB (or a newer one) is present on disk and
  /// returns an open read-only handle. Safe to call on every cold start.
  Future<GroceryReferenceDatabase> installAndOpen() async {
    final dir = await getApplicationSupportDirectory();
    final target = File('${dir.path}/$_installedFileName');

    final bundledVersion = await _readBundledVersion();
    final installedVersion = await _db.getGroceryVersion(_versionKey);

    if (!target.existsSync() ||
        (bundledVersion != null && installedVersion < bundledVersion)) {
      await _install(target);
      if (bundledVersion != null) {
        await _db.setGroceryVersion(_versionKey, bundledVersion);
      }
    }

    return GroceryReferenceDatabase.open(target.path);
  }

  Future<int?> _readBundledVersion() async {
    try {
      final raw = await _bundle.loadString(_versionAsset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (json['version'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> _install(File target) async {
    final data = await _bundle.load(_asset);
    final compressed = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final bytes = gzip.decode(compressed);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    if (target.existsSync()) {
      await target.delete();
    }
    await tmp.rename(target.path);
    if (kDebugMode) {
      debugPrint(
          'grocery_ref installed: ${bytes.length} bytes -> ${target.path}');
    }
  }
}
