import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../../core/time/day.dart';
import '../../domain/journey_upgrades.dart';
import '../../domain/models.dart';
import '../../domain/templates.dart';
import '../../domain/tracker_goal.dart';
import '../../domain/tracker_type.dart';
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
    // Workout first, writing only the columns that change: the meal-check
    // inserts below renumber sort orders, which a full-row write of the
    // (older) planned tracker would undo.
    if (upgrade.workoutAsYesNo() case final workout?) {
      await (_db.update(
        _db.trackers,
      )..where((t) => t.id.equals(workout.id))).write(
        TrackersCompanion(
          type: Value(workout.type),
          goal: Value(workout.goal),
          description: Value(workout.description),
          config: Value(workout.config),
        ),
      );
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
    for (final p in upgrade.prayersWithRule()) {
      await (_db.update(_db.trackers)..where((t) => t.id.equals(p.id))).write(
        TrackersCompanion(config: Value(p.config)),
      );
    }
    if (upgrade.leftOfficeWithSkip() case final leftOffice?) {
      await (_db.update(_db.trackers)..where((t) => t.id.equals(leftOffice.id)))
          .write(TrackersCompanion(config: Value(leftOffice.config)));
    }
    for (final t in upgrade.newMealChecks(journeyId: journeyId, from: today)) {
      await trackers.insert(t);
    }
    if (upgrade.mealTexts.isNotEmpty) {
      await _foldMealTexts(upgrade, journeyId: journeyId, today: today);
    }
  });

  /// Meals: "what I ate" becomes information on the matching
  /// "… on time?" check, and only eating on time earns points.
  ///
  /// - each check asks "What did you eat?" (info only), creating the check
  ///   from today if the journey doesn't have it;
  /// - meal texts from days the check already existed move into its
  ///   comment (a day without an on-time answer gets a comment-only entry,
  ///   which earns nothing);
  /// - the text trackers are archived from today: past days keep their
  ///   score and their text stays in the tracker's history.
  Future<void> _foldMealTexts(
    JourneyUpgrade upgrade, {
    required int journeyId,
    required Day today,
  }) async {
    final trackers = TrackerRepository(_db);
    final entries = EntryRepository(_db);
    for (final meal in upgrade.mealTexts) {
      final name = JourneyUpgrade.checkNameFor(meal);
      var check = _findCheck(await trackers.forJourney(journeyId), meal, name);
      if (check == null) {
        final id = await trackers.insert(
          mealOnTime(
            JourneyUpgrade.mealNames[meal.name] ?? meal.name,
            section: meal.section,
            at: meal.anchorMinutes ?? 12 * 60,
            icon: meal.icon,
            placeholder: meal.config.placeholder,
          ).copyWith(
            journeyId: journeyId,
            activeFrom: today,
            // The meal's schedule and reminder carry over to its check.
            weekdays: meal.weekdays,
            isRequired: meal.isRequired,
            reminderEnabled: meal.reminderEnabled,
            reminderMinutes: () => meal.reminderMinutes,
          ),
        );
        check = (await trackers.forJourney(journeyId))
            .firstWhere((t) => t.id == id);
      } else {
        // Keep the check's own reminder; adopt the meal's if it has none.
        final takeReminder = !check.reminderEnabled && meal.reminderEnabled;
        await (_db.update(
          _db.trackers,
        )..where((t) => t.id.equals(check!.id))).write(
          TrackersCompanion(
            icon: Value(meal.icon),
            config: Value(
              check.config.copyWith(
                notePrompt: 'What did you eat?',
                noteIsInfoOnly: true,
                placeholder: meal.config.placeholder.isEmpty
                    ? check.config.placeholder
                    : meal.config.placeholder,
              ),
            ),
            reminderEnabled: takeReminder
                ? const Value(true)
                : const Value.absent(),
            reminderMinutes: takeReminder
                ? Value(meal.reminderMinutes ?? meal.anchorMinutes)
                : const Value.absent(),
          ),
        );
      }

      final mealRows = await (_db.select(
        _db.entries,
      )..where((e) => e.trackerId.equals(meal.id))).get();
      final checkRows = await (_db.select(
        _db.entries,
      )..where((e) => e.trackerId.equals(check!.id))).get();
      final checkByDay = {
        for (final e in checkRows.map((r) => r.toDomain())) e.day: e,
      };
      var moved = 0;
      for (final e in mealRows.map((r) => r.toDomain())) {
        final text = switch (e.value) {
          TextValue(:final text) => text.trim(),
          _ => '',
        };
        final info = [
          if (text.isNotEmpty) text,
          if (e.note.trim().isNotEmpty) e.note.trim(),
        ].join('\n');
        if (info.isEmpty || e.day.isBefore(check.activeFrom)) continue;
        final existing = checkByDay[e.day];
        final note = existing?.note.trim() ?? '';
        if (note.contains(info)) continue;
        await entries.upsert(
          trackerId: check.id,
          day: e.day,
          value: existing?.value ?? const TextValue(''),
          note: note.isEmpty ? info : '$note\n$info',
        );
        moved++;
      }
      await trackers.archive(meal.id, today);
      _log.info('${meal.name} folded into $name ($moved entries moved)');
    }
  }

  /// The meal's on-time check: by its usual name, else by what it is (a
  /// Yes/No "On time"/"Late" check at the meal's time or in its section),
  /// so a check the user renamed is still found.
  static Tracker? _findCheck(List<Tracker> all, Tracker meal, String name) {
    final candidates = [
      for (final t in all)
        if (!t.isArchived && t.id != meal.id) t,
    ];
    final byName = candidates.where((t) => t.name == name).firstOrNull;
    if (byName != null) return byName;
    bool looksLikeCheck(Tracker t) =>
        t.type == TrackerType.checkbox &&
        t.goal is BoolGoal &&
        t.config.yesLabel == 'On time' &&
        t.config.noLabel == 'Late';
    final checks = candidates.where(looksLikeCheck).toList();
    return checks
            .where(
              (t) =>
                  t.anchorMinutes != null &&
                  t.anchorMinutes == meal.anchorMinutes,
            )
            .firstOrNull ??
        checks.where((t) => t.section == meal.section).singleOrNull;
  }
}
