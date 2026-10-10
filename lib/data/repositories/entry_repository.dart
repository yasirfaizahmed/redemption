import 'package:drift/drift.dart';

import '../../core/time/day.dart';
import '../../domain/models.dart';
import '../../domain/tracker_value.dart';
import '../db/database.dart';
import 'mappers.dart';

class EntryRepository {
  EntryRepository(this._db);

  final AppDatabase _db;

  /// Every entry of every tracker in a journey. Journeys are small (≈90 days ×
  /// ~15 trackers), so analytics are computed in memory from this stream.
  Stream<List<Entry>> watchForJourney(int journeyId) {
    final q = _db.select(_db.entries).join([
      innerJoin(_db.trackers, _db.trackers.id.equalsExp(_db.entries.trackerId)),
    ])..where(_db.trackers.journeyId.equals(journeyId));
    return q.watch().map(
      (rows) => [for (final r in rows) r.readTable(_db.entries).toDomain()],
    );
  }

  Future<Entry?> get(int trackerId, Day day) async {
    final q = _db.select(_db.entries)
      ..where((e) => e.trackerId.equals(trackerId) & e.day.equalsValue(day));
    return (await q.getSingleOrNull())?.toDomain();
  }

  /// Inserts or replaces the entry of [trackerId] on [day].
  Future<void> upsert({
    required int trackerId,
    required Day day,
    required TrackerValue value,
    String note = '',
  }) async {
    final now = DateTime.now();
    await _db
        .into(_db.entries)
        .insert(
          EntriesCompanion.insert(
            trackerId: trackerId,
            day: day,
            value: value,
            note: Value(note),
            updatedAt: Value(now),
          ),
          onConflict: DoUpdate(
            (old) => EntriesCompanion(
              value: Value(value),
              note: Value(note),
              updatedAt: Value(now),
            ),
            target: [_db.entries.trackerId, _db.entries.day],
          ),
        );
  }

  Future<void> delete(int trackerId, Day day) => (_db.delete(
    _db.entries,
  )..where((e) => e.trackerId.equals(trackerId) & e.day.equalsValue(day))).go();

  /// All attachment paths referenced by any entry (for orphan cleanup).
  Future<Set<String>> referencedAttachments() async {
    final rows = await _db.select(_db.entries).get();
    return {
      for (final r in rows)
        if (r.value case AttachmentsValue(:final files))
          for (final f in files) f.relativePath,
    };
  }
}
