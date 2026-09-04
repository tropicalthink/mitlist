import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sample household the premium flow is played on: the same flat the
/// feature tour uses, one person larger.
///
/// The whole argument for premium is arithmetic — a fifth person makes every
/// share smaller and every turn rarer — so these pages let someone do that
/// arithmetic by hand rather than read a claim about it. Toggling the
/// newcomer out of a split really does put the price back up.
///
/// Everything here lives in memory for one visit and is thrown away
/// afterwards. It is a demonstration, never the person's real household.
class PremiumMember {
  const PremiumMember({
    required this.id,
    required this.name,
    this.isNewcomer = false,
  });

  final String id;
  final String name;

  /// The person the household cannot currently add: the one over the free
  /// limit. Drawn apart from the others so the pages have a subject.
  final bool isNewcomer;

  String get initials => name.isEmpty ? '?' : name[0].toUpperCase();
}

class PremiumListItem {
  const PremiumListItem({
    required this.id,
    required this.name,
    required this.checked,
    this.addedById,
  });

  final String id;
  final String name;
  final bool checked;

  /// Which member put it on the list; null for items the person adds
  /// themselves.
  final String? addedById;

  PremiumListItem copyWith({bool? checked}) => PremiumListItem(
        id: id,
        name: name,
        checked: checked ?? this.checked,
        addedById: addedById,
      );
}

class PremiumChore {
  const PremiumChore({
    required this.id,
    required this.title,
    required this.assigneeId,
    this.done = false,
  });

  final String id;
  final String title;
  final String assigneeId;
  final bool done;

  PremiumChore copyWith({String? assigneeId, bool? done}) => PremiumChore(
        id: id,
        title: title,
        assigneeId: assigneeId ?? this.assigneeId,
        done: done ?? this.done,
      );
}

class PremiumSampleState {
  const PremiumSampleState({
    required this.householdName,
    required this.members,
    required this.listName,
    required this.items,
    required this.expenseCents,
    required this.expenseSplit,
    required this.chores,
  });

  final String householdName;

  /// The person is always first, the newcomer always last.
  final List<PremiumMember> members;

  final String listName;
  final List<PremiumListItem> items;

  /// "The big shop", paid by the person.
  final int expenseCents;

  /// Member ids sharing it. The payer is always in.
  final Set<String> expenseSplit;

  final List<PremiumChore> chores;

  PremiumMember get me => members.first;

  PremiumMember get newcomer =>
      members.lastWhere((m) => m.isNewcomer, orElse: () => members.last);

  PremiumMember member(String id) => members.firstWhere((m) => m.id == id);

  /// How many ways the expense is split, never below one.
  int get splitWays => expenseSplit.isEmpty ? 1 : expenseSplit.length;

  /// What each person in the split pays, in cents. Integer division matches
  /// what the money screen actually does with an indivisible remainder.
  int get shareEachCents => expenseCents ~/ splitWays;

  /// Members carrying the rota, in order. A chore comes back to you once per
  /// full pass, so this is also how many weeks there are between your turns.
  int get rotaSize => members.length;

  PremiumSampleState copyWith({
    List<PremiumListItem>? items,
    Set<String>? expenseSplit,
    List<PremiumChore>? chores,
  }) =>
      PremiumSampleState(
        householdName: householdName,
        members: members,
        listName: listName,
        items: items ?? this.items,
        expenseCents: expenseCents,
        expenseSplit: expenseSplit ?? this.expenseSplit,
        chores: chores ?? this.chores,
      );
}

/// Ids are stable so tests and widget keys can refer to them.
const premiumMeId = 'me';
const premiumSamId = 'sam';
const premiumInesId = 'ines';
const premiumTheoId = 'theo';
const premiumMaraId = 'mara';

const premiumChoreBinsId = 'bins';
const premiumChoreBathroomId = 'bathroom';
const premiumChoreShopId = 'shop';

PremiumSampleState seedPremiumSampleState() => const PremiumSampleState(
      householdName: 'Flat 3B',
      members: [
        PremiumMember(id: premiumMeId, name: 'You'),
        PremiumMember(id: premiumSamId, name: 'Sam'),
        PremiumMember(id: premiumInesId, name: 'Ines'),
        PremiumMember(id: premiumTheoId, name: 'Theo'),
        PremiumMember(id: premiumMaraId, name: 'Mara', isNewcomer: true),
      ],
      listName: 'Weekend groceries',
      items: [
        PremiumListItem(
            id: 'i1', name: 'Oat milk', checked: true, addedById: premiumSamId),
        PremiumListItem(
            id: 'i2',
            name: 'Dish soap',
            checked: true,
            addedById: premiumInesId),
        PremiumListItem(id: 'i3', name: 'Coffee beans', checked: false),
        PremiumListItem(
            id: 'i4',
            name: 'Bin bags',
            checked: false,
            addedById: premiumTheoId),
        PremiumListItem(
            id: 'i5',
            name: 'Washing powder',
            checked: false,
            addedById: premiumMaraId),
      ],
      expenseCents: 6240,
      expenseSplit: {
        premiumMeId,
        premiumSamId,
        premiumInesId,
        premiumTheoId,
        premiumMaraId,
      },
      chores: [
        PremiumChore(
          id: premiumChoreBinsId,
          title: 'Take out bins',
          assigneeId: premiumInesId,
        ),
        PremiumChore(
          id: premiumChoreBathroomId,
          title: 'Clean bathroom',
          assigneeId: premiumMeId,
        ),
        PremiumChore(
          id: premiumChoreShopId,
          title: 'Do the big shop',
          assigneeId: premiumMaraId,
        ),
      ],
    );

class PremiumSandbox extends StateNotifier<PremiumSampleState> {
  PremiumSandbox() : super(seedPremiumSampleState());

  void toggleItem(String id) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == id) item.copyWith(checked: !item.checked) else item,
      ],
    );
  }

  /// Toggles whether [memberId] shares the expense. The person who paid is
  /// always in the split, so their chip is a statement rather than a control.
  void toggleShare(String memberId) {
    if (memberId == state.me.id) return;
    final split = {...state.expenseSplit};
    if (!split.remove(memberId)) split.add(memberId);
    state = state.copyWith(expenseSplit: split);
  }

  /// Ticking a chore off hands it to the next member, which is the point: the
  /// longer the rota, the further away your own name gets.
  void completeChore(String id) {
    state = state.copyWith(
      chores: [
        for (final chore in state.chores)
          if (chore.id == id)
            chore.copyWith(
              done: !chore.done,
              assigneeId: chore.done
                  ? previousInRotation(chore).id
                  : nextInRotation(chore).id,
            )
          else
            chore,
      ],
    );
  }

  PremiumMember nextInRotation(PremiumChore chore) {
    final members = state.members;
    final index = members.indexWhere((m) => m.id == chore.assigneeId);
    return members[(index + 1) % members.length];
  }

  PremiumMember previousInRotation(PremiumChore chore) {
    final members = state.members;
    final index = members.indexWhere((m) => m.id == chore.assigneeId);
    return members[(index - 1 + members.length) % members.length];
  }
}

/// One sandbox per visit to the premium flow; leaving it throws the sample
/// household away.
final premiumSandboxProvider =
    StateNotifierProvider.autoDispose<PremiumSandbox, PremiumSampleState>(
  (ref) => PremiumSandbox(),
);
