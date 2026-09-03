import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sample household the feature tour is played on. Everything here lives
/// in memory for the length of one tour and is thrown away afterwards: it is
/// a demonstration, not a draft of the household the person will create.
///
/// Names and amounts are deliberately ordinary. The seed exists so that every
/// tour page has something real to tap, and so that a tap on one page shows
/// up on another (ingredients added on the recipe page land on the list from
/// the lists page).
class TourMember {
  const TourMember({required this.id, required this.name});

  final String id;
  final String name;

  String get initials => name.isEmpty ? '?' : name[0].toUpperCase();
}

class TourListItem {
  const TourListItem({
    required this.id,
    required this.name,
    required this.checked,
    this.addedBy,
  });

  final String id;
  final String name;
  final bool checked;

  /// Who put it on the list; null for items the person adds themselves.
  final String? addedBy;

  TourListItem copyWith({bool? checked}) => TourListItem(
        id: id,
        name: name,
        checked: checked ?? this.checked,
        addedBy: addedBy,
      );
}

class TourChore {
  const TourChore({
    required this.id,
    required this.title,
    required this.assigneeId,
    required this.dueInDays,
    required this.everyDays,
    this.done = false,
  });

  final String id;
  final String title;
  final String assigneeId;

  /// Days from "today"; negative means overdue.
  final int dueInDays;
  final int everyDays;
  final bool done;

  bool get overdue => !done && dueInDays < 0;

  TourChore copyWith({bool? done}) => TourChore(
        id: id,
        title: title,
        assigneeId: assigneeId,
        dueInDays: dueInDays,
        everyDays: everyDays,
        done: done ?? this.done,
      );
}

class TourState {
  const TourState({
    required this.householdName,
    required this.members,
    required this.listName,
    required this.items,
    required this.pizzaCents,
    required this.pizzaSplit,
    required this.repairCents,
    required this.chores,
    required this.ingredientsAdded,
  });

  final String householdName;

  /// The person is always first.
  final List<TourMember> members;

  final String listName;
  final List<TourListItem> items;

  /// "Pizza night", paid by the person.
  final int pizzaCents;

  /// Member ids sharing the pizza. Always contains the person.
  final Set<String> pizzaSplit;

  /// "Washing machine repair", paid by the third member, split three ways.
  final int repairCents;

  final List<TourChore> chores;

  /// Whether the recipe's ingredients have been pushed onto the list.
  final bool ingredientsAdded;

  TourMember get me => members.first;

  TourMember member(String id) => members.firstWhere((m) => m.id == id);

  /// The person's net balance in cents against the whole household after
  /// both expenses: positive means others owe them.
  int get netBalanceCents => owedToMeCents - iOweCents;

  /// What the others owe the person for the pizza, in cents.
  int get owedToMeCents {
    final shares = pizzaSplit.length;
    if (shares <= 1) return 0;
    final each = pizzaCents ~/ shares;
    return each * (shares - 1);
  }

  /// What the person owes for the repair (one third of it), in cents.
  int get iOweCents => repairCents ~/ members.length;

  /// Per-member share of the pizza owed to the person, in cents, for every
  /// member in the split other than the person.
  Map<String, int> get pizzaSharesOwed {
    final shares = pizzaSplit.length;
    if (shares <= 1) return const {};
    final each = pizzaCents ~/ shares;
    return {
      for (final id in pizzaSplit)
        if (id != me.id) id: each,
    };
  }

  TourState copyWith({
    List<TourListItem>? items,
    Set<String>? pizzaSplit,
    List<TourChore>? chores,
    bool? ingredientsAdded,
  }) =>
      TourState(
        householdName: householdName,
        members: members,
        listName: listName,
        items: items ?? this.items,
        pizzaCents: pizzaCents,
        pizzaSplit: pizzaSplit ?? this.pizzaSplit,
        repairCents: repairCents,
        chores: chores ?? this.chores,
        ingredientsAdded: ingredientsAdded ?? this.ingredientsAdded,
      );
}

/// Ids are stable so tests and widget keys can refer to them.
const tourMeId = 'me';
const tourSamId = 'sam';
const tourInesId = 'ines';

const tourChoreBinsId = 'bins';
const tourChoreBathroomId = 'bathroom';
const tourChorePlantsId = 'plants';

/// Ingredients the recipe page pushes onto the list, in order.
const tourRecipeIngredients = ['Eggs', 'Tinned tomatoes', 'Feta'];

TourState seedTourState() => const TourState(
      householdName: 'Flat 3B',
      members: [
        TourMember(id: tourMeId, name: 'You'),
        TourMember(id: tourSamId, name: 'Sam'),
        TourMember(id: tourInesId, name: 'Ines'),
      ],
      listName: 'Weekend groceries',
      items: [
        TourListItem(id: 'i1', name: 'Oat milk', checked: true, addedBy: 'Sam'),
        TourListItem(id: 'i2', name: 'Bananas', checked: true, addedBy: 'Sam'),
        TourListItem(id: 'i3', name: 'Coffee beans', checked: false),
        TourListItem(
            id: 'i4', name: 'Dish soap', checked: false, addedBy: 'Ines'),
        TourListItem(id: 'i5', name: 'Rice', checked: false),
        TourListItem(
            id: 'i6', name: 'Toilet paper', checked: false, addedBy: 'Sam'),
      ],
      pizzaCents: 4200,
      pizzaSplit: {tourMeId, tourSamId, tourInesId},
      repairCents: 6000,
      chores: [
        TourChore(
          id: tourChoreBinsId,
          title: 'Take out bins',
          assigneeId: tourInesId,
          dueInDays: -1,
          everyDays: 7,
        ),
        TourChore(
          id: tourChoreBathroomId,
          title: 'Clean bathroom',
          assigneeId: tourMeId,
          dueInDays: 2,
          everyDays: 7,
        ),
        TourChore(
          id: tourChorePlantsId,
          title: 'Water plants',
          assigneeId: tourSamId,
          dueInDays: 4,
          everyDays: 7,
        ),
      ],
      ingredientsAdded: false,
    );

class TourSandbox extends StateNotifier<TourState> {
  TourSandbox() : super(seedTourState());

  int _nextItem = 100;

  void toggleItem(String id) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == id) item.copyWith(checked: !item.checked) else item,
      ],
    );
  }

  /// Appends a new unchecked item. Blank names are ignored.
  void addItem(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      items: [
        ...state.items,
        TourListItem(id: 'u${_nextItem++}', name: trimmed, checked: false),
      ],
    );
  }

  /// Toggles whether [memberId] shares the pizza. The person who paid is
  /// always in the split.
  void togglePizzaShare(String memberId) {
    if (memberId == state.me.id) return;
    final split = {...state.pizzaSplit};
    if (!split.remove(memberId)) split.add(memberId);
    state = state.copyWith(pizzaSplit: split);
  }

  void toggleChore(String id) {
    state = state.copyWith(
      chores: [
        for (final chore in state.chores)
          if (chore.id == id) chore.copyWith(done: !chore.done) else chore,
      ],
    );
  }

  /// Pushes the recipe's ingredients onto the list once.
  void addRecipeIngredients() {
    if (state.ingredientsAdded) return;
    state = state.copyWith(
      ingredientsAdded: true,
      items: [
        ...state.items,
        for (final name in tourRecipeIngredients)
          TourListItem(id: 'r${_nextItem++}', name: name, checked: false),
      ],
    );
  }

  /// Who takes [chore] after the current assignee: the next member in order.
  TourMember nextInRotation(TourChore chore) {
    final members = state.members;
    final index = members.indexWhere((m) => m.id == chore.assigneeId);
    return members[(index + 1) % members.length];
  }
}

/// One sandbox per visit to the tour; leaving the tour throws it away.
final tourSandboxProvider =
    StateNotifierProvider.autoDispose<TourSandbox, TourState>(
  (ref) => TourSandbox(),
);
