class LivingThing {
  final String id;
  final String groupId;
  final String name;
  final String species;
  final String? location;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LivingThing({
    required this.id, required this.groupId, required this.name,
    required this.species, this.location, this.imageUrl,
    required this.createdAt, required this.updatedAt,
  });

  factory LivingThing.fromJson(Map<String, dynamic> json) => LivingThing(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    name: json['name'] as String,
    species: json['species'] as String? ?? 'unknown',
    location: json['location'] as String?,
    imageUrl: json['image_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'group_id': groupId, 'name': name, 'species': species,
    if (location != null) 'location': location,
    if (imageUrl != null) 'image_url': imageUrl,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };
}

class CareSchedule {
  final String id;
  final String livingThingId;
  final int frequencyValue;
  final String frequencyUnit;
  final DateTime nextDue;

  const CareSchedule({
    required this.id, required this.livingThingId,
    required this.frequencyValue, required this.frequencyUnit, required this.nextDue,
  });

  factory CareSchedule.fromJson(Map<String, dynamic> json) => CareSchedule(
    id: json['id'] as String,
    livingThingId: json['living_thing_id'] as String,
    frequencyValue: json['frequency_value'] as int,
    frequencyUnit: json['frequency_unit'] as String,
    nextDue: DateTime.parse(json['next_due'] as String),
  );
}

class CreateLivingThingRequest {
  final String groupId;
  final String name;
  final String species;
  final String? location;
  final String? imageUrl;
  const CreateLivingThingRequest({
    required this.groupId, required this.name,
    this.species = 'unknown', this.location, this.imageUrl,
  });
  Map<String, dynamic> toJson() => {
    'group_id': groupId, 'name': name, 'species': species,
    if (location != null) 'location': location,
    if (imageUrl != null) 'image_url': imageUrl,
  };
}

class UpdateLivingThingRequest {
  final String? name;
  final String? species;
  final String? location;
  final String? imageUrl;

  const UpdateLivingThingRequest({this.name, this.species, this.location, this.imageUrl});

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (name != null) m['name'] = name;
    if (species != null) m['species'] = species;
    if (location != null) m['location'] = location;
    if (imageUrl != null) m['image_url'] = imageUrl;
    return m;
  }
}

class CreateCareScheduleRequest {
  final int frequencyValue;
  final String frequencyUnit;
  final DateTime nextDue;
  const CreateCareScheduleRequest({
    required this.frequencyValue, required this.frequencyUnit, required this.nextDue,
  });
  Map<String, dynamic> toJson() => {
    'frequency_value': frequencyValue, 'frequency_unit': frequencyUnit, 'next_due': nextDue.toIso8601String(),
  };
}

class LogCareRequest {
  final String? notes;
  const LogCareRequest({this.notes});
  Map<String, dynamic> toJson() => {
    if (notes != null) 'notes': notes,
  };
}
