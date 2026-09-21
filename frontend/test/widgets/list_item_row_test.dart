import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/theme/grocery_category_visual.dart';
import 'package:mitlist/theme/list_tile_accent.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/app_card.dart';
import 'package:mitlist/widgets/list/list_item_row.dart';

final _milk = ListItem(
  id: 'item-1',
  listId: 'list-1',
  name: 'Whole milk',
  quantity: 2,
  unit: 'l',
  canonicalItemId: 'milk',
  checked: false,
  position: 0,
  createdAt: _date,
  updatedAt: _date,
);

final _date = DateTime(2026, 1, 1);

Widget _host(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: MitlistTheme.light,
    darkTheme: MitlistTheme.dark,
    themeMode: themeMode,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: appChild!,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shopping row uses the canonical category visual',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        ListItemRow(
          item: _milk,
          onToggle: (_) {},
          onTap: () => tapped = true,
          shoppingVisual: true,
          groceryCategory: 'dairy',
        ),
      ),
    );

    final card = tester.widget<AppCard>(find.byType(AppCard));
    expect(
      card.backgroundColor,
      ListTileAccent.fromSeed(
        GroceryCategoryVisual.seed('dairy', 'milk'),
        Brightness.light,
      ).tileBackground,
    );
    expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    expect(find.text('2 l'), findsOneWidget);

    await tester.tap(find.text('Whole milk'));
    expect(tapped, isTrue);
  });

  testWidgets('todo row keeps the compact neutral treatment', (tester) async {
    await tester.pumpWidget(
      _host(
        ListItemRow(
          item: _milk,
          onToggle: (_) {},
          onTap: () {},
        ),
      ),
    );

    expect(find.byType(AppCard), findsNothing);
    expect(find.byIcon(Icons.water_drop_outlined), findsNothing);
  });

  testWidgets('shopping row survives dark mode and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        ListItemRow(
          item: _milk,
          onToggle: (_) {},
          onTap: () {},
          shoppingVisual: true,
          groceryCategory: 'dairy',
          claimedLabel: '· claimed',
        ),
        themeMode: ThemeMode.dark,
        textScaler: const TextScaler.linear(1.5),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('2 l · claimed'), findsOneWidget);
  });

  testWidgets('credits the household member who added the item',
      (tester) async {
    await tester.pumpWidget(
      _host(
        ListItemRow(
          item: _milk,
          onToggle: (_) {},
          addedByName: 'Sam',
          shoppingVisual: true,
          groceryCategory: 'dairy',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sam added this'), findsOneWidget);
  });

  testWidgets('shows no credit line without an adder', (tester) async {
    await tester.pumpWidget(
      _host(ListItemRow(item: _milk, onToggle: (_) {})),
    );
    await tester.pump();

    expect(find.textContaining('added this'), findsNothing);
  });
}
