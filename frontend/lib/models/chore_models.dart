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
      };
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

  const ChoreAssignment({
    required this.id,
    required this.choreId,
    required this.userId,
    required this.status,
    required this.dueDate,
    required this.assignedAt,
    required this.completedAt,
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
      );
}

class CurrentChore {
  final Chore chore;
  final ChoreAssignment? pendingAssignment;
  final ChoreAssignment? lastAssignment;
  final String dueStatus;
  final bool assignedToMe;

  const CurrentChore({
    required this.chore,
    this.pendingAssignment,
    this.lastAssignment,
    required this.dueStatus,
    required this.assignedToMe,
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

  const ChoreDetails({
    required this.chore,
    this.pendingAssignment,
    this.lastAssignment,
    required this.stats,
    required this.dueStatus,
    required this.assignedToMe,
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
      );
}
