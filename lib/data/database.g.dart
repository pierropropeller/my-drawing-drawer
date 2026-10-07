// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PitsTable extends Pits with TableInfo<$PitsTable, Pit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverImageIdMeta = const VerificationMeta(
    'coverImageId',
  );
  @override
  late final GeneratedColumn<String> coverImageId = GeneratedColumn<String>(
    'cover_image_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _officialCoverIdMeta = const VerificationMeta(
    'officialCoverId',
  );
  @override
  late final GeneratedColumn<String> officialCoverId = GeneratedColumn<String>(
    'official_cover_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fanArtCoverIdMeta = const VerificationMeta(
    'fanArtCoverId',
  );
  @override
  late final GeneratedColumn<String> fanArtCoverId = GeneratedColumn<String>(
    'fan_art_cover_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    name,
    description,
    coverImageId,
    officialCoverId,
    fanArtCoverId,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pits';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cover_image_id')) {
      context.handle(
        _coverImageIdMeta,
        coverImageId.isAcceptableOrUnknown(
          data['cover_image_id']!,
          _coverImageIdMeta,
        ),
      );
    }
    if (data.containsKey('official_cover_id')) {
      context.handle(
        _officialCoverIdMeta,
        officialCoverId.isAcceptableOrUnknown(
          data['official_cover_id']!,
          _officialCoverIdMeta,
        ),
      );
    }
    if (data.containsKey('fan_art_cover_id')) {
      context.handle(
        _fanArtCoverIdMeta,
        fanArtCoverId.isAcceptableOrUnknown(
          data['fan_art_cover_id']!,
          _fanArtCoverIdMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      coverImageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image_id'],
      ),
      officialCoverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}official_cover_id'],
      ),
      fanArtCoverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fan_art_cover_id'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $PitsTable createAlias(String alias) {
    return $PitsTable(attachedDatabase, alias);
  }
}

class Pit extends DataClass implements Insertable<Pit> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String name;
  final String? description;
  final String? coverImageId;

  /// 坑內「官方圖冊」「好看同人圖」兩格各自的封面（預覽頁的「設為封面」設的是這裡）。
  /// 主頁坑卡片的封面是 [coverImageId]，由長按坑內頁的格子選擇。
  final String? officialCoverId;
  final String? fanArtCoverId;
  final bool archived;
  const Pit({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.name,
    this.description,
    this.coverImageId,
    this.officialCoverId,
    this.fanArtCoverId,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || coverImageId != null) {
      map['cover_image_id'] = Variable<String>(coverImageId);
    }
    if (!nullToAbsent || officialCoverId != null) {
      map['official_cover_id'] = Variable<String>(officialCoverId);
    }
    if (!nullToAbsent || fanArtCoverId != null) {
      map['fan_art_cover_id'] = Variable<String>(fanArtCoverId);
    }
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  PitsCompanion toCompanion(bool nullToAbsent) {
    return PitsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      coverImageId: coverImageId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImageId),
      officialCoverId: officialCoverId == null && nullToAbsent
          ? const Value.absent()
          : Value(officialCoverId),
      fanArtCoverId: fanArtCoverId == null && nullToAbsent
          ? const Value.absent()
          : Value(fanArtCoverId),
      archived: Value(archived),
    );
  }

  factory Pit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pit(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      coverImageId: serializer.fromJson<String?>(json['coverImageId']),
      officialCoverId: serializer.fromJson<String?>(json['officialCoverId']),
      fanArtCoverId: serializer.fromJson<String?>(json['fanArtCoverId']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'coverImageId': serializer.toJson<String?>(coverImageId),
      'officialCoverId': serializer.toJson<String?>(officialCoverId),
      'fanArtCoverId': serializer.toJson<String?>(fanArtCoverId),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Pit copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> coverImageId = const Value.absent(),
    Value<String?> officialCoverId = const Value.absent(),
    Value<String?> fanArtCoverId = const Value.absent(),
    bool? archived,
  }) => Pit(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    coverImageId: coverImageId.present ? coverImageId.value : this.coverImageId,
    officialCoverId: officialCoverId.present
        ? officialCoverId.value
        : this.officialCoverId,
    fanArtCoverId: fanArtCoverId.present
        ? fanArtCoverId.value
        : this.fanArtCoverId,
    archived: archived ?? this.archived,
  );
  Pit copyWithCompanion(PitsCompanion data) {
    return Pit(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      coverImageId: data.coverImageId.present
          ? data.coverImageId.value
          : this.coverImageId,
      officialCoverId: data.officialCoverId.present
          ? data.officialCoverId.value
          : this.officialCoverId,
      fanArtCoverId: data.fanArtCoverId.present
          ? data.fanArtCoverId.value
          : this.fanArtCoverId,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pit(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('coverImageId: $coverImageId, ')
          ..write('officialCoverId: $officialCoverId, ')
          ..write('fanArtCoverId: $fanArtCoverId, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    name,
    description,
    coverImageId,
    officialCoverId,
    fanArtCoverId,
    archived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pit &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.name == this.name &&
          other.description == this.description &&
          other.coverImageId == this.coverImageId &&
          other.officialCoverId == this.officialCoverId &&
          other.fanArtCoverId == this.fanArtCoverId &&
          other.archived == this.archived);
}

class PitsCompanion extends UpdateCompanion<Pit> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> coverImageId;
  final Value<String?> officialCoverId;
  final Value<String?> fanArtCoverId;
  final Value<bool> archived;
  final Value<int> rowid;
  const PitsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.coverImageId = const Value.absent(),
    this.officialCoverId = const Value.absent(),
    this.fanArtCoverId = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PitsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.coverImageId = const Value.absent(),
    this.officialCoverId = const Value.absent(),
    this.fanArtCoverId = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Pit> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? coverImageId,
    Expression<String>? officialCoverId,
    Expression<String>? fanArtCoverId,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (coverImageId != null) 'cover_image_id': coverImageId,
      if (officialCoverId != null) 'official_cover_id': officialCoverId,
      if (fanArtCoverId != null) 'fan_art_cover_id': fanArtCoverId,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PitsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? coverImageId,
    Value<String?>? officialCoverId,
    Value<String?>? fanArtCoverId,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return PitsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImageId: coverImageId ?? this.coverImageId,
      officialCoverId: officialCoverId ?? this.officialCoverId,
      fanArtCoverId: fanArtCoverId ?? this.fanArtCoverId,
      archived: archived ?? this.archived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (coverImageId.present) {
      map['cover_image_id'] = Variable<String>(coverImageId.value);
    }
    if (officialCoverId.present) {
      map['official_cover_id'] = Variable<String>(officialCoverId.value);
    }
    if (fanArtCoverId.present) {
      map['fan_art_cover_id'] = Variable<String>(fanArtCoverId.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PitsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('coverImageId: $coverImageId, ')
          ..write('officialCoverId: $officialCoverId, ')
          ..write('fanArtCoverId: $fanArtCoverId, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfficialGroupsTable extends OfficialGroups
    with TableInfo<$OfficialGroupsTable, OfficialGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfficialGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pitIdMeta = const VerificationMeta('pitId');
  @override
  late final GeneratedColumn<String> pitId = GeneratedColumn<String>(
    'pit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('official'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    kind,
    name,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'official_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfficialGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('pit_id')) {
      context.handle(
        _pitIdMeta,
        pitId.isAcceptableOrUnknown(data['pit_id']!, _pitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pitIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfficialGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfficialGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      pitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pit_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $OfficialGroupsTable createAlias(String alias) {
    return $OfficialGroupsTable(attachedDatabase, alias);
  }
}

class OfficialGroup extends DataClass implements Insertable<OfficialGroup> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String pitId;
  final String kind;
  final String name;
  final int sortOrder;
  const OfficialGroup({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.pitId,
    required this.kind,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['pit_id'] = Variable<String>(pitId);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  OfficialGroupsCompanion toCompanion(bool nullToAbsent) {
    return OfficialGroupsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      pitId: Value(pitId),
      kind: Value(kind),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory OfficialGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfficialGroup(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      pitId: serializer.fromJson<String>(json['pitId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'pitId': serializer.toJson<String>(pitId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  OfficialGroup copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    String? pitId,
    String? kind,
    String? name,
    int? sortOrder,
  }) => OfficialGroup(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    pitId: pitId ?? this.pitId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  OfficialGroup copyWithCompanion(OfficialGroupsCompanion data) {
    return OfficialGroup(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      pitId: data.pitId.present ? data.pitId.value : this.pitId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfficialGroup(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    kind,
    name,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfficialGroup &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.pitId == this.pitId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class OfficialGroupsCompanion extends UpdateCompanion<OfficialGroup> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<String> pitId;
  final Value<String> kind;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const OfficialGroupsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.pitId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfficialGroupsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String pitId,
    this.kind = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pitId = Value(pitId),
       name = Value(name);
  static Insertable<OfficialGroup> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? pitId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (pitId != null) 'pit_id': pitId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfficialGroupsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? pitId,
    Value<String>? kind,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return OfficialGroupsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      pitId: pitId ?? this.pitId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (pitId.present) {
      map['pit_id'] = Variable<String>(pitId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfficialGroupsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfficialImagesTable extends OfficialImages
    with TableInfo<$OfficialImagesTable, OfficialImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfficialImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pitIdMeta = const VerificationMeta('pitId');
  @override
  late final GeneratedColumn<String> pitId = GeneratedColumn<String>(
    'pit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageFileMeta = const VerificationMeta(
    'imageFile',
  );
  @override
  late final GeneratedColumn<String> imageFile = GeneratedColumn<String>(
    'image_file',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    groupId,
    imageFile,
    width,
    height,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'official_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfficialImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('pit_id')) {
      context.handle(
        _pitIdMeta,
        pitId.isAcceptableOrUnknown(data['pit_id']!, _pitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pitIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('image_file')) {
      context.handle(
        _imageFileMeta,
        imageFile.isAcceptableOrUnknown(data['image_file']!, _imageFileMeta),
      );
    } else if (isInserting) {
      context.missing(_imageFileMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfficialImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfficialImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      pitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pit_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      imageFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_file'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
    );
  }

  @override
  $OfficialImagesTable createAlias(String alias) {
    return $OfficialImagesTable(attachedDatabase, alias);
  }
}

class OfficialImage extends DataClass implements Insertable<OfficialImage> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String pitId;
  final String groupId;
  final String imageFile;
  final int width;
  final int height;
  const OfficialImage({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.pitId,
    required this.groupId,
    required this.imageFile,
    required this.width,
    required this.height,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['pit_id'] = Variable<String>(pitId);
    map['group_id'] = Variable<String>(groupId);
    map['image_file'] = Variable<String>(imageFile);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    return map;
  }

  OfficialImagesCompanion toCompanion(bool nullToAbsent) {
    return OfficialImagesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      pitId: Value(pitId),
      groupId: Value(groupId),
      imageFile: Value(imageFile),
      width: Value(width),
      height: Value(height),
    );
  }

  factory OfficialImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfficialImage(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      pitId: serializer.fromJson<String>(json['pitId']),
      groupId: serializer.fromJson<String>(json['groupId']),
      imageFile: serializer.fromJson<String>(json['imageFile']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'pitId': serializer.toJson<String>(pitId),
      'groupId': serializer.toJson<String>(groupId),
      'imageFile': serializer.toJson<String>(imageFile),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
    };
  }

  OfficialImage copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    String? pitId,
    String? groupId,
    String? imageFile,
    int? width,
    int? height,
  }) => OfficialImage(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    pitId: pitId ?? this.pitId,
    groupId: groupId ?? this.groupId,
    imageFile: imageFile ?? this.imageFile,
    width: width ?? this.width,
    height: height ?? this.height,
  );
  OfficialImage copyWithCompanion(OfficialImagesCompanion data) {
    return OfficialImage(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      pitId: data.pitId.present ? data.pitId.value : this.pitId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      imageFile: data.imageFile.present ? data.imageFile.value : this.imageFile,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfficialImage(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('groupId: $groupId, ')
          ..write('imageFile: $imageFile, ')
          ..write('width: $width, ')
          ..write('height: $height')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    groupId,
    imageFile,
    width,
    height,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfficialImage &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.pitId == this.pitId &&
          other.groupId == this.groupId &&
          other.imageFile == this.imageFile &&
          other.width == this.width &&
          other.height == this.height);
}

class OfficialImagesCompanion extends UpdateCompanion<OfficialImage> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<String> pitId;
  final Value<String> groupId;
  final Value<String> imageFile;
  final Value<int> width;
  final Value<int> height;
  final Value<int> rowid;
  const OfficialImagesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.pitId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.imageFile = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfficialImagesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String pitId,
    required String groupId,
    required String imageFile,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pitId = Value(pitId),
       groupId = Value(groupId),
       imageFile = Value(imageFile);
  static Insertable<OfficialImage> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? pitId,
    Expression<String>? groupId,
    Expression<String>? imageFile,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (pitId != null) 'pit_id': pitId,
      if (groupId != null) 'group_id': groupId,
      if (imageFile != null) 'image_file': imageFile,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfficialImagesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? pitId,
    Value<String>? groupId,
    Value<String>? imageFile,
    Value<int>? width,
    Value<int>? height,
    Value<int>? rowid,
  }) {
    return OfficialImagesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      pitId: pitId ?? this.pitId,
      groupId: groupId ?? this.groupId,
      imageFile: imageFile ?? this.imageFile,
      width: width ?? this.width,
      height: height ?? this.height,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (pitId.present) {
      map['pit_id'] = Variable<String>(pitId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (imageFile.present) {
      map['image_file'] = Variable<String>(imageFile.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfficialImagesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('groupId: $groupId, ')
          ..write('imageFile: $imageFile, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FanArtsTable extends FanArts with TableInfo<$FanArtsTable, FanArt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FanArtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pitIdMeta = const VerificationMeta('pitId');
  @override
  late final GeneratedColumn<String> pitId = GeneratedColumn<String>(
    'pit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageFileMeta = const VerificationMeta(
    'imageFile',
  );
  @override
  late final GeneratedColumn<String> imageFile = GeneratedColumn<String>(
    'image_file',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    imageFile,
    width,
    height,
    author,
    source,
    groupId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fan_arts';
  @override
  VerificationContext validateIntegrity(
    Insertable<FanArt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('pit_id')) {
      context.handle(
        _pitIdMeta,
        pitId.isAcceptableOrUnknown(data['pit_id']!, _pitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pitIdMeta);
    }
    if (data.containsKey('image_file')) {
      context.handle(
        _imageFileMeta,
        imageFile.isAcceptableOrUnknown(data['image_file']!, _imageFileMeta),
      );
    } else if (isInserting) {
      context.missing(_imageFileMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FanArt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FanArt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      pitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pit_id'],
      )!,
      imageFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_file'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
    );
  }

  @override
  $FanArtsTable createAlias(String alias) {
    return $FanArtsTable(attachedDatabase, alias);
  }
}

class FanArt extends DataClass implements Insertable<FanArt> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String pitId;
  final String imageFile;
  final int width;
  final int height;
  final String author;

  /// 舊版的出處文字（v5 起改用 [groupId]，保留欄位以相容舊資料）。
  final String source;
  final String? groupId;
  const FanArt({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.pitId,
    required this.imageFile,
    required this.width,
    required this.height,
    required this.author,
    required this.source,
    this.groupId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['pit_id'] = Variable<String>(pitId);
    map['image_file'] = Variable<String>(imageFile);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['author'] = Variable<String>(author);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    return map;
  }

  FanArtsCompanion toCompanion(bool nullToAbsent) {
    return FanArtsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      pitId: Value(pitId),
      imageFile: Value(imageFile),
      width: Value(width),
      height: Value(height),
      author: Value(author),
      source: Value(source),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
    );
  }

  factory FanArt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FanArt(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      pitId: serializer.fromJson<String>(json['pitId']),
      imageFile: serializer.fromJson<String>(json['imageFile']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      author: serializer.fromJson<String>(json['author']),
      source: serializer.fromJson<String>(json['source']),
      groupId: serializer.fromJson<String?>(json['groupId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'pitId': serializer.toJson<String>(pitId),
      'imageFile': serializer.toJson<String>(imageFile),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'author': serializer.toJson<String>(author),
      'source': serializer.toJson<String>(source),
      'groupId': serializer.toJson<String?>(groupId),
    };
  }

  FanArt copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    String? pitId,
    String? imageFile,
    int? width,
    int? height,
    String? author,
    String? source,
    Value<String?> groupId = const Value.absent(),
  }) => FanArt(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    pitId: pitId ?? this.pitId,
    imageFile: imageFile ?? this.imageFile,
    width: width ?? this.width,
    height: height ?? this.height,
    author: author ?? this.author,
    source: source ?? this.source,
    groupId: groupId.present ? groupId.value : this.groupId,
  );
  FanArt copyWithCompanion(FanArtsCompanion data) {
    return FanArt(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      pitId: data.pitId.present ? data.pitId.value : this.pitId,
      imageFile: data.imageFile.present ? data.imageFile.value : this.imageFile,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      author: data.author.present ? data.author.value : this.author,
      source: data.source.present ? data.source.value : this.source,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FanArt(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('imageFile: $imageFile, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('author: $author, ')
          ..write('source: $source, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    imageFile,
    width,
    height,
    author,
    source,
    groupId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FanArt &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.pitId == this.pitId &&
          other.imageFile == this.imageFile &&
          other.width == this.width &&
          other.height == this.height &&
          other.author == this.author &&
          other.source == this.source &&
          other.groupId == this.groupId);
}

class FanArtsCompanion extends UpdateCompanion<FanArt> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<String> pitId;
  final Value<String> imageFile;
  final Value<int> width;
  final Value<int> height;
  final Value<String> author;
  final Value<String> source;
  final Value<String?> groupId;
  final Value<int> rowid;
  const FanArtsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.pitId = const Value.absent(),
    this.imageFile = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.author = const Value.absent(),
    this.source = const Value.absent(),
    this.groupId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FanArtsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String pitId,
    required String imageFile,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.author = const Value.absent(),
    this.source = const Value.absent(),
    this.groupId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pitId = Value(pitId),
       imageFile = Value(imageFile);
  static Insertable<FanArt> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? pitId,
    Expression<String>? imageFile,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? author,
    Expression<String>? source,
    Expression<String>? groupId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (pitId != null) 'pit_id': pitId,
      if (imageFile != null) 'image_file': imageFile,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (author != null) 'author': author,
      if (source != null) 'source': source,
      if (groupId != null) 'group_id': groupId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FanArtsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? pitId,
    Value<String>? imageFile,
    Value<int>? width,
    Value<int>? height,
    Value<String>? author,
    Value<String>? source,
    Value<String?>? groupId,
    Value<int>? rowid,
  }) {
    return FanArtsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      pitId: pitId ?? this.pitId,
      imageFile: imageFile ?? this.imageFile,
      width: width ?? this.width,
      height: height ?? this.height,
      author: author ?? this.author,
      source: source ?? this.source,
      groupId: groupId ?? this.groupId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (pitId.present) {
      map['pit_id'] = Variable<String>(pitId.value);
    }
    if (imageFile.present) {
      map['image_file'] = Variable<String>(imageFile.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FanArtsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('imageFile: $imageFile, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('author: $author, ')
          ..write('source: $source, ')
          ..write('groupId: $groupId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pitIdMeta = const VerificationMeta('pitId');
  @override
  late final GeneratedColumn<String> pitId = GeneratedColumn<String>(
    'pit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    name,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('pit_id')) {
      context.handle(
        _pitIdMeta,
        pitId.isAcceptableOrUnknown(data['pit_id']!, _pitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pitIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      pitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pit_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String pitId;
  final String name;
  const Tag({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.pitId,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['pit_id'] = Variable<String>(pitId);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      pitId: Value(pitId),
      name: Value(name),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      pitId: serializer.fromJson<String>(json['pitId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'pitId': serializer.toJson<String>(pitId),
      'name': serializer.toJson<String>(name),
    };
  }

  Tag copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    String? pitId,
    String? name,
  }) => Tag(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    pitId: pitId ?? this.pitId,
    name: name ?? this.name,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      pitId: data.pitId.present ? data.pitId.value : this.pitId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, updatedAt, deletedAt, deviceId, pitId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.pitId == this.pitId &&
          other.name == this.name);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<String> pitId;
  final Value<String> name;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.pitId = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String pitId,
    required String name,
    this.rowid = const Value.absent(),
  }) : pitId = Value(pitId),
       name = Value(name);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? pitId,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (pitId != null) 'pit_id': pitId,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? pitId,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      pitId: pitId ?? this.pitId,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (pitId.present) {
      map['pit_id'] = Variable<String>(pitId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdeasTable extends Ideas with TableInfo<$IdeasTable, Idea> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdeasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pitIdMeta = const VerificationMeta('pitId');
  @override
  late final GeneratedColumn<String> pitId = GeneratedColumn<String>(
    'pit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    title,
    body,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ideas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Idea> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('pit_id')) {
      context.handle(
        _pitIdMeta,
        pitId.isAcceptableOrUnknown(data['pit_id']!, _pitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pitIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Idea map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Idea(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      pitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pit_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  $IdeasTable createAlias(String alias) {
    return $IdeasTable(attachedDatabase, alias);
  }
}

class Idea extends DataClass implements Insertable<Idea> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String pitId;
  final String title;
  final String body;
  const Idea({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.pitId,
    required this.title,
    required this.body,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['pit_id'] = Variable<String>(pitId);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    return map;
  }

  IdeasCompanion toCompanion(bool nullToAbsent) {
    return IdeasCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      pitId: Value(pitId),
      title: Value(title),
      body: Value(body),
    );
  }

  factory Idea.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Idea(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      pitId: serializer.fromJson<String>(json['pitId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'pitId': serializer.toJson<String>(pitId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
    };
  }

  Idea copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    String? pitId,
    String? title,
    String? body,
  }) => Idea(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    pitId: pitId ?? this.pitId,
    title: title ?? this.title,
    body: body ?? this.body,
  );
  Idea copyWithCompanion(IdeasCompanion data) {
    return Idea(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      pitId: data.pitId.present ? data.pitId.value : this.pitId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Idea(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('title: $title, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    title,
    body,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Idea &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.pitId == this.pitId &&
          other.title == this.title &&
          other.body == this.body);
}

class IdeasCompanion extends UpdateCompanion<Idea> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<String> pitId;
  final Value<String> title;
  final Value<String> body;
  final Value<int> rowid;
  const IdeasCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.pitId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdeasCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String pitId,
    required String title,
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pitId = Value(pitId),
       title = Value(title);
  static Insertable<Idea> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? pitId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (pitId != null) 'pit_id': pitId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdeasCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? pitId,
    Value<String>? title,
    Value<String>? body,
    Value<int>? rowid,
  }) {
    return IdeasCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      pitId: pitId ?? this.pitId,
      title: title ?? this.title,
      body: body ?? this.body,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (pitId.present) {
      map['pit_id'] = Variable<String>(pitId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdeasCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, Draft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pitIdMeta = const VerificationMeta('pitId');
  @override
  late final GeneratedColumn<String> pitId = GeneratedColumn<String>(
    'pit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    title,
    body,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Draft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('pit_id')) {
      context.handle(
        _pitIdMeta,
        pitId.isAcceptableOrUnknown(data['pit_id']!, _pitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pitIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Draft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Draft(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      pitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pit_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class Draft extends DataClass implements Insertable<Draft> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String pitId;
  final String? title;
  final String? body;
  const Draft({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.pitId,
    this.title,
    this.body,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['pit_id'] = Variable<String>(pitId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      pitId: Value(pitId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
    );
  }

  factory Draft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Draft(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      pitId: serializer.fromJson<String>(json['pitId']),
      title: serializer.fromJson<String?>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'pitId': serializer.toJson<String>(pitId),
      'title': serializer.toJson<String?>(title),
      'body': serializer.toJson<String?>(body),
    };
  }

  Draft copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    String? pitId,
    Value<String?> title = const Value.absent(),
    Value<String?> body = const Value.absent(),
  }) => Draft(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    pitId: pitId ?? this.pitId,
    title: title.present ? title.value : this.title,
    body: body.present ? body.value : this.body,
  );
  Draft copyWithCompanion(DraftsCompanion data) {
    return Draft(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      pitId: data.pitId.present ? data.pitId.value : this.pitId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Draft(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('title: $title, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    title,
    body,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Draft &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.pitId == this.pitId &&
          other.title == this.title &&
          other.body == this.body);
}

class DraftsCompanion extends UpdateCompanion<Draft> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<String> pitId;
  final Value<String?> title;
  final Value<String?> body;
  final Value<int> rowid;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.pitId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String pitId,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pitId = Value(pitId);
  static Insertable<Draft> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? pitId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (pitId != null) 'pit_id': pitId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? pitId,
    Value<String?>? title,
    Value<String?>? body,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      pitId: pitId ?? this.pitId,
      title: title ?? this.title,
      body: body ?? this.body,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (pitId.present) {
      map['pit_id'] = Variable<String>(pitId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PiecesTable extends Pieces with TableInfo<$PiecesTable, Piece> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PiecesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pitIdMeta = const VerificationMeta('pitId');
  @override
  late final GeneratedColumn<String> pitId = GeneratedColumn<String>(
    'pit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _targetLikesMeta = const VerificationMeta(
    'targetLikes',
  );
  @override
  late final GeneratedColumn<int> targetLikes = GeneratedColumn<int>(
    'target_likes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _actualLikesMeta = const VerificationMeta(
    'actualLikes',
  );
  @override
  late final GeneratedColumn<int> actualLikes = GeneratedColumn<int>(
    'actual_likes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    title,
    body,
    targetLikes,
    actualLikes,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pieces';
  @override
  VerificationContext validateIntegrity(
    Insertable<Piece> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('pit_id')) {
      context.handle(
        _pitIdMeta,
        pitId.isAcceptableOrUnknown(data['pit_id']!, _pitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pitIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('target_likes')) {
      context.handle(
        _targetLikesMeta,
        targetLikes.isAcceptableOrUnknown(
          data['target_likes']!,
          _targetLikesMeta,
        ),
      );
    }
    if (data.containsKey('actual_likes')) {
      context.handle(
        _actualLikesMeta,
        actualLikes.isAcceptableOrUnknown(
          data['actual_likes']!,
          _actualLikesMeta,
        ),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Piece map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Piece(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      pitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pit_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      targetLikes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_likes'],
      )!,
      actualLikes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_likes'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      )!,
    );
  }

  @override
  $PiecesTable createAlias(String alias) {
    return $PiecesTable(attachedDatabase, alias);
  }
}

class Piece extends DataClass implements Insertable<Piece> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String pitId;
  final String title;
  final String body;
  final int targetLikes;
  final int actualLikes;
  final DateTime finishedAt;
  const Piece({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.pitId,
    required this.title,
    required this.body,
    required this.targetLikes,
    required this.actualLikes,
    required this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['pit_id'] = Variable<String>(pitId);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['target_likes'] = Variable<int>(targetLikes);
    map['actual_likes'] = Variable<int>(actualLikes);
    map['finished_at'] = Variable<DateTime>(finishedAt);
    return map;
  }

  PiecesCompanion toCompanion(bool nullToAbsent) {
    return PiecesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      pitId: Value(pitId),
      title: Value(title),
      body: Value(body),
      targetLikes: Value(targetLikes),
      actualLikes: Value(actualLikes),
      finishedAt: Value(finishedAt),
    );
  }

  factory Piece.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Piece(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      pitId: serializer.fromJson<String>(json['pitId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      targetLikes: serializer.fromJson<int>(json['targetLikes']),
      actualLikes: serializer.fromJson<int>(json['actualLikes']),
      finishedAt: serializer.fromJson<DateTime>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'pitId': serializer.toJson<String>(pitId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'targetLikes': serializer.toJson<int>(targetLikes),
      'actualLikes': serializer.toJson<int>(actualLikes),
      'finishedAt': serializer.toJson<DateTime>(finishedAt),
    };
  }

  Piece copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    String? pitId,
    String? title,
    String? body,
    int? targetLikes,
    int? actualLikes,
    DateTime? finishedAt,
  }) => Piece(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    pitId: pitId ?? this.pitId,
    title: title ?? this.title,
    body: body ?? this.body,
    targetLikes: targetLikes ?? this.targetLikes,
    actualLikes: actualLikes ?? this.actualLikes,
    finishedAt: finishedAt ?? this.finishedAt,
  );
  Piece copyWithCompanion(PiecesCompanion data) {
    return Piece(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      pitId: data.pitId.present ? data.pitId.value : this.pitId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      targetLikes: data.targetLikes.present
          ? data.targetLikes.value
          : this.targetLikes,
      actualLikes: data.actualLikes.present
          ? data.actualLikes.value
          : this.actualLikes,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Piece(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('targetLikes: $targetLikes, ')
          ..write('actualLikes: $actualLikes, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pitId,
    title,
    body,
    targetLikes,
    actualLikes,
    finishedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Piece &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.pitId == this.pitId &&
          other.title == this.title &&
          other.body == this.body &&
          other.targetLikes == this.targetLikes &&
          other.actualLikes == this.actualLikes &&
          other.finishedAt == this.finishedAt);
}

class PiecesCompanion extends UpdateCompanion<Piece> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<String> pitId;
  final Value<String> title;
  final Value<String> body;
  final Value<int> targetLikes;
  final Value<int> actualLikes;
  final Value<DateTime> finishedAt;
  final Value<int> rowid;
  const PiecesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.pitId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.targetLikes = const Value.absent(),
    this.actualLikes = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PiecesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String pitId,
    required String title,
    this.body = const Value.absent(),
    this.targetLikes = const Value.absent(),
    this.actualLikes = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pitId = Value(pitId),
       title = Value(title);
  static Insertable<Piece> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? pitId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? targetLikes,
    Expression<int>? actualLikes,
    Expression<DateTime>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (pitId != null) 'pit_id': pitId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (targetLikes != null) 'target_likes': targetLikes,
      if (actualLikes != null) 'actual_likes': actualLikes,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PiecesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? pitId,
    Value<String>? title,
    Value<String>? body,
    Value<int>? targetLikes,
    Value<int>? actualLikes,
    Value<DateTime>? finishedAt,
    Value<int>? rowid,
  }) {
    return PiecesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      pitId: pitId ?? this.pitId,
      title: title ?? this.title,
      body: body ?? this.body,
      targetLikes: targetLikes ?? this.targetLikes,
      actualLikes: actualLikes ?? this.actualLikes,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (pitId.present) {
      map['pit_id'] = Variable<String>(pitId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (targetLikes.present) {
      map['target_likes'] = Variable<int>(targetLikes.value);
    }
    if (actualLikes.present) {
      map['actual_likes'] = Variable<int>(actualLikes.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PiecesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pitId: $pitId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('targetLikes: $targetLikes, ')
          ..write('actualLikes: $actualLikes, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntityImagesTable extends EntityImages
    with TableInfo<$EntityImagesTable, EntityImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntityImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<OwnerType, String> ownerType =
      GeneratedColumn<String>(
        'owner_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<OwnerType>($EntityImagesTable.$converterownerType);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageFileMeta = const VerificationMeta(
    'imageFile',
  );
  @override
  late final GeneratedColumn<String> imageFile = GeneratedColumn<String>(
    'image_file',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    ownerType,
    ownerId,
    imageFile,
    width,
    height,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entity_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntityImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('image_file')) {
      context.handle(
        _imageFileMeta,
        imageFile.isAcceptableOrUnknown(data['image_file']!, _imageFileMeta),
      );
    } else if (isInserting) {
      context.missing(_imageFileMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntityImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntityImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      ownerType: $EntityImagesTable.$converterownerType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}owner_type'],
        )!,
      ),
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      imageFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_file'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $EntityImagesTable createAlias(String alias) {
    return $EntityImagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OwnerType, String, String> $converterownerType =
      const EnumNameConverter<OwnerType>(OwnerType.values);
}

class EntityImage extends DataClass implements Insertable<EntityImage> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final OwnerType ownerType;
  final String ownerId;
  final String imageFile;
  final int width;
  final int height;
  final int sortOrder;
  const EntityImage({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.ownerType,
    required this.ownerId,
    required this.imageFile,
    required this.width,
    required this.height,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    {
      map['owner_type'] = Variable<String>(
        $EntityImagesTable.$converterownerType.toSql(ownerType),
      );
    }
    map['owner_id'] = Variable<String>(ownerId);
    map['image_file'] = Variable<String>(imageFile);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  EntityImagesCompanion toCompanion(bool nullToAbsent) {
    return EntityImagesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      ownerType: Value(ownerType),
      ownerId: Value(ownerId),
      imageFile: Value(imageFile),
      width: Value(width),
      height: Value(height),
      sortOrder: Value(sortOrder),
    );
  }

  factory EntityImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntityImage(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      ownerType: $EntityImagesTable.$converterownerType.fromJson(
        serializer.fromJson<String>(json['ownerType']),
      ),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      imageFile: serializer.fromJson<String>(json['imageFile']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'ownerType': serializer.toJson<String>(
        $EntityImagesTable.$converterownerType.toJson(ownerType),
      ),
      'ownerId': serializer.toJson<String>(ownerId),
      'imageFile': serializer.toJson<String>(imageFile),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  EntityImage copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    OwnerType? ownerType,
    String? ownerId,
    String? imageFile,
    int? width,
    int? height,
    int? sortOrder,
  }) => EntityImage(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    ownerType: ownerType ?? this.ownerType,
    ownerId: ownerId ?? this.ownerId,
    imageFile: imageFile ?? this.imageFile,
    width: width ?? this.width,
    height: height ?? this.height,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  EntityImage copyWithCompanion(EntityImagesCompanion data) {
    return EntityImage(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      ownerType: data.ownerType.present ? data.ownerType.value : this.ownerType,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      imageFile: data.imageFile.present ? data.imageFile.value : this.imageFile,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntityImage(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('ownerType: $ownerType, ')
          ..write('ownerId: $ownerId, ')
          ..write('imageFile: $imageFile, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    ownerType,
    ownerId,
    imageFile,
    width,
    height,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntityImage &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.ownerType == this.ownerType &&
          other.ownerId == this.ownerId &&
          other.imageFile == this.imageFile &&
          other.width == this.width &&
          other.height == this.height &&
          other.sortOrder == this.sortOrder);
}

class EntityImagesCompanion extends UpdateCompanion<EntityImage> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<OwnerType> ownerType;
  final Value<String> ownerId;
  final Value<String> imageFile;
  final Value<int> width;
  final Value<int> height;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const EntityImagesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.ownerType = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.imageFile = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntityImagesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required OwnerType ownerType,
    required String ownerId,
    required String imageFile,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerType = Value(ownerType),
       ownerId = Value(ownerId),
       imageFile = Value(imageFile);
  static Insertable<EntityImage> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? ownerType,
    Expression<String>? ownerId,
    Expression<String>? imageFile,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (ownerType != null) 'owner_type': ownerType,
      if (ownerId != null) 'owner_id': ownerId,
      if (imageFile != null) 'image_file': imageFile,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntityImagesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<OwnerType>? ownerType,
    Value<String>? ownerId,
    Value<String>? imageFile,
    Value<int>? width,
    Value<int>? height,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return EntityImagesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      imageFile: imageFile ?? this.imageFile,
      width: width ?? this.width,
      height: height ?? this.height,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (ownerType.present) {
      map['owner_type'] = Variable<String>(
        $EntityImagesTable.$converterownerType.toSql(ownerType.value),
      );
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (imageFile.present) {
      map['image_file'] = Variable<String>(imageFile.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntityImagesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('ownerType: $ownerType, ')
          ..write('ownerId: $ownerId, ')
          ..write('imageFile: $imageFile, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PieceLinksTable extends PieceLinks
    with TableInfo<$PieceLinksTable, PieceLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PieceLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pieceIdMeta = const VerificationMeta(
    'pieceId',
  );
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
    'piece_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pieceId,
    platform,
    url,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'piece_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<PieceLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('piece_id')) {
      context.handle(
        _pieceIdMeta,
        pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PieceLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PieceLink(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      pieceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}piece_id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
    );
  }

  @override
  $PieceLinksTable createAlias(String alias) {
    return $PieceLinksTable(attachedDatabase, alias);
  }
}

class PieceLink extends DataClass implements Insertable<PieceLink> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String pieceId;
  final String platform;
  final String url;
  const PieceLink({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.pieceId,
    required this.platform,
    required this.url,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['piece_id'] = Variable<String>(pieceId);
    map['platform'] = Variable<String>(platform);
    map['url'] = Variable<String>(url);
    return map;
  }

  PieceLinksCompanion toCompanion(bool nullToAbsent) {
    return PieceLinksCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      pieceId: Value(pieceId),
      platform: Value(platform),
      url: Value(url),
    );
  }

  factory PieceLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PieceLink(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      pieceId: serializer.fromJson<String>(json['pieceId']),
      platform: serializer.fromJson<String>(json['platform']),
      url: serializer.fromJson<String>(json['url']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'pieceId': serializer.toJson<String>(pieceId),
      'platform': serializer.toJson<String>(platform),
      'url': serializer.toJson<String>(url),
    };
  }

  PieceLink copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    String? pieceId,
    String? platform,
    String? url,
  }) => PieceLink(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    pieceId: pieceId ?? this.pieceId,
    platform: platform ?? this.platform,
    url: url ?? this.url,
  );
  PieceLink copyWithCompanion(PieceLinksCompanion data) {
    return PieceLink(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
      platform: data.platform.present ? data.platform.value : this.platform,
      url: data.url.present ? data.url.value : this.url,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PieceLink(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pieceId: $pieceId, ')
          ..write('platform: $platform, ')
          ..write('url: $url')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    pieceId,
    platform,
    url,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PieceLink &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.pieceId == this.pieceId &&
          other.platform == this.platform &&
          other.url == this.url);
}

class PieceLinksCompanion extends UpdateCompanion<PieceLink> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<String> pieceId;
  final Value<String> platform;
  final Value<String> url;
  final Value<int> rowid;
  const PieceLinksCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.platform = const Value.absent(),
    this.url = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PieceLinksCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String pieceId,
    required String platform,
    required String url,
    this.rowid = const Value.absent(),
  }) : pieceId = Value(pieceId),
       platform = Value(platform),
       url = Value(url);
  static Insertable<PieceLink> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? pieceId,
    Expression<String>? platform,
    Expression<String>? url,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (pieceId != null) 'piece_id': pieceId,
      if (platform != null) 'platform': platform,
      if (url != null) 'url': url,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PieceLinksCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? pieceId,
    Value<String>? platform,
    Value<String>? url,
    Value<int>? rowid,
  }) {
    return PieceLinksCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      pieceId: pieceId ?? this.pieceId,
      platform: platform ?? this.platform,
      url: url ?? this.url,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PieceLinksCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('pieceId: $pieceId, ')
          ..write('platform: $platform, ')
          ..write('url: $url, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagLinksTable extends TagLinks with TableInfo<$TagLinksTable, TagLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TagTarget, String> targetType =
      GeneratedColumn<String>(
        'target_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TagTarget>($TagLinksTable.$convertertargetType);
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tagId, targetType, targetId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tagId, targetType, targetId};
  @override
  TagLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagLink(
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      targetType: $TagLinksTable.$convertertargetType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}target_type'],
        )!,
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
    );
  }

  @override
  $TagLinksTable createAlias(String alias) {
    return $TagLinksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TagTarget, String, String> $convertertargetType =
      const EnumNameConverter<TagTarget>(TagTarget.values);
}

class TagLink extends DataClass implements Insertable<TagLink> {
  final String tagId;
  final TagTarget targetType;
  final String targetId;
  const TagLink({
    required this.tagId,
    required this.targetType,
    required this.targetId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag_id'] = Variable<String>(tagId);
    {
      map['target_type'] = Variable<String>(
        $TagLinksTable.$convertertargetType.toSql(targetType),
      );
    }
    map['target_id'] = Variable<String>(targetId);
    return map;
  }

  TagLinksCompanion toCompanion(bool nullToAbsent) {
    return TagLinksCompanion(
      tagId: Value(tagId),
      targetType: Value(targetType),
      targetId: Value(targetId),
    );
  }

  factory TagLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagLink(
      tagId: serializer.fromJson<String>(json['tagId']),
      targetType: $TagLinksTable.$convertertargetType.fromJson(
        serializer.fromJson<String>(json['targetType']),
      ),
      targetId: serializer.fromJson<String>(json['targetId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tagId': serializer.toJson<String>(tagId),
      'targetType': serializer.toJson<String>(
        $TagLinksTable.$convertertargetType.toJson(targetType),
      ),
      'targetId': serializer.toJson<String>(targetId),
    };
  }

  TagLink copyWith({String? tagId, TagTarget? targetType, String? targetId}) =>
      TagLink(
        tagId: tagId ?? this.tagId,
        targetType: targetType ?? this.targetType,
        targetId: targetId ?? this.targetId,
      );
  TagLink copyWithCompanion(TagLinksCompanion data) {
    return TagLink(
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      targetType: data.targetType.present
          ? data.targetType.value
          : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagLink(')
          ..write('tagId: $tagId, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tagId, targetType, targetId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagLink &&
          other.tagId == this.tagId &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId);
}

class TagLinksCompanion extends UpdateCompanion<TagLink> {
  final Value<String> tagId;
  final Value<TagTarget> targetType;
  final Value<String> targetId;
  final Value<int> rowid;
  const TagLinksCompanion({
    this.tagId = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagLinksCompanion.insert({
    required String tagId,
    required TagTarget targetType,
    required String targetId,
    this.rowid = const Value.absent(),
  }) : tagId = Value(tagId),
       targetType = Value(targetType),
       targetId = Value(targetId);
  static Insertable<TagLink> custom({
    Expression<String>? tagId,
    Expression<String>? targetType,
    Expression<String>? targetId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tagId != null) 'tag_id': tagId,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagLinksCompanion copyWith({
    Value<String>? tagId,
    Value<TagTarget>? targetType,
    Value<String>? targetId,
    Value<int>? rowid,
  }) {
    return TagLinksCompanion(
      tagId: tagId ?? this.tagId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(
        $TagLinksTable.$convertertargetType.toSql(targetType.value),
      );
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagLinksCompanion(')
          ..write('tagId: $tagId, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdeaDraftsTable extends IdeaDrafts
    with TableInfo<$IdeaDraftsTable, IdeaDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdeaDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ideaIdMeta = const VerificationMeta('ideaId');
  @override
  late final GeneratedColumn<String> ideaId = GeneratedColumn<String>(
    'idea_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draft_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [ideaId, draftId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'idea_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdeaDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('idea_id')) {
      context.handle(
        _ideaIdMeta,
        ideaId.isAcceptableOrUnknown(data['idea_id']!, _ideaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ideaIdMeta);
    }
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ideaId, draftId};
  @override
  IdeaDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdeaDraft(
      ideaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idea_id'],
      )!,
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_id'],
      )!,
    );
  }

  @override
  $IdeaDraftsTable createAlias(String alias) {
    return $IdeaDraftsTable(attachedDatabase, alias);
  }
}

class IdeaDraft extends DataClass implements Insertable<IdeaDraft> {
  final String ideaId;
  final String draftId;
  const IdeaDraft({required this.ideaId, required this.draftId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['idea_id'] = Variable<String>(ideaId);
    map['draft_id'] = Variable<String>(draftId);
    return map;
  }

  IdeaDraftsCompanion toCompanion(bool nullToAbsent) {
    return IdeaDraftsCompanion(ideaId: Value(ideaId), draftId: Value(draftId));
  }

  factory IdeaDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdeaDraft(
      ideaId: serializer.fromJson<String>(json['ideaId']),
      draftId: serializer.fromJson<String>(json['draftId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ideaId': serializer.toJson<String>(ideaId),
      'draftId': serializer.toJson<String>(draftId),
    };
  }

  IdeaDraft copyWith({String? ideaId, String? draftId}) => IdeaDraft(
    ideaId: ideaId ?? this.ideaId,
    draftId: draftId ?? this.draftId,
  );
  IdeaDraft copyWithCompanion(IdeaDraftsCompanion data) {
    return IdeaDraft(
      ideaId: data.ideaId.present ? data.ideaId.value : this.ideaId,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdeaDraft(')
          ..write('ideaId: $ideaId, ')
          ..write('draftId: $draftId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ideaId, draftId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdeaDraft &&
          other.ideaId == this.ideaId &&
          other.draftId == this.draftId);
}

class IdeaDraftsCompanion extends UpdateCompanion<IdeaDraft> {
  final Value<String> ideaId;
  final Value<String> draftId;
  final Value<int> rowid;
  const IdeaDraftsCompanion({
    this.ideaId = const Value.absent(),
    this.draftId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdeaDraftsCompanion.insert({
    required String ideaId,
    required String draftId,
    this.rowid = const Value.absent(),
  }) : ideaId = Value(ideaId),
       draftId = Value(draftId);
  static Insertable<IdeaDraft> custom({
    Expression<String>? ideaId,
    Expression<String>? draftId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ideaId != null) 'idea_id': ideaId,
      if (draftId != null) 'draft_id': draftId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdeaDraftsCompanion copyWith({
    Value<String>? ideaId,
    Value<String>? draftId,
    Value<int>? rowid,
  }) {
    return IdeaDraftsCompanion(
      ideaId: ideaId ?? this.ideaId,
      draftId: draftId ?? this.draftId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ideaId.present) {
      map['idea_id'] = Variable<String>(ideaId.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<String>(draftId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdeaDraftsCompanion(')
          ..write('ideaId: $ideaId, ')
          ..write('draftId: $draftId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdeaPiecesTable extends IdeaPieces
    with TableInfo<$IdeaPiecesTable, IdeaPiece> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdeaPiecesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ideaIdMeta = const VerificationMeta('ideaId');
  @override
  late final GeneratedColumn<String> ideaId = GeneratedColumn<String>(
    'idea_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pieceIdMeta = const VerificationMeta(
    'pieceId',
  );
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
    'piece_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [ideaId, pieceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'idea_pieces';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdeaPiece> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('idea_id')) {
      context.handle(
        _ideaIdMeta,
        ideaId.isAcceptableOrUnknown(data['idea_id']!, _ideaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ideaIdMeta);
    }
    if (data.containsKey('piece_id')) {
      context.handle(
        _pieceIdMeta,
        pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ideaId, pieceId};
  @override
  IdeaPiece map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdeaPiece(
      ideaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idea_id'],
      )!,
      pieceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}piece_id'],
      )!,
    );
  }

  @override
  $IdeaPiecesTable createAlias(String alias) {
    return $IdeaPiecesTable(attachedDatabase, alias);
  }
}

class IdeaPiece extends DataClass implements Insertable<IdeaPiece> {
  final String ideaId;
  final String pieceId;
  const IdeaPiece({required this.ideaId, required this.pieceId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['idea_id'] = Variable<String>(ideaId);
    map['piece_id'] = Variable<String>(pieceId);
    return map;
  }

  IdeaPiecesCompanion toCompanion(bool nullToAbsent) {
    return IdeaPiecesCompanion(ideaId: Value(ideaId), pieceId: Value(pieceId));
  }

  factory IdeaPiece.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdeaPiece(
      ideaId: serializer.fromJson<String>(json['ideaId']),
      pieceId: serializer.fromJson<String>(json['pieceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ideaId': serializer.toJson<String>(ideaId),
      'pieceId': serializer.toJson<String>(pieceId),
    };
  }

  IdeaPiece copyWith({String? ideaId, String? pieceId}) => IdeaPiece(
    ideaId: ideaId ?? this.ideaId,
    pieceId: pieceId ?? this.pieceId,
  );
  IdeaPiece copyWithCompanion(IdeaPiecesCompanion data) {
    return IdeaPiece(
      ideaId: data.ideaId.present ? data.ideaId.value : this.ideaId,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdeaPiece(')
          ..write('ideaId: $ideaId, ')
          ..write('pieceId: $pieceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ideaId, pieceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdeaPiece &&
          other.ideaId == this.ideaId &&
          other.pieceId == this.pieceId);
}

class IdeaPiecesCompanion extends UpdateCompanion<IdeaPiece> {
  final Value<String> ideaId;
  final Value<String> pieceId;
  final Value<int> rowid;
  const IdeaPiecesCompanion({
    this.ideaId = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdeaPiecesCompanion.insert({
    required String ideaId,
    required String pieceId,
    this.rowid = const Value.absent(),
  }) : ideaId = Value(ideaId),
       pieceId = Value(pieceId);
  static Insertable<IdeaPiece> custom({
    Expression<String>? ideaId,
    Expression<String>? pieceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ideaId != null) 'idea_id': ideaId,
      if (pieceId != null) 'piece_id': pieceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdeaPiecesCompanion copyWith({
    Value<String>? ideaId,
    Value<String>? pieceId,
    Value<int>? rowid,
  }) {
    return IdeaPiecesCompanion(
      ideaId: ideaId ?? this.ideaId,
      pieceId: pieceId ?? this.pieceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ideaId.present) {
      map['idea_id'] = Variable<String>(ideaId.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdeaPiecesCompanion(')
          ..write('ideaId: $ideaId, ')
          ..write('pieceId: $pieceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftPiecesTable extends DraftPieces
    with TableInfo<$DraftPiecesTable, DraftPiece> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftPiecesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draft_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pieceIdMeta = const VerificationMeta(
    'pieceId',
  );
  @override
  late final GeneratedColumn<String> pieceId = GeneratedColumn<String>(
    'piece_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [draftId, pieceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'draft_pieces';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftPiece> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('piece_id')) {
      context.handle(
        _pieceIdMeta,
        pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {draftId, pieceId};
  @override
  DraftPiece map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftPiece(
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_id'],
      )!,
      pieceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}piece_id'],
      )!,
    );
  }

  @override
  $DraftPiecesTable createAlias(String alias) {
    return $DraftPiecesTable(attachedDatabase, alias);
  }
}

class DraftPiece extends DataClass implements Insertable<DraftPiece> {
  final String draftId;
  final String pieceId;
  const DraftPiece({required this.draftId, required this.pieceId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['draft_id'] = Variable<String>(draftId);
    map['piece_id'] = Variable<String>(pieceId);
    return map;
  }

  DraftPiecesCompanion toCompanion(bool nullToAbsent) {
    return DraftPiecesCompanion(
      draftId: Value(draftId),
      pieceId: Value(pieceId),
    );
  }

  factory DraftPiece.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftPiece(
      draftId: serializer.fromJson<String>(json['draftId']),
      pieceId: serializer.fromJson<String>(json['pieceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'draftId': serializer.toJson<String>(draftId),
      'pieceId': serializer.toJson<String>(pieceId),
    };
  }

  DraftPiece copyWith({String? draftId, String? pieceId}) => DraftPiece(
    draftId: draftId ?? this.draftId,
    pieceId: pieceId ?? this.pieceId,
  );
  DraftPiece copyWithCompanion(DraftPiecesCompanion data) {
    return DraftPiece(
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftPiece(')
          ..write('draftId: $draftId, ')
          ..write('pieceId: $pieceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(draftId, pieceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftPiece &&
          other.draftId == this.draftId &&
          other.pieceId == this.pieceId);
}

class DraftPiecesCompanion extends UpdateCompanion<DraftPiece> {
  final Value<String> draftId;
  final Value<String> pieceId;
  final Value<int> rowid;
  const DraftPiecesCompanion({
    this.draftId = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftPiecesCompanion.insert({
    required String draftId,
    required String pieceId,
    this.rowid = const Value.absent(),
  }) : draftId = Value(draftId),
       pieceId = Value(pieceId);
  static Insertable<DraftPiece> custom({
    Expression<String>? draftId,
    Expression<String>? pieceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (draftId != null) 'draft_id': draftId,
      if (pieceId != null) 'piece_id': pieceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftPiecesCompanion copyWith({
    Value<String>? draftId,
    Value<String>? pieceId,
    Value<int>? rowid,
  }) {
    return DraftPiecesCompanion(
      draftId: draftId ?? this.draftId,
      pieceId: pieceId ?? this.pieceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (draftId.present) {
      map['draft_id'] = Variable<String>(draftId.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<String>(pieceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftPiecesCompanion(')
          ..write('draftId: $draftId, ')
          ..write('pieceId: $pieceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, Goal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<GoalPeriod, String> period =
      GeneratedColumn<String>(
        'period',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<GoalPeriod>($GoalsTable.$converterperiod);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<GoalKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<GoalKind>($GoalsTable.$converterkind);
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pitIdMeta = const VerificationMeta('pitId');
  @override
  late final GeneratedColumn<String> pitId = GeneratedColumn<String>(
    'pit_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requireLikesMeta = const VerificationMeta(
    'requireLikes',
  );
  @override
  late final GeneratedColumn<int> requireLikes = GeneratedColumn<int>(
    'require_likes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    period,
    year,
    month,
    name,
    kind,
    count,
    pitId,
    requireLikes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Goal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    if (data.containsKey('pit_id')) {
      context.handle(
        _pitIdMeta,
        pitId.isAcceptableOrUnknown(data['pit_id']!, _pitIdMeta),
      );
    }
    if (data.containsKey('require_likes')) {
      context.handle(
        _requireLikesMeta,
        requireLikes.isAcceptableOrUnknown(
          data['require_likes']!,
          _requireLikesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Goal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Goal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      period: $GoalsTable.$converterperiod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}period'],
        )!,
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      kind: $GoalsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      pitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pit_id'],
      ),
      requireLikes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}require_likes'],
      ),
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<GoalPeriod, String, String> $converterperiod =
      const EnumNameConverter<GoalPeriod>(GoalPeriod.values);
  static JsonTypeConverter2<GoalKind, String, String> $converterkind =
      const EnumNameConverter<GoalKind>(GoalKind.values);
}

class Goal extends DataClass implements Insertable<Goal> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final GoalPeriod period;
  final int year;
  final int? month;
  final String? name;
  final GoalKind kind;
  final int count;
  final String? pitId;
  final int? requireLikes;
  const Goal({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.period,
    required this.year,
    this.month,
    this.name,
    required this.kind,
    required this.count,
    this.pitId,
    this.requireLikes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    {
      map['period'] = Variable<String>(
        $GoalsTable.$converterperiod.toSql(period),
      );
    }
    map['year'] = Variable<int>(year);
    if (!nullToAbsent || month != null) {
      map['month'] = Variable<int>(month);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    {
      map['kind'] = Variable<String>($GoalsTable.$converterkind.toSql(kind));
    }
    map['count'] = Variable<int>(count);
    if (!nullToAbsent || pitId != null) {
      map['pit_id'] = Variable<String>(pitId);
    }
    if (!nullToAbsent || requireLikes != null) {
      map['require_likes'] = Variable<int>(requireLikes);
    }
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      period: Value(period),
      year: Value(year),
      month: month == null && nullToAbsent
          ? const Value.absent()
          : Value(month),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      kind: Value(kind),
      count: Value(count),
      pitId: pitId == null && nullToAbsent
          ? const Value.absent()
          : Value(pitId),
      requireLikes: requireLikes == null && nullToAbsent
          ? const Value.absent()
          : Value(requireLikes),
    );
  }

  factory Goal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Goal(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      period: $GoalsTable.$converterperiod.fromJson(
        serializer.fromJson<String>(json['period']),
      ),
      year: serializer.fromJson<int>(json['year']),
      month: serializer.fromJson<int?>(json['month']),
      name: serializer.fromJson<String?>(json['name']),
      kind: $GoalsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      count: serializer.fromJson<int>(json['count']),
      pitId: serializer.fromJson<String?>(json['pitId']),
      requireLikes: serializer.fromJson<int?>(json['requireLikes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'period': serializer.toJson<String>(
        $GoalsTable.$converterperiod.toJson(period),
      ),
      'year': serializer.toJson<int>(year),
      'month': serializer.toJson<int?>(month),
      'name': serializer.toJson<String?>(name),
      'kind': serializer.toJson<String>(
        $GoalsTable.$converterkind.toJson(kind),
      ),
      'count': serializer.toJson<int>(count),
      'pitId': serializer.toJson<String?>(pitId),
      'requireLikes': serializer.toJson<int?>(requireLikes),
    };
  }

  Goal copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? deviceId,
    GoalPeriod? period,
    int? year,
    Value<int?> month = const Value.absent(),
    Value<String?> name = const Value.absent(),
    GoalKind? kind,
    int? count,
    Value<String?> pitId = const Value.absent(),
    Value<int?> requireLikes = const Value.absent(),
  }) => Goal(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    period: period ?? this.period,
    year: year ?? this.year,
    month: month.present ? month.value : this.month,
    name: name.present ? name.value : this.name,
    kind: kind ?? this.kind,
    count: count ?? this.count,
    pitId: pitId.present ? pitId.value : this.pitId,
    requireLikes: requireLikes.present ? requireLikes.value : this.requireLikes,
  );
  Goal copyWithCompanion(GoalsCompanion data) {
    return Goal(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      period: data.period.present ? data.period.value : this.period,
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      count: data.count.present ? data.count.value : this.count,
      pitId: data.pitId.present ? data.pitId.value : this.pitId,
      requireLikes: data.requireLikes.present
          ? data.requireLikes.value
          : this.requireLikes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Goal(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('period: $period, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('count: $count, ')
          ..write('pitId: $pitId, ')
          ..write('requireLikes: $requireLikes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    period,
    year,
    month,
    name,
    kind,
    count,
    pitId,
    requireLikes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Goal &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.period == this.period &&
          other.year == this.year &&
          other.month == this.month &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.count == this.count &&
          other.pitId == this.pitId &&
          other.requireLikes == this.requireLikes);
}

class GoalsCompanion extends UpdateCompanion<Goal> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> deviceId;
  final Value<GoalPeriod> period;
  final Value<int> year;
  final Value<int?> month;
  final Value<String?> name;
  final Value<GoalKind> kind;
  final Value<int> count;
  final Value<String?> pitId;
  final Value<int?> requireLikes;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.period = const Value.absent(),
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.count = const Value.absent(),
    this.pitId = const Value.absent(),
    this.requireLikes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    required GoalPeriod period,
    required int year,
    this.month = const Value.absent(),
    this.name = const Value.absent(),
    required GoalKind kind,
    required int count,
    this.pitId = const Value.absent(),
    this.requireLikes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : period = Value(period),
       year = Value(year),
       kind = Value(kind),
       count = Value(count);
  static Insertable<Goal> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? period,
    Expression<int>? year,
    Expression<int>? month,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? count,
    Expression<String>? pitId,
    Expression<int>? requireLikes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (period != null) 'period': period,
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (count != null) 'count': count,
      if (pitId != null) 'pit_id': pitId,
      if (requireLikes != null) 'require_likes': requireLikes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? deviceId,
    Value<GoalPeriod>? period,
    Value<int>? year,
    Value<int?>? month,
    Value<String?>? name,
    Value<GoalKind>? kind,
    Value<int>? count,
    Value<String?>? pitId,
    Value<int?>? requireLikes,
    Value<int>? rowid,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      period: period ?? this.period,
      year: year ?? this.year,
      month: month ?? this.month,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      count: count ?? this.count,
      pitId: pitId ?? this.pitId,
      requireLikes: requireLikes ?? this.requireLikes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(
        $GoalsTable.$converterperiod.toSql(period.value),
      );
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $GoalsTable.$converterkind.toSql(kind.value),
      );
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (pitId.present) {
      map['pit_id'] = Variable<String>(pitId.value);
    }
    if (requireLikes.present) {
      map['require_likes'] = Variable<int>(requireLikes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('period: $period, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('count: $count, ')
          ..write('pitId: $pitId, ')
          ..write('requireLikes: $requireLikes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $YearReviewMonthsTable extends YearReviewMonths
    with TableInfo<$YearReviewMonthsTable, YearReviewMonth> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $YearReviewMonthsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageFileMeta = const VerificationMeta(
    'imageFile',
  );
  @override
  late final GeneratedColumn<String> imageFile = GeneratedColumn<String>(
    'image_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [year, month, imageFile, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'year_review_months';
  @override
  VerificationContext validateIntegrity(
    Insertable<YearReviewMonth> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('image_file')) {
      context.handle(
        _imageFileMeta,
        imageFile.isAcceptableOrUnknown(data['image_file']!, _imageFileMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {year, month};
  @override
  YearReviewMonth map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return YearReviewMonth(
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      )!,
      imageFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_file'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $YearReviewMonthsTable createAlias(String alias) {
    return $YearReviewMonthsTable(attachedDatabase, alias);
  }
}

class YearReviewMonth extends DataClass implements Insertable<YearReviewMonth> {
  final int year;
  final int month;
  final String? imageFile;
  final DateTime updatedAt;
  const YearReviewMonth({
    required this.year,
    required this.month,
    this.imageFile,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['year'] = Variable<int>(year);
    map['month'] = Variable<int>(month);
    if (!nullToAbsent || imageFile != null) {
      map['image_file'] = Variable<String>(imageFile);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  YearReviewMonthsCompanion toCompanion(bool nullToAbsent) {
    return YearReviewMonthsCompanion(
      year: Value(year),
      month: Value(month),
      imageFile: imageFile == null && nullToAbsent
          ? const Value.absent()
          : Value(imageFile),
      updatedAt: Value(updatedAt),
    );
  }

  factory YearReviewMonth.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return YearReviewMonth(
      year: serializer.fromJson<int>(json['year']),
      month: serializer.fromJson<int>(json['month']),
      imageFile: serializer.fromJson<String?>(json['imageFile']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'year': serializer.toJson<int>(year),
      'month': serializer.toJson<int>(month),
      'imageFile': serializer.toJson<String?>(imageFile),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  YearReviewMonth copyWith({
    int? year,
    int? month,
    Value<String?> imageFile = const Value.absent(),
    DateTime? updatedAt,
  }) => YearReviewMonth(
    year: year ?? this.year,
    month: month ?? this.month,
    imageFile: imageFile.present ? imageFile.value : this.imageFile,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  YearReviewMonth copyWithCompanion(YearReviewMonthsCompanion data) {
    return YearReviewMonth(
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      imageFile: data.imageFile.present ? data.imageFile.value : this.imageFile,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('YearReviewMonth(')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('imageFile: $imageFile, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(year, month, imageFile, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is YearReviewMonth &&
          other.year == this.year &&
          other.month == this.month &&
          other.imageFile == this.imageFile &&
          other.updatedAt == this.updatedAt);
}

class YearReviewMonthsCompanion extends UpdateCompanion<YearReviewMonth> {
  final Value<int> year;
  final Value<int> month;
  final Value<String?> imageFile;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const YearReviewMonthsCompanion({
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.imageFile = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  YearReviewMonthsCompanion.insert({
    required int year,
    required int month,
    this.imageFile = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : year = Value(year),
       month = Value(month);
  static Insertable<YearReviewMonth> custom({
    Expression<int>? year,
    Expression<int>? month,
    Expression<String>? imageFile,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (imageFile != null) 'image_file': imageFile,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  YearReviewMonthsCompanion copyWith({
    Value<int>? year,
    Value<int>? month,
    Value<String?>? imageFile,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return YearReviewMonthsCompanion(
      year: year ?? this.year,
      month: month ?? this.month,
      imageFile: imageFile ?? this.imageFile,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (imageFile.present) {
      map['image_file'] = Variable<String>(imageFile.value);
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
    return (StringBuffer('YearReviewMonthsCompanion(')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('imageFile: $imageFile, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewSettingsTable extends ReviewSettings
    with TableInfo<$ReviewSettingsTable, ReviewSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _columnsMeta = const VerificationMeta(
    'columns',
  );
  @override
  late final GeneratedColumn<int> columns = GeneratedColumn<int>(
    'columns',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _ratioMeta = const VerificationMeta('ratio');
  @override
  late final GeneratedColumn<String> ratio = GeneratedColumn<String>(
    'ratio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('1:1'),
  );
  static const VerificationMeta _monthFormatMeta = const VerificationMeta(
    'monthFormat',
  );
  @override
  late final GeneratedColumn<String> monthFormat = GeneratedColumn<String>(
    'month_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Jan'),
  );
  static const VerificationMeta _monthOnImageMeta = const VerificationMeta(
    'monthOnImage',
  );
  @override
  late final GeneratedColumn<bool> monthOnImage = GeneratedColumn<bool>(
    'month_on_image',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("month_on_image" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    year,
    columns,
    ratio,
    monthFormat,
    monthOnImage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('columns')) {
      context.handle(
        _columnsMeta,
        columns.isAcceptableOrUnknown(data['columns']!, _columnsMeta),
      );
    }
    if (data.containsKey('ratio')) {
      context.handle(
        _ratioMeta,
        ratio.isAcceptableOrUnknown(data['ratio']!, _ratioMeta),
      );
    }
    if (data.containsKey('month_format')) {
      context.handle(
        _monthFormatMeta,
        monthFormat.isAcceptableOrUnknown(
          data['month_format']!,
          _monthFormatMeta,
        ),
      );
    }
    if (data.containsKey('month_on_image')) {
      context.handle(
        _monthOnImageMeta,
        monthOnImage.isAcceptableOrUnknown(
          data['month_on_image']!,
          _monthOnImageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {year};
  @override
  ReviewSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewSetting(
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      columns: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}columns'],
      )!,
      ratio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ratio'],
      )!,
      monthFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month_format'],
      )!,
      monthOnImage: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}month_on_image'],
      )!,
    );
  }

  @override
  $ReviewSettingsTable createAlias(String alias) {
    return $ReviewSettingsTable(attachedDatabase, alias);
  }
}

class ReviewSetting extends DataClass implements Insertable<ReviewSetting> {
  final int year;
  final int columns;
  final String ratio;
  final String monthFormat;
  final bool monthOnImage;
  const ReviewSetting({
    required this.year,
    required this.columns,
    required this.ratio,
    required this.monthFormat,
    required this.monthOnImage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['year'] = Variable<int>(year);
    map['columns'] = Variable<int>(columns);
    map['ratio'] = Variable<String>(ratio);
    map['month_format'] = Variable<String>(monthFormat);
    map['month_on_image'] = Variable<bool>(monthOnImage);
    return map;
  }

  ReviewSettingsCompanion toCompanion(bool nullToAbsent) {
    return ReviewSettingsCompanion(
      year: Value(year),
      columns: Value(columns),
      ratio: Value(ratio),
      monthFormat: Value(monthFormat),
      monthOnImage: Value(monthOnImage),
    );
  }

  factory ReviewSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewSetting(
      year: serializer.fromJson<int>(json['year']),
      columns: serializer.fromJson<int>(json['columns']),
      ratio: serializer.fromJson<String>(json['ratio']),
      monthFormat: serializer.fromJson<String>(json['monthFormat']),
      monthOnImage: serializer.fromJson<bool>(json['monthOnImage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'year': serializer.toJson<int>(year),
      'columns': serializer.toJson<int>(columns),
      'ratio': serializer.toJson<String>(ratio),
      'monthFormat': serializer.toJson<String>(monthFormat),
      'monthOnImage': serializer.toJson<bool>(monthOnImage),
    };
  }

  ReviewSetting copyWith({
    int? year,
    int? columns,
    String? ratio,
    String? monthFormat,
    bool? monthOnImage,
  }) => ReviewSetting(
    year: year ?? this.year,
    columns: columns ?? this.columns,
    ratio: ratio ?? this.ratio,
    monthFormat: monthFormat ?? this.monthFormat,
    monthOnImage: monthOnImage ?? this.monthOnImage,
  );
  ReviewSetting copyWithCompanion(ReviewSettingsCompanion data) {
    return ReviewSetting(
      year: data.year.present ? data.year.value : this.year,
      columns: data.columns.present ? data.columns.value : this.columns,
      ratio: data.ratio.present ? data.ratio.value : this.ratio,
      monthFormat: data.monthFormat.present
          ? data.monthFormat.value
          : this.monthFormat,
      monthOnImage: data.monthOnImage.present
          ? data.monthOnImage.value
          : this.monthOnImage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewSetting(')
          ..write('year: $year, ')
          ..write('columns: $columns, ')
          ..write('ratio: $ratio, ')
          ..write('monthFormat: $monthFormat, ')
          ..write('monthOnImage: $monthOnImage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(year, columns, ratio, monthFormat, monthOnImage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewSetting &&
          other.year == this.year &&
          other.columns == this.columns &&
          other.ratio == this.ratio &&
          other.monthFormat == this.monthFormat &&
          other.monthOnImage == this.monthOnImage);
}

class ReviewSettingsCompanion extends UpdateCompanion<ReviewSetting> {
  final Value<int> year;
  final Value<int> columns;
  final Value<String> ratio;
  final Value<String> monthFormat;
  final Value<bool> monthOnImage;
  const ReviewSettingsCompanion({
    this.year = const Value.absent(),
    this.columns = const Value.absent(),
    this.ratio = const Value.absent(),
    this.monthFormat = const Value.absent(),
    this.monthOnImage = const Value.absent(),
  });
  ReviewSettingsCompanion.insert({
    this.year = const Value.absent(),
    this.columns = const Value.absent(),
    this.ratio = const Value.absent(),
    this.monthFormat = const Value.absent(),
    this.monthOnImage = const Value.absent(),
  });
  static Insertable<ReviewSetting> custom({
    Expression<int>? year,
    Expression<int>? columns,
    Expression<String>? ratio,
    Expression<String>? monthFormat,
    Expression<bool>? monthOnImage,
  }) {
    return RawValuesInsertable({
      if (year != null) 'year': year,
      if (columns != null) 'columns': columns,
      if (ratio != null) 'ratio': ratio,
      if (monthFormat != null) 'month_format': monthFormat,
      if (monthOnImage != null) 'month_on_image': monthOnImage,
    });
  }

  ReviewSettingsCompanion copyWith({
    Value<int>? year,
    Value<int>? columns,
    Value<String>? ratio,
    Value<String>? monthFormat,
    Value<bool>? monthOnImage,
  }) {
    return ReviewSettingsCompanion(
      year: year ?? this.year,
      columns: columns ?? this.columns,
      ratio: ratio ?? this.ratio,
      monthFormat: monthFormat ?? this.monthFormat,
      monthOnImage: monthOnImage ?? this.monthOnImage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (columns.present) {
      map['columns'] = Variable<int>(columns.value);
    }
    if (ratio.present) {
      map['ratio'] = Variable<String>(ratio.value);
    }
    if (monthFormat.present) {
      map['month_format'] = Variable<String>(monthFormat.value);
    }
    if (monthOnImage.present) {
      map['month_on_image'] = Variable<bool>(monthOnImage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewSettingsCompanion(')
          ..write('year: $year, ')
          ..write('columns: $columns, ')
          ..write('ratio: $ratio, ')
          ..write('monthFormat: $monthFormat, ')
          ..write('monthOnImage: $monthOnImage')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [seq, entity, entityId, op, queuedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final int seq;
  final String entity;
  final String entityId;
  final String op;
  final DateTime queuedAt;
  const OutboxData({
    required this.seq,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.queuedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['op'] = Variable<String>(op);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      entity: Value(entity),
      entityId: Value(entityId),
      op: Value(op),
      queuedAt: Value(queuedAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      seq: serializer.fromJson<int>(json['seq']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      op: serializer.fromJson<String>(json['op']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'op': serializer.toJson<String>(op),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
    };
  }

  OutboxData copyWith({
    int? seq,
    String? entity,
    String? entityId,
    String? op,
    DateTime? queuedAt,
  }) => OutboxData(
    seq: seq ?? this.seq,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    op: op ?? this.op,
    queuedAt: queuedAt ?? this.queuedAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      seq: data.seq.present ? data.seq.value : this.seq,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      op: data.op.present ? data.op.value : this.op,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('seq: $seq, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('queuedAt: $queuedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, entity, entityId, op, queuedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.seq == this.seq &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.op == this.op &&
          other.queuedAt == this.queuedAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<int> seq;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> op;
  final Value<DateTime> queuedAt;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.op = const Value.absent(),
    this.queuedAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String entity,
    required String entityId,
    required String op,
    this.queuedAt = const Value.absent(),
  }) : entity = Value(entity),
       entityId = Value(entityId),
       op = Value(op);
  static Insertable<OutboxData> custom({
    Expression<int>? seq,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? op,
    Expression<DateTime>? queuedAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (op != null) 'op': op,
      if (queuedAt != null) 'queued_at': queuedAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? op,
    Value<DateTime>? queuedAt,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      op: op ?? this.op,
      queuedAt: queuedAt ?? this.queuedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('queuedAt: $queuedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncDocsTable extends SyncDocs with TableInfo<$SyncDocsTable, SyncDoc> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncDocsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteModifiedMeta = const VerificationMeta(
    'remoteModified',
  );
  @override
  late final GeneratedColumn<String> remoteModified = GeneratedColumn<String>(
    'remote_modified',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [kind, id, updatedAtMs, remoteModified];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_docs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncDoc> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('remote_modified')) {
      context.handle(
        _remoteModifiedMeta,
        remoteModified.isAcceptableOrUnknown(
          data['remote_modified']!,
          _remoteModifiedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, id};
  @override
  SyncDoc map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncDoc(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      remoteModified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_modified'],
      )!,
    );
  }

  @override
  $SyncDocsTable createAlias(String alias) {
    return $SyncDocsTable(attachedDatabase, alias);
  }
}

class SyncDoc extends DataClass implements Insertable<SyncDoc> {
  final String kind;
  final String id;
  final int updatedAtMs;
  final String remoteModified;
  const SyncDoc({
    required this.kind,
    required this.id,
    required this.updatedAtMs,
    required this.remoteModified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['id'] = Variable<String>(id);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    map['remote_modified'] = Variable<String>(remoteModified);
    return map;
  }

  SyncDocsCompanion toCompanion(bool nullToAbsent) {
    return SyncDocsCompanion(
      kind: Value(kind),
      id: Value(id),
      updatedAtMs: Value(updatedAtMs),
      remoteModified: Value(remoteModified),
    );
  }

  factory SyncDoc.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncDoc(
      kind: serializer.fromJson<String>(json['kind']),
      id: serializer.fromJson<String>(json['id']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      remoteModified: serializer.fromJson<String>(json['remoteModified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'id': serializer.toJson<String>(id),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'remoteModified': serializer.toJson<String>(remoteModified),
    };
  }

  SyncDoc copyWith({
    String? kind,
    String? id,
    int? updatedAtMs,
    String? remoteModified,
  }) => SyncDoc(
    kind: kind ?? this.kind,
    id: id ?? this.id,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    remoteModified: remoteModified ?? this.remoteModified,
  );
  SyncDoc copyWithCompanion(SyncDocsCompanion data) {
    return SyncDoc(
      kind: data.kind.present ? data.kind.value : this.kind,
      id: data.id.present ? data.id.value : this.id,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      remoteModified: data.remoteModified.present
          ? data.remoteModified.value
          : this.remoteModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncDoc(')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('remoteModified: $remoteModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, id, updatedAtMs, remoteModified);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncDoc &&
          other.kind == this.kind &&
          other.id == this.id &&
          other.updatedAtMs == this.updatedAtMs &&
          other.remoteModified == this.remoteModified);
}

class SyncDocsCompanion extends UpdateCompanion<SyncDoc> {
  final Value<String> kind;
  final Value<String> id;
  final Value<int> updatedAtMs;
  final Value<String> remoteModified;
  final Value<int> rowid;
  const SyncDocsCompanion({
    this.kind = const Value.absent(),
    this.id = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.remoteModified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncDocsCompanion.insert({
    required String kind,
    required String id,
    required int updatedAtMs,
    this.remoteModified = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       id = Value(id),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<SyncDoc> custom({
    Expression<String>? kind,
    Expression<String>? id,
    Expression<int>? updatedAtMs,
    Expression<String>? remoteModified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (id != null) 'id': id,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (remoteModified != null) 'remote_modified': remoteModified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncDocsCompanion copyWith({
    Value<String>? kind,
    Value<String>? id,
    Value<int>? updatedAtMs,
    Value<String>? remoteModified,
    Value<int>? rowid,
  }) {
    return SyncDocsCompanion(
      kind: kind ?? this.kind,
      id: id ?? this.id,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      remoteModified: remoteModified ?? this.remoteModified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (remoteModified.present) {
      map['remote_modified'] = Variable<String>(remoteModified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncDocsCompanion(')
          ..write('kind: $kind, ')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('remoteModified: $remoteModified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PitsTable pits = $PitsTable(this);
  late final $OfficialGroupsTable officialGroups = $OfficialGroupsTable(this);
  late final $OfficialImagesTable officialImages = $OfficialImagesTable(this);
  late final $FanArtsTable fanArts = $FanArtsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $IdeasTable ideas = $IdeasTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $PiecesTable pieces = $PiecesTable(this);
  late final $EntityImagesTable entityImages = $EntityImagesTable(this);
  late final $PieceLinksTable pieceLinks = $PieceLinksTable(this);
  late final $TagLinksTable tagLinks = $TagLinksTable(this);
  late final $IdeaDraftsTable ideaDrafts = $IdeaDraftsTable(this);
  late final $IdeaPiecesTable ideaPieces = $IdeaPiecesTable(this);
  late final $DraftPiecesTable draftPieces = $DraftPiecesTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $YearReviewMonthsTable yearReviewMonths = $YearReviewMonthsTable(
    this,
  );
  late final $ReviewSettingsTable reviewSettings = $ReviewSettingsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncDocsTable syncDocs = $SyncDocsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pits,
    officialGroups,
    officialImages,
    fanArts,
    tags,
    ideas,
    drafts,
    pieces,
    entityImages,
    pieceLinks,
    tagLinks,
    ideaDrafts,
    ideaPieces,
    draftPieces,
    goals,
    yearReviewMonths,
    reviewSettings,
    outbox,
    syncDocs,
  ];
}

typedef $$PitsTableCreateCompanionBuilder = PitsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  required String name,
  Value<String?> description,
  Value<String?> coverImageId,
  Value<String?> officialCoverId,
  Value<String?> fanArtCoverId,
  Value<bool> archived,
  Value<int> rowid,
});
typedef $$PitsTableUpdateCompanionBuilder = PitsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  Value<String> name,
  Value<String?> description,
  Value<String?> coverImageId,
  Value<String?> officialCoverId,
  Value<String?> fanArtCoverId,
  Value<bool> archived,
  Value<int> rowid,
});

class $$PitsTableFilterComposer extends Composer<_$AppDatabase, $PitsTable> {
  $$PitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImageId => $composableBuilder(
    column: $table.coverImageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officialCoverId => $composableBuilder(
    column: $table.officialCoverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fanArtCoverId => $composableBuilder(
    column: $table.fanArtCoverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PitsTableOrderingComposer extends Composer<_$AppDatabase, $PitsTable> {
  $$PitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImageId => $composableBuilder(
    column: $table.coverImageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officialCoverId => $composableBuilder(
    column: $table.officialCoverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fanArtCoverId => $composableBuilder(
    column: $table.fanArtCoverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PitsTable> {
  $$PitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverImageId => $composableBuilder(
    column: $table.coverImageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get officialCoverId => $composableBuilder(
    column: $table.officialCoverId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fanArtCoverId => $composableBuilder(
    column: $table.fanArtCoverId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);
}

class $$PitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PitsTable,
          Pit,
          $$PitsTableFilterComposer,
          $$PitsTableOrderingComposer,
          $$PitsTableAnnotationComposer,
          $$PitsTableCreateCompanionBuilder,
          $$PitsTableUpdateCompanionBuilder,
          (Pit, BaseReferences<_$AppDatabase, $PitsTable, Pit>),
          Pit,
          PrefetchHooks Function()
        > {
  $$PitsTableTableManager(_$AppDatabase db, $PitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverImageId = const Value.absent(),
                Value<String?> officialCoverId = const Value.absent(),
                Value<String?> fanArtCoverId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PitsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                name: name,
                description: description,
                coverImageId: coverImageId,
                officialCoverId: officialCoverId,
                fanArtCoverId: fanArtCoverId,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> coverImageId = const Value.absent(),
                Value<String?> officialCoverId = const Value.absent(),
                Value<String?> fanArtCoverId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PitsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                name: name,
                description: description,
                coverImageId: coverImageId,
                officialCoverId: officialCoverId,
                fanArtCoverId: fanArtCoverId,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PitsTable, Pit>(table),
                  BaseReferences<_$AppDatabase, $PitsTable, Pit>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PitsTable,
      Pit,
      $$PitsTableFilterComposer,
      $$PitsTableOrderingComposer,
      $$PitsTableAnnotationComposer,
      $$PitsTableCreateCompanionBuilder,
      $$PitsTableUpdateCompanionBuilder,
      (Pit, BaseReferences<_$AppDatabase, $PitsTable, Pit>),
      Pit,
      PrefetchHooks Function()
    >;
typedef $$OfficialGroupsTableCreateCompanionBuilder =
    OfficialGroupsCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> deviceId,
      required String pitId,
      Value<String> kind,
      required String name,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$OfficialGroupsTableUpdateCompanionBuilder =
    OfficialGroupsCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> deviceId,
      Value<String> pitId,
      Value<String> kind,
      Value<String> name,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$OfficialGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $OfficialGroupsTable> {
  $$OfficialGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfficialGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfficialGroupsTable> {
  $$OfficialGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfficialGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfficialGroupsTable> {
  $$OfficialGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get pitId =>
      $composableBuilder(column: $table.pitId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$OfficialGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfficialGroupsTable,
          OfficialGroup,
          $$OfficialGroupsTableFilterComposer,
          $$OfficialGroupsTableOrderingComposer,
          $$OfficialGroupsTableAnnotationComposer,
          $$OfficialGroupsTableCreateCompanionBuilder,
          $$OfficialGroupsTableUpdateCompanionBuilder,
          (
            OfficialGroup,
            BaseReferences<_$AppDatabase, $OfficialGroupsTable, OfficialGroup>,
          ),
          OfficialGroup,
          PrefetchHooks Function()
        > {
  $$OfficialGroupsTableTableManager(
    _$AppDatabase db,
    $OfficialGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfficialGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfficialGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfficialGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> pitId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfficialGroupsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                kind: kind,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required String pitId,
                Value<String> kind = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfficialGroupsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                kind: kind,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OfficialGroupsTable, OfficialGroup>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OfficialGroupsTable,
                    OfficialGroup
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfficialGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfficialGroupsTable,
      OfficialGroup,
      $$OfficialGroupsTableFilterComposer,
      $$OfficialGroupsTableOrderingComposer,
      $$OfficialGroupsTableAnnotationComposer,
      $$OfficialGroupsTableCreateCompanionBuilder,
      $$OfficialGroupsTableUpdateCompanionBuilder,
      (
        OfficialGroup,
        BaseReferences<_$AppDatabase, $OfficialGroupsTable, OfficialGroup>,
      ),
      OfficialGroup,
      PrefetchHooks Function()
    >;
typedef $$OfficialImagesTableCreateCompanionBuilder =
    OfficialImagesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> deviceId,
      required String pitId,
      required String groupId,
      required String imageFile,
      Value<int> width,
      Value<int> height,
      Value<int> rowid,
    });
typedef $$OfficialImagesTableUpdateCompanionBuilder =
    OfficialImagesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> deviceId,
      Value<String> pitId,
      Value<String> groupId,
      Value<String> imageFile,
      Value<int> width,
      Value<int> height,
      Value<int> rowid,
    });

class $$OfficialImagesTableFilterComposer
    extends Composer<_$AppDatabase, $OfficialImagesTable> {
  $$OfficialImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfficialImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $OfficialImagesTable> {
  $$OfficialImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfficialImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfficialImagesTable> {
  $$OfficialImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get pitId =>
      $composableBuilder(column: $table.pitId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get imageFile =>
      $composableBuilder(column: $table.imageFile, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);
}

class $$OfficialImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfficialImagesTable,
          OfficialImage,
          $$OfficialImagesTableFilterComposer,
          $$OfficialImagesTableOrderingComposer,
          $$OfficialImagesTableAnnotationComposer,
          $$OfficialImagesTableCreateCompanionBuilder,
          $$OfficialImagesTableUpdateCompanionBuilder,
          (
            OfficialImage,
            BaseReferences<_$AppDatabase, $OfficialImagesTable, OfficialImage>,
          ),
          OfficialImage,
          PrefetchHooks Function()
        > {
  $$OfficialImagesTableTableManager(
    _$AppDatabase db,
    $OfficialImagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfficialImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfficialImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfficialImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> pitId = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> imageFile = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfficialImagesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                groupId: groupId,
                imageFile: imageFile,
                width: width,
                height: height,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required String pitId,
                required String groupId,
                required String imageFile,
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfficialImagesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                groupId: groupId,
                imageFile: imageFile,
                width: width,
                height: height,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OfficialImagesTable, OfficialImage>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OfficialImagesTable,
                    OfficialImage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfficialImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfficialImagesTable,
      OfficialImage,
      $$OfficialImagesTableFilterComposer,
      $$OfficialImagesTableOrderingComposer,
      $$OfficialImagesTableAnnotationComposer,
      $$OfficialImagesTableCreateCompanionBuilder,
      $$OfficialImagesTableUpdateCompanionBuilder,
      (
        OfficialImage,
        BaseReferences<_$AppDatabase, $OfficialImagesTable, OfficialImage>,
      ),
      OfficialImage,
      PrefetchHooks Function()
    >;
typedef $$FanArtsTableCreateCompanionBuilder = FanArtsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  required String pitId,
  required String imageFile,
  Value<int> width,
  Value<int> height,
  Value<String> author,
  Value<String> source,
  Value<String?> groupId,
  Value<int> rowid,
});
typedef $$FanArtsTableUpdateCompanionBuilder = FanArtsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  Value<String> pitId,
  Value<String> imageFile,
  Value<int> width,
  Value<int> height,
  Value<String> author,
  Value<String> source,
  Value<String?> groupId,
  Value<int> rowid,
});

class $$FanArtsTableFilterComposer
    extends Composer<_$AppDatabase, $FanArtsTable> {
  $$FanArtsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FanArtsTableOrderingComposer
    extends Composer<_$AppDatabase, $FanArtsTable> {
  $$FanArtsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FanArtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FanArtsTable> {
  $$FanArtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get pitId =>
      $composableBuilder(column: $table.pitId, builder: (column) => column);

  GeneratedColumn<String> get imageFile =>
      $composableBuilder(column: $table.imageFile, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);
}

class $$FanArtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FanArtsTable,
          FanArt,
          $$FanArtsTableFilterComposer,
          $$FanArtsTableOrderingComposer,
          $$FanArtsTableAnnotationComposer,
          $$FanArtsTableCreateCompanionBuilder,
          $$FanArtsTableUpdateCompanionBuilder,
          (FanArt, BaseReferences<_$AppDatabase, $FanArtsTable, FanArt>),
          FanArt,
          PrefetchHooks Function()
        > {
  $$FanArtsTableTableManager(_$AppDatabase db, $FanArtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FanArtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FanArtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FanArtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> pitId = const Value.absent(),
                Value<String> imageFile = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FanArtsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                imageFile: imageFile,
                width: width,
                height: height,
                author: author,
                source: source,
                groupId: groupId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required String pitId,
                required String imageFile,
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FanArtsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                imageFile: imageFile,
                width: width,
                height: height,
                author: author,
                source: source,
                groupId: groupId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FanArtsTable, FanArt>(table),
                  BaseReferences<_$AppDatabase, $FanArtsTable, FanArt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FanArtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FanArtsTable,
      FanArt,
      $$FanArtsTableFilterComposer,
      $$FanArtsTableOrderingComposer,
      $$FanArtsTableAnnotationComposer,
      $$FanArtsTableCreateCompanionBuilder,
      $$FanArtsTableUpdateCompanionBuilder,
      (FanArt, BaseReferences<_$AppDatabase, $FanArtsTable, FanArt>),
      FanArt,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  required String pitId,
  required String name,
  Value<int> rowid,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  Value<String> pitId,
  Value<String> name,
  Value<int> rowid,
});

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get pitId =>
      $composableBuilder(column: $table.pitId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
          Tag,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> pitId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required String pitId,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, Tag>(table),
                  BaseReferences<_$AppDatabase, $TagsTable, Tag>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
      Tag,
      PrefetchHooks Function()
    >;
typedef $$IdeasTableCreateCompanionBuilder = IdeasCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  required String pitId,
  required String title,
  Value<String> body,
  Value<int> rowid,
});
typedef $$IdeasTableUpdateCompanionBuilder = IdeasCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  Value<String> pitId,
  Value<String> title,
  Value<String> body,
  Value<int> rowid,
});

class $$IdeasTableFilterComposer extends Composer<_$AppDatabase, $IdeasTable> {
  $$IdeasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdeasTableOrderingComposer
    extends Composer<_$AppDatabase, $IdeasTable> {
  $$IdeasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdeasTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdeasTable> {
  $$IdeasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get pitId =>
      $composableBuilder(column: $table.pitId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $$IdeasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdeasTable,
          Idea,
          $$IdeasTableFilterComposer,
          $$IdeasTableOrderingComposer,
          $$IdeasTableAnnotationComposer,
          $$IdeasTableCreateCompanionBuilder,
          $$IdeasTableUpdateCompanionBuilder,
          (Idea, BaseReferences<_$AppDatabase, $IdeasTable, Idea>),
          Idea,
          PrefetchHooks Function()
        > {
  $$IdeasTableTableManager(_$AppDatabase db, $IdeasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdeasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdeasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdeasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> pitId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdeasCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                title: title,
                body: body,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required String pitId,
                required String title,
                Value<String> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdeasCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                title: title,
                body: body,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IdeasTable, Idea>(table),
                  BaseReferences<_$AppDatabase, $IdeasTable, Idea>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdeasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdeasTable,
      Idea,
      $$IdeasTableFilterComposer,
      $$IdeasTableOrderingComposer,
      $$IdeasTableAnnotationComposer,
      $$IdeasTableCreateCompanionBuilder,
      $$IdeasTableUpdateCompanionBuilder,
      (Idea, BaseReferences<_$AppDatabase, $IdeasTable, Idea>),
      Idea,
      PrefetchHooks Function()
    >;
typedef $$DraftsTableCreateCompanionBuilder = DraftsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  required String pitId,
  Value<String?> title,
  Value<String?> body,
  Value<int> rowid,
});
typedef $$DraftsTableUpdateCompanionBuilder = DraftsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  Value<String> pitId,
  Value<String?> title,
  Value<String?> body,
  Value<int> rowid,
});

class $$DraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get pitId =>
      $composableBuilder(column: $table.pitId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftsTable,
          Draft,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (Draft, BaseReferences<_$AppDatabase, $DraftsTable, Draft>),
          Draft,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$AppDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> pitId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                title: title,
                body: body,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required String pitId,
                Value<String?> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                title: title,
                body: body,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftsTable, Draft>(table),
                  BaseReferences<_$AppDatabase, $DraftsTable, Draft>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftsTable,
      Draft,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (Draft, BaseReferences<_$AppDatabase, $DraftsTable, Draft>),
      Draft,
      PrefetchHooks Function()
    >;
typedef $$PiecesTableCreateCompanionBuilder = PiecesCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  required String pitId,
  required String title,
  Value<String> body,
  Value<int> targetLikes,
  Value<int> actualLikes,
  Value<DateTime> finishedAt,
  Value<int> rowid,
});
typedef $$PiecesTableUpdateCompanionBuilder = PiecesCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  Value<String> pitId,
  Value<String> title,
  Value<String> body,
  Value<int> targetLikes,
  Value<int> actualLikes,
  Value<DateTime> finishedAt,
  Value<int> rowid,
});

class $$PiecesTableFilterComposer
    extends Composer<_$AppDatabase, $PiecesTable> {
  $$PiecesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetLikes => $composableBuilder(
    column: $table.targetLikes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualLikes => $composableBuilder(
    column: $table.actualLikes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PiecesTableOrderingComposer
    extends Composer<_$AppDatabase, $PiecesTable> {
  $$PiecesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetLikes => $composableBuilder(
    column: $table.targetLikes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualLikes => $composableBuilder(
    column: $table.actualLikes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PiecesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PiecesTable> {
  $$PiecesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get pitId =>
      $composableBuilder(column: $table.pitId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get targetLikes => $composableBuilder(
    column: $table.targetLikes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualLikes => $composableBuilder(
    column: $table.actualLikes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );
}

class $$PiecesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PiecesTable,
          Piece,
          $$PiecesTableFilterComposer,
          $$PiecesTableOrderingComposer,
          $$PiecesTableAnnotationComposer,
          $$PiecesTableCreateCompanionBuilder,
          $$PiecesTableUpdateCompanionBuilder,
          (Piece, BaseReferences<_$AppDatabase, $PiecesTable, Piece>),
          Piece,
          PrefetchHooks Function()
        > {
  $$PiecesTableTableManager(_$AppDatabase db, $PiecesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PiecesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PiecesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PiecesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> pitId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> targetLikes = const Value.absent(),
                Value<int> actualLikes = const Value.absent(),
                Value<DateTime> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PiecesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                title: title,
                body: body,
                targetLikes: targetLikes,
                actualLikes: actualLikes,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required String pitId,
                required String title,
                Value<String> body = const Value.absent(),
                Value<int> targetLikes = const Value.absent(),
                Value<int> actualLikes = const Value.absent(),
                Value<DateTime> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PiecesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pitId: pitId,
                title: title,
                body: body,
                targetLikes: targetLikes,
                actualLikes: actualLikes,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PiecesTable, Piece>(table),
                  BaseReferences<_$AppDatabase, $PiecesTable, Piece>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PiecesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PiecesTable,
      Piece,
      $$PiecesTableFilterComposer,
      $$PiecesTableOrderingComposer,
      $$PiecesTableAnnotationComposer,
      $$PiecesTableCreateCompanionBuilder,
      $$PiecesTableUpdateCompanionBuilder,
      (Piece, BaseReferences<_$AppDatabase, $PiecesTable, Piece>),
      Piece,
      PrefetchHooks Function()
    >;
typedef $$EntityImagesTableCreateCompanionBuilder =
    EntityImagesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> deviceId,
      required OwnerType ownerType,
      required String ownerId,
      required String imageFile,
      Value<int> width,
      Value<int> height,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$EntityImagesTableUpdateCompanionBuilder =
    EntityImagesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> deviceId,
      Value<OwnerType> ownerType,
      Value<String> ownerId,
      Value<String> imageFile,
      Value<int> width,
      Value<int> height,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$EntityImagesTableFilterComposer
    extends Composer<_$AppDatabase, $EntityImagesTable> {
  $$EntityImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OwnerType, OwnerType, String> get ownerType =>
      $composableBuilder(
        column: $table.ownerType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntityImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntityImagesTable> {
  $$EntityImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerType => $composableBuilder(
    column: $table.ownerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntityImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntityImagesTable> {
  $$EntityImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OwnerType, String> get ownerType =>
      $composableBuilder(column: $table.ownerType, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get imageFile =>
      $composableBuilder(column: $table.imageFile, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$EntityImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntityImagesTable,
          EntityImage,
          $$EntityImagesTableFilterComposer,
          $$EntityImagesTableOrderingComposer,
          $$EntityImagesTableAnnotationComposer,
          $$EntityImagesTableCreateCompanionBuilder,
          $$EntityImagesTableUpdateCompanionBuilder,
          (
            EntityImage,
            BaseReferences<_$AppDatabase, $EntityImagesTable, EntityImage>,
          ),
          EntityImage,
          PrefetchHooks Function()
        > {
  $$EntityImagesTableTableManager(_$AppDatabase db, $EntityImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntityImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntityImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntityImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<OwnerType> ownerType = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> imageFile = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntityImagesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                ownerType: ownerType,
                ownerId: ownerId,
                imageFile: imageFile,
                width: width,
                height: height,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required OwnerType ownerType,
                required String ownerId,
                required String imageFile,
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntityImagesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                ownerType: ownerType,
                ownerId: ownerId,
                imageFile: imageFile,
                width: width,
                height: height,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntityImagesTable, EntityImage>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EntityImagesTable,
                    EntityImage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntityImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntityImagesTable,
      EntityImage,
      $$EntityImagesTableFilterComposer,
      $$EntityImagesTableOrderingComposer,
      $$EntityImagesTableAnnotationComposer,
      $$EntityImagesTableCreateCompanionBuilder,
      $$EntityImagesTableUpdateCompanionBuilder,
      (
        EntityImage,
        BaseReferences<_$AppDatabase, $EntityImagesTable, EntityImage>,
      ),
      EntityImage,
      PrefetchHooks Function()
    >;
typedef $$PieceLinksTableCreateCompanionBuilder = PieceLinksCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  required String pieceId,
  required String platform,
  required String url,
  Value<int> rowid,
});
typedef $$PieceLinksTableUpdateCompanionBuilder = PieceLinksCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  Value<String> pieceId,
  Value<String> platform,
  Value<String> url,
  Value<int> rowid,
});

class $$PieceLinksTableFilterComposer
    extends Composer<_$AppDatabase, $PieceLinksTable> {
  $$PieceLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pieceId => $composableBuilder(
    column: $table.pieceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PieceLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $PieceLinksTable> {
  $$PieceLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pieceId => $composableBuilder(
    column: $table.pieceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PieceLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PieceLinksTable> {
  $$PieceLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get pieceId =>
      $composableBuilder(column: $table.pieceId, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);
}

class $$PieceLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PieceLinksTable,
          PieceLink,
          $$PieceLinksTableFilterComposer,
          $$PieceLinksTableOrderingComposer,
          $$PieceLinksTableAnnotationComposer,
          $$PieceLinksTableCreateCompanionBuilder,
          $$PieceLinksTableUpdateCompanionBuilder,
          (
            PieceLink,
            BaseReferences<_$AppDatabase, $PieceLinksTable, PieceLink>,
          ),
          PieceLink,
          PrefetchHooks Function()
        > {
  $$PieceLinksTableTableManager(_$AppDatabase db, $PieceLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PieceLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PieceLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PieceLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> pieceId = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PieceLinksCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pieceId: pieceId,
                platform: platform,
                url: url,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required String pieceId,
                required String platform,
                required String url,
                Value<int> rowid = const Value.absent(),
              }) => PieceLinksCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                pieceId: pieceId,
                platform: platform,
                url: url,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PieceLinksTable, PieceLink>(table),
                  BaseReferences<_$AppDatabase, $PieceLinksTable, PieceLink>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PieceLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PieceLinksTable,
      PieceLink,
      $$PieceLinksTableFilterComposer,
      $$PieceLinksTableOrderingComposer,
      $$PieceLinksTableAnnotationComposer,
      $$PieceLinksTableCreateCompanionBuilder,
      $$PieceLinksTableUpdateCompanionBuilder,
      (PieceLink, BaseReferences<_$AppDatabase, $PieceLinksTable, PieceLink>),
      PieceLink,
      PrefetchHooks Function()
    >;
typedef $$TagLinksTableCreateCompanionBuilder = TagLinksCompanion Function({
  required String tagId,
  required TagTarget targetType,
  required String targetId,
  Value<int> rowid,
});
typedef $$TagLinksTableUpdateCompanionBuilder = TagLinksCompanion Function({
  Value<String> tagId,
  Value<TagTarget> targetType,
  Value<String> targetId,
  Value<int> rowid,
});

class $$TagLinksTableFilterComposer
    extends Composer<_$AppDatabase, $TagLinksTable> {
  $$TagLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TagTarget, TagTarget, String> get targetType =>
      $composableBuilder(
        column: $table.targetType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $TagLinksTable> {
  $$TagLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagLinksTable> {
  $$TagLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TagTarget, String> get targetType =>
      $composableBuilder(
        column: $table.targetType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);
}

class $$TagLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagLinksTable,
          TagLink,
          $$TagLinksTableFilterComposer,
          $$TagLinksTableOrderingComposer,
          $$TagLinksTableAnnotationComposer,
          $$TagLinksTableCreateCompanionBuilder,
          $$TagLinksTableUpdateCompanionBuilder,
          (TagLink, BaseReferences<_$AppDatabase, $TagLinksTable, TagLink>),
          TagLink,
          PrefetchHooks Function()
        > {
  $$TagLinksTableTableManager(_$AppDatabase db, $TagLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tagId = const Value.absent(),
                Value<TagTarget> targetType = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagLinksCompanion(
                tagId: tagId,
                targetType: targetType,
                targetId: targetId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tagId,
                required TagTarget targetType,
                required String targetId,
                Value<int> rowid = const Value.absent(),
              }) => TagLinksCompanion.insert(
                tagId: tagId,
                targetType: targetType,
                targetId: targetId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagLinksTable, TagLink>(table),
                  BaseReferences<_$AppDatabase, $TagLinksTable, TagLink>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagLinksTable,
      TagLink,
      $$TagLinksTableFilterComposer,
      $$TagLinksTableOrderingComposer,
      $$TagLinksTableAnnotationComposer,
      $$TagLinksTableCreateCompanionBuilder,
      $$TagLinksTableUpdateCompanionBuilder,
      (TagLink, BaseReferences<_$AppDatabase, $TagLinksTable, TagLink>),
      TagLink,
      PrefetchHooks Function()
    >;
typedef $$IdeaDraftsTableCreateCompanionBuilder = IdeaDraftsCompanion Function({
  required String ideaId,
  required String draftId,
  Value<int> rowid,
});
typedef $$IdeaDraftsTableUpdateCompanionBuilder = IdeaDraftsCompanion Function({
  Value<String> ideaId,
  Value<String> draftId,
  Value<int> rowid,
});

class $$IdeaDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $IdeaDraftsTable> {
  $$IdeaDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ideaId => $composableBuilder(
    column: $table.ideaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdeaDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $IdeaDraftsTable> {
  $$IdeaDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ideaId => $composableBuilder(
    column: $table.ideaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdeaDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdeaDraftsTable> {
  $$IdeaDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ideaId =>
      $composableBuilder(column: $table.ideaId, builder: (column) => column);

  GeneratedColumn<String> get draftId =>
      $composableBuilder(column: $table.draftId, builder: (column) => column);
}

class $$IdeaDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdeaDraftsTable,
          IdeaDraft,
          $$IdeaDraftsTableFilterComposer,
          $$IdeaDraftsTableOrderingComposer,
          $$IdeaDraftsTableAnnotationComposer,
          $$IdeaDraftsTableCreateCompanionBuilder,
          $$IdeaDraftsTableUpdateCompanionBuilder,
          (
            IdeaDraft,
            BaseReferences<_$AppDatabase, $IdeaDraftsTable, IdeaDraft>,
          ),
          IdeaDraft,
          PrefetchHooks Function()
        > {
  $$IdeaDraftsTableTableManager(_$AppDatabase db, $IdeaDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdeaDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdeaDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdeaDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ideaId = const Value.absent(),
                Value<String> draftId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdeaDraftsCompanion(
                ideaId: ideaId,
                draftId: draftId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ideaId,
                required String draftId,
                Value<int> rowid = const Value.absent(),
              }) => IdeaDraftsCompanion.insert(
                ideaId: ideaId,
                draftId: draftId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IdeaDraftsTable, IdeaDraft>(table),
                  BaseReferences<_$AppDatabase, $IdeaDraftsTable, IdeaDraft>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdeaDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdeaDraftsTable,
      IdeaDraft,
      $$IdeaDraftsTableFilterComposer,
      $$IdeaDraftsTableOrderingComposer,
      $$IdeaDraftsTableAnnotationComposer,
      $$IdeaDraftsTableCreateCompanionBuilder,
      $$IdeaDraftsTableUpdateCompanionBuilder,
      (IdeaDraft, BaseReferences<_$AppDatabase, $IdeaDraftsTable, IdeaDraft>),
      IdeaDraft,
      PrefetchHooks Function()
    >;
typedef $$IdeaPiecesTableCreateCompanionBuilder = IdeaPiecesCompanion Function({
  required String ideaId,
  required String pieceId,
  Value<int> rowid,
});
typedef $$IdeaPiecesTableUpdateCompanionBuilder = IdeaPiecesCompanion Function({
  Value<String> ideaId,
  Value<String> pieceId,
  Value<int> rowid,
});

class $$IdeaPiecesTableFilterComposer
    extends Composer<_$AppDatabase, $IdeaPiecesTable> {
  $$IdeaPiecesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ideaId => $composableBuilder(
    column: $table.ideaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pieceId => $composableBuilder(
    column: $table.pieceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdeaPiecesTableOrderingComposer
    extends Composer<_$AppDatabase, $IdeaPiecesTable> {
  $$IdeaPiecesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ideaId => $composableBuilder(
    column: $table.ideaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pieceId => $composableBuilder(
    column: $table.pieceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdeaPiecesTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdeaPiecesTable> {
  $$IdeaPiecesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ideaId =>
      $composableBuilder(column: $table.ideaId, builder: (column) => column);

  GeneratedColumn<String> get pieceId =>
      $composableBuilder(column: $table.pieceId, builder: (column) => column);
}

class $$IdeaPiecesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdeaPiecesTable,
          IdeaPiece,
          $$IdeaPiecesTableFilterComposer,
          $$IdeaPiecesTableOrderingComposer,
          $$IdeaPiecesTableAnnotationComposer,
          $$IdeaPiecesTableCreateCompanionBuilder,
          $$IdeaPiecesTableUpdateCompanionBuilder,
          (
            IdeaPiece,
            BaseReferences<_$AppDatabase, $IdeaPiecesTable, IdeaPiece>,
          ),
          IdeaPiece,
          PrefetchHooks Function()
        > {
  $$IdeaPiecesTableTableManager(_$AppDatabase db, $IdeaPiecesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdeaPiecesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdeaPiecesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdeaPiecesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ideaId = const Value.absent(),
                Value<String> pieceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdeaPiecesCompanion(
                ideaId: ideaId,
                pieceId: pieceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ideaId,
                required String pieceId,
                Value<int> rowid = const Value.absent(),
              }) => IdeaPiecesCompanion.insert(
                ideaId: ideaId,
                pieceId: pieceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IdeaPiecesTable, IdeaPiece>(table),
                  BaseReferences<_$AppDatabase, $IdeaPiecesTable, IdeaPiece>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdeaPiecesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdeaPiecesTable,
      IdeaPiece,
      $$IdeaPiecesTableFilterComposer,
      $$IdeaPiecesTableOrderingComposer,
      $$IdeaPiecesTableAnnotationComposer,
      $$IdeaPiecesTableCreateCompanionBuilder,
      $$IdeaPiecesTableUpdateCompanionBuilder,
      (IdeaPiece, BaseReferences<_$AppDatabase, $IdeaPiecesTable, IdeaPiece>),
      IdeaPiece,
      PrefetchHooks Function()
    >;
typedef $$DraftPiecesTableCreateCompanionBuilder =
    DraftPiecesCompanion Function({
      required String draftId,
      required String pieceId,
      Value<int> rowid,
    });
typedef $$DraftPiecesTableUpdateCompanionBuilder =
    DraftPiecesCompanion Function({
      Value<String> draftId,
      Value<String> pieceId,
      Value<int> rowid,
    });

class $$DraftPiecesTableFilterComposer
    extends Composer<_$AppDatabase, $DraftPiecesTable> {
  $$DraftPiecesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pieceId => $composableBuilder(
    column: $table.pieceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftPiecesTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftPiecesTable> {
  $$DraftPiecesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pieceId => $composableBuilder(
    column: $table.pieceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftPiecesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftPiecesTable> {
  $$DraftPiecesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get draftId =>
      $composableBuilder(column: $table.draftId, builder: (column) => column);

  GeneratedColumn<String> get pieceId =>
      $composableBuilder(column: $table.pieceId, builder: (column) => column);
}

class $$DraftPiecesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftPiecesTable,
          DraftPiece,
          $$DraftPiecesTableFilterComposer,
          $$DraftPiecesTableOrderingComposer,
          $$DraftPiecesTableAnnotationComposer,
          $$DraftPiecesTableCreateCompanionBuilder,
          $$DraftPiecesTableUpdateCompanionBuilder,
          (
            DraftPiece,
            BaseReferences<_$AppDatabase, $DraftPiecesTable, DraftPiece>,
          ),
          DraftPiece,
          PrefetchHooks Function()
        > {
  $$DraftPiecesTableTableManager(_$AppDatabase db, $DraftPiecesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftPiecesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftPiecesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftPiecesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> draftId = const Value.absent(),
                Value<String> pieceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftPiecesCompanion(
                draftId: draftId,
                pieceId: pieceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String draftId,
                required String pieceId,
                Value<int> rowid = const Value.absent(),
              }) => DraftPiecesCompanion.insert(
                draftId: draftId,
                pieceId: pieceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftPiecesTable, DraftPiece>(table),
                  BaseReferences<_$AppDatabase, $DraftPiecesTable, DraftPiece>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftPiecesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftPiecesTable,
      DraftPiece,
      $$DraftPiecesTableFilterComposer,
      $$DraftPiecesTableOrderingComposer,
      $$DraftPiecesTableAnnotationComposer,
      $$DraftPiecesTableCreateCompanionBuilder,
      $$DraftPiecesTableUpdateCompanionBuilder,
      (
        DraftPiece,
        BaseReferences<_$AppDatabase, $DraftPiecesTable, DraftPiece>,
      ),
      DraftPiece,
      PrefetchHooks Function()
    >;
typedef $$GoalsTableCreateCompanionBuilder = GoalsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  required GoalPeriod period,
  required int year,
  Value<int?> month,
  Value<String?> name,
  required GoalKind kind,
  required int count,
  Value<String?> pitId,
  Value<int?> requireLikes,
  Value<int> rowid,
});
typedef $$GoalsTableUpdateCompanionBuilder = GoalsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> deviceId,
  Value<GoalPeriod> period,
  Value<int> year,
  Value<int?> month,
  Value<String?> name,
  Value<GoalKind> kind,
  Value<int> count,
  Value<String?> pitId,
  Value<int?> requireLikes,
  Value<int> rowid,
});

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<GoalPeriod, GoalPeriod, String> get period =>
      $composableBuilder(
        column: $table.period,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<GoalKind, GoalKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requireLikes => $composableBuilder(
    column: $table.requireLikes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pitId => $composableBuilder(
    column: $table.pitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requireLikes => $composableBuilder(
    column: $table.requireLikes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<GoalPeriod, String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<GoalKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<String> get pitId =>
      $composableBuilder(column: $table.pitId, builder: (column) => column);

  GeneratedColumn<int> get requireLikes => $composableBuilder(
    column: $table.requireLikes,
    builder: (column) => column,
  );
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalsTable,
          Goal,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (Goal, BaseReferences<_$AppDatabase, $GoalsTable, Goal>),
          Goal,
          PrefetchHooks Function()
        > {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<GoalPeriod> period = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int?> month = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<GoalKind> kind = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<String?> pitId = const Value.absent(),
                Value<int?> requireLikes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                period: period,
                year: year,
                month: month,
                name: name,
                kind: kind,
                count: count,
                pitId: pitId,
                requireLikes: requireLikes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                required GoalPeriod period,
                required int year,
                Value<int?> month = const Value.absent(),
                Value<String?> name = const Value.absent(),
                required GoalKind kind,
                required int count,
                Value<String?> pitId = const Value.absent(),
                Value<int?> requireLikes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                period: period,
                year: year,
                month: month,
                name: name,
                kind: kind,
                count: count,
                pitId: pitId,
                requireLikes: requireLikes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GoalsTable, Goal>(table),
                  BaseReferences<_$AppDatabase, $GoalsTable, Goal>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalsTable,
      Goal,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (Goal, BaseReferences<_$AppDatabase, $GoalsTable, Goal>),
      Goal,
      PrefetchHooks Function()
    >;
typedef $$YearReviewMonthsTableCreateCompanionBuilder =
    YearReviewMonthsCompanion Function({
      required int year,
      required int month,
      Value<String?> imageFile,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$YearReviewMonthsTableUpdateCompanionBuilder =
    YearReviewMonthsCompanion Function({
      Value<int> year,
      Value<int> month,
      Value<String?> imageFile,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$YearReviewMonthsTableFilterComposer
    extends Composer<_$AppDatabase, $YearReviewMonthsTable> {
  $$YearReviewMonthsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$YearReviewMonthsTableOrderingComposer
    extends Composer<_$AppDatabase, $YearReviewMonthsTable> {
  $$YearReviewMonthsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageFile => $composableBuilder(
    column: $table.imageFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$YearReviewMonthsTableAnnotationComposer
    extends Composer<_$AppDatabase, $YearReviewMonthsTable> {
  $$YearReviewMonthsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get imageFile =>
      $composableBuilder(column: $table.imageFile, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$YearReviewMonthsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $YearReviewMonthsTable,
          YearReviewMonth,
          $$YearReviewMonthsTableFilterComposer,
          $$YearReviewMonthsTableOrderingComposer,
          $$YearReviewMonthsTableAnnotationComposer,
          $$YearReviewMonthsTableCreateCompanionBuilder,
          $$YearReviewMonthsTableUpdateCompanionBuilder,
          (
            YearReviewMonth,
            BaseReferences<
              _$AppDatabase,
              $YearReviewMonthsTable,
              YearReviewMonth
            >,
          ),
          YearReviewMonth,
          PrefetchHooks Function()
        > {
  $$YearReviewMonthsTableTableManager(
    _$AppDatabase db,
    $YearReviewMonthsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$YearReviewMonthsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$YearReviewMonthsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$YearReviewMonthsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                Value<int> month = const Value.absent(),
                Value<String?> imageFile = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => YearReviewMonthsCompanion(
                year: year,
                month: month,
                imageFile: imageFile,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int year,
                required int month,
                Value<String?> imageFile = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => YearReviewMonthsCompanion.insert(
                year: year,
                month: month,
                imageFile: imageFile,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$YearReviewMonthsTable, YearReviewMonth>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $YearReviewMonthsTable,
                    YearReviewMonth
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$YearReviewMonthsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $YearReviewMonthsTable,
      YearReviewMonth,
      $$YearReviewMonthsTableFilterComposer,
      $$YearReviewMonthsTableOrderingComposer,
      $$YearReviewMonthsTableAnnotationComposer,
      $$YearReviewMonthsTableCreateCompanionBuilder,
      $$YearReviewMonthsTableUpdateCompanionBuilder,
      (
        YearReviewMonth,
        BaseReferences<_$AppDatabase, $YearReviewMonthsTable, YearReviewMonth>,
      ),
      YearReviewMonth,
      PrefetchHooks Function()
    >;
typedef $$ReviewSettingsTableCreateCompanionBuilder =
    ReviewSettingsCompanion Function({
      Value<int> year,
      Value<int> columns,
      Value<String> ratio,
      Value<String> monthFormat,
      Value<bool> monthOnImage,
    });
typedef $$ReviewSettingsTableUpdateCompanionBuilder =
    ReviewSettingsCompanion Function({
      Value<int> year,
      Value<int> columns,
      Value<String> ratio,
      Value<String> monthFormat,
      Value<bool> monthOnImage,
    });

class $$ReviewSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewSettingsTable> {
  $$ReviewSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get columns => $composableBuilder(
    column: $table.columns,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ratio => $composableBuilder(
    column: $table.ratio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monthFormat => $composableBuilder(
    column: $table.monthFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get monthOnImage => $composableBuilder(
    column: $table.monthOnImage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewSettingsTable> {
  $$ReviewSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get columns => $composableBuilder(
    column: $table.columns,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ratio => $composableBuilder(
    column: $table.ratio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthFormat => $composableBuilder(
    column: $table.monthFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get monthOnImage => $composableBuilder(
    column: $table.monthOnImage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewSettingsTable> {
  $$ReviewSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get columns =>
      $composableBuilder(column: $table.columns, builder: (column) => column);

  GeneratedColumn<String> get ratio =>
      $composableBuilder(column: $table.ratio, builder: (column) => column);

  GeneratedColumn<String> get monthFormat => $composableBuilder(
    column: $table.monthFormat,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get monthOnImage => $composableBuilder(
    column: $table.monthOnImage,
    builder: (column) => column,
  );
}

class $$ReviewSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewSettingsTable,
          ReviewSetting,
          $$ReviewSettingsTableFilterComposer,
          $$ReviewSettingsTableOrderingComposer,
          $$ReviewSettingsTableAnnotationComposer,
          $$ReviewSettingsTableCreateCompanionBuilder,
          $$ReviewSettingsTableUpdateCompanionBuilder,
          (
            ReviewSetting,
            BaseReferences<_$AppDatabase, $ReviewSettingsTable, ReviewSetting>,
          ),
          ReviewSetting,
          PrefetchHooks Function()
        > {
  $$ReviewSettingsTableTableManager(
    _$AppDatabase db,
    $ReviewSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                Value<int> columns = const Value.absent(),
                Value<String> ratio = const Value.absent(),
                Value<String> monthFormat = const Value.absent(),
                Value<bool> monthOnImage = const Value.absent(),
              }) => ReviewSettingsCompanion(
                year: year,
                columns: columns,
                ratio: ratio,
                monthFormat: monthFormat,
                monthOnImage: monthOnImage,
              ),
          createCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                Value<int> columns = const Value.absent(),
                Value<String> ratio = const Value.absent(),
                Value<String> monthFormat = const Value.absent(),
                Value<bool> monthOnImage = const Value.absent(),
              }) => ReviewSettingsCompanion.insert(
                year: year,
                columns: columns,
                ratio: ratio,
                monthFormat: monthFormat,
                monthOnImage: monthOnImage,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewSettingsTable, ReviewSetting>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ReviewSettingsTable,
                    ReviewSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewSettingsTable,
      ReviewSetting,
      $$ReviewSettingsTableFilterComposer,
      $$ReviewSettingsTableOrderingComposer,
      $$ReviewSettingsTableAnnotationComposer,
      $$ReviewSettingsTableCreateCompanionBuilder,
      $$ReviewSettingsTableUpdateCompanionBuilder,
      (
        ReviewSetting,
        BaseReferences<_$AppDatabase, $ReviewSettingsTable, ReviewSetting>,
      ),
      ReviewSetting,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String entity,
  required String entityId,
  required String op,
  Value<DateTime> queuedAt,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> entity,
  Value<String> entityId,
  Value<String> op,
  Value<DateTime> queuedAt,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                entity: entity,
                entityId: entityId,
                op: op,
                queuedAt: queuedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String entity,
                required String entityId,
                required String op,
                Value<DateTime> queuedAt = const Value.absent(),
              }) => OutboxCompanion.insert(
                seq: seq,
                entity: entity,
                entityId: entityId,
                op: op,
                queuedAt: queuedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxData>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncDocsTableCreateCompanionBuilder = SyncDocsCompanion Function({
  required String kind,
  required String id,
  required int updatedAtMs,
  Value<String> remoteModified,
  Value<int> rowid,
});
typedef $$SyncDocsTableUpdateCompanionBuilder = SyncDocsCompanion Function({
  Value<String> kind,
  Value<String> id,
  Value<int> updatedAtMs,
  Value<String> remoteModified,
  Value<int> rowid,
});

class $$SyncDocsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncDocsTable> {
  $$SyncDocsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteModified => $composableBuilder(
    column: $table.remoteModified,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncDocsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncDocsTable> {
  $$SyncDocsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteModified => $composableBuilder(
    column: $table.remoteModified,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncDocsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncDocsTable> {
  $$SyncDocsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteModified => $composableBuilder(
    column: $table.remoteModified,
    builder: (column) => column,
  );
}

class $$SyncDocsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncDocsTable,
          SyncDoc,
          $$SyncDocsTableFilterComposer,
          $$SyncDocsTableOrderingComposer,
          $$SyncDocsTableAnnotationComposer,
          $$SyncDocsTableCreateCompanionBuilder,
          $$SyncDocsTableUpdateCompanionBuilder,
          (SyncDoc, BaseReferences<_$AppDatabase, $SyncDocsTable, SyncDoc>),
          SyncDoc,
          PrefetchHooks Function()
        > {
  $$SyncDocsTableTableManager(_$AppDatabase db, $SyncDocsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncDocsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncDocsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncDocsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<String> remoteModified = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncDocsCompanion(
                kind: kind,
                id: id,
                updatedAtMs: updatedAtMs,
                remoteModified: remoteModified,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String id,
                required int updatedAtMs,
                Value<String> remoteModified = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncDocsCompanion.insert(
                kind: kind,
                id: id,
                updatedAtMs: updatedAtMs,
                remoteModified: remoteModified,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncDocsTable, SyncDoc>(table),
                  BaseReferences<_$AppDatabase, $SyncDocsTable, SyncDoc>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncDocsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncDocsTable,
      SyncDoc,
      $$SyncDocsTableFilterComposer,
      $$SyncDocsTableOrderingComposer,
      $$SyncDocsTableAnnotationComposer,
      $$SyncDocsTableCreateCompanionBuilder,
      $$SyncDocsTableUpdateCompanionBuilder,
      (SyncDoc, BaseReferences<_$AppDatabase, $SyncDocsTable, SyncDoc>),
      SyncDoc,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PitsTableTableManager get pits => $$PitsTableTableManager(_db, _db.pits);
  $$OfficialGroupsTableTableManager get officialGroups =>
      $$OfficialGroupsTableTableManager(_db, _db.officialGroups);
  $$OfficialImagesTableTableManager get officialImages =>
      $$OfficialImagesTableTableManager(_db, _db.officialImages);
  $$FanArtsTableTableManager get fanArts =>
      $$FanArtsTableTableManager(_db, _db.fanArts);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$IdeasTableTableManager get ideas =>
      $$IdeasTableTableManager(_db, _db.ideas);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$PiecesTableTableManager get pieces =>
      $$PiecesTableTableManager(_db, _db.pieces);
  $$EntityImagesTableTableManager get entityImages =>
      $$EntityImagesTableTableManager(_db, _db.entityImages);
  $$PieceLinksTableTableManager get pieceLinks =>
      $$PieceLinksTableTableManager(_db, _db.pieceLinks);
  $$TagLinksTableTableManager get tagLinks =>
      $$TagLinksTableTableManager(_db, _db.tagLinks);
  $$IdeaDraftsTableTableManager get ideaDrafts =>
      $$IdeaDraftsTableTableManager(_db, _db.ideaDrafts);
  $$IdeaPiecesTableTableManager get ideaPieces =>
      $$IdeaPiecesTableTableManager(_db, _db.ideaPieces);
  $$DraftPiecesTableTableManager get draftPieces =>
      $$DraftPiecesTableTableManager(_db, _db.draftPieces);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$YearReviewMonthsTableTableManager get yearReviewMonths =>
      $$YearReviewMonthsTableTableManager(_db, _db.yearReviewMonths);
  $$ReviewSettingsTableTableManager get reviewSettings =>
      $$ReviewSettingsTableTableManager(_db, _db.reviewSettings);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncDocsTableTableManager get syncDocs =>
      $$SyncDocsTableTableManager(_db, _db.syncDocs);
}
