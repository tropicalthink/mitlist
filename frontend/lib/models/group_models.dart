/// Group model representing a household or group.
class Group {
  final String id;
  final String name;
  final String? description;
  final bool? isPersonal;
  final int? memberCount;
  final String currency;
  final List<String> choreZones;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.isPersonal,
    this.memberCount,
    this.currency = 'USD',
    this.choreZones = const [],
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
      currency: json['currency'] as String? ?? 'USD',
      choreZones: (json['chore_zones'] as List<dynamic>?)
              ?.map((z) => z as String)
              .toList() ??
          const [],
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
      'currency': currency,
      'chore_zones': choreZones,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Create group request payload.
class CreateGroupRequest {
  final String name;
  final String? description;
  final String currency;

  const CreateGroupRequest({
    required this.name,
    this.description,
    this.currency = 'USD',
  });

  factory CreateGroupRequest.fromJson(Map<String, dynamic> json) {
    return CreateGroupRequest(
      name: json['name'] as String,
      description: json['description'] as String?,
      currency: json['currency'] as String? ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'currency': currency,
    };
  }
}

/// Update group request payload.
class UpdateGroupRequest {
  final String? name;
  final String? description;
  final String? currency;
  final List<String>? choreZones;

  const UpdateGroupRequest({
    this.name,
    this.description,
    this.currency,
    this.choreZones,
  });

  factory UpdateGroupRequest.fromJson(Map<String, dynamic> json) {
    return UpdateGroupRequest(
      name: json['name'] as String?,
      description: json['description'] as String?,
      currency: json['currency'] as String?,
      choreZones: (json['chore_zones'] as List<dynamic>?)
          ?.map((z) => z as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'currency': currency,
      if (choreZones != null) 'chore_zones': choreZones,
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

/// What an invite code opens, fetched before the recipient accepts.
class InvitePreview {
  final String code;
  final String groupId;
  final String groupName;
  final int memberCount;
  final DateTime expiresAt;
  final InviteStatus status;

  const InvitePreview({
    required this.code,
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    required this.expiresAt,
    required this.status,
  });

  factory InvitePreview.fromJson(Map<String, dynamic> json) => InvitePreview(
        code: json['code'] as String,
        groupId: json['group_id'] as String,
        groupName: json['group_name'] as String,
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        status: InviteStatus.fromWire(json['status'] as String?),
      );
}

/// Whether an invite can still be accepted. Mirrors the backend's
/// `InviteStatus*` constants.
enum InviteStatus {
  valid,
  expired,
  used,
  alreadyMember;

  static InviteStatus fromWire(String? raw) => switch (raw) {
        'expired' => InviteStatus.expired,
        'used' => InviteStatus.used,
        'already_member' => InviteStatus.alreadyMember,
        _ => InviteStatus.valid,
      };
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
        usedAt: json['used_at'] != null
            ? DateTime.parse(json['used_at'] as String)
            : null,
      );
}

class GroupMemberProfile {
  final String userId;
  final String displayName;
  final String role;

  const GroupMemberProfile({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  factory GroupMemberProfile.fromJson(Map<String, dynamic> json) =>
      GroupMemberProfile(
        userId: json['user_id'] as String,
        displayName:
            json['display_name'] as String? ?? json['user_id'] as String,
        role: json['role'] as String? ?? 'member',
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
        claimedAt: json['claimed_at'] != null
            ? DateTime.parse(json['claimed_at'] as String)
            : null,
      );
}
