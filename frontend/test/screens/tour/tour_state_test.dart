import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/screens/tour/tour_state.dart';

void main() {
  group('TourSandbox', () {
    test('seed has four things to buy, one overdue chore, a positive balance',
        () {
      final state = seedTourState();
      expect(state.items.where((i) => !i.checked).length, 4);
      expect(state.chores.where((c) => c.overdue).map((c) => c.id),
          [tourChoreBinsId]);
      // Pizza $42 three ways: Sam and Ines owe $14 each. Repair $60 three
      // ways: the person owes $20. Net: owed $8.
      expect(state.owedToMeCents, 2800);
      expect(state.iOweCents, 2000);
      expect(state.netBalanceCents, 800);
    });

    test('toggling and adding items changes the list', () {
      final sandbox = TourSandbox();
      sandbox.toggleItem('i3');
      expect(sandbox.state.items.firstWhere((i) => i.id == 'i3').checked, true);
      sandbox.toggleItem('i3');
      expect(
          sandbox.state.items.firstWhere((i) => i.id == 'i3').checked, false);

      sandbox.addItem('  Lemons ');
      expect(sandbox.state.items.last.name, 'Lemons');
      expect(sandbox.state.items.last.checked, false);

      final before = sandbox.state.items.length;
      sandbox.addItem('   ');
      expect(sandbox.state.items.length, before);
    });

    test('leaving people out of the pizza split moves the balance', () {
      final sandbox = TourSandbox();
      sandbox.togglePizzaShare(tourInesId);
      // Two ways: Sam owes $21; the person still owes $20 for the repair.
      expect(sandbox.state.pizzaSharesOwed, {tourSamId: 2100});
      expect(sandbox.state.netBalanceCents, 100);

      sandbox.togglePizzaShare(tourSamId);
      expect(sandbox.state.pizzaSharesOwed, isEmpty);
      expect(sandbox.state.netBalanceCents, -2000);

      // The payer cannot be removed.
      sandbox.togglePizzaShare(tourMeId);
      expect(sandbox.state.pizzaSplit, contains(tourMeId));
    });

    test('chores rotate to the next member', () {
      final sandbox = TourSandbox();
      final bathroom =
          sandbox.state.chores.firstWhere((c) => c.id == tourChoreBathroomId);
      expect(bathroom.assigneeId, tourMeId);
      expect(sandbox.nextInRotation(bathroom).id, tourSamId);

      final plants =
          sandbox.state.chores.firstWhere((c) => c.id == tourChorePlantsId);
      expect(sandbox.nextInRotation(plants).id, tourInesId);

      sandbox.toggleChore(tourChoreBinsId);
      final bins =
          sandbox.state.chores.firstWhere((c) => c.id == tourChoreBinsId);
      expect(bins.done, true);
      expect(bins.overdue, false);
    });

    test('recipe ingredients land on the list once', () {
      final sandbox = TourSandbox();
      final before = sandbox.state.items.length;
      sandbox.addRecipeIngredients();
      expect(sandbox.state.items.length, before + tourRecipeIngredients.length);
      expect(sandbox.state.items.last.name, tourRecipeIngredients.last);
      sandbox.addRecipeIngredients();
      expect(sandbox.state.items.length, before + tourRecipeIngredients.length);
    });
  });
}
