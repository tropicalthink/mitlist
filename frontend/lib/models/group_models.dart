/// Group model representing a household or group.
class Group {
  final String id;
  final String name;
  final String? description;
  final bool? isPersonal;
  final int? memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.isPersonal,
    this.memberCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPersonal: json['is_personal'] as bool?,
      memberCount: json['member_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      if (isPersonal != null) 'is_personal': isPersonal,
      if (memberCount != null) 'member_count': memberCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Create group request payload.
class CreateGroupRequest {
  final String name;
  final String? description;

  const CreateGroupRequest({
    required this.name,
    this.description,
  });

  factory CreateGroupRequest.fromJson(Map<String, dynamic> json) {
    return CreateGroupRequest(
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }
}

/// Update group request payload.
class UpdateGroupRequest {
  final String? name;
  final String? description;

  const UpdateGroupRequest({
    this.name,
    this.description,
  });

  factory UpdateGroupRequest.fromJson(Map<String, dynamic> json) {
    return UpdateGroupRequest(
      name: json['name'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }
}

/// Join group request payload.
class JoinGroupRequest {
  final String code;

  const JoinGroupRequest({
    required this.code,
  });

  factory JoinGroupRequest.fromJson(Map<String, dynamic> json) {
    return JoinGroupRequest(
      code: json['code'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
    };
  }
}

/// Invite member request payload.
class InviteMemberRequest {
  final String role;

  const InviteMemberRequest({
    required this.role,
  });

  factory InviteMemberRequest.fromJson(Map<String, dynamic> json) {
    return InviteMemberRequest(
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
    };
  }
}

class GroupInvite {
  final String id;
  final String groupId;
  final String code;
  final DateTime expiresAt;
  final String? usedBy;
  final DateTime? usedAt;

  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.code,
    required this.expiresAt,
    required this.usedBy,
    required this.usedAt,
  });

  factory GroupInvite.fromJson(Map<String, dynamic> json) => GroupInvite(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        usedBy: json['used_by'] as String?,
        usedAt: json['used_at'] != null ? DateTime.parse(json['used_at'] as String) : null,
      );
}

class UpdateMemberRoleRequest {
  final String role;
  const UpdateMemberRoleRequest({required this.role});
  Map<String, dynamic> toJson() => {'role': role};
}

class PendingClaim {
  final String id;
  final String groupId;
  final String code;
  final DateTime expiresAt;
  final String? claimedBy;
  final DateTime? claimedAt;

  const PendingClaim({
    required this.id,
    required this.groupId,
    required this.code,
    required this.expiresAt,
    required this.claimedBy,
    required this.claimedAt,
  });

  factory PendingClaim.fromJson(Map<String, dynamic> json) => PendingClaim(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        claimedBy: json['claimed_by'] as String?,
        claimedAt: json['claimed_at'] != null ? DateTime.parse(json['claimed_at'] as String) : null,
      );
}
