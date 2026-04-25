class ItemList {
  final String id;
  final String groupId;
  final String name;
  final String type;
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemList({
    required this.id,
    required this.groupId,
    required this.name,
    required this.type,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItemList.fromJson(Map<String, dynamic> json) {
    return ItemList(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'shopping',
      itemCount: json['item_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'group_id': groupId,
    'name': name,
    'type': type,
    'item_count': itemCount,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class ListItem {
  final String id;
  final String listId;
  final String name;
  final int quantity;
  final String unit;
  final bool checked;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ListItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.checked,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ListItem.fromJson(Map<String, dynamic> json) {
    return ListItem(
      id: json['id'] as String,
      listId: json['list_id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int? ?? 1,
      unit: json['unit'] as String? ?? '',
      checked: json['checked'] as bool? ?? false,
      position: json['position'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'list_id': listId,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'checked': checked,
    'position': position,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class CreateListRequest {
  final String groupId;
  final String name;
  final String type;
  const CreateListRequest({required this.groupId, required this.name, this.type = 'shopping'});
  Map<String, dynamic> toJson() => {'group_id': groupId, 'name': name, 'type': type};
}

class CreateListItemRequest {
  final String name;
  final int quantity;
  final String unit;
  const CreateListItemRequest({required this.name, this.quantity = 1, this.unit = ''});
  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity, 'unit': unit};
}

class UpdateListItemRequest {
  final String? name;
  final int? quantity;
  final String? unit;
  final bool? checked;
  final int? position;
  const UpdateListItemRequest({this.name, this.quantity, this.unit, this.checked, this.position});
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (name != null) m['name'] = name;
    if (quantity != null) m['quantity'] = quantity;
    if (unit != null) m['unit'] = unit;
    if (checked != null) m['checked'] = checked;
    if (position != null) m['position'] = position;
    return m;
  }
}

class ReorderItemsRequest {
  final List<String> itemIds;
  const ReorderItemsRequest({required this.itemIds});
  Map<String, dynamic> toJson() => {'item_ids': itemIds};
}
