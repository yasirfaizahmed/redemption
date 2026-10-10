// Drift column getters reference themselves in CHECK constraints by design.
// ignore_for_file: recursive_getters

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/time/day.dart';
import '../../domain/dashboard.dart';
import '../../domain/tracker_config.dart';
import '../../domain/tracker_goal.dart';
import '../../domain/tracker_type.dart';
import '../../domain/tracker_value.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Type converters: domain objects <-> SQLite columns.
// ---------------------------------------------------------------------------

class DayConverter extends TypeConverter<Day, String>
    with JsonTypeConverter<Day, String> {
  const DayConverter();
  @override
  Day fromSql(String fromDb) => Day.parse(fromDb);
  @override
  String toSql(Day value) => value.key;
}

class TrackerTypeConverter extends TypeConverter<TrackerType, String>
    with JsonTypeConverter<TrackerType, String> {
  const TrackerTypeConverter();
  @override
  TrackerType fromSql(String fromDb) => TrackerType.parse(fromDb);
  @override
  String toSql(TrackerType value) => value.name;
}

class TrackerConfigConverter extends TypeConverter<TrackerConfig, String>
    with JsonTypeConverter2<TrackerConfig, String, Map<String, dynamic>> {
  const TrackerConfigConverter();
  @override
  TrackerConfig fromJson(Map<String, dynamic> json) =>
      TrackerConfig.fromJson(json);
  @override
  Map<String, dynamic> toJson(TrackerConfig value) => value.toJson();
  @override
  TrackerConfig fromSql(String fromDb) =>
      TrackerConfig.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);
  @override
  String toSql(TrackerConfig value) => jsonEncode(value.toJson());
}

class TrackerGoalConverter extends TypeConverter<TrackerGoal, String>
    with JsonTypeConverter2<TrackerGoal, String, Map<String, dynamic>> {
  const TrackerGoalConverter();
  @override
  TrackerGoal fromJson(Map<String, dynamic> json) => TrackerGoal.fromJson(json);
  @override
  Map<String, dynamic> toJson(TrackerGoal value) => value.toJson();
  @override
  TrackerGoal fromSql(String fromDb) =>
      TrackerGoal.fromJson(jsonDecode(fromDb) as Map<String, dynamic>?);
  @override
  String toSql(TrackerGoal value) => jsonEncode(value.toJson());
}

class TrackerValueConverter extends TypeConverter<TrackerValue, String>
    with JsonTypeConverter2<TrackerValue, String, Map<String, dynamic>> {
  const TrackerValueConverter();
  @override
  TrackerValue fromJson(Map<String, dynamic> json) =>
      TrackerValue.fromJson(json) ?? const TextValue('');
  @override
  Map<String, dynamic> toJson(TrackerValue value) => value.toJson();
  @override
  TrackerValue fromSql(String fromDb) =>
      TrackerValue.fromJson(jsonDecode(fromDb) as Map<String, dynamic>) ??
      const TextValue('');
  @override
  String toSql(TrackerValue value) => jsonEncode(value.toJson());
}

class DashboardConfigConverter
    extends TypeConverter<DashboardItemConfig, String>
    with JsonTypeConverter2<DashboardItemConfig, String, Map<String, dynamic>> {
  const DashboardConfigConverter();
  @override
  DashboardItemConfig fromJson(Map<String, dynamic> json) =>
      DashboardItemConfig.fromJson(json);
  @override
  Map<String, dynamic> toJson(DashboardItemConfig value) => value.toJson();
  @override
  DashboardItemConfig fromSql(String fromDb) =>
      DashboardItemConfig.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);
  @override
  String toSql(DashboardItemConfig value) => jsonEncode(value.toJson());
}

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

@DataClassName('JourneyRow')
class Journeys extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get intention => text().withDefault(const Constant(''))();
  TextColumn get startDay => text().map(const DayConverter())();
  IntColumn get durationDays =>
      integer().check(durationDays.isBiggerThanValue(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('TrackerRow')
@TableIndex(name: 'trackers_journey', columns: {#journeyId})
class Trackers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get journeyId =>
      integer().references(Journeys, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get type => text().map(const TrackerTypeConverter())();
  TextColumn get icon => text().withDefault(const Constant('check'))();
  IntColumn get color => integer()();
  TextColumn get section => text().withDefault(const Constant(''))();
  IntColumn get anchorMinutes => integer().nullable()();
  IntColumn get weekdays => integer().withDefault(const Constant(0x7F))();
  BoolColumn get isRequired => boolean().withDefault(const Constant(true))();
  TextColumn get config => text()
      .map(const TrackerConfigConverter())
      .withDefault(const Constant('{}'))();
  TextColumn get goal => text()
      .map(const TrackerGoalConverter())
      .withDefault(const Constant('{"kind":"logged"}'))();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get reminderMinutes => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get activeFrom => text().map(const DayConverter())();
  TextColumn get archivedOn => text().map(const DayConverter()).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('EntryRow')
@TableIndex(name: 'entries_day', columns: {#day})
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackerId =>
      integer().references(Trackers, #id, onDelete: KeyAction.cascade)();
  TextColumn get day => text().map(const DayConverter())();
  TextColumn get value => text().map(const TrackerValueConverter())();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {trackerId, day},
  ];
}

@DataClassName('DashboardItemRow')
class DashboardItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get journeyId =>
      integer().references(Journeys, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get size => text().withDefault(const Constant('full'))();
  TextColumn get config => text()
      .map(const DashboardConfigConverter())
      .withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Journeys, Trackers, Entries, DashboardItems, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  static const fileName = 'redemption';

  static QueryExecutor _openDefault() => driftDatabase(name: fileName);

  /// Bump on every schema change and add a step to [migration].
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Future migrations go here, one `if (from < N)` block per version.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
