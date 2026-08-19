class Chore {
  final String id;
  final String groupId;
  final String name;
  final String? description;
  final String rotationType;
  final String frequency;
  final int periodInterval;
  final List<String> periodConfig;
  final DateTime? startDate;
  final bool trackDateOnly;
  final bool rollover;
  final String assignmentType;
  final List<String> assignmentConfig;
  final bool isActive;
  final List<String> supplies;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Chore({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    required this.rotationType,
    required this.frequency,
    this.periodInterval = 1,
    this.periodConfig = const [],
    this.startDate,
    this.trackDateOnly = false,
    this.rollover = false,
    this.assignmentType = 'round-robin',
    this.assignmentConfig = const [],
    required this.isActive,
    this.supplies = const [],
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        rotationType: json['rotation_type'] as String? ?? 'none',
        frequency: json['frequency'] as String? ?? 'daily',
        periodInterval: json['period_interval'] as int? ?? 1,
        periodConfig: (json['period_config'] as List<dynamic>? ?? const [])
            .map((v) => v as String)
            .toList(),
        startDate: json['start_date'] != null
            ? DateTime.parse(json['start_date'] as String)
            : null,
        trackDateOnly: json['track_date_only'] as bool? ?? false,
        rollover: json['rollover'] as bool? ?? false,
        assignmentType: json['assignment_type'] as String? ?? 'round-robin',
        assignmentConfig:
            (json['assignment_config'] as List<dynamic>? ?? const [])
                .map((v) => v as String)
                .toList(),
        isActive: json['is_active'] as bool? ?? true,
        supplies: (json['supplies'] as List<dynamic>? ?? const [])
            .map((v) => v as String)
            .toList(),
        category: json['category'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'name': name,
        if (description != null) 'description': description,
        'rotation_type': rotationType,
        'frequency': frequency,
        'period_interval': periodInterval,
        'period_config': periodConfig,
        if (startDate != null)
          'start_date': startDate!.toUtc().toIso8601String(),
        'track_date_only': trackDateOnly,
        'rollover': rollover,
        'assignment_type': assignmentType,
        'assignment_config': assignmentConfig,
        'is_active': isActive,
        'supplies': supplies,
        if (category != null) 'category': category,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class CreateChoreRequest {
  final String groupId;
  final String name;
  final String? description;
  final String rotationType;
  final String frequency;
  final int periodInterval;
  final List<String> periodConfig;
  final DateTime? startDate;
  final bool trackDateOnly;
  final bool rollover;
  final String assignmentType;
  final List<String> assignmentConfig;
  final bool isActive;
  final List<String> supplies;
  final String? category;
  const CreateChoreRequest({
    required this.groupId,
    required this.name,
    this.description,
    this.rotationType = 'none',
    this.frequency = 'daily',
    this.periodInterval = 1,
    this.periodConfig = const [],
    this.startDate,
    this.trackDateOnly = false,
    this.rollover = false,
    this.assignmentType = 'round-robin',
    this.assignmentConfig = const [],
    this.isActive = true,
    this.supplies = const [],
    this.category,
  });
  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'name': name,
        if (description != null) 'description': description,
        'rotation_type': rotationType,
        'frequency': frequency,
        'period_interval': periodInterval,
        'period_config': periodConfig,
        if (startDate != null)
          'start_date': startDate!.toUtc().toIso8601String(),
        'track_date_only': trackDateOnly,
        'rollover': rollover,
        'assignment_type': assignmentType,
        'assignment_config': assignmentConfig,
        'is_active': isActive,
        'supplies': supplies,
        if (category != null) 'category': category,
      };

  /// Inverse of [toJson], so a queued offline create can be rebuilt from its
  /// durable outbox payload when it finally drains.
  factory CreateChoreRequest.fromJson(Map<String, dynamic> json) =>
      CreateChoreRequest(
        groupId: json['group_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        rotationType: json['rotation_type'] as String? ?? 'none',
        frequency: json['frequency'] as String? ?? 'daily',
        periodInterval: (json['period_interval'] as num?)?.toInt() ?? 1,
        periodConfig: _stringList(json['period_config']),
        startDate: json['start_date'] == null
            ? null
            : DateTime.parse(json['start_date'] as String),
        trackDateOnly: json['track_date_only'] as bool? ?? false,
        rollover: json['rollover'] as bool? ?? false,
        assignmentType: json['assignment_type'] as String? ?? 'round-robin',
        assignmentConfig: _stringList(json['assignment_config']),
        isActive: json['is_active'] as bool? ?? true,
        supplies: _stringList(json['supplies']),
        category: json['category'] as String?,
      );

  static List<String> _stringList(Object? raw) =>
      raw is List ? raw.whereType<String>().toList() : const [];
}

class UpdateChoreRequest {
  final String? name;
  final String? description;
  final String? rotationType;
  final String? frequency;
  final int? periodInterval;
  final List<String>? periodConfig;
  final DateTime? startDate;
  final bool? trackDateOnly;
  final bool? rollover;
  final String? assignmentType;
  final List<String>? assignmentConfig;
  final bool? isActive;
  final List<String>? supplies;

  const UpdateChoreRequest({
    this.name,
    this.description,
    this.rotationType,
    this.frequency,
    this.periodInterval,
    this.periodConfig,
    this.startDate,
    this.trackDateOnly,
    this.rollover,
    this.assignmentType,
    this.assignmentConfig,
    this.isActive,
    this.supplies,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (name != null) m['name'] = name;
    if (description != null) m['description'] = description;
    if (rotationType != null) m['rotation_type'] = rotationType;
    if (frequency != null) m['frequency'] = frequency;
    if (periodInterval != null) m['period_interval'] = periodInterval;
    if (periodConfig != null) m['period_config'] = periodConfig;
    if (startDate != null) {
      m['start_date'] = startDate!.toUtc().toIso8601String();
    }
    if (trackDateOnly != null) m['track_date_only'] = trackDateOnly;
    if (rollover != null) m['rollover'] = rollover;
    if (assignmentType != null) m['assignment_type'] = assignmentType;
    if (assignmentConfig != null) m['assignment_config'] = assignmentConfig;
    if (isActive != null) m['is_active'] = isActive;
    if (supplies != null) m['supplies'] = supplies;
    return m;
  }
}

class CompleteChoreRequest {
  final String? notes;
  const CompleteChoreRequest({this.notes});
  Map<String, dynamic> toJson() => {
        if (notes != null) 'notes': notes,
      };
}

class RescheduleChoreRequest {
  final DateTime? dueDate;
  final String? assigneeId;

  const RescheduleChoreRequest({this.dueDate, this.assigneeId});

  Map<String, dynamic> toJson() => {
        if (dueDate != null) 'due_date': dueDate!.toUtc().toIso8601String(),
        if (assigneeId != null) 'assignee_id': assigneeId,
      };
}

class ChoreAssignment {
  final String id;
  final String choreId;
  final String userId;
  final String status;
  final DateTime? dueDate;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final String? skipReason;

  const ChoreAssignment({
    required this.id,
    required this.choreId,
    required this.userId,
    required this.status,
    required this.dueDate,
    required this.assignedAt,
    required this.completedAt,
    this.skipReason,
  });

  factory ChoreAssignment.fromJson(Map<String, dynamic> json) =>
      ChoreAssignment(
        id: json['id'] as String,
        choreId: json['chore_id'] as String,
        userId: json['user_id'] as String,
        status: json['status'] as String? ?? 'pending',
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
        assignedAt: DateTime.parse(json['assigned_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        skipReason: json['skip_reason'] as String?,
      );
}

class CurrentChore {
  final Chore chore;
  final ChoreAssignment? pendingAssignment;
  final ChoreAssignment? lastAssignment;
  final String dueStatus;
  final bool assignedToMe;

  /// Who the turn passes to after the pending assignment; only set when the
  /// rotation is deterministic (sequential assignment types).
  final String? nextAssigneeUserId;

  const CurrentChore({
    required this.chore,
    this.pendingAssignment,
    this.lastAssignment,
    required this.dueStatus,
    required this.assignedToMe,
    this.nextAssigneeUserId,
  });

  factory CurrentChore.fromJson(Map<String, dynamic> json) => CurrentChore(
        chore: Chore.fromJson((json['chore'] as Map).cast<String, dynamic>()),
        pendingAssignment: json['pending_assignment'] != null
            ? ChoreAssignment.fromJson(
                (json['pending_assignment'] as Map).cast<String, dynamic>(),
              )
            : null,
        lastAssignment: json['last_assignment'] != null
            ? ChoreAssignment.fromJson(
                (json['last_assignment'] as Map).cast<String, dynamic>(),
              )
            : null,
        dueStatus: json['due_status'] as String? ?? 'unscheduled',
        assignedToMe: json['assigned_to_me'] as bool? ?? false,
        nextAssigneeUserId: json['next_assignee_user_id'] as String?,
      );
}

class ChoreStats {
  final int trackedCount;
  final DateTime? lastTrackedAt;
  final String? lastDoneByUserId;
  final double? averageFrequencyHours;

  const ChoreStats({
    required this.trackedCount,
    this.lastTrackedAt,
    this.lastDoneByUserId,
    this.averageFrequencyHours,
  });

  factory ChoreStats.fromJson(Map<String, dynamic> json) => ChoreStats(
        trackedCount: json['tracked_count'] as int? ?? 0,
        lastTrackedAt: json['last_tracked_at'] != null
            ? DateTime.parse(json['last_tracked_at'] as String)
            : null,
        lastDoneByUserId: json['last_done_by_user_id'] as String?,
        averageFrequencyHours:
            (json['average_frequency_hours'] as num?)?.toDouble(),
      );
}

class ChoreDetails {
  final Chore chore;
  final ChoreAssignment? pendingAssignment;
  final ChoreAssignment? lastAssignment;
  final ChoreStats stats;
  final String dueStatus;
  final bool assignedToMe;

  /// Who the turn passes to after the pending assignment; only set when the
  /// rotation is deterministic (sequential assignment types).
  final String? nextAssigneeUserId;

  const ChoreDetails({
    required this.chore,
    this.pendingAssignment,
    this.lastAssignment,
    required this.stats,
    required this.dueStatus,
    required this.assignedToMe,
    this.nextAssigneeUserId,
  });

  factory ChoreDetails.fromJson(Map<String, dynamic> json) => ChoreDetails(
        chore: Chore.fromJson((json['chore'] as Map).cast<String, dynamic>()),
        pendingAssignment: json['pending_assignment'] != null
            ? ChoreAssignment.fromJson(
                (json['pending_assignment'] as Map).cast<String, dynamic>(),
              )
            : null,
        lastAssignment: json['last_assignment'] != null
            ? ChoreAssignment.fromJson(
                (json['last_assignment'] as Map).cast<String, dynamic>(),
              )
            : null,
        stats:
            ChoreStats.fromJson((json['stats'] as Map).cast<String, dynamic>()),
        dueStatus: json['due_status'] as String? ?? 'unscheduled',
        assignedToMe: json['assigned_to_me'] as bool? ?? false,
        nextAssigneeUserId: json['next_assignee_user_id'] as String?,
      );
}

class ChoreTemplate {
  final String id;
  final String groupId;
  final String name;
  final String? description;
  final String rotationType;
  final String frequency;
  final int periodInterval;
  final List<String> periodConfig;
  final bool trackDateOnly;
  final bool rollover;
  final String assignmentType;
  final String? category;

  const ChoreTemplate({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    this.rotationType = '',
    this.frequency = 'daily',
    this.periodInterval = 1,
    this.periodConfig = const [],
    this.trackDateOnly = false,
    this.rollover = false,
    this.assignmentType = 'round-robin',
    this.category,
  });

  factory ChoreTemplate.fromJson(Map<String, dynamic> json) => ChoreTemplate(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        rotationType: json['rotation_type'] as String? ?? '',
        frequency: json['frequency'] as String? ?? 'daily',
        periodInterval: json['period_interval'] as int? ?? 1,
        periodConfig: (json['period_config'] as List<dynamic>? ?? const [])
            .map((v) => v as String)
            .toList(),
        trackDateOnly: json['track_date_only'] as bool? ?? false,
        rollover: json['rollover'] as bool? ?? false,
        assignmentType: json['assignment_type'] as String? ?? 'round-robin',
        category: json['category'] as String?,
      );
}

class CreateChoreTemplateRequest {
  final String groupId;
  final String name;
  final String? description;
  final String frequency;
  final int periodInterval;
  final List<String> periodConfig;
  final bool trackDateOnly;
  final bool rollover;
  final String assignmentType;
  final String? category;

  const CreateChoreTemplateRequest({
    required this.groupId,
    required this.name,
    this.description,
    this.frequency = 'daily',
    this.periodInterval = 1,
    this.periodConfig = const [],
    this.trackDateOnly = false,
    this.rollover = false,
    this.assignmentType = 'round-robin',
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'name': name,
        if (description != null) 'description': description,
        'frequency': frequency,
        'period_interval': periodInterval,
        'period_config': periodConfig,
        'track_date_only': trackDateOnly,
        'rollover': rollover,
        'assignment_type': assignmentType,
        if (category != null) 'category': category,
      };
}

class UpdateChoreTemplateRequest {
  final String? name;
  final String? description;

  const UpdateChoreTemplateRequest({this.name, this.description});

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      };
}

class ChoreLoadEntry {
  final String userId;
  final int completedCount;

  const ChoreLoadEntry({required this.userId, required this.completedCount});

  factory ChoreLoadEntry.fromJson(Map<String, dynamic> json) => ChoreLoadEntry(
        userId: json['user_id'] as String,
        completedCount: json['completed_count'] as int? ?? 0,
      );
}

class SkipChoreRequest {
  final String? skipReason;
  const SkipChoreRequest({this.skipReason});
  Map<String, dynamic> toJson() => {
        if (skipReason != null) 'skip_reason': skipReason,
      };
}

class ChoreSubtask {
  final String id;
  final String choreId;
  final String title;
  final bool completed;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChoreSubtask({
    required this.id,
    required this.choreId,
    required this.title,
    this.completed = false,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChoreSubtask.fromJson(Map<String, dynamic> json) => ChoreSubtask(
        id: json['id'] as String,
        choreId: json['chore_id'] as String,
        title: json['title'] as String,
        completed: json['completed'] as bool? ?? false,
        position: json['position'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  ChoreSubtask copyWith({
    String? id,
    String? choreId,
    String? title,
    bool? completed,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ChoreSubtask(
        id: id ?? this.id,
        choreId: choreId ?? this.choreId,
        title: title ?? this.title,
        completed: completed ?? this.completed,
        position: position ?? this.position,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class CreateSubtaskRequest {
  final String title;
  const CreateSubtaskRequest({required this.title});
  Map<String, dynamic> toJson() => {'title': title};
}

class UpdateSubtaskRequest {
  final String? title;
  final bool? completed;
  final int? position;
  const UpdateSubtaskRequest({this.title, this.completed, this.position});
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (title != null) m['title'] = title;
    if (completed != null) m['completed'] = completed;
    if (position != null) m['position'] = position;
    return m;
  }
}

class ReorderSubtasksRequest {
  final List<String> subtaskIds;
  const ReorderSubtasksRequest({required this.subtaskIds});
  Map<String, dynamic> toJson() => {'subtask_ids': subtaskIds};
}

class AddSuppliesToListRequest {
  final String listId;
  const AddSuppliesToListRequest({required this.listId});
  Map<String, dynamic> toJson() => {'list_id': listId};
}
