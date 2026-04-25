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
    'id': id, 'group_id': groupId, 'name': name, 'description': description,
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
    'group_id': groupId, 'name': name, 'description': description,
    'rotation_type': rotationType, 'frequency': frequency, 'is_active': isActive,
  };
}

class CompleteChoreRequest {
  final String? notes;
  const CompleteChoreRequest({this.notes});
  Map<String, dynamic> toJson() => {'notes': notes};
}
