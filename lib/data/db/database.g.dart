// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $JourneysTable extends Journeys
    with TableInfo<$JourneysTable, JourneyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JourneysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intentionMeta = const VerificationMeta(
    'intention',
  );
  @override
  late final GeneratedColumn<String> intention = GeneratedColumn<String>(
    'intention',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Day, String> startDay =
      GeneratedColumn<String>(
        'start_day',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Day>($JourneysTable.$converterstartDay);
  static const VerificationMeta _durationDaysMeta = const VerificationMeta(
    'durationDays',
  );
  @override
  late final GeneratedColumn<int> durationDays = GeneratedColumn<int>(
    'duration_days',
    aliasedName,
    false,
    check: () => ComparableExpr(durationDays).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    intention,
    startDay,
    durationDays,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journeys';
  @override
  VerificationContext validateIntegrity(
    Insertable<JourneyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('intention')) {
      context.handle(
        _intentionMeta,
        intention.isAcceptableOrUnknown(data['intention']!, _intentionMeta),
      );
    }
    if (data.containsKey('duration_days')) {
      context.handle(
        _durationDaysMeta,
        durationDays.isAcceptableOrUnknown(
          data['duration_days']!,
          _durationDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationDaysMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JourneyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JourneyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      intention: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intention'],
      )!,
      startDay: $JourneysTable.$converterstartDay.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}start_day'],
        )!,
      ),
      durationDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_days'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $JourneysTable createAlias(String alias) {
    return $JourneysTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Day, String, String> $converterstartDay =
      const DayConverter();
}

class JourneyRow extends DataClass implements Insertable<JourneyRow> {
  final int id;
  final String name;
  final String intention;
  final Day startDay;
  final int durationDays;
  final bool isActive;
  final DateTime createdAt;
  const JourneyRow({
    required this.id,
    required this.name,
    required this.intention,
    required this.startDay,
    required this.durationDays,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['intention'] = Variable<String>(intention);
    {
      map['start_day'] = Variable<String>(
        $JourneysTable.$converterstartDay.toSql(startDay),
      );
    }
    map['duration_days'] = Variable<int>(durationDays);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  JourneysCompanion toCompanion(bool nullToAbsent) {
    return JourneysCompanion(
      id: Value(id),
      name: Value(name),
      intention: Value(intention),
      startDay: Value(startDay),
      durationDays: Value(durationDays),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory JourneyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JourneyRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      intention: serializer.fromJson<String>(json['intention']),
      startDay: $JourneysTable.$converterstartDay.fromJson(
        serializer.fromJson<String>(json['startDay']),
      ),
      durationDays: serializer.fromJson<int>(json['durationDays']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'intention': serializer.toJson<String>(intention),
      'startDay': serializer.toJson<String>(
        $JourneysTable.$converterstartDay.toJson(startDay),
      ),
      'durationDays': serializer.toJson<int>(durationDays),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  JourneyRow copyWith({
    int? id,
    String? name,
    String? intention,
    Day? startDay,
    int? durationDays,
    bool? isActive,
    DateTime? createdAt,
  }) => JourneyRow(
    id: id ?? this.id,
    name: name ?? this.name,
    intention: intention ?? this.intention,
    startDay: startDay ?? this.startDay,
    durationDays: durationDays ?? this.durationDays,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  JourneyRow copyWithCompanion(JourneysCompanion data) {
    return JourneyRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      intention: data.intention.present ? data.intention.value : this.intention,
      startDay: data.startDay.present ? data.startDay.value : this.startDay,
      durationDays: data.durationDays.present
          ? data.durationDays.value
          : this.durationDays,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JourneyRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('intention: $intention, ')
          ..write('startDay: $startDay, ')
          ..write('durationDays: $durationDays, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    intention,
    startDay,
    durationDays,
    isActive,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JourneyRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.intention == this.intention &&
          other.startDay == this.startDay &&
          other.durationDays == this.durationDays &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class JourneysCompanion extends UpdateCompanion<JourneyRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> intention;
  final Value<Day> startDay;
  final Value<int> durationDays;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const JourneysCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.intention = const Value.absent(),
    this.startDay = const Value.absent(),
    this.durationDays = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  JourneysCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.intention = const Value.absent(),
    required Day startDay,
    required int durationDays,
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       startDay = Value(startDay),
       durationDays = Value(durationDays);
  static Insertable<JourneyRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? intention,
    Expression<String>? startDay,
    Expression<int>? durationDays,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (intention != null) 'intention': intention,
      if (startDay != null) 'start_day': startDay,
      if (durationDays != null) 'duration_days': durationDays,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  JourneysCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? intention,
    Value<Day>? startDay,
    Value<int>? durationDays,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return JourneysCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      intention: intention ?? this.intention,
      startDay: startDay ?? this.startDay,
      durationDays: durationDays ?? this.durationDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (intention.present) {
      map['intention'] = Variable<String>(intention.value);
    }
    if (startDay.present) {
      map['start_day'] = Variable<String>(
        $JourneysTable.$converterstartDay.toSql(startDay.value),
      );
    }
    if (durationDays.present) {
      map['duration_days'] = Variable<int>(durationDays.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JourneysCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('intention: $intention, ')
          ..write('startDay: $startDay, ')
          ..write('durationDays: $durationDays, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TrackersTable extends Trackers
    with TableInfo<$TrackersTable, TrackerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _journeyIdMeta = const VerificationMeta(
    'journeyId',
  );
  @override
  late final GeneratedColumn<int> journeyId = GeneratedColumn<int>(
    'journey_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES journeys (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TrackerType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TrackerType>($TrackersTable.$convertertype);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('check'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _anchorMinutesMeta = const VerificationMeta(
    'anchorMinutes',
  );
  @override
  late final GeneratedColumn<int> anchorMinutes = GeneratedColumn<int>(
    'anchor_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekdaysMeta = const VerificationMeta(
    'weekdays',
  );
  @override
  late final GeneratedColumn<int> weekdays = GeneratedColumn<int>(
    'weekdays',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0x7F),
  );
  static const VerificationMeta _isRequiredMeta = const VerificationMeta(
    'isRequired',
  );
  @override
  late final GeneratedColumn<bool> isRequired = GeneratedColumn<bool>(
    'is_required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_required" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TrackerConfig, String> config =
      GeneratedColumn<String>(
        'config',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      ).withConverter<TrackerConfig>($TrackersTable.$converterconfig);
  @override
  late final GeneratedColumnWithTypeConverter<TrackerGoal, String> goal =
      GeneratedColumn<String>(
        'goal',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{"kind":"logged"}'),
      ).withConverter<TrackerGoal>($TrackersTable.$convertergoal);
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reminderMinutesMeta = const VerificationMeta(
    'reminderMinutes',
  );
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
    'reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  late final GeneratedColumnWithTypeConverter<Day, String> activeFrom =
      GeneratedColumn<String>(
        'active_from',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Day>($TrackersTable.$converteractiveFrom);
  @override
  late final GeneratedColumnWithTypeConverter<Day?, String> archivedOn =
      GeneratedColumn<String>(
        'archived_on',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Day?>($TrackersTable.$converterarchivedOnn);
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
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    journeyId,
    name,
    description,
    type,
    icon,
    color,
    section,
    anchorMinutes,
    weekdays,
    isRequired,
    config,
    goal,
    reminderEnabled,
    reminderMinutes,
    sortOrder,
    activeFrom,
    archivedOn,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trackers';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('journey_id')) {
      context.handle(
        _journeyIdMeta,
        journeyId.isAcceptableOrUnknown(data['journey_id']!, _journeyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_journeyIdMeta);
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
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    }
    if (data.containsKey('anchor_minutes')) {
      context.handle(
        _anchorMinutesMeta,
        anchorMinutes.isAcceptableOrUnknown(
          data['anchor_minutes']!,
          _anchorMinutesMeta,
        ),
      );
    }
    if (data.containsKey('weekdays')) {
      context.handle(
        _weekdaysMeta,
        weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta),
      );
    }
    if (data.containsKey('is_required')) {
      context.handle(
        _isRequiredMeta,
        isRequired.isAcceptableOrUnknown(data['is_required']!, _isRequiredMeta),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
        _reminderMinutesMeta,
        reminderMinutes.isAcceptableOrUnknown(
          data['reminder_minutes']!,
          _reminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      journeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}journey_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      type: $TrackersTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      )!,
      anchorMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anchor_minutes'],
      ),
      weekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekdays'],
      )!,
      isRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_required'],
      )!,
      config: $TrackersTable.$converterconfig.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}config'],
        )!,
      ),
      goal: $TrackersTable.$convertergoal.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}goal'],
        )!,
      ),
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      activeFrom: $TrackersTable.$converteractiveFrom.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}active_from'],
        )!,
      ),
      archivedOn: $TrackersTable.$converterarchivedOnn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}archived_on'],
        ),
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TrackersTable createAlias(String alias) {
    return $TrackersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TrackerType, String, String> $convertertype =
      const TrackerTypeConverter();
  static JsonTypeConverter2<TrackerConfig, String, Map<String, dynamic>>
  $converterconfig = const TrackerConfigConverter();
  static JsonTypeConverter2<TrackerGoal, String, Map<String, dynamic>>
  $convertergoal = const TrackerGoalConverter();
  static JsonTypeConverter2<Day, String, String> $converteractiveFrom =
      const DayConverter();
  static JsonTypeConverter2<Day, String, String> $converterarchivedOn =
      const DayConverter();
  static JsonTypeConverter2<Day?, String?, String?> $converterarchivedOnn =
      JsonTypeConverter2.asNullable($converterarchivedOn);
}

class TrackerRow extends DataClass implements Insertable<TrackerRow> {
  final int id;
  final int journeyId;
  final String name;
  final String description;
  final TrackerType type;
  final String icon;
  final int color;
  final String section;
  final int? anchorMinutes;
  final int weekdays;
  final bool isRequired;
  final TrackerConfig config;
  final TrackerGoal goal;
  final bool reminderEnabled;
  final int? reminderMinutes;
  final int sortOrder;
  final Day activeFrom;
  final Day? archivedOn;
  final DateTime createdAt;
  const TrackerRow({
    required this.id,
    required this.journeyId,
    required this.name,
    required this.description,
    required this.type,
    required this.icon,
    required this.color,
    required this.section,
    this.anchorMinutes,
    required this.weekdays,
    required this.isRequired,
    required this.config,
    required this.goal,
    required this.reminderEnabled,
    this.reminderMinutes,
    required this.sortOrder,
    required this.activeFrom,
    this.archivedOn,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['journey_id'] = Variable<int>(journeyId);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    {
      map['type'] = Variable<String>($TrackersTable.$convertertype.toSql(type));
    }
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<int>(color);
    map['section'] = Variable<String>(section);
    if (!nullToAbsent || anchorMinutes != null) {
      map['anchor_minutes'] = Variable<int>(anchorMinutes);
    }
    map['weekdays'] = Variable<int>(weekdays);
    map['is_required'] = Variable<bool>(isRequired);
    {
      map['config'] = Variable<String>(
        $TrackersTable.$converterconfig.toSql(config),
      );
    }
    {
      map['goal'] = Variable<String>($TrackersTable.$convertergoal.toSql(goal));
    }
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    if (!nullToAbsent || reminderMinutes != null) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    {
      map['active_from'] = Variable<String>(
        $TrackersTable.$converteractiveFrom.toSql(activeFrom),
      );
    }
    if (!nullToAbsent || archivedOn != null) {
      map['archived_on'] = Variable<String>(
        $TrackersTable.$converterarchivedOnn.toSql(archivedOn),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TrackersCompanion toCompanion(bool nullToAbsent) {
    return TrackersCompanion(
      id: Value(id),
      journeyId: Value(journeyId),
      name: Value(name),
      description: Value(description),
      type: Value(type),
      icon: Value(icon),
      color: Value(color),
      section: Value(section),
      anchorMinutes: anchorMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(anchorMinutes),
      weekdays: Value(weekdays),
      isRequired: Value(isRequired),
      config: Value(config),
      goal: Value(goal),
      reminderEnabled: Value(reminderEnabled),
      reminderMinutes: reminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutes),
      sortOrder: Value(sortOrder),
      activeFrom: Value(activeFrom),
      archivedOn: archivedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedOn),
      createdAt: Value(createdAt),
    );
  }

  factory TrackerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackerRow(
      id: serializer.fromJson<int>(json['id']),
      journeyId: serializer.fromJson<int>(json['journeyId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      type: $TrackersTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<int>(json['color']),
      section: serializer.fromJson<String>(json['section']),
      anchorMinutes: serializer.fromJson<int?>(json['anchorMinutes']),
      weekdays: serializer.fromJson<int>(json['weekdays']),
      isRequired: serializer.fromJson<bool>(json['isRequired']),
      config: $TrackersTable.$converterconfig.fromJson(
        serializer.fromJson<Map<String, dynamic>>(json['config']),
      ),
      goal: $TrackersTable.$convertergoal.fromJson(
        serializer.fromJson<Map<String, dynamic>>(json['goal']),
      ),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      reminderMinutes: serializer.fromJson<int?>(json['reminderMinutes']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      activeFrom: $TrackersTable.$converteractiveFrom.fromJson(
        serializer.fromJson<String>(json['activeFrom']),
      ),
      archivedOn: $TrackersTable.$converterarchivedOnn.fromJson(
        serializer.fromJson<String?>(json['archivedOn']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'journeyId': serializer.toJson<int>(journeyId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'type': serializer.toJson<String>(
        $TrackersTable.$convertertype.toJson(type),
      ),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<int>(color),
      'section': serializer.toJson<String>(section),
      'anchorMinutes': serializer.toJson<int?>(anchorMinutes),
      'weekdays': serializer.toJson<int>(weekdays),
      'isRequired': serializer.toJson<bool>(isRequired),
      'config': serializer.toJson<Map<String, dynamic>>(
        $TrackersTable.$converterconfig.toJson(config),
      ),
      'goal': serializer.toJson<Map<String, dynamic>>(
        $TrackersTable.$convertergoal.toJson(goal),
      ),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'reminderMinutes': serializer.toJson<int?>(reminderMinutes),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'activeFrom': serializer.toJson<String>(
        $TrackersTable.$converteractiveFrom.toJson(activeFrom),
      ),
      'archivedOn': serializer.toJson<String?>(
        $TrackersTable.$converterarchivedOnn.toJson(archivedOn),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TrackerRow copyWith({
    int? id,
    int? journeyId,
    String? name,
    String? description,
    TrackerType? type,
    String? icon,
    int? color,
    String? section,
    Value<int?> anchorMinutes = const Value.absent(),
    int? weekdays,
    bool? isRequired,
    TrackerConfig? config,
    TrackerGoal? goal,
    bool? reminderEnabled,
    Value<int?> reminderMinutes = const Value.absent(),
    int? sortOrder,
    Day? activeFrom,
    Value<Day?> archivedOn = const Value.absent(),
    DateTime? createdAt,
  }) => TrackerRow(
    id: id ?? this.id,
    journeyId: journeyId ?? this.journeyId,
    name: name ?? this.name,
    description: description ?? this.description,
    type: type ?? this.type,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    section: section ?? this.section,
    anchorMinutes: anchorMinutes.present
        ? anchorMinutes.value
        : this.anchorMinutes,
    weekdays: weekdays ?? this.weekdays,
    isRequired: isRequired ?? this.isRequired,
    config: config ?? this.config,
    goal: goal ?? this.goal,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinutes: reminderMinutes.present
        ? reminderMinutes.value
        : this.reminderMinutes,
    sortOrder: sortOrder ?? this.sortOrder,
    activeFrom: activeFrom ?? this.activeFrom,
    archivedOn: archivedOn.present ? archivedOn.value : this.archivedOn,
    createdAt: createdAt ?? this.createdAt,
  );
  TrackerRow copyWithCompanion(TrackersCompanion data) {
    return TrackerRow(
      id: data.id.present ? data.id.value : this.id,
      journeyId: data.journeyId.present ? data.journeyId.value : this.journeyId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      type: data.type.present ? data.type.value : this.type,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      section: data.section.present ? data.section.value : this.section,
      anchorMinutes: data.anchorMinutes.present
          ? data.anchorMinutes.value
          : this.anchorMinutes,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      isRequired: data.isRequired.present
          ? data.isRequired.value
          : this.isRequired,
      config: data.config.present ? data.config.value : this.config,
      goal: data.goal.present ? data.goal.value : this.goal,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderMinutes: data.reminderMinutes.present
          ? data.reminderMinutes.value
          : this.reminderMinutes,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      activeFrom: data.activeFrom.present
          ? data.activeFrom.value
          : this.activeFrom,
      archivedOn: data.archivedOn.present
          ? data.archivedOn.value
          : this.archivedOn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackerRow(')
          ..write('id: $id, ')
          ..write('journeyId: $journeyId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('section: $section, ')
          ..write('anchorMinutes: $anchorMinutes, ')
          ..write('weekdays: $weekdays, ')
          ..write('isRequired: $isRequired, ')
          ..write('config: $config, ')
          ..write('goal: $goal, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('activeFrom: $activeFrom, ')
          ..write('archivedOn: $archivedOn, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    journeyId,
    name,
    description,
    type,
    icon,
    color,
    section,
    anchorMinutes,
    weekdays,
    isRequired,
    config,
    goal,
    reminderEnabled,
    reminderMinutes,
    sortOrder,
    activeFrom,
    archivedOn,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackerRow &&
          other.id == this.id &&
          other.journeyId == this.journeyId &&
          other.name == this.name &&
          other.description == this.description &&
          other.type == this.type &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.section == this.section &&
          other.anchorMinutes == this.anchorMinutes &&
          other.weekdays == this.weekdays &&
          other.isRequired == this.isRequired &&
          other.config == this.config &&
          other.goal == this.goal &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderMinutes == this.reminderMinutes &&
          other.sortOrder == this.sortOrder &&
          other.activeFrom == this.activeFrom &&
          other.archivedOn == this.archivedOn &&
          other.createdAt == this.createdAt);
}

class TrackersCompanion extends UpdateCompanion<TrackerRow> {
  final Value<int> id;
  final Value<int> journeyId;
  final Value<String> name;
  final Value<String> description;
  final Value<TrackerType> type;
  final Value<String> icon;
  final Value<int> color;
  final Value<String> section;
  final Value<int?> anchorMinutes;
  final Value<int> weekdays;
  final Value<bool> isRequired;
  final Value<TrackerConfig> config;
  final Value<TrackerGoal> goal;
  final Value<bool> reminderEnabled;
  final Value<int?> reminderMinutes;
  final Value<int> sortOrder;
  final Value<Day> activeFrom;
  final Value<Day?> archivedOn;
  final Value<DateTime> createdAt;
  const TrackersCompanion({
    this.id = const Value.absent(),
    this.journeyId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.type = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.section = const Value.absent(),
    this.anchorMinutes = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.config = const Value.absent(),
    this.goal = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.activeFrom = const Value.absent(),
    this.archivedOn = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TrackersCompanion.insert({
    this.id = const Value.absent(),
    required int journeyId,
    required String name,
    this.description = const Value.absent(),
    required TrackerType type,
    this.icon = const Value.absent(),
    required int color,
    this.section = const Value.absent(),
    this.anchorMinutes = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.config = const Value.absent(),
    this.goal = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required Day activeFrom,
    this.archivedOn = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : journeyId = Value(journeyId),
       name = Value(name),
       type = Value(type),
       color = Value(color),
       activeFrom = Value(activeFrom);
  static Insertable<TrackerRow> custom({
    Expression<int>? id,
    Expression<int>? journeyId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? type,
    Expression<String>? icon,
    Expression<int>? color,
    Expression<String>? section,
    Expression<int>? anchorMinutes,
    Expression<int>? weekdays,
    Expression<bool>? isRequired,
    Expression<String>? config,
    Expression<String>? goal,
    Expression<bool>? reminderEnabled,
    Expression<int>? reminderMinutes,
    Expression<int>? sortOrder,
    Expression<String>? activeFrom,
    Expression<String>? archivedOn,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (journeyId != null) 'journey_id': journeyId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (section != null) 'section': section,
      if (anchorMinutes != null) 'anchor_minutes': anchorMinutes,
      if (weekdays != null) 'weekdays': weekdays,
      if (isRequired != null) 'is_required': isRequired,
      if (config != null) 'config': config,
      if (goal != null) 'goal': goal,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (activeFrom != null) 'active_from': activeFrom,
      if (archivedOn != null) 'archived_on': archivedOn,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TrackersCompanion copyWith({
    Value<int>? id,
    Value<int>? journeyId,
    Value<String>? name,
    Value<String>? description,
    Value<TrackerType>? type,
    Value<String>? icon,
    Value<int>? color,
    Value<String>? section,
    Value<int?>? anchorMinutes,
    Value<int>? weekdays,
    Value<bool>? isRequired,
    Value<TrackerConfig>? config,
    Value<TrackerGoal>? goal,
    Value<bool>? reminderEnabled,
    Value<int?>? reminderMinutes,
    Value<int>? sortOrder,
    Value<Day>? activeFrom,
    Value<Day?>? archivedOn,
    Value<DateTime>? createdAt,
  }) {
    return TrackersCompanion(
      id: id ?? this.id,
      journeyId: journeyId ?? this.journeyId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      section: section ?? this.section,
      anchorMinutes: anchorMinutes ?? this.anchorMinutes,
      weekdays: weekdays ?? this.weekdays,
      isRequired: isRequired ?? this.isRequired,
      config: config ?? this.config,
      goal: goal ?? this.goal,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      sortOrder: sortOrder ?? this.sortOrder,
      activeFrom: activeFrom ?? this.activeFrom,
      archivedOn: archivedOn ?? this.archivedOn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (journeyId.present) {
      map['journey_id'] = Variable<int>(journeyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $TrackersTable.$convertertype.toSql(type.value),
      );
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (anchorMinutes.present) {
      map['anchor_minutes'] = Variable<int>(anchorMinutes.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<int>(weekdays.value);
    }
    if (isRequired.present) {
      map['is_required'] = Variable<bool>(isRequired.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(
        $TrackersTable.$converterconfig.toSql(config.value),
      );
    }
    if (goal.present) {
      map['goal'] = Variable<String>(
        $TrackersTable.$convertergoal.toSql(goal.value),
      );
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (activeFrom.present) {
      map['active_from'] = Variable<String>(
        $TrackersTable.$converteractiveFrom.toSql(activeFrom.value),
      );
    }
    if (archivedOn.present) {
      map['archived_on'] = Variable<String>(
        $TrackersTable.$converterarchivedOnn.toSql(archivedOn.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackersCompanion(')
          ..write('id: $id, ')
          ..write('journeyId: $journeyId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('section: $section, ')
          ..write('anchorMinutes: $anchorMinutes, ')
          ..write('weekdays: $weekdays, ')
          ..write('isRequired: $isRequired, ')
          ..write('config: $config, ')
          ..write('goal: $goal, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('activeFrom: $activeFrom, ')
          ..write('archivedOn: $archivedOn, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, EntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackerIdMeta = const VerificationMeta(
    'trackerId',
  );
  @override
  late final GeneratedColumn<int> trackerId = GeneratedColumn<int>(
    'tracker_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trackers (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Day, String> day =
      GeneratedColumn<String>(
        'day',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Day>($EntriesTable.$converterday);
  @override
  late final GeneratedColumnWithTypeConverter<TrackerValue, String> value =
      GeneratedColumn<String>(
        'value',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TrackerValue>($EntriesTable.$convertervalue);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    defaultValue: currentDateAndTime,
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
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackerId,
    day,
    value,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tracker_id')) {
      context.handle(
        _trackerIdMeta,
        trackerId.isAcceptableOrUnknown(data['tracker_id']!, _trackerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackerIdMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {trackerId, day},
  ];
  @override
  EntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tracker_id'],
      )!,
      day: $EntriesTable.$converterday.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}day'],
        )!,
      ),
      value: $EntriesTable.$convertervalue.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}value'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Day, String, String> $converterday =
      const DayConverter();
  static JsonTypeConverter2<TrackerValue, String, Map<String, dynamic>>
  $convertervalue = const TrackerValueConverter();
}

class EntryRow extends DataClass implements Insertable<EntryRow> {
  final int id;
  final int trackerId;
  final Day day;
  final TrackerValue value;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  const EntryRow({
    required this.id,
    required this.trackerId,
    required this.day,
    required this.value,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tracker_id'] = Variable<int>(trackerId);
    {
      map['day'] = Variable<String>($EntriesTable.$converterday.toSql(day));
    }
    {
      map['value'] = Variable<String>(
        $EntriesTable.$convertervalue.toSql(value),
      );
    }
    map['note'] = Variable<String>(note);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      trackerId: Value(trackerId),
      day: Value(day),
      value: Value(value),
      note: Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory EntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRow(
      id: serializer.fromJson<int>(json['id']),
      trackerId: serializer.fromJson<int>(json['trackerId']),
      day: $EntriesTable.$converterday.fromJson(
        serializer.fromJson<String>(json['day']),
      ),
      value: $EntriesTable.$convertervalue.fromJson(
        serializer.fromJson<Map<String, dynamic>>(json['value']),
      ),
      note: serializer.fromJson<String>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackerId': serializer.toJson<int>(trackerId),
      'day': serializer.toJson<String>($EntriesTable.$converterday.toJson(day)),
      'value': serializer.toJson<Map<String, dynamic>>(
        $EntriesTable.$convertervalue.toJson(value),
      ),
      'note': serializer.toJson<String>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EntryRow copyWith({
    int? id,
    int? trackerId,
    Day? day,
    TrackerValue? value,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EntryRow(
    id: id ?? this.id,
    trackerId: trackerId ?? this.trackerId,
    day: day ?? this.day,
    value: value ?? this.value,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EntryRow copyWithCompanion(EntriesCompanion data) {
    return EntryRow(
      id: data.id.present ? data.id.value : this.id,
      trackerId: data.trackerId.present ? data.trackerId.value : this.trackerId,
      day: data.day.present ? data.day.value : this.day,
      value: data.value.present ? data.value.value : this.value,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRow(')
          ..write('id: $id, ')
          ..write('trackerId: $trackerId, ')
          ..write('day: $day, ')
          ..write('value: $value, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, trackerId, day, value, note, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRow &&
          other.id == this.id &&
          other.trackerId == this.trackerId &&
          other.day == this.day &&
          other.value == this.value &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EntriesCompanion extends UpdateCompanion<EntryRow> {
  final Value<int> id;
  final Value<int> trackerId;
  final Value<Day> day;
  final Value<TrackerValue> value;
  final Value<String> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.trackerId = const Value.absent(),
    this.day = const Value.absent(),
    this.value = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    required int trackerId,
    required Day day,
    required TrackerValue value,
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : trackerId = Value(trackerId),
       day = Value(day),
       value = Value(value);
  static Insertable<EntryRow> custom({
    Expression<int>? id,
    Expression<int>? trackerId,
    Expression<String>? day,
    Expression<String>? value,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackerId != null) 'tracker_id': trackerId,
      if (day != null) 'day': day,
      if (value != null) 'value': value,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  EntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? trackerId,
    Value<Day>? day,
    Value<TrackerValue>? value,
    Value<String>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      trackerId: trackerId ?? this.trackerId,
      day: day ?? this.day,
      value: value ?? this.value,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackerId.present) {
      map['tracker_id'] = Variable<int>(trackerId.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(
        $EntriesTable.$converterday.toSql(day.value),
      );
    }
    if (value.present) {
      map['value'] = Variable<String>(
        $EntriesTable.$convertervalue.toSql(value.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('trackerId: $trackerId, ')
          ..write('day: $day, ')
          ..write('value: $value, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DashboardItemsTable extends DashboardItems
    with TableInfo<$DashboardItemsTable, DashboardItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DashboardItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _journeyIdMeta = const VerificationMeta(
    'journeyId',
  );
  @override
  late final GeneratedColumn<int> journeyId = GeneratedColumn<int>(
    'journey_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES journeys (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('full'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DashboardItemConfig, String>
  config = GeneratedColumn<String>(
    'config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  ).withConverter<DashboardItemConfig>($DashboardItemsTable.$converterconfig);
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
    journeyId,
    kind,
    size,
    config,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dashboard_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DashboardItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('journey_id')) {
      context.handle(
        _journeyIdMeta,
        journeyId.isAcceptableOrUnknown(data['journey_id']!, _journeyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_journeyIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
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
  DashboardItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DashboardItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      journeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}journey_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size'],
      )!,
      config: $DashboardItemsTable.$converterconfig.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}config'],
        )!,
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $DashboardItemsTable createAlias(String alias) {
    return $DashboardItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DashboardItemConfig, String, Map<String, dynamic>>
  $converterconfig = const DashboardConfigConverter();
}

class DashboardItemRow extends DataClass
    implements Insertable<DashboardItemRow> {
  final int id;
  final int journeyId;
  final String kind;
  final String size;
  final DashboardItemConfig config;
  final int sortOrder;
  const DashboardItemRow({
    required this.id,
    required this.journeyId,
    required this.kind,
    required this.size,
    required this.config,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['journey_id'] = Variable<int>(journeyId);
    map['kind'] = Variable<String>(kind);
    map['size'] = Variable<String>(size);
    {
      map['config'] = Variable<String>(
        $DashboardItemsTable.$converterconfig.toSql(config),
      );
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  DashboardItemsCompanion toCompanion(bool nullToAbsent) {
    return DashboardItemsCompanion(
      id: Value(id),
      journeyId: Value(journeyId),
      kind: Value(kind),
      size: Value(size),
      config: Value(config),
      sortOrder: Value(sortOrder),
    );
  }

  factory DashboardItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DashboardItemRow(
      id: serializer.fromJson<int>(json['id']),
      journeyId: serializer.fromJson<int>(json['journeyId']),
      kind: serializer.fromJson<String>(json['kind']),
      size: serializer.fromJson<String>(json['size']),
      config: $DashboardItemsTable.$converterconfig.fromJson(
        serializer.fromJson<Map<String, dynamic>>(json['config']),
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'journeyId': serializer.toJson<int>(journeyId),
      'kind': serializer.toJson<String>(kind),
      'size': serializer.toJson<String>(size),
      'config': serializer.toJson<Map<String, dynamic>>(
        $DashboardItemsTable.$converterconfig.toJson(config),
      ),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  DashboardItemRow copyWith({
    int? id,
    int? journeyId,
    String? kind,
    String? size,
    DashboardItemConfig? config,
    int? sortOrder,
  }) => DashboardItemRow(
    id: id ?? this.id,
    journeyId: journeyId ?? this.journeyId,
    kind: kind ?? this.kind,
    size: size ?? this.size,
    config: config ?? this.config,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  DashboardItemRow copyWithCompanion(DashboardItemsCompanion data) {
    return DashboardItemRow(
      id: data.id.present ? data.id.value : this.id,
      journeyId: data.journeyId.present ? data.journeyId.value : this.journeyId,
      kind: data.kind.present ? data.kind.value : this.kind,
      size: data.size.present ? data.size.value : this.size,
      config: data.config.present ? data.config.value : this.config,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DashboardItemRow(')
          ..write('id: $id, ')
          ..write('journeyId: $journeyId, ')
          ..write('kind: $kind, ')
          ..write('size: $size, ')
          ..write('config: $config, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, journeyId, kind, size, config, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DashboardItemRow &&
          other.id == this.id &&
          other.journeyId == this.journeyId &&
          other.kind == this.kind &&
          other.size == this.size &&
          other.config == this.config &&
          other.sortOrder == this.sortOrder);
}

class DashboardItemsCompanion extends UpdateCompanion<DashboardItemRow> {
  final Value<int> id;
  final Value<int> journeyId;
  final Value<String> kind;
  final Value<String> size;
  final Value<DashboardItemConfig> config;
  final Value<int> sortOrder;
  const DashboardItemsCompanion({
    this.id = const Value.absent(),
    this.journeyId = const Value.absent(),
    this.kind = const Value.absent(),
    this.size = const Value.absent(),
    this.config = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  DashboardItemsCompanion.insert({
    this.id = const Value.absent(),
    required int journeyId,
    required String kind,
    this.size = const Value.absent(),
    this.config = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : journeyId = Value(journeyId),
       kind = Value(kind);
  static Insertable<DashboardItemRow> custom({
    Expression<int>? id,
    Expression<int>? journeyId,
    Expression<String>? kind,
    Expression<String>? size,
    Expression<String>? config,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (journeyId != null) 'journey_id': journeyId,
      if (kind != null) 'kind': kind,
      if (size != null) 'size': size,
      if (config != null) 'config': config,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  DashboardItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? journeyId,
    Value<String>? kind,
    Value<String>? size,
    Value<DashboardItemConfig>? config,
    Value<int>? sortOrder,
  }) {
    return DashboardItemsCompanion(
      id: id ?? this.id,
      journeyId: journeyId ?? this.journeyId,
      kind: kind ?? this.kind,
      size: size ?? this.size,
      config: config ?? this.config,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (journeyId.present) {
      map['journey_id'] = Variable<int>(journeyId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(
        $DashboardItemsTable.$converterconfig.toSql(config.value),
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DashboardItemsCompanion(')
          ..write('id: $id, ')
          ..write('journeyId: $journeyId, ')
          ..write('kind: $kind, ')
          ..write('size: $size, ')
          ..write('config: $config, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $JourneysTable journeys = $JourneysTable(this);
  late final $TrackersTable trackers = $TrackersTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $DashboardItemsTable dashboardItems = $DashboardItemsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index trackersJourney = Index(
    'trackers_journey',
    'CREATE INDEX trackers_journey ON trackers (journey_id)',
  );
  late final Index entriesDay = Index(
    'entries_day',
    'CREATE INDEX entries_day ON entries (day)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    journeys,
    trackers,
    entries,
    dashboardItems,
    settings,
    trackersJourney,
    entriesDay,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'journeys',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trackers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trackers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'journeys',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dashboard_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$JourneysTableCreateCompanionBuilder = JourneysCompanion Function({
  Value<int> id,
  required String name,
  Value<String> intention,
  required Day startDay,
  required int durationDays,
  Value<bool> isActive,
  Value<DateTime> createdAt,
});
typedef $$JourneysTableUpdateCompanionBuilder = JourneysCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> intention,
  Value<Day> startDay,
  Value<int> durationDays,
  Value<bool> isActive,
  Value<DateTime> createdAt,
});

final class $$JourneysTableReferences
    extends BaseReferences<_$AppDatabase, $JourneysTable, JourneyRow> {
  $$JourneysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TrackersTable, List<TrackerRow>>
  _trackersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trackers,
    aliasName: 'journeys__id__trackers__journey_id',
  );

  $$TrackersTableProcessedTableManager get trackersRefs {
    final manager = $$TrackersTableTableManager(
      $_db,
      $_db.trackers,
    ).filter((f) => f.journeyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DashboardItemsTable, List<DashboardItemRow>>
  _dashboardItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dashboardItems,
    aliasName: 'journeys__id__dashboard_items__journey_id',
  );

  $$DashboardItemsTableProcessedTableManager get dashboardItemsRefs {
    final manager = $$DashboardItemsTableTableManager(
      $_db,
      $_db.dashboardItems,
    ).filter((f) => f.journeyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_dashboardItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$JourneysTableFilterComposer
    extends Composer<_$AppDatabase, $JourneysTable> {
  $$JourneysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intention => $composableBuilder(
    column: $table.intention,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Day, Day, String> get startDay =>
      $composableBuilder(
        column: $table.startDay,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get durationDays => $composableBuilder(
    column: $table.durationDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> trackersRefs(
    Expression<bool> Function($$TrackersTableFilterComposer f) f,
  ) {
    final $$TrackersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackers,
      getReferencedColumn: (t) => t.journeyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackersTableFilterComposer(
            $db: $db,
            $table: $db.trackers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dashboardItemsRefs(
    Expression<bool> Function($$DashboardItemsTableFilterComposer f) f,
  ) {
    final $$DashboardItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dashboardItems,
      getReferencedColumn: (t) => t.journeyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DashboardItemsTableFilterComposer(
            $db: $db,
            $table: $db.dashboardItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$JourneysTableOrderingComposer
    extends Composer<_$AppDatabase, $JourneysTable> {
  $$JourneysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intention => $composableBuilder(
    column: $table.intention,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDay => $composableBuilder(
    column: $table.startDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationDays => $composableBuilder(
    column: $table.durationDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JourneysTableAnnotationComposer
    extends Composer<_$AppDatabase, $JourneysTable> {
  $$JourneysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get intention =>
      $composableBuilder(column: $table.intention, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Day, String> get startDay =>
      $composableBuilder(column: $table.startDay, builder: (column) => column);

  GeneratedColumn<int> get durationDays => $composableBuilder(
    column: $table.durationDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> trackersRefs<T extends Object>(
    Expression<T> Function($$TrackersTableAnnotationComposer a) f,
  ) {
    final $$TrackersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackers,
      getReferencedColumn: (t) => t.journeyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackersTableAnnotationComposer(
            $db: $db,
            $table: $db.trackers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dashboardItemsRefs<T extends Object>(
    Expression<T> Function($$DashboardItemsTableAnnotationComposer a) f,
  ) {
    final $$DashboardItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dashboardItems,
      getReferencedColumn: (t) => t.journeyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DashboardItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.dashboardItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$JourneysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JourneysTable,
          JourneyRow,
          $$JourneysTableFilterComposer,
          $$JourneysTableOrderingComposer,
          $$JourneysTableAnnotationComposer,
          $$JourneysTableCreateCompanionBuilder,
          $$JourneysTableUpdateCompanionBuilder,
          (JourneyRow, $$JourneysTableReferences),
          JourneyRow,
          PrefetchHooks Function({bool trackersRefs, bool dashboardItemsRefs})
        > {
  $$JourneysTableTableManager(_$AppDatabase db, $JourneysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JourneysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JourneysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JourneysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> intention = const Value.absent(),
                Value<Day> startDay = const Value.absent(),
                Value<int> durationDays = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => JourneysCompanion(
                id: id,
                name: name,
                intention: intention,
                startDay: startDay,
                durationDays: durationDays,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> intention = const Value.absent(),
                required Day startDay,
                required int durationDays,
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => JourneysCompanion.insert(
                id: id,
                name: name,
                intention: intention,
                startDay: startDay,
                durationDays: durationDays,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JourneysTable, JourneyRow>(table),
                  $$JourneysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({trackersRefs = false, dashboardItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (trackersRefs) db.trackers,
                    if (dashboardItemsRefs) db.dashboardItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (trackersRefs)
                        await $_getPrefetchedData<
                          JourneyRow,
                          $JourneysTable,
                          TrackerRow
                        >(
                          currentTable: table,
                          referencedTable: $$JourneysTableReferences
                              ._trackersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$JourneysTableReferences(
                                db,
                                table,
                                p0,
                              ).trackersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.journeyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dashboardItemsRefs)
                        await $_getPrefetchedData<
                          JourneyRow,
                          $JourneysTable,
                          DashboardItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$JourneysTableReferences
                              ._dashboardItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$JourneysTableReferences(
                                db,
                                table,
                                p0,
                              ).dashboardItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.journeyId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$JourneysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JourneysTable,
      JourneyRow,
      $$JourneysTableFilterComposer,
      $$JourneysTableOrderingComposer,
      $$JourneysTableAnnotationComposer,
      $$JourneysTableCreateCompanionBuilder,
      $$JourneysTableUpdateCompanionBuilder,
      (JourneyRow, $$JourneysTableReferences),
      JourneyRow,
      PrefetchHooks Function({bool trackersRefs, bool dashboardItemsRefs})
    >;
typedef $$TrackersTableCreateCompanionBuilder = TrackersCompanion Function({
  Value<int> id,
  required int journeyId,
  required String name,
  Value<String> description,
  required TrackerType type,
  Value<String> icon,
  required int color,
  Value<String> section,
  Value<int?> anchorMinutes,
  Value<int> weekdays,
  Value<bool> isRequired,
  Value<TrackerConfig> config,
  Value<TrackerGoal> goal,
  Value<bool> reminderEnabled,
  Value<int?> reminderMinutes,
  Value<int> sortOrder,
  required Day activeFrom,
  Value<Day?> archivedOn,
  Value<DateTime> createdAt,
});
typedef $$TrackersTableUpdateCompanionBuilder = TrackersCompanion Function({
  Value<int> id,
  Value<int> journeyId,
  Value<String> name,
  Value<String> description,
  Value<TrackerType> type,
  Value<String> icon,
  Value<int> color,
  Value<String> section,
  Value<int?> anchorMinutes,
  Value<int> weekdays,
  Value<bool> isRequired,
  Value<TrackerConfig> config,
  Value<TrackerGoal> goal,
  Value<bool> reminderEnabled,
  Value<int?> reminderMinutes,
  Value<int> sortOrder,
  Value<Day> activeFrom,
  Value<Day?> archivedOn,
  Value<DateTime> createdAt,
});

final class $$TrackersTableReferences
    extends BaseReferences<_$AppDatabase, $TrackersTable, TrackerRow> {
  $$TrackersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $JourneysTable _journeyIdTable(_$AppDatabase db) =>
      db.journeys.createAlias('trackers__journey_id__journeys__id');

  $$JourneysTableProcessedTableManager get journeyId {
    final $_column = $_itemColumn<int>('journey_id')!;

    final manager = $$JourneysTableTableManager(
      $_db,
      $_db.journeys,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_journeyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EntriesTable, List<EntryRow>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'trackers__id__entries__tracker_id',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.trackerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TrackersTableFilterComposer
    extends Composer<_$AppDatabase, $TrackersTable> {
  $$TrackersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
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

  ColumnWithTypeConverterFilters<TrackerType, TrackerType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anchorMinutes => $composableBuilder(
    column: $table.anchorMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TrackerConfig, TrackerConfig, String>
  get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<TrackerGoal, TrackerGoal, String> get goal =>
      $composableBuilder(
        column: $table.goal,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Day, Day, String> get activeFrom =>
      $composableBuilder(
        column: $table.activeFrom,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Day?, Day, String> get archivedOn =>
      $composableBuilder(
        column: $table.archivedOn,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$JourneysTableFilterComposer get journeyId {
    final $$JourneysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.journeyId,
      referencedTable: $db.journeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JourneysTableFilterComposer(
            $db: $db,
            $table: $db.journeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.trackerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrackersTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackersTable> {
  $$TrackersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anchorMinutes => $composableBuilder(
    column: $table.anchorMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeFrom => $composableBuilder(
    column: $table.activeFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedOn => $composableBuilder(
    column: $table.archivedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$JourneysTableOrderingComposer get journeyId {
    final $$JourneysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.journeyId,
      referencedTable: $db.journeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JourneysTableOrderingComposer(
            $db: $db,
            $table: $db.journeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackersTable> {
  $$TrackersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TrackerType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<int> get anchorMinutes => $composableBuilder(
    column: $table.anchorMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TrackerConfig, String> get config =>
      $composableBuilder(column: $table.config, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TrackerGoal, String> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Day, String> get activeFrom =>
      $composableBuilder(
        column: $table.activeFrom,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Day?, String> get archivedOn =>
      $composableBuilder(
        column: $table.archivedOn,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$JourneysTableAnnotationComposer get journeyId {
    final $$JourneysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.journeyId,
      referencedTable: $db.journeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JourneysTableAnnotationComposer(
            $db: $db,
            $table: $db.journeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.trackerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrackersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackersTable,
          TrackerRow,
          $$TrackersTableFilterComposer,
          $$TrackersTableOrderingComposer,
          $$TrackersTableAnnotationComposer,
          $$TrackersTableCreateCompanionBuilder,
          $$TrackersTableUpdateCompanionBuilder,
          (TrackerRow, $$TrackersTableReferences),
          TrackerRow,
          PrefetchHooks Function({bool journeyId, bool entriesRefs})
        > {
  $$TrackersTableTableManager(_$AppDatabase db, $TrackersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> journeyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<TrackerType> type = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String> section = const Value.absent(),
                Value<int?> anchorMinutes = const Value.absent(),
                Value<int> weekdays = const Value.absent(),
                Value<bool> isRequired = const Value.absent(),
                Value<TrackerConfig> config = const Value.absent(),
                Value<TrackerGoal> goal = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<Day> activeFrom = const Value.absent(),
                Value<Day?> archivedOn = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TrackersCompanion(
                id: id,
                journeyId: journeyId,
                name: name,
                description: description,
                type: type,
                icon: icon,
                color: color,
                section: section,
                anchorMinutes: anchorMinutes,
                weekdays: weekdays,
                isRequired: isRequired,
                config: config,
                goal: goal,
                reminderEnabled: reminderEnabled,
                reminderMinutes: reminderMinutes,
                sortOrder: sortOrder,
                activeFrom: activeFrom,
                archivedOn: archivedOn,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int journeyId,
                required String name,
                Value<String> description = const Value.absent(),
                required TrackerType type,
                Value<String> icon = const Value.absent(),
                required int color,
                Value<String> section = const Value.absent(),
                Value<int?> anchorMinutes = const Value.absent(),
                Value<int> weekdays = const Value.absent(),
                Value<bool> isRequired = const Value.absent(),
                Value<TrackerConfig> config = const Value.absent(),
                Value<TrackerGoal> goal = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required Day activeFrom,
                Value<Day?> archivedOn = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TrackersCompanion.insert(
                id: id,
                journeyId: journeyId,
                name: name,
                description: description,
                type: type,
                icon: icon,
                color: color,
                section: section,
                anchorMinutes: anchorMinutes,
                weekdays: weekdays,
                isRequired: isRequired,
                config: config,
                goal: goal,
                reminderEnabled: reminderEnabled,
                reminderMinutes: reminderMinutes,
                sortOrder: sortOrder,
                activeFrom: activeFrom,
                archivedOn: archivedOn,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackersTable, TrackerRow>(table),
                  $$TrackersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({journeyId = false, entriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entriesRefs) db.entries],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (journeyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.journeyId,
                        referencedTable: $$TrackersTableReferences
                            ._journeyIdTable(db),
                        referencedColumn: $$TrackersTableReferences
                            ._journeyIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entriesRefs)
                    await $_getPrefetchedData<
                      TrackerRow,
                      $TrackersTable,
                      EntryRow
                    >(
                      currentTable: table,
                      referencedTable: $$TrackersTableReferences
                          ._entriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TrackersTableReferences(db, table, p0).entriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.trackerId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TrackersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackersTable,
      TrackerRow,
      $$TrackersTableFilterComposer,
      $$TrackersTableOrderingComposer,
      $$TrackersTableAnnotationComposer,
      $$TrackersTableCreateCompanionBuilder,
      $$TrackersTableUpdateCompanionBuilder,
      (TrackerRow, $$TrackersTableReferences),
      TrackerRow,
      PrefetchHooks Function({bool journeyId, bool entriesRefs})
    >;
typedef $$EntriesTableCreateCompanionBuilder = EntriesCompanion Function({
  Value<int> id,
  required int trackerId,
  required Day day,
  required TrackerValue value,
  Value<String> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$EntriesTableUpdateCompanionBuilder = EntriesCompanion Function({
  Value<int> id,
  Value<int> trackerId,
  Value<Day> day,
  Value<TrackerValue> value,
  Value<String> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$EntriesTableReferences
    extends BaseReferences<_$AppDatabase, $EntriesTable, EntryRow> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TrackersTable _trackerIdTable(_$AppDatabase db) =>
      db.trackers.createAlias('entries__tracker_id__trackers__id');

  $$TrackersTableProcessedTableManager get trackerId {
    final $_column = $_itemColumn<int>('tracker_id')!;

    final manager = $$TrackersTableTableManager(
      $_db,
      $_db.trackers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Day, Day, String> get day =>
      $composableBuilder(
        column: $table.day,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<TrackerValue, TrackerValue, String>
  get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
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

  $$TrackersTableFilterComposer get trackerId {
    final $$TrackersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackerId,
      referencedTable: $db.trackers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackersTableFilterComposer(
            $db: $db,
            $table: $db.trackers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
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

  $$TrackersTableOrderingComposer get trackerId {
    final $$TrackersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackerId,
      referencedTable: $db.trackers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackersTableOrderingComposer(
            $db: $db,
            $table: $db.trackers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Day, String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TrackerValue, String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TrackersTableAnnotationComposer get trackerId {
    final $$TrackersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackerId,
      referencedTable: $db.trackers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackersTableAnnotationComposer(
            $db: $db,
            $table: $db.trackers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          EntryRow,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (EntryRow, $$EntriesTableReferences),
          EntryRow,
          PrefetchHooks Function({bool trackerId})
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackerId = const Value.absent(),
                Value<Day> day = const Value.absent(),
                Value<TrackerValue> value = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                trackerId: trackerId,
                day: day,
                value: value,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackerId,
                required Day day,
                required TrackerValue value,
                Value<String> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                trackerId: trackerId,
                day: day,
                value: value,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntriesTable, EntryRow>(table),
                  $$EntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackerId,
                        referencedTable: $$EntriesTableReferences
                            ._trackerIdTable(db),
                        referencedColumn: $$EntriesTableReferences
                            ._trackerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      EntryRow,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (EntryRow, $$EntriesTableReferences),
      EntryRow,
      PrefetchHooks Function({bool trackerId})
    >;
typedef $$DashboardItemsTableCreateCompanionBuilder =
    DashboardItemsCompanion Function({
      Value<int> id,
      required int journeyId,
      required String kind,
      Value<String> size,
      Value<DashboardItemConfig> config,
      Value<int> sortOrder,
    });
typedef $$DashboardItemsTableUpdateCompanionBuilder =
    DashboardItemsCompanion Function({
      Value<int> id,
      Value<int> journeyId,
      Value<String> kind,
      Value<String> size,
      Value<DashboardItemConfig> config,
      Value<int> sortOrder,
    });

final class $$DashboardItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DashboardItemsTable, DashboardItemRow> {
  $$DashboardItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $JourneysTable _journeyIdTable(_$AppDatabase db) =>
      db.journeys.createAlias('dashboard_items__journey_id__journeys__id');

  $$JourneysTableProcessedTableManager get journeyId {
    final $_column = $_itemColumn<int>('journey_id')!;

    final manager = $$JourneysTableTableManager(
      $_db,
      $_db.journeys,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_journeyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DashboardItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DashboardItemsTable> {
  $$DashboardItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    DashboardItemConfig,
    DashboardItemConfig,
    String
  >
  get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$JourneysTableFilterComposer get journeyId {
    final $$JourneysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.journeyId,
      referencedTable: $db.journeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JourneysTableFilterComposer(
            $db: $db,
            $table: $db.journeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DashboardItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DashboardItemsTable> {
  $$DashboardItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get config => $composableBuilder(
    column: $table.config,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$JourneysTableOrderingComposer get journeyId {
    final $$JourneysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.journeyId,
      referencedTable: $db.journeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JourneysTableOrderingComposer(
            $db: $db,
            $table: $db.journeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DashboardItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DashboardItemsTable> {
  $$DashboardItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DashboardItemConfig, String> get config =>
      $composableBuilder(column: $table.config, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$JourneysTableAnnotationComposer get journeyId {
    final $$JourneysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.journeyId,
      referencedTable: $db.journeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JourneysTableAnnotationComposer(
            $db: $db,
            $table: $db.journeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DashboardItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DashboardItemsTable,
          DashboardItemRow,
          $$DashboardItemsTableFilterComposer,
          $$DashboardItemsTableOrderingComposer,
          $$DashboardItemsTableAnnotationComposer,
          $$DashboardItemsTableCreateCompanionBuilder,
          $$DashboardItemsTableUpdateCompanionBuilder,
          (DashboardItemRow, $$DashboardItemsTableReferences),
          DashboardItemRow,
          PrefetchHooks Function({bool journeyId})
        > {
  $$DashboardItemsTableTableManager(
    _$AppDatabase db,
    $DashboardItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DashboardItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DashboardItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DashboardItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> journeyId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> size = const Value.absent(),
                Value<DashboardItemConfig> config = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => DashboardItemsCompanion(
                id: id,
                journeyId: journeyId,
                kind: kind,
                size: size,
                config: config,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int journeyId,
                required String kind,
                Value<String> size = const Value.absent(),
                Value<DashboardItemConfig> config = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => DashboardItemsCompanion.insert(
                id: id,
                journeyId: journeyId,
                kind: kind,
                size: size,
                config: config,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DashboardItemsTable, DashboardItemRow>(table),
                  $$DashboardItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({journeyId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (journeyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.journeyId,
                        referencedTable: $$DashboardItemsTableReferences
                            ._journeyIdTable(db),
                        referencedColumn: $$DashboardItemsTableReferences
                            ._journeyIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DashboardItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DashboardItemsTable,
      DashboardItemRow,
      $$DashboardItemsTableFilterComposer,
      $$DashboardItemsTableOrderingComposer,
      $$DashboardItemsTableAnnotationComposer,
      $$DashboardItemsTableCreateCompanionBuilder,
      $$DashboardItemsTableUpdateCompanionBuilder,
      (DashboardItemRow, $$DashboardItemsTableReferences),
      DashboardItemRow,
      PrefetchHooks Function({bool journeyId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
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

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$JourneysTableTableManager get journeys =>
      $$JourneysTableTableManager(_db, _db.journeys);
  $$TrackersTableTableManager get trackers =>
      $$TrackersTableTableManager(_db, _db.trackers);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$DashboardItemsTableTableManager get dashboardItems =>
      $$DashboardItemsTableTableManager(_db, _db.dashboardItems);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
