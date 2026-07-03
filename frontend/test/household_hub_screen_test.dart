import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/screens/home/household_hub_screen.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/widgets/alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows retry UI when group resolution fails', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(() => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          cachedGroupsProvider.overrideWith(
            (ref) async => throw Exception('network down'),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HouseholdHubScreen(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(AppAlert), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('Create or join a household'), findsNothing);
  });
}
