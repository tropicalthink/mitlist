import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mitlist/app.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final database = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(() => database.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const MitlistApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
