import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/correction_memory_service.dart';
import 'package:mitlist/services/scan/scan_pipeline_service.dart';
import 'package:mitlist/storage/app_database.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  test('constructs shipped scan pipeline wiring in tests', () async {
    final db = _memoryDb();
    addTearDown(db.close);

    final pipeline = ScanPipelineService(db: db);

    expect(pipeline.corrections, isA<CorrectionMemoryService>());
  });
}
