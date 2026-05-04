import '../models/group_models.dart';

/// Picks [preferredGroupId] when it appears in [groups]; otherwise [groups.first].
///
/// [groups] should be the memberships returned by [GroupService.listGroups]
/// (typically with `limit: 50` so [preferredGroupId] can be found). The API
/// orders groups by newest first, so "first only" is a weak default when the
/// user has several households; pass the shell's selected household id when
/// available so tab/sheet flows match the hub.
String? resolveActiveGroupId(List<Group> groups, String? preferredGroupId) {
  if (groups.isEmpty) return null;
  if (preferredGroupId != null &&
      groups.any((g) => g.id == preferredGroupId)) {
    return preferredGroupId;
  }
  return groups.first.id;
}
