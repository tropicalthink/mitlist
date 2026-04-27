class ItemList {
  final String id;
  final String groupId;
  final String name;
  final String type;
  final int? itemCount;

  /// First lines from the list (hub card preview), from API `item_preview`.
  final List<String> itemPreview;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemList({
    required this.id,
    required this.groupId,
    required this.name,
    required this.type,
    this.itemCount,
    this.itemPreview = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItemList.fromJson(Map<String, dynamic> json) {
    final rawPreview = json['item_preview'];
    List<String> preview = const [];
    if (rawPreview is List) {
      preview = rawPreview.map((e) => e.toString()).toList();
    }
    return ItemList(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'shopping',
      itemCount: json['item_count'] as int?,
      itemPreview: preview,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'name': name,
        'type': type,
        if (itemCount != null) 'item_count': itemCount,
        if (itemPreview.isNotEmpty) 'item_preview': itemPreview,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ListItem {
  final String id;
  final String listId;
  final String name;
  final double quantity;
  final String unit;
  final String note;
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
    this.note = '',
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
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String? ?? '',
      note: json['note'] as String? ?? '',
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
        if (note.isNotEmpty) 'note': note,
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
  const CreateListRequest(
      {required this.groupId, required this.name, this.type = 'shopping'});
  Map<String, dynamic> toJson() =>
      {'group_id': groupId, 'name': name, 'type': type};
}

class UpdateListRequest {
  final String? name;
  final String? type;

  const UpdateListRequest({this.name, this.type});

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (name != null) m['name'] = name;
    if (type != null) m['type'] = type;
    return m;
  }
}

class CreateListItemRequest {
  final String name;
  final double quantity;
  final String unit;
  final String note;
  const CreateListItemRequest(
      {required this.name, this.quantity = 1, this.unit = '', this.note = ''});
  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        if (note.isNotEmpty) 'note': note
      };
}

class UpdateListItemRequest {
  final String? name;
  final double? quantity;
  final String? unit;
  final String? note;
  final bool? checked;
  final int? position;
  const UpdateListItemRequest(
      {this.name,
      this.quantity,
      this.unit,
      this.note,
      this.checked,
      this.position});
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (name != null) m['name'] = name;
    if (quantity != null) m['quantity'] = quantity;
    if (unit != null) m['unit'] = unit;
    if (note != null) m['note'] = note;
    if (checked != null) m['checked'] = checked;
    if (position != null) m['position'] = position;
    return m;
  }
}

class AddListItemAmountRequest {
  final String name;
  final double amount;
  final String unit;
  final String note;

  const AddListItemAmountRequest({
    required this.name,
    this.amount = 1,
    this.unit = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        if (note.isNotEmpty) 'note': note,
      };
}

class RemoveListItemAmountRequest {
  final String name;
  final double amount;
  final String unit;

  const RemoveListItemAmountRequest({
    required this.name,
    this.amount = 1,
    this.unit = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
      };
}

class ReorderItemsRequest {
  final List<String> itemIds;
  const ReorderItemsRequest({required this.itemIds});
  Map<String, dynamic> toJson() => {'item_ids': itemIds};
}
