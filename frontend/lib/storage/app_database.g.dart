// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ListsTableTable extends ListsTable
    with TableInfo<$ListsTableTable, ListsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemCountMeta =
      const VerificationMeta('itemCount');
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
      'item_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _itemPreviewJsonMeta =
      const VerificationMeta('itemPreviewJson');
  @override
  late final GeneratedColumn<String> itemPreviewJson = GeneratedColumn<String>(
      'item_preview_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        name,
        type,
        itemCount,
        itemPreviewJson,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lists_table';
  @override
  VerificationContext validateIntegrity(Insertable<ListsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(_itemCountMeta,
          itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta));
    }
    if (data.containsKey('item_preview_json')) {
      context.handle(
          _itemPreviewJsonMeta,
          itemPreviewJson.isAcceptableOrUnknown(
              data['item_preview_json']!, _itemPreviewJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      itemCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}item_count']),
      itemPreviewJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}item_preview_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ListsTableTable createAlias(String alias) {
    return $ListsTableTable(attachedDatabase, alias);
  }
}

class ListsTableData extends DataClass implements Insertable<ListsTableData> {
  final String id;
  final String groupId;
  final String name;
  final String type;
  final int? itemCount;
  final String itemPreviewJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ListsTableData(
      {required this.id,
      required this.groupId,
      required this.name,
      required this.type,
      this.itemCount,
      required this.itemPreviewJson,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || itemCount != null) {
      map['item_count'] = Variable<int>(itemCount);
    }
    map['item_preview_json'] = Variable<String>(itemPreviewJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ListsTableCompanion toCompanion(bool nullToAbsent) {
    return ListsTableCompanion(
      id: Value(id),
      groupId: Value(groupId),
      name: Value(name),
      type: Value(type),
      itemCount: itemCount == null && nullToAbsent
          ? const Value.absent()
          : Value(itemCount),
      itemPreviewJson: Value(itemPreviewJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ListsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListsTableData(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      itemCount: serializer.fromJson<int?>(json['itemCount']),
      itemPreviewJson: serializer.fromJson<String>(json['itemPreviewJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'itemCount': serializer.toJson<int?>(itemCount),
      'itemPreviewJson': serializer.toJson<String>(itemPreviewJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ListsTableData copyWith(
          {String? id,
          String? groupId,
          String? name,
          String? type,
          Value<int?> itemCount = const Value.absent(),
          String? itemPreviewJson,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ListsTableData(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        name: name ?? this.name,
        type: type ?? this.type,
        itemCount: itemCount.present ? itemCount.value : this.itemCount,
        itemPreviewJson: itemPreviewJson ?? this.itemPreviewJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ListsTableData copyWithCompanion(ListsTableCompanion data) {
    return ListsTableData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      itemPreviewJson: data.itemPreviewJson.present
          ? data.itemPreviewJson.value
          : this.itemPreviewJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListsTableData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('itemCount: $itemCount, ')
          ..write('itemPreviewJson: $itemPreviewJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, name, type, itemCount,
      itemPreviewJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListsTableData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.type == this.type &&
          other.itemCount == this.itemCount &&
          other.itemPreviewJson == this.itemPreviewJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ListsTableCompanion extends UpdateCompanion<ListsTableData> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> name;
  final Value<String> type;
  final Value<int?> itemCount;
  final Value<String> itemPreviewJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ListsTableCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.itemPreviewJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListsTableCompanion.insert({
    required String id,
    required String groupId,
    required String name,
    required String type,
    this.itemCount = const Value.absent(),
    this.itemPreviewJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        name = Value(name),
        type = Value(type),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ListsTableData> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? itemCount,
    Expression<String>? itemPreviewJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (itemCount != null) 'item_count': itemCount,
      if (itemPreviewJson != null) 'item_preview_json': itemPreviewJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String>? name,
      Value<String>? type,
      Value<int?>? itemCount,
      Value<String>? itemPreviewJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ListsTableCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      type: type ?? this.type,
      itemCount: itemCount ?? this.itemCount,
      itemPreviewJson: itemPreviewJson ?? this.itemPreviewJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (itemPreviewJson.present) {
      map['item_preview_json'] = Variable<String>(itemPreviewJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListsTableCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('itemCount: $itemCount, ')
          ..write('itemPreviewJson: $itemPreviewJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListItemsTableTable extends ListItemsTable
    with TableInfo<$ListItemsTableTable, ListItemsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
      'list_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _checkedMeta =
      const VerificationMeta('checked');
  @override
  late final GeneratedColumn<bool> checked = GeneratedColumn<bool>(
      'checked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("checked" IN (0, 1))'));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _priceCentsMeta =
      const VerificationMeta('priceCents');
  @override
  late final GeneratedColumn<int> priceCents = GeneratedColumn<int>(
      'price_cents', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _canonicalItemIdMeta =
      const VerificationMeta('canonicalItemId');
  @override
  late final GeneratedColumn<String> canonicalItemId = GeneratedColumn<String>(
      'canonical_item_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        listId,
        name,
        quantity,
        unit,
        checked,
        position,
        priceCents,
        canonicalItemId,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'list_items_table';
  @override
  VerificationContext validateIntegrity(Insertable<ListItemsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(_listIdMeta,
          listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta));
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('checked')) {
      context.handle(_checkedMeta,
          checked.isAcceptableOrUnknown(data['checked']!, _checkedMeta));
    } else if (isInserting) {
      context.missing(_checkedMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('price_cents')) {
      context.handle(
          _priceCentsMeta,
          priceCents.isAcceptableOrUnknown(
              data['price_cents']!, _priceCentsMeta));
    }
    if (data.containsKey('canonical_item_id')) {
      context.handle(
          _canonicalItemIdMeta,
          canonicalItemId.isAcceptableOrUnknown(
              data['canonical_item_id']!, _canonicalItemIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListItemsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListItemsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      listId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}list_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      checked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}checked'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      priceCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_cents']),
      canonicalItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}canonical_item_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ListItemsTableTable createAlias(String alias) {
    return $ListItemsTableTable(attachedDatabase, alias);
  }
}

class ListItemsTableData extends DataClass
    implements Insertable<ListItemsTableData> {
  final String id;
  final String listId;
  final String name;
  final double quantity;
  final String unit;
  final bool checked;
  final int position;
  final int? priceCents;
  final String? canonicalItemId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ListItemsTableData(
      {required this.id,
      required this.listId,
      required this.name,
      required this.quantity,
      required this.unit,
      required this.checked,
      required this.position,
      this.priceCents,
      this.canonicalItemId,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['list_id'] = Variable<String>(listId);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    map['checked'] = Variable<bool>(checked);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || priceCents != null) {
      map['price_cents'] = Variable<int>(priceCents);
    }
    if (!nullToAbsent || canonicalItemId != null) {
      map['canonical_item_id'] = Variable<String>(canonicalItemId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ListItemsTableCompanion toCompanion(bool nullToAbsent) {
    return ListItemsTableCompanion(
      id: Value(id),
      listId: Value(listId),
      name: Value(name),
      quantity: Value(quantity),
      unit: Value(unit),
      checked: Value(checked),
      position: Value(position),
      priceCents: priceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(priceCents),
      canonicalItemId: canonicalItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(canonicalItemId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ListItemsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListItemsTableData(
      id: serializer.fromJson<String>(json['id']),
      listId: serializer.fromJson<String>(json['listId']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      checked: serializer.fromJson<bool>(json['checked']),
      position: serializer.fromJson<int>(json['position']),
      priceCents: serializer.fromJson<int?>(json['priceCents']),
      canonicalItemId: serializer.fromJson<String?>(json['canonicalItemId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'listId': serializer.toJson<String>(listId),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
      'checked': serializer.toJson<bool>(checked),
      'position': serializer.toJson<int>(position),
      'priceCents': serializer.toJson<int?>(priceCents),
      'canonicalItemId': serializer.toJson<String?>(canonicalItemId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ListItemsTableData copyWith(
          {String? id,
          String? listId,
          String? name,
          double? quantity,
          String? unit,
          bool? checked,
          int? position,
          Value<int?> priceCents = const Value.absent(),
          Value<String?> canonicalItemId = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ListItemsTableData(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        checked: checked ?? this.checked,
        position: position ?? this.position,
        priceCents: priceCents.present ? priceCents.value : this.priceCents,
        canonicalItemId: canonicalItemId.present
            ? canonicalItemId.value
            : this.canonicalItemId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ListItemsTableData copyWithCompanion(ListItemsTableCompanion data) {
    return ListItemsTableData(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      checked: data.checked.present ? data.checked.value : this.checked,
      position: data.position.present ? data.position.value : this.position,
      priceCents:
          data.priceCents.present ? data.priceCents.value : this.priceCents,
      canonicalItemId: data.canonicalItemId.present
          ? data.canonicalItemId.value
          : this.canonicalItemId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListItemsTableData(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('checked: $checked, ')
          ..write('position: $position, ')
          ..write('priceCents: $priceCents, ')
          ..write('canonicalItemId: $canonicalItemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, listId, name, quantity, unit, checked,
      position, priceCents, canonicalItemId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListItemsTableData &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.checked == this.checked &&
          other.position == this.position &&
          other.priceCents == this.priceCents &&
          other.canonicalItemId == this.canonicalItemId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ListItemsTableCompanion extends UpdateCompanion<ListItemsTableData> {
  final Value<String> id;
  final Value<String> listId;
  final Value<String> name;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<bool> checked;
  final Value<int> position;
  final Value<int?> priceCents;
  final Value<String?> canonicalItemId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ListItemsTableCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.checked = const Value.absent(),
    this.position = const Value.absent(),
    this.priceCents = const Value.absent(),
    this.canonicalItemId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListItemsTableCompanion.insert({
    required String id,
    required String listId,
    required String name,
    required double quantity,
    required String unit,
    required bool checked,
    required int position,
    this.priceCents = const Value.absent(),
    this.canonicalItemId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        listId = Value(listId),
        name = Value(name),
        quantity = Value(quantity),
        unit = Value(unit),
        checked = Value(checked),
        position = Value(position),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ListItemsTableData> custom({
    Expression<String>? id,
    Expression<String>? listId,
    Expression<String>? name,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<bool>? checked,
    Expression<int>? position,
    Expression<int>? priceCents,
    Expression<String>? canonicalItemId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (checked != null) 'checked': checked,
      if (position != null) 'position': position,
      if (priceCents != null) 'price_cents': priceCents,
      if (canonicalItemId != null) 'canonical_item_id': canonicalItemId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListItemsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? listId,
      Value<String>? name,
      Value<double>? quantity,
      Value<String>? unit,
      Value<bool>? checked,
      Value<int>? position,
      Value<int?>? priceCents,
      Value<String?>? canonicalItemId,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ListItemsTableCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      checked: checked ?? this.checked,
      position: position ?? this.position,
      priceCents: priceCents ?? this.priceCents,
      canonicalItemId: canonicalItemId ?? this.canonicalItemId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (checked.present) {
      map['checked'] = Variable<bool>(checked.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (priceCents.present) {
      map['price_cents'] = Variable<int>(priceCents.value);
    }
    if (canonicalItemId.present) {
      map['canonical_item_id'] = Variable<String>(canonicalItemId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListItemsTableCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('checked: $checked, ')
          ..write('position: $position, ')
          ..write('priceCents: $priceCents, ')
          ..write('canonicalItemId: $canonicalItemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTableTable extends ExpensesTable
    with TableInfo<$ExpensesTableTable, ExpensesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payerIdMeta =
      const VerificationMeta('payerId');
  @override
  late final GeneratedColumn<String> payerId = GeneratedColumn<String>(
      'payer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
      'amount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _baseAmountMeta =
      const VerificationMeta('baseAmount');
  @override
  late final GeneratedColumn<int> baseAmount = GeneratedColumn<int>(
      'base_amount', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _fxRateMeta = const VerificationMeta('fxRate');
  @override
  late final GeneratedColumn<double> fxRate = GeneratedColumn<double>(
      'fx_rate', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        payerId,
        amount,
        baseAmount,
        fxRate,
        description,
        category,
        currency,
        notes,
        date,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses_table';
  @override
  VerificationContext validateIntegrity(Insertable<ExpensesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('payer_id')) {
      context.handle(_payerIdMeta,
          payerId.isAcceptableOrUnknown(data['payer_id']!, _payerIdMeta));
    } else if (isInserting) {
      context.missing(_payerIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('base_amount')) {
      context.handle(
          _baseAmountMeta,
          baseAmount.isAcceptableOrUnknown(
              data['base_amount']!, _baseAmountMeta));
    }
    if (data.containsKey('fx_rate')) {
      context.handle(_fxRateMeta,
          fxRate.isAcceptableOrUnknown(data['fx_rate']!, _fxRateMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpensesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpensesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      payerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payer_id'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount'])!,
      baseAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}base_amount'])!,
      fxRate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fx_rate'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $ExpensesTableTable createAlias(String alias) {
    return $ExpensesTableTable(attachedDatabase, alias);
  }
}

class ExpensesTableData extends DataClass
    implements Insertable<ExpensesTableData> {
  final String id;
  final String groupId;
  final String payerId;
  final int amount;
  final int baseAmount;
  final double fxRate;
  final String description;
  final String category;
  final String currency;
  final String notes;
  final DateTime date;
  final DateTime createdAt;

  /// Server last-modified stamp, kept as the optimistic-concurrency base for
  /// offline edits. Nullable: rows created locally have no server version yet,
  /// and rows cached before this column existed have none either.
  final DateTime? updatedAt;
  const ExpensesTableData(
      {required this.id,
      required this.groupId,
      required this.payerId,
      required this.amount,
      required this.baseAmount,
      required this.fxRate,
      required this.description,
      required this.category,
      required this.currency,
      required this.notes,
      required this.date,
      required this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['payer_id'] = Variable<String>(payerId);
    map['amount'] = Variable<int>(amount);
    map['base_amount'] = Variable<int>(baseAmount);
    map['fx_rate'] = Variable<double>(fxRate);
    map['description'] = Variable<String>(description);
    map['category'] = Variable<String>(category);
    map['currency'] = Variable<String>(currency);
    map['notes'] = Variable<String>(notes);
    map['date'] = Variable<DateTime>(date);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  ExpensesTableCompanion toCompanion(bool nullToAbsent) {
    return ExpensesTableCompanion(
      id: Value(id),
      groupId: Value(groupId),
      payerId: Value(payerId),
      amount: Value(amount),
      baseAmount: Value(baseAmount),
      fxRate: Value(fxRate),
      description: Value(description),
      category: Value(category),
      currency: Value(currency),
      notes: Value(notes),
      date: Value(date),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory ExpensesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpensesTableData(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      payerId: serializer.fromJson<String>(json['payerId']),
      amount: serializer.fromJson<int>(json['amount']),
      baseAmount: serializer.fromJson<int>(json['baseAmount']),
      fxRate: serializer.fromJson<double>(json['fxRate']),
      description: serializer.fromJson<String>(json['description']),
      category: serializer.fromJson<String>(json['category']),
      currency: serializer.fromJson<String>(json['currency']),
      notes: serializer.fromJson<String>(json['notes']),
      date: serializer.fromJson<DateTime>(json['date']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'payerId': serializer.toJson<String>(payerId),
      'amount': serializer.toJson<int>(amount),
      'baseAmount': serializer.toJson<int>(baseAmount),
      'fxRate': serializer.toJson<double>(fxRate),
      'description': serializer.toJson<String>(description),
      'category': serializer.toJson<String>(category),
      'currency': serializer.toJson<String>(currency),
      'notes': serializer.toJson<String>(notes),
      'date': serializer.toJson<DateTime>(date),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  ExpensesTableData copyWith(
          {String? id,
          String? groupId,
          String? payerId,
          int? amount,
          int? baseAmount,
          double? fxRate,
          String? description,
          String? category,
          String? currency,
          String? notes,
          DateTime? date,
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      ExpensesTableData(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        payerId: payerId ?? this.payerId,
        amount: amount ?? this.amount,
        baseAmount: baseAmount ?? this.baseAmount,
        fxRate: fxRate ?? this.fxRate,
        description: description ?? this.description,
        category: category ?? this.category,
        currency: currency ?? this.currency,
        notes: notes ?? this.notes,
        date: date ?? this.date,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  ExpensesTableData copyWithCompanion(ExpensesTableCompanion data) {
    return ExpensesTableData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      payerId: data.payerId.present ? data.payerId.value : this.payerId,
      amount: data.amount.present ? data.amount.value : this.amount,
      baseAmount:
          data.baseAmount.present ? data.baseAmount.value : this.baseAmount,
      fxRate: data.fxRate.present ? data.fxRate.value : this.fxRate,
      description:
          data.description.present ? data.description.value : this.description,
      category: data.category.present ? data.category.value : this.category,
      currency: data.currency.present ? data.currency.value : this.currency,
      notes: data.notes.present ? data.notes.value : this.notes,
      date: data.date.present ? data.date.value : this.date,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesTableData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('payerId: $payerId, ')
          ..write('amount: $amount, ')
          ..write('baseAmount: $baseAmount, ')
          ..write('fxRate: $fxRate, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('currency: $currency, ')
          ..write('notes: $notes, ')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      groupId,
      payerId,
      amount,
      baseAmount,
      fxRate,
      description,
      category,
      currency,
      notes,
      date,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpensesTableData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.payerId == this.payerId &&
          other.amount == this.amount &&
          other.baseAmount == this.baseAmount &&
          other.fxRate == this.fxRate &&
          other.description == this.description &&
          other.category == this.category &&
          other.currency == this.currency &&
          other.notes == this.notes &&
          other.date == this.date &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ExpensesTableCompanion extends UpdateCompanion<ExpensesTableData> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> payerId;
  final Value<int> amount;
  final Value<int> baseAmount;
  final Value<double> fxRate;
  final Value<String> description;
  final Value<String> category;
  final Value<String> currency;
  final Value<String> notes;
  final Value<DateTime> date;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const ExpensesTableCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.payerId = const Value.absent(),
    this.amount = const Value.absent(),
    this.baseAmount = const Value.absent(),
    this.fxRate = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.currency = const Value.absent(),
    this.notes = const Value.absent(),
    this.date = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesTableCompanion.insert({
    required String id,
    required String groupId,
    required String payerId,
    required int amount,
    this.baseAmount = const Value.absent(),
    this.fxRate = const Value.absent(),
    required String description,
    required String category,
    required String currency,
    required String notes,
    required DateTime date,
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        payerId = Value(payerId),
        amount = Value(amount),
        description = Value(description),
        category = Value(category),
        currency = Value(currency),
        notes = Value(notes),
        date = Value(date),
        createdAt = Value(createdAt);
  static Insertable<ExpensesTableData> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? payerId,
    Expression<int>? amount,
    Expression<int>? baseAmount,
    Expression<double>? fxRate,
    Expression<String>? description,
    Expression<String>? category,
    Expression<String>? currency,
    Expression<String>? notes,
    Expression<DateTime>? date,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (payerId != null) 'payer_id': payerId,
      if (amount != null) 'amount': amount,
      if (baseAmount != null) 'base_amount': baseAmount,
      if (fxRate != null) 'fx_rate': fxRate,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (currency != null) 'currency': currency,
      if (notes != null) 'notes': notes,
      if (date != null) 'date': date,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String>? payerId,
      Value<int>? amount,
      Value<int>? baseAmount,
      Value<double>? fxRate,
      Value<String>? description,
      Value<String>? category,
      Value<String>? currency,
      Value<String>? notes,
      Value<DateTime>? date,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<int>? rowid}) {
    return ExpensesTableCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      payerId: payerId ?? this.payerId,
      amount: amount ?? this.amount,
      baseAmount: baseAmount ?? this.baseAmount,
      fxRate: fxRate ?? this.fxRate,
      description: description ?? this.description,
      category: category ?? this.category,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (payerId.present) {
      map['payer_id'] = Variable<String>(payerId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (baseAmount.present) {
      map['base_amount'] = Variable<int>(baseAmount.value);
    }
    if (fxRate.present) {
      map['fx_rate'] = Variable<double>(fxRate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesTableCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('payerId: $payerId, ')
          ..write('amount: $amount, ')
          ..write('baseAmount: $baseAmount, ')
          ..write('fxRate: $fxRate, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('currency: $currency, ')
          ..write('notes: $notes, ')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FinanceSummariesTable extends FinanceSummaries
    with TableInfo<$FinanceSummariesTable, FinanceSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FinanceSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _summaryJsonMeta =
      const VerificationMeta('summaryJson');
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
      'summary_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [groupId, summaryJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'finance_summaries';
  @override
  VerificationContext validateIntegrity(Insertable<FinanceSummary> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
          _summaryJsonMeta,
          summaryJson.isAcceptableOrUnknown(
              data['summary_json']!, _summaryJsonMeta));
    } else if (isInserting) {
      context.missing(_summaryJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  FinanceSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FinanceSummary(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      summaryJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $FinanceSummariesTable createAlias(String alias) {
    return $FinanceSummariesTable(attachedDatabase, alias);
  }
}

class FinanceSummary extends DataClass implements Insertable<FinanceSummary> {
  final String groupId;
  final String summaryJson;
  final DateTime updatedAt;
  const FinanceSummary(
      {required this.groupId,
      required this.summaryJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['summary_json'] = Variable<String>(summaryJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FinanceSummariesCompanion toCompanion(bool nullToAbsent) {
    return FinanceSummariesCompanion(
      groupId: Value(groupId),
      summaryJson: Value(summaryJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory FinanceSummary.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FinanceSummary(
      groupId: serializer.fromJson<String>(json['groupId']),
      summaryJson: serializer.fromJson<String>(json['summaryJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'summaryJson': serializer.toJson<String>(summaryJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FinanceSummary copyWith(
          {String? groupId, String? summaryJson, DateTime? updatedAt}) =>
      FinanceSummary(
        groupId: groupId ?? this.groupId,
        summaryJson: summaryJson ?? this.summaryJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  FinanceSummary copyWithCompanion(FinanceSummariesCompanion data) {
    return FinanceSummary(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      summaryJson:
          data.summaryJson.present ? data.summaryJson.value : this.summaryJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FinanceSummary(')
          ..write('groupId: $groupId, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, summaryJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FinanceSummary &&
          other.groupId == this.groupId &&
          other.summaryJson == this.summaryJson &&
          other.updatedAt == this.updatedAt);
}

class FinanceSummariesCompanion extends UpdateCompanion<FinanceSummary> {
  final Value<String> groupId;
  final Value<String> summaryJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FinanceSummariesCompanion({
    this.groupId = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FinanceSummariesCompanion.insert({
    required String groupId,
    required String summaryJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        summaryJson = Value(summaryJson),
        updatedAt = Value(updatedAt);
  static Insertable<FinanceSummary> custom({
    Expression<String>? groupId,
    Expression<String>? summaryJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FinanceSummariesCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? summaryJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return FinanceSummariesCompanion(
      groupId: groupId ?? this.groupId,
      summaryJson: summaryJson ?? this.summaryJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FinanceSummariesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CurrentChoresCachesTable extends CurrentChoresCaches
    with TableInfo<$CurrentChoresCachesTable, CurrentChoresCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurrentChoresCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _choresJsonMeta =
      const VerificationMeta('choresJson');
  @override
  late final GeneratedColumn<String> choresJson = GeneratedColumn<String>(
      'chores_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [groupId, choresJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'current_chores_caches';
  @override
  VerificationContext validateIntegrity(Insertable<CurrentChoresCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('chores_json')) {
      context.handle(
          _choresJsonMeta,
          choresJson.isAcceptableOrUnknown(
              data['chores_json']!, _choresJsonMeta));
    } else if (isInserting) {
      context.missing(_choresJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  CurrentChoresCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurrentChoresCache(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      choresJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chores_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CurrentChoresCachesTable createAlias(String alias) {
    return $CurrentChoresCachesTable(attachedDatabase, alias);
  }
}

class CurrentChoresCache extends DataClass
    implements Insertable<CurrentChoresCache> {
  final String groupId;
  final String choresJson;
  final DateTime updatedAt;
  const CurrentChoresCache(
      {required this.groupId,
      required this.choresJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['chores_json'] = Variable<String>(choresJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CurrentChoresCachesCompanion toCompanion(bool nullToAbsent) {
    return CurrentChoresCachesCompanion(
      groupId: Value(groupId),
      choresJson: Value(choresJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory CurrentChoresCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurrentChoresCache(
      groupId: serializer.fromJson<String>(json['groupId']),
      choresJson: serializer.fromJson<String>(json['choresJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'choresJson': serializer.toJson<String>(choresJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CurrentChoresCache copyWith(
          {String? groupId, String? choresJson, DateTime? updatedAt}) =>
      CurrentChoresCache(
        groupId: groupId ?? this.groupId,
        choresJson: choresJson ?? this.choresJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CurrentChoresCache copyWithCompanion(CurrentChoresCachesCompanion data) {
    return CurrentChoresCache(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      choresJson:
          data.choresJson.present ? data.choresJson.value : this.choresJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurrentChoresCache(')
          ..write('groupId: $groupId, ')
          ..write('choresJson: $choresJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, choresJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurrentChoresCache &&
          other.groupId == this.groupId &&
          other.choresJson == this.choresJson &&
          other.updatedAt == this.updatedAt);
}

class CurrentChoresCachesCompanion extends UpdateCompanion<CurrentChoresCache> {
  final Value<String> groupId;
  final Value<String> choresJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CurrentChoresCachesCompanion({
    this.groupId = const Value.absent(),
    this.choresJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurrentChoresCachesCompanion.insert({
    required String groupId,
    required String choresJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        choresJson = Value(choresJson),
        updatedAt = Value(updatedAt);
  static Insertable<CurrentChoresCache> custom({
    Expression<String>? groupId,
    Expression<String>? choresJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (choresJson != null) 'chores_json': choresJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurrentChoresCachesCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? choresJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CurrentChoresCachesCompanion(
      groupId: groupId ?? this.groupId,
      choresJson: choresJson ?? this.choresJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (choresJson.present) {
      map['chores_json'] = Variable<String>(choresJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrentChoresCachesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('choresJson: $choresJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipesTableTable extends RecipesTable
    with TableInfo<$RecipesTableTable, RecipesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _prepTimeMeta =
      const VerificationMeta('prepTime');
  @override
  late final GeneratedColumn<int> prepTime = GeneratedColumn<int>(
      'prep_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cookTimeMeta =
      const VerificationMeta('cookTime');
  @override
  late final GeneratedColumn<int> cookTime = GeneratedColumn<int>(
      'cook_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _servingsMeta =
      const VerificationMeta('servings');
  @override
  late final GeneratedColumn<int> servings = GeneratedColumn<int>(
      'servings', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _visibilityMeta =
      const VerificationMeta('visibility');
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
      'visibility', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('private'));
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagsJsonMeta =
      const VerificationMeta('tagsJson');
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
      'tags_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        description,
        prepTime,
        cookTime,
        servings,
        imageUrl,
        visibility,
        groupId,
        tagsJson,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes_table';
  @override
  VerificationContext validateIntegrity(Insertable<RecipesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('prep_time')) {
      context.handle(_prepTimeMeta,
          prepTime.isAcceptableOrUnknown(data['prep_time']!, _prepTimeMeta));
    } else if (isInserting) {
      context.missing(_prepTimeMeta);
    }
    if (data.containsKey('cook_time')) {
      context.handle(_cookTimeMeta,
          cookTime.isAcceptableOrUnknown(data['cook_time']!, _cookTimeMeta));
    } else if (isInserting) {
      context.missing(_cookTimeMeta);
    }
    if (data.containsKey('servings')) {
      context.handle(_servingsMeta,
          servings.isAcceptableOrUnknown(data['servings']!, _servingsMeta));
    } else if (isInserting) {
      context.missing(_servingsMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('visibility')) {
      context.handle(
          _visibilityMeta,
          visibility.isAcceptableOrUnknown(
              data['visibility']!, _visibilityMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    }
    if (data.containsKey('tags_json')) {
      context.handle(_tagsJsonMeta,
          tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      prepTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}prep_time'])!,
      cookTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cook_time'])!,
      servings: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}servings'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      visibility: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}visibility'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id']),
      tagsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RecipesTableTable createAlias(String alias) {
    return $RecipesTableTable(attachedDatabase, alias);
  }
}

class RecipesTableData extends DataClass
    implements Insertable<RecipesTableData> {
  final String id;
  final String title;
  final String description;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String? imageUrl;

  /// 'private' or 'household'. Replaces the old is_public boolean, which the
  /// server dropped in migration 000058.
  final String visibility;

  /// The household a 'household' recipe is shared with, else null.
  final String? groupId;

  /// Tags as a JSON array. The cache used to drop them entirely, so any recipe
  /// served from here came back untagged and the offline edit path could not
  /// touch them.
  final String tagsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RecipesTableData(
      {required this.id,
      required this.title,
      required this.description,
      required this.prepTime,
      required this.cookTime,
      required this.servings,
      this.imageUrl,
      required this.visibility,
      this.groupId,
      required this.tagsJson,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['prep_time'] = Variable<int>(prepTime);
    map['cook_time'] = Variable<int>(cookTime);
    map['servings'] = Variable<int>(servings);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['visibility'] = Variable<String>(visibility);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    map['tags_json'] = Variable<String>(tagsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecipesTableCompanion toCompanion(bool nullToAbsent) {
    return RecipesTableCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      prepTime: Value(prepTime),
      cookTime: Value(cookTime),
      servings: Value(servings),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      visibility: Value(visibility),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      tagsJson: Value(tagsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecipesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipesTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      prepTime: serializer.fromJson<int>(json['prepTime']),
      cookTime: serializer.fromJson<int>(json['cookTime']),
      servings: serializer.fromJson<int>(json['servings']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      visibility: serializer.fromJson<String>(json['visibility']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'prepTime': serializer.toJson<int>(prepTime),
      'cookTime': serializer.toJson<int>(cookTime),
      'servings': serializer.toJson<int>(servings),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'visibility': serializer.toJson<String>(visibility),
      'groupId': serializer.toJson<String?>(groupId),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecipesTableData copyWith(
          {String? id,
          String? title,
          String? description,
          int? prepTime,
          int? cookTime,
          int? servings,
          Value<String?> imageUrl = const Value.absent(),
          String? visibility,
          Value<String?> groupId = const Value.absent(),
          String? tagsJson,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      RecipesTableData(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        prepTime: prepTime ?? this.prepTime,
        cookTime: cookTime ?? this.cookTime,
        servings: servings ?? this.servings,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        visibility: visibility ?? this.visibility,
        groupId: groupId.present ? groupId.value : this.groupId,
        tagsJson: tagsJson ?? this.tagsJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  RecipesTableData copyWithCompanion(RecipesTableCompanion data) {
    return RecipesTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      prepTime: data.prepTime.present ? data.prepTime.value : this.prepTime,
      cookTime: data.cookTime.present ? data.cookTime.value : this.cookTime,
      servings: data.servings.present ? data.servings.value : this.servings,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      visibility:
          data.visibility.present ? data.visibility.value : this.visibility,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipesTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('prepTime: $prepTime, ')
          ..write('cookTime: $cookTime, ')
          ..write('servings: $servings, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('visibility: $visibility, ')
          ..write('groupId: $groupId, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, description, prepTime, cookTime,
      servings, imageUrl, visibility, groupId, tagsJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipesTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.prepTime == this.prepTime &&
          other.cookTime == this.cookTime &&
          other.servings == this.servings &&
          other.imageUrl == this.imageUrl &&
          other.visibility == this.visibility &&
          other.groupId == this.groupId &&
          other.tagsJson == this.tagsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecipesTableCompanion extends UpdateCompanion<RecipesTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> description;
  final Value<int> prepTime;
  final Value<int> cookTime;
  final Value<int> servings;
  final Value<String?> imageUrl;
  final Value<String> visibility;
  final Value<String?> groupId;
  final Value<String> tagsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RecipesTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.prepTime = const Value.absent(),
    this.cookTime = const Value.absent(),
    this.servings = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.visibility = const Value.absent(),
    this.groupId = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipesTableCompanion.insert({
    required String id,
    required String title,
    required String description,
    required int prepTime,
    required int cookTime,
    required int servings,
    this.imageUrl = const Value.absent(),
    this.visibility = const Value.absent(),
    this.groupId = const Value.absent(),
    this.tagsJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        description = Value(description),
        prepTime = Value(prepTime),
        cookTime = Value(cookTime),
        servings = Value(servings),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<RecipesTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? prepTime,
    Expression<int>? cookTime,
    Expression<int>? servings,
    Expression<String>? imageUrl,
    Expression<String>? visibility,
    Expression<String>? groupId,
    Expression<String>? tagsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (prepTime != null) 'prep_time': prepTime,
      if (cookTime != null) 'cook_time': cookTime,
      if (servings != null) 'servings': servings,
      if (imageUrl != null) 'image_url': imageUrl,
      if (visibility != null) 'visibility': visibility,
      if (groupId != null) 'group_id': groupId,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? description,
      Value<int>? prepTime,
      Value<int>? cookTime,
      Value<int>? servings,
      Value<String?>? imageUrl,
      Value<String>? visibility,
      Value<String?>? groupId,
      Value<String>? tagsJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return RecipesTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      servings: servings ?? this.servings,
      imageUrl: imageUrl ?? this.imageUrl,
      visibility: visibility ?? this.visibility,
      groupId: groupId ?? this.groupId,
      tagsJson: tagsJson ?? this.tagsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (prepTime.present) {
      map['prep_time'] = Variable<int>(prepTime.value);
    }
    if (cookTime.present) {
      map['cook_time'] = Variable<int>(cookTime.value);
    }
    if (servings.present) {
      map['servings'] = Variable<int>(servings.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipesTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('prepTime: $prepTime, ')
          ..write('cookTime: $cookTime, ')
          ..write('servings: $servings, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('visibility: $visibility, ')
          ..write('groupId: $groupId, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PinwallPostsCachesTable extends PinwallPostsCaches
    with TableInfo<$PinwallPostsCachesTable, PinwallPostsCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PinwallPostsCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _postsJsonMeta =
      const VerificationMeta('postsJson');
  @override
  late final GeneratedColumn<String> postsJson = GeneratedColumn<String>(
      'posts_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [groupId, postsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pinwall_posts_caches';
  @override
  VerificationContext validateIntegrity(Insertable<PinwallPostsCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('posts_json')) {
      context.handle(_postsJsonMeta,
          postsJson.isAcceptableOrUnknown(data['posts_json']!, _postsJsonMeta));
    } else if (isInserting) {
      context.missing(_postsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  PinwallPostsCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PinwallPostsCache(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      postsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}posts_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PinwallPostsCachesTable createAlias(String alias) {
    return $PinwallPostsCachesTable(attachedDatabase, alias);
  }
}

class PinwallPostsCache extends DataClass
    implements Insertable<PinwallPostsCache> {
  final String groupId;
  final String postsJson;
  final DateTime updatedAt;
  const PinwallPostsCache(
      {required this.groupId,
      required this.postsJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['posts_json'] = Variable<String>(postsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PinwallPostsCachesCompanion toCompanion(bool nullToAbsent) {
    return PinwallPostsCachesCompanion(
      groupId: Value(groupId),
      postsJson: Value(postsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory PinwallPostsCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PinwallPostsCache(
      groupId: serializer.fromJson<String>(json['groupId']),
      postsJson: serializer.fromJson<String>(json['postsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'postsJson': serializer.toJson<String>(postsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PinwallPostsCache copyWith(
          {String? groupId, String? postsJson, DateTime? updatedAt}) =>
      PinwallPostsCache(
        groupId: groupId ?? this.groupId,
        postsJson: postsJson ?? this.postsJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PinwallPostsCache copyWithCompanion(PinwallPostsCachesCompanion data) {
    return PinwallPostsCache(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      postsJson: data.postsJson.present ? data.postsJson.value : this.postsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PinwallPostsCache(')
          ..write('groupId: $groupId, ')
          ..write('postsJson: $postsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, postsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PinwallPostsCache &&
          other.groupId == this.groupId &&
          other.postsJson == this.postsJson &&
          other.updatedAt == this.updatedAt);
}

class PinwallPostsCachesCompanion extends UpdateCompanion<PinwallPostsCache> {
  final Value<String> groupId;
  final Value<String> postsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PinwallPostsCachesCompanion({
    this.groupId = const Value.absent(),
    this.postsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PinwallPostsCachesCompanion.insert({
    required String groupId,
    required String postsJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        postsJson = Value(postsJson),
        updatedAt = Value(updatedAt);
  static Insertable<PinwallPostsCache> custom({
    Expression<String>? groupId,
    Expression<String>? postsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (postsJson != null) 'posts_json': postsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PinwallPostsCachesCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? postsJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PinwallPostsCachesCompanion(
      groupId: groupId ?? this.groupId,
      postsJson: postsJson ?? this.postsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (postsJson.present) {
      map['posts_json'] = Variable<String>(postsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PinwallPostsCachesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('postsJson: $postsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HubGroupCachesTable extends HubGroupCaches
    with TableInfo<$HubGroupCachesTable, HubGroupCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HubGroupCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupJsonMeta =
      const VerificationMeta('groupJson');
  @override
  late final GeneratedColumn<String> groupJson = GeneratedColumn<String>(
      'group_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [groupId, groupJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hub_group_caches';
  @override
  VerificationContext validateIntegrity(Insertable<HubGroupCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('group_json')) {
      context.handle(_groupJsonMeta,
          groupJson.isAcceptableOrUnknown(data['group_json']!, _groupJsonMeta));
    } else if (isInserting) {
      context.missing(_groupJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  HubGroupCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HubGroupCache(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      groupJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $HubGroupCachesTable createAlias(String alias) {
    return $HubGroupCachesTable(attachedDatabase, alias);
  }
}

class HubGroupCache extends DataClass implements Insertable<HubGroupCache> {
  final String groupId;
  final String groupJson;
  final DateTime updatedAt;
  const HubGroupCache(
      {required this.groupId,
      required this.groupJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['group_json'] = Variable<String>(groupJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  HubGroupCachesCompanion toCompanion(bool nullToAbsent) {
    return HubGroupCachesCompanion(
      groupId: Value(groupId),
      groupJson: Value(groupJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory HubGroupCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HubGroupCache(
      groupId: serializer.fromJson<String>(json['groupId']),
      groupJson: serializer.fromJson<String>(json['groupJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'groupJson': serializer.toJson<String>(groupJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  HubGroupCache copyWith(
          {String? groupId, String? groupJson, DateTime? updatedAt}) =>
      HubGroupCache(
        groupId: groupId ?? this.groupId,
        groupJson: groupJson ?? this.groupJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  HubGroupCache copyWithCompanion(HubGroupCachesCompanion data) {
    return HubGroupCache(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      groupJson: data.groupJson.present ? data.groupJson.value : this.groupJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HubGroupCache(')
          ..write('groupId: $groupId, ')
          ..write('groupJson: $groupJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, groupJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HubGroupCache &&
          other.groupId == this.groupId &&
          other.groupJson == this.groupJson &&
          other.updatedAt == this.updatedAt);
}

class HubGroupCachesCompanion extends UpdateCompanion<HubGroupCache> {
  final Value<String> groupId;
  final Value<String> groupJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const HubGroupCachesCompanion({
    this.groupId = const Value.absent(),
    this.groupJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HubGroupCachesCompanion.insert({
    required String groupId,
    required String groupJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        groupJson = Value(groupJson),
        updatedAt = Value(updatedAt);
  static Insertable<HubGroupCache> custom({
    Expression<String>? groupId,
    Expression<String>? groupJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (groupJson != null) 'group_json': groupJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HubGroupCachesCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? groupJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return HubGroupCachesCompanion(
      groupId: groupId ?? this.groupId,
      groupJson: groupJson ?? this.groupJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (groupJson.present) {
      map['group_json'] = Variable<String>(groupJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HubGroupCachesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('groupJson: $groupJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HubActivityCachesTable extends HubActivityCaches
    with TableInfo<$HubActivityCachesTable, HubActivityCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HubActivityCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _activitiesJsonMeta =
      const VerificationMeta('activitiesJson');
  @override
  late final GeneratedColumn<String> activitiesJson = GeneratedColumn<String>(
      'activities_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hadErrorMeta =
      const VerificationMeta('hadError');
  @override
  late final GeneratedColumn<bool> hadError = GeneratedColumn<bool>(
      'had_error', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("had_error" IN (0, 1))'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [groupId, activitiesJson, hadError, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hub_activity_caches';
  @override
  VerificationContext validateIntegrity(Insertable<HubActivityCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('activities_json')) {
      context.handle(
          _activitiesJsonMeta,
          activitiesJson.isAcceptableOrUnknown(
              data['activities_json']!, _activitiesJsonMeta));
    } else if (isInserting) {
      context.missing(_activitiesJsonMeta);
    }
    if (data.containsKey('had_error')) {
      context.handle(_hadErrorMeta,
          hadError.isAcceptableOrUnknown(data['had_error']!, _hadErrorMeta));
    } else if (isInserting) {
      context.missing(_hadErrorMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  HubActivityCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HubActivityCache(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      activitiesJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}activities_json'])!,
      hadError: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}had_error'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $HubActivityCachesTable createAlias(String alias) {
    return $HubActivityCachesTable(attachedDatabase, alias);
  }
}

class HubActivityCache extends DataClass
    implements Insertable<HubActivityCache> {
  final String groupId;
  final String activitiesJson;
  final bool hadError;
  final DateTime updatedAt;
  const HubActivityCache(
      {required this.groupId,
      required this.activitiesJson,
      required this.hadError,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['activities_json'] = Variable<String>(activitiesJson);
    map['had_error'] = Variable<bool>(hadError);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  HubActivityCachesCompanion toCompanion(bool nullToAbsent) {
    return HubActivityCachesCompanion(
      groupId: Value(groupId),
      activitiesJson: Value(activitiesJson),
      hadError: Value(hadError),
      updatedAt: Value(updatedAt),
    );
  }

  factory HubActivityCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HubActivityCache(
      groupId: serializer.fromJson<String>(json['groupId']),
      activitiesJson: serializer.fromJson<String>(json['activitiesJson']),
      hadError: serializer.fromJson<bool>(json['hadError']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'activitiesJson': serializer.toJson<String>(activitiesJson),
      'hadError': serializer.toJson<bool>(hadError),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  HubActivityCache copyWith(
          {String? groupId,
          String? activitiesJson,
          bool? hadError,
          DateTime? updatedAt}) =>
      HubActivityCache(
        groupId: groupId ?? this.groupId,
        activitiesJson: activitiesJson ?? this.activitiesJson,
        hadError: hadError ?? this.hadError,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  HubActivityCache copyWithCompanion(HubActivityCachesCompanion data) {
    return HubActivityCache(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      activitiesJson: data.activitiesJson.present
          ? data.activitiesJson.value
          : this.activitiesJson,
      hadError: data.hadError.present ? data.hadError.value : this.hadError,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HubActivityCache(')
          ..write('groupId: $groupId, ')
          ..write('activitiesJson: $activitiesJson, ')
          ..write('hadError: $hadError, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, activitiesJson, hadError, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HubActivityCache &&
          other.groupId == this.groupId &&
          other.activitiesJson == this.activitiesJson &&
          other.hadError == this.hadError &&
          other.updatedAt == this.updatedAt);
}

class HubActivityCachesCompanion extends UpdateCompanion<HubActivityCache> {
  final Value<String> groupId;
  final Value<String> activitiesJson;
  final Value<bool> hadError;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const HubActivityCachesCompanion({
    this.groupId = const Value.absent(),
    this.activitiesJson = const Value.absent(),
    this.hadError = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HubActivityCachesCompanion.insert({
    required String groupId,
    required String activitiesJson,
    required bool hadError,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        activitiesJson = Value(activitiesJson),
        hadError = Value(hadError),
        updatedAt = Value(updatedAt);
  static Insertable<HubActivityCache> custom({
    Expression<String>? groupId,
    Expression<String>? activitiesJson,
    Expression<bool>? hadError,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (activitiesJson != null) 'activities_json': activitiesJson,
      if (hadError != null) 'had_error': hadError,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HubActivityCachesCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? activitiesJson,
      Value<bool>? hadError,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return HubActivityCachesCompanion(
      groupId: groupId ?? this.groupId,
      activitiesJson: activitiesJson ?? this.activitiesJson,
      hadError: hadError ?? this.hadError,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (activitiesJson.present) {
      map['activities_json'] = Variable<String>(activitiesJson.value);
    }
    if (hadError.present) {
      map['had_error'] = Variable<bool>(hadError.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HubActivityCachesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('activitiesJson: $activitiesJson, ')
          ..write('hadError: $hadError, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupsCachesTable extends GroupsCaches
    with TableInfo<$GroupsCachesTable, GroupsCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta =
      const VerificationMeta('cacheKey');
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cache_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupsJsonMeta =
      const VerificationMeta('groupsJson');
  @override
  late final GeneratedColumn<String> groupsJson = GeneratedColumn<String>(
      'groups_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [cacheKey, groupsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups_caches';
  @override
  VerificationContext validateIntegrity(Insertable<GroupsCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(_cacheKeyMeta,
          cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta));
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('groups_json')) {
      context.handle(
          _groupsJsonMeta,
          groupsJson.isAcceptableOrUnknown(
              data['groups_json']!, _groupsJsonMeta));
    } else if (isInserting) {
      context.missing(_groupsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  GroupsCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupsCache(
      cacheKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cache_key'])!,
      groupsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}groups_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $GroupsCachesTable createAlias(String alias) {
    return $GroupsCachesTable(attachedDatabase, alias);
  }
}

class GroupsCache extends DataClass implements Insertable<GroupsCache> {
  final String cacheKey;
  final String groupsJson;
  final DateTime updatedAt;
  const GroupsCache(
      {required this.cacheKey,
      required this.groupsJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['groups_json'] = Variable<String>(groupsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GroupsCachesCompanion toCompanion(bool nullToAbsent) {
    return GroupsCachesCompanion(
      cacheKey: Value(cacheKey),
      groupsJson: Value(groupsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory GroupsCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupsCache(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      groupsJson: serializer.fromJson<String>(json['groupsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'groupsJson': serializer.toJson<String>(groupsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GroupsCache copyWith(
          {String? cacheKey, String? groupsJson, DateTime? updatedAt}) =>
      GroupsCache(
        cacheKey: cacheKey ?? this.cacheKey,
        groupsJson: groupsJson ?? this.groupsJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  GroupsCache copyWithCompanion(GroupsCachesCompanion data) {
    return GroupsCache(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      groupsJson:
          data.groupsJson.present ? data.groupsJson.value : this.groupsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCache(')
          ..write('cacheKey: $cacheKey, ')
          ..write('groupsJson: $groupsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, groupsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupsCache &&
          other.cacheKey == this.cacheKey &&
          other.groupsJson == this.groupsJson &&
          other.updatedAt == this.updatedAt);
}

class GroupsCachesCompanion extends UpdateCompanion<GroupsCache> {
  final Value<String> cacheKey;
  final Value<String> groupsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GroupsCachesCompanion({
    this.cacheKey = const Value.absent(),
    this.groupsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCachesCompanion.insert({
    required String cacheKey,
    required String groupsJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : cacheKey = Value(cacheKey),
        groupsJson = Value(groupsJson),
        updatedAt = Value(updatedAt);
  static Insertable<GroupsCache> custom({
    Expression<String>? cacheKey,
    Expression<String>? groupsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (groupsJson != null) 'groups_json': groupsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCachesCompanion copyWith(
      {Value<String>? cacheKey,
      Value<String>? groupsJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return GroupsCachesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      groupsJson: groupsJson ?? this.groupsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (groupsJson.present) {
      map['groups_json'] = Variable<String>(groupsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCachesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('groupsJson: $groupsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettlementsCachesTable extends SettlementsCaches
    with TableInfo<$SettlementsCachesTable, SettlementsCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettlementsCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _settlementsJsonMeta =
      const VerificationMeta('settlementsJson');
  @override
  late final GeneratedColumn<String> settlementsJson = GeneratedColumn<String>(
      'settlements_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [groupId, settlementsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settlements_caches';
  @override
  VerificationContext validateIntegrity(Insertable<SettlementsCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('settlements_json')) {
      context.handle(
          _settlementsJsonMeta,
          settlementsJson.isAcceptableOrUnknown(
              data['settlements_json']!, _settlementsJsonMeta));
    } else if (isInserting) {
      context.missing(_settlementsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  SettlementsCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettlementsCache(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      settlementsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}settlements_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SettlementsCachesTable createAlias(String alias) {
    return $SettlementsCachesTable(attachedDatabase, alias);
  }
}

class SettlementsCache extends DataClass
    implements Insertable<SettlementsCache> {
  final String groupId;
  final String settlementsJson;
  final DateTime updatedAt;
  const SettlementsCache(
      {required this.groupId,
      required this.settlementsJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['settlements_json'] = Variable<String>(settlementsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettlementsCachesCompanion toCompanion(bool nullToAbsent) {
    return SettlementsCachesCompanion(
      groupId: Value(groupId),
      settlementsJson: Value(settlementsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettlementsCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettlementsCache(
      groupId: serializer.fromJson<String>(json['groupId']),
      settlementsJson: serializer.fromJson<String>(json['settlementsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'settlementsJson': serializer.toJson<String>(settlementsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SettlementsCache copyWith(
          {String? groupId, String? settlementsJson, DateTime? updatedAt}) =>
      SettlementsCache(
        groupId: groupId ?? this.groupId,
        settlementsJson: settlementsJson ?? this.settlementsJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SettlementsCache copyWithCompanion(SettlementsCachesCompanion data) {
    return SettlementsCache(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      settlementsJson: data.settlementsJson.present
          ? data.settlementsJson.value
          : this.settlementsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettlementsCache(')
          ..write('groupId: $groupId, ')
          ..write('settlementsJson: $settlementsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, settlementsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettlementsCache &&
          other.groupId == this.groupId &&
          other.settlementsJson == this.settlementsJson &&
          other.updatedAt == this.updatedAt);
}

class SettlementsCachesCompanion extends UpdateCompanion<SettlementsCache> {
  final Value<String> groupId;
  final Value<String> settlementsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettlementsCachesCompanion({
    this.groupId = const Value.absent(),
    this.settlementsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettlementsCachesCompanion.insert({
    required String groupId,
    required String settlementsJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        settlementsJson = Value(settlementsJson),
        updatedAt = Value(updatedAt);
  static Insertable<SettlementsCache> custom({
    Expression<String>? groupId,
    Expression<String>? settlementsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (settlementsJson != null) 'settlements_json': settlementsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettlementsCachesCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? settlementsJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SettlementsCachesCompanion(
      groupId: groupId ?? this.groupId,
      settlementsJson: settlementsJson ?? this.settlementsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (settlementsJson.present) {
      map['settlements_json'] = Variable<String>(settlementsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettlementsCachesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('settlementsJson: $settlementsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarCachesTable extends CalendarCaches
    with TableInfo<$CalendarCachesTable, CalendarCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rangeKeyMeta =
      const VerificationMeta('rangeKey');
  @override
  late final GeneratedColumn<String> rangeKey = GeneratedColumn<String>(
      'range_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventsJsonMeta =
      const VerificationMeta('eventsJson');
  @override
  late final GeneratedColumn<String> eventsJson = GeneratedColumn<String>(
      'events_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [groupId, rangeKey, eventsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_caches';
  @override
  VerificationContext validateIntegrity(Insertable<CalendarCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('range_key')) {
      context.handle(_rangeKeyMeta,
          rangeKey.isAcceptableOrUnknown(data['range_key']!, _rangeKeyMeta));
    } else if (isInserting) {
      context.missing(_rangeKeyMeta);
    }
    if (data.containsKey('events_json')) {
      context.handle(
          _eventsJsonMeta,
          eventsJson.isAcceptableOrUnknown(
              data['events_json']!, _eventsJsonMeta));
    } else if (isInserting) {
      context.missing(_eventsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, rangeKey};
  @override
  CalendarCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarCache(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      rangeKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}range_key'])!,
      eventsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}events_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CalendarCachesTable createAlias(String alias) {
    return $CalendarCachesTable(attachedDatabase, alias);
  }
}

class CalendarCache extends DataClass implements Insertable<CalendarCache> {
  final String groupId;
  final String rangeKey;
  final String eventsJson;
  final DateTime updatedAt;
  const CalendarCache(
      {required this.groupId,
      required this.rangeKey,
      required this.eventsJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['range_key'] = Variable<String>(rangeKey);
    map['events_json'] = Variable<String>(eventsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CalendarCachesCompanion toCompanion(bool nullToAbsent) {
    return CalendarCachesCompanion(
      groupId: Value(groupId),
      rangeKey: Value(rangeKey),
      eventsJson: Value(eventsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory CalendarCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarCache(
      groupId: serializer.fromJson<String>(json['groupId']),
      rangeKey: serializer.fromJson<String>(json['rangeKey']),
      eventsJson: serializer.fromJson<String>(json['eventsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'rangeKey': serializer.toJson<String>(rangeKey),
      'eventsJson': serializer.toJson<String>(eventsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CalendarCache copyWith(
          {String? groupId,
          String? rangeKey,
          String? eventsJson,
          DateTime? updatedAt}) =>
      CalendarCache(
        groupId: groupId ?? this.groupId,
        rangeKey: rangeKey ?? this.rangeKey,
        eventsJson: eventsJson ?? this.eventsJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CalendarCache copyWithCompanion(CalendarCachesCompanion data) {
    return CalendarCache(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      rangeKey: data.rangeKey.present ? data.rangeKey.value : this.rangeKey,
      eventsJson:
          data.eventsJson.present ? data.eventsJson.value : this.eventsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarCache(')
          ..write('groupId: $groupId, ')
          ..write('rangeKey: $rangeKey, ')
          ..write('eventsJson: $eventsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, rangeKey, eventsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarCache &&
          other.groupId == this.groupId &&
          other.rangeKey == this.rangeKey &&
          other.eventsJson == this.eventsJson &&
          other.updatedAt == this.updatedAt);
}

class CalendarCachesCompanion extends UpdateCompanion<CalendarCache> {
  final Value<String> groupId;
  final Value<String> rangeKey;
  final Value<String> eventsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CalendarCachesCompanion({
    this.groupId = const Value.absent(),
    this.rangeKey = const Value.absent(),
    this.eventsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarCachesCompanion.insert({
    required String groupId,
    required String rangeKey,
    required String eventsJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        rangeKey = Value(rangeKey),
        eventsJson = Value(eventsJson),
        updatedAt = Value(updatedAt);
  static Insertable<CalendarCache> custom({
    Expression<String>? groupId,
    Expression<String>? rangeKey,
    Expression<String>? eventsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (rangeKey != null) 'range_key': rangeKey,
      if (eventsJson != null) 'events_json': eventsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarCachesCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? rangeKey,
      Value<String>? eventsJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CalendarCachesCompanion(
      groupId: groupId ?? this.groupId,
      rangeKey: rangeKey ?? this.rangeKey,
      eventsJson: eventsJson ?? this.eventsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (rangeKey.present) {
      map['range_key'] = Variable<String>(rangeKey.value);
    }
    if (eventsJson.present) {
      map['events_json'] = Variable<String>(eventsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarCachesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('rangeKey: $rangeKey, ')
          ..write('eventsJson: $eventsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealPlanCachesTable extends MealPlanCaches
    with TableInfo<$MealPlanCachesTable, MealPlanCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealPlanCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rangeKeyMeta =
      const VerificationMeta('rangeKey');
  @override
  late final GeneratedColumn<String> rangeKey = GeneratedColumn<String>(
      'range_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plansJsonMeta =
      const VerificationMeta('plansJson');
  @override
  late final GeneratedColumn<String> plansJson = GeneratedColumn<String>(
      'plans_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [groupId, rangeKey, plansJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_plan_caches';
  @override
  VerificationContext validateIntegrity(Insertable<MealPlanCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('range_key')) {
      context.handle(_rangeKeyMeta,
          rangeKey.isAcceptableOrUnknown(data['range_key']!, _rangeKeyMeta));
    } else if (isInserting) {
      context.missing(_rangeKeyMeta);
    }
    if (data.containsKey('plans_json')) {
      context.handle(_plansJsonMeta,
          plansJson.isAcceptableOrUnknown(data['plans_json']!, _plansJsonMeta));
    } else if (isInserting) {
      context.missing(_plansJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, rangeKey};
  @override
  MealPlanCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealPlanCache(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      rangeKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}range_key'])!,
      plansJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plans_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MealPlanCachesTable createAlias(String alias) {
    return $MealPlanCachesTable(attachedDatabase, alias);
  }
}

class MealPlanCache extends DataClass implements Insertable<MealPlanCache> {
  final String groupId;
  final String rangeKey;
  final String plansJson;
  final DateTime updatedAt;
  const MealPlanCache(
      {required this.groupId,
      required this.rangeKey,
      required this.plansJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['range_key'] = Variable<String>(rangeKey);
    map['plans_json'] = Variable<String>(plansJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MealPlanCachesCompanion toCompanion(bool nullToAbsent) {
    return MealPlanCachesCompanion(
      groupId: Value(groupId),
      rangeKey: Value(rangeKey),
      plansJson: Value(plansJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory MealPlanCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealPlanCache(
      groupId: serializer.fromJson<String>(json['groupId']),
      rangeKey: serializer.fromJson<String>(json['rangeKey']),
      plansJson: serializer.fromJson<String>(json['plansJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'rangeKey': serializer.toJson<String>(rangeKey),
      'plansJson': serializer.toJson<String>(plansJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MealPlanCache copyWith(
          {String? groupId,
          String? rangeKey,
          String? plansJson,
          DateTime? updatedAt}) =>
      MealPlanCache(
        groupId: groupId ?? this.groupId,
        rangeKey: rangeKey ?? this.rangeKey,
        plansJson: plansJson ?? this.plansJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MealPlanCache copyWithCompanion(MealPlanCachesCompanion data) {
    return MealPlanCache(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      rangeKey: data.rangeKey.present ? data.rangeKey.value : this.rangeKey,
      plansJson: data.plansJson.present ? data.plansJson.value : this.plansJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealPlanCache(')
          ..write('groupId: $groupId, ')
          ..write('rangeKey: $rangeKey, ')
          ..write('plansJson: $plansJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, rangeKey, plansJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealPlanCache &&
          other.groupId == this.groupId &&
          other.rangeKey == this.rangeKey &&
          other.plansJson == this.plansJson &&
          other.updatedAt == this.updatedAt);
}

class MealPlanCachesCompanion extends UpdateCompanion<MealPlanCache> {
  final Value<String> groupId;
  final Value<String> rangeKey;
  final Value<String> plansJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MealPlanCachesCompanion({
    this.groupId = const Value.absent(),
    this.rangeKey = const Value.absent(),
    this.plansJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealPlanCachesCompanion.insert({
    required String groupId,
    required String rangeKey,
    required String plansJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        rangeKey = Value(rangeKey),
        plansJson = Value(plansJson),
        updatedAt = Value(updatedAt);
  static Insertable<MealPlanCache> custom({
    Expression<String>? groupId,
    Expression<String>? rangeKey,
    Expression<String>? plansJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (rangeKey != null) 'range_key': rangeKey,
      if (plansJson != null) 'plans_json': plansJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealPlanCachesCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? rangeKey,
      Value<String>? plansJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return MealPlanCachesCompanion(
      groupId: groupId ?? this.groupId,
      rangeKey: rangeKey ?? this.rangeKey,
      plansJson: plansJson ?? this.plansJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (rangeKey.present) {
      map['range_key'] = Variable<String>(rangeKey.value);
    }
    if (plansJson.present) {
      map['plans_json'] = Variable<String>(plansJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealPlanCachesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('rangeKey: $rangeKey, ')
          ..write('plansJson: $plansJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResponseCachesTable extends ResponseCaches
    with TableInfo<$ResponseCachesTable, ResponseCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResponseCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta =
      const VerificationMeta('cacheKey');
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cache_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusCodeMeta =
      const VerificationMeta('statusCode');
  @override
  late final GeneratedColumn<int> statusCode = GeneratedColumn<int>(
      'status_code', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _bodyJsonMeta =
      const VerificationMeta('bodyJson');
  @override
  late final GeneratedColumn<String> bodyJson = GeneratedColumn<String>(
      'body_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [cacheKey, statusCode, bodyJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'response_caches';
  @override
  VerificationContext validateIntegrity(Insertable<ResponseCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(_cacheKeyMeta,
          cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta));
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('status_code')) {
      context.handle(
          _statusCodeMeta,
          statusCode.isAcceptableOrUnknown(
              data['status_code']!, _statusCodeMeta));
    } else if (isInserting) {
      context.missing(_statusCodeMeta);
    }
    if (data.containsKey('body_json')) {
      context.handle(_bodyJsonMeta,
          bodyJson.isAcceptableOrUnknown(data['body_json']!, _bodyJsonMeta));
    } else if (isInserting) {
      context.missing(_bodyJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  ResponseCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResponseCache(
      cacheKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cache_key'])!,
      statusCode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status_code'])!,
      bodyJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ResponseCachesTable createAlias(String alias) {
    return $ResponseCachesTable(attachedDatabase, alias);
  }
}

class ResponseCache extends DataClass implements Insertable<ResponseCache> {
  final String cacheKey;
  final int statusCode;
  final String bodyJson;
  final DateTime updatedAt;
  const ResponseCache(
      {required this.cacheKey,
      required this.statusCode,
      required this.bodyJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['status_code'] = Variable<int>(statusCode);
    map['body_json'] = Variable<String>(bodyJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ResponseCachesCompanion toCompanion(bool nullToAbsent) {
    return ResponseCachesCompanion(
      cacheKey: Value(cacheKey),
      statusCode: Value(statusCode),
      bodyJson: Value(bodyJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory ResponseCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResponseCache(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      statusCode: serializer.fromJson<int>(json['statusCode']),
      bodyJson: serializer.fromJson<String>(json['bodyJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'statusCode': serializer.toJson<int>(statusCode),
      'bodyJson': serializer.toJson<String>(bodyJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ResponseCache copyWith(
          {String? cacheKey,
          int? statusCode,
          String? bodyJson,
          DateTime? updatedAt}) =>
      ResponseCache(
        cacheKey: cacheKey ?? this.cacheKey,
        statusCode: statusCode ?? this.statusCode,
        bodyJson: bodyJson ?? this.bodyJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ResponseCache copyWithCompanion(ResponseCachesCompanion data) {
    return ResponseCache(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      statusCode:
          data.statusCode.present ? data.statusCode.value : this.statusCode,
      bodyJson: data.bodyJson.present ? data.bodyJson.value : this.bodyJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResponseCache(')
          ..write('cacheKey: $cacheKey, ')
          ..write('statusCode: $statusCode, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, statusCode, bodyJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResponseCache &&
          other.cacheKey == this.cacheKey &&
          other.statusCode == this.statusCode &&
          other.bodyJson == this.bodyJson &&
          other.updatedAt == this.updatedAt);
}

class ResponseCachesCompanion extends UpdateCompanion<ResponseCache> {
  final Value<String> cacheKey;
  final Value<int> statusCode;
  final Value<String> bodyJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ResponseCachesCompanion({
    this.cacheKey = const Value.absent(),
    this.statusCode = const Value.absent(),
    this.bodyJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResponseCachesCompanion.insert({
    required String cacheKey,
    required int statusCode,
    required String bodyJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : cacheKey = Value(cacheKey),
        statusCode = Value(statusCode),
        bodyJson = Value(bodyJson),
        updatedAt = Value(updatedAt);
  static Insertable<ResponseCache> custom({
    Expression<String>? cacheKey,
    Expression<int>? statusCode,
    Expression<String>? bodyJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (statusCode != null) 'status_code': statusCode,
      if (bodyJson != null) 'body_json': bodyJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResponseCachesCompanion copyWith(
      {Value<String>? cacheKey,
      Value<int>? statusCode,
      Value<String>? bodyJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ResponseCachesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      statusCode: statusCode ?? this.statusCode,
      bodyJson: bodyJson ?? this.bodyJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (statusCode.present) {
      map['status_code'] = Variable<int>(statusCode.value);
    }
    if (bodyJson.present) {
      map['body_json'] = Variable<String>(bodyJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResponseCachesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('statusCode: $statusCode, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxOpsTable extends OutboxOps
    with TableInfo<$OutboxOpsTable, OutboxOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idempotencyKeyMeta =
      const VerificationMeta('idempotencyKey');
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
      'idempotency_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        type,
        payloadJson,
        idempotencyKey,
        createdAt,
        lastAttemptAt,
        attemptCount,
        lastError,
        entityType,
        entityId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_ops';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxOp> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
          _idempotencyKeyMeta,
          idempotencyKey.isAcceptableOrUnknown(
              data['idempotency_key']!, _idempotencyKeyMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxOp(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      idempotencyKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}idempotency_key']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type']),
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id']),
    );
  }

  @override
  $OutboxOpsTable createAlias(String alias) {
    return $OutboxOpsTable(attachedDatabase, alias);
  }
}

class OutboxOp extends DataClass implements Insertable<OutboxOp> {
  final String id;
  final String type;
  final String payloadJson;
  final String? idempotencyKey;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final int attemptCount;
  final String? lastError;

  /// The domain entity this op mutates, e.g. 'listItem', 'expense'. Lets the
  /// failed-changes review UI label an op and the per-row flag find it.
  final String? entityType;

  /// The id of the mutated entity (temp id for creates). Used to roll back the
  /// optimistic local row when a failed change is discarded.
  final String? entityId;
  const OutboxOp(
      {required this.id,
      required this.type,
      required this.payloadJson,
      this.idempotencyKey,
      required this.createdAt,
      this.lastAttemptAt,
      required this.attemptCount,
      this.lastError,
      this.entityType,
      this.entityId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || idempotencyKey != null) {
      map['idempotency_key'] = Variable<String>(idempotencyKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || entityType != null) {
      map['entity_type'] = Variable<String>(entityType);
    }
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    return map;
  }

  OutboxOpsCompanion toCompanion(bool nullToAbsent) {
    return OutboxOpsCompanion(
      id: Value(id),
      type: Value(type),
      payloadJson: Value(payloadJson),
      idempotencyKey: idempotencyKey == null && nullToAbsent
          ? const Value.absent()
          : Value(idempotencyKey),
      createdAt: Value(createdAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      entityType: entityType == null && nullToAbsent
          ? const Value.absent()
          : Value(entityType),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
    );
  }

  factory OutboxOp.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxOp(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      idempotencyKey: serializer.fromJson<String?>(json['idempotencyKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      entityType: serializer.fromJson<String?>(json['entityType']),
      entityId: serializer.fromJson<String?>(json['entityId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'idempotencyKey': serializer.toJson<String?>(idempotencyKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'entityType': serializer.toJson<String?>(entityType),
      'entityId': serializer.toJson<String?>(entityId),
    };
  }

  OutboxOp copyWith(
          {String? id,
          String? type,
          String? payloadJson,
          Value<String?> idempotencyKey = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> lastAttemptAt = const Value.absent(),
          int? attemptCount,
          Value<String?> lastError = const Value.absent(),
          Value<String?> entityType = const Value.absent(),
          Value<String?> entityId = const Value.absent()}) =>
      OutboxOp(
        id: id ?? this.id,
        type: type ?? this.type,
        payloadJson: payloadJson ?? this.payloadJson,
        idempotencyKey:
            idempotencyKey.present ? idempotencyKey.value : this.idempotencyKey,
        createdAt: createdAt ?? this.createdAt,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
        attemptCount: attemptCount ?? this.attemptCount,
        lastError: lastError.present ? lastError.value : this.lastError,
        entityType: entityType.present ? entityType.value : this.entityType,
        entityId: entityId.present ? entityId.value : this.entityId,
      );
  OutboxOp copyWithCompanion(OutboxOpsCompanion data) {
    return OutboxOp(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOp(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, payloadJson, idempotencyKey,
      createdAt, lastAttemptAt, attemptCount, lastError, entityType, entityId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxOp &&
          other.id == this.id &&
          other.type == this.type &&
          other.payloadJson == this.payloadJson &&
          other.idempotencyKey == this.idempotencyKey &&
          other.createdAt == this.createdAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId);
}

class OutboxOpsCompanion extends UpdateCompanion<OutboxOp> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> payloadJson;
  final Value<String?> idempotencyKey;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<String?> entityType;
  final Value<String?> entityId;
  final Value<int> rowid;
  const OutboxOpsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxOpsCompanion.insert({
    required String id,
    required String type,
    required String payloadJson,
    this.idempotencyKey = const Value.absent(),
    required DateTime createdAt,
    this.lastAttemptAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        type = Value(type),
        payloadJson = Value(payloadJson),
        createdAt = Value(createdAt);
  static Insertable<OutboxOp> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? payloadJson,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxOpsCompanion copyWith(
      {Value<String>? id,
      Value<String>? type,
      Value<String>? payloadJson,
      Value<String?>? idempotencyKey,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastAttemptAt,
      Value<int>? attemptCount,
      Value<String?>? lastError,
      Value<String?>? entityType,
      Value<String?>? entityId,
      Value<int>? rowid}) {
    return OutboxOpsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      payloadJson: payloadJson ?? this.payloadJson,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOpsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConflictsTable extends Conflicts
    with TableInfo<$ConflictsTable, Conflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localPayloadJsonMeta =
      const VerificationMeta('localPayloadJson');
  @override
  late final GeneratedColumn<String> localPayloadJson = GeneratedColumn<String>(
      'local_payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverPayloadJsonMeta =
      const VerificationMeta('serverPayloadJson');
  @override
  late final GeneratedColumn<String> serverPayloadJson =
      GeneratedColumn<String>('server_payload_json', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _resolvedAtMeta =
      const VerificationMeta('resolvedAt');
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
      'resolved_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityType,
        entityId,
        localPayloadJson,
        serverPayloadJson,
        createdAt,
        resolvedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conflicts';
  @override
  VerificationContext validateIntegrity(Insertable<Conflict> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('local_payload_json')) {
      context.handle(
          _localPayloadJsonMeta,
          localPayloadJson.isAcceptableOrUnknown(
              data['local_payload_json']!, _localPayloadJsonMeta));
    } else if (isInserting) {
      context.missing(_localPayloadJsonMeta);
    }
    if (data.containsKey('server_payload_json')) {
      context.handle(
          _serverPayloadJsonMeta,
          serverPayloadJson.isAcceptableOrUnknown(
              data['server_payload_json']!, _serverPayloadJsonMeta));
    } else if (isInserting) {
      context.missing(_serverPayloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
          _resolvedAtMeta,
          resolvedAt.isAcceptableOrUnknown(
              data['resolved_at']!, _resolvedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conflict(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      localPayloadJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_payload_json'])!,
      serverPayloadJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}server_payload_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      resolvedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}resolved_at']),
    );
  }

  @override
  $ConflictsTable createAlias(String alias) {
    return $ConflictsTable(attachedDatabase, alias);
  }
}

class Conflict extends DataClass implements Insertable<Conflict> {
  final String id;
  final String entityType;
  final String entityId;
  final String localPayloadJson;
  final String serverPayloadJson;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  const Conflict(
      {required this.id,
      required this.entityType,
      required this.entityId,
      required this.localPayloadJson,
      required this.serverPayloadJson,
      required this.createdAt,
      this.resolvedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['local_payload_json'] = Variable<String>(localPayloadJson);
    map['server_payload_json'] = Variable<String>(serverPayloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  ConflictsCompanion toCompanion(bool nullToAbsent) {
    return ConflictsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      localPayloadJson: Value(localPayloadJson),
      serverPayloadJson: Value(serverPayloadJson),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory Conflict.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conflict(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      localPayloadJson: serializer.fromJson<String>(json['localPayloadJson']),
      serverPayloadJson: serializer.fromJson<String>(json['serverPayloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'localPayloadJson': serializer.toJson<String>(localPayloadJson),
      'serverPayloadJson': serializer.toJson<String>(serverPayloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  Conflict copyWith(
          {String? id,
          String? entityType,
          String? entityId,
          String? localPayloadJson,
          String? serverPayloadJson,
          DateTime? createdAt,
          Value<DateTime?> resolvedAt = const Value.absent()}) =>
      Conflict(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        localPayloadJson: localPayloadJson ?? this.localPayloadJson,
        serverPayloadJson: serverPayloadJson ?? this.serverPayloadJson,
        createdAt: createdAt ?? this.createdAt,
        resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
      );
  Conflict copyWithCompanion(ConflictsCompanion data) {
    return Conflict(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      localPayloadJson: data.localPayloadJson.present
          ? data.localPayloadJson.value
          : this.localPayloadJson,
      serverPayloadJson: data.serverPayloadJson.present
          ? data.serverPayloadJson.value
          : this.serverPayloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conflict(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('serverPayloadJson: $serverPayloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityType, entityId, localPayloadJson,
      serverPayloadJson, createdAt, resolvedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conflict &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.localPayloadJson == this.localPayloadJson &&
          other.serverPayloadJson == this.serverPayloadJson &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class ConflictsCompanion extends UpdateCompanion<Conflict> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> localPayloadJson;
  final Value<String> serverPayloadJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const ConflictsCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.localPayloadJson = const Value.absent(),
    this.serverPayloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConflictsCompanion.insert({
    required String id,
    required String entityType,
    required String entityId,
    required String localPayloadJson,
    required String serverPayloadJson,
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entityType = Value(entityType),
        entityId = Value(entityId),
        localPayloadJson = Value(localPayloadJson),
        serverPayloadJson = Value(serverPayloadJson),
        createdAt = Value(createdAt);
  static Insertable<Conflict> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? localPayloadJson,
    Expression<String>? serverPayloadJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (localPayloadJson != null) 'local_payload_json': localPayloadJson,
      if (serverPayloadJson != null) 'server_payload_json': serverPayloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConflictsCompanion copyWith(
      {Value<String>? id,
      Value<String>? entityType,
      Value<String>? entityId,
      Value<String>? localPayloadJson,
      Value<String>? serverPayloadJson,
      Value<DateTime>? createdAt,
      Value<DateTime?>? resolvedAt,
      Value<int>? rowid}) {
    return ConflictsCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      localPayloadJson: localPayloadJson ?? this.localPayloadJson,
      serverPayloadJson: serverPayloadJson ?? this.serverPayloadJson,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (localPayloadJson.present) {
      map['local_payload_json'] = Variable<String>(localPayloadJson.value);
    }
    if (serverPayloadJson.present) {
      map['server_payload_json'] = Variable<String>(serverPayloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConflictsCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('serverPayloadJson: $serverPayloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CanonicalItemsTableTable extends CanonicalItemsTable
    with TableInfo<$CanonicalItemsTableTable, CanonicalItemsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CanonicalItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameDeMeta = const VerificationMeta('nameDe');
  @override
  late final GeneratedColumn<String> nameDe = GeneratedColumn<String>(
      'name_de', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _nameEnMeta = const VerificationMeta('nameEn');
  @override
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
      'name_en', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _nameFrMeta = const VerificationMeta('nameFr');
  @override
  late final GeneratedColumn<String> nameFr = GeneratedColumn<String>(
      'name_fr', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _nameEsMeta = const VerificationMeta('nameEs');
  @override
  late final GeneratedColumn<String> nameEs = GeneratedColumn<String>(
      'name_es', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _defaultUnitMeta =
      const VerificationMeta('defaultUnit');
  @override
  late final GeneratedColumn<String> defaultUnit = GeneratedColumn<String>(
      'default_unit', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isGlobalMeta =
      const VerificationMeta('isGlobal');
  @override
  late final GeneratedColumn<bool> isGlobal = GeneratedColumn<bool>(
      'is_global', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_global" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        nameDe,
        nameEn,
        nameFr,
        nameEs,
        category,
        defaultUnit,
        productId,
        isGlobal,
        version,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'canonical_items_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<CanonicalItemsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name_de')) {
      context.handle(_nameDeMeta,
          nameDe.isAcceptableOrUnknown(data['name_de']!, _nameDeMeta));
    }
    if (data.containsKey('name_en')) {
      context.handle(_nameEnMeta,
          nameEn.isAcceptableOrUnknown(data['name_en']!, _nameEnMeta));
    }
    if (data.containsKey('name_fr')) {
      context.handle(_nameFrMeta,
          nameFr.isAcceptableOrUnknown(data['name_fr']!, _nameFrMeta));
    }
    if (data.containsKey('name_es')) {
      context.handle(_nameEsMeta,
          nameEs.isAcceptableOrUnknown(data['name_es']!, _nameEsMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('default_unit')) {
      context.handle(
          _defaultUnitMeta,
          defaultUnit.isAcceptableOrUnknown(
              data['default_unit']!, _defaultUnitMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    }
    if (data.containsKey('is_global')) {
      context.handle(_isGlobalMeta,
          isGlobal.isAcceptableOrUnknown(data['is_global']!, _isGlobalMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CanonicalItemsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CanonicalItemsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      nameDe: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_de'])!,
      nameEn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_en'])!,
      nameFr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_fr'])!,
      nameEs: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_es'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      defaultUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}default_unit'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id']),
      isGlobal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_global'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $CanonicalItemsTableTable createAlias(String alias) {
    return $CanonicalItemsTableTable(attachedDatabase, alias);
  }
}

class CanonicalItemsTableData extends DataClass
    implements Insertable<CanonicalItemsTableData> {
  final String id;
  final String groupId;
  final String nameDe;
  final String nameEn;
  final String nameFr;
  final String nameEs;
  final String category;
  final String defaultUnit;
  final String? productId;
  final bool isGlobal;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const CanonicalItemsTableData(
      {required this.id,
      required this.groupId,
      required this.nameDe,
      required this.nameEn,
      required this.nameFr,
      required this.nameEs,
      required this.category,
      required this.defaultUnit,
      this.productId,
      required this.isGlobal,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['name_de'] = Variable<String>(nameDe);
    map['name_en'] = Variable<String>(nameEn);
    map['name_fr'] = Variable<String>(nameFr);
    map['name_es'] = Variable<String>(nameEs);
    map['category'] = Variable<String>(category);
    map['default_unit'] = Variable<String>(defaultUnit);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    map['is_global'] = Variable<bool>(isGlobal);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CanonicalItemsTableCompanion toCompanion(bool nullToAbsent) {
    return CanonicalItemsTableCompanion(
      id: Value(id),
      groupId: Value(groupId),
      nameDe: Value(nameDe),
      nameEn: Value(nameEn),
      nameFr: Value(nameFr),
      nameEs: Value(nameEs),
      category: Value(category),
      defaultUnit: Value(defaultUnit),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      isGlobal: Value(isGlobal),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CanonicalItemsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CanonicalItemsTableData(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      nameDe: serializer.fromJson<String>(json['nameDe']),
      nameEn: serializer.fromJson<String>(json['nameEn']),
      nameFr: serializer.fromJson<String>(json['nameFr']),
      nameEs: serializer.fromJson<String>(json['nameEs']),
      category: serializer.fromJson<String>(json['category']),
      defaultUnit: serializer.fromJson<String>(json['defaultUnit']),
      productId: serializer.fromJson<String?>(json['productId']),
      isGlobal: serializer.fromJson<bool>(json['isGlobal']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'nameDe': serializer.toJson<String>(nameDe),
      'nameEn': serializer.toJson<String>(nameEn),
      'nameFr': serializer.toJson<String>(nameFr),
      'nameEs': serializer.toJson<String>(nameEs),
      'category': serializer.toJson<String>(category),
      'defaultUnit': serializer.toJson<String>(defaultUnit),
      'productId': serializer.toJson<String?>(productId),
      'isGlobal': serializer.toJson<bool>(isGlobal),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CanonicalItemsTableData copyWith(
          {String? id,
          String? groupId,
          String? nameDe,
          String? nameEn,
          String? nameFr,
          String? nameEs,
          String? category,
          String? defaultUnit,
          Value<String?> productId = const Value.absent(),
          bool? isGlobal,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      CanonicalItemsTableData(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        nameDe: nameDe ?? this.nameDe,
        nameEn: nameEn ?? this.nameEn,
        nameFr: nameFr ?? this.nameFr,
        nameEs: nameEs ?? this.nameEs,
        category: category ?? this.category,
        defaultUnit: defaultUnit ?? this.defaultUnit,
        productId: productId.present ? productId.value : this.productId,
        isGlobal: isGlobal ?? this.isGlobal,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  CanonicalItemsTableData copyWithCompanion(CanonicalItemsTableCompanion data) {
    return CanonicalItemsTableData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      nameDe: data.nameDe.present ? data.nameDe.value : this.nameDe,
      nameEn: data.nameEn.present ? data.nameEn.value : this.nameEn,
      nameFr: data.nameFr.present ? data.nameFr.value : this.nameFr,
      nameEs: data.nameEs.present ? data.nameEs.value : this.nameEs,
      category: data.category.present ? data.category.value : this.category,
      defaultUnit:
          data.defaultUnit.present ? data.defaultUnit.value : this.defaultUnit,
      productId: data.productId.present ? data.productId.value : this.productId,
      isGlobal: data.isGlobal.present ? data.isGlobal.value : this.isGlobal,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CanonicalItemsTableData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('nameDe: $nameDe, ')
          ..write('nameEn: $nameEn, ')
          ..write('nameFr: $nameFr, ')
          ..write('nameEs: $nameEs, ')
          ..write('category: $category, ')
          ..write('defaultUnit: $defaultUnit, ')
          ..write('productId: $productId, ')
          ..write('isGlobal: $isGlobal, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      groupId,
      nameDe,
      nameEn,
      nameFr,
      nameEs,
      category,
      defaultUnit,
      productId,
      isGlobal,
      version,
      createdAt,
      updatedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CanonicalItemsTableData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.nameDe == this.nameDe &&
          other.nameEn == this.nameEn &&
          other.nameFr == this.nameFr &&
          other.nameEs == this.nameEs &&
          other.category == this.category &&
          other.defaultUnit == this.defaultUnit &&
          other.productId == this.productId &&
          other.isGlobal == this.isGlobal &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CanonicalItemsTableCompanion
    extends UpdateCompanion<CanonicalItemsTableData> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> nameDe;
  final Value<String> nameEn;
  final Value<String> nameFr;
  final Value<String> nameEs;
  final Value<String> category;
  final Value<String> defaultUnit;
  final Value<String?> productId;
  final Value<bool> isGlobal;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CanonicalItemsTableCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.nameDe = const Value.absent(),
    this.nameEn = const Value.absent(),
    this.nameFr = const Value.absent(),
    this.nameEs = const Value.absent(),
    this.category = const Value.absent(),
    this.defaultUnit = const Value.absent(),
    this.productId = const Value.absent(),
    this.isGlobal = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CanonicalItemsTableCompanion.insert({
    required String id,
    required String groupId,
    this.nameDe = const Value.absent(),
    this.nameEn = const Value.absent(),
    this.nameFr = const Value.absent(),
    this.nameEs = const Value.absent(),
    this.category = const Value.absent(),
    this.defaultUnit = const Value.absent(),
    this.productId = const Value.absent(),
    this.isGlobal = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<CanonicalItemsTableData> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? nameDe,
    Expression<String>? nameEn,
    Expression<String>? nameFr,
    Expression<String>? nameEs,
    Expression<String>? category,
    Expression<String>? defaultUnit,
    Expression<String>? productId,
    Expression<bool>? isGlobal,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (nameDe != null) 'name_de': nameDe,
      if (nameEn != null) 'name_en': nameEn,
      if (nameFr != null) 'name_fr': nameFr,
      if (nameEs != null) 'name_es': nameEs,
      if (category != null) 'category': category,
      if (defaultUnit != null) 'default_unit': defaultUnit,
      if (productId != null) 'product_id': productId,
      if (isGlobal != null) 'is_global': isGlobal,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CanonicalItemsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String>? nameDe,
      Value<String>? nameEn,
      Value<String>? nameFr,
      Value<String>? nameEs,
      Value<String>? category,
      Value<String>? defaultUnit,
      Value<String?>? productId,
      Value<bool>? isGlobal,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return CanonicalItemsTableCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      nameDe: nameDe ?? this.nameDe,
      nameEn: nameEn ?? this.nameEn,
      nameFr: nameFr ?? this.nameFr,
      nameEs: nameEs ?? this.nameEs,
      category: category ?? this.category,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      productId: productId ?? this.productId,
      isGlobal: isGlobal ?? this.isGlobal,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (nameDe.present) {
      map['name_de'] = Variable<String>(nameDe.value);
    }
    if (nameEn.present) {
      map['name_en'] = Variable<String>(nameEn.value);
    }
    if (nameFr.present) {
      map['name_fr'] = Variable<String>(nameFr.value);
    }
    if (nameEs.present) {
      map['name_es'] = Variable<String>(nameEs.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (defaultUnit.present) {
      map['default_unit'] = Variable<String>(defaultUnit.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (isGlobal.present) {
      map['is_global'] = Variable<bool>(isGlobal.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CanonicalItemsTableCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('nameDe: $nameDe, ')
          ..write('nameEn: $nameEn, ')
          ..write('nameFr: $nameFr, ')
          ..write('nameEs: $nameEs, ')
          ..write('category: $category, ')
          ..write('defaultUnit: $defaultUnit, ')
          ..write('productId: $productId, ')
          ..write('isGlobal: $isGlobal, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemAliasesTableTable extends ItemAliasesTable
    with TableInfo<$ItemAliasesTableTable, ItemAliasesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemAliasesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _canonicalItemIdMeta =
      const VerificationMeta('canonicalItemId');
  @override
  late final GeneratedColumn<String> canonicalItemId = GeneratedColumn<String>(
      'canonical_item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aliasTextMeta =
      const VerificationMeta('aliasText');
  @override
  late final GeneratedColumn<String> aliasText = GeneratedColumn<String>(
      'alias_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
      'lang', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('und'));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('correction'));
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<int> weight = GeneratedColumn<int>(
      'weight', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        canonicalItemId,
        aliasText,
        lang,
        source,
        weight,
        version,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_aliases_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ItemAliasesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('canonical_item_id')) {
      context.handle(
          _canonicalItemIdMeta,
          canonicalItemId.isAcceptableOrUnknown(
              data['canonical_item_id']!, _canonicalItemIdMeta));
    } else if (isInserting) {
      context.missing(_canonicalItemIdMeta);
    }
    if (data.containsKey('alias_text')) {
      context.handle(_aliasTextMeta,
          aliasText.isAcceptableOrUnknown(data['alias_text']!, _aliasTextMeta));
    } else if (isInserting) {
      context.missing(_aliasTextMeta);
    }
    if (data.containsKey('lang')) {
      context.handle(
          _langMeta, lang.isAcceptableOrUnknown(data['lang']!, _langMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemAliasesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemAliasesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      canonicalItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}canonical_item_id'])!,
      aliasText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alias_text'])!,
      lang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lang'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}weight'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $ItemAliasesTableTable createAlias(String alias) {
    return $ItemAliasesTableTable(attachedDatabase, alias);
  }
}

class ItemAliasesTableData extends DataClass
    implements Insertable<ItemAliasesTableData> {
  final String id;
  final String groupId;
  final String canonicalItemId;
  final String aliasText;
  final String lang;
  final String source;
  final int weight;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ItemAliasesTableData(
      {required this.id,
      required this.groupId,
      required this.canonicalItemId,
      required this.aliasText,
      required this.lang,
      required this.source,
      required this.weight,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['canonical_item_id'] = Variable<String>(canonicalItemId);
    map['alias_text'] = Variable<String>(aliasText);
    map['lang'] = Variable<String>(lang);
    map['source'] = Variable<String>(source);
    map['weight'] = Variable<int>(weight);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ItemAliasesTableCompanion toCompanion(bool nullToAbsent) {
    return ItemAliasesTableCompanion(
      id: Value(id),
      groupId: Value(groupId),
      canonicalItemId: Value(canonicalItemId),
      aliasText: Value(aliasText),
      lang: Value(lang),
      source: Value(source),
      weight: Value(weight),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ItemAliasesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemAliasesTableData(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      canonicalItemId: serializer.fromJson<String>(json['canonicalItemId']),
      aliasText: serializer.fromJson<String>(json['aliasText']),
      lang: serializer.fromJson<String>(json['lang']),
      source: serializer.fromJson<String>(json['source']),
      weight: serializer.fromJson<int>(json['weight']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'canonicalItemId': serializer.toJson<String>(canonicalItemId),
      'aliasText': serializer.toJson<String>(aliasText),
      'lang': serializer.toJson<String>(lang),
      'source': serializer.toJson<String>(source),
      'weight': serializer.toJson<int>(weight),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ItemAliasesTableData copyWith(
          {String? id,
          String? groupId,
          String? canonicalItemId,
          String? aliasText,
          String? lang,
          String? source,
          int? weight,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      ItemAliasesTableData(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        canonicalItemId: canonicalItemId ?? this.canonicalItemId,
        aliasText: aliasText ?? this.aliasText,
        lang: lang ?? this.lang,
        source: source ?? this.source,
        weight: weight ?? this.weight,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  ItemAliasesTableData copyWithCompanion(ItemAliasesTableCompanion data) {
    return ItemAliasesTableData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      canonicalItemId: data.canonicalItemId.present
          ? data.canonicalItemId.value
          : this.canonicalItemId,
      aliasText: data.aliasText.present ? data.aliasText.value : this.aliasText,
      lang: data.lang.present ? data.lang.value : this.lang,
      source: data.source.present ? data.source.value : this.source,
      weight: data.weight.present ? data.weight.value : this.weight,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemAliasesTableData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('canonicalItemId: $canonicalItemId, ')
          ..write('aliasText: $aliasText, ')
          ..write('lang: $lang, ')
          ..write('source: $source, ')
          ..write('weight: $weight, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, canonicalItemId, aliasText, lang,
      source, weight, version, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemAliasesTableData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.canonicalItemId == this.canonicalItemId &&
          other.aliasText == this.aliasText &&
          other.lang == this.lang &&
          other.source == this.source &&
          other.weight == this.weight &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ItemAliasesTableCompanion extends UpdateCompanion<ItemAliasesTableData> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> canonicalItemId;
  final Value<String> aliasText;
  final Value<String> lang;
  final Value<String> source;
  final Value<int> weight;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ItemAliasesTableCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.canonicalItemId = const Value.absent(),
    this.aliasText = const Value.absent(),
    this.lang = const Value.absent(),
    this.source = const Value.absent(),
    this.weight = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemAliasesTableCompanion.insert({
    required String id,
    required String groupId,
    required String canonicalItemId,
    required String aliasText,
    this.lang = const Value.absent(),
    this.source = const Value.absent(),
    this.weight = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        canonicalItemId = Value(canonicalItemId),
        aliasText = Value(aliasText),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ItemAliasesTableData> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? canonicalItemId,
    Expression<String>? aliasText,
    Expression<String>? lang,
    Expression<String>? source,
    Expression<int>? weight,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (canonicalItemId != null) 'canonical_item_id': canonicalItemId,
      if (aliasText != null) 'alias_text': aliasText,
      if (lang != null) 'lang': lang,
      if (source != null) 'source': source,
      if (weight != null) 'weight': weight,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemAliasesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String>? canonicalItemId,
      Value<String>? aliasText,
      Value<String>? lang,
      Value<String>? source,
      Value<int>? weight,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return ItemAliasesTableCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      canonicalItemId: canonicalItemId ?? this.canonicalItemId,
      aliasText: aliasText ?? this.aliasText,
      lang: lang ?? this.lang,
      source: source ?? this.source,
      weight: weight ?? this.weight,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (canonicalItemId.present) {
      map['canonical_item_id'] = Variable<String>(canonicalItemId.value);
    }
    if (aliasText.present) {
      map['alias_text'] = Variable<String>(aliasText.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (weight.present) {
      map['weight'] = Variable<int>(weight.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemAliasesTableCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('canonicalItemId: $canonicalItemId, ')
          ..write('aliasText: $aliasText, ')
          ..write('lang: $lang, ')
          ..write('source: $source, ')
          ..write('weight: $weight, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CorrectionsTableTable extends CorrectionsTable
    with TableInfo<$CorrectionsTableTable, CorrectionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CorrectionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
      'scope', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('household'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rawTextMeta =
      const VerificationMeta('rawText');
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
      'raw_text', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _resolvedCanonicalItemIdMeta =
      const VerificationMeta('resolvedCanonicalItemId');
  @override
  late final GeneratedColumn<String> resolvedCanonicalItemId =
      GeneratedColumn<String>('resolved_canonical_item_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _correctedValueJsonMeta =
      const VerificationMeta('correctedValueJson');
  @override
  late final GeneratedColumn<String> correctedValueJson =
      GeneratedColumn<String>('corrected_value_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual_review'));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _appliedAtMeta =
      const VerificationMeta('appliedAt');
  @override
  late final GeneratedColumn<DateTime> appliedAt = GeneratedColumn<DateTime>(
      'applied_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        userId,
        scope,
        kind,
        rawText,
        resolvedCanonicalItemId,
        correctedValueJson,
        source,
        version,
        createdAt,
        appliedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'corrections_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<CorrectionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('scope')) {
      context.handle(
          _scopeMeta, scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(_rawTextMeta,
          rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta));
    }
    if (data.containsKey('resolved_canonical_item_id')) {
      context.handle(
          _resolvedCanonicalItemIdMeta,
          resolvedCanonicalItemId.isAcceptableOrUnknown(
              data['resolved_canonical_item_id']!,
              _resolvedCanonicalItemIdMeta));
    }
    if (data.containsKey('corrected_value_json')) {
      context.handle(
          _correctedValueJsonMeta,
          correctedValueJson.isAcceptableOrUnknown(
              data['corrected_value_json']!, _correctedValueJsonMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('applied_at')) {
      context.handle(_appliedAtMeta,
          appliedAt.isAcceptableOrUnknown(data['applied_at']!, _appliedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CorrectionsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CorrectionsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id']),
      scope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      rawText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_text'])!,
      resolvedCanonicalItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}resolved_canonical_item_id']),
      correctedValueJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}corrected_value_json']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      appliedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}applied_at']),
    );
  }

  @override
  $CorrectionsTableTable createAlias(String alias) {
    return $CorrectionsTableTable(attachedDatabase, alias);
  }
}

class CorrectionsTableData extends DataClass
    implements Insertable<CorrectionsTableData> {
  final String id;
  final String groupId;
  final String? userId;
  final String scope;
  final String kind;
  final String rawText;
  final String? resolvedCanonicalItemId;
  final String? correctedValueJson;
  final String source;
  final int version;
  final DateTime createdAt;
  final DateTime? appliedAt;
  const CorrectionsTableData(
      {required this.id,
      required this.groupId,
      this.userId,
      required this.scope,
      required this.kind,
      required this.rawText,
      this.resolvedCanonicalItemId,
      this.correctedValueJson,
      required this.source,
      required this.version,
      required this.createdAt,
      this.appliedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['scope'] = Variable<String>(scope);
    map['kind'] = Variable<String>(kind);
    map['raw_text'] = Variable<String>(rawText);
    if (!nullToAbsent || resolvedCanonicalItemId != null) {
      map['resolved_canonical_item_id'] =
          Variable<String>(resolvedCanonicalItemId);
    }
    if (!nullToAbsent || correctedValueJson != null) {
      map['corrected_value_json'] = Variable<String>(correctedValueJson);
    }
    map['source'] = Variable<String>(source);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || appliedAt != null) {
      map['applied_at'] = Variable<DateTime>(appliedAt);
    }
    return map;
  }

  CorrectionsTableCompanion toCompanion(bool nullToAbsent) {
    return CorrectionsTableCompanion(
      id: Value(id),
      groupId: Value(groupId),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      scope: Value(scope),
      kind: Value(kind),
      rawText: Value(rawText),
      resolvedCanonicalItemId: resolvedCanonicalItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedCanonicalItemId),
      correctedValueJson: correctedValueJson == null && nullToAbsent
          ? const Value.absent()
          : Value(correctedValueJson),
      source: Value(source),
      version: Value(version),
      createdAt: Value(createdAt),
      appliedAt: appliedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(appliedAt),
    );
  }

  factory CorrectionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CorrectionsTableData(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      userId: serializer.fromJson<String?>(json['userId']),
      scope: serializer.fromJson<String>(json['scope']),
      kind: serializer.fromJson<String>(json['kind']),
      rawText: serializer.fromJson<String>(json['rawText']),
      resolvedCanonicalItemId:
          serializer.fromJson<String?>(json['resolvedCanonicalItemId']),
      correctedValueJson:
          serializer.fromJson<String?>(json['correctedValueJson']),
      source: serializer.fromJson<String>(json['source']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      appliedAt: serializer.fromJson<DateTime?>(json['appliedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'userId': serializer.toJson<String?>(userId),
      'scope': serializer.toJson<String>(scope),
      'kind': serializer.toJson<String>(kind),
      'rawText': serializer.toJson<String>(rawText),
      'resolvedCanonicalItemId':
          serializer.toJson<String?>(resolvedCanonicalItemId),
      'correctedValueJson': serializer.toJson<String?>(correctedValueJson),
      'source': serializer.toJson<String>(source),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'appliedAt': serializer.toJson<DateTime?>(appliedAt),
    };
  }

  CorrectionsTableData copyWith(
          {String? id,
          String? groupId,
          Value<String?> userId = const Value.absent(),
          String? scope,
          String? kind,
          String? rawText,
          Value<String?> resolvedCanonicalItemId = const Value.absent(),
          Value<String?> correctedValueJson = const Value.absent(),
          String? source,
          int? version,
          DateTime? createdAt,
          Value<DateTime?> appliedAt = const Value.absent()}) =>
      CorrectionsTableData(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        userId: userId.present ? userId.value : this.userId,
        scope: scope ?? this.scope,
        kind: kind ?? this.kind,
        rawText: rawText ?? this.rawText,
        resolvedCanonicalItemId: resolvedCanonicalItemId.present
            ? resolvedCanonicalItemId.value
            : this.resolvedCanonicalItemId,
        correctedValueJson: correctedValueJson.present
            ? correctedValueJson.value
            : this.correctedValueJson,
        source: source ?? this.source,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        appliedAt: appliedAt.present ? appliedAt.value : this.appliedAt,
      );
  CorrectionsTableData copyWithCompanion(CorrectionsTableCompanion data) {
    return CorrectionsTableData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      userId: data.userId.present ? data.userId.value : this.userId,
      scope: data.scope.present ? data.scope.value : this.scope,
      kind: data.kind.present ? data.kind.value : this.kind,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      resolvedCanonicalItemId: data.resolvedCanonicalItemId.present
          ? data.resolvedCanonicalItemId.value
          : this.resolvedCanonicalItemId,
      correctedValueJson: data.correctedValueJson.present
          ? data.correctedValueJson.value
          : this.correctedValueJson,
      source: data.source.present ? data.source.value : this.source,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      appliedAt: data.appliedAt.present ? data.appliedAt.value : this.appliedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CorrectionsTableData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('userId: $userId, ')
          ..write('scope: $scope, ')
          ..write('kind: $kind, ')
          ..write('rawText: $rawText, ')
          ..write('resolvedCanonicalItemId: $resolvedCanonicalItemId, ')
          ..write('correctedValueJson: $correctedValueJson, ')
          ..write('source: $source, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      groupId,
      userId,
      scope,
      kind,
      rawText,
      resolvedCanonicalItemId,
      correctedValueJson,
      source,
      version,
      createdAt,
      appliedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CorrectionsTableData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.userId == this.userId &&
          other.scope == this.scope &&
          other.kind == this.kind &&
          other.rawText == this.rawText &&
          other.resolvedCanonicalItemId == this.resolvedCanonicalItemId &&
          other.correctedValueJson == this.correctedValueJson &&
          other.source == this.source &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.appliedAt == this.appliedAt);
}

class CorrectionsTableCompanion extends UpdateCompanion<CorrectionsTableData> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String?> userId;
  final Value<String> scope;
  final Value<String> kind;
  final Value<String> rawText;
  final Value<String?> resolvedCanonicalItemId;
  final Value<String?> correctedValueJson;
  final Value<String> source;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime?> appliedAt;
  final Value<int> rowid;
  const CorrectionsTableCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.userId = const Value.absent(),
    this.scope = const Value.absent(),
    this.kind = const Value.absent(),
    this.rawText = const Value.absent(),
    this.resolvedCanonicalItemId = const Value.absent(),
    this.correctedValueJson = const Value.absent(),
    this.source = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CorrectionsTableCompanion.insert({
    required String id,
    required String groupId,
    this.userId = const Value.absent(),
    this.scope = const Value.absent(),
    required String kind,
    this.rawText = const Value.absent(),
    this.resolvedCanonicalItemId = const Value.absent(),
    this.correctedValueJson = const Value.absent(),
    this.source = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    this.appliedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        kind = Value(kind),
        createdAt = Value(createdAt);
  static Insertable<CorrectionsTableData> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? userId,
    Expression<String>? scope,
    Expression<String>? kind,
    Expression<String>? rawText,
    Expression<String>? resolvedCanonicalItemId,
    Expression<String>? correctedValueJson,
    Expression<String>? source,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? appliedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (userId != null) 'user_id': userId,
      if (scope != null) 'scope': scope,
      if (kind != null) 'kind': kind,
      if (rawText != null) 'raw_text': rawText,
      if (resolvedCanonicalItemId != null)
        'resolved_canonical_item_id': resolvedCanonicalItemId,
      if (correctedValueJson != null)
        'corrected_value_json': correctedValueJson,
      if (source != null) 'source': source,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (appliedAt != null) 'applied_at': appliedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CorrectionsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String?>? userId,
      Value<String>? scope,
      Value<String>? kind,
      Value<String>? rawText,
      Value<String?>? resolvedCanonicalItemId,
      Value<String?>? correctedValueJson,
      Value<String>? source,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime?>? appliedAt,
      Value<int>? rowid}) {
    return CorrectionsTableCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      scope: scope ?? this.scope,
      kind: kind ?? this.kind,
      rawText: rawText ?? this.rawText,
      resolvedCanonicalItemId:
          resolvedCanonicalItemId ?? this.resolvedCanonicalItemId,
      correctedValueJson: correctedValueJson ?? this.correctedValueJson,
      source: source ?? this.source,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      appliedAt: appliedAt ?? this.appliedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (resolvedCanonicalItemId.present) {
      map['resolved_canonical_item_id'] =
          Variable<String>(resolvedCanonicalItemId.value);
    }
    if (correctedValueJson.present) {
      map['corrected_value_json'] = Variable<String>(correctedValueJson.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (appliedAt.present) {
      map['applied_at'] = Variable<DateTime>(appliedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CorrectionsTableCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('userId: $userId, ')
          ..write('scope: $scope, ')
          ..write('kind: $kind, ')
          ..write('rawText: $rawText, ')
          ..write('resolvedCanonicalItemId: $resolvedCanonicalItemId, ')
          ..write('correctedValueJson: $correctedValueJson, ')
          ..write('source: $source, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('appliedAt: $appliedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoreAislesTableTable extends StoreAislesTable
    with TableInfo<$StoreAislesTableTable, StoreAislesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoreAislesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _storeIdMeta =
      const VerificationMeta('storeId');
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
      'store_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _canonicalItemIdMeta =
      const VerificationMeta('canonicalItemId');
  @override
  late final GeneratedColumn<String> canonicalItemId = GeneratedColumn<String>(
      'canonical_item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aisleMeta = const VerificationMeta('aisle');
  @override
  late final GeneratedColumn<String> aisle = GeneratedColumn<String>(
      'aisle', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _confidenceMeta =
      const VerificationMeta('confidence');
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
      'confidence', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.5));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        storeId,
        canonicalItemId,
        aisle,
        sortOrder,
        confidence,
        version,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'store_aisles_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<StoreAislesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(_storeIdMeta,
          storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta));
    }
    if (data.containsKey('canonical_item_id')) {
      context.handle(
          _canonicalItemIdMeta,
          canonicalItemId.isAcceptableOrUnknown(
              data['canonical_item_id']!, _canonicalItemIdMeta));
    } else if (isInserting) {
      context.missing(_canonicalItemIdMeta);
    }
    if (data.containsKey('aisle')) {
      context.handle(
          _aisleMeta, aisle.isAcceptableOrUnknown(data['aisle']!, _aisleMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('confidence')) {
      context.handle(
          _confidenceMeta,
          confidence.isAcceptableOrUnknown(
              data['confidence']!, _confidenceMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoreAislesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoreAislesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      storeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}store_id']),
      canonicalItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}canonical_item_id'])!,
      aisle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}aisle'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      confidence: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}confidence'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $StoreAislesTableTable createAlias(String alias) {
    return $StoreAislesTableTable(attachedDatabase, alias);
  }
}

class StoreAislesTableData extends DataClass
    implements Insertable<StoreAislesTableData> {
  final String id;
  final String groupId;
  final String? storeId;
  final String canonicalItemId;
  final String aisle;
  final int sortOrder;
  final double confidence;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const StoreAislesTableData(
      {required this.id,
      required this.groupId,
      this.storeId,
      required this.canonicalItemId,
      required this.aisle,
      required this.sortOrder,
      required this.confidence,
      required this.version,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    if (!nullToAbsent || storeId != null) {
      map['store_id'] = Variable<String>(storeId);
    }
    map['canonical_item_id'] = Variable<String>(canonicalItemId);
    map['aisle'] = Variable<String>(aisle);
    map['sort_order'] = Variable<int>(sortOrder);
    map['confidence'] = Variable<double>(confidence);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  StoreAislesTableCompanion toCompanion(bool nullToAbsent) {
    return StoreAislesTableCompanion(
      id: Value(id),
      groupId: Value(groupId),
      storeId: storeId == null && nullToAbsent
          ? const Value.absent()
          : Value(storeId),
      canonicalItemId: Value(canonicalItemId),
      aisle: Value(aisle),
      sortOrder: Value(sortOrder),
      confidence: Value(confidence),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory StoreAislesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoreAislesTableData(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      storeId: serializer.fromJson<String?>(json['storeId']),
      canonicalItemId: serializer.fromJson<String>(json['canonicalItemId']),
      aisle: serializer.fromJson<String>(json['aisle']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      confidence: serializer.fromJson<double>(json['confidence']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'storeId': serializer.toJson<String?>(storeId),
      'canonicalItemId': serializer.toJson<String>(canonicalItemId),
      'aisle': serializer.toJson<String>(aisle),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'confidence': serializer.toJson<double>(confidence),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  StoreAislesTableData copyWith(
          {String? id,
          String? groupId,
          Value<String?> storeId = const Value.absent(),
          String? canonicalItemId,
          String? aisle,
          int? sortOrder,
          double? confidence,
          int? version,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      StoreAislesTableData(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        storeId: storeId.present ? storeId.value : this.storeId,
        canonicalItemId: canonicalItemId ?? this.canonicalItemId,
        aisle: aisle ?? this.aisle,
        sortOrder: sortOrder ?? this.sortOrder,
        confidence: confidence ?? this.confidence,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  StoreAislesTableData copyWithCompanion(StoreAislesTableCompanion data) {
    return StoreAislesTableData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      canonicalItemId: data.canonicalItemId.present
          ? data.canonicalItemId.value
          : this.canonicalItemId,
      aisle: data.aisle.present ? data.aisle.value : this.aisle,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      confidence:
          data.confidence.present ? data.confidence.value : this.confidence,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoreAislesTableData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('storeId: $storeId, ')
          ..write('canonicalItemId: $canonicalItemId, ')
          ..write('aisle: $aisle, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('confidence: $confidence, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, storeId, canonicalItemId, aisle,
      sortOrder, confidence, version, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoreAislesTableData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.storeId == this.storeId &&
          other.canonicalItemId == this.canonicalItemId &&
          other.aisle == this.aisle &&
          other.sortOrder == this.sortOrder &&
          other.confidence == this.confidence &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class StoreAislesTableCompanion extends UpdateCompanion<StoreAislesTableData> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String?> storeId;
  final Value<String> canonicalItemId;
  final Value<String> aisle;
  final Value<int> sortOrder;
  final Value<double> confidence;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const StoreAislesTableCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.canonicalItemId = const Value.absent(),
    this.aisle = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.confidence = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoreAislesTableCompanion.insert({
    required String id,
    required String groupId,
    this.storeId = const Value.absent(),
    required String canonicalItemId,
    this.aisle = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.confidence = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        canonicalItemId = Value(canonicalItemId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<StoreAislesTableData> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? storeId,
    Expression<String>? canonicalItemId,
    Expression<String>? aisle,
    Expression<int>? sortOrder,
    Expression<double>? confidence,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (storeId != null) 'store_id': storeId,
      if (canonicalItemId != null) 'canonical_item_id': canonicalItemId,
      if (aisle != null) 'aisle': aisle,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (confidence != null) 'confidence': confidence,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoreAislesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String?>? storeId,
      Value<String>? canonicalItemId,
      Value<String>? aisle,
      Value<int>? sortOrder,
      Value<double>? confidence,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return StoreAislesTableCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      storeId: storeId ?? this.storeId,
      canonicalItemId: canonicalItemId ?? this.canonicalItemId,
      aisle: aisle ?? this.aisle,
      sortOrder: sortOrder ?? this.sortOrder,
      confidence: confidence ?? this.confidence,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (canonicalItemId.present) {
      map['canonical_item_id'] = Variable<String>(canonicalItemId.value);
    }
    if (aisle.present) {
      map['aisle'] = Variable<String>(aisle.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoreAislesTableCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('storeId: $storeId, ')
          ..write('canonicalItemId: $canonicalItemId, ')
          ..write('aisle: $aisle, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('confidence: $confidence, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseHistoryTableTable extends PurchaseHistoryTable
    with TableInfo<$PurchaseHistoryTableTable, PurchaseHistoryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _canonicalItemIdMeta =
      const VerificationMeta('canonicalItemId');
  @override
  late final GeneratedColumn<String> canonicalItemId = GeneratedColumn<String>(
      'canonical_item_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _listItemIdMeta =
      const VerificationMeta('listItemId');
  @override
  late final GeneratedColumn<String> listItemId = GeneratedColumn<String>(
      'list_item_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _purchasedAtMeta =
      const VerificationMeta('purchasedAt');
  @override
  late final GeneratedColumn<DateTime> purchasedAt = GeneratedColumn<DateTime>(
      'purchased_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        canonicalItemId,
        listItemId,
        quantity,
        unit,
        version,
        purchasedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_history_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<PurchaseHistoryTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('canonical_item_id')) {
      context.handle(
          _canonicalItemIdMeta,
          canonicalItemId.isAcceptableOrUnknown(
              data['canonical_item_id']!, _canonicalItemIdMeta));
    }
    if (data.containsKey('list_item_id')) {
      context.handle(
          _listItemIdMeta,
          listItemId.isAcceptableOrUnknown(
              data['list_item_id']!, _listItemIdMeta));
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('purchased_at')) {
      context.handle(
          _purchasedAtMeta,
          purchasedAt.isAcceptableOrUnknown(
              data['purchased_at']!, _purchasedAtMeta));
    } else if (isInserting) {
      context.missing(_purchasedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PurchaseHistoryTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseHistoryTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      canonicalItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}canonical_item_id']),
      listItemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}list_item_id']),
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      purchasedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}purchased_at'])!,
    );
  }

  @override
  $PurchaseHistoryTableTable createAlias(String alias) {
    return $PurchaseHistoryTableTable(attachedDatabase, alias);
  }
}

class PurchaseHistoryTableData extends DataClass
    implements Insertable<PurchaseHistoryTableData> {
  final String id;
  final String groupId;
  final String? canonicalItemId;
  final String? listItemId;
  final double quantity;
  final String unit;
  final int version;
  final DateTime purchasedAt;
  const PurchaseHistoryTableData(
      {required this.id,
      required this.groupId,
      this.canonicalItemId,
      this.listItemId,
      required this.quantity,
      required this.unit,
      required this.version,
      required this.purchasedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    if (!nullToAbsent || canonicalItemId != null) {
      map['canonical_item_id'] = Variable<String>(canonicalItemId);
    }
    if (!nullToAbsent || listItemId != null) {
      map['list_item_id'] = Variable<String>(listItemId);
    }
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    map['version'] = Variable<int>(version);
    map['purchased_at'] = Variable<DateTime>(purchasedAt);
    return map;
  }

  PurchaseHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return PurchaseHistoryTableCompanion(
      id: Value(id),
      groupId: Value(groupId),
      canonicalItemId: canonicalItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(canonicalItemId),
      listItemId: listItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(listItemId),
      quantity: Value(quantity),
      unit: Value(unit),
      version: Value(version),
      purchasedAt: Value(purchasedAt),
    );
  }

  factory PurchaseHistoryTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseHistoryTableData(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      canonicalItemId: serializer.fromJson<String?>(json['canonicalItemId']),
      listItemId: serializer.fromJson<String?>(json['listItemId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      version: serializer.fromJson<int>(json['version']),
      purchasedAt: serializer.fromJson<DateTime>(json['purchasedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'canonicalItemId': serializer.toJson<String?>(canonicalItemId),
      'listItemId': serializer.toJson<String?>(listItemId),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
      'version': serializer.toJson<int>(version),
      'purchasedAt': serializer.toJson<DateTime>(purchasedAt),
    };
  }

  PurchaseHistoryTableData copyWith(
          {String? id,
          String? groupId,
          Value<String?> canonicalItemId = const Value.absent(),
          Value<String?> listItemId = const Value.absent(),
          double? quantity,
          String? unit,
          int? version,
          DateTime? purchasedAt}) =>
      PurchaseHistoryTableData(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        canonicalItemId: canonicalItemId.present
            ? canonicalItemId.value
            : this.canonicalItemId,
        listItemId: listItemId.present ? listItemId.value : this.listItemId,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        version: version ?? this.version,
        purchasedAt: purchasedAt ?? this.purchasedAt,
      );
  PurchaseHistoryTableData copyWithCompanion(
      PurchaseHistoryTableCompanion data) {
    return PurchaseHistoryTableData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      canonicalItemId: data.canonicalItemId.present
          ? data.canonicalItemId.value
          : this.canonicalItemId,
      listItemId:
          data.listItemId.present ? data.listItemId.value : this.listItemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      version: data.version.present ? data.version.value : this.version,
      purchasedAt:
          data.purchasedAt.present ? data.purchasedAt.value : this.purchasedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseHistoryTableData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('canonicalItemId: $canonicalItemId, ')
          ..write('listItemId: $listItemId, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('version: $version, ')
          ..write('purchasedAt: $purchasedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, canonicalItemId, listItemId,
      quantity, unit, version, purchasedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseHistoryTableData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.canonicalItemId == this.canonicalItemId &&
          other.listItemId == this.listItemId &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.version == this.version &&
          other.purchasedAt == this.purchasedAt);
}

class PurchaseHistoryTableCompanion
    extends UpdateCompanion<PurchaseHistoryTableData> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String?> canonicalItemId;
  final Value<String?> listItemId;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<int> version;
  final Value<DateTime> purchasedAt;
  final Value<int> rowid;
  const PurchaseHistoryTableCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.canonicalItemId = const Value.absent(),
    this.listItemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.version = const Value.absent(),
    this.purchasedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchaseHistoryTableCompanion.insert({
    required String id,
    required String groupId,
    this.canonicalItemId = const Value.absent(),
    this.listItemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime purchasedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        purchasedAt = Value(purchasedAt);
  static Insertable<PurchaseHistoryTableData> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? canonicalItemId,
    Expression<String>? listItemId,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<int>? version,
    Expression<DateTime>? purchasedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (canonicalItemId != null) 'canonical_item_id': canonicalItemId,
      if (listItemId != null) 'list_item_id': listItemId,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (version != null) 'version': version,
      if (purchasedAt != null) 'purchased_at': purchasedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchaseHistoryTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String?>? canonicalItemId,
      Value<String?>? listItemId,
      Value<double>? quantity,
      Value<String>? unit,
      Value<int>? version,
      Value<DateTime>? purchasedAt,
      Value<int>? rowid}) {
    return PurchaseHistoryTableCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      canonicalItemId: canonicalItemId ?? this.canonicalItemId,
      listItemId: listItemId ?? this.listItemId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      version: version ?? this.version,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (canonicalItemId.present) {
      map['canonical_item_id'] = Variable<String>(canonicalItemId.value);
    }
    if (listItemId.present) {
      map['list_item_id'] = Variable<String>(listItemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (purchasedAt.present) {
      map['purchased_at'] = Variable<DateTime>(purchasedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseHistoryTableCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('canonicalItemId: $canonicalItemId, ')
          ..write('listItemId: $listItemId, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('version: $version, ')
          ..write('purchasedAt: $purchasedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemCooccurrenceTableTable extends ItemCooccurrenceTable
    with TableInfo<$ItemCooccurrenceTableTable, ItemCooccurrenceTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemCooccurrenceTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemAIdMeta =
      const VerificationMeta('itemAId');
  @override
  late final GeneratedColumn<String> itemAId = GeneratedColumn<String>(
      'item_a_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemBIdMeta =
      const VerificationMeta('itemBId');
  @override
  late final GeneratedColumn<String> itemBId = GeneratedColumn<String>(
      'item_b_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
      'count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [groupId, itemAId, itemBId, count, lastSeenAt, version];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_cooccurrence_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ItemCooccurrenceTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('item_a_id')) {
      context.handle(_itemAIdMeta,
          itemAId.isAcceptableOrUnknown(data['item_a_id']!, _itemAIdMeta));
    } else if (isInserting) {
      context.missing(_itemAIdMeta);
    }
    if (data.containsKey('item_b_id')) {
      context.handle(_itemBIdMeta,
          itemBId.isAcceptableOrUnknown(data['item_b_id']!, _itemBIdMeta));
    } else if (isInserting) {
      context.missing(_itemBIdMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
          _countMeta, count.isAcceptableOrUnknown(data['count']!, _countMeta));
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, itemAId, itemBId};
  @override
  ItemCooccurrenceTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemCooccurrenceTableData(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      itemAId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_a_id'])!,
      itemBId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_b_id'])!,
      count: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}count'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
    );
  }

  @override
  $ItemCooccurrenceTableTable createAlias(String alias) {
    return $ItemCooccurrenceTableTable(attachedDatabase, alias);
  }
}

class ItemCooccurrenceTableData extends DataClass
    implements Insertable<ItemCooccurrenceTableData> {
  final String groupId;
  final String itemAId;
  final String itemBId;
  final int count;
  final DateTime lastSeenAt;
  final int version;
  const ItemCooccurrenceTableData(
      {required this.groupId,
      required this.itemAId,
      required this.itemBId,
      required this.count,
      required this.lastSeenAt,
      required this.version});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['item_a_id'] = Variable<String>(itemAId);
    map['item_b_id'] = Variable<String>(itemBId);
    map['count'] = Variable<int>(count);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['version'] = Variable<int>(version);
    return map;
  }

  ItemCooccurrenceTableCompanion toCompanion(bool nullToAbsent) {
    return ItemCooccurrenceTableCompanion(
      groupId: Value(groupId),
      itemAId: Value(itemAId),
      itemBId: Value(itemBId),
      count: Value(count),
      lastSeenAt: Value(lastSeenAt),
      version: Value(version),
    );
  }

  factory ItemCooccurrenceTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemCooccurrenceTableData(
      groupId: serializer.fromJson<String>(json['groupId']),
      itemAId: serializer.fromJson<String>(json['itemAId']),
      itemBId: serializer.fromJson<String>(json['itemBId']),
      count: serializer.fromJson<int>(json['count']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'itemAId': serializer.toJson<String>(itemAId),
      'itemBId': serializer.toJson<String>(itemBId),
      'count': serializer.toJson<int>(count),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'version': serializer.toJson<int>(version),
    };
  }

  ItemCooccurrenceTableData copyWith(
          {String? groupId,
          String? itemAId,
          String? itemBId,
          int? count,
          DateTime? lastSeenAt,
          int? version}) =>
      ItemCooccurrenceTableData(
        groupId: groupId ?? this.groupId,
        itemAId: itemAId ?? this.itemAId,
        itemBId: itemBId ?? this.itemBId,
        count: count ?? this.count,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        version: version ?? this.version,
      );
  ItemCooccurrenceTableData copyWithCompanion(
      ItemCooccurrenceTableCompanion data) {
    return ItemCooccurrenceTableData(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      itemAId: data.itemAId.present ? data.itemAId.value : this.itemAId,
      itemBId: data.itemBId.present ? data.itemBId.value : this.itemBId,
      count: data.count.present ? data.count.value : this.count,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemCooccurrenceTableData(')
          ..write('groupId: $groupId, ')
          ..write('itemAId: $itemAId, ')
          ..write('itemBId: $itemBId, ')
          ..write('count: $count, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(groupId, itemAId, itemBId, count, lastSeenAt, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemCooccurrenceTableData &&
          other.groupId == this.groupId &&
          other.itemAId == this.itemAId &&
          other.itemBId == this.itemBId &&
          other.count == this.count &&
          other.lastSeenAt == this.lastSeenAt &&
          other.version == this.version);
}

class ItemCooccurrenceTableCompanion
    extends UpdateCompanion<ItemCooccurrenceTableData> {
  final Value<String> groupId;
  final Value<String> itemAId;
  final Value<String> itemBId;
  final Value<int> count;
  final Value<DateTime> lastSeenAt;
  final Value<int> version;
  final Value<int> rowid;
  const ItemCooccurrenceTableCompanion({
    this.groupId = const Value.absent(),
    this.itemAId = const Value.absent(),
    this.itemBId = const Value.absent(),
    this.count = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemCooccurrenceTableCompanion.insert({
    required String groupId,
    required String itemAId,
    required String itemBId,
    this.count = const Value.absent(),
    required DateTime lastSeenAt,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        itemAId = Value(itemAId),
        itemBId = Value(itemBId),
        lastSeenAt = Value(lastSeenAt);
  static Insertable<ItemCooccurrenceTableData> custom({
    Expression<String>? groupId,
    Expression<String>? itemAId,
    Expression<String>? itemBId,
    Expression<int>? count,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (itemAId != null) 'item_a_id': itemAId,
      if (itemBId != null) 'item_b_id': itemBId,
      if (count != null) 'count': count,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemCooccurrenceTableCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? itemAId,
      Value<String>? itemBId,
      Value<int>? count,
      Value<DateTime>? lastSeenAt,
      Value<int>? version,
      Value<int>? rowid}) {
    return ItemCooccurrenceTableCompanion(
      groupId: groupId ?? this.groupId,
      itemAId: itemAId ?? this.itemAId,
      itemBId: itemBId ?? this.itemBId,
      count: count ?? this.count,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (itemAId.present) {
      map['item_a_id'] = Variable<String>(itemAId.value);
    }
    if (itemBId.present) {
      map['item_b_id'] = Variable<String>(itemBId.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemCooccurrenceTableCompanion(')
          ..write('groupId: $groupId, ')
          ..write('itemAId: $itemAId, ')
          ..write('itemBId: $itemBId, ')
          ..write('count: $count, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanArtifactsTableTable extends ScanArtifactsTable
    with TableInfo<$ScanArtifactsTableTable, ScanArtifactsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanArtifactsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageRefMeta =
      const VerificationMeta('imageRef');
  @override
  late final GeneratedColumn<String> imageRef = GeneratedColumn<String>(
      'image_ref', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _engineMeta = const VerificationMeta('engine');
  @override
  late final GeneratedColumn<String> engine = GeneratedColumn<String>(
      'engine', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('ppocrv6-small-det-medium-rec-onnx'));
  static const VerificationMeta _rawJsonMeta =
      const VerificationMeta('rawJson');
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
      'raw_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resolvedJsonMeta =
      const VerificationMeta('resolvedJson');
  @override
  late final GeneratedColumn<String> resolvedJson = GeneratedColumn<String>(
      'resolved_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        userId,
        imageRef,
        engine,
        rawJson,
        resolvedJson,
        version,
        createdAt,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_artifacts_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ScanArtifactsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('image_ref')) {
      context.handle(_imageRefMeta,
          imageRef.isAcceptableOrUnknown(data['image_ref']!, _imageRefMeta));
    }
    if (data.containsKey('engine')) {
      context.handle(_engineMeta,
          engine.isAcceptableOrUnknown(data['engine']!, _engineMeta));
    }
    if (data.containsKey('raw_json')) {
      context.handle(_rawJsonMeta,
          rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta));
    }
    if (data.containsKey('resolved_json')) {
      context.handle(
          _resolvedJsonMeta,
          resolvedJson.isAcceptableOrUnknown(
              data['resolved_json']!, _resolvedJsonMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanArtifactsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanArtifactsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id']),
      imageRef: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_ref'])!,
      engine: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}engine'])!,
      rawJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_json']),
      resolvedJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resolved_json']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
    );
  }

  @override
  $ScanArtifactsTableTable createAlias(String alias) {
    return $ScanArtifactsTableTable(attachedDatabase, alias);
  }
}

class ScanArtifactsTableData extends DataClass
    implements Insertable<ScanArtifactsTableData> {
  final String id;
  final String groupId;
  final String? userId;
  final String imageRef;
  final String engine;
  final String? rawJson;
  final String? resolvedJson;
  final int version;
  final DateTime createdAt;
  final DateTime? syncedAt;
  const ScanArtifactsTableData(
      {required this.id,
      required this.groupId,
      this.userId,
      required this.imageRef,
      required this.engine,
      this.rawJson,
      this.resolvedJson,
      required this.version,
      required this.createdAt,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['image_ref'] = Variable<String>(imageRef);
    map['engine'] = Variable<String>(engine);
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    if (!nullToAbsent || resolvedJson != null) {
      map['resolved_json'] = Variable<String>(resolvedJson);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  ScanArtifactsTableCompanion toCompanion(bool nullToAbsent) {
    return ScanArtifactsTableCompanion(
      id: Value(id),
      groupId: Value(groupId),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      imageRef: Value(imageRef),
      engine: Value(engine),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
      resolvedJson: resolvedJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedJson),
      version: Value(version),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory ScanArtifactsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanArtifactsTableData(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      userId: serializer.fromJson<String?>(json['userId']),
      imageRef: serializer.fromJson<String>(json['imageRef']),
      engine: serializer.fromJson<String>(json['engine']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
      resolvedJson: serializer.fromJson<String?>(json['resolvedJson']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'userId': serializer.toJson<String?>(userId),
      'imageRef': serializer.toJson<String>(imageRef),
      'engine': serializer.toJson<String>(engine),
      'rawJson': serializer.toJson<String?>(rawJson),
      'resolvedJson': serializer.toJson<String?>(resolvedJson),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  ScanArtifactsTableData copyWith(
          {String? id,
          String? groupId,
          Value<String?> userId = const Value.absent(),
          String? imageRef,
          String? engine,
          Value<String?> rawJson = const Value.absent(),
          Value<String?> resolvedJson = const Value.absent(),
          int? version,
          DateTime? createdAt,
          Value<DateTime?> syncedAt = const Value.absent()}) =>
      ScanArtifactsTableData(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        userId: userId.present ? userId.value : this.userId,
        imageRef: imageRef ?? this.imageRef,
        engine: engine ?? this.engine,
        rawJson: rawJson.present ? rawJson.value : this.rawJson,
        resolvedJson:
            resolvedJson.present ? resolvedJson.value : this.resolvedJson,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  ScanArtifactsTableData copyWithCompanion(ScanArtifactsTableCompanion data) {
    return ScanArtifactsTableData(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      userId: data.userId.present ? data.userId.value : this.userId,
      imageRef: data.imageRef.present ? data.imageRef.value : this.imageRef,
      engine: data.engine.present ? data.engine.value : this.engine,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      resolvedJson: data.resolvedJson.present
          ? data.resolvedJson.value
          : this.resolvedJson,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanArtifactsTableData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('userId: $userId, ')
          ..write('imageRef: $imageRef, ')
          ..write('engine: $engine, ')
          ..write('rawJson: $rawJson, ')
          ..write('resolvedJson: $resolvedJson, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, userId, imageRef, engine,
      rawJson, resolvedJson, version, createdAt, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanArtifactsTableData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.userId == this.userId &&
          other.imageRef == this.imageRef &&
          other.engine == this.engine &&
          other.rawJson == this.rawJson &&
          other.resolvedJson == this.resolvedJson &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class ScanArtifactsTableCompanion
    extends UpdateCompanion<ScanArtifactsTableData> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String?> userId;
  final Value<String> imageRef;
  final Value<String> engine;
  final Value<String?> rawJson;
  final Value<String?> resolvedJson;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const ScanArtifactsTableCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.userId = const Value.absent(),
    this.imageRef = const Value.absent(),
    this.engine = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.resolvedJson = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanArtifactsTableCompanion.insert({
    required String id,
    required String groupId,
    this.userId = const Value.absent(),
    this.imageRef = const Value.absent(),
    this.engine = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.resolvedJson = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        createdAt = Value(createdAt);
  static Insertable<ScanArtifactsTableData> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? userId,
    Expression<String>? imageRef,
    Expression<String>? engine,
    Expression<String>? rawJson,
    Expression<String>? resolvedJson,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (userId != null) 'user_id': userId,
      if (imageRef != null) 'image_ref': imageRef,
      if (engine != null) 'engine': engine,
      if (rawJson != null) 'raw_json': rawJson,
      if (resolvedJson != null) 'resolved_json': resolvedJson,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanArtifactsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String?>? userId,
      Value<String>? imageRef,
      Value<String>? engine,
      Value<String?>? rawJson,
      Value<String?>? resolvedJson,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<DateTime?>? syncedAt,
      Value<int>? rowid}) {
    return ScanArtifactsTableCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      imageRef: imageRef ?? this.imageRef,
      engine: engine ?? this.engine,
      rawJson: rawJson ?? this.rawJson,
      resolvedJson: resolvedJson ?? this.resolvedJson,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (imageRef.present) {
      map['image_ref'] = Variable<String>(imageRef.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (resolvedJson.present) {
      map['resolved_json'] = Variable<String>(resolvedJson.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanArtifactsTableCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('userId: $userId, ')
          ..write('imageRef: $imageRef, ')
          ..write('engine: $engine, ')
          ..write('rawJson: $rawJson, ')
          ..write('resolvedJson: $resolvedJson, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroceryVersionsTableTable extends GroceryVersionsTable
    with TableInfo<$GroceryVersionsTableTable, GroceryVersionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroceryVersionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currentVersionMeta =
      const VerificationMeta('currentVersion');
  @override
  late final GeneratedColumn<int> currentVersion = GeneratedColumn<int>(
      'current_version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [groupId, currentVersion, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'grocery_versions_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<GroceryVersionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('current_version')) {
      context.handle(
          _currentVersionMeta,
          currentVersion.isAcceptableOrUnknown(
              data['current_version']!, _currentVersionMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  GroceryVersionsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroceryVersionsTableData(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      currentVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_version'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $GroceryVersionsTableTable createAlias(String alias) {
    return $GroceryVersionsTableTable(attachedDatabase, alias);
  }
}

class GroceryVersionsTableData extends DataClass
    implements Insertable<GroceryVersionsTableData> {
  final String groupId;
  final int currentVersion;
  final DateTime updatedAt;
  const GroceryVersionsTableData(
      {required this.groupId,
      required this.currentVersion,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['current_version'] = Variable<int>(currentVersion);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GroceryVersionsTableCompanion toCompanion(bool nullToAbsent) {
    return GroceryVersionsTableCompanion(
      groupId: Value(groupId),
      currentVersion: Value(currentVersion),
      updatedAt: Value(updatedAt),
    );
  }

  factory GroceryVersionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroceryVersionsTableData(
      groupId: serializer.fromJson<String>(json['groupId']),
      currentVersion: serializer.fromJson<int>(json['currentVersion']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'currentVersion': serializer.toJson<int>(currentVersion),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GroceryVersionsTableData copyWith(
          {String? groupId, int? currentVersion, DateTime? updatedAt}) =>
      GroceryVersionsTableData(
        groupId: groupId ?? this.groupId,
        currentVersion: currentVersion ?? this.currentVersion,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  GroceryVersionsTableData copyWithCompanion(
      GroceryVersionsTableCompanion data) {
    return GroceryVersionsTableData(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      currentVersion: data.currentVersion.present
          ? data.currentVersion.value
          : this.currentVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroceryVersionsTableData(')
          ..write('groupId: $groupId, ')
          ..write('currentVersion: $currentVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, currentVersion, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroceryVersionsTableData &&
          other.groupId == this.groupId &&
          other.currentVersion == this.currentVersion &&
          other.updatedAt == this.updatedAt);
}

class GroceryVersionsTableCompanion
    extends UpdateCompanion<GroceryVersionsTableData> {
  final Value<String> groupId;
  final Value<int> currentVersion;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GroceryVersionsTableCompanion({
    this.groupId = const Value.absent(),
    this.currentVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroceryVersionsTableCompanion.insert({
    required String groupId,
    this.currentVersion = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        updatedAt = Value(updatedAt);
  static Insertable<GroceryVersionsTableData> custom({
    Expression<String>? groupId,
    Expression<int>? currentVersion,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (currentVersion != null) 'current_version': currentVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroceryVersionsTableCompanion copyWith(
      {Value<String>? groupId,
      Value<int>? currentVersion,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return GroceryVersionsTableCompanion(
      groupId: groupId ?? this.groupId,
      currentVersion: currentVersion ?? this.currentVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (currentVersion.present) {
      map['current_version'] = Variable<int>(currentVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroceryVersionsTableCompanion(')
          ..write('groupId: $groupId, ')
          ..write('currentVersion: $currentVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalItemSignalsTableTable extends LocalItemSignalsTable
    with TableInfo<$LocalItemSignalsTableTable, LocalItemSignalsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalItemSignalsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedNameMeta =
      const VerificationMeta('normalizedName');
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
      'normalized_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
      'count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _promotedCanonicalItemIdMeta =
      const VerificationMeta('promotedCanonicalItemId');
  @override
  late final GeneratedColumn<String> promotedCanonicalItemId =
      GeneratedColumn<String>('promoted_canonical_item_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _firstSeenMeta =
      const VerificationMeta('firstSeen');
  @override
  late final GeneratedColumn<DateTime> firstSeen = GeneratedColumn<DateTime>(
      'first_seen', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenMeta =
      const VerificationMeta('lastSeen');
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
      'last_seen', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        groupId,
        normalizedName,
        displayName,
        count,
        promotedCanonicalItemId,
        firstSeen,
        lastSeen
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_item_signals_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalItemSignalsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
          _normalizedNameMeta,
          normalizedName.isAcceptableOrUnknown(
              data['normalized_name']!, _normalizedNameMeta));
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
          _countMeta, count.isAcceptableOrUnknown(data['count']!, _countMeta));
    }
    if (data.containsKey('promoted_canonical_item_id')) {
      context.handle(
          _promotedCanonicalItemIdMeta,
          promotedCanonicalItemId.isAcceptableOrUnknown(
              data['promoted_canonical_item_id']!,
              _promotedCanonicalItemIdMeta));
    }
    if (data.containsKey('first_seen')) {
      context.handle(_firstSeenMeta,
          firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta));
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(_lastSeenMeta,
          lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta));
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, normalizedName};
  @override
  LocalItemSignalsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalItemSignalsTableData(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      normalizedName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_name'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      count: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}count'])!,
      promotedCanonicalItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}promoted_canonical_item_id']),
      firstSeen: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}first_seen'])!,
      lastSeen: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen'])!,
    );
  }

  @override
  $LocalItemSignalsTableTable createAlias(String alias) {
    return $LocalItemSignalsTableTable(attachedDatabase, alias);
  }
}

class LocalItemSignalsTableData extends DataClass
    implements Insertable<LocalItemSignalsTableData> {
  final String groupId;
  final String normalizedName;
  final String displayName;
  final int count;

  /// Set once the word crossed the threshold and a canonical was minted. Guards
  /// against re-minting: later check-offs reinforce the existing alias instead.
  final String? promotedCanonicalItemId;
  final DateTime firstSeen;
  final DateTime lastSeen;
  const LocalItemSignalsTableData(
      {required this.groupId,
      required this.normalizedName,
      required this.displayName,
      required this.count,
      this.promotedCanonicalItemId,
      required this.firstSeen,
      required this.lastSeen});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['display_name'] = Variable<String>(displayName);
    map['count'] = Variable<int>(count);
    if (!nullToAbsent || promotedCanonicalItemId != null) {
      map['promoted_canonical_item_id'] =
          Variable<String>(promotedCanonicalItemId);
    }
    map['first_seen'] = Variable<DateTime>(firstSeen);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    return map;
  }

  LocalItemSignalsTableCompanion toCompanion(bool nullToAbsent) {
    return LocalItemSignalsTableCompanion(
      groupId: Value(groupId),
      normalizedName: Value(normalizedName),
      displayName: Value(displayName),
      count: Value(count),
      promotedCanonicalItemId: promotedCanonicalItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(promotedCanonicalItemId),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
    );
  }

  factory LocalItemSignalsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalItemSignalsTableData(
      groupId: serializer.fromJson<String>(json['groupId']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      displayName: serializer.fromJson<String>(json['displayName']),
      count: serializer.fromJson<int>(json['count']),
      promotedCanonicalItemId:
          serializer.fromJson<String?>(json['promotedCanonicalItemId']),
      firstSeen: serializer.fromJson<DateTime>(json['firstSeen']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'displayName': serializer.toJson<String>(displayName),
      'count': serializer.toJson<int>(count),
      'promotedCanonicalItemId':
          serializer.toJson<String?>(promotedCanonicalItemId),
      'firstSeen': serializer.toJson<DateTime>(firstSeen),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
    };
  }

  LocalItemSignalsTableData copyWith(
          {String? groupId,
          String? normalizedName,
          String? displayName,
          int? count,
          Value<String?> promotedCanonicalItemId = const Value.absent(),
          DateTime? firstSeen,
          DateTime? lastSeen}) =>
      LocalItemSignalsTableData(
        groupId: groupId ?? this.groupId,
        normalizedName: normalizedName ?? this.normalizedName,
        displayName: displayName ?? this.displayName,
        count: count ?? this.count,
        promotedCanonicalItemId: promotedCanonicalItemId.present
            ? promotedCanonicalItemId.value
            : this.promotedCanonicalItemId,
        firstSeen: firstSeen ?? this.firstSeen,
        lastSeen: lastSeen ?? this.lastSeen,
      );
  LocalItemSignalsTableData copyWithCompanion(
      LocalItemSignalsTableCompanion data) {
    return LocalItemSignalsTableData(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      count: data.count.present ? data.count.value : this.count,
      promotedCanonicalItemId: data.promotedCanonicalItemId.present
          ? data.promotedCanonicalItemId.value
          : this.promotedCanonicalItemId,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalItemSignalsTableData(')
          ..write('groupId: $groupId, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('displayName: $displayName, ')
          ..write('count: $count, ')
          ..write('promotedCanonicalItemId: $promotedCanonicalItemId, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, normalizedName, displayName, count,
      promotedCanonicalItemId, firstSeen, lastSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalItemSignalsTableData &&
          other.groupId == this.groupId &&
          other.normalizedName == this.normalizedName &&
          other.displayName == this.displayName &&
          other.count == this.count &&
          other.promotedCanonicalItemId == this.promotedCanonicalItemId &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen);
}

class LocalItemSignalsTableCompanion
    extends UpdateCompanion<LocalItemSignalsTableData> {
  final Value<String> groupId;
  final Value<String> normalizedName;
  final Value<String> displayName;
  final Value<int> count;
  final Value<String?> promotedCanonicalItemId;
  final Value<DateTime> firstSeen;
  final Value<DateTime> lastSeen;
  final Value<int> rowid;
  const LocalItemSignalsTableCompanion({
    this.groupId = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.displayName = const Value.absent(),
    this.count = const Value.absent(),
    this.promotedCanonicalItemId = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalItemSignalsTableCompanion.insert({
    required String groupId,
    required String normalizedName,
    required String displayName,
    this.count = const Value.absent(),
    this.promotedCanonicalItemId = const Value.absent(),
    required DateTime firstSeen,
    required DateTime lastSeen,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        normalizedName = Value(normalizedName),
        displayName = Value(displayName),
        firstSeen = Value(firstSeen),
        lastSeen = Value(lastSeen);
  static Insertable<LocalItemSignalsTableData> custom({
    Expression<String>? groupId,
    Expression<String>? normalizedName,
    Expression<String>? displayName,
    Expression<int>? count,
    Expression<String>? promotedCanonicalItemId,
    Expression<DateTime>? firstSeen,
    Expression<DateTime>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (displayName != null) 'display_name': displayName,
      if (count != null) 'count': count,
      if (promotedCanonicalItemId != null)
        'promoted_canonical_item_id': promotedCanonicalItemId,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalItemSignalsTableCompanion copyWith(
      {Value<String>? groupId,
      Value<String>? normalizedName,
      Value<String>? displayName,
      Value<int>? count,
      Value<String?>? promotedCanonicalItemId,
      Value<DateTime>? firstSeen,
      Value<DateTime>? lastSeen,
      Value<int>? rowid}) {
    return LocalItemSignalsTableCompanion(
      groupId: groupId ?? this.groupId,
      normalizedName: normalizedName ?? this.normalizedName,
      displayName: displayName ?? this.displayName,
      count: count ?? this.count,
      promotedCanonicalItemId:
          promotedCanonicalItemId ?? this.promotedCanonicalItemId,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (promotedCanonicalItemId.present) {
      map['promoted_canonical_item_id'] =
          Variable<String>(promotedCanonicalItemId.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<DateTime>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalItemSignalsTableCompanion(')
          ..write('groupId: $groupId, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('displayName: $displayName, ')
          ..write('count: $count, ')
          ..write('promotedCanonicalItemId: $promotedCanonicalItemId, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ListsTableTable listsTable = $ListsTableTable(this);
  late final $ListItemsTableTable listItemsTable = $ListItemsTableTable(this);
  late final $ExpensesTableTable expensesTable = $ExpensesTableTable(this);
  late final $FinanceSummariesTable financeSummaries =
      $FinanceSummariesTable(this);
  late final $CurrentChoresCachesTable currentChoresCaches =
      $CurrentChoresCachesTable(this);
  late final $RecipesTableTable recipesTable = $RecipesTableTable(this);
  late final $PinwallPostsCachesTable pinwallPostsCaches =
      $PinwallPostsCachesTable(this);
  late final $HubGroupCachesTable hubGroupCaches = $HubGroupCachesTable(this);
  late final $HubActivityCachesTable hubActivityCaches =
      $HubActivityCachesTable(this);
  late final $GroupsCachesTable groupsCaches = $GroupsCachesTable(this);
  late final $SettlementsCachesTable settlementsCaches =
      $SettlementsCachesTable(this);
  late final $CalendarCachesTable calendarCaches = $CalendarCachesTable(this);
  late final $MealPlanCachesTable mealPlanCaches = $MealPlanCachesTable(this);
  late final $ResponseCachesTable responseCaches = $ResponseCachesTable(this);
  late final $OutboxOpsTable outboxOps = $OutboxOpsTable(this);
  late final $ConflictsTable conflicts = $ConflictsTable(this);
  late final $CanonicalItemsTableTable canonicalItemsTable =
      $CanonicalItemsTableTable(this);
  late final $ItemAliasesTableTable itemAliasesTable =
      $ItemAliasesTableTable(this);
  late final $CorrectionsTableTable correctionsTable =
      $CorrectionsTableTable(this);
  late final $StoreAislesTableTable storeAislesTable =
      $StoreAislesTableTable(this);
  late final $PurchaseHistoryTableTable purchaseHistoryTable =
      $PurchaseHistoryTableTable(this);
  late final $ItemCooccurrenceTableTable itemCooccurrenceTable =
      $ItemCooccurrenceTableTable(this);
  late final $ScanArtifactsTableTable scanArtifactsTable =
      $ScanArtifactsTableTable(this);
  late final $GroceryVersionsTableTable groceryVersionsTable =
      $GroceryVersionsTableTable(this);
  late final $LocalItemSignalsTableTable localItemSignalsTable =
      $LocalItemSignalsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        listsTable,
        listItemsTable,
        expensesTable,
        financeSummaries,
        currentChoresCaches,
        recipesTable,
        pinwallPostsCaches,
        hubGroupCaches,
        hubActivityCaches,
        groupsCaches,
        settlementsCaches,
        calendarCaches,
        mealPlanCaches,
        responseCaches,
        outboxOps,
        conflicts,
        canonicalItemsTable,
        itemAliasesTable,
        correctionsTable,
        storeAislesTable,
        purchaseHistoryTable,
        itemCooccurrenceTable,
        scanArtifactsTable,
        groceryVersionsTable,
        localItemSignalsTable
      ];
}

typedef $$ListsTableTableCreateCompanionBuilder = ListsTableCompanion Function({
  required String id,
  required String groupId,
  required String name,
  required String type,
  Value<int?> itemCount,
  Value<String> itemPreviewJson,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ListsTableTableUpdateCompanionBuilder = ListsTableCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> name,
  Value<String> type,
  Value<int?> itemCount,
  Value<String> itemPreviewJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ListsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ListsTableTable> {
  $$ListsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get itemCount => $composableBuilder(
      column: $table.itemCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemPreviewJson => $composableBuilder(
      column: $table.itemPreviewJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ListsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ListsTableTable> {
  $$ListsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get itemCount => $composableBuilder(
      column: $table.itemCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemPreviewJson => $composableBuilder(
      column: $table.itemPreviewJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ListsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListsTableTable> {
  $$ListsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<String> get itemPreviewJson => $composableBuilder(
      column: $table.itemPreviewJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ListsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ListsTableTable,
    ListsTableData,
    $$ListsTableTableFilterComposer,
    $$ListsTableTableOrderingComposer,
    $$ListsTableTableAnnotationComposer,
    $$ListsTableTableCreateCompanionBuilder,
    $$ListsTableTableUpdateCompanionBuilder,
    (
      ListsTableData,
      BaseReferences<_$AppDatabase, $ListsTableTable, ListsTableData>
    ),
    ListsTableData,
    PrefetchHooks Function()> {
  $$ListsTableTableTableManager(_$AppDatabase db, $ListsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int?> itemCount = const Value.absent(),
            Value<String> itemPreviewJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ListsTableCompanion(
            id: id,
            groupId: groupId,
            name: name,
            type: type,
            itemCount: itemCount,
            itemPreviewJson: itemPreviewJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            required String name,
            required String type,
            Value<int?> itemCount = const Value.absent(),
            Value<String> itemPreviewJson = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ListsTableCompanion.insert(
            id: id,
            groupId: groupId,
            name: name,
            type: type,
            itemCount: itemCount,
            itemPreviewJson: itemPreviewJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ListsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ListsTableTable,
    ListsTableData,
    $$ListsTableTableFilterComposer,
    $$ListsTableTableOrderingComposer,
    $$ListsTableTableAnnotationComposer,
    $$ListsTableTableCreateCompanionBuilder,
    $$ListsTableTableUpdateCompanionBuilder,
    (
      ListsTableData,
      BaseReferences<_$AppDatabase, $ListsTableTable, ListsTableData>
    ),
    ListsTableData,
    PrefetchHooks Function()>;
typedef $$ListItemsTableTableCreateCompanionBuilder = ListItemsTableCompanion
    Function({
  required String id,
  required String listId,
  required String name,
  required double quantity,
  required String unit,
  required bool checked,
  required int position,
  Value<int?> priceCents,
  Value<String?> canonicalItemId,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ListItemsTableTableUpdateCompanionBuilder = ListItemsTableCompanion
    Function({
  Value<String> id,
  Value<String> listId,
  Value<String> name,
  Value<double> quantity,
  Value<String> unit,
  Value<bool> checked,
  Value<int> position,
  Value<int?> priceCents,
  Value<String?> canonicalItemId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ListItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ListItemsTableTable> {
  $$ListItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get listId => $composableBuilder(
      column: $table.listId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checked => $composableBuilder(
      column: $table.checked, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceCents => $composableBuilder(
      column: $table.priceCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ListItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ListItemsTableTable> {
  $$ListItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get listId => $composableBuilder(
      column: $table.listId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checked => $composableBuilder(
      column: $table.checked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceCents => $composableBuilder(
      column: $table.priceCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ListItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListItemsTableTable> {
  $$ListItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<bool> get checked =>
      $composableBuilder(column: $table.checked, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get priceCents => $composableBuilder(
      column: $table.priceCents, builder: (column) => column);

  GeneratedColumn<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ListItemsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ListItemsTableTable,
    ListItemsTableData,
    $$ListItemsTableTableFilterComposer,
    $$ListItemsTableTableOrderingComposer,
    $$ListItemsTableTableAnnotationComposer,
    $$ListItemsTableTableCreateCompanionBuilder,
    $$ListItemsTableTableUpdateCompanionBuilder,
    (
      ListItemsTableData,
      BaseReferences<_$AppDatabase, $ListItemsTableTable, ListItemsTableData>
    ),
    ListItemsTableData,
    PrefetchHooks Function()> {
  $$ListItemsTableTableTableManager(
      _$AppDatabase db, $ListItemsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListItemsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListItemsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListItemsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> listId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<bool> checked = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<int?> priceCents = const Value.absent(),
            Value<String?> canonicalItemId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ListItemsTableCompanion(
            id: id,
            listId: listId,
            name: name,
            quantity: quantity,
            unit: unit,
            checked: checked,
            position: position,
            priceCents: priceCents,
            canonicalItemId: canonicalItemId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String listId,
            required String name,
            required double quantity,
            required String unit,
            required bool checked,
            required int position,
            Value<int?> priceCents = const Value.absent(),
            Value<String?> canonicalItemId = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ListItemsTableCompanion.insert(
            id: id,
            listId: listId,
            name: name,
            quantity: quantity,
            unit: unit,
            checked: checked,
            position: position,
            priceCents: priceCents,
            canonicalItemId: canonicalItemId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ListItemsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ListItemsTableTable,
    ListItemsTableData,
    $$ListItemsTableTableFilterComposer,
    $$ListItemsTableTableOrderingComposer,
    $$ListItemsTableTableAnnotationComposer,
    $$ListItemsTableTableCreateCompanionBuilder,
    $$ListItemsTableTableUpdateCompanionBuilder,
    (
      ListItemsTableData,
      BaseReferences<_$AppDatabase, $ListItemsTableTable, ListItemsTableData>
    ),
    ListItemsTableData,
    PrefetchHooks Function()>;
typedef $$ExpensesTableTableCreateCompanionBuilder = ExpensesTableCompanion
    Function({
  required String id,
  required String groupId,
  required String payerId,
  required int amount,
  Value<int> baseAmount,
  Value<double> fxRate,
  required String description,
  required String category,
  required String currency,
  required String notes,
  required DateTime date,
  required DateTime createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});
typedef $$ExpensesTableTableUpdateCompanionBuilder = ExpensesTableCompanion
    Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> payerId,
  Value<int> amount,
  Value<int> baseAmount,
  Value<double> fxRate,
  Value<String> description,
  Value<String> category,
  Value<String> currency,
  Value<String> notes,
  Value<DateTime> date,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> rowid,
});

class $$ExpensesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ExpensesTableTable> {
  $$ExpensesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payerId => $composableBuilder(
      column: $table.payerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get baseAmount => $composableBuilder(
      column: $table.baseAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fxRate => $composableBuilder(
      column: $table.fxRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ExpensesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpensesTableTable> {
  $$ExpensesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payerId => $composableBuilder(
      column: $table.payerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get baseAmount => $composableBuilder(
      column: $table.baseAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fxRate => $composableBuilder(
      column: $table.fxRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ExpensesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpensesTableTable> {
  $$ExpensesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get payerId =>
      $composableBuilder(column: $table.payerId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get baseAmount => $composableBuilder(
      column: $table.baseAmount, builder: (column) => column);

  GeneratedColumn<double> get fxRate =>
      $composableBuilder(column: $table.fxRate, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ExpensesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExpensesTableTable,
    ExpensesTableData,
    $$ExpensesTableTableFilterComposer,
    $$ExpensesTableTableOrderingComposer,
    $$ExpensesTableTableAnnotationComposer,
    $$ExpensesTableTableCreateCompanionBuilder,
    $$ExpensesTableTableUpdateCompanionBuilder,
    (
      ExpensesTableData,
      BaseReferences<_$AppDatabase, $ExpensesTableTable, ExpensesTableData>
    ),
    ExpensesTableData,
    PrefetchHooks Function()> {
  $$ExpensesTableTableTableManager(_$AppDatabase db, $ExpensesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String> payerId = const Value.absent(),
            Value<int> amount = const Value.absent(),
            Value<int> baseAmount = const Value.absent(),
            Value<double> fxRate = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExpensesTableCompanion(
            id: id,
            groupId: groupId,
            payerId: payerId,
            amount: amount,
            baseAmount: baseAmount,
            fxRate: fxRate,
            description: description,
            category: category,
            currency: currency,
            notes: notes,
            date: date,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            required String payerId,
            required int amount,
            Value<int> baseAmount = const Value.absent(),
            Value<double> fxRate = const Value.absent(),
            required String description,
            required String category,
            required String currency,
            required String notes,
            required DateTime date,
            required DateTime createdAt,
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExpensesTableCompanion.insert(
            id: id,
            groupId: groupId,
            payerId: payerId,
            amount: amount,
            baseAmount: baseAmount,
            fxRate: fxRate,
            description: description,
            category: category,
            currency: currency,
            notes: notes,
            date: date,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ExpensesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExpensesTableTable,
    ExpensesTableData,
    $$ExpensesTableTableFilterComposer,
    $$ExpensesTableTableOrderingComposer,
    $$ExpensesTableTableAnnotationComposer,
    $$ExpensesTableTableCreateCompanionBuilder,
    $$ExpensesTableTableUpdateCompanionBuilder,
    (
      ExpensesTableData,
      BaseReferences<_$AppDatabase, $ExpensesTableTable, ExpensesTableData>
    ),
    ExpensesTableData,
    PrefetchHooks Function()>;
typedef $$FinanceSummariesTableCreateCompanionBuilder
    = FinanceSummariesCompanion Function({
  required String groupId,
  required String summaryJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$FinanceSummariesTableUpdateCompanionBuilder
    = FinanceSummariesCompanion Function({
  Value<String> groupId,
  Value<String> summaryJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$FinanceSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $FinanceSummariesTable> {
  $$FinanceSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summaryJson => $composableBuilder(
      column: $table.summaryJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$FinanceSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $FinanceSummariesTable> {
  $$FinanceSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summaryJson => $composableBuilder(
      column: $table.summaryJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$FinanceSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FinanceSummariesTable> {
  $$FinanceSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
      column: $table.summaryJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FinanceSummariesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FinanceSummariesTable,
    FinanceSummary,
    $$FinanceSummariesTableFilterComposer,
    $$FinanceSummariesTableOrderingComposer,
    $$FinanceSummariesTableAnnotationComposer,
    $$FinanceSummariesTableCreateCompanionBuilder,
    $$FinanceSummariesTableUpdateCompanionBuilder,
    (
      FinanceSummary,
      BaseReferences<_$AppDatabase, $FinanceSummariesTable, FinanceSummary>
    ),
    FinanceSummary,
    PrefetchHooks Function()> {
  $$FinanceSummariesTableTableManager(
      _$AppDatabase db, $FinanceSummariesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FinanceSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FinanceSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FinanceSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> summaryJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FinanceSummariesCompanion(
            groupId: groupId,
            summaryJson: summaryJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String summaryJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FinanceSummariesCompanion.insert(
            groupId: groupId,
            summaryJson: summaryJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FinanceSummariesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FinanceSummariesTable,
    FinanceSummary,
    $$FinanceSummariesTableFilterComposer,
    $$FinanceSummariesTableOrderingComposer,
    $$FinanceSummariesTableAnnotationComposer,
    $$FinanceSummariesTableCreateCompanionBuilder,
    $$FinanceSummariesTableUpdateCompanionBuilder,
    (
      FinanceSummary,
      BaseReferences<_$AppDatabase, $FinanceSummariesTable, FinanceSummary>
    ),
    FinanceSummary,
    PrefetchHooks Function()>;
typedef $$CurrentChoresCachesTableCreateCompanionBuilder
    = CurrentChoresCachesCompanion Function({
  required String groupId,
  required String choresJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CurrentChoresCachesTableUpdateCompanionBuilder
    = CurrentChoresCachesCompanion Function({
  Value<String> groupId,
  Value<String> choresJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CurrentChoresCachesTableFilterComposer
    extends Composer<_$AppDatabase, $CurrentChoresCachesTable> {
  $$CurrentChoresCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get choresJson => $composableBuilder(
      column: $table.choresJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CurrentChoresCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $CurrentChoresCachesTable> {
  $$CurrentChoresCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get choresJson => $composableBuilder(
      column: $table.choresJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CurrentChoresCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CurrentChoresCachesTable> {
  $$CurrentChoresCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get choresJson => $composableBuilder(
      column: $table.choresJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CurrentChoresCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CurrentChoresCachesTable,
    CurrentChoresCache,
    $$CurrentChoresCachesTableFilterComposer,
    $$CurrentChoresCachesTableOrderingComposer,
    $$CurrentChoresCachesTableAnnotationComposer,
    $$CurrentChoresCachesTableCreateCompanionBuilder,
    $$CurrentChoresCachesTableUpdateCompanionBuilder,
    (
      CurrentChoresCache,
      BaseReferences<_$AppDatabase, $CurrentChoresCachesTable,
          CurrentChoresCache>
    ),
    CurrentChoresCache,
    PrefetchHooks Function()> {
  $$CurrentChoresCachesTableTableManager(
      _$AppDatabase db, $CurrentChoresCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurrentChoresCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CurrentChoresCachesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CurrentChoresCachesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> choresJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CurrentChoresCachesCompanion(
            groupId: groupId,
            choresJson: choresJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String choresJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CurrentChoresCachesCompanion.insert(
            groupId: groupId,
            choresJson: choresJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CurrentChoresCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CurrentChoresCachesTable,
    CurrentChoresCache,
    $$CurrentChoresCachesTableFilterComposer,
    $$CurrentChoresCachesTableOrderingComposer,
    $$CurrentChoresCachesTableAnnotationComposer,
    $$CurrentChoresCachesTableCreateCompanionBuilder,
    $$CurrentChoresCachesTableUpdateCompanionBuilder,
    (
      CurrentChoresCache,
      BaseReferences<_$AppDatabase, $CurrentChoresCachesTable,
          CurrentChoresCache>
    ),
    CurrentChoresCache,
    PrefetchHooks Function()>;
typedef $$RecipesTableTableCreateCompanionBuilder = RecipesTableCompanion
    Function({
  required String id,
  required String title,
  required String description,
  required int prepTime,
  required int cookTime,
  required int servings,
  Value<String?> imageUrl,
  Value<String> visibility,
  Value<String?> groupId,
  Value<String> tagsJson,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$RecipesTableTableUpdateCompanionBuilder = RecipesTableCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> description,
  Value<int> prepTime,
  Value<int> cookTime,
  Value<int> servings,
  Value<String?> imageUrl,
  Value<String> visibility,
  Value<String?> groupId,
  Value<String> tagsJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$RecipesTableTableFilterComposer
    extends Composer<_$AppDatabase, $RecipesTableTable> {
  $$RecipesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get prepTime => $composableBuilder(
      column: $table.prepTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cookTime => $composableBuilder(
      column: $table.cookTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get servings => $composableBuilder(
      column: $table.servings, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagsJson => $composableBuilder(
      column: $table.tagsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$RecipesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipesTableTable> {
  $$RecipesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get prepTime => $composableBuilder(
      column: $table.prepTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cookTime => $composableBuilder(
      column: $table.cookTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get servings => $composableBuilder(
      column: $table.servings, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagsJson => $composableBuilder(
      column: $table.tagsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecipesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipesTableTable> {
  $$RecipesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get prepTime =>
      $composableBuilder(column: $table.prepTime, builder: (column) => column);

  GeneratedColumn<int> get cookTime =>
      $composableBuilder(column: $table.cookTime, builder: (column) => column);

  GeneratedColumn<int> get servings =>
      $composableBuilder(column: $table.servings, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RecipesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecipesTableTable,
    RecipesTableData,
    $$RecipesTableTableFilterComposer,
    $$RecipesTableTableOrderingComposer,
    $$RecipesTableTableAnnotationComposer,
    $$RecipesTableTableCreateCompanionBuilder,
    $$RecipesTableTableUpdateCompanionBuilder,
    (
      RecipesTableData,
      BaseReferences<_$AppDatabase, $RecipesTableTable, RecipesTableData>
    ),
    RecipesTableData,
    PrefetchHooks Function()> {
  $$RecipesTableTableTableManager(_$AppDatabase db, $RecipesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<int> prepTime = const Value.absent(),
            Value<int> cookTime = const Value.absent(),
            Value<int> servings = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String> visibility = const Value.absent(),
            Value<String?> groupId = const Value.absent(),
            Value<String> tagsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecipesTableCompanion(
            id: id,
            title: title,
            description: description,
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings,
            imageUrl: imageUrl,
            visibility: visibility,
            groupId: groupId,
            tagsJson: tagsJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String description,
            required int prepTime,
            required int cookTime,
            required int servings,
            Value<String?> imageUrl = const Value.absent(),
            Value<String> visibility = const Value.absent(),
            Value<String?> groupId = const Value.absent(),
            Value<String> tagsJson = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecipesTableCompanion.insert(
            id: id,
            title: title,
            description: description,
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings,
            imageUrl: imageUrl,
            visibility: visibility,
            groupId: groupId,
            tagsJson: tagsJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecipesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecipesTableTable,
    RecipesTableData,
    $$RecipesTableTableFilterComposer,
    $$RecipesTableTableOrderingComposer,
    $$RecipesTableTableAnnotationComposer,
    $$RecipesTableTableCreateCompanionBuilder,
    $$RecipesTableTableUpdateCompanionBuilder,
    (
      RecipesTableData,
      BaseReferences<_$AppDatabase, $RecipesTableTable, RecipesTableData>
    ),
    RecipesTableData,
    PrefetchHooks Function()>;
typedef $$PinwallPostsCachesTableCreateCompanionBuilder
    = PinwallPostsCachesCompanion Function({
  required String groupId,
  required String postsJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PinwallPostsCachesTableUpdateCompanionBuilder
    = PinwallPostsCachesCompanion Function({
  Value<String> groupId,
  Value<String> postsJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PinwallPostsCachesTableFilterComposer
    extends Composer<_$AppDatabase, $PinwallPostsCachesTable> {
  $$PinwallPostsCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get postsJson => $composableBuilder(
      column: $table.postsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PinwallPostsCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $PinwallPostsCachesTable> {
  $$PinwallPostsCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get postsJson => $composableBuilder(
      column: $table.postsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PinwallPostsCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PinwallPostsCachesTable> {
  $$PinwallPostsCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get postsJson =>
      $composableBuilder(column: $table.postsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PinwallPostsCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PinwallPostsCachesTable,
    PinwallPostsCache,
    $$PinwallPostsCachesTableFilterComposer,
    $$PinwallPostsCachesTableOrderingComposer,
    $$PinwallPostsCachesTableAnnotationComposer,
    $$PinwallPostsCachesTableCreateCompanionBuilder,
    $$PinwallPostsCachesTableUpdateCompanionBuilder,
    (
      PinwallPostsCache,
      BaseReferences<_$AppDatabase, $PinwallPostsCachesTable, PinwallPostsCache>
    ),
    PinwallPostsCache,
    PrefetchHooks Function()> {
  $$PinwallPostsCachesTableTableManager(
      _$AppDatabase db, $PinwallPostsCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PinwallPostsCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PinwallPostsCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PinwallPostsCachesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> postsJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PinwallPostsCachesCompanion(
            groupId: groupId,
            postsJson: postsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String postsJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PinwallPostsCachesCompanion.insert(
            groupId: groupId,
            postsJson: postsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PinwallPostsCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PinwallPostsCachesTable,
    PinwallPostsCache,
    $$PinwallPostsCachesTableFilterComposer,
    $$PinwallPostsCachesTableOrderingComposer,
    $$PinwallPostsCachesTableAnnotationComposer,
    $$PinwallPostsCachesTableCreateCompanionBuilder,
    $$PinwallPostsCachesTableUpdateCompanionBuilder,
    (
      PinwallPostsCache,
      BaseReferences<_$AppDatabase, $PinwallPostsCachesTable, PinwallPostsCache>
    ),
    PinwallPostsCache,
    PrefetchHooks Function()>;
typedef $$HubGroupCachesTableCreateCompanionBuilder = HubGroupCachesCompanion
    Function({
  required String groupId,
  required String groupJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$HubGroupCachesTableUpdateCompanionBuilder = HubGroupCachesCompanion
    Function({
  Value<String> groupId,
  Value<String> groupJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$HubGroupCachesTableFilterComposer
    extends Composer<_$AppDatabase, $HubGroupCachesTable> {
  $$HubGroupCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupJson => $composableBuilder(
      column: $table.groupJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$HubGroupCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $HubGroupCachesTable> {
  $$HubGroupCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupJson => $composableBuilder(
      column: $table.groupJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$HubGroupCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HubGroupCachesTable> {
  $$HubGroupCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get groupJson =>
      $composableBuilder(column: $table.groupJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$HubGroupCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HubGroupCachesTable,
    HubGroupCache,
    $$HubGroupCachesTableFilterComposer,
    $$HubGroupCachesTableOrderingComposer,
    $$HubGroupCachesTableAnnotationComposer,
    $$HubGroupCachesTableCreateCompanionBuilder,
    $$HubGroupCachesTableUpdateCompanionBuilder,
    (
      HubGroupCache,
      BaseReferences<_$AppDatabase, $HubGroupCachesTable, HubGroupCache>
    ),
    HubGroupCache,
    PrefetchHooks Function()> {
  $$HubGroupCachesTableTableManager(
      _$AppDatabase db, $HubGroupCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HubGroupCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HubGroupCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HubGroupCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> groupJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HubGroupCachesCompanion(
            groupId: groupId,
            groupJson: groupJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String groupJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              HubGroupCachesCompanion.insert(
            groupId: groupId,
            groupJson: groupJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HubGroupCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HubGroupCachesTable,
    HubGroupCache,
    $$HubGroupCachesTableFilterComposer,
    $$HubGroupCachesTableOrderingComposer,
    $$HubGroupCachesTableAnnotationComposer,
    $$HubGroupCachesTableCreateCompanionBuilder,
    $$HubGroupCachesTableUpdateCompanionBuilder,
    (
      HubGroupCache,
      BaseReferences<_$AppDatabase, $HubGroupCachesTable, HubGroupCache>
    ),
    HubGroupCache,
    PrefetchHooks Function()>;
typedef $$HubActivityCachesTableCreateCompanionBuilder
    = HubActivityCachesCompanion Function({
  required String groupId,
  required String activitiesJson,
  required bool hadError,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$HubActivityCachesTableUpdateCompanionBuilder
    = HubActivityCachesCompanion Function({
  Value<String> groupId,
  Value<String> activitiesJson,
  Value<bool> hadError,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$HubActivityCachesTableFilterComposer
    extends Composer<_$AppDatabase, $HubActivityCachesTable> {
  $$HubActivityCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activitiesJson => $composableBuilder(
      column: $table.activitiesJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hadError => $composableBuilder(
      column: $table.hadError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$HubActivityCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $HubActivityCachesTable> {
  $$HubActivityCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activitiesJson => $composableBuilder(
      column: $table.activitiesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hadError => $composableBuilder(
      column: $table.hadError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$HubActivityCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HubActivityCachesTable> {
  $$HubActivityCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get activitiesJson => $composableBuilder(
      column: $table.activitiesJson, builder: (column) => column);

  GeneratedColumn<bool> get hadError =>
      $composableBuilder(column: $table.hadError, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$HubActivityCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HubActivityCachesTable,
    HubActivityCache,
    $$HubActivityCachesTableFilterComposer,
    $$HubActivityCachesTableOrderingComposer,
    $$HubActivityCachesTableAnnotationComposer,
    $$HubActivityCachesTableCreateCompanionBuilder,
    $$HubActivityCachesTableUpdateCompanionBuilder,
    (
      HubActivityCache,
      BaseReferences<_$AppDatabase, $HubActivityCachesTable, HubActivityCache>
    ),
    HubActivityCache,
    PrefetchHooks Function()> {
  $$HubActivityCachesTableTableManager(
      _$AppDatabase db, $HubActivityCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HubActivityCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HubActivityCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HubActivityCachesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> activitiesJson = const Value.absent(),
            Value<bool> hadError = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HubActivityCachesCompanion(
            groupId: groupId,
            activitiesJson: activitiesJson,
            hadError: hadError,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String activitiesJson,
            required bool hadError,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              HubActivityCachesCompanion.insert(
            groupId: groupId,
            activitiesJson: activitiesJson,
            hadError: hadError,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HubActivityCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HubActivityCachesTable,
    HubActivityCache,
    $$HubActivityCachesTableFilterComposer,
    $$HubActivityCachesTableOrderingComposer,
    $$HubActivityCachesTableAnnotationComposer,
    $$HubActivityCachesTableCreateCompanionBuilder,
    $$HubActivityCachesTableUpdateCompanionBuilder,
    (
      HubActivityCache,
      BaseReferences<_$AppDatabase, $HubActivityCachesTable, HubActivityCache>
    ),
    HubActivityCache,
    PrefetchHooks Function()>;
typedef $$GroupsCachesTableCreateCompanionBuilder = GroupsCachesCompanion
    Function({
  required String cacheKey,
  required String groupsJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$GroupsCachesTableUpdateCompanionBuilder = GroupsCachesCompanion
    Function({
  Value<String> cacheKey,
  Value<String> groupsJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$GroupsCachesTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsCachesTable> {
  $$GroupsCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupsJson => $composableBuilder(
      column: $table.groupsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$GroupsCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsCachesTable> {
  $$GroupsCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupsJson => $composableBuilder(
      column: $table.groupsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$GroupsCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsCachesTable> {
  $$GroupsCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get groupsJson => $composableBuilder(
      column: $table.groupsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GroupsCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GroupsCachesTable,
    GroupsCache,
    $$GroupsCachesTableFilterComposer,
    $$GroupsCachesTableOrderingComposer,
    $$GroupsCachesTableAnnotationComposer,
    $$GroupsCachesTableCreateCompanionBuilder,
    $$GroupsCachesTableUpdateCompanionBuilder,
    (
      GroupsCache,
      BaseReferences<_$AppDatabase, $GroupsCachesTable, GroupsCache>
    ),
    GroupsCache,
    PrefetchHooks Function()> {
  $$GroupsCachesTableTableManager(_$AppDatabase db, $GroupsCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cacheKey = const Value.absent(),
            Value<String> groupsJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GroupsCachesCompanion(
            cacheKey: cacheKey,
            groupsJson: groupsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String cacheKey,
            required String groupsJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              GroupsCachesCompanion.insert(
            cacheKey: cacheKey,
            groupsJson: groupsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GroupsCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GroupsCachesTable,
    GroupsCache,
    $$GroupsCachesTableFilterComposer,
    $$GroupsCachesTableOrderingComposer,
    $$GroupsCachesTableAnnotationComposer,
    $$GroupsCachesTableCreateCompanionBuilder,
    $$GroupsCachesTableUpdateCompanionBuilder,
    (
      GroupsCache,
      BaseReferences<_$AppDatabase, $GroupsCachesTable, GroupsCache>
    ),
    GroupsCache,
    PrefetchHooks Function()>;
typedef $$SettlementsCachesTableCreateCompanionBuilder
    = SettlementsCachesCompanion Function({
  required String groupId,
  required String settlementsJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SettlementsCachesTableUpdateCompanionBuilder
    = SettlementsCachesCompanion Function({
  Value<String> groupId,
  Value<String> settlementsJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SettlementsCachesTableFilterComposer
    extends Composer<_$AppDatabase, $SettlementsCachesTable> {
  $$SettlementsCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get settlementsJson => $composableBuilder(
      column: $table.settlementsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SettlementsCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $SettlementsCachesTable> {
  $$SettlementsCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get settlementsJson => $composableBuilder(
      column: $table.settlementsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SettlementsCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettlementsCachesTable> {
  $$SettlementsCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get settlementsJson => $composableBuilder(
      column: $table.settlementsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettlementsCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettlementsCachesTable,
    SettlementsCache,
    $$SettlementsCachesTableFilterComposer,
    $$SettlementsCachesTableOrderingComposer,
    $$SettlementsCachesTableAnnotationComposer,
    $$SettlementsCachesTableCreateCompanionBuilder,
    $$SettlementsCachesTableUpdateCompanionBuilder,
    (
      SettlementsCache,
      BaseReferences<_$AppDatabase, $SettlementsCachesTable, SettlementsCache>
    ),
    SettlementsCache,
    PrefetchHooks Function()> {
  $$SettlementsCachesTableTableManager(
      _$AppDatabase db, $SettlementsCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettlementsCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettlementsCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettlementsCachesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> settlementsJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettlementsCachesCompanion(
            groupId: groupId,
            settlementsJson: settlementsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String settlementsJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettlementsCachesCompanion.insert(
            groupId: groupId,
            settlementsJson: settlementsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettlementsCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettlementsCachesTable,
    SettlementsCache,
    $$SettlementsCachesTableFilterComposer,
    $$SettlementsCachesTableOrderingComposer,
    $$SettlementsCachesTableAnnotationComposer,
    $$SettlementsCachesTableCreateCompanionBuilder,
    $$SettlementsCachesTableUpdateCompanionBuilder,
    (
      SettlementsCache,
      BaseReferences<_$AppDatabase, $SettlementsCachesTable, SettlementsCache>
    ),
    SettlementsCache,
    PrefetchHooks Function()>;
typedef $$CalendarCachesTableCreateCompanionBuilder = CalendarCachesCompanion
    Function({
  required String groupId,
  required String rangeKey,
  required String eventsJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CalendarCachesTableUpdateCompanionBuilder = CalendarCachesCompanion
    Function({
  Value<String> groupId,
  Value<String> rangeKey,
  Value<String> eventsJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CalendarCachesTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarCachesTable> {
  $$CalendarCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rangeKey => $composableBuilder(
      column: $table.rangeKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventsJson => $composableBuilder(
      column: $table.eventsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CalendarCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarCachesTable> {
  $$CalendarCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rangeKey => $composableBuilder(
      column: $table.rangeKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventsJson => $composableBuilder(
      column: $table.eventsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CalendarCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarCachesTable> {
  $$CalendarCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get rangeKey =>
      $composableBuilder(column: $table.rangeKey, builder: (column) => column);

  GeneratedColumn<String> get eventsJson => $composableBuilder(
      column: $table.eventsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CalendarCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CalendarCachesTable,
    CalendarCache,
    $$CalendarCachesTableFilterComposer,
    $$CalendarCachesTableOrderingComposer,
    $$CalendarCachesTableAnnotationComposer,
    $$CalendarCachesTableCreateCompanionBuilder,
    $$CalendarCachesTableUpdateCompanionBuilder,
    (
      CalendarCache,
      BaseReferences<_$AppDatabase, $CalendarCachesTable, CalendarCache>
    ),
    CalendarCache,
    PrefetchHooks Function()> {
  $$CalendarCachesTableTableManager(
      _$AppDatabase db, $CalendarCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> rangeKey = const Value.absent(),
            Value<String> eventsJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarCachesCompanion(
            groupId: groupId,
            rangeKey: rangeKey,
            eventsJson: eventsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String rangeKey,
            required String eventsJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarCachesCompanion.insert(
            groupId: groupId,
            rangeKey: rangeKey,
            eventsJson: eventsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CalendarCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CalendarCachesTable,
    CalendarCache,
    $$CalendarCachesTableFilterComposer,
    $$CalendarCachesTableOrderingComposer,
    $$CalendarCachesTableAnnotationComposer,
    $$CalendarCachesTableCreateCompanionBuilder,
    $$CalendarCachesTableUpdateCompanionBuilder,
    (
      CalendarCache,
      BaseReferences<_$AppDatabase, $CalendarCachesTable, CalendarCache>
    ),
    CalendarCache,
    PrefetchHooks Function()>;
typedef $$MealPlanCachesTableCreateCompanionBuilder = MealPlanCachesCompanion
    Function({
  required String groupId,
  required String rangeKey,
  required String plansJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$MealPlanCachesTableUpdateCompanionBuilder = MealPlanCachesCompanion
    Function({
  Value<String> groupId,
  Value<String> rangeKey,
  Value<String> plansJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$MealPlanCachesTableFilterComposer
    extends Composer<_$AppDatabase, $MealPlanCachesTable> {
  $$MealPlanCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rangeKey => $composableBuilder(
      column: $table.rangeKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plansJson => $composableBuilder(
      column: $table.plansJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$MealPlanCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $MealPlanCachesTable> {
  $$MealPlanCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rangeKey => $composableBuilder(
      column: $table.rangeKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plansJson => $composableBuilder(
      column: $table.plansJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$MealPlanCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealPlanCachesTable> {
  $$MealPlanCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get rangeKey =>
      $composableBuilder(column: $table.rangeKey, builder: (column) => column);

  GeneratedColumn<String> get plansJson =>
      $composableBuilder(column: $table.plansJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MealPlanCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MealPlanCachesTable,
    MealPlanCache,
    $$MealPlanCachesTableFilterComposer,
    $$MealPlanCachesTableOrderingComposer,
    $$MealPlanCachesTableAnnotationComposer,
    $$MealPlanCachesTableCreateCompanionBuilder,
    $$MealPlanCachesTableUpdateCompanionBuilder,
    (
      MealPlanCache,
      BaseReferences<_$AppDatabase, $MealPlanCachesTable, MealPlanCache>
    ),
    MealPlanCache,
    PrefetchHooks Function()> {
  $$MealPlanCachesTableTableManager(
      _$AppDatabase db, $MealPlanCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealPlanCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealPlanCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealPlanCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> rangeKey = const Value.absent(),
            Value<String> plansJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MealPlanCachesCompanion(
            groupId: groupId,
            rangeKey: rangeKey,
            plansJson: plansJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String rangeKey,
            required String plansJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MealPlanCachesCompanion.insert(
            groupId: groupId,
            rangeKey: rangeKey,
            plansJson: plansJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MealPlanCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MealPlanCachesTable,
    MealPlanCache,
    $$MealPlanCachesTableFilterComposer,
    $$MealPlanCachesTableOrderingComposer,
    $$MealPlanCachesTableAnnotationComposer,
    $$MealPlanCachesTableCreateCompanionBuilder,
    $$MealPlanCachesTableUpdateCompanionBuilder,
    (
      MealPlanCache,
      BaseReferences<_$AppDatabase, $MealPlanCachesTable, MealPlanCache>
    ),
    MealPlanCache,
    PrefetchHooks Function()>;
typedef $$ResponseCachesTableCreateCompanionBuilder = ResponseCachesCompanion
    Function({
  required String cacheKey,
  required int statusCode,
  required String bodyJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ResponseCachesTableUpdateCompanionBuilder = ResponseCachesCompanion
    Function({
  Value<String> cacheKey,
  Value<int> statusCode,
  Value<String> bodyJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ResponseCachesTableFilterComposer
    extends Composer<_$AppDatabase, $ResponseCachesTable> {
  $$ResponseCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get statusCode => $composableBuilder(
      column: $table.statusCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bodyJson => $composableBuilder(
      column: $table.bodyJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ResponseCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $ResponseCachesTable> {
  $$ResponseCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get statusCode => $composableBuilder(
      column: $table.statusCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bodyJson => $composableBuilder(
      column: $table.bodyJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ResponseCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResponseCachesTable> {
  $$ResponseCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<int> get statusCode => $composableBuilder(
      column: $table.statusCode, builder: (column) => column);

  GeneratedColumn<String> get bodyJson =>
      $composableBuilder(column: $table.bodyJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ResponseCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ResponseCachesTable,
    ResponseCache,
    $$ResponseCachesTableFilterComposer,
    $$ResponseCachesTableOrderingComposer,
    $$ResponseCachesTableAnnotationComposer,
    $$ResponseCachesTableCreateCompanionBuilder,
    $$ResponseCachesTableUpdateCompanionBuilder,
    (
      ResponseCache,
      BaseReferences<_$AppDatabase, $ResponseCachesTable, ResponseCache>
    ),
    ResponseCache,
    PrefetchHooks Function()> {
  $$ResponseCachesTableTableManager(
      _$AppDatabase db, $ResponseCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResponseCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResponseCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResponseCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cacheKey = const Value.absent(),
            Value<int> statusCode = const Value.absent(),
            Value<String> bodyJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ResponseCachesCompanion(
            cacheKey: cacheKey,
            statusCode: statusCode,
            bodyJson: bodyJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String cacheKey,
            required int statusCode,
            required String bodyJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ResponseCachesCompanion.insert(
            cacheKey: cacheKey,
            statusCode: statusCode,
            bodyJson: bodyJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ResponseCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ResponseCachesTable,
    ResponseCache,
    $$ResponseCachesTableFilterComposer,
    $$ResponseCachesTableOrderingComposer,
    $$ResponseCachesTableAnnotationComposer,
    $$ResponseCachesTableCreateCompanionBuilder,
    $$ResponseCachesTableUpdateCompanionBuilder,
    (
      ResponseCache,
      BaseReferences<_$AppDatabase, $ResponseCachesTable, ResponseCache>
    ),
    ResponseCache,
    PrefetchHooks Function()>;
typedef $$OutboxOpsTableCreateCompanionBuilder = OutboxOpsCompanion Function({
  required String id,
  required String type,
  required String payloadJson,
  Value<String?> idempotencyKey,
  required DateTime createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<int> attemptCount,
  Value<String?> lastError,
  Value<String?> entityType,
  Value<String?> entityId,
  Value<int> rowid,
});
typedef $$OutboxOpsTableUpdateCompanionBuilder = OutboxOpsCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<String> payloadJson,
  Value<String?> idempotencyKey,
  Value<DateTime> createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<int> attemptCount,
  Value<String?> lastError,
  Value<String?> entityType,
  Value<String?> entityId,
  Value<int> rowid,
});

class $$OutboxOpsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxOpsTable> {
  $$OutboxOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));
}

class $$OutboxOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxOpsTable> {
  $$OutboxOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));
}

class $$OutboxOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxOpsTable> {
  $$OutboxOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);
}

class $$OutboxOpsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxOpsTable,
    OutboxOp,
    $$OutboxOpsTableFilterComposer,
    $$OutboxOpsTableOrderingComposer,
    $$OutboxOpsTableAnnotationComposer,
    $$OutboxOpsTableCreateCompanionBuilder,
    $$OutboxOpsTableUpdateCompanionBuilder,
    (OutboxOp, BaseReferences<_$AppDatabase, $OutboxOpsTable, OutboxOp>),
    OutboxOp,
    PrefetchHooks Function()> {
  $$OutboxOpsTableTableManager(_$AppDatabase db, $OutboxOpsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<String?> idempotencyKey = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String?> entityType = const Value.absent(),
            Value<String?> entityId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxOpsCompanion(
            id: id,
            type: type,
            payloadJson: payloadJson,
            idempotencyKey: idempotencyKey,
            createdAt: createdAt,
            lastAttemptAt: lastAttemptAt,
            attemptCount: attemptCount,
            lastError: lastError,
            entityType: entityType,
            entityId: entityId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String type,
            required String payloadJson,
            Value<String?> idempotencyKey = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String?> entityType = const Value.absent(),
            Value<String?> entityId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxOpsCompanion.insert(
            id: id,
            type: type,
            payloadJson: payloadJson,
            idempotencyKey: idempotencyKey,
            createdAt: createdAt,
            lastAttemptAt: lastAttemptAt,
            attemptCount: attemptCount,
            lastError: lastError,
            entityType: entityType,
            entityId: entityId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxOpsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxOpsTable,
    OutboxOp,
    $$OutboxOpsTableFilterComposer,
    $$OutboxOpsTableOrderingComposer,
    $$OutboxOpsTableAnnotationComposer,
    $$OutboxOpsTableCreateCompanionBuilder,
    $$OutboxOpsTableUpdateCompanionBuilder,
    (OutboxOp, BaseReferences<_$AppDatabase, $OutboxOpsTable, OutboxOp>),
    OutboxOp,
    PrefetchHooks Function()>;
typedef $$ConflictsTableCreateCompanionBuilder = ConflictsCompanion Function({
  required String id,
  required String entityType,
  required String entityId,
  required String localPayloadJson,
  required String serverPayloadJson,
  required DateTime createdAt,
  Value<DateTime?> resolvedAt,
  Value<int> rowid,
});
typedef $$ConflictsTableUpdateCompanionBuilder = ConflictsCompanion Function({
  Value<String> id,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> localPayloadJson,
  Value<String> serverPayloadJson,
  Value<DateTime> createdAt,
  Value<DateTime?> resolvedAt,
  Value<int> rowid,
});

class $$ConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $ConflictsTable> {
  $$ConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPayloadJson => $composableBuilder(
      column: $table.localPayloadJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverPayloadJson => $composableBuilder(
      column: $table.serverPayloadJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnFilters(column));
}

class $$ConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConflictsTable> {
  $$ConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPayloadJson => $composableBuilder(
      column: $table.localPayloadJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverPayloadJson => $composableBuilder(
      column: $table.serverPayloadJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnOrderings(column));
}

class $$ConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConflictsTable> {
  $$ConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get localPayloadJson => $composableBuilder(
      column: $table.localPayloadJson, builder: (column) => column);

  GeneratedColumn<String> get serverPayloadJson => $composableBuilder(
      column: $table.serverPayloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => column);
}

class $$ConflictsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConflictsTable,
    Conflict,
    $$ConflictsTableFilterComposer,
    $$ConflictsTableOrderingComposer,
    $$ConflictsTableAnnotationComposer,
    $$ConflictsTableCreateCompanionBuilder,
    $$ConflictsTableUpdateCompanionBuilder,
    (Conflict, BaseReferences<_$AppDatabase, $ConflictsTable, Conflict>),
    Conflict,
    PrefetchHooks Function()> {
  $$ConflictsTableTableManager(_$AppDatabase db, $ConflictsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> localPayloadJson = const Value.absent(),
            Value<String> serverPayloadJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConflictsCompanion(
            id: id,
            entityType: entityType,
            entityId: entityId,
            localPayloadJson: localPayloadJson,
            serverPayloadJson: serverPayloadJson,
            createdAt: createdAt,
            resolvedAt: resolvedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String entityType,
            required String entityId,
            required String localPayloadJson,
            required String serverPayloadJson,
            required DateTime createdAt,
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConflictsCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            localPayloadJson: localPayloadJson,
            serverPayloadJson: serverPayloadJson,
            createdAt: createdAt,
            resolvedAt: resolvedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConflictsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConflictsTable,
    Conflict,
    $$ConflictsTableFilterComposer,
    $$ConflictsTableOrderingComposer,
    $$ConflictsTableAnnotationComposer,
    $$ConflictsTableCreateCompanionBuilder,
    $$ConflictsTableUpdateCompanionBuilder,
    (Conflict, BaseReferences<_$AppDatabase, $ConflictsTable, Conflict>),
    Conflict,
    PrefetchHooks Function()>;
typedef $$CanonicalItemsTableTableCreateCompanionBuilder
    = CanonicalItemsTableCompanion Function({
  required String id,
  required String groupId,
  Value<String> nameDe,
  Value<String> nameEn,
  Value<String> nameFr,
  Value<String> nameEs,
  Value<String> category,
  Value<String> defaultUnit,
  Value<String?> productId,
  Value<bool> isGlobal,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$CanonicalItemsTableTableUpdateCompanionBuilder
    = CanonicalItemsTableCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> nameDe,
  Value<String> nameEn,
  Value<String> nameFr,
  Value<String> nameEs,
  Value<String> category,
  Value<String> defaultUnit,
  Value<String?> productId,
  Value<bool> isGlobal,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$CanonicalItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CanonicalItemsTableTable> {
  $$CanonicalItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nameDe => $composableBuilder(
      column: $table.nameDe, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nameEn => $composableBuilder(
      column: $table.nameEn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nameFr => $composableBuilder(
      column: $table.nameFr, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nameEs => $composableBuilder(
      column: $table.nameEs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get defaultUnit => $composableBuilder(
      column: $table.defaultUnit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isGlobal => $composableBuilder(
      column: $table.isGlobal, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$CanonicalItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CanonicalItemsTableTable> {
  $$CanonicalItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nameDe => $composableBuilder(
      column: $table.nameDe, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nameEn => $composableBuilder(
      column: $table.nameEn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nameFr => $composableBuilder(
      column: $table.nameFr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nameEs => $composableBuilder(
      column: $table.nameEs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get defaultUnit => $composableBuilder(
      column: $table.defaultUnit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isGlobal => $composableBuilder(
      column: $table.isGlobal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$CanonicalItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CanonicalItemsTableTable> {
  $$CanonicalItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get nameDe =>
      $composableBuilder(column: $table.nameDe, builder: (column) => column);

  GeneratedColumn<String> get nameEn =>
      $composableBuilder(column: $table.nameEn, builder: (column) => column);

  GeneratedColumn<String> get nameFr =>
      $composableBuilder(column: $table.nameFr, builder: (column) => column);

  GeneratedColumn<String> get nameEs =>
      $composableBuilder(column: $table.nameEs, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get defaultUnit => $composableBuilder(
      column: $table.defaultUnit, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<bool> get isGlobal =>
      $composableBuilder(column: $table.isGlobal, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CanonicalItemsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CanonicalItemsTableTable,
    CanonicalItemsTableData,
    $$CanonicalItemsTableTableFilterComposer,
    $$CanonicalItemsTableTableOrderingComposer,
    $$CanonicalItemsTableTableAnnotationComposer,
    $$CanonicalItemsTableTableCreateCompanionBuilder,
    $$CanonicalItemsTableTableUpdateCompanionBuilder,
    (
      CanonicalItemsTableData,
      BaseReferences<_$AppDatabase, $CanonicalItemsTableTable,
          CanonicalItemsTableData>
    ),
    CanonicalItemsTableData,
    PrefetchHooks Function()> {
  $$CanonicalItemsTableTableTableManager(
      _$AppDatabase db, $CanonicalItemsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CanonicalItemsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CanonicalItemsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CanonicalItemsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String> nameDe = const Value.absent(),
            Value<String> nameEn = const Value.absent(),
            Value<String> nameFr = const Value.absent(),
            Value<String> nameEs = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> defaultUnit = const Value.absent(),
            Value<String?> productId = const Value.absent(),
            Value<bool> isGlobal = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CanonicalItemsTableCompanion(
            id: id,
            groupId: groupId,
            nameDe: nameDe,
            nameEn: nameEn,
            nameFr: nameFr,
            nameEs: nameEs,
            category: category,
            defaultUnit: defaultUnit,
            productId: productId,
            isGlobal: isGlobal,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            Value<String> nameDe = const Value.absent(),
            Value<String> nameEn = const Value.absent(),
            Value<String> nameFr = const Value.absent(),
            Value<String> nameEs = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> defaultUnit = const Value.absent(),
            Value<String?> productId = const Value.absent(),
            Value<bool> isGlobal = const Value.absent(),
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CanonicalItemsTableCompanion.insert(
            id: id,
            groupId: groupId,
            nameDe: nameDe,
            nameEn: nameEn,
            nameFr: nameFr,
            nameEs: nameEs,
            category: category,
            defaultUnit: defaultUnit,
            productId: productId,
            isGlobal: isGlobal,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CanonicalItemsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CanonicalItemsTableTable,
    CanonicalItemsTableData,
    $$CanonicalItemsTableTableFilterComposer,
    $$CanonicalItemsTableTableOrderingComposer,
    $$CanonicalItemsTableTableAnnotationComposer,
    $$CanonicalItemsTableTableCreateCompanionBuilder,
    $$CanonicalItemsTableTableUpdateCompanionBuilder,
    (
      CanonicalItemsTableData,
      BaseReferences<_$AppDatabase, $CanonicalItemsTableTable,
          CanonicalItemsTableData>
    ),
    CanonicalItemsTableData,
    PrefetchHooks Function()>;
typedef $$ItemAliasesTableTableCreateCompanionBuilder
    = ItemAliasesTableCompanion Function({
  required String id,
  required String groupId,
  required String canonicalItemId,
  required String aliasText,
  Value<String> lang,
  Value<String> source,
  Value<int> weight,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$ItemAliasesTableTableUpdateCompanionBuilder
    = ItemAliasesTableCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> canonicalItemId,
  Value<String> aliasText,
  Value<String> lang,
  Value<String> source,
  Value<int> weight,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$ItemAliasesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ItemAliasesTableTable> {
  $$ItemAliasesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aliasText => $composableBuilder(
      column: $table.aliasText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lang => $composableBuilder(
      column: $table.lang, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$ItemAliasesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemAliasesTableTable> {
  $$ItemAliasesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aliasText => $composableBuilder(
      column: $table.aliasText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lang => $composableBuilder(
      column: $table.lang, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$ItemAliasesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemAliasesTableTable> {
  $$ItemAliasesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId, builder: (column) => column);

  GeneratedColumn<String> get aliasText =>
      $composableBuilder(column: $table.aliasText, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ItemAliasesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ItemAliasesTableTable,
    ItemAliasesTableData,
    $$ItemAliasesTableTableFilterComposer,
    $$ItemAliasesTableTableOrderingComposer,
    $$ItemAliasesTableTableAnnotationComposer,
    $$ItemAliasesTableTableCreateCompanionBuilder,
    $$ItemAliasesTableTableUpdateCompanionBuilder,
    (
      ItemAliasesTableData,
      BaseReferences<_$AppDatabase, $ItemAliasesTableTable,
          ItemAliasesTableData>
    ),
    ItemAliasesTableData,
    PrefetchHooks Function()> {
  $$ItemAliasesTableTableTableManager(
      _$AppDatabase db, $ItemAliasesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemAliasesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemAliasesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemAliasesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String> canonicalItemId = const Value.absent(),
            Value<String> aliasText = const Value.absent(),
            Value<String> lang = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> weight = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemAliasesTableCompanion(
            id: id,
            groupId: groupId,
            canonicalItemId: canonicalItemId,
            aliasText: aliasText,
            lang: lang,
            source: source,
            weight: weight,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            required String canonicalItemId,
            required String aliasText,
            Value<String> lang = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> weight = const Value.absent(),
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemAliasesTableCompanion.insert(
            id: id,
            groupId: groupId,
            canonicalItemId: canonicalItemId,
            aliasText: aliasText,
            lang: lang,
            source: source,
            weight: weight,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ItemAliasesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ItemAliasesTableTable,
    ItemAliasesTableData,
    $$ItemAliasesTableTableFilterComposer,
    $$ItemAliasesTableTableOrderingComposer,
    $$ItemAliasesTableTableAnnotationComposer,
    $$ItemAliasesTableTableCreateCompanionBuilder,
    $$ItemAliasesTableTableUpdateCompanionBuilder,
    (
      ItemAliasesTableData,
      BaseReferences<_$AppDatabase, $ItemAliasesTableTable,
          ItemAliasesTableData>
    ),
    ItemAliasesTableData,
    PrefetchHooks Function()>;
typedef $$CorrectionsTableTableCreateCompanionBuilder
    = CorrectionsTableCompanion Function({
  required String id,
  required String groupId,
  Value<String?> userId,
  Value<String> scope,
  required String kind,
  Value<String> rawText,
  Value<String?> resolvedCanonicalItemId,
  Value<String?> correctedValueJson,
  Value<String> source,
  Value<int> version,
  required DateTime createdAt,
  Value<DateTime?> appliedAt,
  Value<int> rowid,
});
typedef $$CorrectionsTableTableUpdateCompanionBuilder
    = CorrectionsTableCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String?> userId,
  Value<String> scope,
  Value<String> kind,
  Value<String> rawText,
  Value<String?> resolvedCanonicalItemId,
  Value<String?> correctedValueJson,
  Value<String> source,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime?> appliedAt,
  Value<int> rowid,
});

class $$CorrectionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CorrectionsTableTable> {
  $$CorrectionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resolvedCanonicalItemId => $composableBuilder(
      column: $table.resolvedCanonicalItemId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get correctedValueJson => $composableBuilder(
      column: $table.correctedValueJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get appliedAt => $composableBuilder(
      column: $table.appliedAt, builder: (column) => ColumnFilters(column));
}

class $$CorrectionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CorrectionsTableTable> {
  $$CorrectionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resolvedCanonicalItemId => $composableBuilder(
      column: $table.resolvedCanonicalItemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get correctedValueJson => $composableBuilder(
      column: $table.correctedValueJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get appliedAt => $composableBuilder(
      column: $table.appliedAt, builder: (column) => ColumnOrderings(column));
}

class $$CorrectionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CorrectionsTableTable> {
  $$CorrectionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<String> get resolvedCanonicalItemId => $composableBuilder(
      column: $table.resolvedCanonicalItemId, builder: (column) => column);

  GeneratedColumn<String> get correctedValueJson => $composableBuilder(
      column: $table.correctedValueJson, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get appliedAt =>
      $composableBuilder(column: $table.appliedAt, builder: (column) => column);
}

class $$CorrectionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CorrectionsTableTable,
    CorrectionsTableData,
    $$CorrectionsTableTableFilterComposer,
    $$CorrectionsTableTableOrderingComposer,
    $$CorrectionsTableTableAnnotationComposer,
    $$CorrectionsTableTableCreateCompanionBuilder,
    $$CorrectionsTableTableUpdateCompanionBuilder,
    (
      CorrectionsTableData,
      BaseReferences<_$AppDatabase, $CorrectionsTableTable,
          CorrectionsTableData>
    ),
    CorrectionsTableData,
    PrefetchHooks Function()> {
  $$CorrectionsTableTableTableManager(
      _$AppDatabase db, $CorrectionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CorrectionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CorrectionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CorrectionsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String> scope = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> rawText = const Value.absent(),
            Value<String?> resolvedCanonicalItemId = const Value.absent(),
            Value<String?> correctedValueJson = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> appliedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CorrectionsTableCompanion(
            id: id,
            groupId: groupId,
            userId: userId,
            scope: scope,
            kind: kind,
            rawText: rawText,
            resolvedCanonicalItemId: resolvedCanonicalItemId,
            correctedValueJson: correctedValueJson,
            source: source,
            version: version,
            createdAt: createdAt,
            appliedAt: appliedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            Value<String?> userId = const Value.absent(),
            Value<String> scope = const Value.absent(),
            required String kind,
            Value<String> rawText = const Value.absent(),
            Value<String?> resolvedCanonicalItemId = const Value.absent(),
            Value<String?> correctedValueJson = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> appliedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CorrectionsTableCompanion.insert(
            id: id,
            groupId: groupId,
            userId: userId,
            scope: scope,
            kind: kind,
            rawText: rawText,
            resolvedCanonicalItemId: resolvedCanonicalItemId,
            correctedValueJson: correctedValueJson,
            source: source,
            version: version,
            createdAt: createdAt,
            appliedAt: appliedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CorrectionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CorrectionsTableTable,
    CorrectionsTableData,
    $$CorrectionsTableTableFilterComposer,
    $$CorrectionsTableTableOrderingComposer,
    $$CorrectionsTableTableAnnotationComposer,
    $$CorrectionsTableTableCreateCompanionBuilder,
    $$CorrectionsTableTableUpdateCompanionBuilder,
    (
      CorrectionsTableData,
      BaseReferences<_$AppDatabase, $CorrectionsTableTable,
          CorrectionsTableData>
    ),
    CorrectionsTableData,
    PrefetchHooks Function()>;
typedef $$StoreAislesTableTableCreateCompanionBuilder
    = StoreAislesTableCompanion Function({
  required String id,
  required String groupId,
  Value<String?> storeId,
  required String canonicalItemId,
  Value<String> aisle,
  Value<int> sortOrder,
  Value<double> confidence,
  Value<int> version,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$StoreAislesTableTableUpdateCompanionBuilder
    = StoreAislesTableCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String?> storeId,
  Value<String> canonicalItemId,
  Value<String> aisle,
  Value<int> sortOrder,
  Value<double> confidence,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$StoreAislesTableTableFilterComposer
    extends Composer<_$AppDatabase, $StoreAislesTableTable> {
  $$StoreAislesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get storeId => $composableBuilder(
      column: $table.storeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aisle => $composableBuilder(
      column: $table.aisle, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$StoreAislesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $StoreAislesTableTable> {
  $$StoreAislesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get storeId => $composableBuilder(
      column: $table.storeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aisle => $composableBuilder(
      column: $table.aisle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$StoreAislesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoreAislesTableTable> {
  $$StoreAislesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId, builder: (column) => column);

  GeneratedColumn<String> get aisle =>
      $composableBuilder(column: $table.aisle, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$StoreAislesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StoreAislesTableTable,
    StoreAislesTableData,
    $$StoreAislesTableTableFilterComposer,
    $$StoreAislesTableTableOrderingComposer,
    $$StoreAislesTableTableAnnotationComposer,
    $$StoreAislesTableTableCreateCompanionBuilder,
    $$StoreAislesTableTableUpdateCompanionBuilder,
    (
      StoreAislesTableData,
      BaseReferences<_$AppDatabase, $StoreAislesTableTable,
          StoreAislesTableData>
    ),
    StoreAislesTableData,
    PrefetchHooks Function()> {
  $$StoreAislesTableTableTableManager(
      _$AppDatabase db, $StoreAislesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoreAislesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoreAislesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoreAislesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String?> storeId = const Value.absent(),
            Value<String> canonicalItemId = const Value.absent(),
            Value<String> aisle = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<double> confidence = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StoreAislesTableCompanion(
            id: id,
            groupId: groupId,
            storeId: storeId,
            canonicalItemId: canonicalItemId,
            aisle: aisle,
            sortOrder: sortOrder,
            confidence: confidence,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            Value<String?> storeId = const Value.absent(),
            required String canonicalItemId,
            Value<String> aisle = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<double> confidence = const Value.absent(),
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StoreAislesTableCompanion.insert(
            id: id,
            groupId: groupId,
            storeId: storeId,
            canonicalItemId: canonicalItemId,
            aisle: aisle,
            sortOrder: sortOrder,
            confidence: confidence,
            version: version,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StoreAislesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StoreAislesTableTable,
    StoreAislesTableData,
    $$StoreAislesTableTableFilterComposer,
    $$StoreAislesTableTableOrderingComposer,
    $$StoreAislesTableTableAnnotationComposer,
    $$StoreAislesTableTableCreateCompanionBuilder,
    $$StoreAislesTableTableUpdateCompanionBuilder,
    (
      StoreAislesTableData,
      BaseReferences<_$AppDatabase, $StoreAislesTableTable,
          StoreAislesTableData>
    ),
    StoreAislesTableData,
    PrefetchHooks Function()>;
typedef $$PurchaseHistoryTableTableCreateCompanionBuilder
    = PurchaseHistoryTableCompanion Function({
  required String id,
  required String groupId,
  Value<String?> canonicalItemId,
  Value<String?> listItemId,
  Value<double> quantity,
  Value<String> unit,
  Value<int> version,
  required DateTime purchasedAt,
  Value<int> rowid,
});
typedef $$PurchaseHistoryTableTableUpdateCompanionBuilder
    = PurchaseHistoryTableCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String?> canonicalItemId,
  Value<String?> listItemId,
  Value<double> quantity,
  Value<String> unit,
  Value<int> version,
  Value<DateTime> purchasedAt,
  Value<int> rowid,
});

class $$PurchaseHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $PurchaseHistoryTableTable> {
  $$PurchaseHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get listItemId => $composableBuilder(
      column: $table.listItemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get purchasedAt => $composableBuilder(
      column: $table.purchasedAt, builder: (column) => ColumnFilters(column));
}

class $$PurchaseHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PurchaseHistoryTableTable> {
  $$PurchaseHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get listItemId => $composableBuilder(
      column: $table.listItemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get purchasedAt => $composableBuilder(
      column: $table.purchasedAt, builder: (column) => ColumnOrderings(column));
}

class $$PurchaseHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PurchaseHistoryTableTable> {
  $$PurchaseHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get canonicalItemId => $composableBuilder(
      column: $table.canonicalItemId, builder: (column) => column);

  GeneratedColumn<String> get listItemId => $composableBuilder(
      column: $table.listItemId, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get purchasedAt => $composableBuilder(
      column: $table.purchasedAt, builder: (column) => column);
}

class $$PurchaseHistoryTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PurchaseHistoryTableTable,
    PurchaseHistoryTableData,
    $$PurchaseHistoryTableTableFilterComposer,
    $$PurchaseHistoryTableTableOrderingComposer,
    $$PurchaseHistoryTableTableAnnotationComposer,
    $$PurchaseHistoryTableTableCreateCompanionBuilder,
    $$PurchaseHistoryTableTableUpdateCompanionBuilder,
    (
      PurchaseHistoryTableData,
      BaseReferences<_$AppDatabase, $PurchaseHistoryTableTable,
          PurchaseHistoryTableData>
    ),
    PurchaseHistoryTableData,
    PrefetchHooks Function()> {
  $$PurchaseHistoryTableTableTableManager(
      _$AppDatabase db, $PurchaseHistoryTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchaseHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchaseHistoryTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchaseHistoryTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String?> canonicalItemId = const Value.absent(),
            Value<String?> listItemId = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> purchasedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseHistoryTableCompanion(
            id: id,
            groupId: groupId,
            canonicalItemId: canonicalItemId,
            listItemId: listItemId,
            quantity: quantity,
            unit: unit,
            version: version,
            purchasedAt: purchasedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            Value<String?> canonicalItemId = const Value.absent(),
            Value<String?> listItemId = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<int> version = const Value.absent(),
            required DateTime purchasedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseHistoryTableCompanion.insert(
            id: id,
            groupId: groupId,
            canonicalItemId: canonicalItemId,
            listItemId: listItemId,
            quantity: quantity,
            unit: unit,
            version: version,
            purchasedAt: purchasedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PurchaseHistoryTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $PurchaseHistoryTableTable,
        PurchaseHistoryTableData,
        $$PurchaseHistoryTableTableFilterComposer,
        $$PurchaseHistoryTableTableOrderingComposer,
        $$PurchaseHistoryTableTableAnnotationComposer,
        $$PurchaseHistoryTableTableCreateCompanionBuilder,
        $$PurchaseHistoryTableTableUpdateCompanionBuilder,
        (
          PurchaseHistoryTableData,
          BaseReferences<_$AppDatabase, $PurchaseHistoryTableTable,
              PurchaseHistoryTableData>
        ),
        PurchaseHistoryTableData,
        PrefetchHooks Function()>;
typedef $$ItemCooccurrenceTableTableCreateCompanionBuilder
    = ItemCooccurrenceTableCompanion Function({
  required String groupId,
  required String itemAId,
  required String itemBId,
  Value<int> count,
  required DateTime lastSeenAt,
  Value<int> version,
  Value<int> rowid,
});
typedef $$ItemCooccurrenceTableTableUpdateCompanionBuilder
    = ItemCooccurrenceTableCompanion Function({
  Value<String> groupId,
  Value<String> itemAId,
  Value<String> itemBId,
  Value<int> count,
  Value<DateTime> lastSeenAt,
  Value<int> version,
  Value<int> rowid,
});

class $$ItemCooccurrenceTableTableFilterComposer
    extends Composer<_$AppDatabase, $ItemCooccurrenceTableTable> {
  $$ItemCooccurrenceTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemAId => $composableBuilder(
      column: $table.itemAId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemBId => $composableBuilder(
      column: $table.itemBId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));
}

class $$ItemCooccurrenceTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemCooccurrenceTableTable> {
  $$ItemCooccurrenceTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemAId => $composableBuilder(
      column: $table.itemAId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemBId => $composableBuilder(
      column: $table.itemBId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));
}

class $$ItemCooccurrenceTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemCooccurrenceTableTable> {
  $$ItemCooccurrenceTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get itemAId =>
      $composableBuilder(column: $table.itemAId, builder: (column) => column);

  GeneratedColumn<String> get itemBId =>
      $composableBuilder(column: $table.itemBId, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$ItemCooccurrenceTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ItemCooccurrenceTableTable,
    ItemCooccurrenceTableData,
    $$ItemCooccurrenceTableTableFilterComposer,
    $$ItemCooccurrenceTableTableOrderingComposer,
    $$ItemCooccurrenceTableTableAnnotationComposer,
    $$ItemCooccurrenceTableTableCreateCompanionBuilder,
    $$ItemCooccurrenceTableTableUpdateCompanionBuilder,
    (
      ItemCooccurrenceTableData,
      BaseReferences<_$AppDatabase, $ItemCooccurrenceTableTable,
          ItemCooccurrenceTableData>
    ),
    ItemCooccurrenceTableData,
    PrefetchHooks Function()> {
  $$ItemCooccurrenceTableTableTableManager(
      _$AppDatabase db, $ItemCooccurrenceTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemCooccurrenceTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemCooccurrenceTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemCooccurrenceTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> itemAId = const Value.absent(),
            Value<String> itemBId = const Value.absent(),
            Value<int> count = const Value.absent(),
            Value<DateTime> lastSeenAt = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemCooccurrenceTableCompanion(
            groupId: groupId,
            itemAId: itemAId,
            itemBId: itemBId,
            count: count,
            lastSeenAt: lastSeenAt,
            version: version,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String itemAId,
            required String itemBId,
            Value<int> count = const Value.absent(),
            required DateTime lastSeenAt,
            Value<int> version = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemCooccurrenceTableCompanion.insert(
            groupId: groupId,
            itemAId: itemAId,
            itemBId: itemBId,
            count: count,
            lastSeenAt: lastSeenAt,
            version: version,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ItemCooccurrenceTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $ItemCooccurrenceTableTable,
        ItemCooccurrenceTableData,
        $$ItemCooccurrenceTableTableFilterComposer,
        $$ItemCooccurrenceTableTableOrderingComposer,
        $$ItemCooccurrenceTableTableAnnotationComposer,
        $$ItemCooccurrenceTableTableCreateCompanionBuilder,
        $$ItemCooccurrenceTableTableUpdateCompanionBuilder,
        (
          ItemCooccurrenceTableData,
          BaseReferences<_$AppDatabase, $ItemCooccurrenceTableTable,
              ItemCooccurrenceTableData>
        ),
        ItemCooccurrenceTableData,
        PrefetchHooks Function()>;
typedef $$ScanArtifactsTableTableCreateCompanionBuilder
    = ScanArtifactsTableCompanion Function({
  required String id,
  required String groupId,
  Value<String?> userId,
  Value<String> imageRef,
  Value<String> engine,
  Value<String?> rawJson,
  Value<String?> resolvedJson,
  Value<int> version,
  required DateTime createdAt,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});
typedef $$ScanArtifactsTableTableUpdateCompanionBuilder
    = ScanArtifactsTableCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String?> userId,
  Value<String> imageRef,
  Value<String> engine,
  Value<String?> rawJson,
  Value<String?> resolvedJson,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});

class $$ScanArtifactsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ScanArtifactsTableTable> {
  $$ScanArtifactsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageRef => $composableBuilder(
      column: $table.imageRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get engine => $composableBuilder(
      column: $table.engine, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawJson => $composableBuilder(
      column: $table.rawJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resolvedJson => $composableBuilder(
      column: $table.resolvedJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$ScanArtifactsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanArtifactsTableTable> {
  $$ScanArtifactsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageRef => $composableBuilder(
      column: $table.imageRef, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get engine => $composableBuilder(
      column: $table.engine, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawJson => $composableBuilder(
      column: $table.rawJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resolvedJson => $composableBuilder(
      column: $table.resolvedJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$ScanArtifactsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanArtifactsTableTable> {
  $$ScanArtifactsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get imageRef =>
      $composableBuilder(column: $table.imageRef, builder: (column) => column);

  GeneratedColumn<String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<String> get resolvedJson => $composableBuilder(
      column: $table.resolvedJson, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$ScanArtifactsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ScanArtifactsTableTable,
    ScanArtifactsTableData,
    $$ScanArtifactsTableTableFilterComposer,
    $$ScanArtifactsTableTableOrderingComposer,
    $$ScanArtifactsTableTableAnnotationComposer,
    $$ScanArtifactsTableTableCreateCompanionBuilder,
    $$ScanArtifactsTableTableUpdateCompanionBuilder,
    (
      ScanArtifactsTableData,
      BaseReferences<_$AppDatabase, $ScanArtifactsTableTable,
          ScanArtifactsTableData>
    ),
    ScanArtifactsTableData,
    PrefetchHooks Function()> {
  $$ScanArtifactsTableTableTableManager(
      _$AppDatabase db, $ScanArtifactsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanArtifactsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanArtifactsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanArtifactsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String> imageRef = const Value.absent(),
            Value<String> engine = const Value.absent(),
            Value<String?> rawJson = const Value.absent(),
            Value<String?> resolvedJson = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ScanArtifactsTableCompanion(
            id: id,
            groupId: groupId,
            userId: userId,
            imageRef: imageRef,
            engine: engine,
            rawJson: rawJson,
            resolvedJson: resolvedJson,
            version: version,
            createdAt: createdAt,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            Value<String?> userId = const Value.absent(),
            Value<String> imageRef = const Value.absent(),
            Value<String> engine = const Value.absent(),
            Value<String?> rawJson = const Value.absent(),
            Value<String?> resolvedJson = const Value.absent(),
            Value<int> version = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ScanArtifactsTableCompanion.insert(
            id: id,
            groupId: groupId,
            userId: userId,
            imageRef: imageRef,
            engine: engine,
            rawJson: rawJson,
            resolvedJson: resolvedJson,
            version: version,
            createdAt: createdAt,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ScanArtifactsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ScanArtifactsTableTable,
    ScanArtifactsTableData,
    $$ScanArtifactsTableTableFilterComposer,
    $$ScanArtifactsTableTableOrderingComposer,
    $$ScanArtifactsTableTableAnnotationComposer,
    $$ScanArtifactsTableTableCreateCompanionBuilder,
    $$ScanArtifactsTableTableUpdateCompanionBuilder,
    (
      ScanArtifactsTableData,
      BaseReferences<_$AppDatabase, $ScanArtifactsTableTable,
          ScanArtifactsTableData>
    ),
    ScanArtifactsTableData,
    PrefetchHooks Function()>;
typedef $$GroceryVersionsTableTableCreateCompanionBuilder
    = GroceryVersionsTableCompanion Function({
  required String groupId,
  Value<int> currentVersion,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$GroceryVersionsTableTableUpdateCompanionBuilder
    = GroceryVersionsTableCompanion Function({
  Value<String> groupId,
  Value<int> currentVersion,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$GroceryVersionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $GroceryVersionsTableTable> {
  $$GroceryVersionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentVersion => $composableBuilder(
      column: $table.currentVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$GroceryVersionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GroceryVersionsTableTable> {
  $$GroceryVersionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentVersion => $composableBuilder(
      column: $table.currentVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$GroceryVersionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroceryVersionsTableTable> {
  $$GroceryVersionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get currentVersion => $composableBuilder(
      column: $table.currentVersion, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GroceryVersionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GroceryVersionsTableTable,
    GroceryVersionsTableData,
    $$GroceryVersionsTableTableFilterComposer,
    $$GroceryVersionsTableTableOrderingComposer,
    $$GroceryVersionsTableTableAnnotationComposer,
    $$GroceryVersionsTableTableCreateCompanionBuilder,
    $$GroceryVersionsTableTableUpdateCompanionBuilder,
    (
      GroceryVersionsTableData,
      BaseReferences<_$AppDatabase, $GroceryVersionsTableTable,
          GroceryVersionsTableData>
    ),
    GroceryVersionsTableData,
    PrefetchHooks Function()> {
  $$GroceryVersionsTableTableTableManager(
      _$AppDatabase db, $GroceryVersionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroceryVersionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroceryVersionsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroceryVersionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<int> currentVersion = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GroceryVersionsTableCompanion(
            groupId: groupId,
            currentVersion: currentVersion,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            Value<int> currentVersion = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              GroceryVersionsTableCompanion.insert(
            groupId: groupId,
            currentVersion: currentVersion,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GroceryVersionsTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $GroceryVersionsTableTable,
        GroceryVersionsTableData,
        $$GroceryVersionsTableTableFilterComposer,
        $$GroceryVersionsTableTableOrderingComposer,
        $$GroceryVersionsTableTableAnnotationComposer,
        $$GroceryVersionsTableTableCreateCompanionBuilder,
        $$GroceryVersionsTableTableUpdateCompanionBuilder,
        (
          GroceryVersionsTableData,
          BaseReferences<_$AppDatabase, $GroceryVersionsTableTable,
              GroceryVersionsTableData>
        ),
        GroceryVersionsTableData,
        PrefetchHooks Function()>;
typedef $$LocalItemSignalsTableTableCreateCompanionBuilder
    = LocalItemSignalsTableCompanion Function({
  required String groupId,
  required String normalizedName,
  required String displayName,
  Value<int> count,
  Value<String?> promotedCanonicalItemId,
  required DateTime firstSeen,
  required DateTime lastSeen,
  Value<int> rowid,
});
typedef $$LocalItemSignalsTableTableUpdateCompanionBuilder
    = LocalItemSignalsTableCompanion Function({
  Value<String> groupId,
  Value<String> normalizedName,
  Value<String> displayName,
  Value<int> count,
  Value<String?> promotedCanonicalItemId,
  Value<DateTime> firstSeen,
  Value<DateTime> lastSeen,
  Value<int> rowid,
});

class $$LocalItemSignalsTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalItemSignalsTableTable> {
  $$LocalItemSignalsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get promotedCanonicalItemId => $composableBuilder(
      column: $table.promotedCanonicalItemId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get firstSeen => $composableBuilder(
      column: $table.firstSeen, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnFilters(column));
}

class $$LocalItemSignalsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalItemSignalsTableTable> {
  $$LocalItemSignalsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get promotedCanonicalItemId => $composableBuilder(
      column: $table.promotedCanonicalItemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get firstSeen => $composableBuilder(
      column: $table.firstSeen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
      column: $table.lastSeen, builder: (column) => ColumnOrderings(column));
}

class $$LocalItemSignalsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalItemSignalsTableTable> {
  $$LocalItemSignalsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<String> get promotedCanonicalItemId => $composableBuilder(
      column: $table.promotedCanonicalItemId, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$LocalItemSignalsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalItemSignalsTableTable,
    LocalItemSignalsTableData,
    $$LocalItemSignalsTableTableFilterComposer,
    $$LocalItemSignalsTableTableOrderingComposer,
    $$LocalItemSignalsTableTableAnnotationComposer,
    $$LocalItemSignalsTableTableCreateCompanionBuilder,
    $$LocalItemSignalsTableTableUpdateCompanionBuilder,
    (
      LocalItemSignalsTableData,
      BaseReferences<_$AppDatabase, $LocalItemSignalsTableTable,
          LocalItemSignalsTableData>
    ),
    LocalItemSignalsTableData,
    PrefetchHooks Function()> {
  $$LocalItemSignalsTableTableTableManager(
      _$AppDatabase db, $LocalItemSignalsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalItemSignalsTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalItemSignalsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalItemSignalsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<String> normalizedName = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<int> count = const Value.absent(),
            Value<String?> promotedCanonicalItemId = const Value.absent(),
            Value<DateTime> firstSeen = const Value.absent(),
            Value<DateTime> lastSeen = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalItemSignalsTableCompanion(
            groupId: groupId,
            normalizedName: normalizedName,
            displayName: displayName,
            count: count,
            promotedCanonicalItemId: promotedCanonicalItemId,
            firstSeen: firstSeen,
            lastSeen: lastSeen,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            required String normalizedName,
            required String displayName,
            Value<int> count = const Value.absent(),
            Value<String?> promotedCanonicalItemId = const Value.absent(),
            required DateTime firstSeen,
            required DateTime lastSeen,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalItemSignalsTableCompanion.insert(
            groupId: groupId,
            normalizedName: normalizedName,
            displayName: displayName,
            count: count,
            promotedCanonicalItemId: promotedCanonicalItemId,
            firstSeen: firstSeen,
            lastSeen: lastSeen,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalItemSignalsTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalItemSignalsTableTable,
        LocalItemSignalsTableData,
        $$LocalItemSignalsTableTableFilterComposer,
        $$LocalItemSignalsTableTableOrderingComposer,
        $$LocalItemSignalsTableTableAnnotationComposer,
        $$LocalItemSignalsTableTableCreateCompanionBuilder,
        $$LocalItemSignalsTableTableUpdateCompanionBuilder,
        (
          LocalItemSignalsTableData,
          BaseReferences<_$AppDatabase, $LocalItemSignalsTableTable,
              LocalItemSignalsTableData>
        ),
        LocalItemSignalsTableData,
        PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ListsTableTableTableManager get listsTable =>
      $$ListsTableTableTableManager(_db, _db.listsTable);
  $$ListItemsTableTableTableManager get listItemsTable =>
      $$ListItemsTableTableTableManager(_db, _db.listItemsTable);
  $$ExpensesTableTableTableManager get expensesTable =>
      $$ExpensesTableTableTableManager(_db, _db.expensesTable);
  $$FinanceSummariesTableTableManager get financeSummaries =>
      $$FinanceSummariesTableTableManager(_db, _db.financeSummaries);
  $$CurrentChoresCachesTableTableManager get currentChoresCaches =>
      $$CurrentChoresCachesTableTableManager(_db, _db.currentChoresCaches);
  $$RecipesTableTableTableManager get recipesTable =>
      $$RecipesTableTableTableManager(_db, _db.recipesTable);
  $$PinwallPostsCachesTableTableManager get pinwallPostsCaches =>
      $$PinwallPostsCachesTableTableManager(_db, _db.pinwallPostsCaches);
  $$HubGroupCachesTableTableManager get hubGroupCaches =>
      $$HubGroupCachesTableTableManager(_db, _db.hubGroupCaches);
  $$HubActivityCachesTableTableManager get hubActivityCaches =>
      $$HubActivityCachesTableTableManager(_db, _db.hubActivityCaches);
  $$GroupsCachesTableTableManager get groupsCaches =>
      $$GroupsCachesTableTableManager(_db, _db.groupsCaches);
  $$SettlementsCachesTableTableManager get settlementsCaches =>
      $$SettlementsCachesTableTableManager(_db, _db.settlementsCaches);
  $$CalendarCachesTableTableManager get calendarCaches =>
      $$CalendarCachesTableTableManager(_db, _db.calendarCaches);
  $$MealPlanCachesTableTableManager get mealPlanCaches =>
      $$MealPlanCachesTableTableManager(_db, _db.mealPlanCaches);
  $$ResponseCachesTableTableManager get responseCaches =>
      $$ResponseCachesTableTableManager(_db, _db.responseCaches);
  $$OutboxOpsTableTableManager get outboxOps =>
      $$OutboxOpsTableTableManager(_db, _db.outboxOps);
  $$ConflictsTableTableManager get conflicts =>
      $$ConflictsTableTableManager(_db, _db.conflicts);
  $$CanonicalItemsTableTableTableManager get canonicalItemsTable =>
      $$CanonicalItemsTableTableTableManager(_db, _db.canonicalItemsTable);
  $$ItemAliasesTableTableTableManager get itemAliasesTable =>
      $$ItemAliasesTableTableTableManager(_db, _db.itemAliasesTable);
  $$CorrectionsTableTableTableManager get correctionsTable =>
      $$CorrectionsTableTableTableManager(_db, _db.correctionsTable);
  $$StoreAislesTableTableTableManager get storeAislesTable =>
      $$StoreAislesTableTableTableManager(_db, _db.storeAislesTable);
  $$PurchaseHistoryTableTableTableManager get purchaseHistoryTable =>
      $$PurchaseHistoryTableTableTableManager(_db, _db.purchaseHistoryTable);
  $$ItemCooccurrenceTableTableTableManager get itemCooccurrenceTable =>
      $$ItemCooccurrenceTableTableTableManager(_db, _db.itemCooccurrenceTable);
  $$ScanArtifactsTableTableTableManager get scanArtifactsTable =>
      $$ScanArtifactsTableTableTableManager(_db, _db.scanArtifactsTable);
  $$GroceryVersionsTableTableTableManager get groceryVersionsTable =>
      $$GroceryVersionsTableTableTableManager(_db, _db.groceryVersionsTable);
  $$LocalItemSignalsTableTableTableManager get localItemSignalsTable =>
      $$LocalItemSignalsTableTableTableManager(_db, _db.localItemSignalsTable);
}
