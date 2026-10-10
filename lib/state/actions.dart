import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../core/time/day.dart';
import '../domain/models.dart';
import '../domain/scoring.dart';
import '../domain/tracker_value.dart';
import 'providers.dart';

final _log = Logger('EntryActions');

/// Write-side use cases for entries: persistence + haptics + celebration.
class EntryActions {
  EntryActions(this._ref);

  final Ref _ref;

  Future<void> save(
    Tracker tracker,
    Day day,
    TrackerValue? value, {
    String note = '',
  }) async {
    final settings = _ref.read(settingsValueProvider);
    final scoring = _ref.read(scoringProvider);
    final trackers = _ref.read(allTrackersProvider).value ?? const [];
    final current = _ref.read(entriesProvider).value ?? const <Entry>[];
    final before = scoring.summarize(day, trackers, EntryIndex(current));

    final repo = _ref.read(entryRepositoryProvider);
    final isEmpty = value == null || value.isEmpty;
    if (isEmpty && note.trim().isEmpty) {
      await repo.delete(tracker.id, day);
    } else {
      await repo.upsert(
        trackerId: tracker.id,
        day: day,
        value: value ?? const TextValue(''),
        note: note.trim(),
      );
    }
    _log.fine('Saved ${tracker.name} on $day');

    // Predict the new day summary without waiting for the DB stream.
    final next = [
      for (final e in current)
        if (!(e.trackerId == tracker.id && e.day == day)) e,
      if (!isEmpty)
        Entry(
          id: -1,
          trackerId: tracker.id,
          day: day,
          value: value,
          updatedAt: DateTime.now(),
        ),
    ];
    final after = scoring.summarize(day, trackers, EntryIndex(next));
    final completedTracker =
        !isEmpty && Scoring.isComplete(scoring.progress(tracker, value));
    final perfectNow = !before.isPerfect && after.isPerfect;

    if (settings.haptics) {
      if (perfectNow) {
        await HapticFeedback.heavyImpact();
      } else if (completedTracker) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    }
    if (perfectNow && settings.celebrations) {
      _ref.read(celebrationProvider.notifier).fire();
    }
  }

  Future<void> clear(Tracker tracker, Day day) => save(tracker, day, null);
}

final entryActionsProvider = Provider(EntryActions.new);
