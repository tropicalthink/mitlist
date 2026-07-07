class TemplateModel {
  final String id;
  final String groupId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TemplateModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) => TemplateModel(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class ChoreTemplateModel {
  final String id;
  final String groupId;
  final String name;
  final String rotationType;
  final String frequency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChoreTemplateModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.rotationType,
    required this.frequency,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChoreTemplateModel.fromJson(Map<String, dynamic> json) =>
      ChoreTemplateModel(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        name: json['name'] as String,
        rotationType: json['rotation_type'] as String? ?? 'none',
        frequency: json['frequency'] as String? ?? 'daily',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class CreateTemplateRequest {
  final String groupId;
  final String name;
  const CreateTemplateRequest({required this.groupId, required this.name});
  Map<String, dynamic> toJson() => {'group_id': groupId, 'name': name};
}

class UpdateTemplateRequest {
  final String? name;
  const UpdateTemplateRequest({this.name});
  Map<String, dynamic> toJson() => {if (name != null) 'name': name};
}

class ApplyTemplateRequest {
  final String listName;
  const ApplyTemplateRequest({required this.listName});
  Map<String, dynamic> toJson() => {'list_name': listName};
}

class CreateChoreTemplateRequest {
  final String groupId;
  final String name;
  final String rotationType;
  final String frequency;
  const CreateChoreTemplateRequest({
    required this.groupId,
    required this.name,
    this.rotationType = 'none',
    this.frequency = 'daily',
  });
  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'name': name,
        'rotation_type': rotationType,
        'frequency': frequency,
      };
}

class UpdateChoreTemplateRequest {
  final String? name;
  final String? rotationType;
  final String? frequency;
  const UpdateChoreTemplateRequest(
      {this.name, this.rotationType, this.frequency});
  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (rotationType != null) 'rotation_type': rotationType,
        if (frequency != null) 'frequency': frequency,
      };
}
