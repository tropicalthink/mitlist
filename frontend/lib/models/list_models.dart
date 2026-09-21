import '../utils/uuid_validation.dart';

class ItemList {
  final String id;
  final String groupId;
  final String name;
  final String type;
  final int? itemCount;
  final bool isArchived;
  final DateTime? archivedAt;

  /// One-time household reminder for this list (server `remind_at`).
  /// [reminderSentAt] is set once the reminder was delivered.
  final DateTime? remindAt;
  final DateTime? reminderSentAt;

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
    this.isArchived = false,
    this.archivedAt,
    this.remindAt,
    this.reminderSentAt,
    this.itemPreview = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// True while a reminder is scheduled and has not been delivered yet.
  bool get hasPendingReminder => remindAt != null && reminderSentAt == null;

  factory ItemList.fromJson(Map<String, dynamic> json) {
    final rawPreview = json['item_preview'];
    List<String> preview = const [];
    if (rawPreview is List) {
      preview = rawPreview.whereType<String>().toList();
    }
    final archivedAtRaw = json['archived_at'];
    final remindAtRaw = json['remind_at'];
    final reminderSentAtRaw = json['reminder_sent_at'];
    return ItemList(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'shopping',
      itemCount: json['item_count'] as int?,
      isArchived: json['archived_at'] != null,
      archivedAt: archivedAtRaw != null
          ? DateTime.parse(archivedAtRaw as String)
          : null,
      remindAt:
          remindAtRaw is String ? DateTime.parse(remindAtRaw).toLocal() : null,
      reminderSentAt: reminderSentAtRaw is String
          ? DateTime.parse(reminderSentAtRaw).toLocal()
          : null,
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
        if (remindAt != null) 'remind_at': remindAt!.toUtc().toIso8601String(),
        if (reminderSentAt != null)
          'reminder_sent_at': reminderSentAt!.toUtc().toIso8601String(),
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
  final int? priceCents;
  final String? canonicalItemId;
  final bool checked;
  final int position;
  final String? claimedBy;

  /// Household member who put the item on the list; null for rows that
  /// predate the column or arrived without one. Rendered as the "added by"
  /// line so a shared list shows who asked for what.
  final String? addedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ListItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.note = '',
    this.priceCents,
    this.canonicalItemId,
    required this.checked,
    required this.position,
    this.claimedBy,
    this.addedBy,
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
      priceCents: json['price_cents'] as int?,
      canonicalItemId: json['canonical_item_id'] as String?,
      checked: json['checked'] as bool? ?? false,
      position: json['position'] as int? ?? 0,
      claimedBy: json['claimed_by'] as String?,
      addedBy: json['added_by'] as String?,
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
        if (priceCents != null) 'price_cents': priceCents,
        if (canonicalItemId != null) 'canonical_item_id': canonicalItemId,
        'checked': checked,
        'position': position,
        if (addedBy != null) 'added_by': addedBy,
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
  final int? priceCents;
  final String? canonicalItemId;
  const CreateListItemRequest(
      {required this.name,
      this.quantity = 1,
      this.unit = '',
      this.note = '',
      this.priceCents,
      this.canonicalItemId});
  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        if (note.isNotEmpty) 'note': note,
        if (priceCents != null) 'price_cents': priceCents,
        if (isApiUuid(canonicalItemId)) 'canonical_item_id': canonicalItemId,
      };
}

class UpdateListItemRequest {
  final String? name;
  final double? quantity;
  final String? unit;
  final String? note;
  final int? priceCents;
  final bool? checked;
  final int? position;

  /// The `updated_at` the edit was based on, for optimistic concurrency. When
  /// set, the server returns 409 (with its current state) if the row moved on
  /// since — so a concurrent edit is detected instead of silently clobbered.
  final String? expectedUpdatedAt;

  const UpdateListItemRequest(
      {this.name,
      this.quantity,
      this.unit,
      this.note,
      this.priceCents,
      this.checked,
      this.position,
      this.expectedUpdatedAt});
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (name != null) m['name'] = name;
    if (quantity != null) m['quantity'] = quantity;
    if (unit != null) m['unit'] = unit;
    if (note != null) m['note'] = note;
    if (priceCents != null) m['price_cents'] = priceCents;
    if (checked != null) m['checked'] = checked;
    if (position != null) m['position'] = position;
    if (expectedUpdatedAt != null) m['expected_updated_at'] = expectedUpdatedAt;
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

class ShoppingLocation {
  final String id;
  final String groupId;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingLocation({
    required this.id,
    required this.groupId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingLocation.fromJson(Map<String, dynamic> json) =>
      ShoppingLocation(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        name: json['name'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class Product {
  final String id;
  final String groupId;
  final String name;
  final String barcode;
  final String unit;
  final String? storeId;
  final double minStock;
  final double inStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.groupId,
    required this.name,
    this.barcode = '',
    this.unit = '',
    this.storeId,
    this.minStock = 0,
    this.inStock = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        name: json['name'] as String,
        barcode: json['barcode'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        storeId: json['store_id'] as String?,
        minStock: (json['min_stock'] as num?)?.toDouble() ?? 0,
        inStock: (json['in_stock'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class CreateShoppingLocationRequest {
  final String groupId;
  final String name;
  final int sortOrder;

  const CreateShoppingLocationRequest({
    required this.groupId,
    required this.name,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() =>
      {'group_id': groupId, 'name': name, 'sort_order': sortOrder};
}

class CreateProductRequest {
  final String groupId;
  final String name;
  final String barcode;
  final String unit;
  final String? storeId;
  final double minStock;
  final double inStock;

  const CreateProductRequest({
    required this.groupId,
    required this.name,
    this.barcode = '',
    this.unit = '',
    this.storeId,
    this.minStock = 0,
    this.inStock = 0,
  });

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'name': name,
        'barcode': barcode,
        'unit': unit,
        if (storeId != null) 'store_id': storeId,
        'min_stock': minStock,
        'in_stock': inStock,
      };
}
