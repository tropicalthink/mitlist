final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isValidGroupId(String? groupId) {
  return groupId != null && _uuidPattern.hasMatch(groupId);
}

void ensureValidGroupId(String groupId) {
  if (!isValidGroupId(groupId)) {
    throw ArgumentError.value(groupId, 'groupId', 'Must be a valid UUID');
  }
}
