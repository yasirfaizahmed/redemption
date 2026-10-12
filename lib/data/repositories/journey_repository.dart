import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../../core/time/day.dart';
import '../../domain/models.dart';
import '../../domain/templates.dart';
import '../../domain/tracker_config.dart';
import '../db/database.dart';
import 'mappers.dart';

final _log = Logger('JourneyRepository');

class JourneyRepository {
  JourneyRepository(this._db);

  final AppDatabase _db;

  Stream<Journey?> watchActive() {
    final q = _db.select(_db.journeys)
      ..where((j) => j.isActive.equals(true))
      ..limit(1);
    return q.watchSingleOrNull().map((r) => r?.toDomain());
  }

  Stream<List<Journey>> watchAll() {
    final q = _db.select(_db.journeys)
      ..orderBy([(j) => OrderingTerm.desc(j.createdAt)]);
    return q.watch().map((rows) => [for (final r in rows) r.toDomain()]);
  }

  Future<Journey?> active() async {
    final q = _db.select(_db.journeys)
      ..where((j) => j.isActive.equals(true))
      ..limit(1);
    return (await q.getSingleOrNull())?.toDomain();
  }

  Future<void> update(Journey journey) async {
    await (_db.update(
      _db.journeys,
    )..where((j) => j.id.equals(journey.id))).write(
      JourneysCompanion(
        name: Value(journey.name),
        intention: Value(journey.intention),
        startDay: Value(journey.startDay),
        durationDays: Value(journey.durationDays),
      ),
    );
  }

  Future<void> setActive(int journeyId) => _db.transaction(() async {
    await _db
        .update(_db.journeys)
        .write(const JourneysCompanion(isActive: Value(false)));
    await (_db.update(_db.journeys)..where((j) => j.id.equals(journeyId)))
        .write(const JourneysCompanion(isActive: Value(true)));
  });

  Future<void> delete(int journeyId) =>
      (_db.delete(_db.journeys)..where((j) => j.id.equals(journeyId))).go();

  /// Creates a journey from [template] and makes it the active one.
  Future<int> createFromTemplate({
    required JourneyTemplate template,
    required String name,
    required String intention,
    required Day startDay,
    required int durationDays,
  }) => _db.transaction(() async {
    final journeyId = await _insertActiveJourney(
      name: name,
      intention: intention,
      startDay: startDay,
      durationDays: durationDays,
    );
    final refToId = <String, int>{};
    for (final (i, tt) in template.trackers.indexed) {
      final tracker = tt.tracker.copyWith(
        journeyId: journeyId,
        sortOrder: i,
        activeFrom: startDay,
      );
      refToId[tt.ref] = await _db
          .into(_db.trackers)
          .insert(tracker.toCompanion());
    }
    // Day rules reference other trackers by template ref: resolve them now.
    for (final tt in template.trackers) {
      final rule = tt.tracker.config.dayRule;
      final whenId = refToId[rule?.whenRef];
      if (rule == null || whenId == null) continue;
      await _setDayRule(refToId[tt.ref]!, rule.copyWith(whenTrackerId: whenId));
    }
    for (final (i, w) in template.widgets.indexed) {
      final ids = [
        for (final r in w.refs)
          if (refToId[r] != null) refToId[r]!,
      ];
      await _db
          .into(_db.dashboardItems)
          .insert(
            DashboardItemsCompanion.insert(
              journeyId: journeyId,
              kind: w.kind.name,
              size: Value(w.size.name),
              config: Value(w.config.copyWith(trackerIds: ids)),
              sortOrder: Value(i),
            ),
          );
    }
    _log.info(
      'Created journey $journeyId from template ${template.id} '
      '(${template.trackers.length} trackers)',
    );
    return journeyId;
  });

  Future<void> _setDayRule(int trackerId, DayRule? rule) async {
    final row = await (_db.select(
      _db.trackers,
    )..where((t) => t.id.equals(trackerId))).getSingle();
    await (_db.update(
      _db.trackers,
    )..where((t) => t.id.equals(trackerId))).write(
      TrackersCompanion(
        config: Value(row.config.copyWith(dayRule: () => rule)),
      ),
    );
  }

  /// Starts a fresh journey, optionally copying trackers and dashboard layout
  /// from [copyFrom]. History of the old journey is kept untouched.
  Future<int> createFromExisting({
    required int copyFrom,
    required String name,
    required String intention,
    required Day startDay,
    required int durationDays,
  }) => _db.transaction(() async {
    final journeyId = await _insertActiveJourney(
      name: name,
      intention: intention,
      startDay: startDay,
      durationDays: durationDays,
    );
    final trackers =
        await (_db.select(_db.trackers)..where(
              (t) => t.journeyId.equals(copyFrom) & t.archivedOn.isNull(),
            ))
            .get();
    final idMap = <int, int>{};
    for (final row in trackers) {
      final t = row.toDomain().copyWith(
        journeyId: journeyId,
        activeFrom: startDay,
      );
      idMap[row.id] = await _db.into(_db.trackers).insert(t.toCompanion());
    }
    // Point copied day rules at the copies of the trackers they watch.
    for (final row in trackers) {
      final rule = row.toDomain().config.dayRule;
      if (rule == null) continue;
      final whenId = idMap[rule.whenTrackerId];
      await _setDayRule(
        idMap[row.id]!,
        whenId == null ? null : rule.copyWith(whenTrackerId: whenId),
      );
    }
    final items = await (_db.select(
      _db.dashboardItems,
    )..where((d) => d.journeyId.equals(copyFrom))).get();
    for (final item in items) {
      final cfg = item.config.copyWith(
        trackerIds: [
          for (final id in item.config.trackerIds)
            if (idMap[id] != null) idMap[id]!,
        ],
      );
      await _db
          .into(_db.dashboardItems)
          .insert(
            DashboardItemsCompanion.insert(
              journeyId: journeyId,
              kind: item.kind,
              size: Value(item.size),
              config: Value(cfg),
              sortOrder: Value(item.sortOrder),
            ),
          );
    }
    _log.info('Created journey $journeyId copied from $copyFrom');
    return journeyId;
  });

  Future<int> _insertActiveJourney({
    required String name,
    required String intention,
    required Day startDay,
    required int durationDays,
  }) async {
    await _db
        .update(_db.journeys)
        .write(const JourneysCompanion(isActive: Value(false)));
    return _db
        .into(_db.journeys)
        .insert(
          JourneysCompanion.insert(
            name: name.trim().isEmpty ? 'My journey' : name.trim(),
            intention: Value(intention.trim()),
            startDay: startDay,
            durationDays: durationDays,
            isActive: const Value(true),
          ),
        );
  }
}
