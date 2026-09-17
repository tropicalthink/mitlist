import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/l10n/app_localizations_de.dart';
import 'package:mitlist/l10n/app_localizations_en.dart';
import 'package:mitlist/l10n/app_localizations_es.dart';
import 'package:mitlist/l10n/app_localizations_fr.dart';
import 'package:mitlist/l10n/app_localizations_nl.dart';
import 'package:mitlist/utils/notification_copy.dart';

void main() {
  test('renders structured expense copy in every supported locale', () {
    final locales = <AppLocalizations, String>{
      AppLocalizationsEn(): 'Expense added',
      AppLocalizationsDe(): 'Ausgabe hinzugefügt',
      AppLocalizationsEs(): 'Gasto añadido',
      AppLocalizationsFr(): 'Dépense ajoutée',
      AppLocalizationsNl(): 'Uitgave toegevoegd',
    };
    final data = {
      'copy': {
        'version': 1,
        'template': 'expense_created',
        'params': {
          'actor_name': 'Mina',
          'expense_name': 'Coffee',
          'group_name': 'Flatmates',
        },
      },
    };

    for (final entry in locales.entries) {
      final result = resolveNotificationText(
        l10n: entry.key,
        fallbackTitle: 'server title',
        fallbackBody: 'server body',
        data: data,
      );
      expect(result.title, entry.value);
      expect(result.body, contains('Mina'));
      expect(result.body, isNot('server body'));
    }
  });

  test('renders singular and plural list batches', () {
    final l10n = AppLocalizationsEn();
    Map<String, dynamic> data(int count) => {
          'copy': {
            'version': 1,
            'template': 'list_items_added',
            'params': {
              'actor_name': 'Mina',
              'item_count': '$count',
              'last_item_name': 'Milk',
              'list_name': 'Groceries',
              'group_name': 'Flatmates',
            },
          },
        };

    expect(
      resolveNotificationText(
        l10n: l10n,
        fallbackTitle: '',
        fallbackBody: '',
        data: data(1),
      ).body,
      'Mina added Milk to Groceries in Flatmates.',
    );
    expect(
      resolveNotificationText(
        l10n: l10n,
        fallbackTitle: '',
        fallbackBody: '',
        data: data(4),
      ).body,
      'Mina added 4 items to Groceries in Flatmates.',
    );
  });

  test('lists the digest item names when the server provides them', () {
    final l10n = AppLocalizationsEn();
    final data = {
      'copy': {
        'version': 1,
        'template': 'list_items_added',
        'params': {
          'actor_name': 'Mina',
          'item_count': '4',
          'last_item_name': 'Bread',
          'item_names': 'Milk, Eggs, Bread, …',
          'list_name': 'Groceries',
          'group_name': 'Flatmates',
        },
      },
    };

    expect(
      resolveNotificationText(
        l10n: l10n,
        fallbackTitle: '',
        fallbackBody: '',
        data: data,
      ).body,
      'Mina added 4 items to Groceries in Flatmates: Milk, Eggs, Bread, …',
    );
  });

  test('renders meal plan and expense digests in every supported locale', () {
    final locales = <AppLocalizations>[
      AppLocalizationsEn(),
      AppLocalizationsDe(),
      AppLocalizationsEs(),
      AppLocalizationsFr(),
      AppLocalizationsNl(),
    ];
    final mealPlan = {
      'copy': {
        'version': 1,
        'template': 'meal_plan_changed_digest',
        'params': {
          'actor_name': 'Mina',
          'group_name': 'Flatmates',
          'change_count': '5',
          'item_names': 'Pasta, Curry, Tacos, …',
        },
      },
    };
    final expenses = {
      'copy': {
        'version': 1,
        'template': 'expenses_created_digest',
        'params': {
          'actor_name': 'Mina',
          'group_name': 'Flatmates',
          'expense_count': '3',
        },
      },
    };

    for (final l10n in locales) {
      final meals = resolveNotificationText(
        l10n: l10n,
        fallbackTitle: 'server title',
        fallbackBody: 'server body',
        data: mealPlan,
      );
      expect(meals.title, l10n.notificationMealPlanTitle);
      expect(meals.body, contains('5'));
      expect(meals.body, contains('Pasta, Curry, Tacos, …'));

      final money = resolveNotificationText(
        l10n: l10n,
        fallbackTitle: 'server title',
        fallbackBody: 'server body',
        data: expenses,
      );
      expect(money.title, l10n.notificationExpensesDigestTitle);
      expect(money.body, contains('Mina'));
      expect(money.body, contains('3'));
      expect(money.body, isNot(contains(':')));
    }
  });

  test('digest copy with a single change falls back to the server text', () {
    final result = resolveNotificationText(
      l10n: AppLocalizationsEn(),
      fallbackTitle: 'Meal plan updated',
      fallbackBody: 'Mina updated the meal plan in Flatmates.',
      data: {
        'copy': {
          'version': 1,
          'template': 'meal_plan_changed_digest',
          'params': {
            'actor_name': 'Mina',
            'group_name': 'Flatmates',
            'change_count': '1',
          },
        },
      },
    );
    expect(result.body, 'Mina updated the meal plan in Flatmates.');
  });

  test('supports string-encoded push copy and legacy fallback', () {
    final l10n = AppLocalizationsEn();
    final structured = resolveNotificationText(
      l10n: l10n,
      fallbackTitle: 'Reminder',
      fallbackBody: 'fallback',
      data: {
        'copy':
            '{"version":1,"template":"pinwall_reminder","params":{"content":"Take out recycling"}}',
      },
    );
    expect(structured.body, 'Take out recycling');

    final legacy = resolveNotificationText(
      l10n: l10n,
      fallbackTitle: 'Legacy title',
      fallbackBody: 'Legacy body',
      data: {'screen': 'householdHub'},
    );
    expect(legacy.title, 'Legacy title');
    expect(legacy.body, 'Legacy body');
  });

  test('malformed or incomplete structured copy fails safely', () {
    final result = resolveNotificationText(
      l10n: AppLocalizationsEn(),
      fallbackTitle: 'Safe title',
      fallbackBody: 'Safe body',
      data: {
        'copy': {
          'version': 1,
          'template': 'expense_created',
          'params': {'actor_name': 'Mina'},
        },
      },
    );
    expect(result.title, 'Safe title');
    expect(result.body, 'Safe body');
  });
}
