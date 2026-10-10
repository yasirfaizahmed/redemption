import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/day.dart';
import '../data/backup/backup_service.dart';
import '../data/db/database.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/entry_repository.dart';
import '../data/repositories/journey_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/tracker_repository.dart';
import '../data/storage/attachment_store.dart';
import '../domain/analytics.dart';
import '../domain/app_settings.dart';
import '../domain/dashboard.dart';
import '../domain/models.dart';
import '../domain/scoring.dart';
import '../services/notification_service.dart';

// ---------------------------------------------------------------------------
// Infrastructure (overridden in main() and in tests)
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final attachmentStoreProvider = Provider<AttachmentStore>(
  (ref) =>
      throw UnimplementedError('attachmentStoreProvider must be overridden'),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final journeyRepositoryProvider = Provider(
  (ref) => JourneyRepository(ref.watch(databaseProvider)),
);
final trackerRepositoryProvider = Provider(
  (ref) => TrackerRepository(ref.watch(databaseProvider)),
);
final entryRepositoryProvider = Provider(
  (ref) => EntryRepository(ref.watch(databaseProvider)),
);
final dashboardRepositoryProvider = Provider(
  (ref) => DashboardRepository(ref.watch(databaseProvider)),
);
final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);
final backupServiceProvider = Provider(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(attachmentStoreProvider),
  ),
);

// ---------------------------------------------------------------------------
// Time
// ---------------------------------------------------------------------------

/// Wall clock that ticks on every minute boundary. Drives the "now" line on
/// the timeline and rolls the logical day over without an app restart.
class ClockNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    _scheduleTick();
    return DateTime.now();
  }

  void _scheduleTick() {
    _timer?.cancel();
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(next.difference(now), () {
      state = DateTime.now();
      _scheduleTick();
    });
  }

  /// Called on app resume so a long-suspended app shows the right day.
  void refresh() {
    state = DateTime.now();
    _scheduleTick();
  }
}

/// Fixed clock for tests and screenshots.
class FixedClock extends ClockNotifier {
  FixedClock(this.time);
  final DateTime time;
  @override
  DateTime build() => time;
  @override
  void refresh() {}
}

final clockProvider = NotifierProvider<ClockNotifier, DateTime>(
  ClockNotifier.new,
);

// ---------------------------------------------------------------------------
// Settings & journeys
// ---------------------------------------------------------------------------

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// Settings with defaults while loading — handy for widgets.
final settingsValueProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsProvider).value ?? const AppSettings(),
);

final activeJourneyProvider = StreamProvider<Journey?>(
  (ref) => ref.watch(journeyRepositoryProvider).watchActive(),
);

final journeysProvider = StreamProvider<List<Journey>>(
  (ref) => ref.watch(journeyRepositoryProvider).watchAll(),
);

final _activeJourneyIdProvider = Provider<int?>(
  (ref) => ref.watch(activeJourneyProvider).value?.id,
);

final todayProvider = Provider<Day>((ref) {
  final now = ref.watch(clockProvider);
  final dayStart = ref.watch(
    settingsValueProvider.select((s) => s.dayStartMinutes),
  );
  return Day.current(dayStartMinutes: dayStart, now: now);
});

final scoringProvider = Provider<Scoring>(
  (ref) => Scoring(
    dayStartMinutes: ref.watch(
      settingsValueProvider.select((s) => s.dayStartMinutes),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Trackers, entries, dashboard
// ---------------------------------------------------------------------------

/// All trackers of the active journey, archived included.
final allTrackersProvider = StreamProvider<List<Tracker>>((ref) {
  final id = ref.watch(_activeJourneyIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(trackerRepositoryProvider).watchForJourney(id);
});

final activeTrackersProvider = Provider<List<Tracker>>(
  (ref) => [
    for (final t in ref.watch(allTrackersProvider).value ?? const <Tracker>[])
      if (!t.isArchived) t,
  ],
);

final trackerByIdProvider = Provider.family<Tracker?, int>((ref, id) {
  for (final t in ref.watch(allTrackersProvider).value ?? const <Tracker>[]) {
    if (t.id == id) return t;
  }
  return null;
});

final entriesProvider = StreamProvider<List<Entry>>((ref) {
  final id = ref.watch(_activeJourneyIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(entryRepositoryProvider).watchForJourney(id);
});

final entryIndexProvider = Provider<EntryIndex>((ref) {
  final entries = ref.watch(entriesProvider).value;
  return entries == null ? EntryIndex.empty : EntryIndex(entries);
});

final dashboardItemsProvider = StreamProvider<List<DashboardItem>>((ref) {
  final id = ref.watch(_activeJourneyIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(dashboardRepositoryProvider).watch(id);
});

// ---------------------------------------------------------------------------
// Analytics (derived, recomputed only when inputs change)
// ---------------------------------------------------------------------------

final journeyStatsProvider = Provider<JourneyStats?>((ref) {
  final journey = ref.watch(activeJourneyProvider).value;
  if (journey == null) return null;
  return JourneyStats.compute(
    journey: journey,
    trackers: ref.watch(allTrackersProvider).value ?? const [],
    index: ref.watch(entryIndexProvider),
    today: ref.watch(todayProvider),
    scoring: ref.watch(scoringProvider),
    threshold: ref.watch(
      settingsValueProvider.select((s) => s.successThreshold),
    ),
  );
});

final daySummaryProvider = Provider.family<DaySummary, Day>(
  (ref, day) => ref
      .watch(scoringProvider)
      .summarize(
        day,
        ref.watch(allTrackersProvider).value ?? const [],
        ref.watch(entryIndexProvider),
      ),
);

final trackerStatsProvider = Provider.family<TrackerStats?, int>((ref, id) {
  final journey = ref.watch(activeJourneyProvider).value;
  final tracker = ref.watch(trackerByIdProvider(id));
  if (journey == null || tracker == null) return null;
  return TrackerStats.compute(
    tracker: tracker,
    journey: journey,
    index: ref.watch(entryIndexProvider),
    today: ref.watch(todayProvider),
    scoring: ref.watch(scoringProvider),
  );
});

/// Text suggestions per tracker (frequency ranked).
final textSuggestionsProvider = Provider.family<List<String>, int>((ref, id) {
  final tracker = ref.watch(trackerByIdProvider(id));
  if (tracker == null || !tracker.config.suggestFromHistory) return const [];
  return textSuggestions(tracker, ref.watch(entryIndexProvider));
});

// ---------------------------------------------------------------------------
// UI state
// ---------------------------------------------------------------------------

/// Day shown on the Today tab (null = follow the current day).
class SelectedDayNotifier extends Notifier<Day?> {
  @override
  Day? build() => null;

  void select(Day? day) => state = day;
}

final selectedDayProvider = NotifierProvider<SelectedDayNotifier, Day?>(
  SelectedDayNotifier.new,
);

final effectiveSelectedDayProvider = Provider<Day>((ref) {
  final today = ref.watch(todayProvider);
  final selected = ref.watch(selectedDayProvider);
  if (selected == null || selected.isAfter(today)) return today;
  return selected;
});

/// Incremented whenever the user completes a perfect day (drives confetti).
class CelebrationNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void fire() => state++;
}

final celebrationProvider = NotifierProvider<CelebrationNotifier, int>(
  CelebrationNotifier.new,
);
