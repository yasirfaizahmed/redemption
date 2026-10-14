import 'package:logging/logging.dart';

import '../../core/time/day.dart';
import '../../domain/journey_upgrades.dart';
import '../../domain/tracker_value.dart';
import '../db/database.dart';
import 'entry_repository.dart';
import 'mappers.dart';
import 'tracker_repository.dart';

final _log = Logger('Upgrade');

/// Applies a [JourneyUpgrade] to a journey in one transaction.
class UpgradeRepository {
  UpgradeRepository(this._db);

  final AppDatabase _db;

  Future<void> apply(
    JourneyUpgrade upgrade, {
    required int journeyId,
    required Day today,
  }) => _db.transaction(() async {
    final trackers = TrackerRepository(_db);
    for (final p in upgrade.prayersWithRule()) {
      await trackers.update(p);
    }
    for (final t in upgrade.newMealChecks(journeyId: journeyId, from: today)) {
      await trackers.insert(t);
    }
    if (upgrade.workoutAsYesNo() case final workout?) {
      await trackers.update(workout);
      // What was written about a workout becomes the comment of a
      // "Trained" — the day keeps its credit and nothing is lost.
      final rows = await (_db.select(
        _db.entries,
      )..where((e) => e.trackerId.equals(workout.id))).get();
      final entries = EntryRepository(_db);
      var converted = 0;
      for (final e in rows.map((r) => r.toDomain())) {
        final v = e.value;
        if (v is! TextValue || v.text.trim().isEmpty) continue;
        await entries.upsert(
          trackerId: workout.id,
          day: e.day,
          value: const BoolValue(true),
          note: [
            v.text.trim(),
            if (e.note.trim().isNotEmpty) e.note.trim(),
          ].join('\n'),
        );
        converted++;
      }
      _log.info('Workout is now Yes/No; $converted past entries converted');
    }
  });
}
