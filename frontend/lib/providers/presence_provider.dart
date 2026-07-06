import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import 'group_provider.dart';
import 'list_provider.dart' show sseServiceProvider;

/// Live set of user IDs currently connected to [groupId]'s realtime stream.
///
/// Fed by the `presence:state` events the backend broadcasts on every
/// connect/disconnect, so it reflects who actually has the household open right
/// now — not who is merely a member.
final onlineMemberIdsProvider =
    StreamProvider.family<Set<String>, String>((ref, groupId) {
  final sse = ref.watch(sseServiceProvider);
  // Make sure the stream is open even if no repository attached it yet.
  sse.connect(groupId);

  Set<String> parse(Object? raw) =>
      raw is List ? raw.whereType<String>().toSet() : const <String>{};

  final controller = StreamController<Set<String>>();
  // Seed from the last presence snapshot (delivered when we connected) so an
  // already-connected viewer isn't shown an empty board until someone moves.
  final seed = sse.lastEvent('presence:state', groupId);
  controller.add(seed != null ? parse(seed.payload['user_ids']) : const {});

  final sub = sse.events.listen((e) {
    if (e.type != 'presence:state' || e.groupId != groupId) return;
    controller.add(parse(e.payload['user_ids']));
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Group roster, used to resolve presence ids into names/initials for avatars.
final boardMembersProvider =
    FutureProvider.family<List<GroupMemberProfile>, String>(
        (ref, groupId) async {
  final svc = await ref.read(groupServiceProviderAsync.future);
  return svc.listMembers(groupId);
});

/// Members currently on the board, resolved to profiles and ordered by the
/// roster so avatars don't reshuffle as people come and go. The viewer ([meId])
/// is anchored first when present.
final presentMembersProvider =
    Provider.family<List<GroupMemberProfile>, ({String groupId, String? meId})>(
        (ref, args) {
  final online = ref.watch(onlineMemberIdsProvider(args.groupId)).valueOrNull ??
      const <String>{};
  if (online.isEmpty) return const <GroupMemberProfile>[];

  final members =
      ref.watch(boardMembersProvider(args.groupId)).valueOrNull ?? const [];
  final byId = {for (final m in members) m.userId: m};

  final ordered = <GroupMemberProfile>[];
  // Self first, so "you're here" always anchors the stack.
  final meId = args.meId;
  if (meId != null && online.contains(meId)) {
    ordered.add(byId[meId] ??
        GroupMemberProfile(userId: meId, displayName: '', role: 'member'));
  }
  // Then everyone else in roster order.
  for (final m in members) {
    if (m.userId == meId) continue;
    if (online.contains(m.userId)) ordered.add(m);
  }
  // Finally any online ids the roster hasn't resolved yet.
  final known = ordered.map((m) => m.userId).toSet();
  for (final id in online) {
    if (!known.contains(id)) {
      ordered
          .add(GroupMemberProfile(userId: id, displayName: '', role: 'member'));
    }
  }
  return ordered;
});
