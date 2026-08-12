import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/theme/grocery_category_visual.dart';
import 'package:mitlist/theme/list_tile_accent.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/app_card.dart';
import 'package:mitlist/widgets/shopping/shopping_trip_item_card.dart';

final _milk = ListItem(
  id: 'item-1',
  listId: 'list-1',
  name: 'Whole milk',
  quantity: 2,
  unit: 'l',
  priceCents: 349,
  canonicalItemId: 'milk',
  checked: false,
  position: 0,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

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
  testWidgets('renders a category-aware one-handed picking target',
      (tester) async {
    var toggles = 0;
    await tester.pumpWidget(
      _host(
        ShoppingTripItemCard(
          item: _milk,
          isChecked: false,
          groceryCategory: 'dairy',
          onToggle: () => toggles++,
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
    expect(find.text('2 l · €3.49'), findsOneWidget);
    expect(
        tester.getSize(find.byType(AppCard)).height, greaterThanOrEqualTo(72));

    await tester.tap(find.text('Whole milk'));
    expect(toggles, 1);
  });

  testWidgets('checked card quiets down in dark mode at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        ShoppingTripItemCard(
          item: _milk,
          isChecked: true,
          groceryCategory: 'dairy',
          onToggle: () {},
        ),
        themeMode: ThemeMode.dark,
        textScaler: const TextScaler.linear(1.5),
      ),
    );

    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ShoppingTripItemCard));
    final card = tester.widget<AppCard>(find.byType(AppCard));
    expect(
      card.backgroundColor,
      Theme.of(context).colorScheme.surfaceContainerLow,
    );
    expect(tester.takeException(), isNull);
  });
}
