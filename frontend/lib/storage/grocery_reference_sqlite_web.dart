/// Minimal web-side shape for the synchronous `package:sqlite3` API used by
/// [GroceryReferenceDatabase]. The real package is imported on `dart:io`
/// platforms; web seeds the reference data into Drift/WASM and attaches this
/// empty handle so the shared merge code can remain platform-agnostic.
typedef Row = Map<String, Object?>;
typedef ResultSet = List<Row>;

enum OpenMode { readOnly }

class Database {
  ResultSet select(String sql, [List<Object?> parameters = const []]) =>
      const [];

  void dispose() {}
}

class _Sqlite3 {
  const _Sqlite3();

  Database open(String path, {OpenMode? mode}) => Database();
}

const sqlite3 = _Sqlite3();
