import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../../core/time/day.dart';
import '../../domain/models.dart';
import '../db/database.dart';
import 'mappers.dart';

final _log = Logger('TrackerRepository');

class TrackerRepository {
  TrackerRepository(this._db);

  final AppDatabase _db;

  /// All trackers of a journey (including archived), in display order.
  Stream<List<Tracker>> watchForJourney(int journeyId) {
    final q = _db.select(_db.trackers)
      ..where((t) => t.journeyId.equals(journeyId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return q.watch().map((rows) => [for (final r in rows) r.toDomain()]);
  }

  Future<List<Tracker>> forJourney(int journeyId) async {
    final q = _db.select(_db.trackers)
      ..where((t) => t.journeyId.equals(journeyId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return [for (final r in await q.get()) r.toDomain()];
  }

  Future<List<Tracker>> allWithReminders() async {
    final q =
        _db.select(_db.trackers).join([
          innerJoin(
            _db.journeys,
            _db.journeys.id.equalsExp(_db.trackers.journeyId),
          ),
        ])..where(
          _db.journeys.isActive.equals(true) &
              _db.trackers.reminderEnabled.equals(true) &
              _db.trackers.archivedOn.isNull(),
        );
    final rows = await q.get();
    return [for (final r in rows) r.readTable(_db.trackers).toDomain()];
  }

  /// Inserts a new tracker. It is placed by its anchor time among the
  /// existing trackers so the timeline stays chronological.
  Future<int> insert(Tracker tracker) => _db.transaction(() async {
    final existing = await forJourney(tracker.journeyId);
    var position = existing.length;
    if (tracker.anchorMinutes != null) {
      final idx = existing.indexWhere(
        (t) =>
            t.anchorMinutes != null &&
            t.anchorMinutes! > tracker.anchorMinutes!,
      );
      if (idx >= 0) position = idx;
    }
    final ordered = [...existing]..insert(position, tracker);
    var newId = -1;
    for (final (i, t) in ordered.indexed) {
      if (identical(t, tracker)) {
        newId = await _db
            .into(_db.trackers)
            .insert(t.copyWith(sortOrder: i).toCompanion());
      } else if (t.sortOrder != i) {
        await (_db.update(_db.trackers)..where((r) => r.id.equals(t.id))).write(
          TrackersCompanion(sortOrder: Value(i)),
        );
      }
    }
    _log.info(
      'Inserted tracker $newId "${tracker.name}" (${tracker.type.name})',
    );
    return newId;
  });

  Future<void> update(Tracker tracker) async {
    await (_db.update(_db.trackers)..where((t) => t.id.equals(tracker.id)))
        .write(tracker.toCompanion(includeId: true));
    _log.info('Updated tracker ${tracker.id}');
  }

  /// Persists a new order (list of ids, top to bottom).
  Future<void> reorder(List<int> orderedIds) => _db.batch((b) {
    for (final (i, id) in orderedIds.indexed) {
      b.update(
        _db.trackers,
        TrackersCompanion(sortOrder: Value(i)),
        where: (t) => t.id.equals(id),
      );
    }
  });

  Future<void> archive(int trackerId, Day fromDay) =>
      (_db.update(_db.trackers)..where((t) => t.id.equals(trackerId))).write(
        TrackersCompanion(archivedOn: Value(fromDay)),
      );

  Future<void> restore(int trackerId) =>
      (_db.update(_db.trackers)..where((t) => t.id.equals(trackerId))).write(
        const TrackersCompanion(archivedOn: Value(null)),
      );

  /// Deletes a tracker and (via cascade) all of its entries.
  Future<void> delete(int trackerId) async {
    await (_db.delete(_db.trackers)..where((t) => t.id.equals(trackerId))).go();
    _log.info('Deleted tracker $trackerId');
  }

  Future<int> entryCount(int trackerId) async {
    final count = _db.entries.id.count();
    final q = _db.selectOnly(_db.entries)
      ..addColumns([count])
      ..where(_db.entries.trackerId.equals(trackerId));
    return (await q.getSingle()).read(count) ?? 0;
  }
}
