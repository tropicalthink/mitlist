class Chore {
  final String id;
  final String groupId;
  final String name;
  final String? description;
  final String rotationType;
  final String frequency;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Chore({
    required this.id, required this.groupId, required this.name,
    this.description, required this.rotationType, required this.frequency,
    required this.isActive, required this.createdAt, required this.updatedAt,
  });

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    rotationType: json['rotation_type'] as String? ?? 'none',
    frequency: json['frequency'] as String? ?? 'daily',
    isActive: json['is_active'] as bool? ?? true,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'group_id': groupId, 'name': name,
    if (description != null) 'description': description,
    'rotation_type': rotationType, 'frequency': frequency, 'is_active': isActive,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };
}

class CreateChoreRequest {
  final String groupId;
  final String name;
  final String? description;
  final String rotationType;
  final String frequency;
  final bool isActive;
  const CreateChoreRequest({
    required this.groupId, required this.name, this.description,
    this.rotationType = 'none', this.frequency = 'daily', this.isActive = true,
  });
  Map<String, dynamic> toJson() => {
    'group_id': groupId, 'name': name,
    if (description != null) 'description': description,
    'rotation_type': rotationType, 'frequency': frequency, 'is_active': isActive,
  };
}

class UpdateChoreRequest {
  final String? name;
  final String? description;
  final String? rotationType;
  final String? frequency;
  final bool? isActive;

  const UpdateChoreRequest({
    this.name,
    this.description,
    this.rotationType,
    this.frequency,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (name != null) m['name'] = name;
    if (description != null) m['description'] = description;
    if (rotationType != null) m['rotation_type'] = rotationType;
    if (frequency != null) m['frequency'] = frequency;
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

  factory ChoreAssignment.fromJson(Map<String, dynamic> json) => ChoreAssignment(
        id: json['id'] as String,
        choreId: json['chore_id'] as String,
        userId: json['user_id'] as String,
        status: json['status'] as String? ?? 'pending',
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        assignedAt: DateTime.parse(json['assigned_at'] as String),
        completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      );
}
